// Process recovery.
//
// Every pending step of a job is a Process record that also carries the message
// the step needs (tool + params), so the record, not the in-memory state of
// projects, is the source of truth:
// - dispatch() publishes a step and stamps `dispatched_at` once the broker has
//   confirmed it;
// - the watchdog publishes again the records whose message was never confirmed
//   (projects stopped between saving a record and publishing it). It runs when
//   projects starts and then periodically;
// - a step that is overdue while nothing is waiting in its tool's queue lost its
//   message: the watchdog fails it and tells the user, instead of the project
//   staying "processing" forever. A step that was published is never published
//   again, because image steps after the first overwrite their input in place.
const fs = require("fs");
const path = require("path");
const { v4: uuidv4 } = require("uuid");

const Process = require("../controllers/process");
const Project = require("../controllers/project");
const {
  send_msg_tool,
  send_msg_client_error,
  send_msg_client_preview_error,
  tool_queue_depth,
} = require("./project_msg");
const { intermediateOutputs } = require("./videoStages");

const ms = (name, fallback) => Number(process.env[name] || fallback);
const INTERVAL_MS = ms("RECOVERY_INTERVAL_MS", 15000);
// a record younger than this may still be being published by its request
const UNDISPATCHED_GRACE_MS = ms("RECOVERY_UNDISPATCHED_MS", 30000);
const IMAGE_STEP_TIMEOUT_MS = ms("RECOVERY_IMAGE_TIMEOUT_MS", 5 * 60000);
const VIDEO_STAGE_TIMEOUT_MS = ms("RECOVERY_VIDEO_TIMEOUT_MS", 60 * 60000);
const LOST_CODE = "30001";
const LOST_MESSAGE = "A processing step did not complete. Please try again.";

// Intermediate stage files are only needed until the next stage has read them.
function removeStageFiles(stages) {
  for (const uri of intermediateOutputs(stages)) {
    fs.rmSync(path.resolve(__dirname, "..", uri), { force: true });
  }
}

async function dispatch(job, deps = defaultDeps) {
  await deps.send(job.msg_id, new Date().toISOString(), job.og_img_uri, job.new_img_uri, job.tool, job.params);
  await deps.markDispatched(job.msg_id);
}

// Ends a job whose step was lost, as a tool error would: an extraction run keeps
// it as a barrier so a partial run is never committed.
async function failJob(job, deps = defaultDeps) {
  const preview = /preview/.test(job.msg_id);
  const project = await deps.getProject(job.user_id, job.project_id);
  const holdsRun = !preview && Boolean(project && project.tools.some((t) => t.procedure === "extract_frames"));
  if (holdsRun) await deps.markFailed(job.msg_id);
  else await deps.deleteJob(job.msg_id);
  if (Array.isArray(job.stages)) deps.removeStageFiles(job.stages);
  const runner = job.runner_id || job.user_id;
  const timestamp = new Date().toISOString();
  if (preview) deps.previewError(`update-client-preview-${uuidv4()}`, timestamp, runner, LOST_CODE, LOST_MESSAGE);
  else deps.processError(`update-client-process-${uuidv4()}`, timestamp, runner, LOST_CODE, LOST_MESSAGE);
}

async function recoverOnce(now = Date.now(), deps = defaultDeps) {
  const report = { redispatched: 0, failed: 0 };
  for (const job of await deps.findUndispatched(new Date(now - UNDISPATCHED_GRACE_MS))) {
    await dispatch(job, deps);
    report.redispatched++;
    deps.log(`[RECOVERY] published again msg=${job.msg_id} tool=${job.tool}`);
  }
  const shortest = Math.min(IMAGE_STEP_TIMEOUT_MS, VIDEO_STAGE_TIMEOUT_MS);
  for (const job of await deps.findDispatchedBefore(new Date(now - shortest))) {
    const timeout = Array.isArray(job.stages) && job.stages.length ? VIDEO_STAGE_TIMEOUT_MS : IMAGE_STEP_TIMEOUT_MS;
    if (now - new Date(job.dispatched_at).getTime() < timeout) continue;
    // still waiting behind other work (or the broker cannot tell): not lost
    if ((await deps.queueDepth(job.tool)) !== 0) continue;
    await failJob(job, deps);
    report.failed++;
    deps.log(`[RECOVERY] failed lost step msg=${job.msg_id} tool=${job.tool}`);
  }
  return report;
}

const defaultDeps = {
  send: send_msg_tool,
  markDispatched: Process.markDispatched,
  markFailed: Process.markFailed,
  deleteJob: Process.deleteByMsgId,
  findUndispatched: Process.findUndispatched,
  findDispatchedBefore: Process.findDispatchedBefore,
  getProject: Project.getOne,
  queueDepth: tool_queue_depth,
  removeStageFiles,
  processError: send_msg_client_error,
  previewError: send_msg_client_preview_error,
  log: (line) => console.log(line),
};

function startRecovery() {
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try {
      await recoverOnce();
    } catch (err) {
      console.error("[RECOVERY] error:", err.message);
    } finally {
      running = false;
    }
  };
  tick(); // at start-up: records left behind by a previous instance
  return setInterval(tick, INTERVAL_MS);
}

module.exports = { dispatch, failJob, recoverOnce, startRecovery, removeStageFiles };

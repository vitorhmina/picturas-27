// A video pipeline split into stages, one stage per video service:
//   effects    contiguous ordinary effects (incl. trim/speed) -> video_effects_queue
//   subtitles  speech recognition and burned-in captions      -> video_subtitles_queue
//   frames     still-frame extraction (always terminal)        -> video_frames_queue
//
// Mirrors Tools/video_common/pipeline.py (plan_stages). Both are checked against
// Tools/video_common/tests/stage_plans.json so they cannot drift apart.
const path = require("path");

const STAGE_QUEUE_TOOL = {
  effects: "video_effects",
  subtitles: "video_subtitles",
  frames: "video_frames",
};
const EDIT_SHARE_BEFORE_FRAMES = 70;

function editStages(tools, preview) {
  if (!tools.some((t) => t.procedure === "subtitles")) {
    return [{ kind: "effects", tools: [...tools], preview: Boolean(preview) }];
  }
  const stages = [];
  let pending = [];
  for (const tool of tools) {
    if (tool.procedure === "subtitles") {
      // Normalize the first input to MP4/H.264 even when captioning is a no-op.
      if (pending.length || !stages.length) {
        stages.push({ kind: "effects", tools: pending });
        pending = [];
      }
      stages.push({ kind: "subtitles" });
    } else {
      pending.push(tool);
    }
  }
  if (pending.length) stages.push({ kind: "effects", tools: pending });

  // Only the last stage with a temporal edit is limited to the preview excerpt
  // (the first stage if there is none), as in the single video worker.
  let previewStage = 0;
  stages.forEach((s, i) => {
    if (s.kind === "effects" && s.tools.some((t) => t.procedure === "trim" || t.procedure === "speed")) {
      previewStage = i;
    }
  });
  stages.forEach((s, i) => {
    if (s.kind === "effects") s.preview = Boolean(preview) && i === previewStage;
  });
  return stages;
}

function share(stages, offset, span) {
  const each = span / stages.length;
  stages.forEach((s, i) => {
    s.progress = { offset: offset + i * each, span: each };
  });
  return stages;
}

// Ordered stages for one video; `tools` is videoPipeline(project, imgId).
function planVideoStages(tools, preview) {
  const list = [...(tools || [])];
  const last = list[list.length - 1];
  if (last && last.procedure === "extract_frames") {
    const params = last.params || {};
    const prefix = list.slice(0, -1);
    if (!prefix.length) {
      // Seek directly in the original: no transcode before extracting stills.
      return share([{ kind: "frames", params, preview: Boolean(preview), original: true }], 0, 100);
    }
    // Sampling spans the complete edited timeline, including in preview.
    const edits = share(editStages(prefix, false), 0, EDIT_SHARE_BEFORE_FRAMES);
    const frames = { kind: "frames", params, preview: Boolean(preview), original: false };
    return [...edits, ...share([frames], EDIT_SHARE_BEFORE_FRAMES, 100 - EDIT_SHARE_BEFORE_FRAMES)];
  }
  return share(editStages(list, preview), 0, 100);
}

// Assigns where each stage writes. The last stage writes the final output;
// earlier ones write next to it in a hidden folder that is removed when the job
// ends (the out/ and preview/ folders are also wiped on the next run).
function assignStageOutputs(stages, finalUri, jobId) {
  // Plain concatenation keeps the "./images/..." form used for every other URI.
  const dir = `${path.posix.dirname(finalUri)}/.video-stages`;
  const base = path.posix.basename(finalUri, path.posix.extname(finalUri));
  return stages.map((stage, i) => ({
    ...stage,
    output: i === stages.length - 1 ? finalUri : `${dir}/${base}-${jobId}-${i}.mp4`,
  }));
}

function stageTool(stage) {
  return STAGE_QUEUE_TOOL[stage.kind];
}

// Message parameters for stage `index` (send_msg_tool adds input/output URIs).
function stageParams(stages, index, { preview, progress }) {
  const { output, ...stage } = stages[index];
  return { stage, last: index === stages.length - 1, preview: Boolean(preview), progress };
}

// Intermediate files of a job (every stage output but the final one).
function intermediateOutputs(stages) {
  return (stages || []).slice(0, -1).map((s) => s.output).filter(Boolean);
}

module.exports = {
  STAGE_QUEUE_TOOL,
  planVideoStages,
  assignStageOutputs,
  stageTool,
  stageParams,
  intermediateOutputs,
};

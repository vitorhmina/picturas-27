const test = require("node:test");
const assert = require("node:assert/strict");

const { recoverOnce, dispatch } = require("../utils/recovery");

const NOW = Date.parse("2026-11-22T12:00:00Z");
const ago = (s) => new Date(NOW - s * 1000);

function fakeDeps({ undispatched = [], dispatched = [], depth = 0, tools = [] } = {}) {
  const calls = { sent: [], marked: [], failed: [], deleted: [], processErrors: [], previewErrors: [], removedStages: 0 };
  return {
    calls,
    send: async (msg_id, ts, og, out, tool, params) => calls.sent.push({ msg_id, og, out, tool, params }),
    markDispatched: async (msg_id) => calls.marked.push(msg_id),
    markFailed: async (msg_id) => calls.failed.push(msg_id),
    deleteJob: async (msg_id) => calls.deleted.push(msg_id),
    findUndispatched: async (before) => undispatched.filter((j) => j.createdAt < before),
    findDispatchedBefore: async (before) => dispatched.filter((j) => j.dispatched_at < before),
    getProject: async () => ({ tools }),
    queueDepth: async () => depth,
    removeStageFiles: () => calls.removedStages++,
    processError: (...a) => calls.processErrors.push(a),
    previewError: (...a) => calls.previewErrors.push(a),
    log: () => {},
  };
}

const job = (over) => ({
  msg_id: "request-1", user_id: "u", runner_id: "r", project_id: "p",
  og_img_uri: "in.jpg", new_img_uri: "out.jpg", tool: "contrast", params: { contrastFactor: 1.2 },
  ...over,
});

test("dispatch publishes the stored message and records the confirmation", async () => {
  const deps = fakeDeps();
  await dispatch(job(), deps);
  assert.deepEqual(deps.calls.sent, [{ msg_id: "request-1", og: "in.jpg", out: "out.jpg", tool: "contrast", params: { contrastFactor: 1.2 } }]);
  assert.deepEqual(deps.calls.marked, ["request-1"]);
});

test("a record never published is published again after the grace period", async () => {
  const deps = fakeDeps({ undispatched: [job({ createdAt: ago(60) }), job({ msg_id: "request-young", createdAt: ago(5) })] });
  const report = await recoverOnce(NOW, deps);
  assert.equal(report.redispatched, 1);
  assert.deepEqual(deps.calls.marked, ["request-1"]);
});

test("an overdue image step with nothing waiting in its queue is failed and reported", async () => {
  const deps = fakeDeps({ dispatched: [job({ dispatched_at: ago(6 * 60) })], depth: 0 });
  const report = await recoverOnce(NOW, deps);
  assert.equal(report.failed, 1);
  assert.deepEqual(deps.calls.deleted, ["request-1"]);
  assert.equal(deps.calls.processErrors.length, 1);
  assert.equal(deps.calls.processErrors[0][2], "r"); // the user who ran it
  assert.equal(deps.calls.sent.length, 0); // never published twice
});

test("a step still waiting behind other work, or with an unknown queue, is left alone", async () => {
  for (const depth of [3, null]) {
    const deps = fakeDeps({ dispatched: [job({ dispatched_at: ago(6 * 60) })], depth });
    assert.equal((await recoverOnce(NOW, deps)).failed, 0);
    assert.equal(deps.calls.deleted.length, 0);
  }
});

test("a video stage gets the longer timeout", async () => {
  const stages = [{ kind: "effects" }, { kind: "subtitles" }];
  const recent = fakeDeps({ dispatched: [job({ tool: "video_subtitles", stages, dispatched_at: ago(20 * 60) })] });
  assert.equal((await recoverOnce(NOW, recent)).failed, 0);
  const old = fakeDeps({ dispatched: [job({ tool: "video_subtitles", stages, dispatched_at: ago(61 * 60) })] });
  assert.equal((await recoverOnce(NOW, old)).failed, 1);
  assert.equal(old.calls.removedStages, 1);
});

test("a lost step of an extraction run stays as a failed barrier", async () => {
  const deps = fakeDeps({ dispatched: [job({ dispatched_at: ago(6 * 60) })], tools: [{ procedure: "extract_frames" }] });
  await recoverOnce(NOW, deps);
  assert.deepEqual(deps.calls.failed, ["request-1"]);
  assert.equal(deps.calls.deleted.length, 0);
});

test("a lost preview step reports a preview error", async () => {
  const deps = fakeDeps({ dispatched: [job({ msg_id: "preview-1", dispatched_at: ago(6 * 60) })] });
  await recoverOnce(NOW, deps);
  assert.equal(deps.calls.previewErrors.length, 1);
  assert.equal(deps.calls.processErrors.length, 0);
});

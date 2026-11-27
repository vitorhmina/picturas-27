const test = require("node:test");
const assert = require("node:assert/strict");

const { runStatus } = require("../utils/runStatus");

const img = (id) => ({ _id: id, media_type: "image" });
const vid = (id) => ({ _id: id, media_type: "video" });
const tools = [
  { procedure: "brightness", position: 0 },
  { procedure: "contrast", position: 1 },
  { procedure: "trim", position: 2 }, // video-only: not an image step
];
const project = (over = {}) => ({
  activeToken: 3, committedToken: 2, tools, imgs: [img("a"), img("b"), vid("v")], ...over,
});
const proc = (img_id, cur_pos, over = {}) => ({ img_id, cur_pos, token: 3, msg_id: `request-${img_id}`, ...over });

test("counts one step per image tool and one per video", () => {
  const s = runStatus(project(), [proc("a", 0), proc("b", 0), proc("v", 0)]);
  assert.equal(s.status, "running");
  assert.equal(s.total, 2 * 2 + 1);
  assert.equal(s.done, 0);
});

test("an item with no pending record has finished", () => {
  const s = runStatus(project(), [proc("a", 1), proc("v", 2)]);
  // a: 1 of 2, b: finished (2), v: running (a video counts only when it finishes)
  assert.equal(s.done, 3);
  assert.deepEqual(s.media.map((m) => m.done), [1, 2, 0]);
});

test("a run whose last record finished but is not committed yet is still running", () => {
  // the last source keeps its record until the commit, so the page never sees
  // a run without records that has not been committed
  const s = runStatus(project(), [proc("v", 1, { finished: true })]);
  assert.equal(s.status, "running");
  assert.equal(s.done, s.total);
});

test("a committed run is idle and complete", () => {
  const s = runStatus(project({ committedToken: 3 }), []);
  assert.equal(s.status, "idle");
  assert.equal(s.committed, true);
  assert.equal(s.done, s.total);
});

test("records of other runs and previews are ignored", () => {
  const s = runStatus(project(), [proc("a", 0, { token: 2 }), proc("b", 0, { msg_id: "preview-x" })]);
  assert.equal(s.status, "idle");
  assert.equal(s.committed, false);
});

test("a failed record marks the run as failed", () => {
  const s = runStatus(project(), [proc("v", 1, { failed: true })]);
  assert.equal(s.status, "failed");
});

test("a project never processed is idle and not committed", () => {
  const s = runStatus(project({ activeToken: 0, committedToken: 0 }), []);
  assert.equal(s.status, "idle");
  assert.equal(s.committed, false);
  assert.equal(s.done, 0);
});

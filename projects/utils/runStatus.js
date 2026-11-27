// State of a project's current processing run, derived from what the server
// already stores: the project's run tokens and the pending Process records of
// the run (one per media item, replaced step by step). The browser uses it to
// pick up a run after a reload, in another tab or on another page.
//
// Steps are counted the way the frontend counts process-update events: one per
// (image, image tool) and one per video (a video counts when it finishes).

const { imageTools, isVideoMedia } = require("./video");

function runStatus(project, processes) {
  const token = project.activeToken || 0;
  // token 0: the project has never been processed
  const committed = token > 0 && (project.committedToken || 0) === token;
  const pending = (processes || []).filter(
    (p) => (p.token || 0) === token && !/preview/.test(p.msg_id || "")
  );

  const imgToolCount = imageTools(project).length;
  const media = project.imgs || [];
  const steps = (m) => (isVideoMedia(m) ? 1 : imgToolCount);
  const total = media.reduce((acc, m) => acc + steps(m), 0);

  if (committed || pending.length === 0) {
    // committed: the last run finished; otherwise there is no run in progress
    // (none started, cancelled, or ended with an error already reported)
    return { status: "idle", token, committed, total, done: committed ? total : 0, media: [] };
  }

  const failed = pending.some((p) => p.failed);
  const byMedia = new Map(pending.map((p) => [String(p.img_id), p]));
  let done = 0;
  const items = media.map((m) => {
    const p = byMedia.get(String(m._id));
    const n = steps(m);
    // no pending record: the batch is registered up front, so this item has finished;
    // a finished record waits only for the run to be committed
    const d = !p || p.finished ? n : isVideoMedia(m) ? 0 : Math.min(p.cur_pos || 0, n);
    done += d;
    return { img_id: String(m._id), video: isVideoMedia(m), done: d, total: n };
  });

  return {
    status: failed ? "failed" : "running",
    token,
    committed,
    total,
    done: Math.min(done, total),
    media: items,
  };
}

module.exports = { runStatus };

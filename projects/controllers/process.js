var Process = require("../models/process");

module.exports.getAll = async () => {
  return await Process.find().sort({ _id: 1 }).exec();
};

module.exports.getProject = async (user_id, project_id) => {
  return await Process.find({ user_id: user_id, project_id: project_id })
    .sort({ _id: 1 })
    .exec();
};

module.exports.getOne = async (user_id, project_id, process_id) => {
  return await Process.findOne({
    user_id: user_id,
    project_id: project_id,
    _id: process_id,
  }).exec();
};

module.exports.getOneByMsgId = async (msg_id) => {
  return await Process.findOne({ msg_id }).exec();
};

module.exports.create = async (process) => {
  return await Process.create(process);
};

module.exports.update = (user_id, project_id, process_id, process) => {
  return Process.updateOne(
    { user_id: user_id, project_id: project_id, _id: process_id },
    process,
  );
};

module.exports.delete = (user_id, project_id, process_id) => {
  return Process.deleteOne({
    user_id: user_id,
    project_id: project_id,
    _id: process_id,
  });
};

module.exports.countByProjectAndToken = async (project_id, token) => {
  return await Process.countDocuments({ project_id, token }).exec();
};

// records of a run that still hold its commit back (not yet finished)
module.exports.countUnfinishedByProjectAndToken = async (project_id, token) => {
  return await Process.countDocuments({ project_id, token, finished: { $ne: true } }).exec();
};


// --- recovery (utils/recovery.js) ---

const setByMsgId = (msg_id, fields) => Process.updateOne({ msg_id }, { $set: fields }).exec();

module.exports.markDispatched = (msg_id) => setByMsgId(msg_id, { dispatched_at: new Date() });

module.exports.markOutputStored = (msg_id) => setByMsgId(msg_id, { output_stored: true });

module.exports.setSuccessor = (msg_id, successor_msg_id) => setByMsgId(msg_id, { successor_msg_id });

module.exports.markFailed = (msg_id) => setByMsgId(msg_id, { failed: true });

module.exports.markFinished = (msg_id) => setByMsgId(msg_id, { finished: true });

module.exports.deleteByMsgId = (msg_id) => Process.deleteOne({ msg_id }).exec();

// records saved before `before` whose message was never confirmed by the broker
module.exports.findUndispatched = async (before) => {
  return await Process.find({ dispatched_at: null, tool: { $exists: true }, createdAt: { $lt: before } }).exec();
};

// steps published before `before` that are still pending
module.exports.findDispatchedBefore = async (before) => {
  return await Process.find({ dispatched_at: { $lt: before }, failed: { $ne: true } }).exec();
};

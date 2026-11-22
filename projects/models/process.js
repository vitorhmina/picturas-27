const mongoose = require("mongoose");

var processSchema = new mongoose.Schema({
  user_id: { type: mongoose.Schema.Types.ObjectId, required: true },
  project_id: { type: mongoose.Schema.Types.ObjectId, required: true },
  img_id: { type: mongoose.Schema.Types.ObjectId, required: true },
  msg_id: { type: String, required: true },
  cur_pos: { type: Number, required: true },
  og_img_uri: { type: String, required: true },
  new_img_uri: { type: String, required: true },
  runner_id: { type: String, required: false },  
  cache_key: { type: String, required: false },
  cancelToken: { type: Number, required: false },
  token: { type: Number, required: true },
  // video jobs: the stage plan (utils/videoStages.js); cur_pos is the stage index
  stages: { type: Array, required: false },
}, { timestamps: true });

module.exports = mongoose.model("process", processSchema);

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
  // Recovery (utils/recovery.js). The record carries the message its step needs,
  // so it can be published again if projects stopped before publishing it.
  tool: { type: String, required: false },
  params: { type: mongoose.Schema.Types.Mixed, required: false },
  dispatched_at: { type: Date, required: false },     // when the broker confirmed the message
  output_stored: { type: Boolean, required: false },  // results/previews of this step are saved
  successor_msg_id: { type: String, required: false }, // the next step, once registered
  failed: { type: Boolean, required: false },         // failed job kept as a commit barrier
  finished: { type: Boolean, required: false },       // last step done; kept until the run is committed
}, { timestamps: true });

processSchema.index({ msg_id: 1 });
processSchema.index({ dispatched_at: 1 });

module.exports = mongoose.model("process", processSchema);

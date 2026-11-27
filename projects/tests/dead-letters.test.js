const test = require("node:test");
const assert = require("node:assert/strict");

const { deadLetterReply, DEAD_LETTER_CODE } = require("../utils/deadLetters");

test("a dead letter is answered as an error reply of its step", () => {
  const reply = deadLetterReply({ messageId: "request-1", procedure: "brightness" }, "brightness_queue");
  // the reply handler finds the step by correlationId and ends it with this error
  assert.equal(reply.correlationId, "request-1");
  assert.equal(reply.status, "error");
  assert.equal(reply.error.code, DEAD_LETTER_CODE);
  assert.match(reply.error.msg, /brightness step failed twice/);
  assert.equal(reply.error.details.queue, "brightness_queue");
  assert.notEqual(reply.messageId, "request-1");
});

// Dead letters (DA-2). A tool rejects a message that made it fail twice (see
// Tools/utils/rabbit_mq.py). A policy in rabbitMQ/definitions.json routes the
// rejected message of any tool queue through the picturas.dlx exchange to
// dead_letter_queue, consumed here, and to dead_letter_archive, which keeps the
// last 1000 for analysis (RabbitMQ management, with the x-death headers).
//
// Each dead letter is answered as an error reply of its tool on project_queue,
// so the reply handler ends the step and the user gets the error at once,
// instead of when the recovery watchdog's deadline expires. A repeated dead
// letter is harmless: the step's record is gone and the reply is ignored.

const { v4: uuidv4 } = require("uuid");
const { send_rabbit_msg, read_rabbit_msg } = require("./rabbit_mq");

const DEAD_LETTER_QUEUE = "dead_letter_queue";
const DEAD_LETTER_CODE = 3000;

function deadLetterReply(request, queue) {
  return {
    messageId: `dead-letter-${uuidv4()}`,
    correlationId: request.messageId,
    timestamp: new Date().toISOString(),
    status: "error",
    error: {
      code: DEAD_LETTER_CODE,
      msg: `The ${request.procedure || "tool"} step failed twice and was discarded`,
      details: { queue },
    },
  };
}

async function handleDeadLetter(msg) {
  const death = ((msg.properties && msg.properties.headers) || {})["x-death"];
  const queue = (Array.isArray(death) && death[0] && death[0].queue) || "unknown";
  let request = null;
  try {
    request = JSON.parse(msg.content.toString());
  } catch (err) {
    // nothing to answer; the message stays in dead_letter_archive
  }
  if (!request || !request.messageId) {
    console.error(`[DLQ] unreadable message from ${queue}`);
    return;
  }
  console.error(`[DLQ] msg=${request.messageId} queue=${queue} procedure=${request.procedure}`);
  // resolves once the broker confirmed the reply; only then is the dead letter acknowledged
  await send_rabbit_msg(deadLetterReply(request, queue), "project_queue");
}

function consumeDeadLetters() {
  read_rabbit_msg(DEAD_LETTER_QUEUE, handleDeadLetter);
}

module.exports = { consumeDeadLetters, handleDeadLetter, deadLetterReply, DEAD_LETTER_CODE };

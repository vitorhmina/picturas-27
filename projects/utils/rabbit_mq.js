const amqp = require('amqplib');

const rabbit_host = process.env.RABBITMQ_HOST;
const rabbit_port = process.env.RABBITMQ_PORT;
const rabbit_username = process.env.RABBITMQ_USER;
const rabbit_password = process.env.RABBITMQ_PASS;
const exchange = "picturas";
// Replies handled at the same time; each one is acknowledged only after its handler finished.
const prefetch = Number(process.env.RABBITMQ_PREFETCH || 16);

const rabbit_mq_sv = `amqp://${rabbit_username}:${rabbit_password}@${rabbit_host}:${rabbit_port}`;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// One long-lived connection (it used to be one connection per message, closed
// after 500 ms whether or not the broker had the message). It is re-opened
// after a broker restart and the consumers are registered again.
let connecting = null;
const consumers = [];

function connect() {
    if (!connecting) {
        connecting = (async () => {
            for (let attempt = 1; ; attempt++) {
                let connection = null;
                try {
                    connection = await amqp.connect(rabbit_mq_sv);
                    connection.on('error', (err) => console.error(`[rabbit] connection error: ${err.message}`));
                    connection.on('close', () => {
                        console.error('[rabbit] connection closed; reconnecting');
                        connecting = null;
                        setTimeout(() => connect(), 1000);
                    });
                    // confirm channel: a publish completes only once the broker has the message
                    const publisher = await connection.createConfirmChannel();
                    await publisher.assertExchange(exchange, 'direct', { durable: true });
                    for (const consumer of consumers) await startConsumer(connection, consumer);
                    return { connection, publisher };
                } catch (err) {
                    console.error(`[rabbit] connect failed (${err.message}); retry ${attempt}`);
                    if (connection) connection.removeAllListeners('close');
                    if (connection) connection.close().catch(() => {});
                    await sleep(Math.min(1000 * attempt, 10000));
                }
            }
        })();
    }
    return connecting;
}

async function publish(msg, queue) {
    const body = Buffer.from(JSON.stringify(msg));
    for (let attempt = 1; ; attempt++) {
        try {
            const { publisher } = await connect();
            await new Promise((resolve, reject) => {
                // persistent: the message survives a broker restart (the queues are durable)
                publisher.publish(exchange, queue, body, { persistent: true }, (err) => (err ? reject(err) : resolve()));
            });
            return;
        } catch (err) {
            console.error(`[rabbit] publish to ${queue} failed (${err.message}); retry ${attempt}`);
            await sleep(Math.min(500 * attempt, 5000));
        }
    }
}

// Callers do not need to wait; the promise resolves once the broker confirmed the message.
function send_rabbit_msg(msg, queue) {
    return publish(msg, queue);
}

function settle(channel, action, msg, ...args) {
    // the channel may have closed meanwhile: the broker then redelivers the message
    try {
        channel[action](msg, ...args);
    } catch (err) {
        console.error(`[rabbit] ${action} failed (${err.message})`);
    }
}

async function startConsumer(connection, consumer) {
    if (consumer.connection === connection) return;
    consumer.connection = connection;
    const channel = await connection.createChannel();
    await channel.assertExchange(exchange, 'direct', { durable: true });
    const q = await channel.assertQueue(consumer.queue, { durable: true });
    await channel.prefetch(prefetch);
    await channel.consume(q.queue, async (msg) => {
        if (msg == null) return; // consumer cancelled by the broker
        try {
            await consumer.callback(msg);
            // Acknowledge only after the handler finished: if the service dies
            // midway, the broker redelivers the message instead of losing it
            settle(channel, 'ack', msg);
        } catch (err) {
            // retry once, then drop it so a message that always fails cannot loop forever
            console.error(`[rabbit] handler failed on ${consumer.queue}: ${err.message}`);
            settle(channel, 'nack', msg, false, !msg.fields.redelivered);
        }
    }, {
        noAck: false
    });
}

// Ready (not yet delivered) messages in a queue; null if it cannot be checked.
async function queue_depth(queue) {
    try {
        const { connection } = await connect();
        const channel = await connection.createChannel();
        channel.on('error', () => {}); // a missing queue closes this channel only
        try {
            return (await channel.checkQueue(queue)).messageCount;
        } finally {
            channel.close().catch(() => {});
        }
    } catch (err) {
        return null;
    }
}

function read_rabbit_msg(queue, callback) {
    const consumer = { queue, callback, connection: null };
    consumers.push(consumer);
    connect().then(({ connection }) => startConsumer(connection, consumer))
        .catch((err) => console.error(`[rabbit] consumer on ${queue} failed: ${err.message}`));
}

module.exports = { send_rabbit_msg, read_rabbit_msg, queue_depth };

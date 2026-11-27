import signal
import time

import pika
from pika.exchange_type import ExchangeType

"""
# Callback example for those who need it
def callback(ch, method, properties, body):
    print(f" [x] Received {body.decode()}")
"""

EXCHANGE = "picturas"
# Persistent messages survive a broker restart (the queues are already durable).
PERSISTENT = pika.BasicProperties(delivery_mode=pika.DeliveryMode.Persistent)
TRANSIENT_ERRORS = (pika.exceptions.AMQPConnectionError, pika.exceptions.AMQPChannelError)


class Rabbit_MQ:
    """Consumes a tool queue with manual acknowledgement (at-least-once delivery).

    A message is acknowledged only after its callback returns, that is after the
    reply to the orchestrator was published and confirmed by the broker. If the
    tool dies midway, the broker redelivers the message to the restarted (or
    another) replica, so a crash no longer loses the job. Each replica takes one
    message at a time, so a crash affects at most one in-flight message.
    """

    def __init__(self, host, port, username, password, prefetch=1):
        self._params = pika.ConnectionParameters(
            host, int(port), '/', pika.PlainCredentials(username, password),
            # a callback blocks this thread while it processes (AI tools can take
            # minutes); without heartbeats the broker does not drop the connection
            # midway, as in the video workers
            heartbeat=0,
        )
        self._prefetch = prefetch
        self._queue = ''
        self._busy = False
        self._stopping = False
        self._connect()
        signal.signal(signal.SIGTERM, self._on_sigterm)

    def _connect(self):
        for attempt in range(30):
            try:
                self._connection = pika.BlockingConnection(self._params)
                break
            except pika.exceptions.AMQPConnectionError:
                time.sleep(min(2 * (attempt + 1), 10))
        else:
            raise RuntimeError("Could not connect to RabbitMQ")
        self._channel = self._connection.channel()
        self._channel.exchange_declare(
            exchange=EXCHANGE,
            exchange_type=ExchangeType.direct,
            durable=True,
        )
        # basic_publish now waits for the broker and raises if it rejects the message
        self._channel.confirm_delivery()
        self._channel.basic_qos(prefetch_count=self._prefetch)

    def send_rabbit_msg(self, msg, queue):
        self._channel.basic_publish(exchange=EXCHANGE, routing_key=queue, body=msg, properties=PERSISTENT)

    def _on_sigterm(self, signum, frame):
        # Graceful stop (docker stop, scale-down): an idle replica exits at once;
        # a busy one finishes and acknowledges its current message first.
        self._stopping = True
        if not self._busy:
            raise SystemExit(0)

    def _wrap(self, callback):
        def on_message(ch, method, properties, body):
            self._busy = True
            try:
                callback(ch, method, properties, body)
            except TRANSIENT_ERRORS:
                # the reply was not confirmed: the message stays unacknowledged and
                # is redelivered once the consumer reconnects
                raise
            except Exception as e:  # noqa: BLE001 - a bug in the tool, not a broker fault
                # retry once (possibly on another replica), then reject it so a message
                # that always fails cannot loop forever: the broker dead-letters it
                # (policy in rabbitMQ/definitions.json) and the orchestrator answers
                # the step with an error (projects/utils/deadLetters.js)
                print(f"[rabbit] callback failed on {self._queue}: {e!r} "
                      f"(redelivered={method.redelivered})", flush=True)
                ch.basic_nack(delivery_tag=method.delivery_tag, requeue=not method.redelivered)
            else:
                ch.basic_ack(delivery_tag=method.delivery_tag)
            finally:
                self._busy = False
            if self._stopping:
                ch.stop_consuming()
        return on_message

    def read_rabbit_msg(self, queue, callback):
        if self._queue == '':
            self._queue = queue

        while not self._stopping:
            try:
                self._channel.queue_declare(queue=self._queue, durable=True)
                self._channel.basic_consume(
                    queue=self._queue,
                    on_message_callback=self._wrap(callback),
                    auto_ack=False,
                )
                self._channel.start_consuming()
            except TRANSIENT_ERRORS as e:
                if self._stopping:
                    break
                print(f"[rabbit] connection lost on {self._queue} ({e!r}); reconnecting", flush=True)
                self._connect()

        try:
            self._connection.close()
        except Exception:  # noqa: BLE001 - best effort on shutdown
            pass
        raise SystemExit(0)

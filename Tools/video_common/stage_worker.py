"""PictuRAS video stage worker (RabbitMQ), shared by the video tools.

Each video tool (Tools/video_effects, Tools/video_subtitles, Tools/video_frames)
starts this worker for its own stage; the stage fixes the queue it consumes
(video_<stage>_queue) and therefore what it can be scaled for independently.

Each message carries one stage of a video pipeline, planned by the projects
orchestrator (projects/utils/videoStages.js). The worker runs it, reports
progress to the WebSocket gateway (ws_queue) mapped onto the whole pipeline,
and replies on project_queue; the orchestrator then dispatches the next stage.

As before, the message is acknowledged only after the reply is sent: if the
worker dies midway, RabbitMQ redelivers it. One job at a time per replica.
"""
import datetime
import json
import time
import uuid

import pika
import pytz
from pika.exchange_type import ExchangeType

import utils.env as env
from pipeline import STAGE_KINDS, overall_percent, run_stage

EXCHANGE = "picturas"
PROJECT_QUEUE = "project_queue"
WS_QUEUE = "ws_queue"

CODES = {
    "wrong_procedure": 2000,
    "error_processing": 2001,
    "unsupported_effect": 2002,
    "invalid_trim": 2003,
    "invalid_video": 2004,
    "invalid_speed": 2005,
}
# Matched by name: each service only contains the modules of its own stage.
ERROR_CODES = {
    "UnsupportedEffect": CODES["unsupported_effect"],
    "InvalidTrim": CODES["invalid_trim"],
    "InvalidVideo": CODES["invalid_video"],
    "InvalidSpeed": CODES["invalid_speed"],
}


def now():
    return datetime.datetime.now(pytz.utc)


class StageWorker:
    def __init__(self, stage):
        if stage not in STAGE_KINDS:
            raise ValueError(f"Unknown video stage '{stage}'")
        self.stage = stage
        self.queue = f"video_{stage}_queue"
        self.procedure = f"video_{stage}"
        self.microservice = f"picturas-video-{stage}-ms"
        self._connection = self._connect()
        self._channel = self._connection.channel()
        self._channel.exchange_declare(exchange=EXCHANGE,
                                       exchange_type=ExchangeType.direct, durable=True)
        self._channel.queue_declare(queue=self.queue, durable=True)
        self._channel.queue_bind(queue=self.queue, exchange=EXCHANGE, routing_key=self.queue)
        # one job at a time per replica; parallelism comes from replicas
        self._channel.basic_qos(prefetch_count=1)
        # replies wait for the broker's confirmation before the job is acknowledged
        self._channel.confirm_delivery()

    @staticmethod
    def _connect():
        credentials = pika.PlainCredentials(env.RABBITMQ_USERNAME, env.RABBITMQ_PASSWORD)
        params = pika.ConnectionParameters(
            env.RABBITMQ_HOST, int(env.RABBITMQ_PORT), "/", credentials,
            # a stage blocks this thread for minutes; without a heartbeat the
            # broker does not drop the connection midway
            heartbeat=0,
        )
        for _ in range(30):
            try:
                return pika.BlockingConnection(params)
            except pika.exceptions.AMQPConnectionError:
                time.sleep(2)
        raise RuntimeError("Could not connect to RabbitMQ")

    def _publish(self, queue, msg):
        # persistent: a reply survives a broker restart (the queues are durable)
        self._channel.basic_publish(exchange=EXCHANGE, routing_key=queue, body=json.dumps(msg),
                                    properties=pika.BasicProperties(delivery_mode=pika.DeliveryMode.Persistent))

    def _reply_success(self, msg_id, started, output_uri, video_info):
        output = {"type": video_info.get("output_type", "video"),
                  "imageURI": video_info.get("output_path", output_uri)}
        if output["type"] == "frames":
            output["frames"] = video_info["frames"]
        self._publish(PROJECT_QUEUE, {
            "messageId": f"video-{uuid.uuid4()}",
            "correlationId": msg_id,
            "timestamp": now().isoformat(),
            "status": "success",
            "output": output,
            "metadata": {
                "processingTime": (now() - started).total_seconds() * 1000,
                "microservice": self.microservice,
                "video": video_info,
            },
        })

    def _reply_error(self, msg_id, started, code, message, input_uri):
        self._publish(PROJECT_QUEUE, {
            "messageId": f"video-{uuid.uuid4()}",
            "correlationId": msg_id,
            "timestamp": now().isoformat(),
            "status": "error",
            "error": {
                "code": code,
                "message": message,
                "msg": message,  # the orchestrator reads error.msg
                "details": {"inputFileURI": input_uri},
            },
            "metadata": {
                "processingTime": (now() - started).total_seconds() * 1000,
                "microservice": self.microservice,
            },
        })

    def _progress(self, progress, preview, percent):
        if not progress or not progress.get("user"):
            return
        self._publish(WS_QUEUE, {
            "messageId": f"update-client-video-progress-{uuid.uuid4()}",
            "timestamp": now().isoformat(),
            "status": "success",
            "user": progress["user"],
            "projectId": progress.get("projectId"),
            "imgId": progress.get("imgId"),
            "preview": bool(preview),
            "percent": percent,
        })

    def callback(self, ch, method, properties, body):
        started = now()
        try:
            info = json.loads(body.decode())
            msg_id = info["messageId"]
            params = info["parameters"]
            input_uri = params["inputImageURI"]
            output_uri = params["outputImageURI"]
            stage = params["stage"]
            last = bool(params.get("last"))
            preview = bool(params.get("preview"))
            progress = params.get("progress") or {}
        except (ValueError, KeyError, TypeError) as e:
            print(f"[{self.procedure}] invalid message discarded: {e}", flush=True)
            ch.basic_ack(delivery_tag=method.delivery_tag)
            return

        print(f"[{self.procedure}] msg={msg_id} preview={preview} stage={stage.get('kind')} "
              f"tools={[t.get('procedure') for t in stage.get('tools') or []]}", flush=True)

        if info.get("procedure") != self.procedure or stage.get("kind") != self.stage:
            self._reply_error(msg_id, started, CODES["wrong_procedure"],
                              "The procedure received does not fit into this tool", input_uri)
        else:
            try:
                result = run_stage(
                    stage, input_uri, output_uri,
                    lambda pct: self._progress(progress, preview, overall_percent(stage, pct, last)),
                )
                self._reply_success(msg_id, started, output_uri, result)
                print(f"[{self.procedure}] msg={msg_id} ok t={(now() - started).total_seconds():.1f}s", flush=True)
            except Exception as e:  # noqa: BLE001 - every failure is reported
                code = ERROR_CODES.get(type(e).__name__, CODES["error_processing"])
                self._reply_error(msg_id, started, code, str(e), input_uri)

        # manual ack only at the end
        ch.basic_ack(delivery_tag=method.delivery_tag)

    def run(self):
        self._channel.basic_consume(queue=self.queue, on_message_callback=self.callback, auto_ack=False)
        print(f"[{self.procedure}] waiting for jobs on {self.queue}", flush=True)
        self._channel.start_consuming()


def main(stage):
    StageWorker(stage).run()

# NFR benchmarks

Scripts used to measure the two Phase 2 non-functional requirements before the refactoring
(baseline) and after it (final). Both runs use the same scripts, scenarios and machine.

| NFR | ISO/IEC 25010:2011 | Script | Scenarios |
| --- | --- | --- | --- |
| Elasticity | Performance efficiency › capacity, resource utilisation | `elasticity.py` | E1, E2, E3 |
| Recovery | Reliability › recoverability, fault tolerance | `chaos.py` | R1, R2, R3 |

The scripts are black-box. They use only the public API (`/api-gateway/`) and Socket.IO
(`/socket.io`) through nginx, plus the Docker CLI to read resource usage and inject faults.
They import no service code, so the system can be refactored freely between the two runs.

## Setup

Host requirements: Python 3.10+, ffmpeg (used only to generate the test images), Docker
with Compose, and the stack running at `https://localhost:8080`.

```bash
# 1. Clean stack on the commit under test (wipes all data volumes)
docker compose down -v --remove-orphans
docker compose up -d --build

# 2. Python environment
cd bench
python -m venv .venv
.venv/Scripts/pip install -r requirements.txt    # Linux/macOS: .venv/bin/pip
.venv/Scripts/python prepare_samples.py          # 12 test images in bench/data/
```

On Docker 29+, `docker compose up --build` builds through `buildx bake` and can stop with
`additional privileges requested: pass "--allow=fs.read=..."` (the Tools images use
`context: ./Tools` with a Dockerfile in a subfolder). `COMPOSE_BAKE=false` does not avoid it on
Compose 2.40+. Record in the results how the images were built.

`--remove-orphans` is required. Containers left over from other branches (for example split
video workers) would otherwise consume messages from the same RabbitMQ queues and distort
the results.

Every job runs under a **new premium user**, registered with `type: "premium"` on
`POST /users/`, so the free plan's daily operation limit never cuts a run short. Each job also
gets its own user so that `process-error` events, which carry no project id, can be
attributed to the right job.

## Running

Everything in sequence (about 2 hours; E1 and E2 together run fifteen subtitles jobs):

```bash
bash bench/run_all.sh baseline                 # RUNS=1 for a quick smoke run
tail -f bench/results/baseline/run.log         # progress: one START/END line per step, script output in between
```

Only one benchmark may run at a time. `run_all.sh` takes `bench/.run_all.lock` for the whole suite and each
script takes `bench/.bench.lock`; both refuse to start while another live run holds them, because two overlapping runs compete for the same workers and
invalidate each other's numbers.

Individual scenarios:

```bash
# Elasticity: E1 + E2 + E3, 5 runs each (plus one discarded warm-up subtitles job)
.venv/Scripts/python elasticity.py --label baseline --runs 5

# Recovery: control run first, then one file per fault target
.venv/Scripts/python chaos.py --label baseline --target none       --runs 5
.venv/Scripts/python chaos.py --label baseline --target image-tool --runs 5
.venv/Scripts/python chaos.py --label baseline --target video      --runs 5
.venv/Scripts/python chaos.py --label baseline --target projects   --runs 5

# Summary table
.venv/Scripts/python summarize.py baseline           # results/baseline/summary.csv
.venv/Scripts/python summarize.py baseline final     # results/comparison.csv
```

Raw results go to `results/<label>/<scenario>.json`. Each file records the commit, the
machine/Docker info, the parameters, every run's per-job timestamps and the summary.

After the video worker is split, kill the new workers with `--services`, for example:
`chaos.py --target video --services video_effects_tool,video_subtitles_tool,video_frames_tool`.

## Method

### Timestamps

| Name | Meaning |
| --- | --- |
| `submitted` | just before `POST /:user/:project/process` |
| `first_progress` | first non-preview `video-progress` event for the project. The worker sends it after about 2% of the frames, so it marks "started running" (an upper bound of the dequeue time, off by under 1 s for the short clips) |
| `finished` | first 1 s poll in which `GET /:user/:project/process/url` lists the expected number of results. The orchestrator exposes results only after it commits the whole run |
| error | a `process-error` Socket.IO event for the job's user |

`wait = first_progress − submitted` and `total = finished − submitted`. Since `finished` is
polled once per second, totals have 1 s resolution.

### Elasticity

- **E1, head-of-line blocking.** A subtitles job on `data/speech_60s.webm` is
  submitted first.
  The clip is the first 60 s of the speech sample (`prepare_samples.py`, stream copy): with the full
  177 s a subtitles job takes about 7 minutes on the test machine and the suite 4–5 hours. A light job (brightness 1.3 on `sample_10s_720p.mp4`) follows
  `--light-delay` (5 s) later. Metric: the light job's wait (p50/p95 over runs) and its total.
- **E2, burst.** `--burst` (10) jobs, each from its own user, released at the same instant
  by a thread barrier. They cycle through subtitles, light, effects (brightness → contrast →
  saturation), speed (1.5× on `sample_6s.mov`) and frames (6 JPEGs from the 10 s clip).
  Metrics: makespan (first submit → last finish), and per-job latency and wait p50/p95.
- **E3, resource utilisation.** `docker stats` of all compose containers taken `--settle`
  (60 s) before the bursts, sampled continuously during them, and again 60 s after. Metrics:
  idle memory and running-container count before and after, and peak total CPU/memory per
  burst.

A discarded warm-up subtitles job runs first, so the Whisper model download and first load
do not count against E1.

### Recovery

Each run prepares 3 image projects (4 images each, chain brightness → contrast →
saturation) and 2 video projects (the same chain on the 10 s clip), submits all 5 at once,
and then:

1. injects the fault (see below);
2. waits `--downtime` (5 s) and runs `docker compose start <service>`, standing in for the
   restart that an orchestrator or `restart: on-failure` would perform;
3. waits for every job, up to `--timeout` (180 s).

Fault modes (`--fault`):

- **`pause-kill`** (default): `docker compose pause` as soon as the batch is dispatched, then a
  `--hold` (10 s) wait, then `docker compose kill` (SIGKILL). While the service is frozen, the
  broker keeps delivering messages to its open consumer, so work accumulates in flight inside a
  process that then crashes. This is the window where unacknowledged work is lost or recovered.
  A timed kill would hit it only by chance: in a smoke run, a kill 3 s after submit landed before
  any message had reached `contrast_tool`, and every job simply waited and completed.
- **`kill`**: plain SIGKILL `--kill-after` seconds after submit. Kept for comparison.

| Metric | Definition |
| --- | --- |
| R1 | % of jobs that reach a correct terminal state: done, or an error that reaches the user. A job still pending at the timeout is **hung** |
| R2 | last terminal state minus the restart instant; undefined if any job hung |
| R3 | `Process` documents left in MongoDB for the batch's projects after the wait |

`--target none` is the control run. It must reach 100% and 0 orphans, otherwise the harness
itself is broken.

### Statistics

p50/p95 use the nearest-rank method over all samples, implemented in `common.percentile`.
With 5 runs, p95 equals the maximum. This is stated deliberately rather than presented as
a tail estimate.

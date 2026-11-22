"""Fault-injection benchmark (NFR 2: Reliability - recoverability / fault tolerance).

Each run submits a mixed batch, kills one service while the batch is in flight,
starts it again after --downtime seconds, and waits for every job.

  --target none        control run, no fault (validates the harness)
  --target image-tool  kills contrast_tool (middle step of the image chain)
  --target video       kills the video worker(s)
  --target projects    kills the orchestrator

Metrics per run:
  R1  % of jobs that reach a correct terminal state: done, or an error that reaches
      the user (`process-error`). Jobs still pending at --timeout count as hung.
  R2  recovery time: last terminal state minus the moment the service was restarted
      (only defined when no job hung).
  R3  orphan `Process` records left in MongoDB for the batch after the wait.

Usage:
  python chaos.py --label baseline --target image-tool --runs 5
"""
from __future__ import annotations

import argparse
import time
from concurrent.futures import ThreadPoolExecutor

from client import DEFAULT_BASE, BenchProject, BenchUser
from common import SHORT_VIDEO, compose, environment, single_instance, summary, write_result
from prepare_samples import image_paths

TARGETS = {
    "none": [],
    "image-tool": ["contrast_tool"],
    "video": ["video_tool"],
    "projects": ["projects"],
}
IMAGE_CHAIN = [
    ("brightness", {"brightness": 1.2}),
    ("contrast", {"contrastFactor": 1.3}),
    ("saturation", {"saturationFactor": 1.4}),
]


def prepare_images(base: str, n_images: int) -> tuple[BenchProject, int]:
    p = BenchUser(base).create_project("chaos-images")
    for path in image_paths(n_images):
        p.upload(path)
    for proc, params in IMAGE_CHAIN:
        p.add_tool(proc, params)
    return p, n_images


def prepare_video(base: str) -> tuple[BenchProject, int]:
    p = BenchUser(base).create_project("chaos-video")
    p.upload(SHORT_VIDEO)
    for proc, params in IMAGE_CHAIN:
        p.add_tool(proc, params)
    return p, 1


def orphan_processes(project_ids: list[str]) -> int | None:
    ids = ",".join(f"ObjectId('{pid}')" for pid in project_ids)
    out = compose("exec", "-T", "projects_mongoDB", "mongo", "--port", "27018", "project", "--quiet",
                  "--eval", f"db.processes.countDocuments({{project_id: {{$in: [{ids}]}}}})", check=False)
    try:
        return int(out.strip().splitlines()[-1])
    except (ValueError, IndexError):
        return None


def run_once(args, services: list[str]) -> dict:
    jobs = []
    with ThreadPoolExecutor(8) as ex:
        futs = [ex.submit(prepare_images, args.base, args.images) for _ in range(args.image_projects)]
        futs += [ex.submit(prepare_video, args.base) for _ in range(args.video_projects)]
        for f, kind in zip(futs, ["image"] * args.image_projects + ["video"] * args.video_projects):
            p, n = f.result()
            jobs.append((kind, p, n))

    with ThreadPoolExecutor(len(jobs)) as ex:
        list(ex.map(lambda j: j[1].process(), jobs))

    t_kill = t_restart = None
    if services:
        if args.fault == "pause-kill":
            # Freeze the service as soon as the batch is dispatched. The broker keeps
            # delivering to its open consumer, so work accumulates "in flight" inside a
            # process that then crashes: the window a timed kill would hit by chance.
            compose("pause", *services)
            time.sleep(args.hold)
            t_kill = time.time()
            compose("kill", *services)
            compose("unpause", *services, check=False)  # a killed container may stay paused
        else:
            time.sleep(args.kill_after)
            t_kill = time.time()
            compose("kill", *services)
        time.sleep(args.downtime)
        compose("start", *services)
        t_restart = time.time()

    with ThreadPoolExecutor(len(jobs)) as ex:
        outcomes = list(ex.map(lambda j: j[1].wait(j[2], args.timeout), jobs))

    records = [{
        "kind": kind, "project_id": p.project_id, "expected": n, "status": o.status,
        "results": o.results, "submitted": o.submitted, "finished": o.finished,
        "total_s": o.total_s, "error": o.error,
    } for (kind, p, n), o in zip(jobs, outcomes)]
    for _, p, _ in jobs:
        p.user.close()

    total = len(records)
    done = sum(r["status"] == "done" for r in records)
    errored = sum(r["status"] == "error" for r in records)
    hung = sum(r["status"] == "timeout" for r in records)
    recovery = None
    if hung == 0 and t_restart is not None:
        recovery = max(r["finished"] for r in records) - t_restart

    return {
        "t_kill": t_kill, "t_restart": t_restart, "jobs": records,
        "done": done, "errored": errored, "hung": hung, "total": total,
        "r1_terminal_pct": 100.0 * (done + errored) / total,
        "r1_done_pct": 100.0 * done / total,
        "r2_recovery_s": recovery,
        "r3_orphan_processes": orphan_processes([r["project_id"] for r in records]),
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base", default=DEFAULT_BASE)
    ap.add_argument("--label", default="baseline")
    ap.add_argument("--target", choices=sorted(TARGETS), default="image-tool")
    ap.add_argument("--services", default="", help="override the services to kill (comma separated)")
    ap.add_argument("--runs", type=int, default=5)
    ap.add_argument("--image-projects", type=int, default=3)
    ap.add_argument("--images", type=int, default=4, help="images per image project")
    ap.add_argument("--video-projects", type=int, default=2)
    ap.add_argument("--fault", choices=["pause-kill", "kill"], default="pause-kill",
                    help="pause-kill: freeze at dispatch, hold, then SIGKILL; kill: SIGKILL after --kill-after")
    ap.add_argument("--hold", type=float, default=10.0, help="pause-kill: seconds frozen before the kill")
    ap.add_argument("--kill-after", type=float, default=3.0, help="kill: seconds after submit")
    ap.add_argument("--downtime", type=float, default=5.0, help="seconds the service stays down")
    ap.add_argument("--timeout", type=float, default=180.0, help="per-job timeout; later = hung")
    args = ap.parse_args()

    services = [s for s in args.services.split(",") if s] or TARGETS[args.target]
    single_instance()
    env = environment()
    print(f"commit {env['git_commit'][:8]}  target={args.target} services={services}")

    runs = []
    for i in range(args.runs):
        r = run_once(args, services)
        print(f"run {i + 1}: done={r['done']} error={r['errored']} hung={r['hung']} / {r['total']}  "
              f"recovery={r['r2_recovery_s']}  orphans={r['r3_orphan_processes']}")
        runs.append(r)

    payload = {
        "scenario": f"chaos-{args.target}", "env": env, "params": vars(args), "services": services,
        "runs": runs,
        "summary": {
            "r1_terminal_pct": summary([r["r1_terminal_pct"] for r in runs]),
            "r1_done_pct": summary([r["r1_done_pct"] for r in runs]),
            "r2_recovery_s": summary([r["r2_recovery_s"] for r in runs]),
            "r3_orphan_processes": summary([r["r3_orphan_processes"] for r in runs]),
            "hung_jobs_total": sum(r["hung"] for r in runs),
        },
    }
    print(f"  -> {write_result(args.label, f'chaos-{args.target}', payload)}")


if __name__ == "__main__":
    main()

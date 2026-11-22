"""Elasticity benchmark (NFR 1: Performance efficiency - capacity / resource utilisation).

Scenarios (see bench/README.md for the full method):
  E1  head-of-line blocking: a subtitles job on the first 60 s of the speech video, then a light
      video job (brightness on a 10 s clip) submitted --light-delay seconds later.
      Metric: how long the light job waits before it starts running, and its total time.
  E2  burst: --burst mixed video jobs (subtitles, effects, speed, frame extraction)
      submitted at the same time by different premium users.
      Metric: makespan and per-job latency p50/p95.
  E3  resource utilisation: docker stats when idle before the load, peak during E2,
      and idle again --settle seconds after the burst.

Usage:
  python elasticity.py --label baseline --runs 5
"""
from __future__ import annotations

import argparse
import threading
import time
from concurrent.futures import ThreadPoolExecutor

from client import DEFAULT_BASE, BenchProject, BenchUser
from common import (MOV_VIDEO, SHORT_VIDEO, SPEECH_VIDEO, StatsSampler, compose, docker_stats, single_instance,
                    environment, summary, write_result)

BURST_MIX = ["subtitles", "light", "effects", "speed", "frames"]


def prepare(kind: str, base: str) -> tuple[BenchProject, int]:
    """Create a user + project ready to run one job of the given kind.

    Returns the project and the number of results that mark it as done.
    """
    user = BenchUser(base)
    p = user.create_project(f"bench-{kind}")
    if kind == "subtitles":
        p.upload(SPEECH_VIDEO)
        p.add_tool("subtitles", {})
        return p, 1
    if kind == "light":
        p.upload(SHORT_VIDEO)
        p.add_tool("brightness", {"brightness": 1.3})
        return p, 1
    if kind == "effects":
        p.upload(SHORT_VIDEO)
        p.add_tool("brightness", {"brightness": 1.2})
        p.add_tool("contrast", {"contrastFactor": 1.3})
        p.add_tool("saturation", {"saturationFactor": 1.4})
        return p, 1
    if kind == "speed":
        p.upload(MOV_VIDEO)
        p.add_tool("speed", {"factor": 1.5, "imgId": p.media_id(0)})
        return p, 1
    if kind == "frames":
        p.upload(SHORT_VIDEO)
        p.add_tool("extract_frames", {"mode": "count", "count": 6, "format": "jpeg"})
        return p, 6
    raise ValueError(kind)


def record(kind: str, p: BenchProject, outcome) -> dict:
    return {
        "kind": kind,
        "status": outcome.status,
        "submitted": outcome.submitted,
        "first_progress": outcome.first_progress,
        "finished": outcome.finished,
        "wait_s": outcome.wait_s,
        "total_s": outcome.total_s,
        "results": outcome.results,
        "error": outcome.error,
    }


def run_e1(base: str, light_delay: float, timeout: float) -> dict:
    heavy, heavy_n = prepare("subtitles", base)
    light, light_n = prepare("light", base)
    heavy.process()
    time.sleep(light_delay)
    light.process()
    with ThreadPoolExecutor(2) as ex:
        fh = ex.submit(heavy.wait, heavy_n, timeout)
        fl = ex.submit(light.wait, light_n, timeout)
        h, l = fh.result(), fl.result()
    for p in (heavy, light):
        p.user.close()
    return {"heavy": record("subtitles", heavy, h), "light": record("light", light, l)}


def run_e2(base: str, burst: int, timeout: float) -> dict:
    kinds = [BURST_MIX[i % len(BURST_MIX)] for i in range(burst)]
    with ThreadPoolExecutor(min(burst, 8)) as ex:
        prepared = list(ex.map(lambda k: prepare(k, base), kinds))

    gate = threading.Barrier(len(prepared))

    def go(item):
        p, n = item
        gate.wait()
        p.process()
        return p.wait(n, timeout)

    with StatsSampler() as sampler, ThreadPoolExecutor(len(prepared)) as ex:
        outcomes = list(ex.map(go, prepared))

    jobs = [record(k, p, o) for k, (p, _), o in zip(kinds, prepared, outcomes)]
    for p, _ in prepared:
        p.user.close()
    first_submit = min(j["submitted"] for j in jobs)
    finished = [j["finished"] for j in jobs if j["finished"] is not None]
    makespan = (max(finished) - first_submit) if len(finished) == len(jobs) else None
    return {"jobs": jobs, "makespan_s": makespan, "peak": sampler.peak()}


def idle_snapshot() -> dict:
    rows = docker_stats()
    return {
        "containers": rows,
        "running_containers": len(rows),
        "total_cpu_pct": sum(r["cpu_pct"] or 0 for r in rows),
        "total_mem_mib": sum(r["mem_mib"] or 0 for r in rows),
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base", default=DEFAULT_BASE)
    ap.add_argument("--label", default="baseline", help="results sub-folder (baseline, final, ...)")
    ap.add_argument("--runs", type=int, default=5)
    ap.add_argument("--scenarios", default="E1,E2,E3")
    ap.add_argument("--light-delay", type=float, default=5.0)
    ap.add_argument("--burst", type=int, default=10)
    ap.add_argument("--timeout", type=float, default=1800.0, help="per-job timeout in seconds")
    ap.add_argument("--settle", type=float, default=60.0, help="idle wait before/after load, seconds")
    ap.add_argument("--no-warmup", action="store_true", help="skip the discarded warm-up subtitles job")
    args = ap.parse_args()
    scenarios = {s.strip().upper() for s in args.scenarios.split(",")}
    single_instance()

    env = environment()
    env["services"] = compose("ps", "--format", "{{.Service}}").split()
    print(f"commit {env['git_commit'][:8]}  services={len(env['services'])}")

    if not args.no_warmup:
        print("warm-up: one subtitles job (loads the Whisper model; discarded)")
        p, n = prepare("subtitles", args.base)
        p.process()
        print(f"  warm-up {p.wait(n, args.timeout).status}")
        p.user.close()

    if "E1" in scenarios:
        runs = []
        for i in range(args.runs):
            r = run_e1(args.base, args.light_delay, args.timeout)
            print(f"E1 run {i + 1}: light wait={r['light']['wait_s']} total={r['light']['total_s']} "
                  f"heavy total={r['heavy']['total_s']}")
            runs.append(r)
        payload = {
            "scenario": "E1", "env": env, "params": vars(args), "runs": runs,
            "summary": {
                "light_wait_s": summary([r["light"]["wait_s"] for r in runs]),
                "light_total_s": summary([r["light"]["total_s"] for r in runs]),
                "heavy_total_s": summary([r["heavy"]["total_s"] for r in runs]),
                "light_status": [r["light"]["status"] for r in runs],
            },
        }
        print(f"  -> {write_result(args.label, 'E1', payload)}")

    if "E2" in scenarios or "E3" in scenarios:
        time.sleep(args.settle)
        idle_before = idle_snapshot()
        runs = []
        for i in range(args.runs):
            r = run_e2(args.base, args.burst, args.timeout)
            print(f"E2 run {i + 1}: makespan={r['makespan_s']} "
                  f"statuses={[j['status'] for j in r['jobs']]}")
            runs.append(r)
        time.sleep(args.settle)
        idle_after = idle_snapshot()

        if "E2" in scenarios:
            payload = {
                "scenario": "E2", "env": env, "params": vars(args),
                "runs": [{k: v for k, v in r.items() if k != "peak"} for r in runs],
                "summary": {
                    "makespan_s": summary([r["makespan_s"] for r in runs]),
                    "job_total_s": summary([j["total_s"] for r in runs for j in r["jobs"]]),
                    "job_wait_s": summary([j["wait_s"] for r in runs for j in r["jobs"]]),
                    "by_kind_total_s": {
                        k: summary([j["total_s"] for r in runs for j in r["jobs"] if j["kind"] == k])
                        for k in BURST_MIX
                    },
                },
            }
            print(f"  -> {write_result(args.label, 'E2', payload)}")
        if "E3" in scenarios:
            payload = {
                "scenario": "E3", "env": env, "params": vars(args),
                "idle_before": idle_before, "idle_after": idle_after,
                "peak_per_run": [r["peak"] for r in runs],
                "summary": {
                    "idle_before_mem_mib": idle_before["total_mem_mib"],
                    "idle_after_mem_mib": idle_after["total_mem_mib"],
                    "idle_before_containers": idle_before["running_containers"],
                    "idle_after_containers": idle_after["running_containers"],
                    "peak_total_cpu_pct": summary([r["peak"]["total"]["cpu_pct"] for r in runs]),
                    "peak_total_mem_mib": summary([r["peak"]["total"]["mem_mib"] for r in runs]),
                },
            }
            print(f"  -> {write_result(args.label, 'E3', payload)}")


if __name__ == "__main__":
    main()

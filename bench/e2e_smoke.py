"""End-to-end smoke test of the video paths against a running stack.

Covers the cases the stage split touches: single-stage and multi-stage videos,
subtitles (real speech recognition), frame extraction, a mixed image + video
project, and a multi-stage video preview. For each job it checks completion,
the number of results, the number of `process-update` events (the frontend
counts exactly one per video and one per image step) and, for videos, the
output's duration and audio stream with ffprobe.

Usage: python e2e_smoke.py [--label split]   (writes results/<label>/e2e-smoke.json)
"""
from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
import time
from pathlib import Path

from client import DEFAULT_BASE, BenchUser
from common import SHORT_VIDEO, SPEECH_VIDEO, environment, single_instance, write_result
from prepare_samples import image_paths

B = ("brightness", {"brightness": 1.3})
C = ("contrast", {"contrastFactor": 1.3})
S = ("subtitles", {})
X = ("extract_frames", {"mode": "count", "count": 4, "format": "png"})


def ffprobe_url(session, url):
    with tempfile.TemporaryDirectory() as d:
        path = Path(d) / "out.mp4"
        path.write_bytes(session.get(url, timeout=300).content)
        out = subprocess.run(["ffprobe", "-v", "error", "-print_format", "json", "-show_format", "-show_streams",
                              str(path)], capture_output=True, text=True)
        data = json.loads(out.stdout or "{}")
        streams = data.get("streams", [])
        return {
            "duration": round(float(data.get("format", {}).get("duration", 0)), 2),
            "video_codec": next((s["codec_name"] for s in streams if s["codec_type"] == "video"), None),
            "has_audio": any(s["codec_type"] == "audio" for s in streams),
        }


def run_job(base, name, media, tools, expected_results, expected_updates, expect):
    user = BenchUser(base)
    try:
        p = user.create_project(f"e2e-{name}")
        for m in media:
            p.upload(m)
        for proc, params in tools:
            p.add_tool(proc, params)
        p.process()
        outcome = p.wait(expected_results, timeout_s=1200)
        time.sleep(2)  # late events would show up as extra process-update notifications
        updates = len(user.events_since(outcome.submitted, "process-update"))
        rec = {"name": name, "status": outcome.status, "results": outcome.results, "total_s": outcome.total_s,
               "process_updates": updates, "expected_updates": expected_updates, "error": outcome.error}
        checks = [outcome.status == "done", outcome.results == expected_results, updates == expected_updates]
        if expect and outcome.status == "done":
            videos = [r for r in p.results()["imgs"] if r.get("type") == "video"]
            rec["video"] = [ffprobe_url(user.http, v["url"]) for v in videos]
            for v in rec["video"]:
                checks += [v["video_codec"] == "h264", abs(v["duration"] - expect["duration"]) < 1.0,
                           v["has_audio"] == expect["audio"]]
        rec["ok"] = all(checks)
        return rec
    finally:
        user.close()


def run_preview(base, name, media, tools):
    user = BenchUser(base)
    try:
        p = user.create_project(f"e2e-{name}")
        p.upload(media)
        for proc, params in tools:
            p.add_tool(proc, params)
        res = p.preview(0)
        urls = res.get("urls") or {}
        rec = {"name": name, **res}
        rec["ok"] = res["status"] == "done" and bool(urls.get("imageUrl")) and urls.get("mediaType") == "video"
        if rec["ok"]:
            rec["video"] = [ffprobe_url(user.http, urls["imageUrl"])]
            rec["ok"] = rec["video"][0]["duration"] <= 3.5  # preview renders the first 3 s
        return rec
    finally:
        user.close()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base", default=DEFAULT_BASE)
    ap.add_argument("--label", default="split")
    args = ap.parse_args()
    single_instance()
    imgs = image_paths(2)
    jobs = [
        ("video-effects", [SHORT_VIDEO], [B, C], 1, 1, {"duration": 10.0, "audio": True}),
        ("video-effects-subtitles-effects", [SPEECH_VIDEO], [B, S, C], 1, 1, {"duration": 60.0, "audio": True}),
        ("video-effects-then-frames", [SHORT_VIDEO], [B, X], 4, 1, None),
        # 2 images x 2 image tools = 4 steps, plus 1 per video
        ("mixed-images-and-video", [*imgs, SHORT_VIDEO], [B, C], 3, 5, {"duration": 10.0, "audio": True}),
    ]
    # One case at a time: this checks behaviour, not load (concurrent uploads right
    # after a cold start can exceed nginx's 60 s proxy timeout, unrelated to video).
    records = [run_job(args.base, *j) for j in jobs]
    records.append(run_preview(args.base, "video-preview-3-stages", SHORT_VIDEO, [B, S, C]))
    for r in records:
        print(f"{'OK  ' if r['ok'] else 'FAIL'} {r['name']:34s} status={r['status']} "
              f"results={r.get('results', '-')} updates={r.get('process_updates', '-')}/{r.get('expected_updates', '-')} "
              f"video={r.get('video')}")
    passed = sum(r["ok"] for r in records)
    print(f"{passed}/{len(records)} passed")
    write_result(args.label, "e2e-smoke", {"env": environment(), "records": records, "passed": passed})
    raise SystemExit(0 if passed == len(records) else 1)


if __name__ == "__main__":
    main()

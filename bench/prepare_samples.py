"""Generate the test images used by the benchmarks (deterministic, from a repo sample).

Extracts evenly spaced 1280x720 JPEG frames from samples/video/sample_10s_720p.mp4 into
bench/data/, and cuts the first 60 s of the speech sample (stream copy) for the subtitles jobs. Needs ffmpeg on the PATH. Safe to re-run.
"""
from __future__ import annotations

import argparse
import subprocess

from common import DATA, SHORT_VIDEO, SPEECH_SOURCE, SPEECH_VIDEO


def image_paths(n: int) -> list:
    return [DATA / f"img_{i:02d}.jpg" for i in range(n)]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--count", type=int, default=12)
    args = ap.parse_args()

    DATA.mkdir(parents=True, exist_ok=True)
    for i, path in enumerate(image_paths(args.count)):
        if path.exists():
            continue
        t = 0.4 + i * (9.0 / args.count)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{t:.2f}", "-i", str(SHORT_VIDEO),
                        "-frames:v", "1", "-q:v", "3", str(path)], check=True)
    if not SPEECH_VIDEO.exists():
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(SPEECH_SOURCE), "-t", "60", "-c", "copy",
                        str(SPEECH_VIDEO)], check=True)
    print(f"{args.count} images and {SPEECH_VIDEO.name} ready in {DATA}")


if __name__ == "__main__":
    main()

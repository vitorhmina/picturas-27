"""Byte-for-byte comparison: the original single video worker vs the staged video tools.

Functional-preservation check for the split of Tools/video into video_effects,
video_subtitles and video_frames: the same pipelines, run through the original
process_video and through the stage plan, must produce identical files.

  git archive 0523102 Tools/video | tar -x -C /tmp/old
  python bench/video_equivalence.py /tmp/old/Tools/video Tools /tmp/eq

Needs ffmpeg and the test requirements (Tools/video_common/requirements-dev.txt).
Speech recognition is simulated in both, so no model is downloaded. Each
implementation runs in its own subprocess so their modules never mix.
"""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

OLD, NEW, WORK = map(Path, sys.argv[1:4])
B = {"procedure": "brightness", "params": {"brightness": 1.3}}
C = {"procedure": "contrast", "params": {"contrastFactor": 1.4}}
T = {"procedure": "trim", "params": {"start": 0.5, "end": 3.0}}
V = {"procedure": "speed", "params": {"factor": 1.5}}
S = {"procedure": "subtitles", "params": {}}
X = {"procedure": "extract_frames", "params": {"mode": "count", "count": 4, "format": "png"}}
CASES = {
    "effects": ([B, C], False),
    "trim_speed_effects": ([T, V, B], False),
    "effects_preview": ([B, C], True),
    "subtitles": ([S], False),
    "effects_subtitles_effects_preview": ([B, S, C], True),
    "subtitles_then_trim_preview": ([S, T], True),
    "extract_only": ([X], False),
    "effects_then_extract_preview": ([B, X], True),
    "subtitles_then_extract": ([S, X], False),
}

RUNNER = r'''
import json, sys
from types import SimpleNamespace
for p in reversed(sys.argv[3].split("|")):
    sys.path.insert(0, p)
import subtitles
class Seg(SimpleNamespace): pass
subtitles.speech_model = lambda: SimpleNamespace(transcribe=lambda *a, **k: (iter([
    Seg(start=0.2, end=1.4, text="Hello there"), Seg(start=1.6, end=3.2, text="General Kenobi")]), None))
from video_processor import process_video
tools, preview = json.loads(sys.argv[4])
res = process_video(sys.argv[1], sys.argv[2], tools, preview=preview)
print(json.dumps({"type": res.get("output_type", "video"), "path": res.get("output_path", sys.argv[2])}))
'''


def digest(result):
    p = Path(result["path"])
    if p.is_dir():  # frame manifest: hash every frame in order
        h = hashlib.sha256()
        for f in sorted(p.iterdir()):
            h.update(f.name.encode()); h.update(f.read_bytes())
        return h.hexdigest()
    return hashlib.sha256(p.read_bytes()).hexdigest()


def run(paths, name, tools, preview, src):
    out = WORK / name / "out.mp4"
    out.parent.mkdir(parents=True, exist_ok=True)
    r = subprocess.run([sys.executable, "-c", RUNNER, str(src), str(out), "|".join(map(str, paths)),
                        json.dumps([tools, preview])], capture_output=True, text=True)
    if r.returncode:
        raise SystemExit(f"{name} failed:\n{r.stderr[-1500:]}")
    return json.loads(r.stdout.strip().splitlines()[-1])


WORK.mkdir(parents=True, exist_ok=True)
src = WORK / "src.mp4"
subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i", "testsrc=size=320x240:rate=25:duration=4",
                "-f", "lavfi", "-i", "sine=frequency=440:duration=4", "-c:a", "aac", "-c:v", "libx264",
                "-pix_fmt", "yuv420p", "-shortest", str(src)], check=True)
old_paths = [OLD]
new_paths = [NEW / d for d in ("video_common", "video_effects", "video_subtitles", "video_frames")]
same = 0
for name, (tools, preview) in CASES.items():
    a = run(old_paths, f"old/{name}", tools, preview, src)
    b = run(new_paths, f"new/{name}", tools, preview, src)
    ok = a["type"] == b["type"] and digest(a) == digest(b)
    same += ok
    print(f"{'IDENTICAL' if ok else 'DIFFERENT'}  {name:38s} type={a['type']}/{b['type']}")
print(f"{same}/{len(CASES)} identical")

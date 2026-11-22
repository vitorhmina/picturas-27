"""A video pipeline split into stages, one stage per video service.

Stages follow the boundaries the single video worker already used, so the
number of encodes and the result stay the same:

  effects    contiguous ordinary effects (incl. trim/speed): one decode + one encode
  subtitles  speech recognition and burned-in captions
  frames     still-frame extraction (always terminal)

`plan_stages` is mirrored by projects/utils/videoStages.js, which dispatches the
stages to their queues; tests/stage_plans.json keeps both planners identical.
`run_plan` runs a plan locally in one process: it is what `process_video`
does, and what the tests exercise.
"""
import os
import tempfile
from pathlib import Path

from media import probe

STAGE_KINDS = ("effects", "subtitles", "frames")
# Share of the progress bar given to the edits before an extraction (as before: 70/30).
EDIT_SHARE_BEFORE_FRAMES = 70


def _edit_stages(tools, preview):
    if not any(t.get("procedure") == "subtitles" for t in tools):
        return [{"kind": "effects", "tools": list(tools), "preview": bool(preview)}]

    stages, pending = [], []
    for tool in tools:
        if tool.get("procedure") == "subtitles":
            # Normalize the first input to MP4/H.264 even when captioning is a no-op.
            if pending or not stages:
                stages.append({"kind": "effects", "tools": pending})
                pending = []
            stages.append({"kind": "subtitles"})
        else:
            pending.append(tool)
    if pending:
        stages.append({"kind": "effects", "tools": pending})

    # A preview is the first seconds of the final timeline. Cutting the initial
    # input before a later trim/speed would discard needed frames, so only the
    # last stage with a temporal edit is limited (the first one if there is none).
    preview_stage = max(
        (i for i, s in enumerate(stages)
         if s["kind"] == "effects" and any(t.get("procedure") in ("trim", "speed") for t in s["tools"])),
        default=0,
    )
    for i, stage in enumerate(stages):
        if stage["kind"] == "effects":
            stage["preview"] = bool(preview) and i == preview_stage
    return stages


def _share(stages, offset, span):
    each = span / len(stages)
    for i, stage in enumerate(stages):
        stage["progress"] = {"offset": offset + i * each, "span": each}
    return stages


def plan_stages(tools, preview=False):
    """Ordered stages for one video. `tools` must already be validated."""
    tools = list(tools or [])
    if tools and tools[-1].get("procedure") == "extract_frames":
        params = tools[-1].get("params") or {}
        prefix = tools[:-1]
        if not prefix:
            # Seek directly in the original: no transcode before extracting stills.
            frames = {"kind": "frames", "params": params, "preview": bool(preview), "original": True}
            return _share([frames], 0, 100)
        # Sampling spans the complete edited timeline, including in preview.
        edits = _share(_edit_stages(prefix, False), 0, EDIT_SHARE_BEFORE_FRAMES)
        frames = {"kind": "frames", "params": params, "preview": bool(preview), "original": False}
        return edits + _share([frames], EDIT_SHARE_BEFORE_FRAMES, 100 - EDIT_SHARE_BEFORE_FRAMES)
    return _share(_edit_stages(tools, preview), 0, 100)


def overall_percent(stage, percent, last):
    """Maps a stage's own 0-100 progress onto the whole pipeline."""
    if last and percent >= 100:
        return 100
    p = stage.get("progress") or {"offset": 0, "span": 100}
    return min(99, int(p["offset"] + percent * p["span"] / 100))


def run_stage(stage, input_path, output_path, progress=None):
    """Runs one stage. Video outputs are replaced atomically: on failure nothing
    is left at `output_path` and a previous file there is preserved."""
    report = progress or (lambda _: None)
    kind = stage["kind"]
    Path(output_path).resolve().parent.mkdir(parents=True, exist_ok=True)

    if kind == "effects":
        import video_processor  # looked up at call time so tests can replace it
        return video_processor._process_video(input_path, output_path, stage.get("tools") or [],
                                              report, preview=bool(stage.get("preview")))

    if kind == "subtitles":
        from subtitles import caption_video
        tmp = output_path + ".part.mp4"
        try:
            caption_video(input_path, tmp, probe(input_path), report)
            os.replace(tmp, output_path)
        except BaseException:
            if os.path.exists(tmp):
                os.remove(tmp)
            raise
        result = probe(output_path)
        result["frames"] = round(result["duration"] * result["fps"])
        return result

    if kind == "frames":
        from frame_extraction import extract_frames
        info = probe(input_path, prefer_video_duration=bool(stage.get("original")))
        return extract_frames(input_path, output_path, info, stage.get("params") or {},
                              report, preview=bool(stage.get("preview")))

    raise ValueError(f"Unknown video stage '{kind}'")


def run_plan(input_path, output_path, stages, progress_cb=None):
    """Runs every stage in one process. Intermediate files stay in a temporary
    directory until the whole pipeline succeeds."""
    def reporter(stage, last):
        return lambda pct: progress_cb(overall_percent(stage, pct, last)) if progress_cb else None

    if len(stages) == 1:
        return run_stage(stages[0], input_path, output_path, reporter(stages[0], True))

    target = Path(output_path).resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="stages-", dir=target.parent) as work:
        current, result = input_path, None
        for i, stage in enumerate(stages):
            last = i == len(stages) - 1
            if stage["kind"] == "frames":
                out = output_path  # extraction manages its own atomic destination
            else:
                out = str(Path(work) / f"stage-{i}.mp4")
            result = run_stage(stage, current, out, reporter(stage, last))
            current = out
        if stages[-1]["kind"] != "frames":
            result = probe(current)
            result["frames"] = round(result["duration"] * result["fps"])
            os.replace(current, target)
    if progress_cb:
        progress_cb(100)
    return result

"""The stage plan shared by the video services and the orchestrator."""
import json
from pathlib import Path

import pytest

from pipeline import overall_percent, plan_stages, run_stage

PLANS = json.loads((Path(__file__).parent / "stage_plans.json").read_text(encoding="utf-8"))


@pytest.mark.parametrize("case", PLANS, ids=[c["name"] for c in PLANS])
def test_plan_matches_shared_fixture(case):
    # projects/tests/video-stages.test.js checks the same file against the JS planner
    assert plan_stages(case["tools"], case["preview"]) == case["stages"]


def test_every_plan_covers_the_progress_bar_once():
    for case in PLANS:
        stages = case["stages"]
        assert stages[0]["progress"]["offset"] == 0
        for prev, cur in zip(stages, stages[1:]):
            assert cur["progress"]["offset"] == pytest.approx(prev["progress"]["offset"] + prev["progress"]["span"])
        last = stages[-1]["progress"]
        assert last["offset"] + last["span"] == pytest.approx(100)


def test_overall_percent_only_reaches_100_at_the_end():
    first, last = plan_stages([{"procedure": "subtitles", "params": {}}])
    assert overall_percent(first, 0, False) == 0
    assert overall_percent(first, 100, False) == 50
    assert overall_percent(last, 50, True) == 75
    assert overall_percent(last, 100, True) == 100


def test_plan_does_not_alias_the_input_tools():
    tools = [{"procedure": "brightness", "params": {"brightness": 1.2}}]
    stage = plan_stages(tools)[0]
    stage["tools"].append({"procedure": "contrast", "params": {}})
    assert len(tools) == 1


def test_unknown_stage_is_rejected(tmp_path):
    with pytest.raises(ValueError):
        run_stage({"kind": "nope"}, "in.mp4", str(tmp_path / "out.mp4"))


def test_subtitles_stage_failure_preserves_previous_output(sample_video, tmp_path, monkeypatch):
    import subtitles

    def broken(*_a, **_k):
        raise RuntimeError("recognizer down")

    monkeypatch.setattr(subtitles, "speech_model", lambda: type("M", (), {"transcribe": broken})())
    out = tmp_path / "out.mp4"
    out.write_bytes(b"previous")
    with pytest.raises(RuntimeError):
        run_stage({"kind": "subtitles"}, sample_video, str(out))
    assert out.read_bytes() == b"previous"
    assert not list(tmp_path.glob("*.part.mp4"))

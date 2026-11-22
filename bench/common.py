"""Shared helpers for the benchmark scripts: paths, statistics, Docker access."""
from __future__ import annotations

import json
import math
import platform
import subprocess
import threading
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BENCH = ROOT / "bench"
SAMPLES = ROOT / "samples" / "video"
DATA = BENCH / "data"  # generated test images (see prepare_samples.py), not committed
RESULTS = BENCH / "results"

# First 60 s of samples/video/speech_mandela_177s_1080p.webm (stream copy, see prepare_samples.py).
# The full 177 s clip makes one subtitles job take ~7 min on the test machine; 60 s keeps the
# heavy job several times longer than the light one while making the suite ~2 h instead of 4-5 h.
SPEECH_SOURCE = SAMPLES / "speech_mandela_177s_1080p.webm"
SPEECH_VIDEO = DATA / "speech_60s.webm"
SHORT_VIDEO = SAMPLES / "sample_10s_720p.mp4"
MOV_VIDEO = SAMPLES / "sample_6s.mov"


def percentile(values: list[float], p: float) -> float | None:
    """Nearest-rank percentile (p in 0..100). Documented in bench/README.md."""
    xs = sorted(v for v in values if v is not None)
    if not xs:
        return None
    rank = max(1, math.ceil(p / 100 * len(xs)))
    return xs[rank - 1]


def summary(values: list[float | None]) -> dict:
    xs = [v for v in values if v is not None]
    return {
        "n": len(values),
        "n_valid": len(xs),
        "min": min(xs) if xs else None,
        "p50": percentile(xs, 50),
        "p95": percentile(xs, 95),
        "max": max(xs) if xs else None,
        "mean": sum(xs) / len(xs) if xs else None,
    }


def git_commit() -> str:
    try:
        return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    except Exception:  # noqa: BLE001
        return "unknown"


def environment() -> dict:
    info = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "git_commit": git_commit(),
        "platform": platform.platform(),
        "python": platform.python_version(),
        "cpu_count": __import__("os").cpu_count(),
    }
    try:
        info["docker"] = json.loads(subprocess.check_output(
            ["docker", "info", "--format", "{{json .}}"], text=True, stderr=subprocess.DEVNULL))
        info["docker"] = {k: info["docker"].get(k) for k in ("ServerVersion", "NCPU", "MemTotal", "OperatingSystem")}
    except Exception:  # noqa: BLE001
        info["docker"] = None
    try:
        # Other containers on the host compete for CPU/RAM: record them so the
        # baseline and final runs can be checked for equal conditions.
        ours = set(compose("ps", "-q").split())
        rows = subprocess.check_output(["docker", "ps", "--no-trunc", "--format", "{{.ID}} {{.Names}}"], text=True)
        info["other_containers"] = [r.split(" ", 1)[1] for r in rows.splitlines()
                                    if r and r.split(" ", 1)[0] not in ours]
    except Exception:  # noqa: BLE001
        info["other_containers"] = None
    return info


def compose(*args: str, check: bool = True) -> str:
    out = subprocess.run(["docker", "compose", *args], cwd=ROOT, text=True, capture_output=True)
    if check and out.returncode != 0:
        raise RuntimeError(f"docker compose {' '.join(args)} failed: {out.stderr.strip()}")
    return out.stdout


def docker_stats() -> list[dict]:
    """One `docker stats` snapshot for the containers of the compose project."""
    ids = compose("ps", "-q").split()
    if not ids:
        return []
    out = subprocess.run(["docker", "stats", "--no-stream", "--format", "{{json .}}", *ids],
                         text=True, capture_output=True).stdout
    rows = []
    for line in out.splitlines():
        try:
            d = json.loads(line)
        except ValueError:
            continue
        rows.append({
            "name": d.get("Name"),
            "cpu_pct": _pct(d.get("CPUPerc")),
            "mem_mib": _mem_mib((d.get("MemUsage") or "").split("/")[0]),
        })
    return rows


def _pct(s: str | None) -> float | None:
    try:
        return float((s or "").strip().rstrip("%"))
    except ValueError:
        return None


def _mem_mib(s: str) -> float | None:
    s = s.strip()
    units = {"KiB": 1 / 1024, "MiB": 1, "GiB": 1024, "kB": 1 / 1024, "MB": 1, "GB": 1024, "B": 1 / 1024 ** 2}
    for unit, factor in units.items():
        if s.endswith(unit):
            try:
                return float(s[: -len(unit)]) * factor
            except ValueError:
                return None
    return None


class StatsSampler:
    """Samples `docker stats` in the background (each snapshot takes ~1-2 s)."""

    def __init__(self):
        self.samples: list[dict] = []
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._run, daemon=True)

    def _run(self):
        while not self._stop.is_set():
            self.samples.append({"t": time.time(), "containers": docker_stats()})

    def __enter__(self):
        self._thread.start()
        return self

    def __exit__(self, *exc):
        self._stop.set()
        self._thread.join(timeout=30)

    def peak(self) -> dict:
        """Peak CPU% and memory per container, plus the peak of the sums."""
        per: dict[str, dict] = {}
        peak_cpu_total = peak_mem_total = 0.0
        for s in self.samples:
            cpu_total = mem_total = 0.0
            for c in s["containers"]:
                p = per.setdefault(c["name"], {"cpu_pct": 0.0, "mem_mib": 0.0})
                p["cpu_pct"] = max(p["cpu_pct"], c["cpu_pct"] or 0.0)
                p["mem_mib"] = max(p["mem_mib"], c["mem_mib"] or 0.0)
                cpu_total += c["cpu_pct"] or 0.0
                mem_total += c["mem_mib"] or 0.0
            peak_cpu_total = max(peak_cpu_total, cpu_total)
            peak_mem_total = max(peak_mem_total, mem_total)
        return {"total": {"cpu_pct": peak_cpu_total, "mem_mib": peak_mem_total}, "containers": per}


LOCK = BENCH / ".bench.lock"


def single_instance():
    """Refuse to run while another benchmark process is alive.

    Two overlapping runs compete for the same workers and invalidate each other's
    numbers, so this is enforced rather than left to discipline.
    """
    import atexit
    import os

    if LOCK.exists():
        try:
            pid = int(LOCK.read_text().strip())
        except ValueError:
            pid = None
        if pid and pid != os.getpid() and _pid_alive(pid):
            raise SystemExit(f"another benchmark is running (pid {pid}); remove {LOCK} if it is stale")
    LOCK.write_text(str(os.getpid()))
    atexit.register(lambda: LOCK.unlink(missing_ok=True))


def _pid_alive(pid: int) -> bool:
    import os

    if os.name == "nt":  # os.kill(pid, 0) sends CTRL_C_EVENT on Windows: never use it here
        out = subprocess.run(["tasklist", "/FI", f"PID eq {pid}", "/NH", "/FO", "CSV"],
                             capture_output=True, text=True).stdout
        return f'"{pid}"' in out
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def write_result(label: str, name: str, payload: dict) -> Path:
    out_dir = RESULTS / label
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{name}.json"
    path.write_text(json.dumps(payload, indent=2, default=str), encoding="utf-8")
    return path

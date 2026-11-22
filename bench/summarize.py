"""Collapse the JSON results of one or more labels into a single comparison CSV.

Usage:
  python summarize.py baseline            -> bench/results/baseline/summary.csv
  python summarize.py baseline final      -> bench/results/comparison.csv (one column per label)
"""
from __future__ import annotations

import csv
import json
import sys

from common import RESULTS

# (file, metric name in the CSV, path inside "summary", unit)
METRICS = [
    ("E1", "E1 light job wait p50", ("light_wait_s", "p50"), "s"),
    ("E1", "E1 light job wait p95", ("light_wait_s", "p95"), "s"),
    ("E1", "E1 light job total p95", ("light_total_s", "p95"), "s"),
    ("E1", "E1 subtitles job total p50", ("heavy_total_s", "p50"), "s"),
    ("E2", "E2 burst makespan p50", ("makespan_s", "p50"), "s"),
    ("E2", "E2 burst makespan p95", ("makespan_s", "p95"), "s"),
    ("E2", "E2 job latency p95", ("job_total_s", "p95"), "s"),
    ("E2", "E2 job wait p95", ("job_wait_s", "p95"), "s"),
    ("E3", "E3 idle memory before", ("idle_before_mem_mib",), "MiB"),
    ("E3", "E3 idle memory after", ("idle_after_mem_mib",), "MiB"),
    ("E3", "E3 containers idle after", ("idle_after_containers",), "count"),
    ("E3", "E3 peak total CPU p50", ("peak_total_cpu_pct", "p50"), "%"),
    ("E3", "E3 peak total memory p50", ("peak_total_mem_mib", "p50"), "MiB"),
]
for target in ("none", "image-tool", "video", "projects"):
    f = f"chaos-{target}"
    METRICS += [
        (f, f"R1 terminal jobs ({target}) min", ("r1_terminal_pct", "min"), "%"),
        (f, f"R1 terminal jobs ({target}) mean", ("r1_terminal_pct", "mean"), "%"),
        (f, f"R1 hung jobs ({target}) total", ("hung_jobs_total",), "count"),
        (f, f"R2 recovery ({target}) p95", ("r2_recovery_s", "p95"), "s"),
        (f, f"R3 orphan processes ({target}) max", ("r3_orphan_processes", "max"), "count"),
    ]


def lookup(label: str, file: str, path: tuple) -> object:
    p = RESULTS / label / f"{file}.json"
    if not p.exists():
        return ""
    node = json.loads(p.read_text(encoding="utf-8")).get("summary", {})
    for key in path:
        if not isinstance(node, dict):
            return ""
        node = node.get(key)
    if isinstance(node, float):
        return round(node, 2)
    return "" if node is None else node


def main():
    labels = sys.argv[1:] or ["baseline"]
    out = RESULTS / labels[0] / "summary.csv" if len(labels) == 1 else RESULTS / "comparison.csv"
    with out.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["metric", "unit", *labels])
        for file, name, path, unit in METRICS:
            values = [lookup(label, file, path) for label in labels]
            if any(v != "" for v in values):
                w.writerow([name, unit, *values])
    print(out)


if __name__ == "__main__":
    main()

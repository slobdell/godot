#!/usr/bin/env python3
"""Summarise `make nav-suite`: one row per configuration (arena, units, traffic), aggregated over seeds.

Reads build/nav/<arena>-<units>[-both]-s<seed>.json (arena's maze probe output) and writes summary.json and
summary.md beside them, stamped with the commit and the machine (orchestration.md lesson 10)."""
import glob
import json
import os
import re
import socket
import statistics
import subprocess
import sys


def median(values):
    values = [v for v in values if v is not None]
    return statistics.median(values) if values else None


def main(folder):
    runs = {}
    for path in sorted(glob.glob(os.path.join(folder, "*-s*.json"))):
        match = re.match(r"(.+)-s(\d+)\.json$", os.path.basename(path))
        if not match:
            continue
        with open(path) as f:
            runs.setdefault(match.group(1), []).append(json.load(f))
    commit = os.environ.get("NAV_COMMIT", "")
    if not commit:
        try:
            commit = subprocess.check_output(["git", "rev-parse", "--short=8", "HEAD"], text=True,
                                             stderr=subprocess.DEVNULL).strip()
        except Exception:
            commit = "unknown (pass NAV_COMMIT=<sha>: builder0 has no .git)"
    rows = []
    for tag, results in sorted(runs.items()):
        units = results[0]["units"]
        arrived = [r["arrived"] for r in results]
        never = lambda key: [r[key] if r[key] >= 0 else None for r in results]
        rows.append({
            "config": tag, "seeds": len(results), "units": units,
            "arrived_mean": round(statistics.mean(arrived), 1), "arrived_min": min(arrived),
            "all_arrived_runs": sum(1 for a in arrived if a == units),
            "t50_median_s": median(never("t50_s")), "t90_median_s": median(never("t90_s")),
            "t90_reached_runs": sum(1 for r in results if r["t90_s"] >= 0),
            "t100_reached_runs": sum(1 for r in results if r["t100_s"] >= 0),
            "stuck_units_mean": round(statistics.mean(r["stuck_units"] for r in results), 1),
            "stuck_events_mean": round(statistics.mean(r["stuck_events"] for r in results), 1),
            "crawl_share_mean": round(statistics.mean(r["crawl_share"] for r in results), 3),
            "off_navmesh_total": sum(r["off_navmesh"] for r in results),
        })
    out = {"commit": commit, "machine": socket.gethostname(), "rows": rows}
    with open(os.path.join(folder, "summary.json"), "w") as f:
        json.dump(out, f, indent=1)
    lines = [f"nav-suite at `{commit}` on {socket.gethostname()}, {rows[0]['seeds'] if rows else 0} seeds each", "",
             "| config | arrived (mean / min of N) | all arrived | t50 | t90 (runs reaching) | stuck units | crawl | off mesh |",
             "|---|---|---|---|---|---|---|---|"]
    for r in rows:
        fmt = lambda v: "never" if v is None else f"{v:.0f} s"
        lines.append(f"| {r['config']} | {r['arrived_mean']} / {r['arrived_min']} of {r['units']} | "
                     f"{r['all_arrived_runs']}/{r['seeds']} | {fmt(r['t50_median_s'])} | "
                     f"{fmt(r['t90_median_s'])} ({r['t90_reached_runs']}/{r['seeds']}) | {r['stuck_units_mean']} | "
                     f"{r['crawl_share_mean']:.0%} | {r['off_navmesh_total']} |")
    text = "\n".join(lines) + "\n"
    with open(os.path.join(folder, "summary.md"), "w") as f:
        f.write(text)
    print(text)
    print("NAV_SUITE " + json.dumps(out))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "build/nav")

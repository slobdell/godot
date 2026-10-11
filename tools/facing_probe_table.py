#!/usr/bin/env python3
"""Round 26 (orders O2): the `make facing-probe` table, one row per task, pooled over seeds.

Reads <dir>/<task>-<seed>/screen.json (ScreenPlaytest's faced_* rows) and prints, per task: runs, squads judged,
squads within the tolerance, the median and worst mean-hull error, the median and worst line error (line tasks), and
how many squads had arrived. Report only: exits 0 whenever it read something.
"""
import json
import pathlib
import statistics
import sys


def main(root: str) -> int:
    rows = {}
    for path in sorted(pathlib.Path(root).glob("*/screen.json")):
        for row in json.loads(path.read_text()):
            if "squads" in row:
                rows.setdefault(row["scenario"], []).append(row)
    if not rows:
        print(f"FACING_TABLE no rows under {root}")
        return 1
    print("FACING_TABLE task | runs | squads ok | hull err median/worst deg | line err median/worst deg | arrived")
    for task, runs in rows.items():
        squads = [s for r in runs for s in r["squads"] if s.get("crews", 0) > 0]
        hull = [s["hull_error_deg"] for s in squads if "hull_error_deg" in s]
        line = [s["line_error_deg"] for s in squads if "line_error_deg" in s]
        ok = sum(1 for s in squads if s.get("ok"))
        arrived = sum(1 for s in squads if s.get("arrived"))
        def pair(values):
            return f"{statistics.median(values):.1f}/{max(values):.1f}" if values else "-"
        print(f"FACING_TABLE {task} | {len(runs)} | {ok}/{len(squads)} | {pair(hull)} | {pair(line)} | "
              f"{arrived}/{len(squads)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "build/facing/headless"))

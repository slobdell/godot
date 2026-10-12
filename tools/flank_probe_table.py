#!/usr/bin/env python3
"""Round 27 (orders O1): the `make flank-probe` table.

Reads <dir>/<arm>/<side>-<seed>/screen.json (ScreenPlaytest's `flank` rows) and prints per arm (drawn, clicked): runs,
the task's approach given, runs that reached the drawn side (within 35 deg), the median seconds to reach it, the median
and worst side error at the end, the median best side error, and the median end distance. Report only.
"""
import json
import pathlib
import statistics
import sys


def med(values, fmt="{:.1f}"):
    return fmt.format(statistics.median(values)) if values else "-"


def main(root: str) -> int:
    arms = {}
    for path in sorted(pathlib.Path(root).glob("*/*/screen.json")):
        for row in json.loads(path.read_text()):
            if row.get("scenario") == "flank":
                row["_run"] = path.parent.name
                arms.setdefault(path.parts[-3], []).append(row)
    if not arms:
        print(f"FLANK_TABLE no rows under {root}")
        return 1
    print("FLANK_TABLE arm | runs | approach on task | reached side | median s to reach | end side err median/worst deg | "
          "best side err median | end distance median m")
    for arm in ("drawn", "clicked"):
        rows = arms.get(arm, [])
        if not rows:
            continue
        given = sum(1 for r in rows if r.get("task_approach"))
        reached = [r["reached_side_s"] for r in rows if r.get("reached_side_s", -1) >= 0]
        end = [r["end_side_error_deg"] for r in rows if "end_side_error_deg" in r]
        best = [r["best_side_error_deg"] for r in rows if "best_side_error_deg" in r]
        dist = [r["end_m"] for r in rows if "end_m" in r]
        print(f"FLANK_TABLE {arm} | {len(rows)} | {given}/{len(rows)} | {len(reached)}/{len(rows)} | {med(reached)} | "
              f"{med(end)}/{max(end) if end else '-'} | {med(best)} | {med(dist)}")
    for arm, rows in sorted(arms.items()):
        for r in rows:
            print(f"FLANK_RUN {arm} {r['_run']} target={r.get('target')} start={r.get('start_m')} verb={r.get('task_verb')} "
                  f"approach={r.get('task_approach')} reached={r.get('reached_side_s')} end_err={r.get('end_side_error_deg')} "
                  f"end_m={r.get('end_m')} why={r.get('why', '')}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "build/flank"))

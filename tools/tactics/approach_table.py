#!/usr/bin/env python3
"""Round 27 (brains B0): the table for `make approach-series` (build/approach-series.jsonl, one APPROACH_PROBE per run).

Per arm: runs, the side it attacked from (reach_off_deg: the element's bearing from the target, degrees off the east
side, when its first crew came inside its guns' reach; median / worst), how many runs attacked from within 35 deg of
it, when it got there (reach_s median), the kill (killed k of n, median s) and his crews alive. Exit 1 on a missing run.
"""
import json
import statistics
import sys

SIDE_DEG = 35.0


def main(path: str) -> int:
    rows = [json.loads(line) for line in open(path) if line.strip()]
    missing = [r for r in rows if r.get("missing")]
    for arm in ("east", "none"):
        runs = [r for r in rows if r.get("approach") == arm and not r.get("missing")]
        if not runs:
            continue
        reached = [r for r in runs if r["reach_off_deg"] >= 0]
        offs = sorted(r["reach_off_deg"] for r in reached)
        on_side = sum(1 for o in offs if o <= SIDE_DEG)
        kills = [r["killed_s"] for r in runs if r["killed_s"] >= 0]
        print("APPROACH_TABLE arm=%s n=%d reached=%d off_median=%.1f off_worst=%.1f on_side(<=%d)=%d/%d "
              "reach_s_median=%.1f killed=%d/%d killed_s_median=%.1f alive_mean=%.2f" % (
                  arm, len(runs), len(reached), statistics.median(offs) if offs else -1, offs[-1] if offs else -1,
                  SIDE_DEG, on_side, len(runs),
                  statistics.median([r["reach_s"] for r in reached]) if reached else -1,
                  len(kills), len(runs), statistics.median(kills) if kills else -1,
                  statistics.mean(r["alive"] for r in runs)))
        ends = sorted(r.get("nearest_end_m", -1) for r in runs if r.get("nearest_end_m", -1) >= 0)
        if ends:
            print("APPROACH_TABLE arm=%s nearest crew at the end (immortal target): median %.1f m, worst %.1f m, within 45 m %d/%d"
                  % (arm, statistics.median(ends), ends[-1], sum(1 for e in ends if e <= 45.0), len(ends)))
    if missing:
        print("APPROACH_TABLE missing %d runs" % len(missing))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))

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
        hit_runs = [r for r in runs if r.get("hits", 0) > 0]
        if hit_runs:
            # Round 28 (B1): the arm-independent reading: where on the target's hull the hits landed (degrees off the side
            # drawn). A run is "on side" when the median hit is within SIDE_DEG.
            meds = sorted(r["hit_off_median_deg"] for r in hit_runs)
            print("APPROACH_TABLE arm=%s hits: runs with hits %d/%d, on side by median hit (<=%d) %d/%d, median of medians %.1f, "
                  "hit share on side mean %.2f" % (arm, len(hit_runs), len(runs), SIDE_DEG,
                                                   sum(1 for m in meds if m <= SIDE_DEG), len(runs),
                                                   statistics.median(meds), statistics.mean(r["hit_on_side_share"] for r in hit_runs)))
        shot_runs = [r for r in runs if r.get("shots", 0) > 0]
        if shot_runs:
            # Round 28 (B2): where his crews fired from (median shooter bearing per run) and when the first round went.
            fmeds = sorted(r["fire_off_median_deg"] for r in shot_runs)
            firsts = sorted(r["first_shot_s"] for r in shot_runs)
            print("APPROACH_TABLE arm=%s fire: runs that fired %d/%d, fired from the side (median shooter <=%d) %d/%d, "
                  "median of medians %.1f, first round median %.1f s (worst %.1f)" % (
                      arm, len(shot_runs), len(runs), SIDE_DEG, sum(1 for m in fmeds if m <= SIDE_DEG), len(runs),
                      statistics.median(fmeds), statistics.median(firsts), firsts[-1]))
        won = [r for r in runs if r.get("enemy_alive", -1) == 0]
        if any(r.get("enemy_alive", -1) >= 0 for r in runs):
            shares = [r.get("target_flank_share", 0) for r in runs]
            print("APPROACH_TABLE arm=%s live: his side won (enemy wiped) %d/%d, his crews alive mean %.2f, target's side/rear hit share median %.2f"
                  % (arm, len(won), len(runs), statistics.mean(r["alive"] for r in runs), statistics.median(shares)))
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

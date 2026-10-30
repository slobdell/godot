#!/usr/bin/env python3
"""Round 46 (engage L4, Bar L1): the lane probe's table. One LANE_PROBE line per seed per arm.

    lane_table.py DIR                 one arm: per-seed rows + totals
    lane_table.py --pair OFF_DIR ON_DIR   the paired lines Bar L1 is read from (seeds in both arms, no stage errors)
"""
import json
import math
import os
import sys


def load(folder):
    rows = {}
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".log"):
            continue
        for line in open(os.path.join(folder, name), errors="replace"):
            if line.startswith("LANE_PROBE "):
                row = json.loads(line[len("LANE_PROBE "):])
                rows[row["seed"]] = row
    return rows


def mean(xs):
    return sum(xs) / len(xs) if xs else float("nan")


def se(xs):
    if len(xs) < 2:
        return float("nan")
    m = mean(xs)
    return math.sqrt(sum((x - m) ** 2 for x in xs) / (len(xs) - 1) / len(xs))


def one(folder):
    rows = load(folder)
    for seed in sorted(rows):
        r = rows[seed]
        if "error" in r:
            print(f"{seed} ERROR {r['error']}")
            continue
        print(f"{seed} {r['arena']:9} {r['mode']:6} {r['hull']:10} held {r['held_s']:5.1f} first {r['first_shot_s']:5.1f} "
              f"shots {r['shots']:3} ff {r['ff_hits']} died {int(r['died'])} hp {r['enemy_hp']:.2f} moved {r['moved_m']:5.1f} lines {r['lines']}")
    good = [r for r in rows.values() if "error" not in r]
    print(f"n {len(good)} (errors {len(rows) - len(good)}): held mean {mean([r['held_s'] for r in good]):.2f} s")


def pair(off_dir, on_dir):
    off, on = load(off_dir), load(on_dir)
    seeds = sorted(s for s in off if s in on and "error" not in off[s] and "error" not in on[s])
    errors = sorted(s for s in set(off) | set(on) if s not in seeds)
    print(f"paired seeds {len(seeds)}; unpaired / errors {errors}")
    def line(name, key, cond=lambda s: True):
        ss = [s for s in seeds if cond(s)]
        diffs = [on[s][key] - off[s][key] for s in ss]
        print(f"{name:34} n {len(ss):3}  off {mean([off[s][key] for s in ss]):7.2f}  on {mean([on[s][key] for s in ss]):7.2f}  "
              f"diff {mean(diffs):+7.2f}  se {se(diffs):.2f}")
        return ss, diffs
    blocked = lambda s: off[s]["blocked"]
    print("== deciding")
    line("D1 held_s (all)", "held_s")
    line("D1 held_s (blocked in OFF)", "held_s", blocked)
    ss = [s for s in seeds if off[s]["blocked"]]
    sooner = sum(1 for s in ss if on[s]["first_shot_s"] <= off[s]["first_shot_s"] + 1e-6)
    strictly = sum(1 for s in ss if on[s]["first_shot_s"] < off[s]["first_shot_s"] - 1e-6)
    print(f"{'D2 first shot after the block':34} n {len(ss):3}  sooner or identical {sooner}/{len(ss)}  strictly sooner {strictly}"
          f"  off mean {mean([off[s]['first_shot_s'] for s in ss]):.2f} s  on mean {mean([on[s]['first_shot_s'] for s in ss]):.2f} s")
    print("== guards")
    print(f"{'G1 friendly-fire hits (sum)':34} off {sum(off[s]['ff_hits'] for s in seeds)}  on {sum(on[s]['ff_hits'] for s in seeds)}"
          f"   kills off {sum(off[s]['ff_kills'] for s in seeds)} on {sum(on[s]['ff_kills'] for s in seeds)}")
    d_off = sum(int(off[s]["died"]) for s in seeds)
    d_on = sum(int(on[s]["died"]) for s in seeds)
    print(f"{'G2 crew deaths':34} off {d_off}  on {d_on}  bar on <= off + max(1, 1.645 sqrt(off)) = {d_off + max(1, 1.645 * math.sqrt(d_off)):.1f}")
    line("G3 enemy hp left", "enemy_hp")
    posts = [s for s in seeds if on[s]["mode"] == "post"]
    print(f"{'G4 post: max from his post (on)':34} n {len(posts)}  max {max([on[s]['post_m'] for s in posts], default=0):.1f} m"
          f"  over 5.5 m: {sum(1 for s in posts if on[s]['post_m'] > 5.5)}  (off max {max([off[s]['post_m'] for s in posts], default=0):.1f})")
    print("== reported")
    for mode in ("attack", "post", "cpu"):
        line(f"held_s mode {mode}", "held_s", lambda s, m=mode: on[s]["mode"] == m)
    line("moved_m", "moved_m")
    line("shots", "shots")
    print(f"{'lines (on)':34} {sum(on[s]['lines'] for s in seeds)} over {sum(1 for s in seeds if on[s]['lines'])} runs; off {sum(off[s]['lines'] for s in seeds)}")


if __name__ == "__main__":
    if sys.argv[1] == "--pair":
        pair(sys.argv[2], sys.argv[3])
    else:
        one(sys.argv[1])

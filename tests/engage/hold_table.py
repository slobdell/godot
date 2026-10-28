#!/usr/bin/env python3
"""Round 43 (engage A4): Bar A's lines from `make engage-hold` logs (tests/engage/hold_probe.gd, one ENGAGE_HOLD json line per seed).

    hold_table.py DIR                      one arm: a row per seed and the totals
    hold_table.py --pair BASE_DIR ARM_DIR  the bar: paired by seed, each line with its paired mean difference, se and z

Lines (the bar names them before any number; this prints what they read):
  far_arrive_s   the far crews' arrival at the squad's destination (mean a run, s)                       deciding: ARM < BASE by >= 2 se
  away_s         crew-seconds under a street hold driving AWAY from the crew's own K1 goal (sum a run)   reported (his geometry: dev)
  away_m         the largest such drive (m, max a run)                                                  reported
  last_a_s       the waiting squad's last arrival (s; the window when never)                            reported (expected lower)
  contacts_mouth friendly contacts within 25 m of the street's middle (sum)                             guard: ARM <= BASE + 1.645 se (T1's purpose)
  contacts_far   contacts at the mouth involving a far crew while the passer is still coming (sum)      guard: ARM <= BASE + max(1.645 se, 2)
  jam_s          crew-seconds still (< 0.5 m/s) within 25 m of the middle before arriving (sum)         guard: ARM <= BASE + 1.645 se
  contacts, contacts_fast, contacts_cross, stuck_s, held_s, last_b_s, far_released, far_held, verdicts   reported
  exercised      seeds with a verdict (a street hold happened) and a far crew: the floor is 16 of 24
Report only; the verdict is read against the bar by hand.
"""
import glob
import json
import math
import os
import sys


LINES = ["off_arrive_s", "held_off_s", "held_on_s", "way_released", "far_arrive_s", "away_s", "away_m", "last_a_s", "contacts_mouth", "contacts_far", "jam_s", "contacts", "contacts_fast",
         "contacts_cross", "stuck_s", "held_s", "a_held_s", "last_b_s", "far_released", "far_held", "verdicts"]


def read(folder):
    rows = {}
    for path in sorted(glob.glob(os.path.join(folder, "*.log"))):
        with open(path) as f:
            for line in f:
                if line.startswith("ENGAGE_HOLD "):
                    d = json.loads(line[len("ENGAGE_HOLD "):])
                    if "error" in d:
                        continue
                    rows[int(d["seed"])] = d
    return rows


def mean_se(values):
    n = len(values)
    if n == 0:
        return 0.0, 0.0
    m = sum(values) / n
    if n < 2:
        return m, 0.0
    var = sum((v - m) ** 2 for v in values) / (n - 1)
    return m, math.sqrt(var / n)


def one(folder):
    rows = read(folder)
    print(f"{'seed':>6} {'stage':>14} {'arm':>3} {'far_m':>5} " + " ".join(f"{k:>14}" for k in LINES))
    for seed in sorted(rows):
        d = rows[seed]
        print(f"{seed:>6} {d.get('stage', d['arena']):>14} {d['arm']:>3} {d['far_m']:>5} " + " ".join(f"{float(d.get(k, 0)):>14.1f}" for k in LINES))
    exercised = sum(1 for d in rows.values() if d.get("verdicts", 0) >= 1 and d.get("far_crews"))
    print(f"n {len(rows)} exercised {exercised}")
    for k in LINES:
        vals = [float(d.get(k, 0)) for d in rows.values()]
        m, se = mean_se(vals)
        print(f"  {k:>14}: sum {sum(vals):10.1f} mean {m:8.2f} se {se:6.2f}")


def pair(base_dir, arm_dir, only=None):
    base = read(base_dir)
    arm = read(arm_dir)
    seeds = sorted(s for s in set(base) & set(arm) if only is None or only(base[s]))
    missing = sorted((set(base) | set(arm)) - set(seeds))
    print(f"paired seeds n {len(seeds)}" + (f" (unpaired: {missing})" if missing else ""))
    exercised = sum(1 for s in seeds if base[s].get("verdicts", 0) >= 1 and base[s].get("far_crews"))
    print(f"exercised (a verdict in BASE and a far crew) {exercised} of {len(seeds)}; floor 16")
    print(f"{'line':>14} {'BASE':>10} {'ARM':>10} {'paired mean':>12} {'se':>8} {'z':>7}")
    for k in LINES:
        b = [float(base[s].get(k, 0)) for s in seeds]
        a = [float(arm[s].get(k, 0)) for s in seeds]
        diffs = [a[i] - b[i] for i in range(len(seeds))]
        m, se = mean_se(diffs)
        z = m / se if se > 0 else float("nan")
        print(f"{k:>14} {sum(b):>10.1f} {sum(a):>10.1f} {m:>12.2f} {se:>8.2f} {z:>7.2f}")
    print("per seed (away_s BASE -> ARM, away_m, last_a_s, contacts_far):")
    for s in seeds:
        print(f"  {s} {base[s].get('stage', base[s]['arena']):>14} far {base[s]['far_m']:>5}: away_s {base[s]['away_s']:.0f} -> {arm[s]['away_s']:.0f}, "
              f"away_m {base[s]['away_m']:.1f} -> {arm[s]['away_m']:.1f}, last_a {base[s]['last_a_s']:.1f} -> {arm[s]['last_a_s']:.1f}, "
              f"contacts_far {base[s]['contacts_far']} -> {arm[s]['contacts_far']}, verdicts {base[s]['verdicts']} -> {arm[s]['verdicts']}, "
              f"far_released {arm[s]['far_released']} far_held {arm[s]['far_held']}")


if __name__ == "__main__":
    if len(sys.argv) >= 4 and sys.argv[1] == "--pair":
        pair(sys.argv[2], sys.argv[3])
        if "--by-stage" in sys.argv:
            print("\n=== the side-street seeds (Bar A6's deciding line: off_arrive_s)")
            pair(sys.argv[2], sys.argv[3], lambda d: d.get("off_crews"))
            print("\n=== the head-on seeds (Bar A6's mechanism guard: verdicts, held_on_s)")
            pair(sys.argv[2], sys.argv[3], lambda d: not d.get("off_crews"))
    elif len(sys.argv) == 2:
        one(sys.argv[1])
    else:
        print(__doc__)
        sys.exit(2)

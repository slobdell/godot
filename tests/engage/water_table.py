#!/usr/bin/env python3
"""Round 43 (engage A7): the engage-across-water census from `make engage-water` logs (tests/engage/water_probe.gd, one
ENGAGE_WATER json line per seed).

    water_table.py DIR                     one arm: a row per seed and the totals
    water_table.py --pair BASE_DIR ARM_DIR  paired by seed: each line's paired mean difference, se and z

Lines: water_s (crew-seconds in ENGAGE/SUPPRESS on a contact across water, under an attack / attack-move order),
water_far_s (of those, the contact beyond the gun's range: cannot hit), hop_s / hop_rev_s / hop_far_s (direct hops in that
state, reverse ones, hops while far), crews_water / crews_far, off_order_m (the largest rise of a crew's distance to its order
goal while in the state), last_a_s (the squad's last arrival), deaths, kills. Report only.
"""
import glob, json, math, os, sys

LINES = ["water_s", "water_far_s", "fire_s", "fire_far_s", "hop_s", "hop_rev_s", "hop_far_s", "damage_water", "hits_water",
         "first_hit_water_s", "damage_total", "hits_total", "first_hit_s", "crews_water", "crews_far", "off_order_m", "last_a_s", "deaths", "kills"]


def read(folder):
    rows = {}
    for path in sorted(glob.glob(os.path.join(folder, "*.log"))):
        with open(path) as f:
            for line in f:
                if line.startswith("ENGAGE_WATER "):
                    d = json.loads(line[len("ENGAGE_WATER "):])
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
    print(f"{'seed':>6} {'arena':>9} " + " ".join(f"{k:>12}" for k in LINES) + "  hulls")
    for seed in sorted(rows):
        d = rows[seed]
        print(f"{seed:>6} {d['arena']:>9} " + " ".join(f"{float(d.get(k, 0)):>12.1f}" for k in LINES) + "  " + ",".join(d["hulls"]))
    print(f"n {len(rows)}; seeds with the state {sum(1 for d in rows.values() if d['water_s'] > 0)}, with a far target {sum(1 for d in rows.values() if d['water_far_s'] > 0)}")
    for k in LINES:
        vals = [float(d.get(k, 0)) for d in rows.values()]
        m, se = mean_se(vals)
        print(f"  {k:>12}: sum {sum(vals):10.1f} mean {m:8.2f} se {se:6.2f}")


def pair(base_dir, arm_dir):
    base = read(base_dir)
    arm = read(arm_dir)
    seeds = sorted(set(base) & set(arm))
    print(f"paired seeds n {len(seeds)}")
    print(f"{'line':>12} {'BASE':>10} {'ARM':>10} {'paired mean':>12} {'se':>8} {'z':>7}")
    for k in LINES:
        b = [float(base[s].get(k, 0)) for s in seeds]
        a = [float(arm[s].get(k, 0)) for s in seeds]
        diffs = [a[i] - b[i] for i in range(len(seeds))]
        m, se = mean_se(diffs)
        z = m / se if se > 0 else float("nan")
        print(f"{k:>12} {sum(b):>10.1f} {sum(a):>10.1f} {m:>12.2f} {se:>8.2f} {z:>7.2f}")
    for s in seeds:
        print(f"  {s} {base[s]['arena']:>9}: water {base[s]['water_s']:.1f} -> {arm[s]['water_s']:.1f}, far {base[s]['water_far_s']:.1f} -> {arm[s]['water_far_s']:.1f}, hops {base[s]['hop_s']:.1f} -> {arm[s]['hop_s']:.1f}, off {base[s]['off_order_m']:.1f} -> {arm[s]['off_order_m']:.1f}, last_a {base[s]['last_a_s']:.1f} -> {arm[s]['last_a_s']:.1f}, deaths {base[s]['deaths']} -> {arm[s]['deaths']}, kills {base[s]['kills']} -> {arm[s]['kills']}")


if __name__ == "__main__":
    if len(sys.argv) >= 4 and sys.argv[1] == "--pair":
        pair(sys.argv[2], sys.argv[3])
    elif len(sys.argv) == 2:
        one(sys.argv[1])
    else:
        print(__doc__)
        sys.exit(2)

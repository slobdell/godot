#!/usr/bin/env python3
"""Round 45 (engage E3): the authority probe's table. One AUTHORITY_PROBE json line per seed log in each folder.

  authority_table.py DIR                 one arm: per run and per (verb, path, alone|squad) group
  authority_table.py --pair OFF ON       both arms by seed, and Bar E1's lines (as filed in workstreams.md *Bars (round 45)*)

His case is a crew he orders ALONE: a squad of one (either path) or one crew of a squad given a direct order. A whole squad's
hold task is reported as a guard (no crew sent at the enemy), not a deciding line.
"""
import json
import math
import os
import sys


def load(folder):
    runs = {}
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".log"):
            continue
        for line in open(os.path.join(folder, name), errors="replace"):
            if line.startswith("AUTHORITY_PROBE "):
                row = json.loads(line[len("AUTHORITY_PROBE "):])
                runs[int(row["seed"])] = row
    return runs


def alone(row):
    return row["crews"] == 1 or row["path"] == "direct"


def kind(row):
    return "%s/%s/%s" % (row["verb"], row["path"], "alone" if alone(row) else "squad")


def mean_se(values):
    if not values:
        return float("nan"), float("nan")
    m = sum(values) / len(values)
    if len(values) < 2:
        return m, float("nan")
    var = sum((v - m) ** 2 for v in values) / (len(values) - 1)
    return m, math.sqrt(var / len(values))


def show(runs, label):
    print("== %s: %d runs (%d errors)" % (label, len(runs), sum(1 for r in runs.values() if "error" in r)))
    print("%6s %-9s %-10s %-26s %7s %6s %7s %6s %5s %4s %5s %6s" % ("seed", "arena", "hull", "kind", "moved", "push",
          "toward", "end", "shots", "hit", "died", "back"))
    for seed, r in sorted(runs.items()):
        if "error" in r:
            print("%6d %-9s %-10s %s" % (seed, r["arena"], r["hull"], r["error"]))
            continue
        print("%6d %-9s %-10s %-26s %7s %6d %7.1f %6s %5d %4d %5s %6s" % (seed, r["arena"], r["hull"], kind(r),
              r["moved_m"], r["pushed_rows"], r["toward_m"], r["end_m"], r["shots"], r["hits"], r["died"], r["taken_back"]))


def lines(runs):
    ok = [r for r in runs.values() if "error" not in r]
    his = [r for r in ok if alone(r)]
    held = [r for r in his if r["verb"] in ("hold", "stop") and r["rested"]]
    moves = [r for r in his if r["verb"] == "move" and not r["died"] and r.get("end_phase") != "blocked"]
    squad = [r for r in ok if not alone(r)]
    back = [r for r in ok if r["taken_back"] is not None]
    return {
        "his_runs": len(his),
        "native_decide_runs": "%d/%d" % (sum(1 for r in ok if r.get("native_decide")), len(ok)),
        "held_moved_max_m": max([r["moved_m"] for r in held], default=float("nan")),
        "held_over_2m": sum(1 for r in held if r["moved_m"] > 2.0),
        "held_n": len(held),
        "pushed_rows_his": sum(r["pushed_rows"] for r in his),
        "move_n": len(moves),
        "move_outside_arrival": sum(1 for r in moves if r["end_m"] > r["arrive_m"]),
        "move_blocked": sum(1 for r in his if r["verb"] == "move" and r.get("end_phase") == "blocked"),
        "squad_hold_sent_at_enemy": sum(r["pushed_rows"] for r in squad),
        "shots_held_mean_se": mean_se([r["shots"] for r in held]),
        "held_in_range_n": len([r for r in held if r.get("gap_at_order_m", 1e9) <= r.get("range_m", 0)]),
        "shots_held_in_range_mean_se": mean_se([r["shots"] for r in held if r.get("gap_at_order_m", 1e9) <= r.get("range_m", 0)]),
        "deaths": sum(1 for r in ok if r["died"]),
        "enemy_hp_mean_se": mean_se([r["enemy_hp"] for r in ok]),
        "hits_mean_se": mean_se([r["hits"] for r in ok]),
        "taken_back": "%d/%d" % (sum(1 for r in back if r["taken_back"]), len(back)),
    }


def main(argv):
    if argv and argv[0] == "--pair":
        off, on = load(argv[1]), load(argv[2])
        show(off, "OFF " + argv[1])
        show(on, "ON " + argv[2])
        common = sorted(set(off) & set(on))
        print("== paired seeds: %d" % len(common))
        lo, ln = lines({s: off[s] for s in common}), lines({s: on[s] for s in common})
        for key in lo:
            print("  %-26s off %-28s on %s" % (key, lo[key], ln[key]))
        return 0
    show(load(argv[0]), argv[0])
    for key, value in lines(load(argv[0])).items():
        print("  %-26s %s" % (key, value))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

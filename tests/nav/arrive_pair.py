#!/usr/bin/env python3
"""Round 31 (brains B5c-v5; B3b-2 reads crossings too): the arrive series' bar lines from two squad-arrive files run as separate arms (on = the
gate rule, off = --nav-off=gategiveup), paired by (arena, units, seed). Usage: arrive_pair.py on.jsonl off.jsonl
  within 8 m: cells with all_in8_s on v off, McNemar discordants (for = on only, against = off only), exact p;
  paired median all_in8_s over cells complete in both arms; gate counters."""
import json
import math
import statistics
import sys


def load(path):
    rows = {}
    for line in open(path):
        if line.strip():
            r = json.loads(line)
            rows[(r.get("arena"), r.get("units"), r.get("seed"))] = r
    return rows


def done(r, key):
    return r.get(key) is not None and float(r[key]) >= 0.0


def mcnemar(b, c):
    n = b + c
    if n == 0:
        return 1.0
    k = min(b, c)
    return min(1.0, 2.0 * sum(math.comb(n, i) for i in range(k + 1)) / 2 ** n)


def main(on_path, off_path):
    on, off = load(on_path), load(off_path)
    keys = sorted(set(on) & set(off), key=str)
    lost = sorted(set(on) ^ set(off), key=str)
    for metric in ("all_in8_s",):
        a = sum(done(on[k], metric) for k in keys)
        b = sum(done(off[k], metric) for k in keys)
        f = [k for k in keys if done(on[k], metric) and not done(off[k], metric)]
        g = [k for k in keys if done(off[k], metric) and not done(on[k], metric)]
        print(f"{metric}: on {a} v off {b} of {len(keys)}; discordant for {len(f)} v against {len(g)} "
              f"(McNemar p {mcnemar(len(f), len(g)):.4f}); against: {g[:8]}")
    both = [k for k in keys if done(on[k], "all_in8_s") and done(off[k], "all_in8_s")]
    if both:
        d = [float(on[k]["all_in8_s"]) - float(off[k]["all_in8_s"]) for k in both]
        mo = statistics.median(float(on[k]["all_in8_s"]) for k in both)
        mf = statistics.median(float(off[k]["all_in8_s"]) for k in both)
        print(f"paired all_in8_s over {len(both)} cells complete in both: median on {mo:.1f} v off {mf:.1f} s "
              f"({(mo / mf - 1) * 100:+.1f} %); paired diff median {statistics.median(d):+.1f} s")
    for name, rows in (("on", on), ("off", off)):
        tot = {c: sum(int(r.get(c, 0)) for r in rows.values()) for c in
               ("gates_turned", "gates_latched_away", "gates_near", "gates_given_up", "gates_reached_latched",
                "crossings_found", "crossings_held")}
        fired = sum(1 for r in rows.values() if any(int(r.get(c, 0)) > 0 for c in tot))
        print(f"counters {name}: {tot}; runs with any counter > 0: {fired}/{len(rows)}")
    if lost:
        print(f"UNPAIRED cells: {lost}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

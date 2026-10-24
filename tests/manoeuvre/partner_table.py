#!/usr/bin/env python3
"""Round 39 (manoeuvre stretch): who a long-wedged crew is yielding to, from `make manoeuvre-wedge-trace` logs (WEDGE_EP rows
with `partners` / `partner_top`, tests/manoeuvre/wedge_trace.gd).

    python3 tests/manoeuvre/partner_table.py DIR

Target episodes = round 37's M3 definition: touching a hull, net motion < 0.5 m, >= 3 s. Prints how many there are, the ticks by
partner class (state/way/mutual), the episodes by their DOMINANT class, the mutual pairs (two crews each other's top partner in
overlapping episodes), and the longest episodes with their top partner.
"""
import collections
import glob
import json
import os
import sys


def main(folder):
    eps = []
    for path in sorted(glob.glob(os.path.join(folder, "*.log"))):
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("WEDGE_EP "):
                    eps.append(json.loads(line[9:]))
    target = [e for e in eps if e["s"] >= 3.0 and e["net_m"] < 0.5 and e["touch_hull"] > 0]
    print("episodes %d, target (touching, net < 0.5 m, >= 3 s) %d, %.0f s in all" % (len(eps), len(target), sum(e["s"] for e in target)))
    ticks = collections.Counter()
    dominant = collections.Counter()
    for e in target:
        p = e.get("partners", {})
        ticks.update(p)
        if p:
            dominant[max(p.items(), key=lambda kv: kv[1])[0]] += 1
    total = sum(ticks.values()) or 1
    print("\nticks by partner class (state/way/mutual):")
    for k, v in ticks.most_common():
        print("  %-36s %6d  %5.1f %%" % (k, v, 100.0 * v / total))
    print("\nepisodes by dominant class:")
    for k, v in dominant.most_common():
        print("  %-36s %4d" % (k, v))
    by_fight = collections.defaultdict(list)
    for e in target:
        by_fight[(e["arena"], e["seed"])].append(e)
    pairs = 0
    for (arena, seed), rows in by_fight.items():
        top = {e["crew"]: e for e in rows}
        seen = set()
        for e in rows:
            m = e.get("partner_top", "")
            o = top.get(m)
            if o and o.get("partner_top") == e["crew"] and o["from"] <= e["to"] and e["from"] <= o["to"]:
                key = tuple(sorted((e["crew"], m)))
                if key not in seen:
                    seen.add(key)
                    pairs += 1
    print("\nmutual pairs (each the other's top partner, overlapping): %d" % pairs)
    print("\nlongest:")
    for e in sorted(target, key=lambda e: -e["s"])[:10]:
        p = e.get("partners", {})
        dom = max(p.items(), key=lambda kv: kv[1])[0] if p else "-"
        print("  %s s%d %-22s %-12s %6.1f s net %.2f m partner %-22s %s" % (e["arena"], e["seed"], e["crew"], e["unit"], e["s"],
                                                                          e["net_m"], e.get("partner_top", ""), dom))


if __name__ == "__main__":
    main(sys.argv[1])

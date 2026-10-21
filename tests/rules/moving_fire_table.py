#!/usr/bin/env python3
"""Round 37 (rules R2 measure): pool tests/rules/moving_fire_probe.gd's MOVING_FIRE rows into one table.

Direct-fire damage by the shooter's motion (still / slow / fast, as a fraction of its top speed) x range (near < 50 m,
mid < 100 m, far), the share of it each cell holds, and the arc damage beside it."""
import json
import sys

MOTIONS = ["still", "slow", "fast"]
RANGES = ["near", "mid", "far"]


def main(path):
    rows = [json.loads(line) for line in open(path) if line.strip()]
    damage, hits, shots = {}, {}, {}
    arc = 0.0
    for row in rows:
        for team in row["teams"].values():
            for key, value in team["damage"].items():
                damage[key] = damage.get(key, 0.0) + value
            for key, value in team["hits"].items():
                hits[key] = hits.get(key, 0.0) + value
            for key, value in team["shots"].items():
                shots[key] = shots.get(key, 0.0) + value
            arc += team["arc_damage"]
    direct = sum(damage.values()) or 1.0
    print("fights %d (%s) | direct damage %.0f, arc damage %.0f" % (len(rows), rows[0]["rules"] if rows else "-", direct, arc))
    print("%-6s %24s %24s %24s %10s %8s" % ("", *("%s dmg (share) hits" % r for r in RANGES), "all", "shots"))
    for m in MOTIONS:
        cells = []
        for r in RANGES:
            key = "%s|%s" % (m, r)
            cells.append("%8.0f (%4.1f%%) %6.0f" % (damage.get(key, 0.0), 100.0 * damage.get(key, 0.0) / direct, hits.get(key, 0.0)))
        total = sum(damage.get("%s|%s" % (m, r), 0.0) for r in RANGES)
        print("%-6s %24s %24s %24s %9.1f%% %8.0f" % (m, *cells, 100.0 * total / direct, shots.get(m, 0.0)))
    movers = sum(v for k, v in damage.items() if not k.startswith("still"))
    beyond = sum(v for k, v in damage.items() if not k.startswith("still") and not k.endswith("near"))
    print("movers (>= 15%% of top speed): %.1f%% of direct damage; movers beyond 50 m: %.1f%%" % (100.0 * movers / direct,
            100.0 * beyond / direct))


if __name__ == "__main__":
    main(sys.argv[1])

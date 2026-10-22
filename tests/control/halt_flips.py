#!/usr/bin/env python3
"""Round 37 (orders O1, R36.26): the halt-shape flicker read from orders-probe rows.

    python3 tests/control/halt_flips.py build/orders-probe/rows.jsonl [more rows.jsonl ...]

Per cell (map, squads, route) and arm: placed squads, squads with any halt-shape flip after the place window
(`shape_flips` > 0), the flips summed, re-lays (shape or the element's own terrain read changed) and the squads
with any, the terrain flips at the crews' centroid and at the anchor, reseats, and the
O4 away reads (away_m against the current goal, away_held_m while the goal is unchanged, away_seat_m against the
placed seat). Then the totals per arm and the flipping squads listed (their seed and squad number, to trace).
"""
import json
import sys
from collections import defaultdict


def main(paths):
    rows = []
    for path in paths:
        with open(path) as f:
            rows += [json.loads(line) for line in f if line.strip()]
    cells = defaultdict(list)
    for r in rows:
        cells[(r["map"], r["squads"], r["route"], r["arm"])].append(r)
    cols = ("placed", "flipping", "flips", "relays", "relaying", "terr_c", "terr_a", "reseats", "away", "held", "seat")
    print("%-22s %-10s | " % ("cell", "arm") + " ".join("%8s" % c for c in cols))
    totals = defaultdict(lambda: defaultdict(float))
    flippers = []
    for key in sorted(cells):
        rs = [r for r in cells[key] if r.get("shape_flips", -1) >= 0]
        line = {
            "placed": len(rs),
            "flipping": sum(1 for r in rs if r["shape_flips"] > 0),
            "flips": sum(r["shape_flips"] for r in rs),
            "relays": sum(r.get("relays", 0) for r in rs),
            "relaying": sum(1 for r in rs if r.get("relays", 0) > 0),
            "terr_c": sum(r["terrain_flips"] for r in rs),
            "terr_a": sum(r["anchor_terrain_flips"] for r in rs),
            "reseats": sum(r.get("reseats", 0) for r in rs),
            "away": sum(r.get("away_m", 0.0) for r in rs),
            "held": sum(r.get("away_held_m", 0.0) for r in rs),
            "seat": sum(r.get("away_seat_m", 0.0) for r in rs),
        }
        for c in cols:
            totals[key[3]][c] += line[c]
        print("%-22s %-10s | " % ("%s %d %s" % key[:3], key[3]) + " ".join(
            ("%8.1f" if isinstance(line[c], float) else "%8d") % line[c] for c in cols))
        flippers += [(key, r) for r in rs if r["shape_flips"] > 0 or r.get("relays", 0) > 0]
    print()
    for arm in sorted(totals):
        print("TOTAL %-10s | " % arm + " ".join("%s %.1f" % (c, totals[arm][c]) for c in cols))
    print()
    for key, r in flippers:
        print("FLIP %s %d %s %s seed %d squad %d: relays %d flips %d shapes %s terrain c/a %d/%d reseats %d away %.1f held %.1f seat %.1f"
              % (key[0], key[1], key[2], key[3], r["seed"], r["squad"], r.get("relays", 0), r["shape_flips"], r.get("shapes"),
                 r["terrain_flips"], r["anchor_terrain_flips"], r.get("reseats", 0), r.get("away_m", 0.0),
                 r.get("away_held_m", 0.0), r.get("away_seat_m", 0.0)))


if __name__ == "__main__":
    main(sys.argv[1:])

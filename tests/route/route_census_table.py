#!/usr/bin/env python3
"""Round 47 (route R6): the route census table from route_census.gd logs (ROUTE_LEG lines).

Per leg: ratio = driven metres / the navmesh's shortest from the leg's start to its end. Travel legs (the brain chose
MOVE / KEEP_SLOT / ADVANCE / REGROUP / INVESTIGATE, or no brain) are the route's question; the rest (ORBIT, RETREAT,
ENGAGE, ...) drive what the fight asks and are reported apart. By side, by unit class, by arena; the worst travel
detours (excess metres, ratio > DETOUR) listed with seed / crew / ticks so each can be staged.

  python3 tests/route/route_census_table.py build/route-census/*.log [--detour=1.3] [--top=20]
"""
import json
import sys

TRAVEL = {"", "MOVE", "KEEP_SLOT", "ADVANCE", "REGROUP", "INVESTIGATE"}


def quantile(values, q):
    if not values:
        return float("nan")
    values = sorted(values)
    k = (len(values) - 1) * q
    lo = int(k)
    hi = min(lo + 1, len(values) - 1)
    return values[lo] + (values[hi] - values[lo]) * (k - lo)


def read(paths):
    legs, census = [], []
    for path in paths:
        with open(path, encoding="utf-8", errors="replace") as handle:
            for line in handle:
                if line.startswith("ROUTE_LEG "):
                    legs.append(json.loads(line[len("ROUTE_LEG "):]))
                elif line.startswith("ROUTE_CENSUS "):
                    census.append(json.loads(line[len("ROUTE_CENSUS "):]))
    return legs, census


def row(label, legs, detour):
    ratios = [leg["driven_m"] / leg["shortest_m"] for leg in legs]
    over = sum(1 for r in ratios if r > detour)
    over15 = sum(1 for r in ratios if r > 1.5)
    excess = sum(max(0.0, leg["driven_m"] - leg["shortest_m"]) for leg in legs)
    driven = sum(leg["driven_m"] for leg in legs)
    return "%-26s %6d  p50 %.3f  p90 %.3f  p99 %.3f  max %6.2f  >%.1fx %5.1f%%  >1.5x %5.1f%%  excess %4.1f%% of %7.0f m" % (
        label, len(legs), quantile(ratios, 0.5), quantile(ratios, 0.9), quantile(ratios, 0.99), max(ratios) if ratios else 0.0,
        detour, 100.0 * over / max(1, len(legs)), 100.0 * over15 / max(1, len(legs)), 100.0 * excess / max(1.0, driven), driven)


def main(argv):
    detour = 1.3
    top = 20
    paths = []
    for arg in argv:
        if arg.startswith("--detour="):
            detour = float(arg.split("=", 1)[1])
        elif arg.startswith("--top="):
            top = int(arg.split("=", 1)[1])
        else:
            paths.append(arg)
    legs, census = read(paths)
    print("ROUTE CENSUS: %d fights (%d with a census line), %d legs >= 15 m" % (len(paths), len(census), len(legs)))
    travel = [leg for leg in legs if leg["option"] in TRAVEL]
    other = [leg for leg in legs if leg["option"] not in TRAVEL]
    print(row("travel legs", travel, detour))
    print(row("fight legs (not travel)", other, detour))
    for team, name in ((0, "green"), (1, "rust")):
        print(row("  travel, " + name, [leg for leg in travel if leg["team"] == team], detour))
    print("by unit class (travel):")
    for unit in sorted({leg["unit"] for leg in travel}):
        print(row("  " + unit, [leg for leg in travel if leg["unit"] == unit], detour))
    print("by arena (travel):")
    for arena in sorted({leg["arena"] for leg in travel}):
        print(row("  " + arena, [leg for leg in travel if leg["arena"] == arena], detour))
    still = [leg for leg in travel if leg.get("goal_moved_m", 0.0) <= 5.0]
    print(row("travel, goal still (<=5 m)", still, detour))
    print(row("travel, goal moved (>5 m)", [leg for leg in travel if leg.get("goal_moved_m", 0.0) > 5.0], detour))
    print("by option (all legs):")
    for option in sorted({leg["option"] for leg in legs}):
        print(row("  " + (option or "(no brain)"), [leg for leg in legs if leg["option"] == option], detour))
    worst = sorted((leg for leg in travel if leg["driven_m"] > detour * leg["shortest_m"]),
                   key=lambda leg: leg["driven_m"] - leg["shortest_m"], reverse=True)[:top]
    print("worst travel detours (ratio > %.1f, by excess metres):" % detour)
    for leg in worst:
        print("  %-8s s%-6d %-22s %-10s %-9s %-11s ticks %5d-%5d  driven %6.1f  shortest %6.1f  x%.2f  goal moved %5.1f  replans %3d  %s -> %s" % (
            leg["arena"], leg["seed"], leg["n"], leg["unit"], leg["option"] or "-", leg["order"], leg["tick0"], leg["tick1"],
            leg["driven_m"], leg["shortest_m"], leg["driven_m"] / leg["shortest_m"], leg.get("goal_moved_m", 0.0), leg.get("replans", 0), leg["start"], leg["end"]))
    return 0 if legs else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

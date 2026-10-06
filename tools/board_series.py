#!/usr/bin/env python3
"""Round 19 (board, stretch d): how did the matches end? Reads match_series.py JSON files (one per map) and prints,
per map and overall: the reasons (counts), the time to finish, and among control wins how often the winner destroyed
FEWER credits than the loser (the matches a kills-count-toward-the-win rule could change). Counts, not rates, below
about 30 events (lesson 256)."""
import json
import re
import statistics
import sys


def unit_costs(path="game/units/units.gd"):
    """{unit_id: cost} read from the catalogue's PROFILES (a one-tab-indented `"id": {` then its `"cost": N`)."""
    costs, current = {}, None
    for line in open(path):
        head = re.match(r'^\t"([a-z_0-9]+)": \{\s*$', line)
        if head:
            current = head.group(1)
            continue
        cost = re.match(r'^\t\t"cost": (\d+),', line)
        if cost and current and current not in costs:
            costs[current] = int(cost.group(1))
    return costs


COSTS = unit_costs()


def points_destroyed(result, side):
    # What `side` destroyed = the other side's losses, priced by the unit catalogue the run printed (cost per unit is
    # in the result's army_cost only as totals, so use losses_by_unit with the costs the series recorded, if any).
    other = "rust" if side == "green" else "green"
    prices = result.get("unit_costs", COSTS)
    losses = result.get("losses_by_unit", {}).get(other, {})
    if prices:
        return sum(prices.get(unit, 0) * n for unit, n in losses.items())
    return sum(losses.values())  # no prices recorded: a vehicle count


def summarise(name, results):
    reasons = {}
    durations = []
    disagree = 0
    control_wins = 0
    for r in results:
        reasons[r.get("reason", "?")] = reasons.get(r.get("reason", "?"), 0) + 1
        durations.append(float(r.get("duration_seconds", 0)))
        if r.get("reason") == "control" and r.get("winner") in ("Green", "Rust"):
            control_wins += 1
            winner = r["winner"].lower()
            loser = "rust" if winner == "green" else "green"
            if points_destroyed(r, winner) < points_destroyed(r, loser):
                disagree += 1
    print(f"{name}: {len(results)} matches; ended by {dict(sorted(reasons.items()))}; "
          f"seconds median {statistics.median(durations):.0f} (min {min(durations):.0f}, max {max(durations):.0f}); "
          f"control wins where the winner destroyed less: {disagree} of {control_wins}")


def main():
    everything = []
    for path in sys.argv[1:]:
        with open(path) as handle:
            results = json.load(handle).get("results", [])
        if results:
            summarise(path.rsplit("/", 1)[-1].removesuffix(".json"), results)
            everything.extend(results)
    if everything:
        summarise("all", everything)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Compare two faction-matrix arms PAIRED by seed and colour (research C6, round 10, combat).

Two arms run on the SAME seed list (faction_matrix's seeds 1..N, both colours) are two outcomes of one match each:
the same armies, the same spawn jitter, the same fire dice, differing only in the arm. Comparing their pooled win
rates throws that away and needs ~4x the matches for the same power. This reads each game of both arms (the
`games` list faction_matrix writes), pairs them by (faction, other, seed, colour), and reports per cell:

  pairs     games present in both arms
  b         the treatment won where the control did not (win vs loss/draw)
  c         the control won where the treatment did not
  p         exact two-sided McNemar p over the b + c discordant pairs (binomial, 0.5)

Discordant counts are printed beside every rate, never a pooled rate alone. The refusals are compare_arms' (same
file twice, two machines, two builds, different workload, identical arms): a paired comparison of two runs that
were not asked the same question is still not a comparison.

Usage: paired_arms.py --treatment build/faction-matrix-a.json --control build/faction-matrix-b.json [--json out.json]
"""
import argparse
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compare_arms  # noqa: E402


def mcnemar_p(b, c):
    """Exact two-sided McNemar: under no effect each discordant pair is a fair coin."""
    n = b + c
    if n == 0:
        return 1.0
    k = min(b, c)
    tail = sum(math.comb(n, i) for i in range(k + 1)) / 2 ** n
    return min(1.0, 2.0 * tail)


def games_by_key(data, path):
    if "games" not in data:
        raise SystemExit(f"REFUSED: {path} has no per-game 'games' list -- made by a faction_matrix that predates the "
                         f"paired comparison, so its games cannot be matched by seed")
    table = {}
    for game in data["games"]:
        key = (game["faction"], game["other"], int(game["seed"]), bool(game["first_is_green"]))
        table[key] = game
    return table


def won(game):
    mine = "green" if game["first_is_green"] else "rust"
    return game["winner"] == mine


def paired_cells(treatment, control):
    """{(faction, other): {"pairs", "b", "c", "treatment_wins", "control_wins", "p"}} over the games in both arms."""
    cells = {}
    for key, t_game in treatment.items():
        c_game = control.get(key)
        if c_game is None:
            continue
        cell = cells.setdefault(key[:2], {"pairs": 0, "b": 0, "c": 0, "treatment_wins": 0, "control_wins": 0})
        cell["pairs"] += 1
        t_won, c_won = won(t_game), won(c_game)
        cell["treatment_wins"] += t_won
        cell["control_wins"] += c_won
        if t_won and not c_won:
            cell["b"] += 1
        elif c_won and not t_won:
            cell["c"] += 1
    for cell in cells.values():
        cell["p"] = mcnemar_p(cell["b"], cell["c"])
    return cells


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--treatment", required=True)
    parser.add_argument("--control", required=True)
    parser.add_argument("--build-is-the-arm", default="")
    parser.add_argument("--json")
    args = parser.parse_args()
    treatment, control = compare_arms.load(args.treatment), compare_arms.load(args.control)
    problems = compare_arms.refusals(treatment, control, (args.treatment, args.control), args.build_is_the_arm,
                                     (compare_arms.sha256(args.treatment), compare_arms.sha256(args.control)))
    if problems:
        print("REFUSED:")
        for line in problems:
            print("  " + line)
        return 2
    cells = paired_cells(games_by_key(treatment, args.treatment), games_by_key(control, args.control))
    if not cells:
        print("REFUSED: no game appears in both arms -- the two seed lists do not overlap, so nothing is paired")
        return 2
    print(f"treatment {args.treatment}\ncontrol   {args.control}")
    print(f"{'cell':32} {'pairs':>5} {'treat':>7} {'ctrl':>7} {'b':>4} {'c':>4} {'p':>7}")
    for (faction, other), cell in sorted(cells.items()):
        pairs = cell["pairs"]
        print(f"{faction + ' vs ' + other:32} {pairs:5d} {cell['treatment_wins'] / pairs:7.0%} "
              f"{cell['control_wins'] / pairs:7.0%} {cell['b']:4d} {cell['c']:4d} {cell['p']:7.3f}")
    if args.json:
        with open(args.json, "w") as handle:
            json.dump({"treatment": args.treatment, "control": args.control,
                       "cells": [dict(cell, faction=f, other=o) for (f, o), cell in sorted(cells.items())]},
                      handle, indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())

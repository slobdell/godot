#!/usr/bin/env python3
"""Combat X6: try several --tune variants of the matchup matrix and score each against the designed counters
(`make matchup-search VARIANTS=tools/matchup_variants/x6_round1.json`).

VARIANTS is a JSON object {"name": "unit.stat=v,weapon.stat=v", ...} (an empty string = the catalog as it is). Each
variant plays the matrix for UNITS (default: every unit), and the tool prints, per variant, every designed counter's
win share, how many hold at >= 65%, the worst one, and the average fight length; best variant first. Designed counters
come from each unit's good_vs and weak_vs roles in game/units/units.gd, restricted to the units played.

Usage: matchup_search.py --godot PATH --variants FILE [--units tank,ifv,...] [--seeds 2] [--jobs 6] [--budget 600]
"""
import argparse
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.dont_write_bytecode = True  # importing matchup_matrix must not leave tools/__pycache__ in the checkout
sys.path.insert(0, os.path.join(ROOT, "tools"))
import matchup_matrix  # noqa: E402

BAR = 0.65


def designed_counters(ids):
    """[(winner, loser)] from good_vs and (inverted) weak_vs role lists; every unit's role is its id in the starting
    roster. Sorted and without duplicates."""
    text = open(os.path.join(ROOT, "game", "units", "units.gd")).read()
    pairs = set()
    for match in re.finditer(r'\n\t"(\w+)": \{(.*?)\n\t\},', text, re.S):
        unit, body = match.group(1), match.group(2)
        if unit not in ids:
            continue
        for key, beats in (("good_vs", True), ("weak_vs", False)):
            listed = re.search(r'"%s": \[([^\]]*)\]' % key, body)
            for role in re.findall(r'"(\w+)"', listed.group(1)) if listed else []:
                if role in ids and role != unit:
                    pairs.add((unit, role) if beats else (role, unit))
    return sorted(pairs)


def shares(report, units, escort=""):
    tally = {}
    for match in report["matches"]:
        a, b = match["a"], match["b"]
        outcome = matchup_matrix.verdict(match["result"], units, escort)
        row = tally.setdefault((a, b), {"a": 0.0, "b": 0.0, "n": 0, "seconds": 0.0})
        row["n"] += 1
        row["seconds"] += match["result"]["duration_seconds"]
        if outcome == "draw":
            row["a"] += 0.5
            row["b"] += 0.5
        elif (outcome == "green") == match["a_is_green"]:
            row["a"] += 1
        else:
            row["b"] += 1
    result, seconds, n = {}, 0.0, 0
    for (a, b), row in tally.items():
        result[(a, b)] = row["a"] / row["n"]
        result[(b, a)] = row["b"] / row["n"]
        seconds += row["seconds"]
        n += row["n"]
    return result, seconds / max(n, 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--variants", required=True)
    parser.add_argument("--units", default="")
    parser.add_argument("--seeds", type=int, default=2)
    parser.add_argument("--jobs", type=int, default=6)
    parser.add_argument("--budget", type=int, default=600)
    parser.add_argument("--escort", default="")
    args = parser.parse_args()

    variants = json.load(open(args.variants))
    out_dir = os.path.join(ROOT, "build", "matchup_search")
    os.makedirs(out_dir, exist_ok=True)
    rows = []
    for name, tune in variants.items():
        report_path = os.path.join(out_dir, f"{name}.json")
        command = [sys.executable, os.path.join(ROOT, "tools", "matchup_matrix.py"), "--godot", args.godot,
                   "--seeds", str(args.seeds), "--jobs", str(args.jobs), "--budget", str(args.budget), "--json", report_path]
        for flag, value in (("--units", args.units), ("--tune", tune), ("--escort", args.escort)):
            if value:
                command += [flag, value]
        subprocess.run(command, check=True, capture_output=True, text=True)
        report = json.load(open(report_path))
        units = matchup_matrix.tuned_costs(matchup_matrix.catalog(), tune)
        ids = list(report["armies"].keys())
        table, seconds = shares(report, units, args.escort)
        counters = designed_counters(ids)
        held = [(w, l, table.get((w, l), 0.0)) for w, l in counters]
        wins_something = {u: any(table.get((u, o), 0.0) >= 0.5 for o in ids if o != u) for u in ids}
        score = sum(min(s, BAR) for _, _, s in held) / max(len(held), 1)
        rows.append((score, name, tune, held, seconds, wins_something))
        print(f"done {name}: score {score:.3f}", flush=True)
    rows.sort(key=lambda row: -row[0])
    for score, name, tune, held, seconds, wins_something in rows:
        ok = sum(1 for _, _, s in held if s >= BAR)
        worst = min(held, key=lambda h: h[2]) if held else ("-", "-", 0.0)
        print(f"\n== {name}  score {score:.3f}  counters {ok}/{len(held)} >= {BAR:.0%}  worst {worst[0]}>{worst[1]} "
              f"{worst[2]:.0%}  avg fight {seconds:.0f} s  tune: {tune or '(catalog)'}")
        print("   " + "  ".join(f"{w}>{l} {s:.0%}" for w, l, s in held))
        losers = [u for u, won in wins_something.items() if not won]
        if losers:
            print(f"   wins nothing: {', '.join(losers)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

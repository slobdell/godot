#!/usr/bin/env python3
"""Rules R7: the unit-vs-unit matchup matrix (`make matchups`).

For every pair of unit types, plays cost-equal armies of one type against the other: seeded, on both base
sides, with each type playing both team colors. A match that times out goes to the side with more of its
army's cost still alive. Prints the matrix and, with --balance, writes it between the MATCHUP markers in
_agents/balance.md. Units and costs are read from game/units/units.gd, so a tuning change is measured as-is;
--tune passes Units.apply_tuning overrides to every match (try a number before editing the catalog).

Usage: matchup_matrix.py --godot PATH [--budget 600] [--seeds 3] [--jobs 2] [--time-limit 180]
                         [--units scout,tank,...] [--arena foundry] [--tune unit.stat=v,...] [--json out] [--balance]
"""
import argparse
import concurrent.futures
import itertools
import json
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build", "matchups")
BALANCE = os.path.join(ROOT, "_agents", "balance.md")
BEGIN, END = "<!-- MATCHUP MATRIX BEGIN -->", "<!-- MATCHUP MATRIX END -->"
MAX_SQUAD = 5


def catalog():
    """{unit_id: {"cost": int, "unlock_tier": int}} parsed from units.gd (ids in catalog order)."""
    text = open(os.path.join(ROOT, "game", "units", "units.gd")).read()
    units = {}
    for match in re.finditer(r'\n\t"(\w+)": \{(.*?)\n\t\},', text, re.S):
        body = match.group(2)
        cost = re.search(r'"cost": (\d+)', body)
        if cost and '"role"' in body:
            units[match.group(1)] = {"cost": int(cost.group(1))}
    return units


def tuned_costs(units, tune):
    for pair in filter(None, tune.split(",")):
        key, value = pair.split("=")
        parts = key.split(".")
        if len(parts) == 2 and parts[0] in units and parts[1] == "cost":
            units[parts[0]]["cost"] = int(float(value))
    return units


def army(unit_id, cost, budget, escort=""):
    """The count of `unit_id` whose total cost is closest to `budget` (at least 1), in squads of 5, plus an
    optional escort unit outside the budget (the same for both sides: e.g. a spotter for artillery)."""
    count = max(1, round(budget / cost))
    squads = []
    for index in range(0, count, MAX_SQUAD):
        squads.append({"name": f"{unit_id.capitalize()}{index // MAX_SQUAD + 1}", "directive": {"role": "assault"},
                       "units": [{"unit": unit_id}] * min(MAX_SQUAD, count - index)})
    if escort:
        squads.append({"name": "Escort", "directive": {"role": "scout"}, "units": [{"unit": escort}]})
    return {"name": f"{count} x {unit_id}", "squads": squads}, count, count * cost


def run_match(args, green_file, rust_file, seed, swap):
    command = [args.godot, "--headless", "--fixed-fps", "60", "--path", ROOT, "--", "--match", "--elimination",
               f"--green-doctrine=res://build/matchups/{green_file}", f"--rust-doctrine=res://build/matchups/{rust_file}",
               f"--time-limit={args.time_limit}", f"--seed={seed}", f"--budget={args.budget * 2}"]
    if swap:
        command.append("--swap-bases")
    if args.arena:
        command.append(f"--arena={args.arena}")
    if args.tune:
        command.append(f"--tune={args.tune}")
    completed = subprocess.run(command, capture_output=True, text=True, timeout=args.time_limit + 180)
    for line in completed.stdout.splitlines():
        if line.startswith("MATCH_RESULT "):
            return json.loads(line[len("MATCH_RESULT "):])
    errors = [l for l in (completed.stdout + completed.stderr).splitlines() if "ERROR" in l][:5]
    raise RuntimeError(f"{green_file} vs {rust_file} seed {seed}: no MATCH_RESULT (exit {completed.returncode}) {errors}")


def value_left(result, side, units, escort=""):
    """Share of a side's measured army (the escort excluded) still alive at the end."""
    losses = dict(result.get("losses_by_unit", {}).get(side, {}))
    cost = result["army_cost"][side]
    if escort:
        losses.pop(escort, None)
        cost -= units[escort]["cost"]
    lost = sum(units[u]["cost"] * n for u, n in losses.items())
    cost = max(cost, 1)
    return (cost - lost) / cost


def verdict(result, units, escort=""):
    """"green", "rust", or "draw". Elimination decides; a timeout (or any match with an escort, whose survival
    shouldn't count) goes to the larger share of measured army value left."""
    if not escort and result["reason"] == "elimination" and result["winner"] in ("Green", "Rust"):
        return result["winner"].lower()
    green, rust = value_left(result, "green", units, escort), value_left(result, "rust", units, escort)
    if abs(green - rust) < 0.1:
        return "draw"
    return "green" if green > rust else "rust"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--budget", type=int, default=600, help="points per side (counts round to the nearest)")
    parser.add_argument("--seeds", type=int, default=3, help="seeds per configuration (x2 bases x2 colors)")
    parser.add_argument("--first-seed", type=int, default=1)
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--time-limit", type=int, default=180)
    parser.add_argument("--units", default="", help="comma-separated subset")
    parser.add_argument("--arena", default="")
    parser.add_argument("--tune", default="")
    parser.add_argument("--mirrors", action="store_true", help="also play each unit against itself (fairness)")
    parser.add_argument("--escort", default="", help="a unit type both sides get outside the budget (e.g. scout: a spotter)")
    parser.add_argument("--focus", default="", help="only pairs that include this unit")
    parser.add_argument("--json")
    parser.add_argument("--balance", action="store_true", help="write the matrix into _agents/balance.md")
    args = parser.parse_args()

    units = tuned_costs(catalog(), args.tune)
    ids = [u for u in units if not args.units or u in args.units.split(",")]
    os.makedirs(BUILD, exist_ok=True)
    armies = {}
    for unit_id in ids:
        doctrine, count, cost = army(unit_id, units[unit_id]["cost"], args.budget, args.escort)
        with open(os.path.join(BUILD, f"{unit_id}.json"), "w") as handle:
            json.dump(doctrine, handle)
        armies[unit_id] = (count, cost)

    pairs = list(itertools.combinations(ids, 2)) + ([(u, u) for u in ids] if args.mirrors else [])
    if args.focus:
        pairs = [pair for pair in pairs if args.focus in pair]
    jobs = []
    for a, b in pairs:
        for seed in range(args.first_seed, args.first_seed + args.seeds):
            for swap in (False, True):
                for a_is_green in (True, False):
                    jobs.append((a, b, seed, swap, a_is_green))

    started = time.time()
    tally = {pair: {"a": 0, "b": 0, "draw": 0, "friendly": 0.0, "seconds": 0.0, "n": 0} for pair in pairs}
    failures = []
    raw = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {}
        for a, b, seed, swap, a_is_green in jobs:
            green, rust = (a, b) if a_is_green else (b, a)
            futures[pool.submit(run_match, args, f"{green}.json", f"{rust}.json", seed, swap)] = (a, b, a_is_green)
        for future in concurrent.futures.as_completed(futures):
            a, b, a_is_green = futures[future]
            try:
                result = future.result()
            except Exception as err:
                failures.append(str(err))
                continue
            raw.append({"a": a, "b": b, "a_is_green": a_is_green, "result": result})
            outcome = verdict(result, units, args.escort)
            row = tally[(a, b)]
            row["n"] += 1
            row["seconds"] += result["duration_seconds"]
            row["friendly"] += sum(result["stats"].get("friendly_damage", [0, 0]))
            if outcome == "draw":
                row["draw"] += 1
            elif (outcome == "green") == a_is_green:
                row["a"] += 1
            else:
                row["b"] += 1

    # win share of the ROW unit against the COLUMN unit (draws count half)
    share = {}
    for (a, b), row in tally.items():
        if row["n"]:
            share[(a, b)] = (row["a"] + row["draw"] / 2) / row["n"]
            share[(b, a)] = (row["b"] + row["draw"] / 2) / row["n"]
    lines = [f"Cost-equal armies at ~{args.budget} points per side ({', '.join(f'{u} {armies[u][0]}x = {armies[u][1]}' for u in ids)}); "
             f"{args.seeds} seeds x both bases x both colors = {4 * args.seeds} matches per pair, {args.time_limit} s limit"
             f"{', arena ' + args.arena if args.arena else ''}{', tune ' + args.tune if args.tune else ''}"
             f"{', each side escorted by 1 ' + args.escort + ' (outside the budget and the verdict)' if args.escort else ''}. "
             "Cell = the ROW unit's win share against the COLUMN unit (draws count half; a timeout goes to the side with more army value left).", "",
             "| row beats column | " + " | ".join(ids) + " |", "|---|" + "---|" * len(ids)]
    for a in ids:
        cells = []
        for b in ids:
            if (a, b) in share:
                cells.append(f"**{share[(a, b)]:.0%}**" if share[(a, b)] >= 0.65 else f"{share[(a, b)]:.0%}")
            else:
                cells.append("—")
        lines.append(f"| {a} | " + " | ".join(cells) + " |")
    lines.append("")
    lines.append("| pair | row wins : column wins : draws | avg length | friendly damage / match |")
    lines.append("|---|---|---|---|")
    for (a, b), row in tally.items():
        if row["n"]:
            lines.append(f"| {a} vs {b} | {row['a']} : {row['b']} : {row['draw']} | {row['seconds'] / row['n']:.0f} s | {row['friendly'] / row['n']:.0f} |")
    table = "\n".join(lines)
    print(table)
    print(f"\n{len(raw)} matches in {time.time() - started:.0f} s wall, {args.jobs} jobs")
    for failure in failures:
        print("  FAILED: " + failure)
    if args.json:
        with open(args.json, "w") as handle:
            json.dump({"args": vars(args), "armies": armies, "matches": raw, "failures": failures}, handle, indent=1)
    if args.balance and not failures:
        text = open(BALANCE).read()
        stamp = time.strftime("%Y-%m-%d")
        block = f"{BEGIN}\n_Measured {stamp} with `tools/matchup_matrix.py` (commit {git_head()})._\n\n{table}\n{END}"
        if BEGIN in text:
            text = re.sub(re.escape(BEGIN) + ".*?" + re.escape(END), lambda _: block, text, flags=re.S)
        else:
            text += "\n" + block + "\n"
        open(BALANCE, "w").write(text)
        print(f"wrote the matrix into {BALANCE}")
    sys.exit(1 if failures else 0)


def git_head():
    try:
        return subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    except OSError:
        return "?"


if __name__ == "__main__":
    main()

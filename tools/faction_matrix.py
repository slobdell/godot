#!/usr/bin/env python3
"""X6 (round 4, combat): every faction pair fought at the same budget, counterbalanced.

Faction identity is supposed to live in cost and effectiveness, not in a faction-wide bonus, so the check is that
any pair lands near 50% once both sides play the same number of matches from each colour (game_design.md
*Factions*: "any faction pair is near 50/50 when both sides build good armies"). Each pairing runs `--seeds` matches
with faction A as Green and the same seeds again with A as Rust, which cancels both the side advantage and any
team-identity effect in one pass.

Usage: faction_matrix.py --godot PATH [--budget 5200] [--seeds 6] [--jobs 2] [--time-limit 180] [--json out.json]

Reported per pairing: win rate for the first faction, average match length, average vehicles fielded and lost, and
the suppression the loser was under (Match.stats, added in round 4 L2) — a pairing that is decided by suppression
should show it.
"""
import argparse
import concurrent.futures
import itertools
import json
import subprocess
import sys
import time
import os

# The simulation tick rate (the Makefile exports SIM_HZ; SimClock.TICK_RATE in game/match/sim_clock.gd).
SIM_HZ = os.environ.get("SIM_HZ", "60")

FACTIONS = ["gangs", "condemned", "law", "syndicate"]


def run_match(godot, green, rust, seed, budget, time_limit):
    command = [godot, "--headless", "--fixed-fps", SIM_HZ, "--path", ".", "--", "--match", "--elimination", "--control",
               f"--green-faction={green}", f"--rust-faction={rust}", f"--budget={budget}",
               f"--time-limit={time_limit}", "--score-limit=0", f"--seed={seed}"]
    done = subprocess.run(command, capture_output=True, text=True, timeout=time_limit + 300)
    for line in done.stdout.splitlines():
        if line.startswith("MATCH_RESULT "):
            return json.loads(line[len("MATCH_RESULT "):])
    errors = [l for l in (done.stdout + done.stderr).splitlines() if "ERROR" in l][:3]
    raise RuntimeError(f"{green} vs {rust} seed {seed}: no MATCH_RESULT (exit {done.returncode}) {errors}")


def mean(values):
    values = [v for v in values if v is not None]
    return sum(values) / len(values) if values else 0.0


def summarize(faction, other, results):
    """Win rate and shape of one pairing. `results` is [(result, faction_played_green)]."""
    wins = draws = 0
    sizes, losses, lengths, suppression = [], [], [], []
    for result, as_green in results:
        mine = "green" if as_green else "rust"
        theirs = "rust" if as_green else "green"
        winner = result["winner"].lower()
        if winner == "draw":
            draws += 1
        elif winner == mine:
            wins += 1
        sizes.append(result["units_lost"][mine] + result["units_left"][mine])
        losses.append(result["units_lost"][mine])
        lengths.append(result["duration_seconds"])
        team = 0 if as_green else 1
        samples = result["stats"].get("suppression_samples", [0, 0])[team]
        if samples:
            suppression.append(result["stats"].get("suppression_total", [0, 0])[team] / samples)
    played = max(len(results), 1)
    return {"faction": faction, "versus": other, "matches": len(results),
            "win_rate": wins / played, "draws": draws,
            "vehicles": round(mean(sizes), 1), "lost": round(mean(losses), 1),
            "seconds": round(mean(lengths), 1), "suppression": round(mean(suppression), 3)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--budget", type=int, default=5200)
    parser.add_argument("--seeds", type=int, default=6)
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--time-limit", type=int, default=180)
    parser.add_argument("--factions", default=",".join(FACTIONS))
    parser.add_argument("--json")
    args = parser.parse_args()

    factions = [f.strip() for f in args.factions.split(",") if f.strip()]
    jobs = []
    for first, second in itertools.combinations(factions, 2):
        for seed in range(1, args.seeds + 1):
            jobs.append((first, second, seed, True))    # first plays Green
            jobs.append((second, first, seed, False))   # ...and the same seed from the other colour
    started = time.time()
    outcomes, failures = {}, []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(run_match, args.godot, green, rust, seed, args.budget, args.time_limit):
                   (green, rust, seed, first_is_green) for green, rust, seed, first_is_green in jobs}
        for future in concurrent.futures.as_completed(futures):
            green, rust, seed, first_is_green = futures[future]
            try:
                result = future.result()
            except Exception as err:
                failures.append(str(err))
                continue
            faction, other = (green, rust) if first_is_green else (rust, green)
            outcomes.setdefault((faction, other), []).append((result, first_is_green))

    rows = [summarize(faction, other, results) for (faction, other), results in sorted(outcomes.items())]
    print(f"{len(jobs) - len(failures)} matches at {args.budget} points, {time.time() - started:.0f}s wall, "
          f"{args.jobs} jobs (each pairing counterbalanced: same seeds from both colours)")
    print(f"{'pairing':28} {'win%':>6} {'matches':>8} {'vehicles':>9} {'lost':>6} {'length':>8} {'suppr':>7}")
    for row in sorted(rows, key=lambda r: -r["win_rate"]):
        print(f"{row['faction'] + ' vs ' + row['versus']:28} {row['win_rate']:6.0%} {row['matches']:8d} "
              f"{row['vehicles']:9.1f} {row['lost']:6.1f} {row['seconds']:7.1f}s {row['suppression']:7.3f}")
    for failure in failures:
        print("  FAILED: " + failure)
    if args.json:
        with open(args.json, "w") as handle:
            json.dump({"args": vars(args), "rows": rows, "failures": failures}, handle, indent=2)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()

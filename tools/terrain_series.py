#!/usr/bin/env python3
"""R9's paired series (terrain, round 10): a terrain map against its dry twin on the SAME seeds (C6).

For every seed, the same match (same armies, same flags) runs on `<map>` and on `<map>_dry`, under
`game/theme/arena_kit/terrain/tools/terrain_probe.gd`. The only difference between the arms is the water. Reported:
  - per arm: median crossing_share (unit-time on the bridges/causeways), contested_share (time at the ENEMY's
    objective over time at either), hits, match length;
  - per seed, the paired difference wet - dry, and the DISCORDANT counts (seeds where wet > dry vs wet < dry), with
    a two-sided sign test -- a rate without its discordant pairs is not a paired result;
  - winner flips between the arms.
POSITIVE CONTROL: every wet run must report terrain_entries > 0 and every dry run 0, or the pair is refused.

Usage: terrain_series.py --godot PATH --map crossing [--seeds 32] [--first-seed 1] [--jobs 3]
                         [--faction condemned] [--budget 5200] [--time-limit 180] [--json out.json]
"""
import argparse
import concurrent.futures
import json
import math
import os
import statistics
import subprocess
import sys

SIM_HZ = os.environ.get("SIM_HZ", "60")
PROBE = "res://game/theme/arena_kit/terrain/tools/terrain_probe.gd"


def run(args, arena, seed):
    command = [args.godot, "--headless", "--fixed-fps", SIM_HZ, "--path", ".", "--script", PROBE, "--",
               "--match", "--elimination", "--control", f"--arena={arena}", f"--seed={seed}",
               f"--green-faction={args.faction}", f"--rust-faction={args.faction}",
               f"--budget={args.budget}", f"--time-limit={args.time_limit}"]
    done = subprocess.run(command, capture_output=True, text=True, timeout=args.time_limit * 4 + 240)
    out = {"arena": arena, "seed": seed}
    for line in done.stdout.splitlines():
        if line.startswith("TERRAIN_PROBE "):
            out["probe"] = json.loads(line[len("TERRAIN_PROBE "):])
    if "probe" not in out:
        errors = [l for l in (done.stdout + done.stderr).splitlines() if "ERROR" in l][:5]
        raise RuntimeError(f"{arena} seed {seed}: no TERRAIN_PROBE (exit {done.returncode}) {errors}")
    if out["probe"]["arena"] != arena:
        raise RuntimeError(f"{arena} seed {seed}: ran on '{out['probe']['arena']}' (layout refused?)")
    wet = not arena.endswith("_dry")
    if (out["probe"]["terrain_entries"] > 0) != wet:
        raise RuntimeError(f"{arena} seed {seed}: terrain_entries={out['probe']['terrain_entries']} -- the arm did not apply")
    return out


def sign_test(plus, minus):
    """Two-sided exact sign test p-value over the discordant pairs."""
    n = plus + minus
    if n == 0:
        return 1.0
    k = min(plus, minus)
    tail = sum(math.comb(n, i) for i in range(k + 1)) / 2 ** n
    return min(1.0, 2 * tail)


def paired(runs, key):
    by = {}
    for r in runs:
        by.setdefault(r["seed"], {})[r["arena"].endswith("_dry")] = r["probe"][key]
    diffs = [v[False] - v[True] for v in by.values() if len(v) == 2]
    plus = sum(1 for d in diffs if d > 0)
    minus = sum(1 for d in diffs if d < 0)
    return {"pairs": len(diffs), "median_diff": round(statistics.median(diffs), 4) if diffs else None,
            "mean_diff": round(statistics.mean(diffs), 4) if diffs else None,
            "wet_higher": plus, "dry_higher": minus, "ties": len(diffs) - plus - minus,
            "sign_test_p": round(sign_test(plus, minus), 4)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", required=True)
    ap.add_argument("--map", required=True)
    ap.add_argument("--seeds", type=int, default=32)
    ap.add_argument("--first-seed", type=int, default=1)
    ap.add_argument("--jobs", type=int, default=3)
    ap.add_argument("--faction", default="condemned")
    ap.add_argument("--budget", type=int, default=5200)
    ap.add_argument("--time-limit", type=int, default=180)
    ap.add_argument("--json")
    args = ap.parse_args()
    seeds = list(range(args.first_seed, args.first_seed + args.seeds))
    jobs = [(a, s) for s in seeds for a in (args.map, args.map + "_dry")]
    runs = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for r in pool.map(lambda j: run(args, *j), jobs):
            runs.append(r)
            p = r["probe"]
            print("TERRAIN_RUN %-12s seed %3d  crossing %.4f  contested %.3f  hits %4d  %s in %.0fs"
                  % (r["arena"], r["seed"], p["crossing_share"], p["contested_share"], p["hits"], p["winner"],
                     p["sim_seconds"]), flush=True)
    arms = {}
    for arena in (args.map, args.map + "_dry"):
        mine = [r["probe"] for r in runs if r["arena"] == arena]
        arms[arena] = {k: round(statistics.median(p[k] for p in mine), 4)
                       for k in ("crossing_share", "contested_share", "hits", "sim_seconds")}
    winners = {}
    for r in runs:
        winners.setdefault(r["seed"], {})[r["arena"]] = r["probe"]["winner"]
    flips = sum(1 for v in winners.values() if len(set(v.values())) > 1)
    report = {"map": args.map, "seeds": seeds, "faction": args.faction, "budget": args.budget,
              "time_limit": args.time_limit, "arms": arms,
              "paired": {k: paired(runs, k) for k in ("crossing_share", "contested_share", "hits")},
              "winner_flips": flips, "runs": runs}
    print("TERRAIN_SERIES " + json.dumps({k: v for k, v in report.items() if k != "runs"}))
    if args.json:
        os.makedirs(os.path.dirname(args.json) or ".", exist_ok=True)
        with open(args.json, "w") as f:
            json.dump(report, f, indent=1)


if __name__ == "__main__":
    sys.exit(main())

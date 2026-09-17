#!/usr/bin/env python3
"""Arena X4: prove each arena is fair and measure the fight it produces (_agents/arenas.md).

For every arena and seed, runs the same full-scale mirror match twice: normally, and with --swap-bases (Green starts
north). Same armies, same seed, only the bases change, so the SOUTH side's win rate over both runs is the fairness
control (verification.md). Each match runs under tests/arena/arena_probe.gd, which adds engagement ranges, flank use
and time hidden to the runner's MATCH_RESULT.

Usage: arena_series.py --godot PATH [--arenas yard,pit] [--seeds 8] [--jobs 3] [--faction condemned]
                       [--budget 5200] [--time-limit 180] [--json out.json]
"""
import argparse, concurrent.futures, json, os, statistics, subprocess, sys, time
import os

# The simulation tick rate (the Makefile exports SIM_HZ; SimClock.TICK_RATE in game/match/sim_clock.gd).
SIM_HZ = os.environ.get("SIM_HZ", "60")


def run(args, arena, seed, swap):
    command = [args.godot, "--headless", "--fixed-fps", SIM_HZ, "--path", ".", "--script", "res://tests/arena/arena_probe.gd", "--",
               "--match", "--elimination", "--control", f"--arena={arena}", f"--seed={seed}",
               f"--green-faction={args.green_faction or args.faction}", f"--rust-faction={args.rust_faction or args.faction}",
               f"--budget={args.budget}", f"--time-limit={args.time_limit}"] + (["--swap-bases"] if swap else [])
    completed = subprocess.run(command, capture_output=True, text=True, timeout=args.time_limit * 4 + 180)
    out = {"arena": arena, "seed": seed, "swap": swap}
    for line in completed.stdout.splitlines():
        if line.startswith("MATCH_RESULT "):
            out["result"] = json.loads(line[len("MATCH_RESULT "):])
        elif line.startswith("ARENA_PROBE "):
            out["probe"] = json.loads(line[len("ARENA_PROBE "):])
    if "result" not in out or "probe" not in out:
        errors = [l for l in (completed.stdout + completed.stderr).splitlines() if "ERROR" in l][:5]
        raise RuntimeError(f"{arena} seed {seed} swap={swap}: no result (exit {completed.returncode}) {errors}")
    if out["probe"]["arena"] != arena:
        raise RuntimeError(f"{arena} seed {seed}: the match ran on '{out['probe']['arena']}' (layout refused?)")
    return out


def summarize(runs):
    south_wins = draws = 0
    for r in runs:
        winner = r["result"]["winner"]
        if winner == "draw":
            draws += 1
        elif (winner == "Green") != r["swap"]:
            south_wins += 1
    decided = len(runs) - draws
    probes = [r["probe"] for r in runs]
    median = lambda key: round(statistics.median(p[key] for p in probes), 3) if probes else None
    reasons = {}
    for r in runs:
        reasons[r["result"]["reason"]] = reasons.get(r["result"]["reason"], 0) + 1
    return {"matches": len(runs), "south_win_rate": round(south_wins / decided, 3) if decided else None, "draws": draws,
            "reasons": reasons, "duration_s": median("sim_seconds"), "first_hit_s": median("first_hit_seconds"),
            "range_median_m": median("range_median_m"), "range_p90_m": median("range_p90_m"),
            "flank_share": median("flank_share"), "hidden_share": median("hidden_share")}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--arenas", default="")
    parser.add_argument("--seeds", type=int, default=8)
    parser.add_argument("--first-seed", type=int, default=1)
    parser.add_argument("--jobs", type=int, default=3)
    parser.add_argument("--faction", default="condemned")
    parser.add_argument("--green-faction", default="")
    parser.add_argument("--rust-faction", default="")
    parser.add_argument("--budget", type=int, default=5200)
    parser.add_argument("--time-limit", type=int, default=180)
    parser.add_argument("--json")
    args = parser.parse_args()
    arenas = [a for a in args.arenas.split(",") if a] or sorted(f[:-5] for f in os.listdir("arenas") if f.endswith(".json"))
    jobs = [(a, s, swap) for a in arenas for s in range(args.first_seed, args.first_seed + args.seeds) for swap in (False, True)]
    started = time.time()
    runs, failures = {a: [] for a in arenas}, []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = [pool.submit(run, args, *job) for job in jobs]
        for future in concurrent.futures.as_completed(futures):
            try:
                r = future.result()
                runs[r["arena"]].append(r)
            except Exception as err:
                failures.append(str(err))
    report = {"config": {"faction": args.faction, "green_faction": args.green_faction, "rust_faction": args.rust_faction,
                         "budget": args.budget, "time_limit": args.time_limit, "seeds": args.seeds},
              "arenas": {a: summarize(runs[a]) for a in arenas}, "failures": failures,
              "wall_seconds": round(time.time() - started, 1)}
    for arena, summary in report["arenas"].items():
        print("ARENA_SERIES " + json.dumps({"arena": arena, **summary}))
    for failure in failures:
        print("ARENA_SERIES_FAILURE " + failure)
    if args.json:
        os.makedirs(os.path.dirname(args.json) or ".", exist_ok=True)
        with open(args.json, "w") as f:
            json.dump({**report, "runs": runs}, f, indent=1)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Arena X4: prove each arena is fair and measure the fight it produces (_agents/arenas.md).

For every arena and seed, runs the same full-scale match twice: normally, and with --swap-bases (Green starts north).
Same seed, so the same two armies; only the bases change. The two armies are NOT alike (each team's army is seeded on
its own), and that difference decides most matches: measured 2026-09-17, no seed's winner flipped when the bases
swapped on any arena. So the fairness control is the paired `south_advantage` (see its docstring), with the south win
rate kept for reference (verification.md). Each match runs under tests/arena/arena_probe.gd, which adds engagement ranges, flank use
and time hidden to the runner's MATCH_RESULT.

Usage: arena_series.py --godot PATH [--arenas yard,pit] [--seeds 8] [--jobs 3] [--faction condemned]
                       [--budget 5200] [--time-limit 180] [--json out.json]
"""
import argparse, concurrent.futures, json, math, os, statistics, subprocess, sys, time

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
    # POSITIVE CONTROL: the treatment has to have engaged (_agents/verification.md). The whole fairness result is
    # the PAIRED difference between a normal run and a swapped one, so a --swap-bases that silently did not apply
    # would leave two identical arms and a perfectly plausible "no south advantage" — the answer we hope for,
    # arrived at by the run not happening. Asserting the requested arena was already here; this is its other half.
    if bool(out["probe"].get("swap_bases", False)) != bool(swap):
        raise RuntimeError(f"{arena} seed {seed}: asked for swap={swap} and the match reports "
                           f"swap_bases={out['probe'].get('swap_bases')}, so the pair is not a pair")
    return out


def south_advantage(runs):
    """The paired base effect. Each seed gives each team its own army, and army strength decides most matches, so a
    win rate can't see a small base advantage. For each seed played both ways: Green's margin in surviving share
    (Green's share left minus Rust's) with Green south, minus the same with Green north, halved = what being south is
    worth in surviving share. Also counts the seeds whose winner flipped when the bases swapped."""
    pairs = {}
    for r in runs:
        res = r["result"]
        share = lambda team: res["units_left"][team] / max(1, res["units_left"][team] + res["units_lost"][team])
        pairs.setdefault(r["seed"], {})[r["swap"]] = (share("green") - share("rust"), res["winner"])
    effects = [(v[False][0] - v[True][0]) / 2 for v in pairs.values() if len(v) == 2]
    flips = sum(1 for v in pairs.values() if len(v) == 2 and v[False][1] != v[True][1])
    if not effects:
        return {}
    sd = statistics.stdev(effects) if len(effects) > 1 else 0.0
    return {"south_advantage": round(statistics.mean(effects), 3), "south_advantage_se": round(sd / math.sqrt(len(effects)), 3),
            "pairs": len(effects), "winner_flips": flips}


def green_margin(runs):
    """Green's surviving-share margin over Rust averaged over both base assignments (bases cancel): with different
    factions on each side, how an arena tilts the matchup."""
    margins = []
    for r in runs:
        res = r["result"]
        share = lambda team: res["units_left"][team] / max(1, res["units_left"][team] + res["units_lost"][team])
        margins.append(share("green") - share("rust"))
    wins = sum(1 for r in runs if r["result"]["winner"] == "Green")
    return {"green_margin": round(statistics.mean(margins), 3) if margins else None,
            "green_win_rate": round(wins / len(runs), 3) if runs else None}


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
            "flank_share": median("flank_share"), "hidden_share": median("hidden_share"), **south_advantage(runs), **green_margin(runs)}


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

#!/usr/bin/env python3
"""Mapkit Bar P (round 47, workstreams.md *Bars (round 47)*): THE MAP-KIT TWINS CHANGE THE FIGHT.

Pairs parade v parade_traps, parade v parade_rail (condemned v condemned, seeds 12901-12916, both base orders) and
crossing v crossing_screens (his Crossing case, gangs v syndicate in BOTH faction orders x both base orders, seeds
12917-12932). Every match runs under tests/arena/arena_probe.gd (arena_series.run) to the map's own end (time limit
420 s). Raw runs -> --raw JSON; the verdict table -> stdout and --json. Native: whatever native/bin the folder holds (the
probe reports it; a run without native is refused).

Deciding (filed before any number): the twin changes the fight's shape -- engagement-range distribution or flank / route
use differs from the base beyond the seed spread; for crossing_screens the short-range side's (gangs') shots fired rise.
Guards: fairness (swap-bases margin within noise of 50 %), stall share no worse than the base, match length within the
base's spread and no stalemates (reason time-limit), laptop (measured separately, mapkit-gpu).
"""
import argparse, concurrent.futures, json, math, os, statistics, sys, types

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "tools"))
import arena_series  # noqa: E402

PARADE_SEEDS = range(12901, 12917)
CROSSING_SEEDS = range(12917, 12933)
TIME_LIMIT = 420


def jobs():
    out = []
    for arena in ("parade", "parade_traps", "parade_rail"):
        for seed in PARADE_SEEDS:
            for swap in (False, True):
                out.append((arena, seed, swap, "condemned", "condemned"))
    for arena in ("crossing", "crossing_screens"):
        for seed in CROSSING_SEEDS:
            for green, rust in (("gangs", "syndicate"), ("syndicate", "gangs")):
                for swap in (False, True):
                    out.append((arena, seed, swap, green, rust))
    return out


def one(godot, job):
    arena, seed, swap, green, rust = job
    args = types.SimpleNamespace(godot=godot, faction=green, green_faction=green, rust_faction=rust, budget=5200,
                                 time_limit=TIME_LIMIT)
    run = arena_series.run(args, arena, seed, swap)
    run.update({"green": green, "rust": rust})
    if not run["probe"].get("native", False):
        raise RuntimeError(f"{arena} {seed}: native was OFF (Bar P runs native ON)")
    return run


def mean_sd(values):
    values = [v for v in values if v is not None]
    if not values:
        return None, None, 0
    m = statistics.mean(values)
    sd = statistics.stdev(values) if len(values) > 1 else 0.0
    return m, sd, len(values)


def paired(base_runs, twin_runs, key):
    """Twin minus base for the SAME (seed, swap, factions): mean, its standard error, n."""
    index = {(r["seed"], r["swap"], r["green"]): r for r in base_runs}
    diffs = []
    for r in twin_runs:
        b = index.get((r["seed"], r["swap"], r["green"]))
        if b is not None:
            diffs.append(key(r) - key(b))
    m, sd, n = mean_sd(diffs)
    return {"mean": m, "se": (sd / math.sqrt(n)) if n > 1 else None, "n": n}


def gangs_shots(r):
    return r["probe"]["shots"]["green" if r["green"] == "gangs" else "rust"]


def summary(runs):
    by = {}
    for r in runs:
        by.setdefault(r["arena"], []).append(r)
    table = {}
    keys = {
        "range_median_m": lambda r: r["probe"]["range_median_m"],
        "range_p90_m": lambda r: r["probe"]["range_p90_m"],
        "flank_share": lambda r: r["probe"]["flank_share"],
        "hidden_share": lambda r: r["probe"]["hidden_share"],
        "crossed_share": lambda r: r["probe"]["crossed_share"],
        "stall_share": lambda r: r["probe"]["stall_share"],
        "sim_seconds": lambda r: r["probe"]["sim_seconds"],
    }
    for base, twin in (("parade", "parade_traps"), ("parade", "parade_rail"), ("crossing", "crossing_screens")):
        row = {"base": base, "twin": twin, "n_base": len(by.get(base, [])), "n_twin": len(by.get(twin, []))}
        for name, key in keys.items():
            row[name] = paired(by.get(base, []), by.get(twin, []), key)
            row[name + "_base"] = mean_sd([key(r) for r in by.get(base, [])])[:2]
        if base == "crossing":
            row["gangs_shots"] = paired(by[base], by[twin], gangs_shots)
            row["gangs_shots_base"] = mean_sd([gangs_shots(r) for r in by[base]])[:2]
        row["fairness_twin"] = arena_series.south_advantage(by.get(twin, []))
        row["fairness_base"] = arena_series.south_advantage(by.get(base, []))
        row["stalemates_twin"] = sum(1 for r in by.get(twin, []) if r["probe"].get("reason") == "time_limit")
        row["stalemates_base"] = sum(1 for r in by.get(base, []) if r["probe"].get("reason") == "time_limit")
        table[twin] = row
    return table


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--jobs", type=int, default=10)
    parser.add_argument("--raw", default="build/bar-p-raw.json")
    parser.add_argument("--json", default="build/bar-p.json")
    parser.add_argument("--only-arenas", default="")
    args = parser.parse_args()
    todo = jobs()
    if args.only_arenas:
        keep = set(args.only_arenas.split(","))
        todo = [j for j in todo if j[0] in keep]
    runs, failed = [], []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(one, args.godot, j): j for j in todo}
        for i, future in enumerate(concurrent.futures.as_completed(futures), 1):
            try:
                runs.append(future.result())
            except Exception as error:  # a failed run is reported, never dropped silently
                failed.append({"job": futures[future], "error": str(error)})
            print(f"BAR_P_PROGRESS {i}/{len(todo)} failed={len(failed)}", flush=True)
    os.makedirs(os.path.dirname(args.raw) or ".", exist_ok=True)
    json.dump({"runs": runs, "failed": failed}, open(args.raw, "w"))
    table = summary(runs)
    json.dump(table, open(args.json, "w"), indent=1)
    for twin, row in table.items():
        print("BAR_P " + json.dumps(row))
    print(f"BAR_P_DONE runs={len(runs)} failed={len(failed)}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

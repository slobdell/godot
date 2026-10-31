#!/usr/bin/env python3
"""Mapkit (round 47): CPU fights on terminus_doors watched by tests/arena/arena_probe.gd's door report -- doors open and
shut and the booth calls them; both sides route through them (crossings by side while open); nobody goes through a sealed
door; holds and overstays (manoeuvre's yield is OFF). Not a bar: reserve seeds 12949-12954, both base orders, native ON."""
import argparse, concurrent.futures, json, os, sys, types

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "tools"))
import arena_series  # noqa: E402


def one(godot, seed, swap):
    args = types.SimpleNamespace(godot=godot, faction="condemned", green_faction="condemned", rust_faction="condemned",
                                 budget=5200, time_limit=420)
    run = arena_series.run(args, "terminus_doors", seed, swap)
    return {"seed": seed, "swap": swap, "native": run["probe"]["native"], "reason": run["probe"]["reason"],
            "sim_seconds": run["probe"]["sim_seconds"], "stall_share": run["probe"]["stall_share"], "doors": run["probe"]["doors"]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--json", default="build/doors-watch.json")
    args = parser.parse_args()
    jobs = [(s, w) for s in range(12949, 12955) for w in (False, True)]
    runs = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        for run in pool.map(lambda j: one(args.godot, *j), jobs):
            runs.append(run)
            print("DOORS_WATCH " + json.dumps(run), flush=True)
    os.makedirs(os.path.dirname(args.json) or ".", exist_ok=True)
    json.dump(runs, open(args.json, "w"), indent=1)


if __name__ == "__main__":
    main()

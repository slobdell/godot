#!/usr/bin/env python3
"""Round 6, squad X6: `make squad-coherence` — how legible the army's behaviour is, as numbers.

Runs seeded faction matches in the configuration players actually get (faction armies at the baseline budget, the
control point on, elimination, the CPU's default brains) with `--squad-coherence`, and averages what CoherenceProbe
prints (game/tactics/coherence_probe.gd): idle-in-contact, drill flip-flopping, order thrash, off-slot and stale
orders. `--sides` adds the same flags a tactics-ladder side takes, e.g. `--green-elements --rust-elements` to measure
the element layer instead of brains-only.

Every report records its own conditions (commit, machine, workload, seeds), orchestration.md lesson 31.
"""
import argparse
import concurrent.futures
import json
import os
import platform
import statistics
import subprocess
import sys

SIM_HZ = os.environ.get("SIM_HZ", "30")
METRICS = ["idle_in_contact_share", "off_slot_share", "stale_order_share", "orders_per_unit_min",
           "drill_switches_per_element_min"]


def run(args, seed):
    command = [args.godot, "--headless", "--fixed-fps", SIM_HZ, "--path", ".", "--", "--match", "--elimination",
               "--control", f"--green-faction={args.green}", f"--rust-faction={args.rust}", f"--budget={args.budget}",
               f"--time-limit={args.time_limit}", f"--seed={seed}", "--squad-coherence", *args.extra.split()]
    completed = subprocess.run(command, capture_output=True, text=True, timeout=args.time_limit * 4 + 600)
    report = result = None
    for line in completed.stdout.splitlines():
        if line.startswith("SQUAD_COHERENCE "):
            report = json.loads(line[len("SQUAD_COHERENCE "):])
        elif line.startswith("MATCH_RESULT "):
            result = json.loads(line[len("MATCH_RESULT "):])
    if report is None:
        errors = [l for l in (completed.stdout + completed.stderr).splitlines() if "ERROR" in l][:5]
        raise RuntimeError(f"seed {seed}: no SQUAD_COHERENCE (exit {completed.returncode}) {errors}")
    report["seed"] = seed
    report["winner"] = (result or {}).get("winner")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--seeds", type=int, default=4)
    parser.add_argument("--first-seed", type=int, default=1)
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--green", default="condemned")
    parser.add_argument("--rust", default="law")
    parser.add_argument("--budget", type=int, default=5200)
    parser.add_argument("--time-limit", type=int, default=180)
    parser.add_argument("--extra", default="")
    parser.add_argument("--json", default="build/squad-coherence.json")
    args = parser.parse_args()
    seeds = list(range(args.first_seed, args.first_seed + args.seeds))
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        reports = list(pool.map(lambda s: run(args, s), seeds))
    summary = {}
    for side in ("green", "rust"):
        summary[side] = {}
        for metric in METRICS:
            values = [r[side][metric] for r in reports]
            summary[side][metric] = {"mean": round(statistics.mean(values), 4),
                                     "min": min(values), "max": max(values)}
    try:
        commit = subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip()
        dirty = subprocess.run(["git", "status", "--porcelain", "--untracked-files=no"], capture_output=True,
                               text=True).stdout.strip() != ""
    except OSError:
        commit, dirty = "?", True
    conditions = {"commit": commit + ("+dirty" if dirty else ""), "machine": platform.node(), "sim_hz": SIM_HZ,
                  "workload": f"{args.green} v {args.rust}, budget {args.budget}, control point, elimination, "
                              f"{args.time_limit} s limit, extra '{args.extra}'",
                  "seeds": seeds, "sample_size": f"{len(seeds)} matches"}
    output = {"conditions": conditions, "summary": summary, "matches": reports}
    os.makedirs(os.path.dirname(args.json) or ".", exist_ok=True)
    with open(args.json, "w") as handle:
        json.dump(output, handle, indent=1)
    print(f"SQUAD_COHERENCE_SUMMARY conditions {json.dumps(conditions)}")
    for side in ("green", "rust"):
        print(f"SQUAD_COHERENCE_SUMMARY {side} " + " ".join(
            f"{m}={summary[side][m]['mean']}" for m in METRICS))
    print("SQUAD_COHERENCE_DONE")


if __name__ == "__main__":
    sys.exit(main())

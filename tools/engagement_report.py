#!/usr/bin/env python3
"""Round 5 combat X1: what SHAPE do full-scale fights have? (`make engagement`)

Runs seeded headless faction battles (elimination + control point, the skirmish rules) and averages the
`stats.engagement` block Match fills (game/match/engagement_stats.gd): how far apart the armies fight, how much of
the fighting is a standing exchange, whether the armies' centres of mass move after contact, where kills come from,
and whether cover gets used. Each pairing runs from both colours (the same seeds), so base and colour bias cancel.

Usage: engagement_report.py --godot PATH [--pairs condemned:condemned,gangs:law] [--seeds 4] [--jobs 2]
                            [--budget 5200] [--time-limit 240] [--arena NAME] [--tune a.b=c,...] [--json out.json]
"""
import argparse
import concurrent.futures
import json
import statistics
import subprocess
import sys
import time
import os

# The simulation tick rate (the Makefile exports SIM_HZ; SimClock.TICK_RATE in game/match/sim_clock.gd).
SIM_HZ = os.environ.get("SIM_HZ", "60")


def run(args, green, rust, seed, tune=None):
    command = [args.godot, "--headless", "--fixed-fps", SIM_HZ, "--path", ".", "--", "--match", "--elimination",
               "--control", f"--green-faction={green}", f"--rust-faction={rust}", f"--budget={args.budget}",
               f"--time-limit={args.time_limit}", "--score-limit=0", f"--seed={seed}"]
    if args.arena:
        command.append(f"--arena={args.arena}")
    tune = args.tune if tune is None else tune
    if tune:
        command.append(f"--tune={tune}")
    completed = subprocess.run(command, capture_output=True, text=True, timeout=args.time_limit * 4 + 240)
    for line in completed.stdout.splitlines():
        if line.startswith("MATCH_RESULT "):
            result = json.loads(line[len("MATCH_RESULT "):])
            result["pairing"] = {"green": green, "rust": rust}
            return result
    errors = [l for l in (completed.stdout + completed.stderr).splitlines() if "ERROR" in l][:5]
    raise RuntimeError(f"{green} vs {rust} seed {seed}: no MATCH_RESULT (exit {completed.returncode}) {errors}")


def mean(values, signed=False):
    """Average, skipping None and (unless signed) the -1 "no data" marker EngagementStats uses."""
    values = [v for v in values if v is not None and (signed or v >= 0)]
    return statistics.fmean(values) if values else float("nan")


def summarize(results):
    engagement = [r["stats"]["engagement"] for r in results]
    kills = {face: sum(e["kills"][face] for e in engagement) for face in ("front", "side", "rear", "indirect")}
    direct = kills["front"] + kills["side"] + kills["rear"]
    return {
        "matches": len(results),
        "duration_s": mean([r["duration_seconds"] for r in results]),
        "contact_s": mean([e["contact_second"] for e in engagement]),
        "separation_at_contact_m": mean([e["separation_at_contact"] for e in engagement]),
        "engaged_distance_m": mean([e["engaged_distance_median"] for e in engagement]),
        "kill_distance_m": mean([e["kill_distance_median"] for e in engagement]),
        # N5 (round 6): the two figures that would catch the envelope overshooting into a QUIET fight. Reported in
        # every configuration including the old-world control, because "quieter than before" is only visible against it.
        "shots_per_unit_minute": mean([e.get("shots_per_unit_minute") for e in engagement]),
        # N5: direct-fire only, alongside the all-shots figures rather than instead of them, so round 5's baseline
        # stays comparable. The envelope governs direct fire; artillery is outside it and would otherwise set
        # "contact" from 160 m and hold "engaged" at the separation of two armies that are not yet fighting.
        "direct_contact_s": mean([e.get("direct_contact_second") for e in engagement]),
        "engaged_distance_direct_m": mean([e.get("engaged_distance_direct_median") for e in engagement]),
        "static_share": mean([e["static_share"] for e in engagement]),
        "held_line_share": mean([e.get("held_line_share") for e in engagement]),
        "net_advance_m": mean([max(e.get("net_advance", [0, 0])) for e in engagement], signed=True),  # the side that pushed
        "off_axis_kill_share": mean([e.get("off_axis_kill_share") for e in engagement]),
        "behind_line_kill_share": mean([e.get("behind_line_kill_share") for e in engagement]),
        "centroid_travel_m": mean([sum(e["centroid_travel"]) / 2.0 for e in engagement]),
        "kills": kills,
        "flank_rear_kill_share": (kills["side"] + kills["rear"]) / direct if direct else float("nan"),
        "rear_kill_share": kills["rear"] / direct if direct else float("nan"),
        "indirect_kill_share": kills["indirect"] / max(1, direct + kills["indirect"]),
        "unit_seconds_near_cover": mean([e["unit_seconds_near_cover_share"] for e in engagement]),
        "shots_near_cover": mean([e["shots_near_cover_share"] for e in engagement]),
        "deaths_near_cover": mean([e["deaths_near_cover_share"] for e in engagement]),
        "killers_near_cover": mean([e["kills_by_cover_shooters_share"] for e in engagement]),
        "reasons": {reason: sum(1 for r in results if r["reason"] == reason) for reason in {r["reason"] for r in results}},
    }


def print_row(label, s):
    print(f"{label:<24} n={s['matches']:<3} len {s['duration_s']:5.0f}s  1st shot {s['contact_s']:4.0f}s "
          f"fire {s['shots_per_unit_minute']:5.1f}/unit/min  "
          f"@{s['separation_at_contact_m']:4.0f}m  engaged {s['engaged_distance_m']:4.0f}m "
          f"(direct {s['engaged_distance_direct_m']:4.0f}m @{s['direct_contact_s']:3.0f}s)  kill {s['kill_distance_m']:4.0f}m  "
          f"static {s['static_share']:4.0%} held-line {s['held_line_share']:4.0%}  moved {s['centroid_travel_m']:4.0f}m "
          f"push {s['net_advance_m']:4.0f}m  off-axis kills {s['off_axis_kill_share']:4.0%} (behind line {s['behind_line_kill_share']:3.0%})  "
          f"flank+rear {s['flank_rear_kill_share']:4.0%} (rear {s['rear_kill_share']:3.0%})  indirect {s['indirect_kill_share']:3.0%}  "
          f"cover: time {s['unit_seconds_near_cover']:3.0%} shots {s['shots_near_cover']:3.0%} "
          f"deaths {s['deaths_near_cover']:3.0%}  {s['reasons']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--pairs", default="condemned:condemned")
    parser.add_argument("--seeds", type=int, default=4)
    parser.add_argument("--first-seed", type=int, default=1)
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--budget", type=int, default=5200)
    parser.add_argument("--time-limit", type=int, default=240)
    parser.add_argument("--arena", default="")
    parser.add_argument("--tune", default="")
    parser.add_argument("--json")
    parser.add_argument("--variants", default="", help="JSON file {name: tune string}: run every variant, one row each")
    args = parser.parse_args()
    if args.variants:
        return run_variants(args)

    pairs = [tuple(p.split(":")) for p in args.pairs.split(",") if p]
    jobs = []
    for green, rust in pairs:
        for seed in range(args.first_seed, args.first_seed + args.seeds):
            jobs.append((green, rust, seed))
            if green != rust:
                jobs.append((rust, green, seed))
    started = time.time()
    results, failures = [], []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = [pool.submit(run, args, g, r, s) for g, r, s in jobs]
        for future in concurrent.futures.as_completed(futures):
            try:
                results.append(future.result())
            except Exception as err:
                failures.append(str(err))

    print(f"ENGAGEMENT budget {args.budget}, arena {args.arena or 'default'}, tune '{args.tune}', "
          f"{len(results)} matches in {time.time() - started:.0f}s")
    by_pair = {}
    for r in results:
        key = ":".join(sorted([r["pairing"]["green"], r["pairing"]["rust"]]))
        by_pair.setdefault(key, []).append(r)
    for key in sorted(by_pair):
        print_row(key, summarize(by_pair[key]))
    overall = summarize(results) if results else None
    if overall and len(by_pair) > 1:
        print_row("ALL", overall)
    for failure in failures:
        print("FAILED", failure, file=sys.stderr)
    if args.json:
        with open(args.json, "w") as handle:
            json.dump({"args": vars(args), "overall": overall,
                       "pairs": {k: summarize(v) for k, v in by_pair.items()}, "results": results}, handle, indent=1)
    return 1 if failures else 0


def run_variants(args):
    """Every variant plays the same pairings and seeds; one ALL row per variant, for A/B tuning."""
    variants = json.load(open(args.variants))
    pairs = [tuple(p.split(":")) for p in args.pairs.split(",") if p]
    jobs = []
    for name, tune in variants.items():
        for green, rust in pairs:
            for seed in range(args.first_seed, args.first_seed + args.seeds):
                jobs.append((name, tune, green, rust, seed))
                if green != rust:
                    jobs.append((name, tune, rust, green, seed))
    started = time.time()
    by_variant, failures = {name: [] for name in variants}, []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(run, args, g, r, s, tune): name for name, tune, g, r, s in jobs}
        for future in concurrent.futures.as_completed(futures):
            try:
                by_variant[futures[future]].append(future.result())
            except Exception as err:
                failures.append(str(err))
    print(f"ENGAGEMENT VARIANTS pairs {args.pairs}, seeds {args.seeds}, {len(jobs)} matches in {time.time() - started:.0f}s")
    summaries = {}
    for name in variants:
        if by_variant[name]:
            summaries[name] = summarize(by_variant[name])
            summaries[name]["wins"] = wins_by_faction(by_variant[name])
            print_row(name, summaries[name])
            print(f"{'':<24} wins {summaries[name]['wins']}")
    for failure in failures:
        print("FAILED", failure, file=sys.stderr)
    if args.json:
        with open(args.json, "w") as handle:
            json.dump({"args": vars(args), "variants": variants, "summaries": summaries}, handle, indent=1)
    return 1 if failures else 0


def wins_by_faction(results):
    wins = {}
    for r in results:
        side = {"Green": "green", "Rust": "rust"}.get(r["winner"])
        name = r["pairing"][side] if side else "draw"
        wins[name] = wins.get(name, 0) + 1
    return wins


if __name__ == "__main__":
    sys.exit(main())

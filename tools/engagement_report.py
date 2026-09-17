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


def run(args, green, rust, seed):
    command = [args.godot, "--headless", "--fixed-fps", "60", "--path", ".", "--", "--match", "--elimination",
               "--control", f"--green-faction={green}", f"--rust-faction={rust}", f"--budget={args.budget}",
               f"--time-limit={args.time_limit}", "--score-limit=0", f"--seed={seed}"]
    if args.arena:
        command.append(f"--arena={args.arena}")
    if args.tune:
        command.append(f"--tune={args.tune}")
    completed = subprocess.run(command, capture_output=True, text=True, timeout=args.time_limit * 4 + 240)
    for line in completed.stdout.splitlines():
        if line.startswith("MATCH_RESULT "):
            result = json.loads(line[len("MATCH_RESULT "):])
            result["pairing"] = {"green": green, "rust": rust}
            return result
    errors = [l for l in (completed.stdout + completed.stderr).splitlines() if "ERROR" in l][:5]
    raise RuntimeError(f"{green} vs {rust} seed {seed}: no MATCH_RESULT (exit {completed.returncode}) {errors}")


def mean(values):
    values = [v for v in values if v is not None and v >= 0]
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
        "static_share": mean([e["static_share"] for e in engagement]),
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
    print(f"{label:<24} n={s['matches']:<3} len {s['duration_s']:5.0f}s  contact {s['contact_s']:4.0f}s "
          f"@{s['separation_at_contact_m']:4.0f}m  engaged {s['engaged_distance_m']:4.0f}m  kill {s['kill_distance_m']:4.0f}m  "
          f"static {s['static_share']:4.0%}  moved {s['centroid_travel_m']:4.0f}m  "
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
    args = parser.parse_args()

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


if __name__ == "__main__":
    sys.exit(main())

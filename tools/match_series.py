#!/usr/bin/env python3
"""Run a series of seeded headless matches and summarize them: `make matches`.

This is the seed of the experiment harness in _agents/squad_ai_design.md
(E2/E3 need hundreds of matches per configuration). Each match is a separate
Godot process running faster than real time; several run in parallel.

Usage: match_series.py --godot PATH [--runs N] [--jobs J] [--green G] [--rust R]
                       [--score-limit K] [--time-limit S] [--first-seed S] [--json out.json]
"""
import argparse
import concurrent.futures
import json
import subprocess
import sys
import time


def run_match(args, seed):
    command = [args.godot, "--headless", "--fixed-fps", "60", "--path", ".", "--",
               "--match", f"--green={args.green}", f"--rust={args.rust}",
               f"--score-limit={args.score_limit}", f"--time-limit={args.time_limit}", f"--seed={seed}"] + args.extra.split()
    completed = subprocess.run(command, capture_output=True, text=True, timeout=args.time_limit + 120)
    for line in completed.stdout.splitlines():
        if line.startswith("MATCH_RESULT "):
            return json.loads(line[len("MATCH_RESULT "):])
    errors = [l for l in (completed.stdout + completed.stderr).splitlines() if "ERROR" in l][:5]
    raise RuntimeError(f"seed {seed}: no MATCH_RESULT (exit {completed.returncode}) {errors}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--runs", type=int, default=10)
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--green", type=int, default=1)
    parser.add_argument("--rust", type=int, default=1)
    parser.add_argument("--score-limit", type=int, default=5)
    parser.add_argument("--time-limit", type=int, default=300)
    parser.add_argument("--first-seed", type=int, default=1)
    parser.add_argument("--json")
    parser.add_argument("--extra", default="", help="extra game flags, e.g. --rust-first")
    args = parser.parse_args()

    started = time.time()
    seeds = range(args.first_seed, args.first_seed + args.runs)
    results, failures = [], []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for future in concurrent.futures.as_completed([pool.submit(run_match, args, s) for s in seeds]):
            try:
                results.append(future.result())
            except Exception as err:  # report every failure, keep the rest
                failures.append(str(err))

    wins = {"Green": 0, "Rust": 0, "draw": 0}
    faces = {"front": 0, "side": 0, "rear": 0}
    shots = hits = 0
    for r in results:
        wins[r["winner"]] += 1
        for face, count in r["stats"]["hits_by_face"].items():
            faces[face] += count
        shots += sum(r["stats"]["shots"])
        hits += sum(r["stats"]["hits"])
    n = max(len(results), 1)
    total_faces = max(sum(faces.values()), 1)
    lineup = args.extra.strip() or f"{args.green}v{args.rust} bots"
    print(f"{len(results)} matches ({lineup}, first to {args.score_limit} or {args.time_limit}s), "
          f"{time.time() - started:.1f}s wall, {args.jobs} jobs")
    print(f"  wins: Green {wins['Green']}  Rust {wins['Rust']}  draw {wins['draw']}")
    print(f"  avg sim length {sum(r['sim_seconds'] for r in results) / n:.1f}s, "
          f"avg speedup {sum(r['speedup'] for r in results) / n:.1f}x real time")
    print(f"  accuracy {hits / max(shots, 1):.0%} ({hits}/{shots}); hits by face: "
          + ", ".join(f"{k} {v / total_faces:.0%}" for k, v in faces.items()))
    ready = [sum(r["stats"].get("gun_ready_samples", [0, 0])[t] for r in results) for t in (0, 1)]
    idle = [sum(r["stats"].get("gun_idle_samples", [0, 0])[t] for r in results) for t in (0, 1)]
    if sum(ready):
        # A loaded gun with an enemy in the tank's own sight, not firing. Found the T2 target-lock bug.
        print(f"  idle guns: Green {idle[0] / max(ready[0], 1):.0%}  Rust {idle[1] / max(ready[1], 1):.0%}")
    # Pace and snowballing (streams/archive/round1/gameplay.md "Measure"): when does the fight start, how many does the loser take down.
    def mean(values):
        values = [v for v in values if v is not None and v >= 0]
        return f"{sum(values) / len(values):.1f}" if values else "n/a"
    team_index = {"Green": 0, "Rust": 1}
    loser_kills = [r["stats"]["kills"][1 - team_index[r["winner"]]] for r in results if r["winner"] in team_index]
    print(f"  pace: first shot {mean([r['stats'].get('first_shot_seconds') for r in results])}s, "
          f"first kill {mean([r['stats'].get('first_kill_seconds') for r in results])}s; "
          f"loser kills {mean(loser_kills)}; shots/match {shots / n:.0f}")
    # L2 (round 4): was there any suppressive fire in these matches? Mean suppression per living unit-sample and the
    # share of those samples that were pinned, by the team UNDER fire. Both near zero means the brains never
    # deliberately suppressed, whatever the mechanics allow.
    samples = [sum(r["stats"].get("suppression_samples", [0, 0])[t] for r in results) for t in (0, 1)]
    if sum(samples):
        totals = [sum(r["stats"].get("suppression_total", [0, 0])[t] for r in results) for t in (0, 1)]
        pinned = [sum(r["stats"].get("pinned_samples", [0, 0])[t] for r in results) for t in (0, 1)]
        print("  suppression (mean per living unit, share pinned): "
              + "  ".join(f"{name} {totals[t] / max(samples[t], 1):.2f} / {pinned[t] / max(samples[t], 1):.1%}"
                          for t, name in enumerate(("Green", "Rust"))))
    friendly = [sum(r["stats"].get("friendly_damage", [0, 0])[t] for r in results) for t in (0, 1)]
    if sum(friendly):
        # R4 friendly fire: hull + shield points each team dealt to its own units.
        print(f"  friendly damage per match: Green {friendly[0] / n:.0f}  Rust {friendly[1] / n:.0f}; "
              f"friendly kills Green {sum(r['stats'].get('friendly_kills', [0, 0])[0] for r in results)}  "
              f"Rust {sum(r['stats'].get('friendly_kills', [0, 0])[1] for r in results)}")
    options = [{}, {}]
    for r in results:
        for t in (0, 1):
            for k, v in r["stats"].get("options", [{}, {}])[t].items():
                options[t][k] = options[t].get(k, 0) + v
    for t, name in ((0, "Green"), (1, "Rust")):
        total = max(sum(options[t].values()), 1)
        if options[t]:
            print(f"  {name} doing: " + ", ".join(f"{k} {v / total:.0%}" for k, v in sorted(options[t].items(), key=lambda kv: -kv[1])))
    for failure in failures:
        print("  FAILED: " + failure)
    if args.json:
        with open(args.json, "w") as handle:
            json.dump({"args": vars(args), "results": results, "failures": failures}, handle, indent=2)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()

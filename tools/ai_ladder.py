#!/usr/bin/env python3
"""AI ladder (_agents/unit_ai.md "AI ladder"): brain variants play each other, an ELO table comes out.

Every pairing plays the same army on both sides (a mirror, so only the brains differ), counterbalanced: each
seed is played four ways, {A as Green, A as Rust} x {normal bases, --swap-bases}. Brain variants are selected
with the game flags --green-brain=<id> / --rust-brain=<id> (BrainVariants.PROFILES in game/ai/brain_variants.gd).

ELO: every match is a game between the two variants (a draw is half a win), K=16, all ratings start at 1000;
the match list is replayed in a fixed order PASSES times so the table doesn't depend on schedule order.
A challenger replaces the champion only if it beats it head to head (more wins than losses) AND out-rates it.

A variant "x3+v3" is brain x3 with a CpuCommander running policy v3; --doctrine takes a file name or "cpu:<archetype>"
(with --extra "--budget=1000").

Usage: ai_ladder.py --godot PATH --variants a4,a6 [--champion a4] [--runs 4] [--jobs 2]
                    [--doctrine individuals] [--time-limit 240] [--extra "--control"] [--json out.json]
"""
import argparse
import concurrent.futures
import itertools
import json
import subprocess
import sys
import time

K = 16
PASSES = 20


def side_flags(side, variant):
    """A variant is a BrainVariants id, optionally "+<policy>" for a CpuCommander on that side (e.g. "x3+v3")."""
    brain, _, commander = variant.partition("+")
    flags = [f"--{side}-brain={brain}"]
    if commander:
        flags.append(f"--{side}-commander={commander}")
    return flags


def run_match(args, green, rust, seed, swap):
    # A doctrine file name, or a seeded CPU army ("cpu:balanced"; both sides get the same one from the match seed).
    # A "res://" path is used as is (tests/ai_scenarios/armies/ holds same-army mirrors of the CPU archetypes: "cpu:"
    # armies are seeded per side, so they aren't mirrors).
    doctrine = args.doctrine if args.doctrine.startswith(("cpu", "res://")) else f"res://doctrines/{args.doctrine}.json"
    command = [args.godot, "--headless", "--fixed-fps", "60", "--path", ".", "--", "--match", "--elimination",
               f"--green-doctrine={doctrine}", f"--rust-doctrine={doctrine}", *side_flags("green", green),
               *side_flags("rust", rust), f"--time-limit={args.time_limit}", f"--seed={seed}"]
    if swap:
        command.append("--swap-bases")
    command += args.extra.split()
    completed = subprocess.run(command, capture_output=True, text=True, timeout=args.time_limit + 300)
    for line in completed.stdout.splitlines():
        if line.startswith("MATCH_RESULT "):
            result = json.loads(line[len("MATCH_RESULT "):])
            stats = result["stats"]
            return {"green": green, "rust": rust, "seed": seed, "swap": swap, "winner": result["winner"],
                    "sim_seconds": result["sim_seconds"], "shots": stats["shots"], "kills": stats["kills"],
                    "hits": stats.get("hits", [0, 0]), "damage": stats.get("damage", [0, 0]),
                    "shield_damage": stats.get("shield_damage", [0, 0]), "options": stats.get("options", [{}, {}]),
                    "hits_by_face": stats.get("hits_by_face", {})}
    errors = [l for l in (completed.stdout + completed.stderr).splitlines() if "ERROR" in l][:5]
    raise RuntimeError(f"{green} vs {rust} seed {seed} swap {swap}: no MATCH_RESULT (exit {completed.returncode}) {errors}")


def score_for(match, variant):
    """1 win, 0.5 draw, 0 loss, from `variant`'s side of the match."""
    if match["winner"] == "draw":
        return 0.5
    side = "green" if match["winner"] == "Green" else "rust"
    return 1.0 if match[side] == variant else 0.0


def elo(variants, matches):
    ratings = {v: 1000.0 for v in variants}
    ordered = sorted(matches, key=lambda m: (m["green"], m["rust"], m["seed"], m["swap"]))
    history = []
    for _ in range(PASSES):
        for m in ordered:
            a, b = m["green"], m["rust"]
            expected = 1.0 / (1.0 + 10 ** ((ratings[b] - ratings[a]) / 400.0))
            actual = score_for(m, a)
            ratings[a] += K * (actual - expected)
            ratings[b] -= K * (actual - expected)
        history.append(dict(ratings))
    # Average the last half of the passes: ratings oscillate around their fixed point.
    tail = history[PASSES // 2:]
    return {v: sum(h[v] for h in tail) / len(tail) for v in variants}


def print_stats(variants, matches):
    """Per variant, summed over its sides: accuracy, damage dealt, and where its brains spent their time (Match
    stats["options"] samples). Mirrors of one variant are skipped (a ladder never plays them)."""
    print("Per variant (both colors): shots, hits (accuracy), hull + shield damage dealt, kills; top options by time")
    for v in variants:
        shots = hits = damage = kills = 0
        options = {}
        for m in matches:
            for side, index in (("green", 0), ("rust", 1)):
                if m[side] != v:
                    continue
                shots += m["shots"][index]
                hits += m["hits"][index]
                damage += m["damage"][index] + m["shield_damage"][index]
                kills += m["kills"][index]
                for option, count in m["options"][index].items():
                    options[option] = options.get(option, 0) + count
        total = max(sum(options.values()), 1)
        top = sorted(options.items(), key=lambda kv: -kv[1])[:6]
        faces = {}
        for m in matches:
            if m["green"] == v and m["rust"] == v + "_twin" or m["rust"] == v and m["green"] == v + "_twin":
                for face, count in m["hits_by_face"].items():
                    faces[face] = faces.get(face, 0) + count
        face_note = ""
        if faces:
            total_faces = max(sum(faces.values()), 1)
            face_note = " (mirror vs its _twin, hits by face: " + ", ".join(
                f"{f} {100.0 * c / total_faces:.0f}%" for f, c in sorted(faces.items())) + ")"
        print(f"  {v}{face_note}: {shots} shots, {hits} hits ({100.0 * hits / max(shots, 1):.0f}%), {damage:.0f} damage, {kills} kills; "
              + ", ".join(f"{o} {100.0 * c / total:.0f}%" for o, c in top))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--variants", required=True, help="comma-separated BrainVariants ids")
    parser.add_argument("--champion", default="", help="the current champion (must beat it to replace it)")
    parser.add_argument("--runs", type=int, default=4, help="seeds per pairing (each seed is played 4 ways)")
    parser.add_argument("--first-seed", type=int, default=1)
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--doctrine", default="individuals")
    parser.add_argument("--time-limit", type=int, default=240)
    parser.add_argument("--extra", default="", help="extra game flags for every match, e.g. --control")
    parser.add_argument("--json")
    args = parser.parse_args()
    variants = [v for v in args.variants.split(",") if v]
    if len(variants) < 2:
        sys.exit("need at least two variants")

    started = time.time()
    jobs = []
    for a, b in itertools.combinations(variants, 2):
        for seed in range(args.first_seed, args.first_seed + args.runs):
            for green, rust in ((a, b), (b, a)):
                for swap in (False, True):
                    jobs.append((green, rust, seed, swap))
    matches, failures = [], []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = [pool.submit(run_match, args, *job) for job in jobs]
        for future in concurrent.futures.as_completed(futures):
            try:
                matches.append(future.result())
            except Exception as err:
                failures.append(str(err))

    ratings = elo(variants, matches)
    print(f"AI ladder: {len(matches)} matches ({args.doctrine} mirror, {args.runs} seeds x 4 per pairing"
          f"{', ' + args.extra if args.extra else ''}), {time.time() - started:.0f}s wall")
    print("| Variant | ELO | W | L | D |")
    print("|---|---|---|---|---|")
    for v in sorted(variants, key=lambda v: -ratings[v]):
        w = sum(1 for m in matches if v in (m["green"], m["rust"]) and score_for(m, v) == 1.0)
        l = sum(1 for m in matches if v in (m["green"], m["rust"]) and score_for(m, v) == 0.0)
        d = sum(1 for m in matches if v in (m["green"], m["rust"]) and m["winner"] == "draw")
        print(f"| {v} | {ratings[v]:.0f} | {w} | {l} | {d} |")
    print("Head to head (row's wins-losses-draws vs column):")
    for a in variants:
        cells = []
        for b in variants:
            if a == b:
                cells.append("-")
                continue
            pair = [m for m in matches if {m["green"], m["rust"]} == {a, b}]
            w = sum(1 for m in pair if score_for(m, a) == 1.0)
            l = sum(1 for m in pair if score_for(m, a) == 0.0)
            cells.append(f"{w}-{l}-{len(pair) - w - l}")
        print(f"  {a}: " + "  ".join(f"{b} {c}" for b, c in zip(variants, cells)))
    print_stats(variants, matches)
    verdict = ""
    if args.champion and args.champion in variants:
        best = max(variants, key=lambda v: ratings[v])
        if best != args.champion:
            pair = [m for m in matches if {m["green"], m["rust"]} == {best, args.champion}]
            w = sum(1 for m in pair if score_for(m, best) == 1.0)
            l = sum(1 for m in pair if score_for(m, best) == 0.0)
            verdict = (f"NEW CHAMPION: {best} (beat {args.champion} {w}-{l})" if w > l
                       else f"champion stays {args.champion}: {best} out-rates it but went {w}-{l} head to head")
        else:
            verdict = f"champion stays {args.champion}"
        print(verdict)
    for failure in failures:
        print("  FAILED: " + failure)
    if args.json:
        with open(args.json, "w") as handle:
            json.dump({"args": vars(args), "ratings": ratings, "verdict": verdict, "matches": matches,
                       "failures": failures}, handle, indent=2)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()

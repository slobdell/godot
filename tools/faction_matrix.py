#!/usr/bin/env python3
"""X6 (round 4, combat): every faction pair fought at the same budget, counterbalanced.

Faction identity is supposed to live in cost and effectiveness, not in a faction-wide bonus, so the check is that
any pair lands near 50% once both sides play the same number of matches from each colour (game_design.md
*Factions*: "any faction pair is near 50/50 when both sides build good armies"). Each pairing runs `--seeds` matches
with faction A as Green and the same seeds again with A as Rust, which cancels both the side advantage and any
team-identity effect in one pass.

Usage: faction_matrix.py --godot PATH [--budget 5200] [--seeds 6] [--jobs 2] [--time-limit 180] [--json out.json]

Reported per pairing: win rate for the first faction, average match length, average vehicles fielded and lost, and
the suppression the loser was under (Match.stats, added in round 4 L2) — a pairing that is decided by suppression
should show it.
"""
import argparse
import concurrent.futures
import itertools
import json
import os
import re
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run_conditions
import subprocess
import sys
import time
import os

# The simulation tick rate (the Makefile exports SIM_HZ; SimClock.TICK_RATE in game/match/sim_clock.gd).
SIM_HZ = os.environ.get("SIM_HZ", "60")

def _factions_from_catalog():
    """The faction list, READ from `Units.FACTIONS` rather than copied beside it.

    This was a copied table: `["gangs", "condemned", "law", "syndicate"]`, hard-coded here. Add a faction to the
    catalog and every matrix would quietly run without it -- no error, just a smaller table that looks complete.
    That is the worst shape of the copied-table bug this project keeps finding (feel's ROSTER, make_arenas.py
    mirroring the spawn grid, arena_report.KIT missing `block`): the ones that hurt are where the copy WINS or
    where the original is SILENTLY ABSENT, because both fail without a symptom.

    It raises rather than falling back to a hard-coded list on purpose. A fallback would restore the exact bug the
    moment the parse broke, and would do it silently -- which is how a guard becomes decoration.
    """
    source = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "units", "units.gd")
    with open(source) as handle:
        found = re.search(r"const FACTIONS\s*:=\s*\[([^\]]*)\]", handle.read())
    if not found:
        raise SystemExit("faction_matrix: cannot find `const FACTIONS` in game/units/units.gd -- the catalog moved, "
                         "and guessing the faction list is how a matrix silently runs without one of them")
    return [name.strip().strip('"') for name in found.group(1).split(",") if name.strip()]


FACTIONS = _factions_from_catalog()


def run_match(godot, green, rust, seed, budget, time_limit, arena="", controls=()):
    # X5 (round 6): --arena, because this tool ran EVERY match on the default layout (foundry) and said so nowhere.
    # That is fine for a like-for-like A/B and wrong for anything conditional on terrain: the Syndicate's designator
    # pays off where sightlines are long and pays nothing in a close map, so a single-map number would be reported as
    # a property of the faction when it is a property of foundry. Every row this tool prints is one map's answer.
    command = [godot, "--headless", "--fixed-fps", SIM_HZ, "--path", ".", "--", "--match", "--elimination", "--control",
               f"--green-faction={green}", f"--rust-faction={rust}", f"--budget={budget}",
               f"--time-limit={time_limit}", "--score-limit=0", f"--seed={seed}"]
    if arena:
        command.append(f"--arena={arena}")
    command.extend(controls)
    done = subprocess.run(command, capture_output=True, text=True, timeout=time_limit + 300)
    for line in done.stdout.splitlines():
        if line.startswith("MATCH_RESULT "):
            return json.loads(line[len("MATCH_RESULT "):])
    errors = [l for l in (done.stdout + done.stderr).splitlines() if "ERROR" in l][:3]
    raise RuntimeError(f"{green} vs {rust} seed {seed}: no MATCH_RESULT (exit {done.returncode}) {errors}")


def mean(values):
    values = [v for v in values if v is not None]
    return sum(values) / len(values) if values else 0.0


def summarize(faction, other, results):
    """Win rate and shape of one pairing. `results` is [(result, faction_played_green)]."""
    wins = draws = 0
    sizes, losses, lengths, suppression = [], [], [], []
    for result, as_green in results:
        mine = "green" if as_green else "rust"
        theirs = "rust" if as_green else "green"
        winner = result["winner"].lower()
        if winner == "draw":
            draws += 1
        elif winner == mine:
            wins += 1
        sizes.append(result["units_lost"][mine] + result["units_left"][mine])
        losses.append(result["units_lost"][mine])
        lengths.append(result["duration_seconds"])
        team = 0 if as_green else 1
        samples = result["stats"].get("suppression_samples", [0, 0])[team]
        if samples:
            suppression.append(result["stats"].get("suppression_total", [0, 0])[team] / samples)
    played = max(len(results), 1)
    return {"faction": faction, "versus": other, "matches": len(results),
            "win_rate": wins / played, "draws": draws,
            "vehicles": round(mean(sizes), 1), "lost": round(mean(losses), 1),
            "seconds": round(mean(lengths), 1), "suppression": round(mean(suppression), 3)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--budget", type=int, default=5200)
    parser.add_argument("--seeds", type=int, default=6)
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--time-limit", type=int, default=180)
    parser.add_argument("--factions", default=",".join(FACTIONS))
    parser.add_argument("--arena", default="", help="layout name; default runs the built-in default (foundry)")
    # X4 (round 7): the ablation arm. The gangs' 23% -> 53% swing is unattributed because CP4 and the `gangs/scout`
    # directive fix landed in one commit with no matrix between, so this runs the same matrix with every unit on its
    # plain-role directive. It is a CONTROL: it belongs in a measurement, never in a number quoted as the game.
    parser.add_argument("--no-faction-directives", action="store_true",
                        help="control arm: every unit takes its plain-role directive (Army.faction_directives=false)")
    # Round 9 (A2): the same matrix with a combat knob changed, so a mechanism's ladder arm is the SAME BUILD with
    # `--tune=switch.cost=1` (or `switch.price=0`) rather than a different checkout. Without this, every arm of a
    # combat A/B was a separate build and "does not lose" could never be said about one mechanism in isolation.
    parser.add_argument("--tune", default="", help="passed through to the match as --tune (e.g. switch.cost=1)")
    parser.add_argument("--json")
    args = parser.parse_args()

    factions = [f.strip() for f in args.factions.split(",") if f.strip()]
    # `--factions` defaults to `",".join(Units.FACTIONS)` read live from the catalogue, so the RAW arg records the
    # order that const happened to have at run time -- it changed between rounds 8 and 9 when someone reordered
    # `units.gd:50`, and two identical runs then looked like different arms to anyone diffing their `args` blocks.
    # That nearly cost a builder0 run. The job set is provably independent of the order (itertools.combinations over
    # unordered pairs, both orientations per seed, seeds 1..N regardless of position), so record the RESOLVED list
    # canonically as well: a diff of this field is then a statement about the experiment rather than about a const.
    resolved_factions = sorted(factions)
    controls = ("--no-faction-directives",) if args.no_faction_directives else ()
    if args.tune:
        controls = controls + (f"--tune={args.tune}",)
    jobs = []
    for first, second in itertools.combinations(factions, 2):
        for seed in range(1, args.seeds + 1):
            jobs.append((first, second, seed, True))    # first plays Green
            jobs.append((second, first, seed, False))   # ...and the same seed from the other colour
    started = time.time()
    outcomes, failures = {}, []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(run_match, args.godot, green, rust, seed, args.budget, args.time_limit, args.arena,
                                controls):
                   (green, rust, seed, first_is_green) for green, rust, seed, first_is_green in jobs}
        for future in concurrent.futures.as_completed(futures):
            green, rust, seed, first_is_green = futures[future]
            try:
                result = future.result()
            except Exception as err:
                failures.append(str(err))
                continue
            faction, other = (green, rust) if first_is_green else (rust, green)
            outcomes.setdefault((faction, other), []).append((result, first_is_green))

    rows = [summarize(faction, other, results) for (faction, other), results in sorted(outcomes.items())]
    # Name the map in the output: every row is ONE map's answer, and a reader who does not know which will read a
    # property of foundry as a property of the faction.
    # POSITIVE CONTROL (adherence). A treatment arm with no treatment is a FAILED RUN, not a null result -- you do
    # not report a drug trial without checking the patients took the drug. This project has produced two designator
    # numbers that measured a different game: once the unit was silently dropped from every army, once it was fielded
    # but classified as a line unit and pushed to the front. Neither was caught by any check; both were caught by a
    # result looking slightly wrong, which only works when the confound happens to push the implausible way.
    #
    # The assertion needs no knowledge of any roster: the match reports how many designators each side FIELDED and
    # how many times one PAINTED. Fielded with zero paints means the mechanism did not engage, so the number is not
    # about the mechanism and must not be quoted as though it were.
    # ADHERENCE, the other half of the positive control. The block below asks whether the TREATMENT engaged; this
    # asks whether the ARM was the one requested. A flag that is silently dropped -- misspelled, eaten by a wrapper,
    # not yet on the remote's checkout -- produces a control arm identical to the treatment arm, two files that
    # differ only in their names, and a "no effect" conclusion that is really "I ran the same thing twice". That is
    # the same failure as the data-only control that cost this stream most of round 6, in a form a tool can catch.
    want = {"faction_directives": not args.no_faction_directives}
    mismatched = sorted({f"{key}={got.get(key)} (asked for {value})"
                         for _pairing, results in outcomes.items() for result, _green in results
                         for got in [result.get("controls") or {}]
                         for key, value in want.items() if got.get(key) != value})
    if mismatched:
        print("REFUSED: the runs did not carry the controls this invocation asked for -- both arms are the same arm:")
        for line in mismatched[:5]:
            print("  " + line)
        if not any((result.get("controls") for _p, rs in outcomes.items() for result, _g in rs)):
            print("  (MATCH_RESULT carried no `controls` at all: the build predates it, so no arm can be proven)")
        if args.json and os.path.exists(args.json):
            os.remove(args.json)
        return 2

    unengaged = []
    fielding_sides, paints = 0, 0
    for (faction, other), results in sorted(outcomes.items()):
        # outcomes holds (result, first_is_green) PAIRS, not bare results -- and team 0 is Green, so which faction a
        # team index refers to depends on that flag. Getting this wrong is what made the guard crash the tool.
        for result, first_is_green in results:
            st = result.get("stats", {})
            green_side, rust_side = (faction, other) if first_is_green else (other, faction)
            for team, side in ((0, green_side), (1, rust_side)):
                fielded = (st.get("designators_fielded") or [0, 0])[team]
                painted = (st.get("designations") or [0, 0])[team]
                if fielded:
                    fielding_sides += 1
                    paints += painted
                if fielded and not painted:
                    unengaged.append(f"{side}: {fielded} designator(s) fielded, 0 paints")
    if unengaged:
        print("REFUSED: the treatment never engaged in %d match(es) -- this is a failed run, not a result:"
              % len(unengaged))
        for line in sorted(set(unengaged))[:5]:
            print("  " + line)
        # Refuse to PERSIST, not merely to print (arena's improvement on this, after the same construction caught
        # eight immobilised unit-pairs in make nav-maze on its first run). A printed refusal can be scrolled past;
        # an absent file cannot be cited, copied into references/, or picked up by whoever greps for the newest json.
        # The failure mode being defended against is a refused run becoming a number six weeks later.
        if args.json and os.path.exists(args.json):
            os.remove(args.json)
        return 2
    print(f"run: {run_conditions.header()}")
    print("arm: %s" % ("CONTROL -- plain-role directives (--no-faction-directives)" if args.no_faction_directives
                       else "normal play -- faction directives ON"))
    # Say what the control SAW, not only that it did not fire. A guard that is silent when it ran and silent when it
    # never ran is indistinguishable from no guard, which is how the designator got measured twice without engaging.
    # Zero fielding sides is legitimate when no designating faction is in `--factions`; it is NOT a pass, so it is
    # printed as "not exercised" rather than left to look like one.
    if fielding_sides:
        print(f"positive control: {fielding_sides} side(s) fielded a designator, {paints} paints -- treatment engaged")
    else:
        print("positive control: NOT EXERCISED -- no side fielded a designator in this matrix "
              "(expected when --factions excludes the syndicate, or when no drawn archetype carries one)")
    print(f"{len(jobs) - len(failures)} matches on {args.arena or 'foundry (default)'} at {args.budget} points, "
          f"{time.time() - started:.0f}s wall, "
          f"{args.jobs} jobs (each pairing counterbalanced: same seeds from both colours)")
    print(f"{'pairing':28} {'win%':>6} {'matches':>8} {'vehicles':>9} {'lost':>6} {'length':>8} {'suppr':>7}")
    for row in sorted(rows, key=lambda r: -r["win_rate"]):
        print(f"{row['faction'] + ' vs ' + row['versus']:28} {row['win_rate']:6.0%} {row['matches']:8d} "
              f"{row['vehicles']:9.1f} {row['lost']:6.1f} {row['seconds']:7.1f}s {row['suppression']:7.3f}")
    # PER FACTION, not just per pairing (arena asked, 2026-09-19): if one faction moves between two maps and nobody
    # else does, that is an asymmetry -- a map paying one army more than another. If EVERY faction's spread widens on
    # the open map, that is a property of the map itself. **Those two results look identical in a pairing table**,
    # which is why this block exists.
    totals = {}
    for row in rows:
        for side, won in ((row["faction"], row["win_rate"] * row["matches"]),
                          (row["versus"], (1.0 - row["win_rate"]) * row["matches"])):
            got, played = totals.get(side, (0.0, 0))
            totals[side] = (got + won, played + row["matches"])
    print(f"\n{'faction':16} {'record':>10} {'win%':>6}   (on {args.arena or 'foundry (default)'})")
    for side in sorted(totals, key=lambda f: -totals[f][0] / max(totals[f][1], 1)):
        won, played = totals[side]
        print(f"{side:16} {round(won):5.0f}/{played:<4d} {won / max(played, 1):6.0%}")
    for failure in failures:
        print("  FAILED: " + failure)
    if args.json:
        with open(args.json, "w") as handle:
            json.dump({"run": run_conditions.describe(), "args": vars(args),
                       "factions_resolved": resolved_factions, "rows": rows, "failures": failures},
                      handle, indent=2)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    # sys.exit(main()), not a bare main(): the refusal paths `return 2`, and a bare call throws that away and exits 0.
    # A guard that reports SUCCESS to every caller -- make, a wrapper script, a shell `&&` -- is worse than no guard,
    # because the refusal scrolls past while the pipeline goes green. Found by reading to the bottom of the file
    # after the same block had already shipped broken once.
    sys.exit(main())

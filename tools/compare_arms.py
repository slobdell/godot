#!/usr/bin/env python3
"""Compare two faction-matrix arms, and REFUSE the comparisons that are not comparisons.

Round 7 (combat). Every measurement this stream has got wrong was got wrong in the comparison, not in the run:
a filtered arm against a full one, a builder0 arm against a laptop one, and a control that differed from its
treatment only in the name of its file. Each was arithmetic between two numbers that were never about the same
thing, and each looked completely ordinary on the page.

`run_conditions` put the machine and the commit INSIDE each run's own output so a mismatch could be seen. This
does the seeing, because the step where a human reads two files and subtracts is the step that failed.

Four refusals, and the last is the one nobody finds by inspection:

  1. **Same file twice.** An arm compared with itself is a zero, and a zero is what "no effect" looks like.
  2. **Different commit or machine.** The laptop is ~2.75x slower than builder0; a difference measured across
     two builds is a difference between two games.
  3. **Different workload.** Different arena, budget, seeds, time limit or faction list means the two runs were
     not asked the same question, whatever their arms were.
  4. **Identical arms.** Two runs with the same controls are the same arm run twice. The result is a beautifully
     clean null -- the answer you hoped for, reached by the treatment never happening. arena found the same shape
     in its own `--swap-bases` fairness tool on the same day: *an assertion about the stage is not an assertion
     about the experiment.*

Usage: compare_arms.py --treatment build/faction-matrix-boulevard.json \\
                       --control   build/faction-matrix-boulevard-plainroles.json [--faction gangs]
"""
import argparse
import json
import sys

# The `args` keys that describe the QUESTION rather than the ARM. Two runs must agree on all of these, or they
# were not asked the same thing. `json` is excluded deliberately: the output path is the one field that is
# SUPPOSED to differ between two arms, and requiring it to match would refuse every correct comparison.
WORKLOAD = ("arena", "budget", "seeds", "time_limit", "factions")
# The keys that describe the ARM. At least one must differ, or there is only one arm.
CONTROLS = ("no_faction_directives",)


def load(path):
    with open(path) as handle:
        data = json.load(handle)
    for key in ("rows", "args"):
        if key not in data:
            raise SystemExit(f"REFUSED: {path} has no '{key}' -- not a faction-matrix result")
    return data


def win_rates(data):
    """Per faction: (wins, matches) summed over every pairing it appears in, from either side."""
    totals = {}
    for row in data["rows"]:
        for side, won in ((row["faction"], row["win_rate"] * row["matches"]),
                          (row["versus"], (1.0 - row["win_rate"]) * row["matches"])):
            got, played = totals.get(side, (0.0, 0))
            totals[side] = (got + won, played + row["matches"])
    return totals


def refusals(treatment, control, paths, build_is_the_arm=""):
    """`build_is_the_arm`: a description of what the two BUILDS differ by, when the treatment is a code or data
    change rather than a runner flag. Sizing a vehicle is one -- you cannot put a hull_size behind a flag -- and
    without this the tool refuses the one comparison it was built to make. It is not an escape hatch: declaring it
    swaps which guard applies rather than removing one. The commits must then DIFFER (identical commits mean the
    build is not the arm and the run is one arm twice), and machine, dirtiness and workload are still enforced."""
    out = []
    if paths[0] == paths[1]:
        out.append("the same file twice -- an arm compared with itself is a zero, and a zero reads as 'no effect'")
        return out
    for field in ("machine", "dirty"):
        first, second = treatment.get("run", {}).get(field), control.get("run", {}).get(field)
        if first != second:
            out.append(f"run.{field} differs: {first!r} vs {second!r} -- two machines, not two arms")
    first_commit = treatment.get("run", {}).get("commit")
    second_commit = control.get("run", {}).get("commit")
    if build_is_the_arm:
        if first_commit == second_commit:
            out.append(f"the build was declared to be the arm ({build_is_the_arm!r}) but both runs are at "
                       f"{first_commit!r} -- that is one arm run twice, not a before and an after")
    elif first_commit != second_commit:
        out.append(f"run.commit differs: {first_commit!r} vs {second_commit!r} -- two builds, not two arms. If the "
                   f"BUILD is the treatment (a size, a constant, anything you cannot put behind a flag), say so "
                   f"with --build-is-the-arm '<what changed>'")
    if treatment.get("run", {}).get("dirty") or control.get("run", {}).get("dirty"):
        out.append("one of the runs was made from a DIRTY tree: its commit does not identify what ran")
    for field in WORKLOAD:
        first, second = treatment["args"].get(field), control["args"].get(field)
        if first != second:
            out.append(f"args.{field} differs: {first!r} vs {second!r} -- the two runs were asked different questions")
    if not build_is_the_arm and all(treatment["args"].get(field) == control["args"].get(field) for field in CONTROLS):
        arm = {field: treatment["args"].get(field) for field in CONTROLS}
        out.append(f"IDENTICAL ARMS {arm} -- this is one arm run twice, and its difference will be a clean null")
    return out


def matchup_rows(treatment, control):
    """Every matchup that appears in both arms, largest movement first, ONE row per pair.

    "gangs vs law" and "law vs gangs" are the same ten matches seen from opposite ends, so a per-direction table
    prints each result twice and halves its own useful length. Canonical orientation is alphabetical, so the same
    matchup reads the same way in every report.
    """
    pairs = {}
    for data, key in ((treatment, "t"), (control, "c")):
        for row in data["rows"]:
            side, other = sorted((row["faction"], row["versus"]))
            rate = row["win_rate"] if side == row["faction"] else 1.0 - row["win_rate"]
            pairs.setdefault((side, other), {})[key] = (rate, row["matches"])
    moved = [(abs(v["t"][0] - v["c"][0]), k, v) for k, v in pairs.items() if "t" in v and "c" in v]
    moved.sort(reverse=True)
    return moved


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--treatment", required=True, help="the run WITH the thing being measured")
    parser.add_argument("--control", required=True, help="the arm it is measured against")
    parser.add_argument("--faction", default="", help="report only this faction")
    parser.add_argument("--build-is-the-arm", default="", metavar="WHAT_CHANGED",
                        help="the treatment is a code/data change, not a flag (e.g. 'gang_tank 5.6 m -> 14 m'). "
                             "Permits the commits to differ, and then REQUIRES it.")
    args = parser.parse_args()

    treatment, control = load(args.treatment), load(args.control)
    problems = refusals(treatment, control, (args.treatment, args.control), args.build_is_the_arm)
    if problems:
        print("REFUSED: these two runs cannot be subtracted from each other:")
        for line in problems:
            print("  " + line)
        return 2

    where = treatment["args"].get("arena") or "foundry (default)"
    print(f"run: {treatment.get('run', {}).get('commit', '?')} on {treatment.get('run', {}).get('machine', '?')}, "
          f"map {where}")
    print(f"treatment: {args.treatment}\ncontrol:   {args.control}")
    if args.build_is_the_arm:
        print("the arm IS THE BUILD: %s  (%s -> %s)" % (args.build_is_the_arm,
              control.get("run", {}).get("commit"), treatment.get("run", {}).get("commit")))
    else:
        print(f"the arm differs in: {', '.join(f for f in CONTROLS if treatment['args'].get(f) != control['args'].get(f))}")
    # Print the resolved filter. A comparison showing one faction looks exactly like a comparison where only one
    # faction moved, and this stream has already lost a round's conclusions to a make variable nobody passed
    # (`UNITS ?= 60`). Say which rows are missing rather than leaving the reader to infer it from their absence.
    print("factions: %s" % (f"ONLY {args.faction} -- the other rows are FILTERED OUT, not unchanged"
                            if args.faction else "all"))
    first, second = win_rates(treatment), win_rates(control)
    print(f"\n{'faction':16} {'treatment':>12} {'control':>12} {'delta':>9}   (one map; per faction, never pooled)")
    for side in sorted(set(first) | set(second)):
        if args.faction and side != args.faction:
            continue
        won_t, played_t = first.get(side, (0.0, 0))
        won_c, played_c = second.get(side, (0.0, 0))
        rate_t = won_t / max(played_t, 1)
        rate_c = won_c / max(played_c, 1)
        print(f"{side:16} {rate_t:10.0%} n={played_t:<3d} {rate_c:10.0%} n={played_c:<3d} "
              f"{(rate_t - rate_c) * 100.0:+8.0f} pts")
    # PER MATCHUP AS WELL AS PER FACTION. Round 8: the 14 m rig took `gangs vs law` from 9/20 to 0/20 across two
    # maps, and on pit the per-FACTION number was a flat 30% in both arms -- losing one matchup outright was offset
    # by gaining another. A pooled row said "no effect" about a matchup that had become unwinnable. Pooling is not
    # neutral: it is an average over exactly the dimension an asymmetry lives in.
    # One row per PAIR, not per direction: "gangs vs law" and "law vs gangs" are the same ten matches seen from
    # opposite ends, and printing both halves the table's useful length for no information. Canonical orientation
    # is alphabetical, so the same matchup reads the same way in every report.
    moved = matchup_rows(treatment, control)
    print(f"\n{'matchup':28} {'treatment':>10} {'control':>9} {'delta':>9}   (per matchup: an asymmetry lives here)")
    for _size, (side, other), v in moved[:8]:
        print(f"{side + ' vs ' + other:28} {v['t'][0]:9.0%}{v['t'][1]:>4} {v['c'][0]:8.0%}{v['c'][1]:>4} "
              f"{(v['t'][0] - v['c'][0]) * 100:+8.0f} pts")

    print("\nThis is ONE map's answer. A faction that moves here and nowhere else is an asymmetry; every faction\n"
          "moving is a property of the map. Those look identical in a single table, so quote both maps or neither.")
    return 0


if __name__ == "__main__":
    # sys.exit(main()), never a bare main(): the refusals return 2, and a bare call discards it and exits 0 --
    # a refusal that reports success to make, to a wrapper, or to a shell `&&`. That bug shipped in
    # faction_matrix.py this round and is not shipping again.
    sys.exit(main())

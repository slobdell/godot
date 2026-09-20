#!/usr/bin/env python3
"""X2 (A2, round 9): the switching cost's churn A/B, all four arms over several seeds.

`main`'s commitment is TWO mechanisms -- a flat bonus AND a hard dwell timer -- and A2 replaces both with one. So a
two-arm comparison charges A2 with beating two things while being one, and any churn credited to the flat bonus might
belong to the timer that P3 says works by storing pressure up. Four arms are what it takes to say which term did what:

    cost      A2's state-dependent switching cost (the default build)
    flat      the flat 1.15 bonus alone           (--tune=switch.legacy=1,switch.dwell=0)
    flat+dwell  the flat bonus and its timer      (--tune=switch.legacy=1)   == main
    none      no commitment term at all           (--tune=switch.price=0)

`none` is the honest baseline for "does this mechanism do anything"; `flat+dwell` is the honest baseline for "is it
better than what it replaces". Reporting only one of those two is how a mechanism gets adopted or rejected for the
wrong reason.

Every rate is reported per class AND per locomotion, because metrics measured that the creep is a property of wheels
rather than of a role (ifv and lancer are almost all creep; tracked hulls produce none), so a role split reads two
mechanisms as one column.

Seeds are the sample. Each arm runs the same seeds, and the spread across seeds is reported beside every mean --
a single-seed delta between two arms is two different fights, not a measurement.
"""

import argparse
import concurrent.futures
import json
import statistics
import subprocess
import sys

SIM_HZ = "30"

ARMS = {
    "cost": "",
    # The stance floor is combat's addition, not catalogue A2, and round 9's duel scenario measured it costing
    # flanking (flank seconds 6.27/5.27 -> 2.07/3.53 of 20). It gets its own arm rather than a judgement call.
    "cost-nostance": "switch.stance=0",
    "flat": "switch.legacy=1,switch.dwell=0",
    "flat+dwell": "switch.legacy=1",
    "none": "switch.price=0",
}
# Reported per class; `tank` is the row that matters most because tracked hulls produce no creep cusps, so it is the
# only one whose switches are unambiguously about decisions rather than about the wheeled shuffle.
RATES = ["switches_per_unit_min", "reversals_4s_per_unit_min", "reversals_3s_per_unit_min",
         "flipped_per_think", "consulted", "offered_s_median"]
# Not rates: the share of time each option was actually RUN, and the option->option transition rates. A cost that
# suppresses a manoeuvre shows up here and nowhere else -- the churn tables said nothing while the duel scenario lost
# 60% of its flanking.
SHARES = ["option_share", "transitions_per_unit_min"]


def run_probe(godot, arena, seed, seconds, budget, green_army, rust_army, require, tune):
    command = [godot, "--headless", "--fixed-fps", SIM_HZ, "--path", ".", "--script",
               "res://tests/combat/switch_probe.gd", "--", f"--arena={arena}", f"--seed={seed}",
               f"--time-limit={seconds}", f"--budget={budget}",
               f"--green-army={green_army}", f"--rust-army={rust_army}", f"--require={require}"]
    if tune:
        command.append(f"--tune={tune}")
    done = subprocess.run(command, capture_output=True, text=True, timeout=seconds * 20 + 600)
    for line in done.stdout.splitlines():
        if line.startswith("SWITCH_ARM "):
            return json.loads(line[len("SWITCH_ARM "):])
    errors = [l for l in (done.stdout + done.stderr).splitlines() if "ERROR" in l][:3]
    raise RuntimeError(f"seed {seed} arm '{tune or 'cost'}': no SWITCH_ARM line (exit {done.returncode}) {errors}")


def collect(runs, section, key):
    """{bucket: [value per seed]} for one reported rate."""
    out = {}
    for run in runs:
        for bucket, row in run[section].items():
            out.setdefault(bucket, []).append(float(row[key]))
    return out


def merge_shares(runs, section, key):
    """{bucket: {option: mean over seeds}} for the dictionary-valued columns."""
    gathered = {}
    for run in runs:
        for bucket, row in run[section].items():
            for name, value in row.get(key, {}).items():
                gathered.setdefault(bucket, {}).setdefault(name, []).append(float(value))
    return {bucket: {name: round(statistics.fmean(values), 3) for name, values in sorted(options.items())}
            for bucket, options in gathered.items()}


def summarise(values):
    if not values:
        return None
    mean = statistics.fmean(values)
    spread = statistics.pstdev(values) if len(values) > 1 else 0.0
    return {"mean": round(mean, 3), "sd": round(spread, 3), "n": len(values),
            "seeds": [round(v, 3) for v in values]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--arena", default="yard")
    parser.add_argument("--seeds", default="1,3,7")
    parser.add_argument("--seconds", type=int, default=120)
    parser.add_argument("--budget", type=int, default=6500)
    # Named archetypes, not a seeded draft: seed 3's draft fielded no War Rig at all, and the run said nothing.
    parser.add_argument("--green-army", default="gang_ram")
    parser.add_argument("--rust-army", default="law_line")
    # The probe refuses the run if these are not on the field, so a series cannot report real numbers about a
    # question it could not answer. Round 9 lost one run to exactly that before the gate existed.
    parser.add_argument("--require", default="gang_tank")
    parser.add_argument("--arms", default=",".join(ARMS))
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--json")
    args = parser.parse_args()

    seeds = [int(s) for s in args.seeds.split(",") if s.strip()]
    arms = [a.strip() for a in args.arms.split(",") if a.strip()]
    for arm in arms:
        if arm not in ARMS:
            sys.exit(f"unknown arm '{arm}' (have {', '.join(ARMS)})")

    jobs = [(arm, seed) for arm in arms for seed in seeds]
    results, failures = {}, []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(run_probe, args.godot, args.arena, seed, args.seconds, args.budget,
                               args.green_army, args.rust_army, args.require, ARMS[arm]): (arm, seed)
                   for arm, seed in jobs}
        for future in concurrent.futures.as_completed(futures):
            arm, seed = futures[future]
            try:
                results.setdefault(arm, []).append(future.result())
            except Exception as error:  # noqa: BLE001 - one bad run must not lose the other eleven
                failures.append(f"{arm} seed {seed}: {error}")

    if failures:
        print("FAILED RUNS (reported, not hidden):", file=sys.stderr)
        for failure in failures:
            print("  " + failure, file=sys.stderr)

    report = {"arena": args.arena, "seeds": seeds, "seconds": args.seconds,
              "green_army": args.green_army, "rust_army": args.rust_army,
              "failures": failures, "arms": {}}
    for arm in arms:
        runs = results.get(arm, [])
        if not runs:
            continue
        report["arms"][arm] = {
            section: dict(
                {key: {bucket: summarise(values) for bucket, values in collect(runs, section, key).items()}
                 for key in RATES},
                **{key: merge_shares(runs, section, key) for key in SHARES})
            for section in ["by_class", "by_locomotion"]
        }

    for section in ["by_class", "by_locomotion"]:
        for key in ["switches_per_unit_min", "reversals_4s_per_unit_min"]:
            print(f"\n=== {key}, {section.removeprefix('by_')} (mean over seeds {seeds}, sd in brackets) ===")
            buckets = sorted({b for arm in report["arms"] for b in report["arms"][arm][section][key]})
            print(f"{'':<14}" + "".join(f"{arm:>16}" for arm in arms))
            for bucket in buckets:
                cells = ""
                for arm in arms:
                    row = report["arms"].get(arm, {}).get(section, {}).get(key, {}).get(bucket)
                    cells += f"{'-':>16}" if row is None else f"{row['mean']:>10.1f} [{row['sd']:>3.1f}]"
                print(f"{bucket:<14}{cells}")

    print("\n=== share of time running each fight manoeuvre, by class (mean over seeds) ===")
    manoeuvres = ["ENGAGE", "FLANK", "ORBIT", "SUPPRESS", "COVER_FIRE", "CLEAR_LANE"]
    for bucket in sorted({b for arm in report["arms"] for b in report["arms"][arm]["by_class"]["option_share"]}):
        print(f"\n  {bucket}")
        print(f"    {'arm':<16}" + "".join(f"{m:>12}" for m in manoeuvres))
        for arm in arms:
            shares = report["arms"].get(arm, {}).get("by_class", {}).get("option_share", {}).get(bucket, {})
            if not shares:
                continue
            print(f"    {arm:<16}" + "".join(f"{shares.get(m, 0.0):>12.3f}" for m in manoeuvres))

    if args.json:
        with open(args.json, "w") as handle:
            json.dump(report, handle, indent=1)
        print(f"\nwrote {args.json}")
    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()

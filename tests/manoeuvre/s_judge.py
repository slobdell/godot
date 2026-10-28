#!/usr/bin/env python3
"""Round 43 (manoeuvre Bar S, C43.5): the judge of `make manoeuvre-bar-s` logs (tests/manoeuvre/start_trace.gd's START_RUN rows,
his first-order shape per arena x seed x arm), paired by (arena, seed), BASE v ARM:

  D1 crews seated within the bound 15 s after their order (TacticsFormation.seat_bound of their squad, the same yardstick in
     every arm): ARM mean - BASE mean >= 2 se of the paired per-run difference, AND ARM pooled > BASE pooled
  D2 start-zone yield + blocked seconds (the traced crews, the 15 s after their order): BASE mean - ARM mean >= 2 se, AND ARM
     pooled < BASE pooled
Reported: never-arrived crews, mean arrival (never = 15 s), k-turn s, wedged s, seat moves, per-cell rows, SCRIPT ERROR files.

    python3 tests/manoeuvre/s_judge.py DIR --base=base --arm=both [--cells]
"""
import glob
import json
import math
import os
import statistics
import sys


def load(folder):
    runs, errors = {}, []
    for path in sorted(glob.glob(os.path.join(folder, "*.log"))):
        run = None
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("START_RUN "):
                    run = json.loads(line[10:])
                elif "SCRIPT ERROR" in line:
                    errors.append(os.path.basename(path))
        if run is None:
            print("MISSING (no START_RUN): %s" % os.path.basename(path))
            continue
        runs[(run["arm"], run["arena"], int(run["seed"]))] = run
    return runs, sorted(set(errors))


def paired(base, arm, keys, f):
    d = [f(arm[k]) - f(base[k]) for k in keys]
    mean_d = statistics.mean(d) if d else 0.0
    se = statistics.stdev(d) / math.sqrt(len(d)) if len(d) > 1 else float("inf")
    return mean_d, se, sum(f(base[k]) for k in keys), sum(f(arm[k]) for k in keys)


def main():
    folder = sys.argv[1]
    base_arm, on_arm = "base", "both"
    for a in sys.argv[2:]:
        if a.startswith("--base="):
            base_arm = a.split("=", 1)[1]
        elif a.startswith("--arm="):
            on_arm = a.split("=", 1)[1]
    runs, errors = load(folder)
    base = {k[1:]: r for k, r in runs.items() if k[0] == base_arm}
    arm = {k[1:]: r for k, r in runs.items() if k[0] == on_arm}
    keys = sorted(set(base) & set(arm))
    print("Bar S judge: %s v %s, %d paired runs (base %d, arm %d), %d files with SCRIPT ERROR" % (base_arm, on_arm, len(keys), len(base), len(arm), len(errors)))
    for e in errors:
        print("  SCRIPT ERROR in %s" % e)
    if not keys:
        print("VERDICT: NO PAIRS")
        return 2
    verdict = True
    d1_mean, d1_se, d1_base, d1_arm = paired(base, arm, keys, lambda r: r["seated_in_bound_15s"])
    ok1 = d1_mean >= 2.0 * d1_se and d1_arm > d1_base
    print("D1 seated within the bound by 15 s: pooled %d -> %d; paired mean %+.3f a run, se %.3f (%+.1f se); line >= +2 se and ARM > BASE: %s"
          % (d1_base, d1_arm, d1_mean, d1_se, d1_mean / d1_se if d1_se > 0 else float("inf"), "PASS" if ok1 else "FAIL"))
    d2_mean, d2_se, d2_base, d2_arm = paired(base, arm, keys, lambda r: r["yield_blocked_s"])
    ok2 = -d2_mean >= 2.0 * d2_se and d2_arm < d2_base
    print("D2 start-zone yield + blocked s: pooled %.1f -> %.1f; paired mean %+.3f s a run, se %.3f (%+.1f se); line <= -2 se and ARM < BASE: %s"
          % (d2_base, d2_arm, d2_mean, d2_se, d2_mean / d2_se if d2_se > 0 else float("inf"), "PASS" if ok2 else "FAIL"))
    verdict = ok1 and ok2 and not errors
    # R43.14: per-arena guards (paired over that arena's seeds): yield + blocked s and k-turn s ARM <= BASE + 2 se.
    for arena in sorted(set(k[0] for k in keys)):
        sub = [k for k in keys if k[0] == arena]
        for label, f in [("yield+blocked s", lambda r: r["yield_blocked_s"]), ("k-turn s", lambda r: sum(c["kturn_s"] for c in r["per_crew"]))]:
            m, se, b, a = paired(base, arm, sub, f)
            ok = m <= 2.0 * se
            verdict = verdict and ok
            print("G %-9s %-16s pooled %7.1f -> %7.1f; paired mean %+.3f a run, se %.3f (%+.1f se); line <= +2 se: %s"
                  % (arena, label, b, a, m, se, m / se if se > 0 else 0.0, "PASS" if ok else "FAIL"))
    for label, f in [("never-arrived crews", lambda r: r["never_arrived"]), ("mean arrival s (never = 15)", lambda r: r["arrival_mean_s"]),
                     ("k-turn s", lambda r: sum(c["kturn_s"] for c in r["per_crew"])), ("wedged s", lambda r: sum(c["wedged_s"] for c in r["per_crew"])),
                     ("seat moves", lambda r: sum(c["seat_moves"] for c in r["per_crew"]))]:
        m, se, b, a = paired(base, arm, keys, f)
        print("  reported %-28s pooled %8.1f -> %8.1f; paired mean %+.3f (se %.3f)" % (label, b, a, m, se))
    if "--cells" in sys.argv:
        print("  per cell (arena seed): seated base->arm | yield+blocked base->arm | never base->arm")
        for k in keys:
            print("   %-10s %6d: %2d -> %2d | %5.1f -> %5.1f | %d -> %d" % (k[0], k[1], base[k]["seated_in_bound_15s"], arm[k]["seated_in_bound_15s"],
                  base[k]["yield_blocked_s"], arm[k]["yield_blocked_s"], base[k]["never_arrived"], arm[k]["never_arrived"]))
    print("VERDICT: %s" % ("PASS" if verdict else "FAIL"))
    return 0 if verdict else 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Round 41 (manoeuvre Bar Q3, R41.6): the group-order GUARD lines, strict and written before numbers, over `make manoeuvre-probe-jam`
logs of his 5-squad across click (orders' O1 probe) in two arms, paired by (arena, seed, headings):

  G5 every-squad-in time: ARM mean <= BASE mean + 1.645 se (se of the paired per-run difference; a never-in run reads as the window)
  G6 never-in squads a run: ARM mean <= BASE mean + 1.645 se (paired)
  G7 friendly contact ticks: ARM total <= 1.05 x BASE
Reported: jam-seconds (probe_jam's), the rule's counters.

    python3 tests/manoeuvre/q3_judge.py DIR [--base=main] [--arm=wait] [--window=90]
"""
import glob
import json
import math
import os
import statistics
import sys


def load(folder):
    runs = {}
    for path in sorted(glob.glob(os.path.join(folder, "*.log"))):
        run, probe, squads = None, None, []
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("JAM_RUN "):
                    run = json.loads(line[8:])
                elif line.startswith("ORDERS_PROBE {"):
                    probe = json.loads(line[13:])
                elif line.startswith("ORDERS_PROBE_SQUAD "):
                    squads.append(json.loads(line[19:]))
        if run is None or probe is None:
            print("MISSING (no JAM_RUN / ORDERS_PROBE): %s" % os.path.basename(path))
            continue
        run["all_in_s"] = float(probe.get("all_in_s", -1.0))
        run["never_in_squads"] = sum(1 for s in squads if float(s.get("arrived_s", -1.0)) < 0)
        run["contact_ticks"] = int(probe.get("contact_ticks", 0))
        runs[(run["arm"], run["arena"], run["seed"], run["headings"])] = run
    return runs


def paired(base, arm, keys, f):
    d = [f(arm[k]) - f(base[k]) for k in keys]
    mean_b = statistics.mean(f(base[k]) for k in keys) if keys else 0.0
    mean_a = statistics.mean(f(arm[k]) for k in keys) if keys else 0.0
    se = statistics.stdev(d) / math.sqrt(len(d)) if len(d) > 1 else float("inf")
    return mean_b, mean_a, se


def main(argv):
    folder = argv[1]
    base_arm, on_arm, window = "main", "wait", 90.0
    for a in argv[2:]:
        if a.startswith("--base="):
            base_arm = a.split("=", 1)[1]
        elif a.startswith("--arm="):
            on_arm = a.split("=", 1)[1]
        elif a.startswith("--window="):
            window = float(a.split("=", 1)[1])
    runs = load(folder)
    base = {k[1:]: r for k, r in runs.items() if k[0] == base_arm}
    arm = {k[1:]: r for k, r in runs.items() if k[0] == on_arm}
    keys = sorted(set(base) & set(arm))
    missing = sorted(set(base) ^ set(arm))
    lines, ok = [], True

    def line(name, passed, text):
        nonlocal ok
        ok = ok and passed
        lines.append("%s %s: %s" % ("PASS" if passed else "FAIL", name, text))

    lines.append("paired runs: %d (unpaired: %s)" % (len(keys), ", ".join("%s s%s %s" % k for k in missing) or "none"))
    allin = lambda r: r["all_in_s"] if r["all_in_s"] >= 0 else window
    b, a, se = paired(base, arm, keys, allin)
    line("G5 every-squad-in mean", a <= b + 1.645 * se,
         "%.1f -> %.1f s (never-in reads as %.0f; line <= %.1f = base + 1.645 x se %.2f)" % (b, a, window, b + 1.645 * se, se))
    b, a, se = paired(base, arm, keys, lambda r: float(r["never_in_squads"]))
    line("G6 never-in squads a run", a <= b + 1.645 * se,
         "%.2f -> %.2f (line <= %.2f, se %.3f); runs never-in %d -> %d" % (
             b, a, b + 1.645 * se, se, sum(1 for k in keys if base[k]["all_in_s"] < 0), sum(1 for k in keys if arm[k]["all_in_s"] < 0)))
    cb = sum(base[k]["contact_ticks"] for k in keys)
    ca = sum(arm[k]["contact_ticks"] for k in keys)
    line("G7 friendly contact ticks", ca <= 1.05 * cb, "%d -> %d (line <= %.0f)" % (cb, ca, 1.05 * cb))
    jb = sum(float(base[k]["jam_s"]) for k in keys)
    ja = sum(float(arm[k]["jam_s"]) for k in keys)
    lines.append("reported jam-seconds %.0f -> %.0f (%+.1f %%)" % (jb, ja, 100.0 * (ja - jb) / jb if jb else 0.0))
    # Round 43 (the round-42 slip): under --arm=deckwait the counters are deckwait_* (JAM_RUN), not Q2's waits / wait_queued.
    if on_arm == "deckwait":
        for r in arm.values():
            if "deckwait_waits" in r:
                r["waits"], r["wait_queued"], r["wait_timeouts"] = r["deckwait_waits"], r["deckwait_queued"], r["deckwait_timeouts"]
    w = [arm[k] for k in keys if "waits" in arm[k]]
    if w:
        lines.append("reported %s counters a run (mean): waits %.0f, queued crew-ticks %.0f, time-outs %.0f, longest %.1f s" % (
            on_arm, statistics.mean(r["waits"] for r in w), statistics.mean(r["wait_queued"] for r in w),
            statistics.mean(r["wait_timeouts"] for r in w), max(float(r["wait_longest"].get("s", 0)) for r in w)))
    lines.append("per cell: " + " | ".join("%s s%s: all-in %.1f -> %.1f, never-in squads %d -> %d" % (
        k[0], k[1], base[k]["all_in_s"], arm[k]["all_in_s"], base[k]["never_in_squads"], arm[k]["never_in_squads"]) for k in keys))
    lines.append("VERDICT %s" % ("PASS" if ok else "FAIL"))
    print("\n".join(lines))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))

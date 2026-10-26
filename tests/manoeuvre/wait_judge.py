#!/usr/bin/env python3
"""Round 41 (manoeuvre Q2, his rule): the judge for a wait-v-main read of `make manoeuvre-probe-jam` logs (probe_jam.gd's JAM_RUN
and the probe's ORDERS_PROBE rows), paired by (arena, seed, headings). A lab read, and Bar Q2's lines once it is filed (the bar
is in _agents/streams/manoeuvre.md Status, filed before any number on its seeds).

    python3 tests/manoeuvre/wait_judge.py DIR [--off=main] [--on=wait] [--window=90]

Lines (the bar names which decide):
  D1 jam-seconds a run: ON <= D_RATIO x OFF pooled AND the paired per-run mean < 0 by >= 2 se.
  D2 every-squad-in time: paired per-run mean (a never-in run reads as the window) ON - OFF <= 0 (reported with its se).
  G5 never-in runs: ON <= OFF.
  G6 friendly contact ticks (the probe's): ON <= 1.10 x OFF.
Reported: jam-seconds by blocker class per arm; the rule's own counters (waits, timeouts, longest) from the ON arm's route_arms
when the logs carry them.
"""
import glob
import json
import math
import os
import statistics
import sys

D_RATIO = 0.8


def load(folder):
    runs = {}
    for path in sorted(glob.glob(os.path.join(folder, "*.log"))):
        run, probe = None, None
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("JAM_RUN "):
                    run = json.loads(line[8:])
                elif line.startswith("ORDERS_PROBE {"):
                    probe = json.loads(line[13:])
        if run is None:
            continue
        run["all_in_s"] = probe.get("all_in_s", -1.0) if probe else -1.0
        run["contact_ticks"] = int(probe.get("contact_ticks", 0)) if probe else 0
        runs[(run["arm"], run["arena"], run["seed"], run["headings"])] = run
    return runs


def paired(off, on, keys, f):
    d = [f(on[k]) - f(off[k]) for k in keys]
    a = sum(f(off[k]) for k in keys)
    b = sum(f(on[k]) for k in keys)
    mean = statistics.mean(d) if d else 0.0
    se = statistics.stdev(d) / math.sqrt(len(d)) if len(d) > 1 else float("inf")
    return a, b, mean, se


def main(argv):
    folder = argv[1]
    off_arm, on_arm, window = "main", "wait", 90.0
    for a in argv[2:]:
        if a.startswith("--off="):
            off_arm = a.split("=", 1)[1]
        elif a.startswith("--on="):
            on_arm = a.split("=", 1)[1]
        elif a.startswith("--window="):
            window = float(a.split("=", 1)[1])
    runs = load(folder)
    off = {k[1:]: r for k, r in runs.items() if k[0] == off_arm}
    on = {k[1:]: r for k, r in runs.items() if k[0] == on_arm}
    keys = sorted(set(off) & set(on))
    missing = sorted(set(off) ^ set(on))
    lines, ok = [], True

    def line(name, passed, text):
        nonlocal ok
        ok = ok and passed
        lines.append("%s %s: %s" % ("PASS" if passed else "FAIL", name, text))

    lines.append("paired runs: %d (unpaired: %s)" % (len(keys), ", ".join("%s s%s %s" % k for k in missing) or "none"))
    a, b, mean, se = paired(off, on, keys, lambda r: float(r["jam_s"]))
    line("D1 jam-seconds", b <= D_RATIO * a and mean <= -2.0 * se,
         "%.1f -> %.1f s (%+.1f %%; line <= %.1f); paired mean %+.1f s a run, se %.1f (%.1f se; line <= -2 se)" % (
             a, b, 100.0 * (b - a) / a if a else 0.0, D_RATIO * a, mean, se, mean / se if se else 0.0))
    allin = lambda r: float(r["all_in_s"]) if float(r["all_in_s"]) >= 0 else window
    a, b, mean, se = paired(off, on, keys, allin)
    line("D2 every-squad-in", mean <= 0.0,
         "mean %.1f -> %.1f s (never-in reads as %.0f); paired mean %+.1f s, se %.1f (%.1f se)" % (
             a / max(len(keys), 1), b / max(len(keys), 1), window, mean, se, mean / se if se else 0.0))
    no = sum(1 for k in keys if float(off[k]["all_in_s"]) < 0)
    nn = sum(1 for k in keys if float(on[k]["all_in_s"]) < 0)
    line("G5 never-in runs", nn <= no, "%d -> %d of %d" % (no, nn, len(keys)))
    a, b, mean, se = paired(off, on, keys, lambda r: float(r["contact_ticks"]))
    line("G6 friendly contact ticks", b <= 1.10 * a, "%d -> %d (line <= %.0f)" % (a, b, 1.10 * a))
    for name, arm in ((off_arm, off), (on_arm, on)):
        by = {}
        for k in keys:
            for c, s in arm[k]["by_class"].items():
                by[c] = by.get(c, 0.0) + s
        tot = sum(by.values()) or 1.0
        lines.append("  %s jam-s by blocker: %s" % (name, ", ".join("%s %.0f (%.0f %%)" % (c, s, 100 * s / tot)
                                                                     for c, s in sorted(by.items(), key=lambda kv: -kv[1]))))
    w = [on[k] for k in keys if "waits" in on[k]]
    if w:
        lines.append("  %s rule counters a run (mean): waits %.0f (>= 2 s: %.0f), queued crew-ticks %.0f, time-outs %.0f, longest %.1f s; by kind %s" % (
            on_arm, statistics.mean(r["waits"] for r in w), statistics.mean(r.get("wait_long", 0) for r in w), statistics.mean(r["wait_queued"] for r in w),
            statistics.mean(r["wait_timeouts"] for r in w), max(float(r["wait_longest"].get("s", 0)) for r in w),
            {k: sum(r["wait_by_kind"].get(k, 0) for r in w) for k in sorted(set().union(*[r["wait_by_kind"].keys() for r in w]))}))
    per = []
    for k in keys:
        per.append("%s s%s %s: jam %.0f -> %.0f, all-in %.1f -> %.1f" % (k[0], k[1], k[2], off[k]["jam_s"], on[k]["jam_s"],
                                                                        off[k]["all_in_s"], on[k]["all_in_s"]))
    lines.append("  per cell: " + " | ".join(per))
    lines.append("VERDICT %s" % ("PASS" if ok else "FAIL"))
    print("\n".join(lines))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))

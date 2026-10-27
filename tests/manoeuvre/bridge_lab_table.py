#!/usr/bin/env python3
"""Round 41 (manoeuvre Q3 / Q2 on the bridge): read bridge-series.jsonl files side by side (one per tree x arm, as
`~/overnight-manoeuvre/r41/bridgelab1/bridge-<tree>-<arm>.jsonl`) into round 40's lab table: runs passing bridge-pooled's line
(every surviving crew crossed, no crew at the rim over RIM_LINE_S), pooled rim-seconds, deck-jam seconds, the worst single crew's
rim seconds, mean arrival, and the runs over the rim line. With two files named OFF and ON for the same tree it also prints
the paired per-run rim difference and its se (Bar Q3's deciding form).

    python3 tests/manoeuvre/bridge_lab_table.py LABEL=FILE.jsonl [LABEL=FILE.jsonl ...] [--pair=OFFLABEL,ONLABEL] [--q6]

Round 42 (Bar Q6): `--q6` with a pair prints the tree's lines: rim pooled ON <= OFF, every surviving crew crosses ON, worst crew
ON <= RIM_LINE_S, the arrival guard (paired per-run mean ON <= OFF + 1.645 se), and a tree verdict.
"""
import json
import math
import statistics
import sys

RIM_LINE_S = 3.0


def load(path):
    rows = []
    for line in open(path, errors="replace"):
        line = line.strip()
        if line:
            rows.append(json.loads(line))
    return rows


def key(r):
    return (r["arena"], r["side"], int(r["seed"]), str(r["start_tick"]))


def worst_rim(r):
    return max([float(v) for v in r.get("rim_s", {}).values()] or [0.0])


def passes(r):
    # The probe's own verdict: rim_crews counts crews at the rim for >= RIM_STUCK_S x TICK_RATE ticks (3.00 s fails); the row's
    # rim_s is snapped to 0.1 s, so a crew at 2.93-2.97 s prints 3.0 and passes.
    return int(r["crossed"]) == int(r["alive"]) and int(r.get("rim_crews", 1)) == 0


def main(argv):
    files, pair, q6 = {}, None, False
    for a in argv[1:]:
        if a.startswith("--pair="):
            pair = a.split("=", 1)[1].split(",")
        elif a == "--q6":
            q6 = True
        else:
            label, path = a.split("=", 1)
            files[label] = load(path)
    print("%-14s %5s %8s %8s %9s %8s %9s %8s" % ("arm", "runs", "pass", "rim s", "deck jam", "worst", "arrival", "over 3 s"))
    for label, rows in files.items():
        print("%-14s %5d %8s %8.1f %9.1f %8.1f %9.1f %8d" % (
            label, len(rows), "%d/%d" % (sum(passes(r) for r in rows), len(rows)),
            sum(float(r["rim_total_s"]) for r in rows), sum(float(r["deck_jam_s"]) for r in rows),
            max([worst_rim(r) for r in rows] or [0.0]),
            statistics.mean(float(r["arrived_s"]) for r in rows) if rows else 0.0,
            sum(1 for r in rows if int(r.get("rim_crews", 0)) > 0)))
        for r in rows:
            if not passes(r):
                print("    FAIL %s %s seed %s tick %s: crossed %s/%s, worst rim %.1f s (%s)" % (
                    r["arena"], r["side"], r["seed"], r["start_tick"], r["crossed"], r["alive"], worst_rim(r),
                    ", ".join("%s %.1f" % kv for kv in sorted(r["rim_s"].items(), key=lambda kv: -float(kv[1]))[:2])))
    if pair and all(p in files for p in pair):
        off = {key(r): r for r in files[pair[0]]}
        on = {key(r): r for r in files[pair[1]]}
        keys = sorted(set(off) & set(on))
        d = [float(on[k]["rim_total_s"]) - float(off[k]["rim_total_s"]) for k in keys]
        a = sum(float(off[k]["rim_total_s"]) for k in keys)
        b = sum(float(on[k]["rim_total_s"]) for k in keys)
        mean = statistics.mean(d) if d else 0.0
        se = statistics.stdev(d) / math.sqrt(len(d)) if len(d) > 1 else float("inf")
        print("paired %s -> %s over %d runs: rim %.1f -> %.1f s (%+.0f %%; line <= %.1f = 0.8 x OFF), per-run mean %+.2f s, se %.2f (%.1f se; line <= -2 se)" % (
            pair[0], pair[1], len(keys), a, b, 100.0 * (b - a) / a if a else 0.0, 0.8 * a, mean, se, mean / se if se else 0.0))
        da = [float(on[k]["arrived_s"]) - float(off[k]["arrived_s"]) for k in keys]
        amean = statistics.mean(da) if da else 0.0
        ase = statistics.stdev(da) / math.sqrt(len(da)) if len(da) > 1 else float("inf")
        print("paired arrival %s -> %s: mean %.1f -> %.1f s, per-run mean %+.2f s, se %.2f (%+.1f se)" % (
            pair[0], pair[1], statistics.mean(float(off[k]["arrived_s"]) for k in keys) if keys else 0.0,
            statistics.mean(float(on[k]["arrived_s"]) for k in keys) if keys else 0.0, amean, ase, amean / ase if ase else 0.0))
        if q6:
            # Round 42 (Bar Q6, deciding 2 and the arrival guard, one tree): rim pooled ON <= OFF; every surviving crew crosses ON;
            # worst crew ON <= RIM_LINE_S; arrival paired per-run mean ON <= OFF + 1.645 se.
            lines = [
                ("Q6 rim pooled ON <= OFF", b <= a, "%.1f -> %.1f s" % (a, b)),
                ("Q6 every surviving crew crosses ON", all(int(on[k]["crossed"]) >= int(on[k]["alive"]) for k in keys),
                 "%d/%d runs" % (sum(1 for k in keys if int(on[k]["crossed"]) >= int(on[k]["alive"])), len(keys))),
                ("Q6 worst crew ON <= %.0f s" % RIM_LINE_S, max([worst_rim(on[k]) for k in keys] or [0.0]) <= RIM_LINE_S,
                 "%.1f s" % max([worst_rim(on[k]) for k in keys] or [0.0])),
                ("Q6 arrival guard: paired mean ON <= OFF + 1.645 se", amean <= 1.645 * ase,
                 "%+.2f s a run (line <= %+.2f)" % (amean, 1.645 * ase)),
            ]
            for name, ok, text in lines:
                print("%s %s: %s" % ("PASS" if ok else "FAIL", name, text))
            print("Q6 TREE VERDICT %s" % ("PASS" if all(ok for _, ok, _ in lines) else "FAIL"))


if __name__ == "__main__":
    main(sys.argv)

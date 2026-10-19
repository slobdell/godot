#!/usr/bin/env python3
"""B6 (round 34): the bar's lines (workstreams *Bars (round 34)*, brains B6), ON (the halt's shape on the final
approach) v --halt-shape-early=off, paired by run.

  (1) ground-series rows (one jsonl, arm on/off; GROUND_EXTRA=--drift-trace so the run logs hold DRIFT_TRACE):
      (a) pooled drift moves ON <= 0.5 x OFF
      (b) Sumps: all_in8_s paired mean(ON - OFF) <= 1.645 se, and hollow runs ON <= OFF + 1;
          yard/Terminus: crews in, paired mean(ON - OFF) >= -1.645 se
      (c) REPORTED: the arrived re-lays left ON (DRIFT_TRACE arrived true): count, distance
  (2) crossing-series rows (two jsonl, ON and OFF): runs with every crew across ON >= OFF - 1; last-across time paired
      (both crossed) mean(ON - OFF) <= 1.645 se; seat_passes + point_passes + overtakes paired mean(ON - OFF) <= 1.645 se
Usage: b6_table.py ground.jsonl ground_runs_dir cross_on.jsonl cross_off.jsonl
"""
import glob
import json
import math
import os
import re
import statistics
import sys

K = 1.645


def paired(diffs):
    if not diffs:
        return 0.0, 0.0
    se = statistics.stdev(diffs) / math.sqrt(len(diffs)) if len(diffs) > 1 else 0.0
    return statistics.mean(diffs), se


def load(path):
    return [json.loads(line) for line in open(path) if line.strip()]


def ground(path, runs_dir):
    rows = {}
    for r in load(path):
        rows[(r["cell"], r["arm"], r.get("seed"), r.get("start_tick"))] = r
    keys = sorted({(c, s, t) for (c, a, s, t) in rows})
    missing = [k for k in keys if (k[0], "on", k[1], k[2]) not in rows or (k[0], "off", k[1], k[2]) not in rows
               or rows[(k[0], "on", k[1], k[2])].get("missing") or rows[(k[0], "off", k[1], k[2])].get("missing")]
    pairs = [k for k in keys if k not in missing]
    on = lambda k: rows[(k[0], "on", k[1], k[2])]
    off = lambda k: rows[(k[0], "off", k[1], k[2])]
    print("(1) ground-series: %d pairs%s" % (len(pairs), " | MISSING %s" % missing if missing else ""))
    d_on = sum(int(on(k).get("drift_moves", 0)) for k in pairs)
    d_off = sum(int(off(k).get("drift_moves", 0)) for k in pairs)
    a_ok = d_on <= 0.5 * d_off
    print("(a) pooled drift moves %d v %d (limit %.1f) %s" % (d_on, d_off, 0.5 * d_off, "PASS" if a_ok else "FAIL"))
    sumps = [k for k in pairs if k[0] == "sumps"]
    diffs = []
    for k in sumps:
        a, b = on(k).get("all_in8_s"), off(k).get("all_in8_s")
        # never within 8 m counts as the run's length (the probe's 120 s)
        a = float(a) if a is not None and float(a) >= 0 else 120.0
        b = float(b) if b is not None and float(b) >= 0 else 120.0
        diffs.append(a - b)
    m, se = paired(diffs)
    hollow_on = sum(1 for k in sumps if on(k).get("hollow"))
    hollow_off = sum(1 for k in sumps if off(k).get("hollow"))
    b1_ok = m <= K * se and hollow_on <= hollow_off + 1
    print("(b) Sumps n %d: all_in8 mean diff %+.2f s (limit %+.2f) | hollow %d v %d (limit %d) %s" % (
        len(sumps), m, K * se, hollow_on, hollow_off, hollow_off + 1, "PASS" if b1_ok else "FAIL"))
    others = [k for k in pairs if k[0] != "sumps"]
    cdiffs = [int(on(k).get("arrived", 0)) - int(off(k).get("arrived", 0)) for k in others]
    cm, cse = paired(cdiffs)
    b2_ok = cm >= -K * cse
    print("    yard/Terminus n %d: crews in %d v %d, mean diff %+.2f (floor %+.2f) %s" % (
        len(others), sum(int(on(k).get("arrived", 0)) for k in others), sum(int(off(k).get("arrived", 0)) for k in others),
        cm, -K * cse, "PASS" if b2_ok else "FAIL"))
    for k in pairs:
        a, b = on(k), off(k)
        if a.get("drift_moves") != b.get("drift_moves") or (k[0] == "sumps" and a.get("all_in8_s") != b.get("all_in8_s")):
            print("    %s s%s t%s: drift %s v %s | %s" % (k[0], k[1], k[2], a.get("drift_moves"), b.get("drift_moves"),
                  ("all_in8 %s v %s hollow %s v %s" % (a.get("all_in8_s"), b.get("all_in8_s"), a.get("hollow"), b.get("hollow")))
                  if k[0] == "sumps" else "crews in %s v %s of %s" % (a.get("arrived"), b.get("arrived"), a.get("crews"))))
    left = []
    for log in glob.glob(os.path.join(runs_dir, "*-on-*.log")):
        for line in open(log, errors="replace"):
            m2 = re.search(r"DRIFT_TRACE t=([\d.]+) (\S+) seat \d+ \(([-\d.]+), ([-\d.]+)\) -> \(([-\d.]+), ([-\d.]+)\).*arrived true formation (\S+)", line)
            if m2:
                left.append((os.path.basename(log), m2[2], math.hypot(float(m2[5]) - float(m2[3]), float(m2[6]) - float(m2[4])), m2[7]))
    dist = sorted(x[2] for x in left)
    print("(c) REPORTED arrived re-lays left ON: %d%s" % (len(left), " | median %.1f m, max %.1f m, runs %d, formations %s" % (
        dist[len(dist) // 2], dist[-1], len({x[0] for x in left}), sorted({x[3] for x in left})) if left else ""))
    return a_ok and b1_ok and b2_ok


def crossing(on_path, off_path):
    key = lambda r: (r["arena"], r["formation"], r["side"], r["seed"], str(r.get("start_tick")))
    on = {key(r): r for r in load(on_path)}
    off = {key(r): r for r in load(off_path)}
    pairs = sorted(set(on) & set(off))
    missing = sorted(set(on) ^ set(off)) + [k for k in pairs if on[k].get("missing") or off[k].get("missing")]
    pairs = [k for k in pairs if not on[k].get("missing") and not off[k].get("missing")]
    full = lambda r: int(r.get("crossed", 0)) == int(r.get("crews", -1))
    f_on, f_off = sum(full(on[k]) for k in pairs), sum(full(off[k]) for k in pairs)
    both = [k for k in pairs if full(on[k]) and full(off[k])]
    tm, tse = paired([float(on[k]["crossed_s"]) - float(off[k]["crossed_s"]) for k in both])
    order = lambda r: int(r.get("seat_passes", 0)) + int(r.get("point_passes", 0)) + int(r.get("overtakes", 0))
    om, ose = paired([order(on[k]) - order(off[k]) for k in pairs])
    ok = f_on >= f_off - 1 and tm <= K * tse and om <= K * ose
    print("(2) crossing-series: %d pairs%s" % (len(pairs), " | MISSING %s" % missing if missing else ""))
    print("    every crew across: %d v %d (floor %d) %s" % (f_on, f_off, f_off - 1, "PASS" if f_on >= f_off - 1 else "FAIL"))
    print("    last across (n %d both crossed): mean diff %+.2f s (limit %+.2f) %s" % (
        len(both), tm, K * tse, "PASS" if tm <= K * tse else "FAIL"))
    print("    seat + point passes + overtakes: %d v %d, mean diff %+.2f (limit %+.2f) %s" % (
        sum(order(on[k]) for k in pairs), sum(order(off[k]) for k in pairs), om, K * ose, "PASS" if om <= K * ose else "FAIL"))
    for k in pairs:
        if order(on[k]) != order(off[k]) or full(on[k]) != full(off[k]):
            print("    %s: across %s/%s v %s/%s, order %d v %d, last %s v %s" % (
                k, on[k]["crossed"], on[k]["crews"], off[k]["crossed"], off[k]["crews"], order(on[k]), order(off[k]),
                on[k].get("crossed_s"), off[k].get("crossed_s")))
    return ok


if __name__ == "__main__":
    g = ground(sys.argv[1], sys.argv[2])
    c = crossing(sys.argv[3], sys.argv[4])
    print("B6_BAR (1) %s (2) %s" % ("PASS" if g else "FAIL", "PASS" if c else "FAIL"))

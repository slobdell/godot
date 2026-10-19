#!/usr/bin/env python3
"""Brains B9 (R34.15): the lane spread's bar over `make lane-series` (LANE_ARM=aa and LANE_ARM=ruled dirs).
The RULED side is green on even seeds, rust on odd (in the A/A arm the same labels, both sides off).
  DECIDING  E = ln((kills_R+1)/(deaths_R+1)) - ln((kills_B+1)/(deaths_B+1)) per fight; ruled arm mean E > 1.645 se
  GUARDS    (ruled arm, R - B per fight, paired) jam deaths, stuck deaths, first contact (s), contact spread (s):
            mean <= 1.645 se each; NOT DRAGGING: fight length (finished_s, else ran_s) ruled v aa paired by
            (arena, seed): mean diff <= 1.645 se
Usage: lane_series.py AA_DIR RULED_DIR"""
import glob
import json
import math
import os
import statistics
import sys

K = 1.645


def load(d):
    out = {}
    for path in glob.glob(os.path.join(d, "*.log")):
        for line in open(path, errors="replace"):
            if line.startswith("LANE_CENSUS "):
                r = json.loads(line.split(" ", 1)[1])
                out[(r["arena"], int(r["seed"]))] = r
    return out


def sides(r):
    ruled = "0" if int(r["seed"]) % 2 == 0 else "1"
    base = "1" if ruled == "0" else "0"
    t = r["teams"]
    return t.get(ruled, {}), t.get(base, {})


def exch(row):
    return math.log((int(row.get("kills", 0)) + 1) / (int(row.get("deaths", 0)) + 1))


def paired(xs):
    if len(xs) < 2:
        return (xs[0] if xs else 0.0), 0.0
    return statistics.mean(xs), statistics.stdev(xs) / math.sqrt(len(xs))


def length(r):
    return float(r["finished_s"]) if float(r.get("finished_s", -1)) >= 0 else float(r.get("ran_s", 180.0))


def report(label, rows):
    es = [exch(R) - exch(B) for R, B in (sides(r) for r in rows.values())]
    m, se = paired(es)
    return m, se, len(es)


def main(aa_dir, ruled_dir):
    aa, ruled = load(aa_dir), load(ruled_dir)
    m, se, n = report("aa", aa)
    print("A/A   (both off, ruled labels by parity): E mean %+.3f se %.3f n %d" % (m, se, n))
    for arena in sorted({k[0] for k in ruled}):
        sub = {k: v for k, v in ruled.items() if k[0] == arena}
        am, ase, an = report(arena, sub)
        print("  ruled %-9s E mean %+.3f se %.3f n %d" % (arena, am, ase, an))
    m, se, n = report("ruled", ruled)
    ok = m > K * se
    print("DECIDING ruled E mean %+.3f se %.3f n %d (needs > %+.3f) %s" % (m, se, n, K * se, "PASS" if ok else "FAIL"))
    guards_ok = True
    for key, label in (("jam_deaths", "jam deaths"), ("stuck_deaths", "stuck deaths"), ("first_shot_s", "first contact s"),
                       ("contact_spread_s", "contact spread s")):
        diffs = []
        for r in ruled.values():
            R, B = sides(r)
            if key == "first_shot_s" and (float(R.get(key, -1)) < 0 or float(B.get(key, -1)) < 0):
                continue
            diffs.append(float(R.get(key, 0)) - float(B.get(key, 0)))
        dm, dse = paired(diffs)
        g = dm <= K * dse
        guards_ok = guards_ok and g
        print("GUARD %-17s R-B mean %+.2f (limit %+.2f) n %d %s" % (label, dm, K * dse, len(diffs), "PASS" if g else "FAIL"))
    common = sorted(set(aa) & set(ruled))
    dd = [length(ruled[k]) - length(aa[k]) for k in common]
    dm, dse = paired(dd)
    g = dm <= K * dse
    guards_ok = guards_ok and g
    print("GUARD %-17s ruled-aa mean %+.1f s (limit %+.1f) n %d %s" % ("fight length", dm, K * dse, len(dd), "PASS" if g else "FAIL"))
    print("GUARD far loops: REPORTED only (far_census not in this probe)")
    print("B9_BAR %s" % ("PASS" if ok and guards_ok else "FAIL"))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

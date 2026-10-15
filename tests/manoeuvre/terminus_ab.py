#!/usr/bin/env python3
"""Round 31 (manoeuvre): a paired Terminus A/B from two census (or nav-drive) folders, in round 30's judged-table form
(tools/judge/rows.py `terminus_rows` reads it back).

Per run (terminus-<squad>-<seed>.log): arrivals = the sum of `arrived` over its NAV_DRIVE_LEG rows (of `units`), wall
contact-ticks = NAV_DRIVE's wall_contacts.contact_unit_ticks. Per squad, paired by seed: the arrivals line (guard: new not
down beyond 1.645 se of the paired difference), the contact-ticks line (guard: new <= base + 1.645 se), each also with
each arm's two worst runs dropped, and one `per seed arrived(contacts)` line. A run with no NAV_DRIVE line is MISSING
and drops its pair (printed).

Usage: terminus_ab.py BASE_DIR NEW_DIR [--label NAME]
"""
import glob
import json
import math
import os
import re
import statistics
import sys


def read_run(path):
    arrived, units, contacts, done = 0, 0, None, False
    with open(path, errors="replace") as handle:
        for line in handle:
            if line.startswith("NAV_DRIVE_LEG "):
                try:
                    row = json.loads(line[len("NAV_DRIVE_LEG "):])
                except json.JSONDecodeError:
                    continue
                arrived += int(row.get("arrived", 0))
                units += int(row.get("units", 0))
            elif line.startswith("NAV_DRIVE {"):
                try:
                    row = json.loads(line[len("NAV_DRIVE "):])
                except json.JSONDecodeError:
                    continue
                contacts = int(row.get("wall_contacts", {}).get("contact_unit_ticks", 0))
                done = True
    return {"arrived": arrived, "crews": units, "contacts": contacts} if done else None


def runs(folder):
    out = {}
    for path in glob.glob(os.path.join(folder, "terminus-*-*.log")):
        m = re.search(r"terminus-(\w+)-(\d+)\.log$", path)
        if m:
            out[(m.group(1), int(m.group(2)))] = read_run(path)
    return out


def guard(diffs, worse_is_up):
    n = len(diffs)
    if n < 2:
        return 0.0, float("nan"), "n<2"
    total = sum(diffs)
    se = statistics.stdev(diffs) * math.sqrt(n)  # se of the SUM of n paired differences
    bound = 1.645 * se
    ok = total <= bound if worse_is_up else total >= -bound
    return total, se, "PASS" if ok else "FAIL"


def drop_worst(pairs, metric, worse_is_up):
    """Drop each arm's two worst runs (by that arm's own value), then pair what is left."""
    def worst(index):
        ranked = sorted(pairs, key=lambda p: p[index][metric], reverse=worse_is_up)
        return {p[0] for p in ranked[:2]}
    gone = worst(1) | worst(2)
    return [p for p in pairs if p[0] not in gone]


def main(argv):
    label = ""
    if "--label" in argv:
        i = argv.index("--label")
        label = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    base, new = runs(argv[0]), runs(argv[1])
    print("TERMINUS_AB %s base %s | new %s" % (label, argv[0], argv[1]))
    for squad in sorted({k[0] for k in base} | {k[0] for k in new}):
        seeds = sorted({k[1] for k in base if k[0] == squad} | {k[1] for k in new if k[0] == squad})
        pairs, missing = [], []
        for seed in seeds:
            b, n = base.get((squad, seed)), new.get((squad, seed))
            if b is None or n is None:
                missing.append(seed)
                continue
            pairs.append((seed, b, n))
        print("== %s (%d seeds)" % (squad, len(pairs)) + ("  MISSING seeds %s" % missing if missing else ""))
        if not pairs:
            continue
        crews = sum(p[1]["crews"] for p in pairs)
        d_arr = [p[2]["arrived"] - p[1]["arrived"] for p in pairs]
        total, se, verdict = guard(d_arr, worse_is_up=False)
        print("  arrivals base %d new %d of %d: diff %+d se %.2f 1.645se %.1f: %s" % (
                sum(p[1]["arrived"] for p in pairs), sum(p[2]["arrived"] for p in pairs), crews, total, se, 1.645 * se, verdict))
        d_con = [p[2]["contacts"] - p[1]["contacts"] for p in pairs]
        total, se, verdict = guard(d_con, worse_is_up=True)
        print("  contact-ticks base %d new %d: diff %+d se %.1f 1.645se %.1f: %s" % (
                sum(p[1]["contacts"] for p in pairs), sum(p[2]["contacts"] for p in pairs), total, se, 1.645 * se, verdict))
        for metric, up in (("arrived", False), ("contacts", True)):
            kept = drop_worst(pairs, metric, up)
            total, se, verdict = guard([p[2][metric] - p[1][metric] for p in kept], worse_is_up=up)
            print("  %s without each arm's two worst runs (%d pairs): diff %+d se %.1f: %s" % (metric, len(kept), total, se, verdict))
        print("  per seed arrived(contacts): " + " ".join("%d:%d>%d(%d>%d)" % (
                p[0], p[1]["arrived"], p[2]["arrived"], p[1]["contacts"], p[2]["contacts"]) for p in pairs))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

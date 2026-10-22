#!/usr/bin/env python3
"""Round 38 (settle): the judge for S1's bar (_agents/streams/settle.md Status, filed before any number).

    python3 tests/settle/settle_judge.py s1 PROBE_DIR FIGHT_DIR CENSUS_BASE.jsonl CENSUS_ARM.jsonl BASE_ARM NEW_ARM

PROBE_DIR / FIGHT_DIR are orders-probe output folders (rows.jsonl, runs.jsonl, logs/). Prints PASS/FAIL per line and a
final VERDICT line. The guards reuse orders' judge (tests/control/orders_judge.py) so the lines are the ones its bars read.
"""
import glob
import json
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "control"))
import orders_judge as oj  # noqa: E402

LONG_M = 25.0


def moved(row):
    return max(row["place_m"], 0.0) + max(row["twitch_m"], 0.0)


def keyed(rows, arm):
    return {(r["map"], r["squads"], r["route"], r["seed"], r["squad"]): r for r in rows if r["arm"] == arm}


def turned(folder, arm):
    n = total = 0
    for path in glob.glob(os.path.join(folder, "logs", "*-%s-s*.log" % arm)):
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("DEPLOY_TRACE "):
                    total += 1
                    n += 1 if json.loads(line.split(" ", 1)[1]).get("fit", {}).get("turned") else 0
    return n, total


def s1(argv):
    probe, fight, census_b, census_n, base, new = argv
    lines = []
    rows = oj.load(os.path.join(probe, "rows.jsonl"))
    b, n = keyed(rows, base), keyed(rows, new)
    common = [k for k in b if k in n]
    t, deploys = turned(probe, new)
    differ = any(json.dumps({k: v for k, v in b[c].items() if k != "arm"}, sort_keys=True)
                 != json.dumps({k: v for k, v in n[c].items() if k != "arm"}, sort_keys=True) for c in common)
    long_b = sum(1 for c in common if moved(b[c]) >= LONG_M)
    long_n = sum(1 for c in common if moved(n[c]) >= LONG_M)
    counter = t > 0 and differ
    lines.append("%s counter: deploys turned %d of %d on %s, rows differ %s; squads %d" % (
        "PASS" if counter else "FAIL", t, deploys, new, differ, len(common)))
    workload = long_b >= 10
    sum_b = sum(moved(b[c]) for c in common)
    sum_n = sum(moved(n[c]) for c in common)
    dec = workload and long_n <= 0.5 * long_b and sum_n < sum_b
    lines.append("%s deciding: squads with a crew moved >= %.0f m after the deploy %d -> %d (<= %.1f; base >= 10: %s); "
                 "summed place+twitch %.1f -> %.1f m" % ("PASS" if dec else "FAIL", LONG_M, long_b, long_n, 0.5 * long_b,
                                                         workload, sum_b, sum_n))
    ok = counter and dec
    ok = oj.probe_guards(rows, base, new, lines, settle=True) and ok
    shapes = sum(1 for c in common if b[c]["halt_shape"] != n[c]["halt_shape"])
    shape_ok = shapes <= max(1, 0.02 * len(common))
    lines.append("%s guard first shape: squads whose halt shape differs %d of %d (<= 2 %%); base %s | arm %s" % (
        "PASS" if shape_ok else "FAIL", shapes, len(common), dict(Counter(b[c]["halt_shape"] for c in common)),
        dict(Counter(n[c]["halt_shape"] for c in common))))
    ok = ok and shape_ok
    runs = oj.load(os.path.join(probe, "runs.jsonl"))
    for key in ("friend_contacts", "friend_contacts_foreign"):
        cb = sum(r.get(key, 0) for r in runs if r["arm"] == base)
        cn = sum(r.get(key, 0) for r in runs if r["arm"] == new)
        passed = cn <= cb * 1.1 + 5
        ok = ok and passed
        lines.append("%s guard %s %d -> %d (<= %.1f)" % ("PASS" if passed else "FAIL", key, cb, cn, cb * 1.1 + 5))
    for key in ("relays", "shape_flips", "parked_redeals", "redealt"):
        lines.append("  reported %s %d -> %d" % (key, oj.total(rows, base, key), oj.total(rows, new, key)))
    ok = oj.fight_guards(oj.load(os.path.join(fight, "runs.jsonl")), base, new, lines) and ok
    frows = oj.load(os.path.join(fight, "rows.jsonl"))
    fb, fn = keyed(frows, base), keyed(frows, new)
    fc = [k for k in fb if k in fn]
    lines.append("  reported fight probe: squads >= %.0f m %d -> %d, parked re-deals %d -> %d (%d squads)" % (
        LONG_M, sum(1 for c in fc if moved(fb[c]) >= LONG_M), sum(1 for c in fc if moved(fn[c]) >= LONG_M),
        oj.total(frows, base, "parked_redeals"), oj.total(frows, new, "parked_redeals"), len(fc)))
    cb, cn = oj.load(census_b), oj.load(census_n)
    f_b = sum(r.get("contacts_friend", 0) for r in cb)
    f_n = sum(r.get("contacts_friend", 0) for r in cn)
    s_b = sum(r.get("stuck_s", 0.0) for r in cb)
    s_n = sum(r.get("stuck_s", 0.0) for r in cn)
    c1, c2 = f_n <= f_b * 1.1 + 5, s_n <= s_b * 1.2 + 10
    lines.append("%s CPU guard friendly contacts %d -> %d (<= %.1f), fights %d/%d" % (
        "PASS" if c1 else "FAIL", f_b, f_n, f_b * 1.1 + 5, len(cb), len(cn)))
    lines.append("%s CPU guard stuck s %.1f -> %.1f (<= %.1f)" % ("PASS" if c2 else "FAIL", s_b, s_n, s_b * 1.2 + 10))
    lines.append("  outcomes base %s | arm %s" % (dict(sorted(Counter(str(r.get("outcome")) for r in cb).items())),
                                                 dict(sorted(Counter(str(r.get("outcome")) for r in cn).items()))))
    ok = ok and c1 and c2 and len(cb) > 0 and len(cn) > 0
    lines.append("VERDICT %s" % ("PASS" if ok else "FAIL"))
    print("\n".join(lines))
    return 0 if ok else 1


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] != "s1":
        print(__doc__)
        sys.exit(2)
    sys.exit(s1(sys.argv[2:]))

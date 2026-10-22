#!/usr/bin/env python3
"""Round 38 (settle): the judge for S1's bar (_agents/streams/settle.md Status, filed before any number).

    python3 tests/settle/settle_judge.py s1|s2 PROBE_DIR FIGHT_DIR CENSUS_BASE.jsonl CENSUS_ARM.jsonl BASE_ARM NEW_ARM

s1 = Bar S1 DEPLOY_FIT, s2 = Bar S2 DEPLOY_LATCH (the same guards; each its own counter and deciding lines).

    python3 tests/settle/settle_judge.py s3 FIGHT_DIR LATCH_ARM HELD_ARM O2_ARM

s3 = Bar H DEPLOY_HOLD (held v latch) and Bar S3 O2-on-settle (o2 v held), the fight probe only.

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


def runs_of(path):
    """A probe's run lines, without the error lines a run that never started prints (counted)."""
    rows = oj.load(path)
    return [r for r in rows if "arm" in r], sum(1 for r in rows if "arm" not in r)


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


def judge(mode, argv):
    probe, fight, census_b, census_n, base, new = argv
    lines = []
    rows = oj.load(os.path.join(probe, "rows.jsonl"))
    b, n = keyed(rows, base), keyed(rows, new)
    common = [k for k in b if k in n]
    differ = any(json.dumps({k: v for k, v in b[c].items() if k != "arm"}, sort_keys=True)
                 != json.dumps({k: v for k, v in n[c].items() if k != "arm"}, sort_keys=True) for c in common)
    frows = oj.load(os.path.join(fight, "rows.jsonl"))
    fb, fn = keyed(frows, base), keyed(frows, new)
    fc = [k for k in fb if k in fn]
    ok = (s1_lines if mode == "s1" else s2_lines)(probe, b, n, common, differ, fb, fn, fc, base, new, lines)
    return guards(rows, frows, fc, fb, fn, probe, fight, census_b, census_n, base, new, b, n, common, lines, ok)


def s1_lines(probe, b, n, common, differ, fb, fn, fc, base, new, lines):
    t, deploys = turned(probe, new)
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
    return counter and dec


def s2_lines(probe, b, n, common, differ, fb, fn, fc, base, new, lines):
    fl_b = sum(max(b[c]["shape_flips"], 0) for c in common)
    fl_n = sum(max(n[c]["shape_flips"], 0) for c in common)
    ff_b = sum(max(fb[c]["shape_flips"], 0) for c in fc)
    ff_n = sum(max(fn[c]["shape_flips"], 0) for c in fc)
    rs_b = sum(b[c].get("reseats", 0) for c in common)
    rs_n = sum(n[c].get("reseats", 0) for c in common)
    counter = differ and (fl_b + ff_b) >= 10
    lines.append("%s counter: rows differ %s, base shape flips (no-fight + fight) %d (>= 10); squads %d + %d" % (
        "PASS" if counter else "FAIL", differ, fl_b + ff_b, len(common), len(fc)))
    dec = fl_n <= 0.25 * fl_b + 1 and ff_n <= 0.25 * ff_b + 1 and rs_n <= rs_b
    lines.append("%s deciding: shape flips no-fight %d -> %d (<= %.1f), fight %d -> %d (<= %.1f); reseats %d -> %d (no more)" % (
        "PASS" if dec else "FAIL", fl_b, fl_n, 0.25 * fl_b + 1, ff_b, ff_n, 0.25 * ff_b + 1, rs_b, rs_n))
    return counter and dec


def guards(rows, frows, fc, fb, fn, probe, fight, census_b, census_n, base, new, b, n, common, lines, ok):
    ok = oj.probe_guards(rows, base, new, lines, settle=True) and ok
    first = lambda r: (r.get("shapes") or [r["halt_shape"]])[0]
    shapes = sum(1 for c in common if first(b[c]) != first(n[c]))
    shape_ok = shapes <= max(1, 0.03 * len(common))
    lines.append("%s guard first shape: squads whose first halt shape differs %d of %d (<= 3 %%); base %s | arm %s" % (
        "PASS" if shape_ok else "FAIL", shapes, len(common), dict(Counter(first(b[c]) for c in common)),
        dict(Counter(first(n[c]) for c in common))))
    ok = ok and shape_ok
    runs, _ = runs_of(os.path.join(probe, "runs.jsonl"))
    for key in ("friend_contacts", "friend_contacts_foreign"):
        cb = sum(r.get(key, 0) for r in runs if r["arm"] == base)
        cn = sum(r.get(key, 0) for r in runs if r["arm"] == new)
        passed = cn <= cb * 1.1 + 5
        ok = ok and passed
        lines.append("%s guard %s %d -> %d (<= %.1f)" % ("PASS" if passed else "FAIL", key, cb, cn, cb * 1.1 + 5))
    for key in ("relays", "shape_flips", "parked_redeals", "redealt"):
        lines.append("  reported %s %d -> %d" % (key, oj.total(rows, base, key), oj.total(rows, new, key)))
    fruns, ferr = runs_of(os.path.join(fight, "runs.jsonl"))
    if ferr:
        lines.append("  fight probe: %d run lines without an arm (runs that never started) left out" % ferr)
    ok = oj.fight_guards(fruns, base, new, lines) and ok
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
    lines.append("VERDICT %s %s v %s" % ("PASS" if ok else "FAIL", new, base))
    print("\n".join(lines))
    return 0 if ok else 1


def per_fight(rows, arm, field):
    from collections import defaultdict
    f = defaultdict(float)
    for r in rows:
        if r["arm"] == arm:
            f[(r["map"], r["squads"], r["seed"])] += max(r.get(field, 0) or 0, 0)
    return f


def s3(argv):
    import math
    import statistics as st
    fight, latch, held, o2 = argv
    rows = oj.load(os.path.join(fight, "rows.jsonl"))
    runs, _ = runs_of(os.path.join(fight, "runs.jsonl"))
    lines = []
    # Bar H: held v latch.
    rl, rh = per_fight(rows, latch, "parked_redeals"), per_fight(rows, held, "parked_redeals")
    sl, sh = per_fight(rows, latch, "reseats"), per_fight(rows, held, "reseats")
    tl, th = sum(rl.values()), sum(rh.values())
    counter = tl >= 10
    dec_h = counter and th <= 0.6 * tl and sum(sh.values()) <= sum(sl.values())
    lines.append("%s Bar H deciding: parked re-deals %d -> %d (<= %.1f; latch >= 10: %s), reseats %d -> %d (no more); fights %d/%d" % (
        "PASS" if dec_h else "FAIL", tl, th, 0.6 * tl, counter, sum(sl.values()), sum(sh.values()), len(rl), len(rh)))
    ok_h = oj.fight_guards(runs, latch, held, lines) and dec_h
    lines.append("VERDICT %s %s v %s" % ("PASS" if ok_h else "FAIL", held, latch))
    # Bar S3: o2 v held (R37.13's line + the re-deals no higher).
    b, n = list(per_fight(rows, held, "off_idle_s").values()), list(per_fight(rows, o2, "off_idle_s").values())
    if len(b) < 2 or len(n) < 2:
        lines.append("FAIL Bar S3 MISSING off_idle_s rows (%d/%d fights)" % (len(b), len(n)))
        b, n = b or [0.0], n or [0.0]
    se = math.sqrt(st.variance(b) / len(b) + st.variance(n) / len(n)) if len(b) > 1 and len(n) > 1 else float("inf")
    dec = st.mean(n) <= 0.5 * st.mean(b) and st.mean(b) - st.mean(n) > 1.645 * se
    lines.append("%s Bar S3 deciding: off_idle_s a fight %.1f -> %.1f (<= %.1f), drop %.1f v 1.645 se %.1f; fights %d/%d" % (
        "PASS" if dec else "FAIL", st.mean(b), st.mean(n), 0.5 * st.mean(b), st.mean(b) - st.mean(n), 1.645 * se, len(b), len(n)))
    ro = per_fight(rows, o2, "parked_redeals")
    to = sum(ro.values())
    red_ok = to <= th * 1.1 + 3
    lines.append("%s Bar S3 re-deals: parked re-deals %d -> %d (<= %.1f) [latch alone %d]" % (
        "PASS" if red_ok else "FAIL", th, to, th * 1.1 + 3, tl))
    pr = sum(r.get("parked_returns", 0) for r in runs if r["arm"] == o2)
    lines.append("%s counter: parked_returns %d" % ("PASS" if pr > 0 else "FAIL", pr))
    ok = oj.fight_guards(runs, held, o2, lines) and dec and red_ok and pr > 0
    lines.append("VERDICT %s %s v %s" % ("PASS" if ok else "FAIL", o2, held))
    print("\n".join(lines))
    return 0 if ok and ok_h else 1


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "s3":
        sys.exit(s3(sys.argv[2:]))
    if len(sys.argv) < 2 or sys.argv[1] not in ("s1", "s2"):
        print(__doc__)
        sys.exit(2)
    sys.exit(judge(sys.argv[1], sys.argv[2:]))

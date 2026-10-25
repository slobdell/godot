#!/usr/bin/env python3
"""Round 38 (settle): the judge for S1's bar (_agents/streams/settle.md Status, filed before any number).

    python3 tests/settle/settle_judge.py s1|s2 PROBE_DIR FIGHT_DIR CENSUS_BASE.jsonl CENSUS_ARM.jsonl BASE_ARM NEW_ARM

s1 = Bar S1 DEPLOY_FIT, s2 = Bar S2 DEPLOY_LATCH (the same guards; each its own counter and deciding lines).

    python3 tests/settle/settle_judge.py s3 FIGHT_DIR LATCH_ARM HELD_ARM O2_ARM

s3 = Bar H DEPLOY_HOLD (held v latch) and Bar S3 O2-on-settle (o2 v held), the fight probe only.

    python3 tests/settle/settle_judge.py h2 FIGHT_DIR BASE_ARM HELD_ARM

h2 = round 39's Bar H v2: the same hold, judged on the REDEAL_TRACE lines in FIGHT_DIR/logs (needs --deploy-trace on both arms).

    python3 tests/settle/settle_judge.py s2v3 PROBE FIGHT3 FIGHT5 CENSUS_BASE.jsonl CENSUS_ARM.jsonl BASE_ARM NEW_ARM

s2v3 = R38.15's S2 v3 bar: s2's lines, with the first-shape guard read against the ground the squad stands on (the
STAND_TRACE lines) and never-in as a total.

    python3 tests/settle/settle_judge.py t1 PROBE FIGHT3 FIGHT5 BASE NEW

t1 = round 40's Bar T1 (settle.md Status): the deploy trigger, judged on cap deploys and the wait from arrival to deploy.

PROBE_DIR / FIGHT_DIR are orders-probe output folders (rows.jsonl, runs.jsonl, logs/). Prints PASS/FAIL per line and a
final VERDICT line. The guards reuse orders' judge (tests/control/orders_judge.py) so the lines are the ones its bars read.
"""
import collections
import glob
import gzip
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
    for path in glob.glob(os.path.join(folder, "logs", "*-%s-s*.log" % arm)) + \
            glob.glob(os.path.join(folder, "logs", "*-%s-s*.log.gz" % arm)):
        with (gzip.open(path, "rt", errors="replace") if path.endswith(".gz") else open(path, errors="replace")) as f:
            for line in f:
                if line.startswith("DEPLOY_TRACE "):
                    total += 1
                    n += 1 if json.loads(line.split(" ", 1)[1]).get("fit", {}).get("turned") else 0
    return n, total


def streets(folder, arm):
    """S1 v5 (R38.37): per cell (map-squads-route), the herringbone deploys whose street axis was set / null, and the
    turns the street refused."""
    cells = collections.defaultdict(lambda: {"set": 0, "null": 0, "refused": 0})
    for path in glob.glob(os.path.join(folder, "logs", "*-%s-s*.log" % arm)):
        cell = "-".join(os.path.basename(path).split("-")[:3])
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("DEPLOY_TRACE "):
                    fit = json.loads(line.split(" ", 1)[1]).get("fit", {})
                    if "street" in fit:
                        cells[cell][fit["street"]] += 1
                        cells[cell]["refused"] += 1 if fit.get("street_refused") else 0
    return dict(cells)


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


def s1v2(argv):
    """R38.11's bar: python3 settle_judge.py s1v2 PROBE FIGHT3 FIGHT5 BASE NEW"""
    probe, fight3, fight5, base, new = argv
    lines = []
    rows = oj.load(os.path.join(probe, "rows.jsonl"))
    b, n = keyed(rows, base), keyed(rows, new)
    common = [k for k in b if k in n]
    t, deploys = turned(probe, new)
    counter = t > 0
    lines.append("%s counter: deploys turned %d of %d on %s; squads %d" % ("PASS" if counter else "FAIL", t, deploys, new, len(common)))
    leg_b = sum(1 for c in common if b[c]["deploy_leg_m"] >= LONG_M)
    leg_n = sum(1 for c in common if n[c]["deploy_leg_m"] >= LONG_M)
    dec = leg_b >= 10 and leg_n <= 0.5 * leg_b
    # R38.34 (S1 v4, the fit stacked on the latch): the deciding line is reported, the guards judged.
    dec_judged = os.environ.get("SETTLE_S1_DECIDING_JUDGED", "1") != "0"
    lines.append("%s deciding: squads with a deploy leg >= %.0f m %d -> %d (<= %.1f; base >= 10)" % (
        ("PASS" if dec else "FAIL") if dec_judged else "  reported", LONG_M, leg_b, leg_n, 0.5 * leg_b))
    dec = dec or not dec_judged
    tw_b = sum(1 for c in common if b[c]["twitch_m"] >= 15)
    tw_n = sum(1 for c in common if n[c]["twitch_m"] >= 15)
    g_tw = tw_n <= tw_b
    lines.append("%s guard twitch: squads with twitch >= 15 m %d -> %d (not up)" % ("PASS" if g_tw else "FAIL", tw_b, tw_n))
    nb = sum(1 for sq in oj.by_run(rows, base).values() if oj.run_all_in(sq) < 0)
    nn = sum(1 for sq in oj.by_run(rows, new).values() if oj.run_all_in(sq) < 0)
    g_ni = nn <= nb
    lines.append("%s guard never-in: %d -> %d runs (arm <= base)" % ("PASS" if g_ni else "FAIL", nb, nn))
    first = lambda r: (r.get("shapes") or [r["halt_shape"]])[0]
    shapes = sum(1 for c in common if first(b[c]) != first(n[c]))
    g_sh = shapes <= max(1, 0.03 * len(common))
    lines.append("%s guard first shape: differs %d of %d (<= 3 %%)" % ("PASS" if g_sh else "FAIL", shapes, len(common)))
    runs, _ = runs_of(os.path.join(probe, "runs.jsonl"))
    g_c = True
    for key in ("friend_contacts", "friend_contacts_foreign"):
        cb = sum(r.get(key, 0) for r in runs if r["arm"] == base)
        cn = sum(r.get(key, 0) for r in runs if r["arm"] == new)
        passed = cn <= cb * 1.1 + 5
        g_c = g_c and passed
        lines.append("%s guard %s %d -> %d (<= %.1f)" % ("PASS" if passed else "FAIL", key, cb, cn, cb * 1.1 + 5))
    g_f = True
    for label, d in (("3-squad", fight3), ("5-squad (--probe-budget=3000)", fight5)):
        fr, ferr = runs_of(os.path.join(d, "runs.jsonl"))
        lines.append("  fight read %s (%d runs that never started)" % (label, ferr))
        g_f = oj.fight_guards(fr, base, new, lines) and g_f and ferr == 0
    lines.append("  reported: place+twitch >= 25 m squads %d -> %d" % (sum(1 for c in common if moved(b[c]) >= LONG_M),
                                                                       sum(1 for c in common if moved(n[c]) >= LONG_M)))
    cells = streets(probe, new)
    if cells:
        tot = {k: sum(c[k] for c in cells.values()) for k in ("set", "null", "refused")}
        lines.append("  reported street axis (herringbone deploys): set %d, null %d; turns refused %d" % (
            tot["set"], tot["null"], tot["refused"]))
        for cell in sorted(cells):
            c = cells[cell]
            lines.append("    %s: set %d null %d refused %d" % (cell, c["set"], c["null"], c["refused"]))
    ok = counter and dec and g_tw and g_ni and g_sh and g_c and g_f
    lines.append("VERDICT %s %s v %s (S1 v2, R38.11)" % ("PASS" if ok else "FAIL", new, base))
    print("\n".join(lines))
    return 0 if ok else 1


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


def first(row):
    return (row.get("shapes") or [row["halt_shape"]])[0]


def shape_differs(probe, base, new, b, n, common, lines):
    """Bars S1 / S2 as filed: the first halt shape differs in <= 3 % of squads."""
    shapes = sum(1 for c in common if first(b[c]) != first(n[c]))
    shape_ok = shapes <= max(1, 0.03 * len(common))
    lines.append("%s guard first shape: squads whose first halt shape differs %d of %d (<= 3 %%); base %s | arm %s" % (
        "PASS" if shape_ok else "FAIL", shapes, len(common), dict(Counter(first(b[c]) for c in common)),
        dict(Counter(first(n[c]) for c in common))))
    return shape_ok


# R38.15 (S2 v3): the shape the doctrine table's hold pick stands in on each terrain (every deploy of S2's re-read did).
EXPECTED = {"lanes": "herringbone", "dense": "herringbone", "open": "coil"}
NATO = ["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot"]


# The reference terrain: "anchor" = terrain_at the squad's first deploy anchor (DEPLOY_TRACE anchor_terrain; the deploy is
# the same in both arms and its anchor is not moved by the shape that stands), "stand" = terrain_at the crews' centroid
# STAND_TRACE_S after it (STAND_TRACE; the shape that stands moves it). env SETTLE_V3_REFERENCE, default anchor.
REFERENCE = os.environ.get("SETTLE_V3_REFERENCE", "anchor")


def stands(probe, arm, key):
    """{squad index: {"terrain": the reference terrain}} of one probe run, from the squad's first DEPLOY_TRACE
    (anchor_terrain) or STAND_TRACE line (terrain), by REFERENCE."""
    m, squads, route, seed = key
    out = {}
    path = os.path.join(probe, "logs", "%s-%d-%s-%s-s%d.log" % (m, squads, route, arm, seed))
    if not os.path.exists(path):
        return out
    tag, field = ("DEPLOY_TRACE ", "anchor_terrain") if REFERENCE == "anchor" else ("STAND_TRACE ", "terrain")
    with open(path, errors="replace") as f:
        for line in f:
            if line.startswith(tag):
                d = json.loads(line.split(" ", 1)[1])
                letter = d["leader"].split("_")[1] if d["leader"].count("_") >= 2 else ""
                if letter in NATO and field in d:
                    out.setdefault(NATO.index(letter) + 1, {"terrain": d[field]})
    return out


def wrong_shapes(probe, arm, rows):
    """{right, wrong, no halt, no stand} over one arm's squads: wrong = the first standing shape is not the one the table
    stands in on the terrain where the squad stands (the same terrain function for every arm)."""
    tally, wrong = Counter(), []
    cache = {}
    for c, r in rows.items():
        run = c[:4]
        if run not in cache:
            cache[run] = stands(probe, arm, run)
        st = cache[run].get(c[4])
        shape = first(r)
        if shape == "":
            tally["no halt"] += 1
        elif st is None:
            tally["no stand"] += 1
        elif shape != EXPECTED.get(st["terrain"], shape):
            tally["wrong"] += 1
            wrong.append((c, st["terrain"], shape))
        else:
            tally["right"] += 1
    return tally, wrong


def shape_wrong(probe, base, new, b, n, common, lines, judged=True):
    """R38.15 (S2 v3): squads whose first shape is wrong for the ground they stand on, arm <= base. R38.20 (S2 v4): the
    same count REPORTED, not judged (judged=False: the arm latches the read it is judged by)."""
    tb, wb = wrong_shapes(probe, base, {c: b[c] for c in common})
    tn, wn = wrong_shapes(probe, new, {c: n[c] for c in common})
    ok = tb["right"] + tb["wrong"] > 0 and tn["wrong"] <= tb["wrong"]
    label = ("PASS" if ok else "FAIL") + " guard" if judged else "  reported"
    lines.append("%s first shape wrong for the ground (reference %s): %d -> %d%s; base %s | arm %s" % (
        label, REFERENCE, tb["wrong"], tn["wrong"], " (arm <= base)" if judged else "", dict(tb), dict(tn)))
    for arm, w in ((base, wb), (new, wn)):
        lines.append("  wrong on %s: %s" % (arm, " ".join("%s-%d-%s-s%d#%d:%s/%s" % (c + (t, s)) for c, t, s in w) or "none"))
    return ok if judged else True


def relays_reported(folder, arm, lines):
    """R38.20: the anchor latch's re-lays at the deploy (DEPLOY_TRACE latch_lays) and the deploys that hit the cap."""
    lays, capped, deploys = 0, [], 0
    for path in sorted(glob.glob(os.path.join(folder, "logs", "*-%s-s*.log" % arm))):
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("DEPLOY_TRACE "):
                    d = json.loads(line.split(" ", 1)[1])
                    deploys += 1
                    lays += max(int(d.get("latch_lays", 0)), 0)
                    if d.get("latch_capped"):
                        capped.append("%s:%s" % (os.path.basename(path)[:-4], d["leader"]))
    lines.append("  reported %s deploy re-lays %d over %d deploys; at the cap %d: %s" % (arm, lays, deploys, len(capped),
                                                                                    " ".join(capped) or "none"))


def guards(rows, frows, fc, fb, fn, probe, fight, census_b, census_n, base, new, b, n, common, lines, ok,
           shape_guard=shape_differs, never_in_total=False):
    if never_in_total:
        # R38.15: never-in is the total over the fresh seeds, latch <= main; every other per-cell line as filed.
        cell_lines = []
        oj.probe_guards(rows, base, new, cell_lines, settle=True)
        failed = [l for l in cell_lines if l.startswith("  FAIL") and "never-in" not in l]
        lines.extend(l for l in cell_lines if l.startswith("  FAIL"))
        lines.append("%s probe guards but never-in (%s)" % ("FAIL" if failed else "PASS", cell_lines[-1].split(" ", 1)[1]))
        nb = sum(1 for sq in oj.by_run(rows, base).values() if oj.run_all_in(sq) < 0)
        nn = sum(1 for sq in oj.by_run(rows, new).values() if oj.run_all_in(sq) < 0)
        lines.append("%s guard never-in (R38.15): %d -> %d runs (arm <= base)" % ("PASS" if nn <= nb else "FAIL", nb, nn))
        ok = ok and not failed and nn <= nb
    else:
        ok = oj.probe_guards(rows, base, new, lines, settle=True) and ok
    ok = shape_guard(probe, base, new, b, n, common, lines) and ok
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


def s2v3(argv):
    """R38.15's bar: python3 settle_judge.py s2v3 PROBE FIGHT3 FIGHT5 CENSUS_BASE CENSUS_ARM BASE NEW"""
    probe, fight3, fight5, census_b, census_n, base, new = argv
    lines = []
    rows = oj.load(os.path.join(probe, "rows.jsonl"))
    b, n = keyed(rows, base), keyed(rows, new)
    common = [k for k in b if k in n]
    differ = any(json.dumps({k: v for k, v in b[c].items() if k != "arm"}, sort_keys=True)
                 != json.dumps({k: v for k, v in n[c].items() if k != "arm"}, sort_keys=True) for c in common)
    frows = oj.load(os.path.join(fight3, "rows.jsonl"))
    fb, fn = keyed(frows, base), keyed(frows, new)
    fc = [k for k in fb if k in fn]
    ok = s2_lines(probe, b, n, common, differ, fb, fn, fc, base, new, lines)
    ok5 = []
    f5, err5 = runs_of(os.path.join(fight5, "runs.jsonl"))
    g5 = oj.fight_guards(f5, base, new, ok5) and err5 == 0
    ok = g5 and ok
    lines.append("5-squad fight read (--probe-budget=3000; %d runs that never started):" % err5)
    lines.extend(ok5)
    if os.environ.get("SETTLE_SHAPE_JUDGED", "1") == "0":
        # R38.20 (S2 v4): first shape reported, not judged; the anchor latch's re-lays reported.
        relays_reported(probe, new, lines)
        shape = lambda *a: shape_wrong(*a, judged=False)
    else:
        shape = shape_wrong
    code = guards(rows, frows, fc, fb, fn, probe, fight3, census_b, census_n, base, new, b, n, common, lines, ok,
                  shape_guard=shape, never_in_total=True)
    return code


def cleared(folder, arm):
    """S1 route-clear: deploys, and seats moved clear on deploys' own updates (DEPLOY_TRACE "cleared")."""
    n = total = 0
    for path in glob.glob(os.path.join(folder, "logs", "*-%s-s*.log" % arm)) + \
            glob.glob(os.path.join(folder, "logs", "*-%s-s*.log.gz" % arm)):
        with (gzip.open(path, "rt", errors="replace") if path.endswith(".gz") else open(path, errors="replace")) as f:
            for line in f:
                if line.startswith("DEPLOY_TRACE "):
                    total += 1
                    n += int(json.loads(line.split(" ", 1)[1]).get("cleared", 0))
    return n, total


def s1c(argv, v3b=False):
    """Round 39 Bar S1 route-clear (settle.md Status, filed before any number):
    python3 settle_judge.py s1c PROBE FIGHT3 FIGHT5 BASE NEW
    v3b (round 40 Bar S1 v3b, R40.15, amended before any number): deciding = squads with twitch >= 15 m, arm <= 0.85 x
    base with base >= 20; never-in a guard (arm <= base, none new on any cell); every other s1c guard as filed."""
    probe, fight3, fight5, base, new = argv
    lines = []
    rows = oj.load(os.path.join(probe, "rows.jsonl"))
    b, n = keyed(rows, base), keyed(rows, new)
    common = [k for k in b if k in n]
    moved_n, deploys = cleared(probe, new)
    counter = moved_n > 0
    lines.append("%s counter: seats cleared %d over %d deploys on %s; squads %d" % ("PASS" if counter else "FAIL", moved_n,
                                                                                   deploys, new, len(common)))
    rb, rn = oj.by_run(rows, base), oj.by_run(rows, new)
    five = lambda run: run[1] == 5
    never_b = {k for k, sq in rb.items() if five(k) and oj.run_all_in(sq) < 0}
    never_n = {k for k, sq in rn.items() if five(k) and oj.run_all_in(sq) < 0}
    fresh = sorted(never_n - never_b)
    dec = len(never_b) >= 2 and len(never_n) <= len(never_b) - 1 and not fresh
    tw_b = sum(1 for c in common if b[c]["twitch_m"] >= 15)
    tw_n = sum(1 for c in common if n[c]["twitch_m"] >= 15)
    if v3b:
        dec = tw_b >= 20 and tw_n <= 0.85 * tw_b
        lines.append("%s deciding (R40.15): squads with twitch >= 15 m %d -> %d (<= %.1f, 0.85 x base; base >= 20)" % (
            "PASS" if dec else "FAIL", tw_b, tw_n, 0.85 * tw_b))
    else:
        lines.append("%s deciding: never-in runs on the 5-squad cells %d -> %d (<= base - 1, base >= 2) and none new (%d new: %s)" % (
        "PASS" if dec else "FAIL", len(never_b), len(never_n), len(fresh), fresh))
    lines.append("    base never-in: %s" % sorted(never_b))
    lines.append("    arm never-in: %s" % sorted(never_n))
    nb = sum(1 for sq in rb.values() if oj.run_all_in(sq) < 0)
    nn = sum(1 for sq in rn.values() if oj.run_all_in(sq) < 0)
    g_ni = nn <= nb
    if v3b:
        new_any = sorted({k for k, sq in rn.items() if oj.run_all_in(sq) < 0} - {k for k, sq in rb.items() if oj.run_all_in(sq) < 0})
        g_ni = g_ni and not new_any
        lines.append("%s guard never-in, every cell: %d -> %d runs (arm <= base) and none new (%d new: %s)" % (
            "PASS" if g_ni else "FAIL", nb, nn, len(new_any), new_any))
    else:
        lines.append("%s guard never-in, every cell: %d -> %d runs (arm <= base)" % ("PASS" if g_ni else "FAIL", nb, nn))
    both = [k for k in rb if k in rn and oj.run_all_in(rb[k]) >= 0 and oj.run_all_in(rn[k]) >= 0]
    tb = sum(oj.run_all_in(rb[k]) for k in both) / max(len(both), 1)
    tn = sum(oj.run_all_in(rn[k]) for k in both) / max(len(both), 1)
    g_t = tn <= tb * 1.10 + 1.0
    lines.append("%s guard all-in time: mean over %d runs in on both %.1f -> %.1f s (<= %.1f)" % (
        "PASS" if g_t else "FAIL", len(both), tb, tn, tb * 1.10 + 1.0))
    g_tw = tw_n <= tw_b
    if not v3b:
        lines.append("%s guard twitch: squads with twitch >= 15 m %d -> %d (not up)" % ("PASS" if g_tw else "FAIL", tw_b, tw_n))
    shapes = sum(1 for c in common if first(b[c]) != first(n[c]))
    g_sh = shapes <= max(1, 0.03 * len(common))
    lines.append("%s guard first shape: differs %d of %d (<= 3 %%)" % ("PASS" if g_sh else "FAIL", shapes, len(common)))
    fl_b = sum(max(int(b[c].get("shape_flips", 0)), 0) for c in common)
    fl_n = sum(max(int(n[c].get("shape_flips", 0)), 0) for c in common)
    g_fl = fl_n <= fl_b + 3
    lines.append("%s guard shape flips (the latch): %d -> %d (<= base + 3)" % ("PASS" if g_fl else "FAIL", fl_b, fl_n))
    runs, _ = runs_of(os.path.join(probe, "runs.jsonl"))
    g_c = True
    for key in ("friend_contacts", "friend_contacts_foreign"):
        cb = sum(r.get(key, 0) for r in runs if r["arm"] == base)
        cn = sum(r.get(key, 0) for r in runs if r["arm"] == new)
        passed = cn <= cb * 1.1 + 5
        g_c = g_c and passed
        lines.append("%s guard %s %d -> %d (<= %.1f)" % ("PASS" if passed else "FAIL", key, cb, cn, cb * 1.1 + 5))
    g_f = True
    for label, d in (("3-squad", fight3), ("5-squad (--probe-budget=3000)", fight5)):
        fr, ferr = runs_of(os.path.join(d, "runs.jsonl"))
        lines.append("  fight read %s (%d runs that never started)" % (label, ferr))
        g_f = oj.fight_guards(fr, base, new, lines) and g_f and ferr == 0
    lines.append("  reported: place+twitch >= 25 m squads %d -> %d; deploy leg >= 25 m %d -> %d" % (
        sum(1 for c in common if moved(b[c]) >= LONG_M), sum(1 for c in common if moved(n[c]) >= LONG_M),
        sum(1 for c in common if b[c]["deploy_leg_m"] >= LONG_M), sum(1 for c in common if n[c]["deploy_leg_m"] >= LONG_M)))
    ok = counter and dec and g_ni and g_t and g_tw and g_sh and g_fl and g_c and g_f
    lines.append("VERDICT %s %s v %s (%s)" % ("PASS" if ok else "FAIL", new, base,
                                            "Bar S1 v3b, round 40, R40.15" if v3b else "Bar S1 route-clear, round 39"))
    print("\n".join(lines))
    return 0 if ok else 1


def capdeal_count(folder, arm):
    """Cap deal: deploys, and cap deploys the arm dealt (DEPLOY_TRACE "cap_deal" non-empty)."""
    n = total = 0
    for path in glob.glob(os.path.join(folder, "logs", "*-%s-s*.log" % arm)) + \
            glob.glob(os.path.join(folder, "logs", "*-%s-s*.log.gz" % arm)):
        with (gzip.open(path, "rt", errors="replace") if path.endswith(".gz") else open(path, errors="replace")) as f:
            for line in f:
                if line.startswith("DEPLOY_TRACE "):
                    total += 1
                    n += 1 if json.loads(line.split(" ", 1)[1]).get("cap_deal") else 0
    return n, total


def capdeal(argv):
    """Round 40 Bar cap deal (settle.md Status, filed before any number; R40.14):
    python3 settle_judge.py capdeal PROBE FIGHT3 FIGHT5 BASE NEW"""
    probe, fight3, fight5, base, new = argv
    lines = []
    rows = oj.load(os.path.join(probe, "rows.jsonl"))
    b, n = keyed(rows, base), keyed(rows, new)
    common = [k for k in b if k in n]
    dealt, deploys = capdeal_count(probe, new)
    counter = dealt > 0
    lines.append("%s counter: cap deploys dealt %d over %d deploys on %s; squads %d" % ("PASS" if counter else "FAIL", dealt,
                                                                                       deploys, new, len(common)))
    leg_b = sum(1 for c in common if b[c]["deploy_leg_m"] >= LONG_M)
    leg_n = sum(1 for c in common if n[c]["deploy_leg_m"] >= LONG_M)
    d1 = leg_b >= 20 and leg_n <= 0.75 * leg_b
    lines.append("%s deciding: squads with a deploy leg >= %.0f m %d -> %d (<= %.1f, 0.75 x base; base >= 20)" % (
        "PASS" if d1 else "FAIL", LONG_M, leg_b, leg_n, 0.75 * leg_b))
    tw_b = sum(1 for c in common if b[c]["twitch_m"] >= 15)
    tw_n = sum(1 for c in common if n[c]["twitch_m"] >= 15)
    d2 = tw_n <= tw_b
    lines.append("%s deciding: squads with twitch >= 15 m %d -> %d (no more)" % ("PASS" if d2 else "FAIL", tw_b, tw_n))
    rb, rn = oj.by_run(rows, base), oj.by_run(rows, new)
    nb = sum(1 for sq in rb.values() if oj.run_all_in(sq) < 0)
    nn = sum(1 for sq in rn.values() if oj.run_all_in(sq) < 0)
    new_any = sorted({k for k, sq in rn.items() if oj.run_all_in(sq) < 0} - {k for k, sq in rb.items() if oj.run_all_in(sq) < 0})
    g_ni = nn <= nb and not new_any
    lines.append("%s guard never-in, every cell: %d -> %d runs (arm <= base) and none new (%d new: %s)" % (
        "PASS" if g_ni else "FAIL", nb, nn, len(new_any), new_any))
    both = [k for k in rb if k in rn and oj.run_all_in(rb[k]) >= 0 and oj.run_all_in(rn[k]) >= 0]
    tb = sum(oj.run_all_in(rb[k]) for k in both) / max(len(both), 1)
    tn = sum(oj.run_all_in(rn[k]) for k in both) / max(len(both), 1)
    g_t = tn <= tb * 1.10 + 1.0
    lines.append("%s guard all-in time: mean over %d runs in on both %.1f -> %.1f s (<= %.1f)" % (
        "PASS" if g_t else "FAIL", len(both), tb, tn, tb * 1.10 + 1.0))
    out_b = sum(1 for c in common if b[c].get("anchor_outside"))
    out_n = sum(1 for c in common if n[c].get("anchor_outside"))
    g_o = out_n <= out_b + 2
    lines.append("%s guard places outside: %d -> %d (<= base + 2)" % ("PASS" if g_o else "FAIL", out_b, out_n))
    fl_b = sum(max(int(b[c].get("shape_flips", 0)), 0) for c in common)
    fl_n = sum(max(int(n[c].get("shape_flips", 0)), 0) for c in common)
    g_fl = fl_n <= fl_b + 3
    lines.append("%s guard shape flips: %d -> %d (<= base + 3)" % ("PASS" if g_fl else "FAIL", fl_b, fl_n))
    runs, _ = runs_of(os.path.join(probe, "runs.jsonl"))
    g_c = True
    for key in ("friend_contacts", "friend_contacts_foreign"):
        cb = sum(r.get(key, 0) for r in runs if r["arm"] == base)
        cn = sum(r.get(key, 0) for r in runs if r["arm"] == new)
        passed = cn <= cb * 1.1 + 5
        g_c = g_c and passed
        lines.append("%s guard %s %d -> %d (<= %.1f)" % ("PASS" if passed else "FAIL", key, cb, cn, cb * 1.1 + 5))
    g_f = True
    for label, d in (("3-squad", fight3), ("5-squad (--probe-budget=3000)", fight5)):
        fr, ferr = runs_of(os.path.join(d, "runs.jsonl"))
        lines.append("  fight read %s (%d runs that never started)" % (label, ferr))
        g_f = oj.fight_guards(fr, base, new, lines) and g_f and ferr == 0
    lines.append("  reported: place+twitch >= 25 m squads %d -> %d; first shape differs %d of %d" % (
        sum(1 for c in common if moved(b[c]) >= LONG_M), sum(1 for c in common if moved(n[c]) >= LONG_M),
        sum(1 for c in common if first(b[c]) != first(n[c])), len(common)))
    ok = counter and d1 and d2 and g_ni and g_t and g_o and g_fl and g_c and g_f
    lines.append("VERDICT %s %s v %s (Bar cap deal, round 40)" % ("PASS" if ok else "FAIL", new, base))
    print("\n".join(lines))
    return 0 if ok else 1


def redeal_traces(fight, arm):
    """REDEAL_TRACE lines (ElementPlan._trace_redeal) per arm: [(log, cause, crews moved), ...] from FIGHT/logs/*-ARM-s*.log."""
    out = []
    for path in sorted(glob.glob(os.path.join(fight, "logs", "*-%s-s*.log" % arm))):
        with open(path) as f:
            for line in f:
                if line.startswith("REDEAL_TRACE "):
                    d = json.loads(line.split(" ", 1)[1])
                    out.append((os.path.basename(path), d.get("cause", ""), len(d.get("moved", {}))))
    return out


def h2(argv):
    """Round 39 Bar H v2 (settle.md Status): held v main on REDEAL_TRACE, the fight probe only."""
    fight, base, held = argv
    rows = oj.load(os.path.join(fight, "rows.jsonl"))
    runs, err = runs_of(os.path.join(fight, "runs.jsonl"))
    lines = []
    tb, th = redeal_traces(fight, base), redeal_traces(fight, held)
    loss_b = sum(1 for t in tb if t[1] == "loss")
    other_b = sum(1 for t in tb if t[1] != "loss")
    other_h = sum(1 for t in th if t[1] != "loss")
    counter = loss_b >= 20
    lines.append("%s counter: %s re-lays after a loss %d (>= 20)" % ("PASS" if counter else "FAIL", base, loss_b))
    dec = counter and len(th) <= 0.2 * len(tb)
    lines.append("%s deciding: REDEAL_TRACE re-lays %d -> %d (<= %.1f); crews moved %d -> %d" % (
        "PASS" if dec else "FAIL", len(tb), len(th), 0.2 * len(tb), sum(t[2] for t in tb), sum(t[2] for t in th)))
    g_o = other_h <= other_b + 3
    lines.append("%s guard re-lays from any other cause %d -> %d (<= base + 3)" % ("PASS" if g_o else "FAIL", other_b, other_h))
    lines.append("  fight read (%d runs that never started; fights %d/%d)" % (
        err, sum(1 for r in runs if r["arm"] == base), sum(1 for r in runs if r["arm"] == held)))
    g_f = oj.fight_guards(runs, base, held, lines) and err == 0
    lines.append("  reported: parked_redeals %d -> %d, reseats %d -> %d" % (
        sum(per_fight(rows, base, "parked_redeals").values()), sum(per_fight(rows, held, "parked_redeals").values()),
        sum(per_fight(rows, base, "reseats").values()), sum(per_fight(rows, held, "reseats").values())))
    ok = counter and dec and g_o and g_f
    lines.append("VERDICT %s %s v %s (Bar H v2 DEPLOY_HOLD, round 39)" % ("PASS" if ok else "FAIL", held, base))
    print("\n".join(lines))
    return 0 if ok else 1


def waits(rows, arm, keys):
    """Seconds from each squad's arrival to its deploy (the probe's deploy_s - arrived_s), over `keys`."""
    out = []
    for k in keys:
        r = rows[k]
        if r.get("deploy_s", -1) >= 0 and r.get("arrived_s", -1) >= 0:
            out.append(r["deploy_s"] - r["arrived_s"])
    return out


def t1(argv):
    """Round 40 Bar T1 (settle.md Status, filed before any number): python3 settle_judge.py t1 PROBE FIGHT3 FIGHT5 BASE NEW"""
    import statistics as st
    probe, fight3, fight5, base, new = argv
    lines = []
    rows = oj.load(os.path.join(probe, "rows.jsonl"))
    b, n = keyed(rows, base), keyed(rows, new)
    common = [k for k in b if k in n]
    early = sum(1 for c in common if n[c].get("deploy_cause") in ("settled",) or (n[c].get("deploy_cause") == "all_in"
                and b[c].get("deploy_cause") == "cap"))
    counter = early > 0
    lines.append("%s counter: squads deployed by the new trigger where main capped, or on 'settled': %d of %d" % (
        "PASS" if counter else "FAIL", early, len(common)))
    cap_b = sum(1 for c in common if b[c].get("deploy_cause") == "cap")
    cap_n = sum(1 for c in common if n[c].get("deploy_cause") == "cap")
    d1 = cap_b >= 20 and cap_n <= 0.5 * cap_b
    lines.append("%s deciding: cap deploys %d -> %d (<= 50 %% of base, base >= 20)" % ("PASS" if d1 else "FAIL", cap_b, cap_n))
    wb, wn = waits(b, base, common), waits(n, new, common)
    mb, mn = (st.mean(wb) if wb else 0.0), (st.mean(wn) if wn else 0.0)
    d2 = bool(wb) and mn <= mb
    lines.append("%s guard arrival to deploy, mean over squads %.2f -> %.2f s (<= base); median %.1f -> %.1f" % (
        "PASS" if d2 else "FAIL", mb, mn, st.median(wb) if wb else -1, st.median(wn) if wn else -1))
    rb, rn = oj.by_run(rows, base), oj.by_run(rows, new)
    nb = sum(1 for sq in rb.values() if oj.run_all_in(sq) < 0)
    nn = sum(1 for sq in rn.values() if oj.run_all_in(sq) < 0)
    g_ni = nn <= nb
    lines.append("%s guard never-in, every cell: %d -> %d runs (arm <= base)" % ("PASS" if g_ni else "FAIL", nb, nn))
    both = [k for k in rb if k in rn and oj.run_all_in(rb[k]) >= 0 and oj.run_all_in(rn[k]) >= 0]
    ab = sum(oj.run_all_in(rb[k]) for k in both) / max(len(both), 1)
    an = sum(oj.run_all_in(rn[k]) for k in both) / max(len(both), 1)
    g_ai = an <= ab * 1.10 + 1.0
    lines.append("%s guard all-in time: mean over %d runs in on both %.1f -> %.1f s (<= %.1f, base x 1.10 + 1)" % (
        "PASS" if g_ai else "FAIL", len(both), ab, an, ab * 1.10 + 1.0))
    # Per cell (R36.6's lines but the twitch median): all-in, never-in, end foreign, crossed. An early halt moves a
    # straggler's last approach after its deploy, into place and twitch (main drives it before its deploy, uncounted), so
    # per-cell twitch medians are reported, and the visible reshuffle is judged as the count of squads twitching >= 15 m.
    g_p = True
    for cell in sorted({k[:3] for k in rb} | {k[:3] for k in rn}):
        ba = [oj.run_all_in(rb[k]) for k in rb if k[:3] == cell]
        na = [oj.run_all_in(rn[k]) for k in rn if k[:3] == cell]
        b_in, n_in = [t for t in ba if t >= 0], [t for t in na if t >= 0]
        bt = [max(sq["twitch_m"] for sq in rb[k]) for k in rb if k[:3] == cell]
        nt = [max(sq["twitch_m"] for sq in rn[k]) for k in rn if k[:3] == cell]
        bf = [min((sq["end_foreign_m"] for sq in rb[k] if sq["end_foreign_m"] >= 0), default=99) for k in rb if k[:3] == cell]
        nf = [min((sq["end_foreign_m"] for sq in rn[k] if sq["end_foreign_m"] >= 0), default=99) for k in rn if k[:3] == cell]
        bc = sum(1 for k in rb if k[:3] == cell for sq in rb[k] if sq["crossed"])
        nc = sum(1 for k in rn if k[:3] == cell for sq in rn[k] if sq["crossed"])
        checks = [("all-in", not b_in or oj.med(n_in) <= oj.med(b_in) * 1.2 + 3.0, "%.1f v %.1f" % (oj.med(b_in), oj.med(n_in))),
                  ("never-in", sum(1 for t in na if t < 0) <= sum(1 for t in ba if t < 0),
                   "%d v %d" % (sum(1 for t in ba if t < 0), sum(1 for t in na if t < 0))),
                  ("end foreign", oj.med(nf) >= oj.med(bf) - 3.0, "%.1f v %.1f" % (oj.med(bf), oj.med(nf))),
                  ("crossed", nc <= bc, "%d v %d" % (bc, nc))]
        for name, passed, text in checks:
            g_p = g_p and passed
            if not passed:
                lines.append("  FAIL guard %-12s %s: %s" % (name, " ".join(map(str, cell)), text))
        lines.append("    reported twitch median %s: %.1f v %.1f" % (" ".join(map(str, cell)), oj.med(bt), oj.med(nt)))
    lines.append(("PASS" if g_p else "FAIL") + " per-cell guards (all-in, never-in, end foreign, crossed)")
    tw_b = sum(1 for c in common if b[c]["twitch_m"] >= 15)
    tw_n = sum(1 for c in common if n[c]["twitch_m"] >= 15)
    g_tw = tw_n <= tw_b * 1.1 + 2
    lines.append("%s guard twitch: squads with twitch >= 15 m %d -> %d (<= base x 1.1 + 2)" % ("PASS" if g_tw else "FAIL", tw_b, tw_n))
    lines.append("  reported: place+twitch >= %.0f m squads %d -> %d" % (LONG_M, sum(1 for c in common if moved(b[c]) >= LONG_M),
                 sum(1 for c in common if moved(n[c]) >= LONG_M)))
    shapes = sum(1 for c in common if first(b[c]) != first(n[c]))
    g_sh = shapes <= max(1, 0.03 * len(common))
    lines.append("%s guard first shape: differs %d of %d (<= 3 %%)" % ("PASS" if g_sh else "FAIL", shapes, len(common)))
    fl_b = sum(max(int(b[c].get("shape_flips", 0)), 0) for c in common)
    fl_n = sum(max(int(n[c].get("shape_flips", 0)), 0) for c in common)
    g_fl = fl_n <= fl_b + 3
    lines.append("%s guard shape flips: %d -> %d (<= base + 3)" % ("PASS" if g_fl else "FAIL", fl_b, fl_n))
    po_b = sum(1 for c in common if b[c].get("anchor_outside"))
    po_n = sum(1 for c in common if n[c].get("anchor_outside"))
    g_po = po_n <= po_b + 2
    lines.append("%s guard places outside: %d -> %d (<= base + 2)" % ("PASS" if g_po else "FAIL", po_b, po_n))
    runs, _ = runs_of(os.path.join(probe, "runs.jsonl"))
    g_c = True
    for key in ("friend_contacts", "friend_contacts_foreign"):
        cb = sum(r.get(key, 0) for r in runs if r["arm"] == base)
        cn = sum(r.get(key, 0) for r in runs if r["arm"] == new)
        passed = cn <= cb * 1.1 + 5
        g_c = g_c and passed
        lines.append("%s guard %s %d -> %d (<= %.1f)" % ("PASS" if passed else "FAIL", key, cb, cn, cb * 1.1 + 5))
    g_f = True
    for label, d in (("3-squad", fight3), ("5-squad (--probe-budget=3000)", fight5)):
        fr, ferr = runs_of(os.path.join(d, "runs.jsonl"))
        lines.append("  fight read %s (%d runs that never started)" % (label, ferr))
        g_f = oj.fight_guards(fr, base, new, lines) and g_f and ferr == 0
    lines.append("  reported: deploy leg >= 25 m %d -> %d; all-in median per run %s" % (
        sum(1 for c in common if b[c]["deploy_leg_m"] >= LONG_M), sum(1 for c in common if n[c]["deploy_leg_m"] >= LONG_M),
        "%.1f -> %.1f s" % (st.median([oj.run_all_in(v) for v in rb.values() if oj.run_all_in(v) >= 0] or [-1]),
                            st.median([oj.run_all_in(v) for v in rn.values() if oj.run_all_in(v) >= 0] or [-1]))))
    ok = counter and d1 and d2 and g_ni and g_ai and g_p and g_tw and g_sh and g_fl and g_po and g_c and g_f
    lines.append("VERDICT %s %s v %s (Bar T1, round 40)" % ("PASS" if ok else "FAIL", new, base))
    print("\n".join(lines))
    return 0 if ok else 1


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "t1":
        sys.exit(t1(sys.argv[2:]))
    if len(sys.argv) >= 2 and sys.argv[1] == "h2":
        sys.exit(h2(sys.argv[2:]))
    if len(sys.argv) >= 2 and sys.argv[1] == "s2v3":
        sys.exit(s2v3(sys.argv[2:]))
    if len(sys.argv) >= 2 and sys.argv[1] == "s1c":
        sys.exit(s1c(sys.argv[2:]))
    if len(sys.argv) >= 2 and sys.argv[1] == "s1v3b":
        sys.exit(s1c(sys.argv[2:], v3b=True))
    if len(sys.argv) >= 2 and sys.argv[1] == "capdeal":
        sys.exit(capdeal(sys.argv[2:]))
    if len(sys.argv) >= 2 and sys.argv[1] == "s1v2":
        sys.exit(s1v2(sys.argv[2:]))
    if len(sys.argv) >= 2 and sys.argv[1] == "s3":
        sys.exit(s3(sys.argv[2:]))
    if len(sys.argv) < 2 or sys.argv[1] not in ("s1", "s2"):
        print(__doc__)
        sys.exit(2)
    sys.exit(judge(sys.argv[1], sys.argv[2:]))

#!/usr/bin/env python3
"""CP-F bar lines (a), (d), (e) at 1.645 se, paired by (faction, seed), from <root>/<arm>/<faction>/<task>-<seed>/screen.json.

R33.34 (the overnight judge item): with --wedged, a crew not still at the judge whose last state line (MANOEUVRE_STATE,
needs --turn-states) reads `pinned` (real speed < 0.3 m/s under |throttle| > 0.3) is WEDGED: counted apart, not as a mover.
That changes what (d) measures, so its numbers do not compare with a run read without it.

R33.23's amendment (the stage is barely seed-sensitive): with --distinct, the paired lines count each DISTINCT pair once
(two seeds whose NEW row and BASE row are both identical are one pair), so the se is over distinct pairs only; the
all-pairs numbers are printed beside them."""
import json, pathlib, statistics as st, sys, math, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hull_rest_moving import STATE, kind_of  # the one "pinned" rule (Tank.real_velocity), shared
DISTINCT = "--distinct" in sys.argv
WEDGED = "--wedged" in sys.argv
argv = [a for a in sys.argv if a not in ("--distinct", "--wedged")]
root = pathlib.Path(argv[1]); A, B = (argv[2], argv[3]) if len(argv) > 3 else ("new_drawn", "base_drawn")
runs = {}  # arm -> (task, faction, seed) -> {moving_all, moving_wt, settled, errs_wt}
for p in sorted(root.glob("*/*/*/screen.json")):
    arm, fac, case = p.parts[-4], p.parts[-3], p.parts[-2]
    seed = case.rsplit("-", 1)[-1]
    last = {}
    if WEDGED and (p.parent / "run.log").exists():
        for line in (p.parent / "run.log").read_text(errors="replace").splitlines():
            if line.startswith("SCREEN {"):
                break
            m = STATE.search(line)
            if m:
                last[m.group(2)] = m
    for row in json.loads(p.read_text()):
        if "squads" not in row: continue
        k = (row["scenario"], fac, seed)
        r = runs.setdefault(arm, {}).setdefault(k, {"all": 0, "wt": 0, "settled": float(row.get("settled_after_s", -1)), "errs": [], "focus": False,
                "sig": json.dumps(row, sort_keys=True), "wedged": 0, "wedged_wt": 0})
        for sq in row["squads"]:
            for c in sq.get("each", []):
                mv = 0 if c.get("still", True) else 1
                if mv and WEDGED and kind_of(last.get(c.get("unit", ""))) == "pinned":
                    mv = 0
                    r["wedged"] += 1
                    r["wedged_wt"] += 1 if c["class"] == "wheels/turret" else 0
                r["all"] += mv
                if c["class"] == "wheels/turret":
                    r["wt"] += mv; r["errs"].append(c["hull_error_deg"]); r["focus"] = True
def distinct(ks):
    seen, out = set(), []
    for k in ks:
        sig = (k[0], k[1], runs[A][k]["sig"], runs[B][k]["sig"])
        if sig not in seen:
            seen.add(sig); out.append(k)
    return out
def paired(task, key, fac=None):
    ks = [k for k in runs[A] if k[0] == task and k in runs[B] and (fac is None or k[1] == fac)]
    if DISTINCT:
        ks = distinct(ks)
    d = [runs[A][k][key] - runs[B][k][key] for k in ks]
    se = st.stdev(d) * math.sqrt(len(d)) if len(d) > 1 else 0.0  # se of the SUMMED paired difference
    return len(ks), sum(runs[A][k][key] for k in ks), sum(runs[B][k][key] for k in ks), sum(d), se
tasks = sorted({k[0] for k in runs[A]})
missing = {arm: sorted({(k[1], k[2], k[0]) for k in runs[A if arm == B else B]} - {(k[1], k[2], k[0]) for k in runs[arm]}) for arm in (A, B)}
print("arms", A, B, "runs", len(runs[A]), len(runs[B]), "missing:", missing)
print("(a) wheels/turret per task: median, share <= 15")
for t in tasks:
    e = [x for k, r in runs[A].items() if k[0] == t for x in r["errs"]]
    print("   %-24s n %3d median %5.1f  <=15 %5.1f %%" % (t, len(e), st.median(e), 100.0 * sum(1 for x in e if x <= 15) / len(e)))
print("(d) crews moving at the judge, summed over paired runs: new base diff se(sum) limit(1.645se) verdict")
for t in tasks:
    for key in ("wt", "all"):
        n, a, b, d, se = paired(t, key)
        print("   %-24s %-3s n %2d  %3d %3d  %+4d  se %5.1f  lim %+5.1f  %s" % (t, key, n, a, b, d, se, 1.645 * se, "PASS" if d <= 1.645 * se else "FAIL"))
if WEDGED:
    print("(d-wedged) crews WEDGED at the judge (not still, pinned by real speed), REPORTED: new base")
    for t in tasks:
        for key in ("wedged_wt", "wedged"):
            n, a, b, d, se = paired(t, key)
            print("   %-24s %-9s n %2d  %3d %3d  %+4d" % (t, key, n, a, b, d))
print("(e) never settled (-1 or >= 75) per task, runs holding wheels/turret: new base diff se lim")
for t in tasks:
    ks = [k for k in runs[A] if k[0] == t and k in runs[B] and runs[A][k]["focus"]]
    if DISTINCT:
        ks = distinct(ks)
    ns = lambda arm, k: 1 if runs[arm][k]["settled"] < 0 or runs[arm][k]["settled"] >= 75 else 0
    d = [ns(A, k) - ns(B, k) for k in ks]
    se = st.stdev(d) * math.sqrt(len(d)) if len(d) > 1 else 0.0
    sa = [runs[A][k]["settled"] if runs[A][k]["settled"] >= 0 else 75.0 for k in ks]; sb = [runs[B][k]["settled"] if runs[B][k]["settled"] >= 0 else 75.0 for k in ks]
    print("   %-24s n %2d  %2d %2d  %+3d  se %4.1f lim %+4.1f %s | settle median new %.1f base %.1f paired-diff median %+.1f" % (
        t, len(ks), sum(ns(A, k) for k in ks), sum(ns(B, k) for k in ks), sum(d), se, 1.645 * se, "PASS" if sum(d) <= 1.645 * se else "FAIL",
        st.median(sa), st.median(sb), st.median([x - y for x, y in zip(sa, sb)])))
print("(d) by faction, all classes: new/base")
for t in tasks:
    print("   %-24s" % t, "  ".join("%s %d/%d" % (f[:4], paired(t, "all", f)[1], paired(t, "all", f)[2]) for f in ("condemned", "gangs", "law", "syndicate")))

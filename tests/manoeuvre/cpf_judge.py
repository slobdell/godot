#!/usr/bin/env python3
"""CP-F bar lines (a), (d), (e) at 1.645 se, paired by (faction, seed), from <root>/<arm>/<faction>/<task>-<seed>/screen.json."""
import json, pathlib, statistics as st, sys, math
root = pathlib.Path(sys.argv[1]); A, B = (sys.argv[2], sys.argv[3]) if len(sys.argv) > 3 else ("new_drawn", "base_drawn")
runs = {}  # arm -> (task, faction, seed) -> {moving_all, moving_wt, settled, errs_wt}
for p in sorted(root.glob("*/*/*/screen.json")):
    arm, fac, case = p.parts[-4], p.parts[-3], p.parts[-2]
    seed = case.rsplit("-", 1)[-1]
    for row in json.loads(p.read_text()):
        if "squads" not in row: continue
        k = (row["scenario"], fac, seed)
        r = runs.setdefault(arm, {}).setdefault(k, {"all": 0, "wt": 0, "settled": float(row.get("settled_after_s", -1)), "errs": [], "focus": False})
        for sq in row["squads"]:
            for c in sq.get("each", []):
                mv = 0 if c.get("still", True) else 1
                r["all"] += mv
                if c["class"] == "wheels/turret":
                    r["wt"] += mv; r["errs"].append(c["hull_error_deg"]); r["focus"] = True
def paired(task, key, fac=None):
    ks = [k for k in runs[A] if k[0] == task and k in runs[B] and (fac is None or k[1] == fac)]
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
print("(e) never settled (-1 or >= 75) per task, runs holding wheels/turret: new base diff se lim")
for t in tasks:
    ks = [k for k in runs[A] if k[0] == t and k in runs[B] and runs[A][k]["focus"]]
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

#!/usr/bin/env python3
"""Round 34 (manoeuvre M1, the ruler): the hull-rest A/A. Two runs of the SAME arm on two seed sets, read as a pair.

Usage: hull_rest_aa.py <root> <armA> <armB>   (rows at <root>/<arm>/<faction>/<task>-<seed>/screen.json)
Pairs the i-th seed of A with the i-th seed of B per (task, faction) and prints, per task: crews moving at the judge
(by `still`, and by `real_mps` < 0.3 where the row carries it), wedged (reported moving, made < 0.3 m/s), the
wheels/turret hull-error median, settled_after_s; each as A total, B total, the paired sd a run and the se of the summed
difference (what a bar's guard must clear), and the swing |A - B| / mean in %. Report only.
"""
import json, pathlib, statistics as st, sys, math

FOCUS = "wheels/turret"
STILL = 0.3


def read(root, arm):
    runs = {}
    for p in sorted(pathlib.Path(root, arm).glob("*/*/screen.json")):
        fac, case = p.parts[-2], p.parts[-1 - 1]
        fac, case = p.parent.parent.name, p.parent.name
        task, seed = case.rsplit("-", 1)
        for row in json.loads(p.read_text()):
            if "squads" not in row:
                continue
            r = {"moving": 0, "moving_real": 0, "wedged": 0, "errs": [], "settled": float(row.get("settled_after_s", -1)), "n": 0}
            for sq in row["squads"]:
                for c in sq.get("each", []):
                    r["n"] += 1
                    mv = 0 if c.get("still", True) else 1
                    r["moving"] += mv
                    if "real_mps" in c:
                        real_mv = 1 if float(c["real_mps"]) >= STILL else 0
                        r["moving_real"] += real_mv
                        if mv and not real_mv:
                            r["wedged"] += 1
                    if c.get("class") == FOCUS:
                        r["errs"].append(float(c["hull_error_deg"]))
            runs.setdefault((task, fac), []).append((int(seed), r))
    for k in runs:
        runs[k].sort()
    return runs


def main(root, a, b):
    A, B = read(root, a), read(root, b)
    tasks = sorted({k[0] for k in A} | {k[0] for k in B})
    print("HULL_AA %s v %s under %s (pairs: the i-th seed of each per task x faction)" % (a, b, root))
    print("%-22s %-12s %5s | %8s %8s | %8s %8s %8s | %6s" % ("task", "metric", "pairs", "A", "B", "sd/run", "se(sum)", "k se", "swing"))
    for task in tasks:
        pairs = []
        for fac in sorted({k[1] for k in A if k[0] == task} | {k[1] for k in B if k[0] == task}):
            ra, rb = A.get((task, fac), []), B.get((task, fac), [])
            for (sa, xa), (sb, xb) in zip(ra, rb):
                pairs.append((xa, xb))
        if not pairs:
            continue
        for metric, f in (("moving", lambda r: r["moving"]), ("moving_real", lambda r: r["moving_real"]), ("wedged", lambda r: r["wedged"]),
                          ("settled_s", lambda r: r["settled"] if r["settled"] >= 0 else 75.0),
                          ("wt_err_med", lambda r: st.median(r["errs"]) if r["errs"] else float("nan"))):
            d = [f(xa) - f(xb) for xa, xb in pairs if not (math.isnan(f(xa)) or math.isnan(f(xb)))]
            if len(d) < 2:
                continue
            ta = sum(f(xa) for xa, _ in pairs if not math.isnan(f(xa)))
            tb = sum(f(xb) for _, xb in pairs if not math.isnan(f(xb)))
            sd = st.stdev(d)
            se = sd * math.sqrt(len(d))
            mean = (ta + tb) / 2.0
            print("%-22s %-12s %5d | %8.1f %8.1f | %8.2f %8.1f %8.1f | %5.0f%%" % (task, metric, len(d), ta, tb, sd, se, 1.645 * se, 100.0 * abs(ta - tb) / mean if mean else 0.0))
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:4]))

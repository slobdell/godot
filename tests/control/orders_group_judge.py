#!/usr/bin/env python3
"""Round 41 (orders O2): Bar O2's verdict, from tests/control/orders_o2_bar.sh's folder (filed in the brief's Status
before any number; unamended once numbers are seen).

    python3 tests/control/orders_group_judge.py OUT BASE_ARM NEW_ARM

OUT/group  his group order (runs.jsonl, rows.jsonl): DECIDING + the wait guards.
OUT/streets, OUT/his  the orders probe's cells: R36.6 probe guards per cell (orders_judge.probe_guards), contacts.
OUT/fight  the probe's fight: his kills, his losses, the CPU's losses (orders_judge.fight_guards).

Counter: the arm queued at least one squad. Deciding (his group order, all cells pooled, paired by map and seed): the
all-in time (a run with a squad never in counts as the window, WINDOW_S) falls: mean paired difference + 1.645 se < 0;
AND squads never in, arm <= base. Guards: each map's median all-in <= base + 5 s; friendly contacts <= base x 1.1 + 5;
the wait (C41.3 + the orchestrator's): of squads that waited, median <= 6 s; released by the 20 s cap <= 10 % of squads
queued; clicks where any squad waited > 5 s <= 50 % (per-squad median and max reported). Prints PASS/FAIL per line and a
VERDICT.
"""
import json
import math
import os
import statistics as st
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import orders_judge  # noqa: E402

WINDOW_S = 180.0


def load(path):
    return [json.loads(line) for line in open(path) if line.strip()] if os.path.exists(path) else []


def censored(run):
    return run["all_in_s"] if run["all_in_s"] >= 0 else WINDOW_S


def judge_group(folder, base, new, lines):
    runs = load(os.path.join(folder, "runs.jsonl"))
    rows = load(os.path.join(folder, "rows.jsonl"))
    b = {(r["map"], r["seed"]): r for r in runs if r["arm"] == base}
    n = {(r["map"], r["seed"]): r for r in runs if r["arm"] == new}
    keys = sorted(set(b) & set(n))
    ok = True
    if not keys:
        lines.append("FAIL group: no paired runs")
        return False
    queued = sum(n[k]["group"].get("depart_queued", 0) for k in keys)
    lines.append("%s counter: squads queued %d" % ("PASS" if queued > 0 else "FAIL", queued))
    ok = ok and queued > 0
    diffs = [censored(n[k]) - censored(b[k]) for k in keys]
    mean = st.mean(diffs)
    se = st.stdev(diffs) / math.sqrt(len(diffs)) if len(diffs) > 1 else float("inf")
    passed = mean + 1.645 * se < 0
    ok = ok and passed
    lines.append("%s deciding all-in: mean paired diff %+.1f s (se %.1f, n %d); median %.1f v %.1f s" % (
        "PASS" if passed else "FAIL", mean, se, len(keys), st.median(censored(b[k]) for k in keys),
        st.median(censored(n[k]) for k in keys)))
    never = lambda arm: sum(1 for r in rows if r["arm"] == arm and r["arrived_s"] < 0 and (r["map"], r["seed"]) in keys)
    passed = never(new) <= never(base)
    ok = ok and passed
    lines.append("%s deciding never-in squads: %d v %d" % ("PASS" if passed else "FAIL", never(base), never(new)))
    for m in sorted({k[0] for k in keys}):
        mk = [k for k in keys if k[0] == m]
        bm, nm = st.median(censored(b[k]) for k in mk), st.median(censored(n[k]) for k in mk)
        passed = nm <= bm + 5.0
        ok = ok and passed
        lines.append("  %s guard %-9s all-in median %.1f v %.1f s; never-in runs %d v %d (n %d)" % (
            "PASS" if passed else "FAIL", m, bm, nm, sum(1 for k in mk if b[k]["all_in_s"] < 0),
            sum(1 for k in mk if n[k]["all_in_s"] < 0), len(mk)))
    bc, nc = sum(b[k]["friend_contacts"] for k in keys), sum(n[k]["friend_contacts"] for k in keys)
    passed = nc <= bc * 1.1 + 5
    ok = ok and passed
    lines.append("%s guard contacts %d v %d" % ("PASS" if passed else "FAIL", bc, nc))
    # The wait guard: every squad's wait in the arm (0 = left on the click).
    waits = [w for k in keys for w in n[k]["group"].get("waits_s", {}).values()]
    waited = [w for w in waits if w > 0]
    by_squad = defaultdict(list)
    for k in keys:
        for sq, w in n[k]["group"].get("waits_s", {}).items():
            by_squad[sq].append(w)
    timeouts = sum(n[k]["group"].get("depart_timeout", 0) for k in keys)
    long_clicks = sum(1 for k in keys if any(w > 5.0 for w in n[k]["group"].get("waits_s", {}).values()))
    med_w = st.median(waited) if waited else 0.0
    checks = [("waited median", med_w <= 6.0, "%.1f s of %d squads that waited (of %d)" % (med_w, len(waited), len(waits))),
              ("cap releases", timeouts <= 0.1 * max(queued, 1), "%d of %d queued" % (timeouts, queued)),
              ("clicks > 5 s", long_clicks <= 0.5 * len(keys), "%d of %d clicks" % (long_clicks, len(keys)))]
    for name, passed, text in checks:
        ok = ok and passed
        lines.append("%s guard wait %s: %s" % ("PASS" if passed else "FAIL", name, text))
    for sq in sorted(by_squad, key=int):
        ws = by_squad[sq]
        lines.append("  wait squad %s: median %.1f max %.1f s (n %d)" % (sq, st.median(ws), max(ws), len(ws)))
    return ok


def main(argv):
    out, base, new = argv[1], argv[2], argv[3]
    lines = []
    ok = judge_group(os.path.join(out, "group"), base, new, lines)
    rows = load(os.path.join(out, "streets", "rows.jsonl"))
    runs = load(os.path.join(out, "streets", "runs.jsonl"))
    his, his_runs = load(os.path.join(out, "his", "rows.jsonl")), load(os.path.join(out, "his", "runs.jsonl"))
    for r in his + his_runs:
        r["map"] = "terminus_his"
    rows, runs = rows + his, runs + his_runs
    if not rows:
        lines.append("FAIL streets: no rows")
        ok = False
    else:
        ok = orders_judge.probe_guards(rows, base, new, lines) and ok
        bc = sum(r.get("friend_contacts", 0) for r in runs if r["arm"] == base)
        nc = sum(r.get("friend_contacts", 0) for r in runs if r["arm"] == new)
        passed = nc <= bc * 1.1 + 5
        ok = ok and passed
        lines.append("%s guard probe contacts %d v %d" % ("PASS" if passed else "FAIL", bc, nc))
    fight = load(os.path.join(out, "fight", "runs.jsonl"))
    ok = orders_judge.fight_guards(fight, base, new, lines) and ok
    print("\n".join(lines))
    print("VERDICT %s" % ("PASS" if ok else "FAIL"))


if __name__ == "__main__":
    main(sys.argv)

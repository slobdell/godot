#!/usr/bin/env python3
"""Round 37 (orders): the judged probe read against the bars in the brief's Status (O1, O2, O3).

    python3 tests/control/orders_judge.py o1 rows.jsonl BASE_ARM NEW_ARM [census_base.jsonl census_new.jsonl]
    python3 tests/control/orders_judge.py o1fight rows.jsonl BASE_ARM NEW_ARM
    python3 tests/control/orders_judge.py o2 rows.jsonl BASE_ARM NEW_ARM
    python3 tests/control/orders_judge.py o3 rows.jsonl BASE_ARM NEW_ARM runs.jsonl

Probe guards (each cell, medians over seeds; R36.6's): all-in (the cell run's last squad arrival) <= base x 1.2 + 3 s and
no more never-in seeds; twitch worst <= base + 3 m; end foreign min >= base - 3 m; crossed no higher. Fight guards
(per-fight totals): his kills, his losses, the CPU's losses each within base +/- 1.645 se (se from the base arm's
per-fight sd over n fights). Prints one PASS/FAIL line per line of the bar and a VERDICT.
"""
import json
import math
import statistics as st
import sys
from collections import defaultdict


def load(path):
    with open(path) as f:
        return [json.loads(line) for line in f if line.strip()]


def by_run(rows, arm):
    runs = defaultdict(list)
    for r in rows:
        if r["arm"] == arm:
            runs[(r["map"], r["squads"], r["route"], r["seed"])].append(r)
    return runs


def run_all_in(squads):
    times = [s["arrived_s"] for s in squads]
    return -1.0 if any(t < 0 for t in times) else max(times)


def med(xs):
    return st.median(xs) if xs else float("nan")


def probe_guards(rows, base, new, lines):
    b, n = by_run(rows, base), by_run(rows, new)
    cells = sorted({k[:3] for k in b} | {k[:3] for k in n})
    ok = True
    for cell in cells:
        bk = [k for k in b if k[:3] == cell]
        nk = [k for k in n if k[:3] == cell]
        ba = [run_all_in(b[k]) for k in bk]
        na = [run_all_in(n[k]) for k in nk]
        b_in, n_in = [t for t in ba if t >= 0], [t for t in na if t >= 0]
        checks = [
            ("all-in", med(n_in) <= med(b_in) * 1.2 + 3.0, "%.1f v %.1f" % (med(b_in), med(n_in))),
            ("never-in", sum(1 for t in na if t < 0) <= sum(1 for t in ba if t < 0),
             "%d v %d" % (sum(1 for t in ba if t < 0), sum(1 for t in na if t < 0))),
        ]
        bt = [max((s["twitch_m"] for s in b[k]), default=-1) for k in bk]
        nt = [max((s["twitch_m"] for s in n[k]), default=-1) for k in nk]
        checks.append(("twitch", med(nt) <= med(bt) + 3.0, "%.1f v %.1f" % (med(bt), med(nt))))
        bf = [min((s["end_foreign_m"] for s in b[k] if s["end_foreign_m"] >= 0), default=99) for k in bk]
        nf = [min((s["end_foreign_m"] for s in n[k] if s["end_foreign_m"] >= 0), default=99) for k in nk]
        checks.append(("end foreign", med(nf) >= med(bf) - 3.0, "%.1f v %.1f" % (med(bf), med(nf))))
        bc = sum(1 for k in bk for s in b[k] if s["crossed"])
        nc = sum(1 for k in nk for s in n[k] if s["crossed"])
        checks.append(("crossed", nc <= bc, "%d v %d" % (bc, nc)))
        for name, passed, text in checks:
            ok = ok and passed
            if not passed:
                lines.append("  FAIL guard %-12s %s: %s" % (name, " ".join(map(str, cell)), text))
    lines.append(("PASS" if ok else "FAIL") + " probe guards (%d cells)" % len(cells))
    return ok


def fight_guards(runs_path_or_rows, base, new, lines):
    # Per-fight totals from the squad rows' run fields are not in rows; read ORDERS_PROBE run lines instead.
    runs = runs_path_or_rows
    ok = True
    for key, label in (("green_kills", "his kills"), ("green_lost", "his losses"), ("rust_lost", "CPU losses")):
        b = [float(r[key]) for r in runs if r["arm"] == base]
        n = [float(r[key]) for r in runs if r["arm"] == new]
        if len(b) < 2 or not n:
            lines.append("  MISSING %s" % label)
            ok = False
            continue
        se = st.stdev(b) / math.sqrt(len(b))
        passed = abs(st.mean(n) - st.mean(b)) <= 1.645 * se
        ok = ok and passed
        lines.append("  %s guard %-11s base %.2f arm %.2f a fight (se %.2f, n %d/%d)" % (
            "PASS" if passed else "FAIL", label, st.mean(b), st.mean(n), se, len(b), len(n)))
    lines.append(("PASS" if ok else "FAIL") + " fight guards")
    return ok


def total(rows, arm, field, pred=None):
    return sum(r.get(field, 0) for r in rows if r["arm"] == arm and r.get(field, -1) >= 0 and (pred is None or pred(r)))


def main(argv):
    mode, rows_path, base, new = argv[:4]
    rows = load(rows_path)
    lines = []
    ok = True
    if mode in ("o1", "o1fight"):
        br, nr = total(rows, base, "relays"), total(rows, new, "relays")
        bs, ns = total(rows, base, "shape_flips"), total(rows, new, "shape_flips")
        b_rows = {(r["map"], r["squads"], r["route"], r["seed"], r["squad"]): r for r in rows if r["arm"] == base}
        n_rows = {(r["map"], r["squads"], r["route"], r["seed"], r["squad"]): r for r in rows if r["arm"] == new}
        differ = any(json.dumps({k: v for k, v in b_rows[k].items() if k != "arm"}, sort_keys=True)
                     != json.dumps({k: v for k, v in n_rows[k].items() if k != "arm"}, sort_keys=True)
                     for k in b_rows if k in n_rows)
        counter = br >= 10 and differ
        lines.append("%s counter: base relays %d (>= 10), rows differ %s" % ("PASS" if counter else "FAIL", br, differ))
        dec = nr <= 0.25 * br and (ns <= 1 if mode == "o1" else ns <= 0.25 * bs)
        lines.append("%s deciding: relays %d -> %d (<= %.1f), shape flips %d -> %d" % (
            "PASS" if dec else "FAIL", br, nr, 0.25 * br, bs, ns))
        ok = counter and dec
        if mode == "o1":
            ok = probe_guards(rows, base, new, lines) and ok
            if len(argv) >= 6:
                cb, cn = load(argv[4]), load(argv[5])
                fb = sum(r.get("contacts_friend", 0) for r in cb)
                fn = sum(r.get("contacts_friend", 0) for r in cn)
                sb = sum(r.get("stuck_s", 0.0) for r in cb)
                sn = sum(r.get("stuck_s", 0.0) for r in cn)
                c1 = fn <= fb * 1.1 + 5
                c2 = sn <= sb * 1.2 + 10
                lines.append("%s CPU guard friendly contacts %d -> %d (<= %.1f), fights %d/%d" % (
                    "PASS" if c1 else "FAIL", fb, fn, fb * 1.1 + 5, len(cb), len(cn)))
                lines.append("%s CPU guard stuck s %.1f -> %.1f (<= %.1f)" % ("PASS" if c2 else "FAIL", sb, sn, sb * 1.2 + 10))
                lines.append("  outcomes base %s | arm %s" % (
                    dict(sorted(__import__("collections").Counter(str(r.get("outcome")) for r in cb).items())),
                    dict(sorted(__import__("collections").Counter(str(r.get("outcome")) for r in cn).items()))))
                ok = ok and c1 and c2
    elif mode == "o2":
        # R37.13's final bar: off_idle_s a fight (unpaired: fights diverge), arm <= 50 % of base and the drop > 1.645 se.
        def per_fight(arm):
            f = defaultdict(float)
            for r in rows:
                if r["arm"] == arm:
                    f[(r["map"], r["squads"], r["seed"])] += r.get("off_idle_s", 0.0)
            return list(f.values())
        b, n = per_fight(base), per_fight(new)
        se = math.sqrt(st.variance(b) / len(b) + st.variance(n) / len(n)) if len(b) > 1 and len(n) > 1 else float("inf")
        dec = st.mean(n) <= 0.5 * st.mean(b) and st.mean(b) - st.mean(n) > 1.645 * se
        lines.append("%s deciding: off_idle_s a fight %.1f -> %.1f (<= %.1f), drop %.1f v 1.645 se %.1f; fights %d/%d" % (
            "PASS" if dec else "FAIL", st.mean(b), st.mean(n), 0.5 * st.mean(b), st.mean(b) - st.mean(n), 1.645 * se,
            len(b), len(n)))
        for arm in (base, new):
            split = defaultdict(float)
            for r in rows:
                if r["arm"] == arm:
                    for k, v in r.get("off_split_s", {}).items():
                        split[k] += v
            lines.append("  split %-8s %s" % (arm, {k: round(v, 1) for k, v in sorted(split.items())}))
        brain = lambda arm: sum(v for r in rows if r["arm"] == arm for k, v in r.get("left_by", {}).items()
                                if not k.endswith("+drift") and not k.startswith(("GIVEWAY", "MOVE")))
        retreat = lambda arm: sum(v for r in rows if r["arm"] == arm for k, v in r.get("left_by", {}).items()
                                  if k.startswith("RETREAT"))
        lines.append("  reported: brain-move leaves %d -> %d, RETREAT leaves %d -> %d" % (
            brain(base), brain(new), retreat(base), retreat(new)))
        ok = dec
        if len(argv) >= 5:
            runs = load(argv[4])
            pr = sum(r.get("parked_returns", 0) for r in runs if r["arm"] == new)
            lines.append("%s counter: parked_returns %d" % ("PASS" if pr > 0 else "FAIL", pr))
            ok = ok and pr > 0
            ok = fight_guards(runs, base, new, lines) and ok
    elif mode == "o3":
        bd = sum(1 for r in rows if r["arm"] == base and r.get("redealt", 0) > 0)
        nd = sum(1 for r in rows if r["arm"] == new and r.get("redealt", 0) > 0)
        runs = load(argv[4])
        sw = sum(r.get("swapped_whole", 0) for r in runs if r["arm"] == new)
        lines.append("%s counter: swapped_whole %d" % ("PASS" if sw > 0 else "FAIL", sw))
        dec = nd == 0 and bd >= 10
        lines.append("%s deciding: squads arriving short %d -> %d (base >= 10)" % ("PASS" if dec else "FAIL", bd, nd))
        ok = sw > 0 and dec
        for key in ("friend_contacts", "friend_contacts_foreign"):
            b = sum(r.get(key, 0) for r in runs if r["arm"] == base)
            n = sum(r.get(key, 0) for r in runs if r["arm"] == new)
            passed = n <= b * 1.1 + 5
            ok = ok and passed
            lines.append("%s guard %s %d -> %d (<= %.1f)" % ("PASS" if passed else "FAIL", key, b, n, b * 1.1 + 5))
        lines.append("  whole_still_crossed %d" % sum(r.get("whole_still_crossed", 0) for r in runs if r["arm"] == new))
        ok = probe_guards(rows, base, new, lines) and ok
    # R37.17 (orchestrator): what he sees whatever the totals say: parked crews sent off their seats, each arm (reported).
    lines.append("  reported: parked re-deals (a crew parked >= 2 s sent > 6 m off its seat) %d -> %d" % (
        total(rows, base, "parked_redeals"), total(rows, new, "parked_redeals")))
    print("\n".join(lines))
    print("VERDICT %s: %s" % (mode, "PASS" if ok else "FAIL"))


if __name__ == "__main__":
    main(sys.argv[1:])

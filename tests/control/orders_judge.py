#!/usr/bin/env python3
"""Round 37 (orders): the judged probe read against the bars in the brief's Status (O1, O2, O3).

    python3 tests/control/orders_judge.py o1 rows.jsonl BASE_ARM NEW_ARM [census_base.jsonl census_new.jsonl]
    python3 tests/control/orders_judge.py o1fight rows.jsonl BASE_ARM NEW_ARM [runs.jsonl]
    python3 tests/control/orders_judge.py o1settle rows.jsonl BASE_ARM NEW_ARM   (R37.37: latch's no-fight re-read)
    python3 tests/control/orders_judge.py o2 rows.jsonl BASE_ARM NEW_ARM
    python3 tests/control/orders_judge.py o3 rows.jsonl BASE_ARM NEW_ARM runs.jsonl
    python3 tests/control/orders_judge.py gl rows.jsonl BASE_ARM NEW_ARM runs.jsonl   (R37.29 group-lay=column)
    python3 tests/control/orders_judge.py g1 rows.jsonl BASE_ARM NEW_ARM runs.jsonl [yard_rows.jsonl]   (round 38 G1, O7 v2)
    python3 tests/control/orders_judge.py g3 rows.jsonl BASE_ARM NEW_ARM runs.jsonl   (round 38 G3, place clear)
    python3 tests/control/orders_judge.py o5 BASE_DIR NEW_DIR   (seat-yield-census folders of *.log)

Probe guards (each cell, medians over seeds; R36.6's): all-in (the cell run's last squad arrival) <= base x 1.2 + 3 s and
no more never-in seeds; twitch worst <= base + 3 m (o1settle, R37.37: place + twitch, the crew's whole travel after the
deploy, worst crew a run); end foreign min >= base - 3 m; crossed no higher. Fight guards
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


def probe_guards(rows, base, new, lines, settle=False):
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
        moved = (lambda s: s["place_m"] + s["twitch_m"]) if settle else (lambda s: s["twitch_m"])
        bt = [max((moved(s) for s in b[k]), default=-1) for k in bk]
        nt = [max((moved(s) for s in n[k]), default=-1) for k in nk]
        checks.append(("place+twitch" if settle else "twitch", med(nt) <= med(bt) + 3.0, "%.1f v %.1f" % (med(bt), med(nt))))
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


def census_rows(folder):
    import glob
    import os
    out = []
    for path in sorted(glob.glob(os.path.join(folder, "*.log"))):
        with open(path) as f:
            for line in f:
                if line.startswith("SEAT_YIELD_CENSUS "):
                    out.append(json.loads(line.split(" ", 1)[1]))
    return out


def judge_o5(base_dir, new_dir):
    # The O5 bar (R37.5): counter seats_aside > 0; deciding CPU screen give-ways arm <= 50 % of base; reported seat give-way
    # deaths (arm <= base + 1.645 sqrt(base)); guards deaths a fight per team within base +/- 1.645 se (base sd, n fights).
    b, n = census_rows(base_dir), census_rows(new_dir)
    lines = []
    aside = sum(r.get("seats_aside", 0) for r in n)
    lines.append("%s counter: seats_aside %d" % ("PASS" if aside > 0 else "FAIL", aside))
    scr = lambda rows: sum(int(r["by_verb"].get("cpu:screen", {}).get("episodes", 0)) for r in rows)
    dth = lambda rows: sum(int(v.get("deaths", 0)) for r in rows for v in r["by_verb"].values())
    bs, ns = scr(b), scr(n)
    dec = ns <= 0.5 * bs
    lines.append("%s deciding: CPU screen give-ways %d -> %d (<= %.1f); fights %d/%d" % (
        "PASS" if dec else "FAIL", bs, ns, 0.5 * bs, len(b), len(n)))
    bd, nd = dth(b), dth(n)
    lines.append("  reported: deaths in seat give-ways %d -> %d (noise line <= %.1f: %s)" % (
        bd, nd, bd + 1.645 * math.sqrt(bd), "within" if nd <= bd + 1.645 * math.sqrt(bd) else "ABOVE"))
    ok = aside > 0 and dec
    for team in ("0", "1"):
        bt = [float(r.get("deaths_by_team", {}).get(team, 0)) for r in b]
        nt = [float(r.get("deaths_by_team", {}).get(team, 0)) for r in n]
        se = st.stdev(bt) / math.sqrt(len(bt)) if len(bt) > 1 else float("inf")
        passed = bool(nt) and abs(st.mean(nt) - st.mean(bt)) <= 1.645 * se
        ok = ok and passed
        lines.append("  %s guard team %s deaths a fight base %.2f arm %.2f (se %.2f, n %d/%d)" % (
            "PASS" if passed else "FAIL", team, st.mean(bt), st.mean(nt) if nt else float("nan"), se, len(bt), len(nt)))
    print("\n".join(lines))
    print("VERDICT o5: %s" % ("PASS" if ok else "FAIL"))


def main(argv):
    if argv[0] == "o5":
        judge_o5(argv[1], argv[2])
        return
    mode, rows_path, base, new = argv[:4]
    rows = load(rows_path)
    lines = []
    ok = True
    if mode in ("o1", "o1fight", "o1settle"):
        br, nr = total(rows, base, "relays"), total(rows, new, "relays")
        bs, ns = total(rows, base, "shape_flips"), total(rows, new, "shape_flips")
        b_rows = {(r["map"], r["squads"], r["route"], r["seed"], r["squad"]): r for r in rows if r["arm"] == base}
        n_rows = {(r["map"], r["squads"], r["route"], r["seed"], r["squad"]): r for r in rows if r["arm"] == new}
        differ = any(json.dumps({k: v for k, v in b_rows[k].items() if k != "arm"}, sort_keys=True)
                     != json.dumps({k: v for k, v in n_rows[k].items() if k != "arm"}, sort_keys=True)
                     for k in b_rows if k in n_rows)
        counter = br >= 10 and differ
        lines.append("%s counter: base relays %d (>= 10), rows differ %s" % ("PASS" if counter else "FAIL", br, differ))
        dec = nr <= 0.25 * br and (ns <= 1 if mode != "o1fight" else ns <= 0.25 * bs)
        lines.append("%s deciding: relays %d -> %d (<= %.1f), shape flips %d -> %d" % (
            "PASS" if dec else "FAIL", br, nr, 0.25 * br, bs, ns))
        ok = counter and dec
        if mode == "o1settle":
            ok = probe_guards(rows, base, new, lines, settle=True) and ok
        elif mode == "o1":
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
        elif len(argv) >= 5:  # o1fight: the O1 addendum's per-fight guards
            ok = fight_guards(load(argv[4]), base, new, lines) and ok
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
    elif mode == "gl":
        # R37.29's bar: places outside the click's corridor <= 25 %, metres driven outside it <= 50 %, crews re-dealt 0.
        runs = load(argv[4])
        laid = sum(r.get("columns_laid", 0) for r in runs if r["arm"] == new)
        b_rows = {(r["map"], r["squads"], r["route"], r["seed"], r["squad"]): r for r in rows if r["arm"] == base}
        n_rows = {(r["map"], r["squads"], r["route"], r["seed"], r["squad"]): r for r in rows if r["arm"] == new}
        differ = any(json.dumps({k: v for k, v in b_rows[k].items() if k != "arm"}, sort_keys=True)
                     != json.dumps({k: v for k, v in n_rows[k].items() if k != "arm"}, sort_keys=True)
                     for k in b_rows if k in n_rows)
        lines.append("%s counter: columns_laid %d, rows differ %s" % ("PASS" if laid > 0 and differ else "FAIL", laid, differ))
        bo = sum(1 for r in rows if r["arm"] == base and r.get("anchor_outside"))
        no = sum(1 for r in rows if r["arm"] == new and r.get("anchor_outside"))
        bm, nm = total(rows, base, "route_out_m"), total(rows, new, "route_out_m")
        nr = sum(1 for r in rows if r["arm"] == new and r.get("redealt", 0) > 0)
        d1, d2, d3 = no <= 0.25 * bo, nm <= 0.5 * bm, nr == 0
        lines.append("%s deciding: places outside the corridor %d -> %d (<= %.1f)" % ("PASS" if d1 else "FAIL", bo, no, 0.25 * bo))
        lines.append("%s deciding: metres driven outside the corridor %.0f -> %.0f (<= %.0f)" % ("PASS" if d2 else "FAIL", bm, nm, 0.5 * bm))
        lines.append("%s deciding: squads with crews re-dealt (arm) %d (base %d)" % ("PASS" if d3 else "FAIL", nr,
                     sum(1 for r in rows if r["arm"] == base and r.get("redealt", 0) > 0)))
        ok = laid > 0 and differ and d1 and d2 and d3
        b = sum(r.get("friend_contacts", 0) for r in runs if r["arm"] == base)
        n = sum(r.get("friend_contacts", 0) for r in runs if r["arm"] == new)
        passed = n <= b * 1.1 + 5
        ok = ok and passed
        lines.append("%s guard friend_contacts %d -> %d (<= %.1f)" % ("PASS" if passed else "FAIL", b, n, b * 1.1 + 5))
        ok = probe_guards(rows, base, new, lines) and ok
    elif mode == "g1":
        # Round 38 G1 (O7 v2)'s bar, filed in the brief's Status: places outside the click's corridor <= 25 % of base; metres
        # driven outside it after a crew was once inside (route_left_m) <= 50 % of base; crews re-dealt 0; guards as gl;
        # the open-ground cell (yard_open) rows identical, both arms.
        runs = load(argv[4])
        laid = sum(r.get("columns_laid", 0) for r in runs if r["arm"] == new)
        kept = sum(r.get("bodies_kept", 0) for r in runs if r["arm"] == new)
        lines.append("%s counter: columns_laid %d (bodies kept %d)" % ("PASS" if laid > 0 else "FAIL", laid, kept))
        # Amended before any judged number: places and metres over the click cells (his click included); re-deals over all.
        clicks = [r for r in rows if r["route"] == "click"]
        bo = sum(1 for r in clicks if r["arm"] == base and r.get("anchor_outside"))
        no = sum(1 for r in clicks if r["arm"] == new and r.get("anchor_outside"))
        bm, nm = total(clicks, base, "route_left_m"), total(clicks, new, "route_left_m")
        nr = sum(1 for r in rows if r["arm"] == new and r.get("redealt", 0) > 0)
        d1, d2, d3 = no <= 0.25 * bo, nm <= 0.5 * bm, nr == 0
        lines.append("%s deciding: places outside the corridor (click cells) %d -> %d (<= %.1f)" % ("PASS" if d1 else "FAIL", bo, no, 0.25 * bo))
        lines.append("%s deciding: metres driven outside the corridor after being in it (click cells) %.0f -> %.0f (<= %.0f)" % (
            "PASS" if d2 else "FAIL", bm, nm, 0.5 * bm))
        lines.append("%s deciding: squads with crews re-dealt (arm) %d (base %d)" % ("PASS" if d3 else "FAIL", nr,
                     sum(1 for r in rows if r["arm"] == base and r.get("redealt", 0) > 0)))
        lines.append("  reported: metres outside incl. the drive in (route_out_m) %.0f -> %.0f" % (
            total(rows, base, "route_out_m"), total(rows, new, "route_out_m")))
        ok = laid > 0 and d1 and d2 and d3
        b = sum(r.get("friend_contacts", 0) for r in runs if r["arm"] == base)
        n = sum(r.get("friend_contacts", 0) for r in runs if r["arm"] == new)
        passed = n <= b * 1.1 + 5
        ok = ok and passed
        lines.append("%s guard friend_contacts %d -> %d (<= %.1f)" % ("PASS" if passed else "FAIL", b, n, b * 1.1 + 5))
        ok = probe_guards(rows, base, new, lines) and ok
        if len(argv) > 5:
            yard = load(argv[5])
            yb = {(r["map"], r["squads"], r["route"], r["seed"], r["squad"]): r for r in yard if r["arm"] == base}
            yn = {(r["map"], r["squads"], r["route"], r["seed"], r["squad"]): r for r in yard if r["arm"] == new}
            same = sum(1 for k in yb if k in yn and json.dumps({a: v for a, v in yb[k].items() if a != "arm"}, sort_keys=True)
                       == json.dumps({a: v for a, v in yn[k].items() if a != "arm"}, sort_keys=True))
            passed = same == len(yb) == len(yn) and len(yb) > 0
            ok = ok and passed
            lines.append("%s guard no-change cell yard_open: %d of %d squad rows identical (arm rows %d)" % (
                "PASS" if passed else "FAIL", same, len(yb), len(yn)))
    elif mode == "g3":
        # Round 38 G3's bar (R38.15), filed in the brief's Status: place pairs closer than 12 m <= 25 % of base (amended);
        # never-in squads no more; offset guards (worst place-to-click median per cell
        # <= base + 15 m; squads placed > 40 m further than main <= 5 % of rows; none > 100 m); R36.6 guards; contacts.
        runs = load(argv[4])
        cleared = sum(r.get("places_cleared", 0) for r in runs if r["arm"] == new)
        lines.append("%s counter: places_cleared %d" % ("PASS" if cleared > 0 else "FAIL", cleared))
        # Amended before any judged number (dev read 1: main parks neighbours 4-6 m apart, so end foreign < 8 m is normal
        # parking): the defect itself, two squads' places laid closer than 12 m (half a herringbone's short side), per run.
        def close_pairs(arm):
            count = 0
            for squads in by_run(rows, arm).values():
                at = [s["anchor"] for s in squads if isinstance(s.get("anchor"), list)]
                count += sum(1 for a in range(len(at)) for c in range(a + 1, len(at))
                             if math.hypot(at[a][0] - at[c][0], at[a][1] - at[c][1]) < 12.0)
            return count
        never = lambda arm: sum(1 for r in rows if r["arm"] == arm and r["arrived_s"] < 0)
        bp, np_, bn, nn = close_pairs(base), close_pairs(new), never(base), never(new)
        d1 = np_ <= 0.25 * bp
        d2 = nn <= bn
        lines.append("%s deciding: place pairs closer than 12 m %d -> %d (<= %.1f)" % ("PASS" if d1 else "FAIL", bp, np_, 0.25 * bp))
        lines.append("%s guard never-in squads %d -> %d (no more)" % ("PASS" if d2 else "FAIL", bn, nn))
        ok = cleared > 0 and d1 and d2
        b_rows = {(r["map"], r["squads"], r["route"], r["seed"], r["squad"]): r for r in rows if r["arm"] == base}
        n_rows = {(r["map"], r["squads"], r["route"], r["seed"], r["squad"]): r for r in rows if r["arm"] == new}
        further = [n_rows[k]["anchor_offset_m"] - b_rows[k]["anchor_offset_m"] for k in n_rows
                   if k in b_rows and n_rows[k]["anchor_offset_m"] >= 0 and b_rows[k]["anchor_offset_m"] >= 0]
        far = sum(1 for d in further if d > 40.0)
        g2 = far <= 0.05 * len(n_rows)
        g3 = all(d <= 100.0 for d in further)
        b, n = by_run(rows, base), by_run(rows, new)
        g1 = True
        for cell in sorted({k[:3] for k in b} | {k[:3] for k in n}):
            bw = med([max(s["anchor_offset_m"] for s in b[k]) for k in b if k[:3] == cell])
            nw = med([max(s["anchor_offset_m"] for s in n[k]) for k in n if k[:3] == cell])
            if not nw <= bw + 15.0:
                g1 = False
                lines.append("  FAIL guard worst offset %s: %.1f v %.1f" % (" ".join(map(str, cell)), bw, nw))
        lines.append("%s guard worst place-to-click median per cell <= base + 15 m" % ("PASS" if g1 else "FAIL"))
        lines.append("%s guard squads placed > 40 m further than main %d of %d (<= %.1f)" % (
            "PASS" if g2 else "FAIL", far, len(n_rows), 0.05 * len(n_rows)))
        lines.append("%s guard no place > 100 m further than main (worst %+.1f m)" % (
            "PASS" if g3 else "FAIL", max(further, default=0.0)))
        moved = sorted(d for d in further if abs(d) > 0.5)
        lines.append("  reported: offsets changed on %d rows; quartiles %s" % (
            len(moved), [round(moved[int(q * (len(moved) - 1))], 1) for q in (0, 0.25, 0.5, 0.75, 1)] if moved else []))
        lines.append("  reported: route_left_m %.0f -> %.0f" % (total(rows, base, "route_left_m"), total(rows, new, "route_left_m")))
        ok = ok and g1 and g2 and g3
        cb = sum(r.get("friend_contacts", 0) for r in runs if r["arm"] == base)
        cn = sum(r.get("friend_contacts", 0) for r in runs if r["arm"] == new)
        passed = cn <= cb * 1.1 + 5
        ok = ok and passed
        lines.append("%s guard friend_contacts %d -> %d (<= %.1f)" % ("PASS" if passed else "FAIL", cb, cn, cb * 1.1 + 5))
        ok = probe_guards(rows, base, new, lines) and ok
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

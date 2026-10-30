#!/usr/bin/env python3
"""Round 46 (orders, Bar V2 THE TIGHTER FILE): the verdict from tests/control/orders_v2_bar.sh's parts.

    python3 tests/control/orders_v2_judge.py <out dir>

<out>/geometry/<cell>/, <out>/streets/ and <out>/fight/ hold the arms `base` (the frozen tree's default: the veto ON, today's
file) and `pack` (--group-pack=on). A run is (part, cell, map, squads, route, seed), paired across the arms.
A run's FILE LENGTH: the farthest place from the click among the squads it moves (place > 2 m from where the squad stands).

DECIDING (pack; base beside):
  L1 file length, the geometry part's 4-squad cells pooled: median <= 75 m AND <= 0.7 x base's median.
  L1b his exact Gorge click (3 squads, recorded starts): median file length <= 50 m.
  L2 all-in sooner or identical: over the geometry and streets runs where both arms got every squad in, paired, pack mean
     <= base mean (strictly sooner runs reported).
GUARDS:
  G-contacts friendly contacts a run (geometry + streets pooled): pack mean <= base mean x 1.25 + 5.
  G-never never-in runs (geometry + streets): pack <= base x 1.2 + 1.
  G-wedged wedged crew-seconds a run (rows' wedged_s summed), paired: pack mean <= base mean + 2 se.
  G-streets on every street run, paired: places outside the click's corridor a run, metres driven outside it a run, all-in:
     pack mean <= base mean + 2 se.
  G-fight the fight part (terminus / locks, 5 squads, click), paired: green lost pack mean <= base mean + 2 se; green kills
     pack mean >= base mean - 2 se.
  G-veto V1's deciding lines hold under the pack: geometry places across a gap (veto_across) = 0 and sent back (veto_fail and not
     veto_across) = 0 in the pack arm.
VERDICT Bar V2: PASS iff every line above passes.
"""
import os
import statistics as st
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import orders_v1_judge as v1  # noqa: E402

HIS_CELL = v1.HIS_CELL


def file_len(entry):
    moved = [r for r in entry.get("rows", {}).values() if r.get("anchor") and ((r["anchor"][0] - r["start"][0]) ** 2 + (r["anchor"][1] - r["start"][1]) ** 2) ** 0.5 > 2.0]
    return max((float(r["anchor_offset_m"]) for r in moved), default=None)


def paired_line(name, pairs, fn, more_is_bad=True):
    d = []
    xs = []
    for b, p in pairs:
        xb, xp = fn(b), fn(p)
        if xb is None or xp is None:
            continue
        xs.append((xb, xp))
        d.append(xp - xb)
    if not d:
        return "PASS %s: no runs" % name
    mb = sum(x for x, _ in xs) / len(xs)
    mp = sum(y for _, y in xs) / len(xs)
    se = st.stdev(d) / len(d) ** 0.5 if len(d) >= 2 else 0.0
    ok = mp <= mb + 2.0 * se + 1e-9 if more_is_bad else mp >= mb - 2.0 * se - 1e-9
    return "%s %s over %d paired runs: pack %.2f v base %.2f (2 se %.2f)" % ("PASS" if ok else "FAIL", name, len(d), mp, mb, 2.0 * se)


def main(argv):
    out = argv[1]
    arms = defaultdict(lambda: defaultdict(dict))
    v1.read_part(arms, "geometry", os.path.join(out, "geometry"))
    v1.read_part(arms, "streets", os.path.join(out, "streets"))
    v1.read_part(arms, "fight", os.path.join(out, "fight"))
    base, pack = arms["base"], arms["pack"]
    keys = sorted(set(base) & set(pack))
    lines = ["runs: base %d pack %d paired %d" % (len(base), len(pack), len(keys))]
    # L1
    g4 = [k for k in keys if k[0] == "geometry" and k[1] != HIS_CELL and k[3] == 4]
    lb = [file_len(base[k]) for k in g4 if file_len(base[k]) is not None]
    lp = [file_len(pack[k]) for k in g4 if file_len(pack[k]) is not None]
    mb, mp = v1.med(lb), v1.med(lp)
    ok = bool(lp) and mp <= 75.0 and mp <= 0.7 * mb
    lines.append("%s deciding L1: 4-squad file length median %.1f m v base %.1f m (<= 75 and <= %.1f) over %d / %d runs" % (
        "PASS" if ok else "FAIL", mp, mb, 0.7 * mb, len(lp), len(lb)))
    his = [k for k in keys if k[1] == HIS_CELL]
    hp = [file_len(pack[k]) for k in his if file_len(pack[k]) is not None]
    hb = [file_len(base[k]) for k in his if file_len(base[k]) is not None]
    ok = bool(hp) and v1.med(hp) <= 50.0
    lines.append("%s deciding L1b: his Gorge click file length median %.1f m v base %.1f m (<= 50) over %d runs" % (
        "PASS" if ok else "FAIL", v1.med(hp), v1.med(hb), len(hp)))
    # L2
    gs = [k for k in keys if k[0] in ("geometry", "streets")]
    both = [(base[k]["run"]["all_in_s"], pack[k]["run"]["all_in_s"]) for k in gs
            if base[k].get("run") and pack[k].get("run") and base[k]["run"]["all_in_s"] >= 0 and pack[k]["run"]["all_in_s"] >= 0]
    if both:
        ab = sum(b for b, _ in both) / len(both)
        ap = sum(p for _, p in both) / len(both)
        sooner = sum(1 for b, p in both if p < b)
        same = sum(1 for b, p in both if p == b)
        lines.append("%s deciding L2: all-in sooner or identical: pack mean %.2f s v base %.2f s over %d runs (strictly sooner %d, identical %d)" % (
            "PASS" if ap <= ab + 1e-9 else "FAIL", ap, ab, len(both), sooner, same))
    else:
        lines.append("FAIL deciding L2: no runs")
    # guards
    cb = [base[k]["run"].get("friend_contacts", 0) for k in gs if base[k].get("run")]
    cp = [pack[k]["run"].get("friend_contacts", 0) for k in gs if pack[k].get("run")]
    mcb, mcp = sum(cb) / max(1, len(cb)), sum(cp) / max(1, len(cp))
    lines.append("%s guard G-contacts: friendly contacts a run %.1f v base %.1f (<= %.1f)" % (
        "PASS" if mcp <= mcb * 1.25 + 5.0 else "FAIL", mcp, mcb, mcb * 1.25 + 5.0))
    nb = sum(1 for k in gs if base[k].get("run") and base[k]["run"]["all_in_s"] < 0)
    np_ = sum(1 for k in gs if pack[k].get("run") and pack[k]["run"]["all_in_s"] < 0)
    lines.append("%s guard G-never: never-in runs %d v base %d (<= %.1f)" % ("PASS" if np_ <= nb * 1.2 + 1 else "FAIL", np_, nb, nb * 1.2 + 1))
    pairs = [(base[k], pack[k]) for k in gs]
    lines.append(paired_line("guard G-wedged (crew-seconds wedged a run)", pairs,
                             lambda e: sum(float(r.get("wedged_s", 0.0) or 0.0) for r in e.get("rows", {}).values()) if e.get("rows") else None))
    sp = [(base[k], pack[k]) for k in keys if k[0] == "streets"]
    lines.append(paired_line("guard G-streets outside (places outside the corridor a run)", sp,
                             lambda e: sum(1 for r in e.get("rows", {}).values() if r.get("anchor_outside")) if e.get("rows") else None))
    lines.append(paired_line("guard G-streets metres (driven outside the corridor a run)", sp,
                             lambda e: sum(float(r.get("route_left_m", 0.0) or 0.0) for r in e.get("rows", {}).values()) if e.get("rows") else None))
    lines.append(paired_line("guard G-streets all-in", sp,
                             lambda e: e["run"]["all_in_s"] if e.get("run") and e["run"]["all_in_s"] >= 0 else None))
    fp = [(base[k], pack[k]) for k in keys if k[0] == "fight"]
    lines.append(paired_line("guard G-fight green lost", fp, lambda e: e["run"].get("green_lost") if e.get("run") else None))
    lines.append(paired_line("guard G-fight green kills", fp, lambda e: e["run"].get("green_kills") if e.get("run") else None, more_is_bad=False))
    across = sum(1 for k in keys if k[0] == "geometry" for r in pack[k].get("rows", {}).values() if r.get("veto_across"))
    back = sum(1 for k in keys if k[0] == "geometry" for r in pack[k].get("rows", {}).values() if r.get("veto_fail") and not r.get("veto_across"))
    lines.append("%s guard G-veto: under the pack, places across a gap %d, sent back %d (= 0)" % ("PASS" if across == 0 and back == 0 else "FAIL", across, back))
    for line in lines:
        print(line)
    verdict = all(line.startswith("PASS") for line in lines if line[:4] in ("PASS", "FAIL"))
    print("VERDICT Bar V2: %s" % ("PASS" if verdict else "FAIL"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

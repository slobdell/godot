#!/usr/bin/env python3
"""Round 46 (orders, Bar V1 THE VETO-ONLY GROUP GUARD): the verdict from tests/control/orders_v1_bar.sh's parts.

    python3 tests/control/orders_v1_judge.py <out dir> [--runs]

<out>/geometry/<cell>/ and <out>/streets/ hold the arms `base` (--group-veto=off) and `veto` (the tree's default) run on the
frozen tree; <out>/main-geometry/<cell>/ and <out>/main-streets/ hold the arm `main` run on main's tree (cb1014bed's code).
A run is (part, cell, map, squads, route, seed); a squad's place is its row's `anchor` (0.1 m, the probe's print).

DECIDING (the veto arm; base printed beside):
  D1 places across a gap from the click (geometry `veto_across`) = 0 over every geometry run.
  D2 places sent back (geometry `veto_back`: > 10 m behind the squad's start along the approach while farther from the click
     than the start) = 0 over every geometry run.
  D5b his exact Gorge click (cell recorded-rfixed-gorge--43.2_53.2, his three squads at their recorded starts): every run has
     every place on his side of the drop (z > 50) and no place failing the veto; every seed present.
GUARDS:
  I1 the OFF path is main's: every squad's place in `base` equals `main`'s, every run of both parts, and the two arms hold the
     same runs (G2's merged code, OFF, never leaks into the default path).
  I2 byte-identity: in `veto`, every squad whose `base` place passes the veto (`veto_fail` false on the base row) has exactly
     the base place; every run with no failing base place is identical as a whole. Both parts (the streets by construction).
  G1 on the TOUCHED cells (a geometry cell, or a streets map x squads x route, where some base run has a failing place), per cell:
     all-in median (runs where every squad arrived) <= base x 1.2 + 3 s; never-in runs <= base x 1.2 + 1; friendly contacts a run
     (mean) <= base x 1.2 + 5.
VERDICT Bar V1: PASS iff D1, D2, D5b, I1, I2 and G1 all pass.
"""
import json
import os
import statistics as st
import sys
from collections import defaultdict

HIS_CELL = "recorded-rfixed-gorge--43.2_53.2"
DROP_NEAR_Z = 50.0


def load(path):
    try:
        with open(path) as f:
            rows = [json.loads(line) for line in f if line.strip()]
    except FileNotFoundError:
        return []
    errors = [r for r in rows if isinstance(r, dict) and "error" in r]
    if errors:
        sys.exit("REFUSED %s: %d of %d rows are errors; first: %s" % (path, len(errors), len(rows), str(errors[0].get("error"))[:200]))
    return rows


def run_key(part, cell, r):
    return (part, cell, r["map"], int(r.get("squads", 0)), r.get("route", "click"), int(r["seed"]))


def read_folder(arms, part, cell, folder):
    """arms[arm][run key] = {"rows": {squad: row}, "run": run line, "geo": geometry line}"""
    for r in load(os.path.join(folder, "rows.jsonl")):
        arms[r["arm"]][run_key(part, cell, r)].setdefault("rows", {})[int(r["squad"])] = r
    for r in load(os.path.join(folder, "runs.jsonl")):
        if "seed" in r:
            arms[r["arm"]][run_key(part, cell, r)]["run"] = r
    for g in load(os.path.join(folder, "geometry.jsonl")):
        for key, entry in arms[g["arm"]].items():
            if key[:3] == (part, cell, g["map"]) and key[5] == int(g["seed"]):
                entry["geo"] = g


def read_part(arms, part, root):
    if not os.path.isdir(root):
        return
    if os.path.exists(os.path.join(root, "rows.jsonl")):
        read_folder(arms, part, "-", root)
    for cell in sorted(os.listdir(root)):
        folder = os.path.join(root, cell)
        if os.path.isdir(folder) and os.path.exists(os.path.join(folder, "rows.jsonl")):
            read_folder(arms, part, cell, folder)


def places(entry):
    return {sq: (tuple(r["anchor"]) if r.get("anchor") else None) for sq, r in entry.get("rows", {}).items()}


def failing(entry):
    return {sq for sq, r in entry.get("rows", {}).items() if r.get("veto_fail")}


def med(xs):
    return st.median(xs) if xs else float("nan")


def touched_cell(key):
    return key[:2] if key[0] == "geometry" else key[:5]


def main(argv):
    out = argv[1]
    show = "--runs" in argv
    arms = defaultdict(lambda: defaultdict(dict))
    read_part(arms, "geometry", os.path.join(out, "geometry"))
    read_part(arms, "streets", os.path.join(out, "streets"))
    read_part(arms, "geometry", os.path.join(out, "main-geometry"))
    read_part(arms, "streets", os.path.join(out, "main-streets"))
    base, veto, mainarm = arms["base"], arms["veto"], arms["main"]
    lines = []
    print("runs: base %d veto %d main %d" % (len(base), len(veto), len(mainarm)))
    # D1 / D2 over the geometry part
    d1 = {"base": 0, "veto": 0}
    d2 = {"base": 0, "veto": 0}
    for name, arm in (("base", base), ("veto", veto)):
        for key, e in arm.items():
            g = e.get("geo")
            if key[0] != "geometry" or g is None:
                continue
            d1[name] += sum(1 for x in g.get("veto_across", []) if x)
            d2[name] += sum(1 for x in g.get("veto_back", []) if x)
    geo_runs = sum(1 for k, e in veto.items() if k[0] == "geometry" and e.get("geo"))
    lines.append("%s deciding D1: places across a gap from the click = 0 over %d veto runs (veto %d, base %d)" % (
        "PASS" if d1["veto"] == 0 and geo_runs else "FAIL", geo_runs, d1["veto"], d1["base"]))
    lines.append("%s deciding D2: places sent back > 10 m = 0 over %d veto runs (veto %d, base %d)" % (
        "PASS" if d2["veto"] == 0 and geo_runs else "FAIL", geo_runs, d2["veto"], d2["base"]))
    # D5b
    his_v = {k: e for k, e in veto.items() if k[1] == HIS_CELL}
    his_b = {k: e for k, e in base.items() if k[1] == HIS_CELL}
    good = 0
    for k, e in his_v.items():
        ps = places(e)
        if ps and all(p is not None and p[1] > DROP_NEAR_Z for p in ps.values()) and not failing(e):
            good += 1
    bad_b = sum(1 for e in his_b.values() if failing(e))
    d5b = bool(his_v) and good == len(his_v) and len(his_v) == len(his_b)
    lines.append("%s deciding D5b: his Gorge click, every place on his side and passing the veto in %d of %d runs (base: %d runs with a failing place)" % (
        "PASS" if d5b else "FAIL", good, len(his_v), bad_b))
    # I1
    i1_bad = 0
    for k in set(base) | set(mainarm):
        if k not in base or k not in mainarm or places(base[k]) != places(mainarm[k]):
            i1_bad += 1
            if show or i1_bad <= 5:
                print("I1 DIFF %s base %s main %s" % (k, places(base.get(k, {})), places(mainarm.get(k, {}))))
    lines.append("%s guard I1: the OFF path is main's: %d of %d runs differ (or missing)" % (
        "PASS" if i1_bad == 0 and mainarm else "FAIL", i1_bad, len(set(base) | set(mainarm))))
    # I2
    i2_bad = 0
    whole = 0
    changed_runs = 0
    for k, b in base.items():
        v = veto.get(k)
        if v is None:
            i2_bad += 1
            continue
        fb = failing(b)
        pb, pv = places(b), places(v)
        if not fb:
            whole += 1
        if pb != pv:
            changed_runs += 1
        for sq, p in pb.items():
            if sq not in fb and pv.get(sq) != p:
                i2_bad += 1
                if show or i2_bad <= 5:
                    print("I2 DIFF %s squad %d base %s veto %s (base fails %s)" % (k, sq, p, pv.get(sq), sorted(fb)))
    lines.append("%s guard I2: every passing base place byte-identical under the veto: %d differ; %d runs with no failing place, %d runs changed" % (
        "PASS" if i2_bad == 0 else "FAIL", i2_bad, whole, changed_runs))
    # G1 on touched cells
    cells = defaultdict(lambda: {"base": [], "veto": []})
    touched = {touched_cell(k) for k, e in base.items() if failing(e)}
    for name, arm in (("base", base), ("veto", veto)):
        for k, e in arm.items():
            if touched_cell(k) in touched and e.get("run"):
                cells[touched_cell(k)][name].append(e["run"])
    g1 = True
    for c in sorted(cells):
        b, v = cells[c]["base"], cells[c]["veto"]
        ab = med([r["all_in_s"] for r in b if r["all_in_s"] >= 0])
        av = med([r["all_in_s"] for r in v if r["all_in_s"] >= 0])
        nb = sum(1 for r in b if r["all_in_s"] < 0)
        nv = sum(1 for r in v if r["all_in_s"] < 0)
        cb = sum(r.get("friend_contacts", 0) for r in b) / max(1, len(b))
        cv = sum(r.get("friend_contacts", 0) for r in v) / max(1, len(v))
        ok_a = not (av == av) or not (ab == ab) or av <= ab * 1.2 + 3.0
        ok_n = nv <= nb * 1.2 + 1
        ok_c = cv <= cb * 1.2 + 5.0
        g1 = g1 and ok_a and ok_n and ok_c
        lines.append("  %s touched %s: n %d/%d all-in %.1f v base %.1f%s, never-in %d v %d%s, contacts a run %.1f v %.1f%s" % (
            "ok  " if ok_a and ok_n and ok_c else "FAIL", "/".join(str(x) for x in c), len(v), len(b), av, ab,
            "" if ok_a else " ALL-IN-FAIL", nv, nb, "" if ok_n else " NEVER-FAIL", cv, cb, "" if ok_c else " CONTACTS-FAIL"))
    lines.insert(len(lines) - len(cells), "%s guard G1: all-in / never-in / contacts on the %d touched cells" % ("PASS" if g1 else "FAIL", len(cells)))
    verdict = all(l.startswith("PASS") for l in lines if l[:4] in ("PASS", "FAIL"))
    for l in lines:
        print(l)
    print("VERDICT Bar V1: %s" % ("PASS" if verdict else "FAIL"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

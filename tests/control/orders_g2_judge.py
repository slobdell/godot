#!/usr/bin/env python3
"""Round 45 (orders): Bar G2, THE GROUP GUARD, read to a verdict as filed in streams/orders.md before any number on 11201-11248.

    python3 tests/control/orders_g2_judge.py <out> BASE_ARM NEW_ARM

<out> is tests/control/orders_g2_bar.sh's folder: geometry/<cell>/{rows,geometry,runs}.jsonl (part A: his geometry, the Gorge
cells among them), streets/ + his/ (part B: G1 v9's own street lines, orders_judge g1v8), fight/runs.jsonl (part C).
Part A, per cell (map x starts x reach, a fixed click its own cell) over the ARM's runs; the base is reported beside:
  D1 across_gap: places across water / a pit / through a neck from the click (the probe's `across_gap` flags, as the guard
     reads them) = 0 in EVERY arm run (his Wrenches);
  D2 backward: places more than BACK_M (10 m) behind their own squad's start along the approach = 0 in every arm run;
  D3 reach: every MOVED place within the fitted body's own reach from the click (the arm's `guard.reach_m`, the farthest seat of
     the ranks the guard lays) + REACH_SLACK_M, every arm run (his Hunters, 58 m off the line);
  D4 (R45.5) the fallback `guard.unlaid` (too few seats: today's places stand) = 0 on every GORGE run; reported per cell;
  D5 (R45.9, re-shaped after dev read 3 before any 11201 number) on every Gorge run every HELD squad (its place within HOLD_M =
     2 m of where it stood: the stay rule fired) stands within the body's reach + one rank step (`guard.step_m`) + REACH_SLACK_M
     of the click: a holder is the next rank behind the stack, not a straggler; one held farther away fails; `held` per cell;
  D5b (R45.9) the FIXED cell with his exact Gorge click and his three squads at their recorded starts (starts `recorded`):
     held = 0 every run, plus D1-D4 and D6 there;
  D6 (R45.6) on the Gorge `spawn` cell (his own click): no place behind its own squad's start along the approach by more than
     BEHIND_M = 2 m, every arm run (a squad turning round to drive back a few metres is "sent BACK").
Guards (what the guard could break): per cell all-in median <= base x 1.2 + 3 s and never-in <= base; held median <= base's
unmoved + HELD_SLACK on reach-80 cells only (R45.9 / R44.5's shape; reach-20 and fixed cells report it); friend_contacts pooled
<= base x 1.1 + 5; part B's verdict (places outside the corridor <= base + 2,
sent away <= base + 2, re-dealt 0; yard_open reported); part C's fight guards. Never amended after a number is seen.
"""
import glob
import json
import os
import subprocess
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import orders_geometry_table as geo  # noqa: E402
import orders_judge as oj  # noqa: E402

REACH_SLACK_M = 6.0
HELD_SLACK = 1
BEHIND_M = 2.0
GORGE = "gorge"


def cell_of(g):
    reach = g.get("reach", -1.0)
    if reach is None or reach < 0:
        return (g["map"], g["starts"], "click %.0f/%.0f" % (g["click"][0], g["click"][1]))
    return (g["map"], g["starts"], "r%.0f" % reach)


def part_a(out, base, new, lines):
    reads = defaultdict(lambda: defaultdict(list))  # cell -> arm -> [read]
    runs_by_arm = defaultdict(list)
    for folder in sorted(glob.glob(os.path.join(out, "geometry", "*-r*"))):
        rows, geos, runs = geo.load(folder + "/rows.jsonl"), geo.load(folder + "/geometry.jsonl"), geo.load(folder + "/runs.jsonl")
        by_key = defaultdict(list)
        for r in rows:
            by_key[(r["map"], r["seed"], r["arm"])].append(r)
        for g in geos:
            key = (g["map"], g["seed"], g["arm"])
            if key not in by_key:
                continue
            read = geo.read_run(by_key[key], g)
            if read is None:
                continue
            click = g["click"]
            moved = [r["anchor"] for r in by_key[key] if r.get("anchor") and geo.flat(r["anchor"], r["start"]) > geo.HOLD_M]
            held_rows = [r for r in by_key[key] if r.get("anchor") and geo.flat(r["anchor"], r["start"]) <= geo.HOLD_M]
            read["held_farthest_m"] = max((geo.flat(r["start"], click) for r in held_rows), default=0.0)
            read["across_gap"] = sum(1 for f in g.get("across_gap", []) if f)
            d = g["approach"]
            along = lambda p: (p[0] - click[0]) * d[0] + (p[1] - click[1]) * d[1]
            read["backward_m"] = max((along(r["start"]) - along(r["anchor"]) for r in by_key[key] if r.get("anchor")), default=0.0)
            read["farthest_moved_m"] = max((geo.flat(a, click) for a in moved), default=0.0)
            guard = g.get("guard", {})
            read["guard_reach_m"] = float(guard.get("reach_m", 0.0))
            read["guard_step_m"] = float(guard.get("step_m", 0.0))
            read["unlaid"] = int(guard.get("unlaid", 0))
            read["relaid"] = int(guard.get("relaid", 0))
            read["restored"] = int(guard.get("restored", 0))
            read["fit"] = int(guard.get("fit", 0))
            read["seed"] = g["seed"]
            reads[cell_of(g)][g["arm"]].append(read)
        for r in runs:
            runs_by_arm[r["arm"]].append(r)
    if not reads:
        lines.append("FAIL part A: no geometry cells read")
        return False
    ok = True
    d1 = d2 = d3 = d4 = d5 = d5b = d6 = True
    for cell in sorted(reads):
        b, n = reads[cell][base], reads[cell][new]
        if not b or not n:
            lines.append("  MISSING cell %s: base %d arm %d runs" % (" ".join(map(str, cell)), len(b), len(n)))
            ok = False
            continue
        gorge = cell[0] == GORGE
        c1 = all(r["across_gap"] == 0 for r in n)
        c2 = all(r["backward"] == 0 for r in n)
        c3 = all(r["farthest_moved_m"] <= r["guard_reach_m"] + REACH_SLACK_M for r in n)
        c4 = (not gorge) or all(r["unlaid"] == 0 for r in n)
        c5 = (not gorge) or all(r["held"] == 0 or r["held_farthest_m"] <= r["guard_reach_m"] + r["guard_step_m"] + REACH_SLACK_M for r in n)
        his = gorge and cell[1] in ("spawn", "recorded")
        recorded = gorge and cell[1] == "recorded"
        c5b = (not recorded) or (all(r["held"] == 0 for r in n) and c1 and c2 and c3 and c4)
        c6 = (not his) or all(r["backward_m"] <= BEHIND_M for r in n)
        d1, d2, d3, d4, d5, d5b, d6 = d1 and c1, d2 and c2, d3 and c3, d4 and c4, d5 and c5, d5b and c5b, d6 and c6
        held_b = geo.med([r["squads"] - r["moved"] for r in b])
        held_n = geo.med([r["held"] for r in n])
        far_cell = cell[2] == "r80"
        g_held = (not far_cell) or held_n <= held_b + HELD_SLACK
        b_in = [r["all_in_s"] for r in b if r["all_in_s"] >= 0]
        n_in = [r["all_in_s"] for r in n if r["all_in_s"] >= 0]
        g_all = (not b_in) or geo.med(n_in) <= geo.med(b_in) * 1.2 + 3.0
        g_never = sum(1 for r in n if r["all_in_s"] < 0) <= sum(1 for r in b if r["all_in_s"] < 0)
        ok = ok and g_all and g_never and g_held
        lines.append("  %s %-7s %-14s n %d/%d: across_gap %d (base %d)%s | backward %d (base %d)%s | farthest moved max %.0f v reach %.0f + %.0f%s | unlaid %d laid %d restored %d%s | held med %.1f (base unmoved %.1f)%s%s | fit %s | spread med %.0f (base %.0f) across med %.0f (base %.0f) | all-in %s v %s%s never %d v %d%s" % (
            cell[0], cell[1], cell[2], len(b), len(n), sum(r["across_gap"] for r in n), sum(r["across_gap"] for r in b), "" if c1 else " D1-FAIL",
            sum(r["backward"] for r in n), sum(r["backward"] for r in b), "" if c2 else " D2-FAIL",
            max(r["farthest_moved_m"] for r in n), geo.med([r["guard_reach_m"] for r in n]), REACH_SLACK_M, "" if c3 else " D3-FAIL",
            sum(r["unlaid"] for r in n), sum(r["relaid"] for r in n), sum(r["restored"] for r in n), "" if c4 else " D4-FAIL",
            held_n, held_b, ("" if c5 else " D5-FAIL") + ("" if c5b else " D5b-FAIL") + (" held farthest %.0f" % max(r["held_farthest_m"] for r in n) if gorge else ""), ("" if c6 else " D6-FAIL") + (" | backward max %.1f m (base %.1f)" % (max(r["backward_m"] for r in n), max(r["backward_m"] for r in b)) if his else "") + ("" if g_held else " HELD-GUARD-FAIL"),
            sorted(set(r["fit"] for r in n)), geo.med([r["spread_m"] for r in n]), geo.med([r["spread_m"] for r in b]),
            geo.med([r["across_m"] for r in n]), geo.med([r["across_m"] for r in b]),
            ("%.1f" % geo.med(n_in)) if n_in else "-", ("%.1f" % geo.med(b_in)) if b_in else "-", "" if g_all else " ALL-IN-FAIL",
            sum(1 for r in n if r["all_in_s"] < 0), sum(1 for r in b if r["all_in_s"] < 0), "" if g_never else " NEVER-FAIL"))
    lines.append("%s deciding D1: places across a gap from the click (water / pit / through a neck) = 0, every arm run" % ("PASS" if d1 else "FAIL"))
    lines.append("%s deciding D2: places > %.0f m behind their own start along the approach = 0, every arm run" % ("PASS" if d2 else "FAIL", geo.BACK_M))
    lines.append("%s deciding D3: every moved place within the fitted body's reach + %.0f m of the click, every arm run" % ("PASS" if d3 else "FAIL", REACH_SLACK_M))
    lines.append("%s deciding D4 (R45.5): the fallback (too few seats, today's places) never taken on a Gorge run" % ("PASS" if d4 else "FAIL"))
    lines.append("%s deciding D5 (R45.9): on every Gorge run every held squad stands within the body's reach + one rank step + %.0f m of the click" % ("PASS" if d5 else "FAIL", REACH_SLACK_M))
    lines.append("%s deciding D5b (R45.9): his exact click with his three squads at their recorded starts: held = 0 every run, D1-D4 there" % ("PASS" if d5b else "FAIL"))
    lines.append("%s deciding D6 (R45.6): on his own Gorge click no place more than %.0f m behind its squad's start along the approach" % ("PASS" if d6 else "FAIL", BEHIND_M))
    bc = sum(r.get("friend_contacts", 0) for r in runs_by_arm[base])
    nc = sum(r.get("friend_contacts", 0) for r in runs_by_arm[new])
    g_contacts = nc <= bc * 1.1 + 5
    lines.append("%s guard friend_contacts (part A, pooled) %d -> %d (<= %.1f)" % ("PASS" if g_contacts else "FAIL", bc, nc, bc * 1.1 + 5))
    lines.append("%s guard part A all-in / never-in per cell, held (reach-80 cells)" % ("PASS" if ok else "FAIL"))
    return d1 and d2 and d3 and d4 and d5 and d5b and d6 and ok and g_contacts


def part_b(out, base, new, lines):
    streets, his = os.path.join(out, "streets"), os.path.join(out, "his")
    if not os.path.exists(streets + "/rows.jsonl") or not os.path.exists(his + "/rows.jsonl"):
        lines.append("FAIL part B: streets / his rows missing")
        return False
    rows, runs = geo.load(streets + "/rows.jsonl"), geo.load(streets + "/runs.jsonl")
    his_rows, his_runs = geo.load(his + "/rows.jsonl"), geo.load(his + "/runs.jsonl")
    for r in his_rows + his_runs:
        r["map"] = "terminus_his"
    with open(out + "/judged_rows.jsonl", "w") as f:
        for r in [r for r in rows if r["map"] != "yard_open"] + his_rows:
            f.write(json.dumps(r) + "\n")
    with open(out + "/judged_runs.jsonl", "w") as f:
        for r in [r for r in runs if r.get("map") != "yard_open"] + his_runs:
            f.write(json.dumps(r) + "\n")
    here = os.path.dirname(os.path.abspath(__file__))
    res = subprocess.run([sys.executable, os.path.join(here, "orders_judge.py"), "g1v8", out + "/judged_rows.jsonl", base, new,
                          out + "/judged_runs.jsonl"], capture_output=True, text=True)
    for line in res.stdout.splitlines():
        lines.append("  B " + line)
    ok = any(line.startswith("VERDICT") and "PASS" in line for line in res.stdout.splitlines())
    yard = [r for r in rows if r["map"] == "yard_open"]
    yb, yn = [r for r in yard if r["arm"] == base], [r for r in yard if r["arm"] == new]
    lines.append("  reported: yard_open (the guard changes a three-abreast body on purpose): %d base / %d arm squad rows" % (len(yb), len(yn)))
    lines.append("%s part B: G1 v9's own street lines (orders_judge g1v8, yard_open reported)" % ("PASS" if ok else "FAIL"))
    return ok


def part_c(out, base, new, lines):
    path = os.path.join(out, "fight", "runs.jsonl")
    if not os.path.exists(path):
        lines.append("FAIL part C: fight runs missing")
        return False
    return oj.fight_guards(geo.load(path), base, new, lines)


def main(argv):
    out, base, new = argv[1], argv[2], argv[3]
    lines = []
    a = part_a(out, base, new, lines)
    b = part_b(out, base, new, lines)
    c = part_c(out, base, new, lines)
    print("\n".join(lines))
    print("VERDICT Bar G2: %s (A %s, B %s, C %s)" % ("PASS" if (a and b and c) else "FAIL", a, b, c))
    return 0 if (a and b and c) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))

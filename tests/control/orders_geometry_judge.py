#!/usr/bin/env python3
"""Round 44 (orders): Bar G1 v10 read to a verdict, as filed in streams/orders.md before any number on 10801-10848.

    python3 tests/control/orders_geometry_judge.py <out> BASE_ARM NEW_ARM

<out> is tests/control/orders_g1v10_bar.sh's folder: geometry/<starts>-r<reach>/{rows,geometry,runs}.jsonl (part A, his geometry),
streets/ + his/ (part B, G1 v9's own cells, judged by orders_judge.py g1v8 with yard_open REPORTED, not guarded), fight/runs.jsonl
(part C). Deciding (part A, per cell = map x starts x reach, medians over seeds, and per run):
  1 (R44.9) across_m over moved squads <= the front the clear ground at the click fits, centred with no slide
    ((fit_abreast - 1) x (widest + gap), + SLIDE_M), every arm run
  2 backward: 0 squads in every arm run (a place > COLUMN_AWAY_M behind its start along the approach)
  3 aside_max_m over moved squads: every arm run <= ASIDE_M (the orchestrator's map-edge line) AND <= half the fitted front
    + SLIDE_M (R44.9: no edge or wall slide)
  4 front_ok: >= FRONT_SHARE of runs in every cell
  5 spread_m reported
  6 (the orchestrator's, R44.5 / R44.6: holding a squad cannot buy the pass) (a) in every reach-80 cell `held` = 0 in >=
    HELD_FAR_SHARE of arm runs; (b) in every reach-80 cell the arm's held squads (median a run) <= base's squads that moved less
    than 2 m + HELD_SLACK; (c) in every reach-20 cell, per run, held <= the squads whose start lies within the arm's own laid
    column's length behind the click, no slack
Guards: part A all-in median <= base x 1.2 + 3 s and never-in <= base per cell; friend_contacts pooled <= base x 1.1 + 5;
part B's verdict; part C's fight guards. Never amended after a number is seen.
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

ACROSS_CELL_M = 60.0
ACROSS_RUN_M = 80.0
ASIDE_M = 52.0
SLIDE_M = 2.0
FRONT_SHARE = 0.9
HELD_FAR_SHARE = 0.9
HELD_SLACK = 1


def part_a(out, base, new, lines):
    reads = defaultdict(lambda: defaultdict(list))  # (map, starts, reach) -> arm -> [read]
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
            if read is not None:
                reads[(g["map"], g["starts"], g["reach"])][g["arm"]].append(read)
        for r in runs:
            runs_by_arm[r["arm"]].append(r)
    if not reads:
        lines.append("FAIL part A: no geometry cells read")
        return False
    ok = True
    d1 = d2 = d3 = d4 = d6 = True
    for cell in sorted(reads):
        b, n = reads[cell][base], reads[cell][new]
        if not b or not n:
            lines.append("  MISSING cell %s: base %d arm %d runs" % (" ".join(map(str, cell)), len(b), len(n)))
            ok = False
            continue
        across = geo.med([r["across_m"] for r in n])
        worst_across = max(r["across_m"] for r in n)
        backward = sum(r["backward"] for r in n)
        aside = max(r["aside_max_m"] for r in n)
        front = sum(1 for r in n if r["front_ok"]) / len(n)
        c1 = all(r["across_m"] <= r["fit_across_m"] + SLIDE_M for r in n)
        c3 = aside <= ASIDE_M and all(r["aside_max_m"] <= r["fit_aside_m"] + SLIDE_M for r in n)
        c2, c4 = backward == 0, front >= FRONT_SHARE
        held_n, held_b = geo.med([r["held"] for r in n]), geo.med([r["held"] for r in b])
        far_moving = sum(1 for r in n if r["held"] == 0) / len(n)
        if cell[2] >= 80:
            c6 = held_n <= held_b + HELD_SLACK and far_moving >= HELD_FAR_SHARE
        else:
            c6 = all(r["held"] <= r["within"] for r in n)
        d1, d2, d3, d4, d6 = d1 and c1, d2 and c2, d3 and c3, d4 and c4, d6 and c6
        b_in = [r["all_in_s"] for r in b if r["all_in_s"] >= 0]
        n_in = [r["all_in_s"] for r in n if r["all_in_s"] >= 0]
        g_all = (not b_in) or geo.med(n_in) <= geo.med(b_in) * 1.2 + 3.0
        g_never = sum(1 for r in n if r["all_in_s"] < 0) <= sum(1 for r in b if r["all_in_s"] < 0)
        ok = ok and g_all and g_never
        lines.append("  %s %-9s %-6s r%-3.0f n %d/%d: fit %d abreast (across <= %.0f) | across med %.0f (base %.0f) worst %.0f%s | backward %d (base %d) | aside max %.0f (base %.0f)%s | front %.0f%% (base %.0f%%) | held med %.1f (base %.1f) all-move %.0f%%%s | spread med %.0f (base %.0f) | all-in %.1f v %.1f%s never %d v %d%s" % (
            "PASS" if (c1 and c2 and c3 and c4 and c6 and g_all and g_never) else "FAIL", cell[0], cell[1], cell[2], len(b), len(n),
            geo.med([r["fit_abreast"] for r in n]), geo.med([r["fit_across_m"] for r in n]),
            across, geo.med([r["across_m"] for r in b]), worst_across, "" if c1 else " FIT", backward, sum(r["backward"] for r in b), aside,
            max(r["aside_max_m"] for r in b), "" if c3 else " SLIDE", 100 * front, 100 * sum(1 for r in b if r["front_ok"]) / len(b),
            held_n, held_b, 100 * far_moving, "" if c6 else " HELD",
            geo.med([r["spread_m"] for r in n]), geo.med([r["spread_m"] for r in b]),
            geo.med(b_in) if b_in else -1, geo.med(n_in) if n_in else -1, "" if g_all else " GUARD", sum(1 for r in b if r["all_in_s"] < 0),
            sum(1 for r in n if r["all_in_s"] < 0), "" if g_never else " GUARD"))
        lines.append("      straight-line read (R44.13 b): across med %.0f (base %.0f) worst %.0f | aside max %.0f (base %.0f)" % (
            geo.med([r["across_line_m"] for r in n]), geo.med([r["across_line_m"] for r in b]), max(r["across_line_m"] for r in n),
            max(r["aside_line_max_m"] for r in n), max(r["aside_line_max_m"] for r in b)))
    lines.append("%s deciding 1 (R44.9): every arm run's across-spread (moved squads) <= the front the clear ground fits centred, + %.0f m" % ("PASS" if d1 else "FAIL", SLIDE_M))
    lines.append("%s deciding 2: squads sent back (> %.0f m behind their start along the approach) = 0 every arm run" % ("PASS" if d2 else "FAIL", geo.BACK_M))
    lines.append("%s deciding 3: farthest moved place off the click line <= %.0f m and <= half the fitted front + %.0f m, every arm run" % ("PASS" if d3 else "FAIL", ASIDE_M, SLIDE_M))
    lines.append("%s deciding 4: the nearest squad lands in front in >= %.0f %% of runs every cell" % ("PASS" if d4 else "FAIL", 100 * FRONT_SHARE))
    lines.append("%s deciding 6 (R44.5 / R44.6): reach-80 cells move every squad in >= %.0f %% of runs and hold <= base's unmoved + %d; reach-20 runs hold only squads already within the column's length" % (
        "PASS" if d6 else "FAIL", 100 * HELD_FAR_SHARE, HELD_SLACK))
    bc = sum(r.get("friend_contacts", 0) for r in runs_by_arm[base])
    nc = sum(r.get("friend_contacts", 0) for r in runs_by_arm[new])
    g_contacts = nc <= bc * 1.1 + 5
    lines.append("%s guard friend_contacts (part A, pooled) %d -> %d (<= %.1f)" % ("PASS" if g_contacts else "FAIL", bc, nc, bc * 1.1 + 5))
    lines.append("%s guard part A all-in / never-in per cell" % ("PASS" if ok else "FAIL"))
    return ok and d1 and d2 and d3 and d4 and d6 and g_contacts


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
    moved = 0
    for a in yb:
        for c in yn:
            if (a["seed"], a["squads"], a["route"], a["squad"]) == (c["seed"], c["squads"], c["route"], c["squad"]) \
                    and a.get("anchor") and c.get("anchor") and geo.flat(a["anchor"], c["anchor"]) >= 10.0:
                moved += 1
    lines.append("  reported: yard_open (v10 changes it on purpose): %d base / %d arm squad rows; arm places >= 10 m from base's: %d" % (len(yb), len(yn), moved))
    lines.append("%s part B: G1 v9's own lines (orders_judge g1v8, yard_open reported)" % ("PASS" if ok else "FAIL"))
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
    print("VERDICT Bar G1 v10: %s (A %s, B %s, C %s)" % ("PASS" if (a and b and c) else "FAIL", a, b, c))
    return 0 if (a and b and c) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))

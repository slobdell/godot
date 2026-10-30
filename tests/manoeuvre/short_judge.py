#!/usr/bin/env python3
"""Bar shortfwd (round 46, manoeuvre M5): judge the SHORT_ROW lines of tests/test_manoeuvre_short_move.gd's Gorge corpus.

usage: short_judge.py DECIDING_LOG GUARD_LOG

Each log holds SHORT_ROW {"pose", "seed", "arm": off|on, "row": {...}} lines, both arms per seed (the corpus runs both itself).
Lines as filed in _agents/streams/archive/round46/manoeuvre.md (Bar shortfwd): D1 metres away from his click, paired ARM - BASE <= -2 se AND pooled ARM < BASE
(identical cells count as identical); floor: OFF reverses in >= 4 of 12; G1 arrival sooner or identical in >= 10 of 12, none > 30 ticks
later, never-arrived ARM <= BASE; G2 off-navmesh ARM <= BASE + 0.25 m every cell; G3 (guard block) arrival <= BASE + 30 ticks and away
<= BASE + 0.5 m every cell, G2 there too; native drive in every row.
"""
import json
import math
import sys


def rows(path):
    cells = {}
    for line in open(path, errors="replace"):
        if line.startswith("SHORT_ROW "):
            j = json.loads(line.split(" ", 1)[1])
            cells.setdefault((j["pose"], j["seed"]), {})[j["arm"]] = j["row"]
    return {k: v for k, v in cells.items() if "off" in v and "on" in v}


def arrival(row):
    return math.inf if int(row["arrived"]) < 0 else int(row["arrived"])


def main():
    deciding = rows(sys.argv[1])
    guard = rows(sys.argv[2])
    ok = True
    natives = [r["native_drive"] for cells in (deciding, guard) for v in cells.values() for r in v.values()]
    native_ok = all(natives)
    print(f"native drive in every row: {native_ok} ({sum(natives)} / {len(natives)})")
    ok &= native_ok
    n = len(deciding)
    print(f"deciding block: {n} paired cells; guard block: {len(guard)}")
    diffs = [float(v["on"]["away_max_m"]) - float(v["off"]["away_max_m"]) for v in deciding.values()]
    mean = sum(diffs) / n
    sd = math.sqrt(sum((d - mean) ** 2 for d in diffs) / (n - 1)) if n > 1 else 0.0
    se = sd / math.sqrt(n) if n else 0.0
    pooled_off = sum(float(v["off"]["away_max_m"]) for v in deciding.values())
    pooled_on = sum(float(v["on"]["away_max_m"]) for v in deciding.values())
    exercised = sum(1 for v in deciding.values() if int(v["off"]["reverse_ticks"]) > 0)
    print(f"floor: OFF reverses in {exercised} of {n} (>= 4): {'MET' if exercised >= 4 else 'NOT MET -> INCONCLUSIVE'}")
    d1 = (mean <= -2 * se and se > 0 or mean < 0 and se == 0) and pooled_on < pooled_off
    print(f"D1 metres away from his click: pooled {pooled_off:.1f} -> {pooled_on:.1f}; paired mean {mean:+.2f} se {se:.2f}"
          f" ({mean / se if se else float('nan'):+.1f} se); identical {sum(1 for d in diffs if d == 0)}: {'PASS' if d1 else 'FAIL'}")
    ok &= d1 and exercised >= 4
    sooner = sum(1 for v in deciding.values() if arrival(v["on"]) < arrival(v["off"]))
    same = sum(1 for v in deciding.values() if arrival(v["on"]) == arrival(v["off"]))
    later = max((arrival(v["on"]) - arrival(v["off"]) for v in deciding.values()), default=0)
    never_off = sum(1 for v in deciding.values() if arrival(v["off"]) == math.inf)
    never_on = sum(1 for v in deciding.values() if arrival(v["on"]) == math.inf)
    g1 = sooner + same >= 10 and later <= 30 and never_on <= never_off
    print(f"G1 arrival: sooner or identical {sooner + same} of {n} (strictly sooner {sooner}); worst later {later} ticks;"
          f" never-arrived {never_off} -> {never_on}: {'PASS' if g1 else 'FAIL'}")
    ok &= g1
    for name, cells in (("deciding", deciding), ("guard", guard)):
        worst = max(float(v["on"]["off_mesh_max_m"]) - float(v["off"]["off_mesh_max_m"]) for v in cells.values())
        g2 = worst <= 0.25
        print(f"G2 off the navmesh ({name}): worst ARM - BASE {worst:+.2f} m (<= 0.25): {'PASS' if g2 else 'FAIL'}")
        ok &= g2
    g3_bad = []
    for (pose, seed), v in sorted(guard.items()):
        da = arrival(v["on"]) - arrival(v["off"])
        dw = float(v["on"]["away_max_m"]) - float(v["off"]["away_max_m"])
        if da > 30 or dw > 0.5:
            g3_bad.append(f"pose {pose} seed {seed}: arrival {da:+} ticks, away {dw:+.1f} m")
    print(f"G3 his other clicks: {len(guard) - len(g3_bad)} of {len(guard)} within the lines: {'PASS' if not g3_bad else 'FAIL ' + '; '.join(g3_bad)}")
    ok &= not g3_bad
    print("per cell (pose seed): reverse ticks OFF -> ON | away m | arrival tick | shortfwd ticks ON")
    for (pose, seed), v in sorted(deciding.items()) + sorted(guard.items()):
        print(f"  {pose} {seed}: {v['off']['reverse_ticks']} -> {v['on']['reverse_ticks']} | {v['off']['away_max_m']} -> {v['on']['away_max_m']}"
              f" | {v['off']['arrived']} -> {v['on']['arrived']} | {v['on']['shortfwd_ticks']}")
    print(f"VERDICT (corpus lines; G4-G7 read apart): {'PASS' if ok else 'FAIL'}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Every judged bar line of round 46, as data (round 46 native N4).

The same fields, helpers and noise kinds as `lines_r31_34.py` (read its docstring). Lines are added as each bar's VERDICT lands in
*Rulings (round 46)* in `_agents/workstreams.md`; nothing is re-measured. Round 46's bars by the seed registry (C46.8): orders V1
(11801-11848) and V2 (11849-11896), engage L1 (11901-11948) and E6 (11949-11996), manoeuvre S v6 (12001-12048) and A6 v5
(12049-12096), camera C1 (12201-12248); native none (twins run on the owner's seeds).
"""
from lines_r31_34 import DET, L, gain, se_line, up  # noqa: F401

WS = "_agents/workstreams.md"
src46 = WS + " Round 46"
NONE = {"kind": "none"}
LINES = []

# --------------------------- Bar S v6, his first squad settles where he clicks (manoeuvre; READ R46.15 + R46.17 FINAL: FAILS, OFF) ---
s6 = (src46 + " Rulings R46.17 (FINAL: FAILS on four lines; the ON recommendation withdrawn), R46.15 and "
      "references/round46/manoeuvre/barss6-builder3-4e72c5470/ (stream/manoeuvre 637d500d2)")
S6 = {"round": 46, "stream": "manoeuvre", "item": "S v6 --seat-bound=on --seat-order=on --seat-last=open (seats by the shape's offsets)",
      "commit": "4e72c5470 (frozen)", "machine": "builder3", "n": "12001-12024: 72 paired cells (locks / terminus / crossing); "
      "group 12025-12036; fights 12037-12042", "source": s6}
d1 = 352 - 249
LINES += [
    L(line="D1 crews seated within the bound by 15 s: ARM > BASE by >= 2 se AND pooled", form="mean", rule=">= +2 se",
      base="249", arm="352 (+7.9 se)", verdict="PASS", noise=se_line(d1 / 7.9, 2 * d1 / 7.9, d1 - 2 * d1 / 7.9), **S6),
    L(line="guard Crossing start-zone yield + blocked s: ARM <= BASE + 2 se", form="mean", rule="<= +2 se", base="-",
      arm="+5.95 s a run (+2.1 se)", verdict="FAIL", noise=up(5.95 / 2.1, 5.95, k=2), **S6),
    L(line="guard Crossing k-turn s: ARM <= BASE + 2 se", form="mean", rule="<= +2 se", base="-", arm="+2.6 se", verdict="FAIL",
      noise={"kind": "none", "note": "z only (+2.6 se); the difference not quoted"}, **S6),
    L(line="guard Locks start-zone yield + blocked s: ARM <= BASE + 2 se", form="mean", rule="<= +2 se", base="-",
      arm="+2.84 s a run (+2.2 se)", verdict="FAIL", noise=up(2.84 / 2.2, 2.84, k=2), **S6),
    L(line="guard wedged s, every arena: ARM <= BASE + 2 se", form="mean", rule="<= +2 se", base="-", arm="each within",
      verdict="PASS", noise={"kind": "none", "note": "margins not quoted"}, **S6),
    L(line="guard never-arrived pooled: ARM <= BASE + 2 se", form="mean", rule="<= +2 se", base="194", arm="149", verdict="PASS",
      noise={"kind": "none", "note": "se not quoted; fewer"}, **S6),
    L(line="group G5 / G6 / G7", form="reported", rule="as filed", base="-", arm="identical arms", verdict="PASS", noise=DET, **S6),
    L(line="G1 v9 corridor ORDERS_PROBE_SQUAD rows byte-identical base v s6", form="count-runs", rule="all identical",
      base="180 rows", arm="180/180", verdict="PASS", noise=DET, **S6),
    L(line="fights G1-G3 as Bar S", form="reported", rule="as filed", base="give-way deaths 54, stuck deaths 119",
      arm="45, 125; contacts -3 %", verdict="PASS", noise={"kind": "none", "note": "margins not quoted"}, **S6),
    L(line="fights G4 kill share worst move <= 0.03", form="reported", rule="<= 0.03", base="Green 0.529 (18 fights)",
      arm="0.489: worst move 0.040 (deaths 809 -> 826)", verdict="FAIL",
      noise={"kind": "none", "note": "a worst-move line over 18 fights; S v4 0.049, S v5 0.029"}, **S6),
]

# --------------------------------------- Bar C1, one planner places the camera (camera; READ R46.20: FAILS on G7 only, OFF) ---
c1 = (src46 + " Rulings R46.20 (FAILS as filed on ONE of 38 lines; OFF; C1 v2 on the reserve) and "
      "references/round46/camera/barc1-verdict-builder3-3bf76e839.txt (stream/camera 0f04dba1d)")
C1 = {"round": 46, "stream": "camera", "item": "C1 --camera-planner (one cost over candidate poses)", "commit": "3bf76e839",
      "machine": "builder3 (the per-frame cost on the laptop)", "n": "12201-12248, 0 runs lost", "source": c1}
LINES += [
    L(line="D1 driving with half+ of his shown squad hidden by a building (s)", form="total", rule="fewer", base="1011 s",
      arm="504 s", verdict="PASS", noise={"kind": "none", "note": "se not quoted"}, **C1),
    L(line="D2 none of his selection on screen (s)", form="total", rule="fewer", base="31.6 s", arm="10.9 s", verdict="PASS",
      noise={"kind": "none", "note": "se not quoted"}, **C1),
    L(line="D3 a new selection to on screen (s)", form="mean", rule="sooner", base="0.14 s", arm="0.06 s", verdict="PASS",
      noise={"kind": "none", "note": "se not quoted"}, **C1),
    L(line="D4 hits off screen within +1 point", form="reported", rule="<= base + 1 %", base="1.9 %", arm="2.0 %", verdict="PASS",
      noise={"kind": "none", "note": "share; se not quoted"}, **C1),
    L(line="G3 enemies on screen (the named risk)", form="reported", rule="as filed", base="57.3", arm="51.1", verdict="PASS",
      noise={"kind": "none", "note": "margin not quoted"}, **C1),
    L(line="inside a building (s a run)", form="mean", rule="no worse", base="0.64 s", arm="0.19 s", verdict="PASS",
      noise={"kind": "none", "note": "se not quoted"}, **C1),
    L(line="laptop per-frame cost (C46.7: mean <= 0.5 ms, p99 <= 1.5 ms)", form="reported", rule="<= 0.5 ms mean", base="-",
      arm="0.36 ms/frame", verdict="PASS", noise={"kind": "none", "note": "laptop UHD 620, under the lock"}, **C1),
    L(line="G7 ambush REAR lane: shot to shooter on screen (s; never = 20)", form="mean", rule="no worse", base="4.72 s (4 of 37 never)",
      arm="9.17 s (9 of 28 never); p50 3.5 v 1.8 s", verdict="FAIL",
      noise={"kind": "none", "note": "left / right lanes faster than today (3.0 v 5.4 s, 0.7 v 1.4 s)"}, **C1),
]

# ---------------------------------------------- E6, the stop cap (engage; R46.22: DROPPED under R46.4, no case to fix) ---
e6 = src46 + " Rulings R46.22 (E6 DROPPED: no case to fix; a bar would be vacuous)"
LINES += [
    L(line="E6 staged dev read: farthest roll after his stop, cap OFF v --turn-in-cap=on", form="reported", rule="(no bar filed)",
      base="<= 3.2 m (7 of 9 at 0.0-1.0 m)", arm="identical (the 3.2 m is seed 7011 in both arms)", verdict="REPORTED (dev)",
      noise={"kind": "none", "note": "n 9 standing stages, 7001-7012, builder0 light, efe4d8ba9's code"},
      round=46, stream="engage", item="E6 --turn-in-cap (the stop cap, one-condition fix)", commit="894f561dd (opt-in)",
      machine="builder0 light", n="9 stages", source=e6),
]

# ------------------------------------- Bar V1, the veto-only group guard (orders; READ R46.33: PASSES, SHIPPED ON 12bd0c68f) ---
v1 = (src46 + " Rulings R46.33 (Bar V1 PASSES; SHIPPED ON) and references/round46/orders/bar-v1-builder3-12bd0c68f/")
V1 = {"round": 46, "stream": "orders", "item": "V1 the veto-only group guard (--group-veto)", "commit": "12bd0c68f",
      "machine": "builder3", "n": "11801-11848: 1632 + 48 + 768 runs, main 816 + 24 + 384", "source": v1}
LINES += [
    L(line="D1 places across the corridor", form="count-runs", rule="fewer", base="303", arm="0", verdict="PASS", noise=DET, **V1),
    L(line="D2 squads sent back", form="count-runs", rule="fewer", base="126", arm="0", verdict="PASS", noise=DET, **V1),
    L(line="D5b his exact Gorge click", form="count-runs", rule="all", base="-", arm="24/24", verdict="PASS", noise=DET, **V1),
    L(line="I1 OFF path == main", form="count-runs", rule="all identical", base="1224", arm="1224/1224", verdict="PASS", noise=DET, **V1),
    L(line="I2 untouched clicks identical", form="count-runs", rule="0 differ", base="914 untouched, 310 changed", arm="0 differ",
      verdict="PASS", noise=DET, **V1),
    L(line="G1 on the touched cells", form="reported", rule="as filed", base="-", arm="13 touched cells PASS", verdict="PASS",
      noise={"kind": "none", "note": "margins not quoted"}, **V1),
    L(line="B- no street run failing", form="count-runs", rule="none failing", base="-", arm="none (Terminus never touched)",
      verdict="PASS", noise=DET, **V1),
    L(line="Crossing: the veto re-deals at the route's first waypoint (ruled before the verdict, not a line)", form="reported",
      rule="(reported)", base="outside 1.23, 67.2 m, all-in 17.1 s, contacts 31.9", arm="1.23, 75.8 m, 18.6 s, 32.9 (3-squad 22/24 runs)",
      verdict="REPORTED", noise={"kind": "none", "note": "paired read; se not quoted"}, **V1),
]

# --------------------------------- Bar V2, the tighter file (orders; R46.36: NOT RUN, dev read only, stays OFF; back to him) ---
LINES += [
    L(line="V2 dev read: group all-in s, factor 0.5 (dc452f797) / 0.75 (0edb74316) v the veto ON", form="reported",
      rule="(no series: not run)", base="19.3 s (contacts 41.9 a run)",
      arm="0.5: 20.8 s, 24 of 48 later (contacts 59.6); 0.75: 19.6 s, 19 of 46 later (82.6)", verdict="NOT RUN (dev read)",
      noise={"kind": "none", "note": "n 1 a cell, builder0; Bar V2's L1 an instrument fault (a 3-abreast front's flank)"},
      round=46, stream="orders", item="V2 --group-pack (the tighter file, R46.2)", commit="dc452f797 / 0edb74316 (dev)",
      machine="builder0", n="46-48 cells, n 1 a cell", source=src46 + " Rulings R46.36"),
]

# ---------------------------------- Bars L1 / L1b / L1c, his IFV finds a lane (engage; R46.24 / R46.28 FAIL, R46.31 PASS) ---
l1 = src46 + " Rulings R46.24 (Bar L1 FAILS on G1 only); ~/overnight-engage/r46/barl1/ (laptop)"
L1 = {"round": 46, "stream": "engage", "item": "L1 --lane-clear (CLEAR_LANE, standing-spread spots)", "commit": "fa9c6ff3a (frozen)",
      "machine": "builder0 light", "n": "11901-11948, 48 paired", "source": l1}
LINES += [
    L(line="D1 held for a friend s: ON - OFF < 0 by >= 1.645 se", form="mean", rule="<= -1.645 se", base="20.79 s",
      arm="16.94 s (-3.0 se)", verdict="PASS", noise=gain(3.85 / 3.0, -3.85), **L1),
    L(line="D2 first shot sooner or identical >= 60 %", form="count-runs", rule=">= 60 %", base="-", arm="35/40 (12 strictly)",
      verdict="PASS", noise=NONE, **L1),
    L(line="G1 friendly-fire hits ON <= OFF + max(1, 1.645 sqrt(OFF)); kills ON <= OFF", form="count-runs", rule="<= 2.6",
      base="1 (kills 0)", arm="6 (kills 0)", verdict="FAIL",
      noise={"kind": "none", "note": "a count line; 5 of 6 hits one run (11922: a burst's rounds 2-4 with Guns_2 in the line)"}, **L1),
    L(line="G2 crew deaths", form="count-runs", rule="<= OFF + max(1, 1.645 sqrt(OFF))", base="0", arm="0", verdict="PASS",
      noise=NONE, **L1),
    L(line="G3 enemy hp left <= +1.645 se", form="mean", rule="<= +1.645 se", base="0.79", arm="0.72", verdict="PASS", noise=NONE, **L1),
    L(line="G4 every ON post run <= 5.5 m from his post", form="reported", rule="<= 5.5 m", base="-", arm="max 4.6 m",
      verdict="PASS", noise=DET, **L1),
]
l1b = src46 + " Rulings R46.28 (Bar L1b FAILS as filed on D1); ~/overnight-engage/r46/barl1b/ (laptop)"
L1B = {"round": 46, "stream": "engage", "item": "L1b --lane-clear (moving-spread spots + the burst re-check)",
       "commit": "c0affabe0 (series tree dcabca4dc)", "machine": "builder0 light", "n": "11949-11996, 48 paired (rule's case 38)",
       "source": l1b}
LINES += [
    L(line="D1 held for a friend s: ON - OFF < 0 by >= 1.645 se", form="mean", rule="<= -1.645 se", base="17.54 s",
      arm="18.28 s (+0.74, se 1.02)", verdict="FAIL", noise=gain(1.02, 0.74), **L1B),
    L(line="D2 first shot sooner or identical >= 60 %", form="count-runs", rule=">= 60 %", base="-", arm="31/38 (8 strictly)",
      verdict="PASS", noise=NONE, **L1B),
    L(line="G1 friendly-fire hits; kills ON <= OFF", form="count-runs", rule="<= OFF + max(1, 1.645 sqrt(OFF))", base="4 (kills 0)",
      arm="1 (kills 0)", verdict="PASS", noise=NONE, **L1B),
    L(line="G2 crew deaths", form="count-runs", rule="<= OFF + max(1, 1.645 sqrt(OFF))", base="1", arm="1", verdict="PASS",
      noise=NONE, **L1B),
    L(line="G3 enemy hp left <= +1.645 se", form="mean", rule="<= +1.645 se", base="0.72", arm="0.74", verdict="PASS", noise=NONE, **L1B),
    L(line="G4 every ON post run <= 5.5 m from his post", form="reported", rule="<= 5.5 m", base="-", arm="max 5.3 m",
      verdict="PASS", noise=DET, **L1B),
]
l1c = (src46 + " Rulings R46.31 (Bar L1c PASSES, G4 on an exact tie) and R46.32 (G5 / G6 PASS; SHIPPED ON 1dd227534, main 0471b8e14)")
L1C = {"round": 46, "stream": "engage", "item": "L1c --lane-clear (standing-spread spots + the burst re-check)",
       "commit": "1dd227534 (code 40d0234f5)", "machine": "builder0 light", "n": "12301-12348, 48 paired", "source": l1c}
LINES += [
    L(line="D1 held for a friend s: ON - OFF < 0 by >= 1.645 se", form="mean", rule="<= -1.645 se", base="15.53 s",
      arm="10.65 s (-4.2 se)", verdict="PASS", noise=gain(4.88 / 4.2, -4.88), **L1C),
    L(line="D2 first shot sooner or identical >= 60 %", form="count-runs", rule=">= 60 %", base="-", arm="31/41 (11 strictly)",
      verdict="PASS", noise=NONE, **L1C),
    L(line="G1 friendly-fire hits; kills ON <= OFF", form="count-runs", rule="<= OFF + max(1, 1.645 sqrt(OFF))", base="9 (kills 0)",
      arm="4 (kills 0)", verdict="PASS", noise=NONE, **L1C),
    L(line="G2 crew deaths", form="count-runs", rule="<= OFF + max(1, 1.645 sqrt(OFF))", base="2", arm="1", verdict="PASS",
      noise=NONE, **L1C),
    L(line="G3 enemy hp left <= +1.645 se", form="mean", rule="<= +1.645 se", base="0.62", arm="0.53", verdict="PASS", noise=NONE, **L1C),
    L(line="G4 every ON post run <= 5.5 m from his post", form="reported", rule="<= 5.5 m", base="10.1 m (12328, same run)",
      arm="10.1 m on 12328, byte-identical both arms; every rule-caused move <= 5.4 m", verdict="PASS (tie, R46.31)", noise=DET, **L1C),
    L(line="G4 post held_s ON - OFF <= +1.645 se", form="mean", rule="<= +1.645 se", base="-", arm="-2.52 (se 1.34)", verdict="PASS",
      noise=up(1.34, -2.52), **L1C),
    L(line="G5 E2's authority probe (12301-12324) --lane-clear=off v default", form="count-runs", rule="identical",
      base="-", arm="24/24 identical; pushed rows 0; stop max 5.1 m both", verdict="PASS", noise=DET, **L1C),
    L(line="G6 orders' default probe rows identical ON v OFF", form="count-runs", rule="all identical", base="48 rows",
      arm="48/48", verdict="PASS", noise=DET, **L1C),
    L(line="G7 native test_native_decide equality on the frozen tree", form="count-runs", rule="0 mismatches", base="-",
      arm="7536 decisions, 0 mismatches (builder3 light)", verdict="PASS", noise=DET, **L1C),
]

# ------------------------------- Bar shortfwd, his short click beside his scout (manoeuvre; R46.25: FAILS D1 alone, SHIPPED ON) ---
sf = src46 + " Rulings R46.25 and references/round46/manoeuvre/barssf-builder0-adeb71696/"
SF = {"round": 46, "stream": "manoeuvre", "item": "shortfwd (a short move beside the hull drives forward)",
      "commit": "adeb71696 (frozen)", "machine": "builder0", "n": "12121-12144, 12 cells", "source": sf}
LINES += [
    L(line="D1 metres away from his click: paired ON - OFF < 0 by >= 2 se", form="mean", rule="<= -2 se",
      base="5.7 m pooled", arm="2.4 m pooled; paired -0.27 m (se 0.17) = -1.6 se", verdict="FAIL",
      noise=gain(0.17, -0.27, k=2, note="diluted: 3 cells better, 9 identical, 0 worse"), **SF),
    L(line="guard arrival sooner or identical", form="count-runs", rule="all", base="-", arm="12/12", verdict="PASS", noise=DET, **SF),
    L(line="guard off-navmesh at the drop", form="mean", rule="no worse", base="-", arm="+0.00", verdict="PASS", noise=DET, **SF),
    L(line="guard his other five clicks identical", form="count-runs", rule="all identical", base="-", arm="12/12", verdict="PASS",
      noise=DET, **SF),
    L(line="guard orders probe byte-identical", form="count-runs", rule="all identical", base="96", arm="96/96", verdict="PASS",
      noise=DET, **SF),
    L(line="guard engage's authority probe identical", form="count-runs", rule="row for row", base="-", arm="identical",
      verdict="PASS", noise=DET, **SF),
]

# ------------------------------- Bar A6 v5, the street hold on where the squad is going (manoeuvre; R46.27: FAILS 2b, SHIPPED ON) ---
a6 = src46 + " Rulings R46.27 and references/round46/manoeuvre/barsa6v5-builder0-258ce00f0/ (stream/manoeuvre 95f44597f)"
A6 = {"round": 46, "stream": "manoeuvre", "item": "A6 v5 holdway (the street hold decided on the squad's way)",
      "commit": "258ce00f0", "machine": "builder0 (native ON)", "n": "12049-12096, n 24", "source": a6}
LINES += [
    L(line="deciding side-street jam s", form="total", rule="fewer by >= 2 se", base="397 s", arm="34 s (-30 s a run, z -5.5)",
      verdict="PASS", noise=gain(30 / 5.5, -30, k=2), **A6),
    L(line="off_arrive", form="mean", rule="no worse", base="-", arm="-1.5", verdict="PASS",
      noise={"kind": "none", "note": "se not quoted"}, **A6),
    L(line="head-on verdicts", form="count-runs", rule="equal", base="12", arm="12", verdict="PASS", noise=DET, **A6),
    L(line="mouth contacts", form="total", rule="no worse", base="720", arm="580", verdict="PASS",
      noise={"kind": "none", "note": "se not quoted"}, **A6),
    L(line="far contacts (A6 v4's miss)", form="total", rule="no worse", base="47", arm="10", verdict="PASS",
      noise={"kind": "none", "note": "se not quoted"}, **A6),
    L(line="last crew in", form="mean", rule="no worse", base="-", arm="+0.5 s (noise)", verdict="PASS",
      noise={"kind": "none", "note": "se not quoted"}, **A6),
    L(line="E1 lines identical", form="count-runs", rule="identical", base="-", arm="identical", verdict="PASS", noise=DET, **A6),
    L(line="guard 2b head-on held_on crew-s <= BASE + 2 se", form="total", rule="<= +2 se", base="498", arm="868 (+30.8 a run, z +2.50)",
      verdict="FAIL", noise=up(30.8 / 2.5, 30.8, k=2), **A6),
]

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

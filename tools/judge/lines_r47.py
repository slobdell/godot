#!/usr/bin/env python3
"""Every judged bar line of round 47, as data (round 47 native N5).

The same fields, helpers and noise kinds as `lines_r31_34.py` (read its docstring). Lines are added as each bar's VERDICT lands in
*Rulings (round 47)* in `_agents/workstreams.md`; nothing is re-measured. Round 47's seeds (C47.11): manoeuvre 12401-12496, route
12501-12596, engage 12601-12696, orders 12701-12796, camera 12801-12896, mapkit 12901-12996; native none (twins run on the owner's).
Filed so far (no verdict yet): Bar K (camera, --camera-select-pan, e4a614eab), Bar M (manoeuvre, --traffic-on=buried, 1aa41aeaf).
"""
from lines_r31_34 import DET, L, gain, se_line, up  # noqa: F401

WS = "_agents/workstreams.md"
src47 = WS + " Round 47"
NONE = {"kind": "none"}
LINES = []

# --------------------------------------------- Bar K, a new selection pans at once (camera; R47.29: FAILS G2/G3/G8/G4b, SHIPPED ON his yes) ---
k_src = (src47 + " Rulings R47.29 and references/round47/camera/bark-verdict-builder3-e4a614eab.txt (stream/camera 67d48c984)")
K = {"round": 47, "stream": "camera", "item": "K --camera-select-pan", "commit": "e4a614eab", "machine": "builder3",
     "n": "12801-12848: 72 deciding + 48 guard runs an arm, 0 lost", "source": k_src}
LINES += [
    L(line="D1 % of play his selection > 30 m off", form="share", rule="<= base and <= 10 %", base="11.9 %", arm="6.9 % (ratio 0.58)",
      verdict="PASS", noise={"kind": "none", "note": "se not quoted"}, **K),
    L(line="D2 far selection framed (s)", form="mean", rule="<= 1.0 s, <= base, p90 <= 1.5 s", base="4.92 s", arm="0.73 s (p90 0.95)",
      verdict="PASS", noise={"kind": "none", "note": "se not quoted"}, **K),
    L(line="D3 never framed", form="count", rule="<= base", base="244", arm="21", verdict="PASS", noise=NONE, **K),
    L(line="G2 none of his selection on screen (s)", form="total", rule="<= base", base="61 s", arm="143 s", verdict="FAIL",
      noise={"kind": "none", "note": "all from SPLIT's 140 m flips (the camera leaves the squad he left); ATTACK equal or better"}, **K),
    L(line="G3 hits off screen", form="share", rule="<= base", base="5.3 %", arm="12.6 %", verdict="FAIL",
      noise={"kind": "none", "note": "SPLIT's flips, as G2"}, **K),
    L(line="G8 rear-ambush turn (s)", form="mean", rule="<= base", base="7.08 s", arm="8.56 s", verdict="FAIL",
      noise={"kind": "none", "note": "same latencies, fewer episodes weighting four 20 s nevers"}, **K),
    L(line="G4b one-frame snaps", form="count", rule="0", base="0", arm="7 (the pan's hand-over)", verdict="FAIL", noise=NONE, **K),
    L(line="G10 laptop planner mean / p99 (ms)", form="reported", rule="<= 0.5 mean, <= 1.5 p99", base="-", arm="0.329 / 0.80",
      verdict="PASS", noise=DET, **K),
    L(line="G5a clicks landed", form="share", rule=">= 70 %", base="83.4 %", arm="77.9 % (60 aimed mid-pan, slip p95 464 px)",
      verdict="PASS", noise=NONE, **K),
]

# ----------------------------------------- Bar E7, his attack beats RETREAT (engage; VERDICT: FAILS G1 only, SHIPPED ON, R47.32) ---
e7_src = src47 + " Bar E7 VERDICT (2026-10-30 ~20:05) and R47.32 (shipped ON under C47.2)"
E7 = {"round": 47, "stream": "engage", "item": "E7 --press-on (his side)", "commit": "d4a88c4a5 (runs stamped 04dd39092)",
      "machine": "builder3", "n": "12601-12648: 48 paired, 0 errors", "source": e7_src}
LINES += [
    L(line="D1 metres driven away from his target a run", form="mean", rule="fewer", base="94.2", arm="30.4 (-63.9, z -3.93)",
      verdict="PASS", noise=gain(16.3, -63.9), **E7),
    L(line="D2 first hit sooner or identical", form="count-runs", rule="sooner-or-identical", base="-", arm="41/48 = 85 % (30 strictly)",
      verdict="PASS", noise=NONE, **E7),
    L(line="G1 friendly hits", form="total", rule="<= 2.6", base="1", arm="6 (1-4 hp each, no kill)", verdict="FAIL",
      noise={"kind": "none", "note": "4 of 6 on 12642's five gang IFVs on Locks (circling, assault through)"}, **E7),
    L(line="G2 crew deaths", form="total", rule="no worse", base="102", arm="93", verdict="PASS", noise=NONE, **E7),
    L(line="G3 the target dies (s)", form="mean", rule="no later", base="44.1", arm="37.0 (-7.1, se 2.5)", verdict="PASS",
      noise=gain(2.5, -7.1), **E7),
    L(line="G4 authority probe rows identical", form="count-runs", rule="all identical", base="24", arm="24/24", verdict="PASS",
      noise=DET, **E7),
    L(line="G6 the CPU side identical", form="count-runs", rule="all identical", base="48", arm="48/48", verdict="PASS", noise=DET, **E7),
]

# ---------------------------------------------- Bar M, buried stations follow the squad's track (manoeuvre; R47.33: PASSES, SHIPPED ON) ---
m_src = (src47 + " Rulings R47.33 and streams/references/round47/manoeuvre/barm-builder3-1aa41aeaf/README.md (stream/manoeuvre)")
M = {"round": 47, "stream": "manoeuvre", "item": "M --traffic-on=buried", "commit": "1aa41aeaf", "machine": "builder3",
     "n": "W1 12401-12424 (96 paired cells); W2 12425-12448 (24 paired)", "source": m_src}
LINES += [
    L(line="D1 his staged Locks case (s)", form="reported", rule="<= 1.0 s", base="3.47 s", arm="0.0 s", verdict="PASS", noise=DET, **M),
    L(line="D2 touched cells noprog_s paired mean < 0 and sooner-or-identical >= 50 %", form="mean", rule="< 0 and >= 50 %", base="-",
      arm="-24.9 crew-s a cell, 54 %", verdict="PASS", noise={"kind": "none", "note": "se not quoted"}, **M),
    L(line="D3 all cells noprog_s", form="mean", rule="<= +1.645 se", base="-", arm="z -0.87", verdict="PASS", noise=NONE, **M),
    L(line="G1 all_in (s)", form="mean", rule="<= +1.645 se", base="-", arm="-0.7 s", verdict="PASS", noise=NONE, **M),
    L(line="G2 never_in", form="total", rule="<= base", base="25", arm="23", verdict="PASS", noise=NONE, **M),
    L(line="G3 contact (s)", form="total", rule="<= +1.645 se", base="6589 s", arm="6249 s (z -0.77)", verdict="PASS", noise=NONE, **M),
    L(line="G4 blocked / yielding", form="mean", rule="<= +1.645 se each", base="-", arm="z -0.77 / -0.43", verdict="PASS", noise=NONE, **M),
    L(line="G5 untouched cells identical", form="count-runs", rule="identical", base="-", arm="vacuous (the rule touched all 96)",
      verdict="PASS", noise=DET, **M),
    L(line="G7 W2 CPU v CPU both teams' noprog_s", form="count-runs", rule="no worse", base="24", arm="identical (0 swaps)",
      verdict="PASS", noise=DET, **M),
]

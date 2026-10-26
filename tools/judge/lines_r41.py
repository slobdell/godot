#!/usr/bin/env python3
"""Every judged bar line of round 41, as data (round 41 native N3).

The same fields, helpers and noise kinds as `lines_r31_34.py` (read its docstring). Lines are added as each bar's VERDICT lands
in *Bars (round 41)* / *Rulings (round 41)* in `_agents/workstreams.md` (or the stream's own final report); nothing is re-measured.
Round 41's bars by the seed registry: manoeuvre Q2 (9001-9024) and Q3 (9025-9048), orders O2 (9101-9124), balance B5
(9201-9240 + 9301-9340), Bar B2s v2 (8801-8840 + 8901-8940, filed round 40), camera K (9501-9512, if seeded).
"""
from lines_r31_34 import DET, L, gain, se_line, up  # noqa: F401

WS = "_agents/workstreams.md"
src41 = WS + " Round 41"
NONE = {"kind": "none"}
LINES = []

# ---------------------------------------------------------------- Bar K3 v1, a smooth camera (camera) -----------------
k3 = src41 + " Rulings 'R41.11 ... Bar K3 v1 FAILS line 3'; filed 0871a6789, OFF d08f63317, ON 01adebec9 (+ clip overlay)"
LINES += [
    L(round=41, stream="camera", item="K3 v1 --camera-glide", commit="01adebec9",
      line="(1) attack clicks on the aimed unit ARM >= 70 % AND >= BASE + 15 points",
      form="total", n="Terminus 9501-9512 pooled, 154 / 146 attack clicks", rule=">= 72.1 %", base="57.1 %", arm="77.4 %",
      verdict="PASS", source=k3, noise=NONE),
    L(round=41, stream="camera", item="K3 v1 --camera-glide", commit="01adebec9",
      line="(2) target slip p95 ARM <= 40 px AND <= half BASE",
      form="p95", n="Terminus 9501-9512 pooled", rule="<= 40 px", base="308 px", arm="13.9 px", verdict="PASS", source=k3, noise=NONE),
    L(round=41, stream="camera", item="K3 v1 --camera-glide", commit="01adebec9",
      line="(3) jerks: ARM total <= 3.0/min, no automatic source > 1.5/min, automatic snaps = 0",
      form="total", n="Terminus 9501-9512 pooled", rule="<= 3.0/min; <= 1.5/min; 0 snaps", base="-",
      arm="0.22/min (max source 0.16); auto_frame 12 one-frame snaps (s9509 glide peak 25.6 px/frame, 1,530 px/s)",
      verdict="FAIL (no screen-speed cap; v2 on 9513-9524)", source=k3, noise=NONE),
    L(round=41, stream="camera", item="K3 v1 --camera-glide", commit="01adebec9",
      line="(4) auto_frame px/min ARM >= 25 % of BASE, no trace failure or SCRIPT ERROR",
      form="total", n="Terminus 9501-9512 pooled", rule=">= 25 %", base="100 %", arm="41 %; no trace failure",
      verdict="PASS", source=k3, noise=NONE),
]

# ---------------------------------------------------------------- Bar Q3, the bridge wait (manoeuvre) ------------------
q3 = (src41 + " Rulings 'R41.13 ... Bar Q3 FAILS'; code f6d9d7b1b, bar tree 7f4eabcd1, overrides tree 368aa08dd; judges in "
      "_agents/streams/references/round41/manoeuvre/barq3-builder0-f6d9d7b1b/ (judge-bridge-main / -overrides / -group / -fights.txt)")
LINES += [
    L(round=41, stream="manoeuvre", item="Q3 --traffic-on=wait", commit="f6d9d7b1b",
      line="DECIDING (main) pooled rim ON <= 0.8 x OFF AND paired per-run mean < 0 by >= 2 se",
      form="total", n="72 runs paired, 9025-9036 x ticks {1,8,15} x both sides", rule="<= 26.2 s and -2 se", base="32.7 s",
      arm="25.3 s (-23 %); per-run mean -0.10 s, se 0.09 (-1.2 se; 37 better, 21 worse, 14 same)",
      verdict="FAIL (significance)", source=q3, noise=gain(0.09, -0.10, k=2.0)),
    L(round=41, stream="manoeuvre", item="Q3 --traffic-on=wait", commit="f6d9d7b1b",
      line="DECIDING (overrides tree) pooled rim ON <= 0.8 x OFF AND paired per-run mean < 0 by >= 2 se",
      form="total", n="72 runs paired, 9025-9036 x ticks {1,8,15} x both sides", rule="<= 21.4 s and -2 se", base="26.7 s",
      arm="25.2 s (-6 %); per-run mean -0.02 s, se 0.09 (-0.2 se)", verdict="FAIL", source=q3, noise=gain(0.09, -0.02, k=2.0)),
    L(round=41, stream="manoeuvre", item="Q3 --traffic-on=wait", commit="f6d9d7b1b",
      line="every crew crosses (bridge-pooled's hard line), both trees", form="count-cells", n="72 runs an arm a tree",
      rule="72/72", base="main 72/72; overrides 72/72", arm="main 72/72; overrides 71/72 (locks green 9030 t15 Green_S_3 4.2 s)",
      verdict="FAIL (overrides tree)", source=q3, noise=DET),
    L(round=41, stream="manoeuvre", item="Q3 --traffic-on=wait", commit="f6d9d7b1b",
      line="G5 group order: every-squad-in mean ARM <= BASE + 1.645 se (never-in reads 90 s)",
      form="mean", n="48 paired runs, 4 maps x 9037-9048", rule="<= 82.0 s", base="78.4 s", arm="82.5 s",
      verdict="FAIL", source=q3, noise=up(2.21, 82.5 - 78.4)),
    L(round=41, stream="manoeuvre", item="Q3 --traffic-on=wait", commit="f6d9d7b1b",
      line="G6 group order: never-in squads a run ARM <= BASE + 1.645 se", form="mean", n="48 paired runs",
      rule="<= 1.34", base="1.08 (25 runs never-in)", arm="1.29 (29)", verdict="PASS", source=q3, noise=up(0.157, 1.29 - 1.08)),
    L(round=41, stream="manoeuvre", item="Q3 --traffic-on=wait", commit="f6d9d7b1b",
      line="G7 group order: friendly contact ticks ARM <= 1.05 x BASE", form="total", n="48 paired runs",
      rule="<= 727,423", base="692,784", arm="761,129 (+9.9 %)", verdict="FAIL", source=q3, noise=NONE),
    L(round=41, stream="manoeuvre", item="Q3 --traffic-on=wait", commit="f6d9d7b1b",
      line="fight guards G1-G4 (wedge trace): give-way deaths, stuck deaths, contacts, kill share / deaths",
      form="total", n="18 paired fights, locks / terminus / sumps x 9037-9042", rule="G1 +22.1; G2 +31.4; G3 <= 457,259; G4 0.03 / +-41",
      base="32; 116; 415,690; 0.609; 816", arm="55 (G1 FAIL); 141; 378,664; 0.593 (worst move 0.015); 805",
      verdict="FAIL (G1)", source=q3, noise=NONE),
]

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

# ---------------------------------------------------------------- Bar K3 v2, a smooth camera (camera) -----------------
k3v2 = (src41 + " Bars 'Bar K3 v2' (FILED 355a5b0a7) and Rulings 'R41.17 ... Bar K3 v2 PASSES every line'; both arms 8a2974e85, "
        "builder0 light, headless 1920x1080 @60, Terminus v CPU autoplay")
K3V2_N = "Terminus 9513-9548, 36 seeds an arm (BASE 51.4 min / 899 clicks, ARM 53.1 min / 918)"
LINES += [
    L(round=41, stream="camera", item="K3 v2 --camera-glide", commit="8a2974e85",
      line="(1) attack clicks on the aimed unit ARM >= 70 % AND >= BASE + 15 points", form="total", n=K3V2_N,
      rule=">= 70 % and >= 67.4 %", base="52.4 %", arm="77.5 %", verdict="PASS", source=k3v2, machine="builder0", noise=NONE),
    L(round=41, stream="camera", item="K3 v2 --camera-glide", commit="8a2974e85",
      line="(2) target slip p95 ARM <= 40 px AND <= half BASE", form="p95", n=K3V2_N, rule="<= 40 px", base="294.6 px",
      arm="34.7 px", verdict="PASS", source=k3v2, machine="builder0", noise=NONE),
    L(round=41, stream="camera", item="K3 v2 --camera-glide", commit="8a2974e85",
      line="(3) jerks: ARM total <= 3.0/min, no automatic source > 1.5/min, automatic snaps = 0", form="total", n=K3V2_N,
      rule="<= 3.0/min; <= 1.5/min; 0 snaps", base="18.27/min; 594 snaps", arm="0.19/min (worst automatic: solid 0.17); 0 snaps",
      verdict="PASS", source=k3v2, machine="builder0", noise=NONE),
    L(round=41, stream="camera", item="K3 v2 --camera-glide", commit="8a2974e85",
      line="(4) auto_frame px/min ARM >= 25 % of BASE, no trace failure or SCRIPT ERROR", form="total", n=K3V2_N,
      rule=">= 25 %", base="100 %", arm="61 %; 36/36 runs ok", verdict="PASS", source=k3v2, machine="builder0", noise=NONE),
    L(round=41, stream="camera", item="K3 v2 --camera-glide", commit="8a2974e85",
      line="(5) the camera still finds the action: ARM held time <= 25 % of play AND ARM attack aims/min >= 90 % of BASE",
      form="total", n=K3V2_N, rule="<= 25 %; >= 90 %", base="action share 41.8 %",
      arm="held 15.0 % of play; action share 41.4 %", verdict="PASS", source=k3v2, machine="builder0", noise=NONE),
]

# ---------------------------------------------------------------- Bar G1 v9, the group click lays a column (orders) -----
g1v9 = (src41 + " Bars 'Bar G1 v9' (FILED 383828c39) and Rulings 'R41.15 ... Bar G1 v9 PASSES every line'; builder2, frozen "
        "872dab643, native on, judge g1v8; evidence references/round41/orders/barg1v9-builder2-872dab643/")
G1V9_N = "9101-9112, n 12 a cell"
LINES += [
    L(round=41, stream="orders", item="G1 v9 --group-column-toward=stay", commit="872dab643",
      line="DECIDING: places outside the corridor", form="total", n=G1V9_N, rule="<= 14.2", base="57", arm="8",
      verdict="PASS", source=g1v9, machine="builder2", noise=NONE),
    L(round=41, stream="orders", item="G1 v9 --group-column-toward=stay", commit="872dab643",
      line="metres outside the corridor after arriving", form="total", n=G1V9_N, rule="<= 1140", base="2281", arm="436",
      verdict="PASS", source=g1v9, machine="builder2", noise=NONE),
    L(round=41, stream="orders", item="G1 v9 --group-column-toward=stay", commit="872dab643",
      line="re-dealt places", form="total", n=G1V9_N, rule="<= base", base="48", arm="0", verdict="PASS", source=g1v9,
      machine="builder2", noise=NONE),
    L(round=41, stream="orders", item="G1 v9 --group-column-toward=stay", commit="872dab643",
      line="guard: friend contacts", form="total", n=G1V9_N, rule="<= 14772.5", base="13425", arm="10393", verdict="PASS",
      source=g1v9, machine="builder2", noise=NONE),
    L(round=41, stream="orders", item="G1 v9 --group-column-toward=stay", commit="872dab643",
      line="guard: places sent away > 10 m", form="total", n=G1V9_N, rule="<= 26", base="24", arm="0", verdict="PASS",
      source=g1v9, machine="builder2", noise=NONE),
    L(round=41, stream="orders", item="G1 v9 --group-column-toward=stay", commit="872dab643",
      line="guard: probe guards held in 14 cells; yard_open identical", form="count-cells", n="14 cells; yard_open 192 runs",
      rule="every cell held; 192/192 identical", base="-", arm="14/14 held; 192/192 identical", verdict="PASS", source=g1v9,
      machine="builder2", noise=DET),
    L(round=41, stream="orders", item="G1 v9 --group-column-toward=stay", commit="872dab643",
      line="reported: parked re-deals", form="total", n=G1V9_N, rule="-", base="376", arm="396", verdict="REPORTED",
      source=g1v9, machine="builder2", noise=NONE),
]

# ---------------------------------------------------------------- B5 combined arms (balance): DEV reads, never a bar -----
b5 = src41 + " Rulings 'R41.16' and 'R41.18' (dev reads; balance Status B5 WRITE-UP FOR HIM, streams/archive/round41/balance.md)"
LINES += [
    L(round=41, stream="balance", item="B5 deal arm (dev)", commit="9204009f6",
      line="dev: all-tanks win share v the faction's artillery-heavy archetype, same money, no stat change", form="mean",
      n="9401-9410, 400 mono fights", rule="his target (all-tanks no longer the easy win)",
      base="Condemned 77 %; Gangs 78 %; Law 93 %; Syndicate 99 % (v their normal deal)",
      arm="Condemned 47 % (-30, se 10); Gangs 52 % (-26, se 6); Law +1; Syndicate +7; pooled -12 (se 3)",
      verdict="REPORTED (dev)", source=b5, machine="builder2", noise=se_line(3, 1.645 * 3, 12 - 1.645 * 3, "pooled")),
    L(round=41, stream="balance", item="B5 pen7 (dev)", commit="8f2643375",
      line="dev: all-tanks win share with autocannon 5 -> 7, pulse 7, twin MG 4", form="mean", n="400 mono fights",
      rule="-", base="85 %", arm="85 % (+0, se 1)", verdict="REPORTED (dev)", source=b5, machine="builder2", noise=NONE),
    L(round=41, stream="balance", item="B5 barrage arm (dev)", commit="3ef8d5771",
      line="dev: all-tanks win share v law_barrage / syndicate_barrage (measure_only)", form="mean", n="200 fights",
      rule="-", base="Law 92 %; Syndicate 92 %", arm="Law 96 % (+4, se 3); Syndicate 87 % (-5, se 5)",
      verdict="REPORTED (dev)", source=b5, machine="builder2", noise=NONE),
]

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

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

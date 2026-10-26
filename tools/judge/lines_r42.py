#!/usr/bin/env python3
"""Every judged bar line of round 42, as data (round 42 native N3).

The same fields, helpers and noise kinds as `lines_r31_34.py` (read its docstring). Lines are added as each bar's VERDICT lands
in *Bars (round 42)* / *Rulings (round 42)* in `_agents/workstreams.md` (or the stream's own final report); nothing is re-measured.
Round 42's bars by the seed registry: engage E1 (9601-9624 deciding, 9625-9648 fight guards), camera K4 (9701-9736 an arm),
manoeuvre Q5 (9801-9824) and Q6 (9825-9848), balance B7 (9901-9940) and B8 (10001-10040 + 10101-10140; 10201-10240 dev, never a
bar); carried: Bar B2s v2 (8801-8840 + 8901-8940), Bar B5 t50 (9201-9240 + 9301-9340, only on his yes).
"""
from lines_r31_34 import DET, L, gain, se_line, up  # noqa: F401

WS = "_agents/workstreams.md"
src42 = WS + " Round 42"
NONE = {"kind": "none"}
LINES = []

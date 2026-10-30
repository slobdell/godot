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

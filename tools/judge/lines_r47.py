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

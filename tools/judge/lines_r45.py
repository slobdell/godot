#!/usr/bin/env python3
"""Every judged bar line of round 45, as data (round 45 native N4).

The same fields, helpers and noise kinds as `lines_r31_34.py` (read its docstring). Lines are added as each bar's VERDICT lands in
*Rulings (round 45)* in `_agents/workstreams.md`; nothing is re-measured. Round 45's bars by the seed registry: orders G2
(11201-11248), engage E1 (11301-11348), manoeuvre B2 (11149-11196) and S v4 (11401-11448), A6 v4 (11449-11496); native none.
Read so far: B2 (R45.11, R45.12, R45.14: FAILS, backout stays OFF). G2, E1, S v4: lines land with their verdicts.
"""
from lines_r31_34 import DET, L, gain, up  # noqa: F401

WS = "_agents/workstreams.md"
src45 = WS + " Round 45"
NONE = {"kind": "none"}
POSES = {"kind": "none", "note": "per-pose verdicts on a deterministic staged corpus: a share of poses, not a sample mean"}
LINES = []

# --------------------------------- Bar B2, his War Rig backs out of the box first (manoeuvre; READ R45.11 / R45.12 / R45.14: FAILS) ---
b = src45 + " Rulings R45.11 (partial read), R45.12 (further legs, two misses), R45.14 (backout stays OFF this round)"
B = {"round": 45, "stream": "manoeuvre", "item": "B2 --traffic-on=backout (re-staged corpus, hull boxes, the stalled leg)",
     "commit": "0493977ed (frozen; native's twin 04ce3abe9 in both arms)", "machine": "builder2 (heavy and light legs)",
     "n": "11149-11196: his start 1 run; corpus 48 jittered poses; workload 72 paired cells 11149-11172", "source": b}
LINES += [
    L(line="D1 his start (Locks 56416, Green_Guns_2): reverses before tick 15 and past the box before tick 110; base must not do both",
      form="reported", rule="< 15 and < 110", base="reverse t44, past t140", arm="reverse t4, past t97", verdict="PASS",
      noise=DET, **B),
    L(line="D2 corpus, base-stuck poses (floor 8): ON clears sooner in >= 80 % and median <= -1.0 s", form="share",
      rule=">= 80 %, median <= -1.0 s", base="11 base-stuck poses", arm="11 of 11 = 100 %, median -3.03 s", verdict="PASS",
      noise=POSES, **B),
    L(line="D2 corpus, cost ceiling on the other poses: worst <= +3.0 s every pose, median <= +1.0 s", form="reported",
      rule="<= +3.0 / <= +1.0 s", base="37 poses", arm="worst +6.3 s (seed 11187, pose 10, crossing crawl: base t166, ON t355; "
      "2 looks, 2 k-turns, 0 stalls), median -0.13 s", verdict="FAIL", noise=POSES, **B),
    L(line="twin: C++ v GDScript drive, same machine (builder2 heavy): corpus rows identical", form="count-runs",
      rule="all identical", base="96 rows", arm="96 / 96 (11187 ON t355 both; the laptop's t273 was the machine)", verdict="PASS",
      noise=DET, **B),
    L(line="G engage's line: his Gorge 107 s, base v bo", form="reported", rule="identical", base="-", arm="IDENTICAL",
      verdict="PASS", noise=DET, **B),
    L(line="G workload yield+blocked s per arena: ARM - BASE <= +2 se", form="mean", rule="<= +2 se", base="72 paired cells",
      arm="PASS on every arena", verdict="PASS", noise=NONE, **B),
    L(line="G workload k-turn s per arena: ARM - BASE <= +2 se", form="mean", rule="<= +2 se", base="72 paired cells",
      arm="crossing -0.5 se, locks +1.8 se, terminus +2.6 se (+1.79 s a run)", verdict="FAIL", noise=NONE, **B),
    L(line="G wedged, never-arrived, seated, unneeded back-up (b1_judge)", form="reported", rule="no worse by 2 se", base="-",
      arm="each PASS", verdict="PASS", noise=NONE, **B),
    L(line="read (not a guard): nose-on crews' time to clear 8 m", form="reported", rule="-", base="248 ticks", arm="264 ticks",
      verdict="NOT JUDGED", noise=NONE, **B),
    L(line="R45.14 cause read (dev, Terminus 7001-7012, 12 paired cells, GDScript drive): k-turn s a run with and without the 11187 "
      "fallback", form="reported", rule="-", base="384.6", arm="bo 438.0 (+4.45, +4.1 se); bo + fallback 438.0, identical: not the "
      "11187 shape (War Rig back-ups are k-turns; the Resupply Tanker behind turns to make way). ON also: yield+blocked -4.9 s a run "
      "(-1.9 se), never-arrived -0.75 a run", verdict="NOT JUDGED", noise=NONE,
      **{**B, "commit": "27a84420b (= 0a80c3685 code), dev", "n": "Terminus 7001-7012, 12 paired cells (dev seeds)"}),
]

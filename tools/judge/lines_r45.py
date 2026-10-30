#!/usr/bin/env python3
"""Every judged bar line of round 45, as data (round 45 native N4).

The same fields, helpers and noise kinds as `lines_r31_34.py` (read its docstring). Lines are added as each bar's VERDICT lands in
*Rulings (round 45)* in `_agents/workstreams.md`; nothing is re-measured. Round 45's bars by the seed registry: orders G2
(11201-11248), engage E1 (11301-11348), manoeuvre B2 (11149-11196) and S v4 (11401-11448), A6 v4 (11449-11496); native none.
Read: B2 (R45.15 final: FAILS on three lines, backout OFF), S v4 (R45.17: FAILS the wedged guard on Locks, seat bound OFF), E1
(R45.19: FAILS as filed, ships ON under C45.2), A6 v4 (R45.20: FAILS guard 4, OFF), B3 (R45.26: FAILS D2's share on exact ties
only, every other line PASSES, backout SHIPS ON per R45.23), S v5 (R45.28: FAILS three guards, OFF), E2b (R45.29: FAILS G5, the
stop cap OFF). G2: its lines land with its verdict (~01:15). An se is derived only where the ruling printed both the paired
difference and its z (se = d / z); a line given as z alone, or as counts, carries `none` with a note, or `fisher` for a share.
"""
from lines_r31_34 import DET, L, gain, se_line, up  # noqa: F401

WS = "_agents/workstreams.md"
src45 = WS + " Round 45"
NONE = {"kind": "none"}
POSES = {"kind": "none", "note": "per-pose verdicts on a deterministic staged corpus: a share of poses, not a sample mean"}
LINES = []

# --------------------------------- Bar B2, his War Rig backs out of the box first (manoeuvre; READ R45.11 / R45.12 / R45.14: FAILS) ---
b = (src45 + " Rulings R45.15 (FINAL: FAILS on three lines; backout OFF), R45.11 / R45.12 / R45.14 and "
     "references/round45/manoeuvre/barsb2-builder0+builder2-0493977ed/ (stream/manoeuvre d91d4b96c)")
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
    L(line="D3 guard poses (R45.4): no guard pose worse (time to clear, wall-contact ticks)", form="count-runs",
      rule="none worse", base="24 jittered poses (11149-11172)", arm="4 of 24 worse: 11155 wall ticks 14 -> 102 (though 1.7 s sooner), "
      "11163 +0.3 s / +19 wall ticks, 11168 +3.5 s, 11171 +32 wall ticks", verdict="FAIL", noise=POSES, **B),
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

# ------------------------------------ Bar S v4, his first squad settles where he clicks (manoeuvre; READ R45.17: FAILS the wedged guard) ---
sv = src45 + " Rulings R45.17 (FAILS as filed; the seat bound stays OFF)"
SV = {"round": 45, "stream": "manoeuvre", "item": "S v4 (the seat bound alone; R45.7's removal)", "commit": "0493977ed (frozen)",
      "machine": "builder2 light", "n": "11401-11424: 72 paired cells (Locks, Crossing, Terminus), C++ drive", "source": sv}
LINES += [
    L(line="D1 seated within the bound by 15 s: ARM > BASE by >= 2 se", form="mean", rule=">= +2 se", base="219 pooled",
      arm="362 pooled (+1.99 a run, +8.6 se)", verdict="PASS", noise=NONE, **SV),
    L(line="D2 start-zone yield + blocked s: ARM < BASE by >= 2 se", form="mean", rule="<= -2 se", base="-",
      arm="-2.3 s a run", verdict="PASS", noise=NONE, **SV),
    L(line="G k-turn and yield s per arena: <= +2 se", form="mean", rule="<= +2 se", base="-", arm="PASS on every arena",
      verdict="PASS", noise=NONE, **SV),
    L(line="G never-arrived (pooled)", form="total", rule="no more", base="243", arm="198 (Locks alone +0.9 a run)",
      verdict="PASS", noise=NONE, **SV),
    L(line="G wedged s per arena: <= +2 se", form="mean", rule="<= +2 se", base="-", arm="Locks +6.44 s a run (+4.4 se); crossing, "
      "terminus pass. Carried by the squad's LAST two crews (slot 5 +88.5 s, slot 4 +54.2 s over 24 seeds: Battery_4/5, the Resupply "
      "Tanker and Gun Truck) converging on a bound the first three fill", verdict="FAIL", noise=NONE, **SV),
]

# ------------------------------------------- Bar E1, his order to a crew wins (engage; READ R45.19: FAILS as filed, ships ON, C45.2) ---
e1 = src45 + " Rulings R45.19 (FAILS as filed; E2 ships ON under C45.2) and Bars (round 45) 'Bar E1'"
E1 = {"round": 45, "stream": "engage", "item": "E1 --player-authority (his order to a crew wins)", "commit": "60262534f (frozen, green)",
      "machine": "builder0 light", "n": "11301-11348, 48 an arm, native ON (3 seeds lost the crew before his order, both arms)",
      "source": e1}
LINES += [
    L(line="D1 hold / stop: every rested run's farthest from rest <= 3.0 m (ON, his case)", form="reported", rule="<= 3.0 m",
      base="OFF max 42.6 m", arm="max 5.5 m: 11315 3.1 m (OFF 6.3), 11330 4.0 m (OFF 5.4), 11344 5.5 m (OFF identical)",
      verdict="FAIL", noise=DET, **E1),
    L(line="D2 element rows sending his crew elsewhere while his order stands: 0", form="total", rule="0", base="798", arm="0",
      verdict="PASS", noise=DET, **E1),
    L(line="D3 his move: every run not dead / not blocked ends within its arrival radius of his click", form="count-runs",
      rule="all", base="-", arm="one move 11.2 m short (11337; OFF identical: the drive)", verdict="FAIL", noise=DET, **E1),
    L(line="G1 crew deaths ON <= OFF + max(1, 1.645 sqrt(OFF)); enemy hp left within 1.645 se", form="total",
      rule="<= OFF + 4.0", base="6", arm="7; enemy hp within se", verdict="PASS",
      noise={"kind": "none", "note": "the line is the bar's own sqrt(OFF) allowance; hp's se not quoted"}, **E1),
    L(line="G2 held crews in range still shoot", form="mean", rule="not fewer beyond 1.645 se", base="28.1", arm="34.1",
      verdict="PASS", noise={"kind": "none", "note": "se not quoted"}, **E1),
    L(line="G3 take-back: his squad task retaken after the order", form="count-runs", rule="no fewer", base="38/40",
      arm="35/38 (11321 / 11345 fail in both arms; 11326, a lone artillery hold then a squad move, taken OFF not ON)",
      verdict="FAIL", noise={"kind": "fisher", "a": 35, "n1": 38, "c": 38, "n2": 40}, **E1),
    L(line="G4 a squad hold sends nobody at the enemy", form="total", rule="0", base="278", arm="0", verdict="PASS", noise=DET, **E1),
    L(line="G5 native ON v --brains-off=native EQUAL", form="count-runs", rule="all", base="48", arm="48 / 48", verdict="PASS",
      noise=DET, **E1),
    L(line="G7 make check green on the frozen tree", form="reported", rule="green", base="-", arm="3451 / 0, 28 ALL JUDGED",
      verdict="PASS", noise=DET, **E1),
]

# ------------------------------------------- Bar A6 v4, the street hold (manoeuvre holdway; READ R45.20: FAILS guard 4, stays OFF) ---
a6 = (src45 + " Rulings R45.20 (FAILS as filed on guard 4) and references/round45/manoeuvre/barsa6v4-builder0-0493977ed/")
A6 = {"round": 45, "stream": "manoeuvre", "item": "A6 v4 (holdway, one-sided head-on guard)", "commit": "0493977ed (frozen)",
      "machine": "builder0 light", "n": "11449-11496: 24 + 24 seeds", "source": a6}
LINES += [
    L(line="deciding: side stage jam_s ARM < BASE beyond 2 se (pooled)", form="mean", rule="<= -2 se", base="397 pooled",
      arm="48 pooled (-29.1 s a run, z -5.6)", verdict="PASS", noise=gain(29.1 / 5.6, -29.1, k=2.0), **A6),
    L(line="guards 1, 2a, 2b (one-sided), 3, 5, 6 (engage's lines identical), 8", form="reported", rule="each as filed", base="-",
      arm="each PASS", verdict="PASS", noise={"kind": "none", "note": "per-guard margins not quoted"}, **A6),
    L(line="guard 4: contacts_far ARM <= BASE + 2.32 a run (filed)", form="mean", rule="<= +2.32 a run", base="9 pooled",
      arm="70 pooled (+2.54 a run, z 1.81): 11450 0->9, 11458 3->9, 11460 6->15, 11464 0->5, 11466 0->32 (head-on stages)",
      verdict="FAIL", noise=se_line(2.54 / 1.81, 2.32, 2.32 - 2.54, note="the filed line +2.32 a run; se = 2.54 / 1.81"), **A6),
]

# ---------------------------------- Bar B3, his War Rig backs out of the box first, every pose (manoeuvre; READ R45.26: backout SHIPS ON) ---
b3 = (src45 + " Rulings R45.23 / R45.26 (FAILS as filed on D2's share only, exact ties; SHIPS ON per R45.23) and "
      "references/round45/manoeuvre/barsb3-builder0+builder2-26b1425e7/ (stream/manoeuvre 813e9b377)")
B3 = {"round": 45, "stream": "manoeuvre", "item": "B3 --traffic-on=backout (B2 + no-room rule + the 11187 fallback)",
      "commit": "26b1425e7 (frozen; C++ drive both arms, native twin EQUAL, probe 60/60)", "machine": "builder0 light + builder2",
      "n": "11701-11748 corpus (48 poses + named 11187); guard poses 11701-11724", "source": b3}
LINES += [
    L(line="D1 his start (Locks 56416, Green_Guns_2): reverses before tick 15 and past the box before tick 110", form="reported",
      rule="< 15 and < 110", base="reverse t44, past t140", arm="reverse t4, past t97", verdict="PASS", noise=DET, **B3),
    L(line="D2 corpus, base-stuck poses: ON sooner in >= 80 %", form="share", rule=">= 80 %", base="12 base-stuck poses",
      arm="9 of 12 = 75 %; the 3 non-wins are ONE pose (10, the Crossing crawl) and EXACT TIES (t360 = t360 x2, t187 = t187)",
      verdict="FAIL", noise=POSES, **B3),
    L(line="D2 corpus, base-stuck poses: median gain <= -1.0 s", form="median", rule="<= -1.0 s", base="12 poses",
      arm="-2.78 s", verdict="PASS", noise=POSES, **B3),
    L(line="D2 cost ceiling on the other poses: worst <= +3.0 s, median <= +1.0 s", form="reported", rule="<= +3.0 / <= +1.0 s",
      base="-", arm="worst +1.3 s, median -0.52 s", verdict="PASS", noise=POSES, **B3),
    L(line="D2 named pose 11187 (B2's ceiling breaker): ON <= OFF + 3 s", form="reported", rule="<= +3 s", base="-", arm="+0.8 s",
      verdict="PASS", noise=DET, **B3),
    L(line="D3 guard poses (no-room stagings): none worse", form="count-runs", rule="none worse", base="24 poses",
      arm="0 of 24 worse", verdict="PASS", noise=POSES, **B3),
    L(line="workload guards: yield+blocked, wedged, the squad's time to clear its start, never-arrived, seated, other crews' "
      "reversing (ARM <= BASE + 2 se)", form="mean", rule="<= +2 se", base="-", arm="each PASS", verdict="PASS",
      noise={"kind": "none", "note": "per-arena margins not quoted in the ruling"}, **B3),
    L(line="read (named risk, not a line): k-turn s per arena", form="reported", rule="-", base="-", arm="terminus +3.7 se",
      verdict="REPORTED", noise=NONE, **B3),
    L(line="group G5-G7 identical; G1 corridor; Gorge tables", form="count-runs", rule="identical", base="-",
      arm="G5-G7 identical; G1 180 / 180; Gorge identical", verdict="PASS", noise=DET, **B3),
    L(line="fights G1-G4", form="reported", rule="as Bar B2", base="-", arm="each PASS; 0 SCRIPT ERROR", verdict="PASS",
      noise={"kind": "none", "note": "margins not quoted"}, **B3),
]

# ------------------------------------- Bar S v5, his first squad settles, the last crew parks behind it (manoeuvre; READ R45.28: FAILS) ---
s5 = (src45 + " Rulings R45.28 (FAILS as filed on three guards; seat rules OFF) and "
      "references/round45/manoeuvre/barss5-builder0-fc639d7e0/ (stream/manoeuvre ac58f0b6a)")
S5 = {"round": 45, "stream": "manoeuvre", "item": "S v5 (--seat-bound --seat-order --seat-last=open)", "commit": "fc639d7e0 (frozen)",
      "machine": "builder0 light", "n": "11751-11774: 72 paired cells (Locks, Crossing, Terminus); group / fights 11775-11792",
      "source": s5}
ZONLY = {"kind": "none", "note": "filed as z only (se units): no paired difference quoted"}
LINES += [
    L(line="D1 seated within the bound by 15 s: ARM > BASE by >= 2 se AND pooled", form="mean", rule=">= +2 se", base="220 pooled",
      arm="329 pooled (+8.4 se)", verdict="PASS", noise=ZONLY, **S5),
    L(line="guard Crossing yield + blocked s: ARM <= BASE + 2 se", form="mean", rule="<= +2 se", base="-",
      arm="+9.85 s a run (+4.1 se): the Battery squad yields to ITSELF in its start zone", verdict="FAIL",
      noise=up(9.85 / 4.1, 9.85, k=2.0), **S5),
    L(line="guard Crossing k-turn s: ARM <= BASE + 2 se", form="mean", rule="<= +2 se", base="-", arm="+2.1 se", verdict="FAIL",
      noise=ZONLY, **S5),
    L(line="guard Locks wedged s: ARM <= BASE + 2 se (S v4's miss)", form="mean", rule="<= +2 se", base="-",
      arm="+3.37 s a run (+3.2 se; S v4's +6.4 halved)", verdict="FAIL", noise=up(3.37 / 3.2, 3.37, k=2.0), **S5),
    L(line="guard Terminus (yield, k-turn, wedged)", form="mean", rule="<= +2 se", base="-", arm="clean (k-turn -9.2 se)",
      verdict="PASS", noise=ZONLY, **S5),
    L(line="guard never-arrived pooled: ARM <= BASE + 2 se", form="mean", rule="<= +2 se", base="-", arm="-0.33 a run",
      verdict="PASS", noise={"kind": "none", "note": "se not quoted"}, **S5),
]

# ---------------------------------------------- Bar E2b, his stop stops (engage; READ R45.29: FAILS as filed on G5, the cap stays OFF) ---
e2 = src45 + " Rulings R45.29 (FAILS as filed on G5; the stop cap stays opt-in) and Bars (round 45) 'Bar E2b'"
E2 = {"round": 45, "stream": "engage", "item": "E2b --turn-in-cap (his stop stops within 2.5 m)", "commit": "fea4cfbec (frozen, green)",
      "machine": "builder0", "n": "11349-11396, 48 an arm, native ON; base no flag v --turn-in-cap=on", "source": e2}
LINES += [
    L(line="D1 where his stop ends: max over rested runs <= 3.0 m", form="reported", rule="<= 3.0 m", base="1.1 m",
      arm="1.1 m (VACUOUS: base never drifted on these seeds)", verdict="PASS", noise=DET, **E2),
    L(line="D1b no run ends farther than base + 0.5 m", form="count-runs", rule="0", base="-", arm="0 worse", verdict="PASS",
      noise=DET, **E2),
    L(line="G1 (M) Bar E1's lines (pushed rows, hold moved, move ends)", form="reported", rule="as E1 / base +- 0.5 m", base="-",
      arm="identical", verdict="PASS", noise=DET, **E2),
    L(line="G2 deaths new <= base + max(1, 1.645 sqrt(base))", form="total", rule="<= base + 4.9", base="9", arm="9",
      verdict="PASS", noise={"kind": "none", "note": "the line is the bar's own sqrt allowance"}, **E2),
    L(line="G3 a stopped crew still shoots back: shots >= base - 1.645 se", form="mean", rule=">= -1.645 se", base="44.2",
      arm="43.9", verdict="PASS", noise={"kind": "none", "note": "se not quoted"}, **E2),
    L(line="G4 take-back unchanged", form="count-runs", rule="unchanged", base="35 / 35", arm="35 / 35", verdict="PASS", noise=DET,
      **E2),
    L(line="G5 native ON v --brains-off=native EQUAL on (S) new", form="count-runs", rule="48 / 48", base="48",
      arm="46 / 48 (11352, 11362: law_artillery in a squad of three; native runs a stop itself except a fixed gun on wheels)",
      verdict="FAIL", noise=DET, **E2),
]

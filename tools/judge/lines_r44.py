#!/usr/bin/env python3
"""Every judged bar line of round 44, as data (round 44 native N4).

The same fields, helpers and noise kinds as `lines_r31_34.py` (read its docstring). Lines are added as each bar's VERDICT lands
in *Rulings (round 44)* in `_agents/workstreams.md` or the bar's judge output under `_agents/streams/references/round44/`; nothing
is re-measured. Round 44's bars by the seed registry: orders G1 v10c (10801-10848), manoeuvre S v3 (10901-10924 deciding) and A6 v3
(10949-10972 + E1 10973-10996), manoeuvre B1 (11101-11148, backout alone); native none. Read: G1 v10c (R44.23), S v3 (R44.7), A6 v3 (R44.19), B1 (R44.25;
its lines filed in round 45, native N4).
"""
from lines_r31_34 import DET, L, gain, up  # noqa: F401

WS = "_agents/workstreams.md"
src44 = WS + " Round 44"
REF = "_agents/streams/references/round44/"
NONE = {"kind": "none"}
CELLS = {"kind": "none", "note": "per-cell pass counts over 25 cells of 24 seeds each: deterministic per cell, not a sample mean"}
LINES = []

# ------------------------------------------------ Bar G1 v10c, the group column (orders; READ R44.23: FAILS A and B) ---
g = (src44 + " Rulings R44.23 (FAILS as filed; `--group-column=always` stays OFF) and " + REF +
     "orders/bar-g1v10c-builder2-805eae5e1/verdict_ab.txt (judge tests/control/orders_geometry_judge.py)")
G = {"round": 44, "stream": "orders", "item": "G1 v10c --group-column=always", "commit": "805eae5e1 (code e2d1b499f + probe adc0362f7)",
     "machine": "builder2", "n": "10801-10848: part A 25 cells x 24 seeds (5 squads; reach 20 / 80 / his click), part B the street corridor",
     "source": g}
LINES += [
    L(line="A deciding 1 (R44.9): every arm run's across-spread (moved squads) <= the front the clear ground fits, + 2 m",
      form="count-cells", rule="every run", base="-", arm="FIT failed on 8 of 25 cells (locks along-20 / his-r-1 / his-20, crossing "
      "his-80, terminus along-20, yard_open along-20 / his-20 among them)", verdict="FAIL", noise=CELLS, **G),
    L(line="A deciding 2: squads sent back (> 10 m behind their start along the approach) = 0 every arm run", form="count-runs",
      rule="0", base="up to 24 (crossing along-20)", arm="0 on every cell", verdict="PASS", noise=DET, **G),
    L(line="A deciding 3: farthest moved place off the click line <= 52 m and <= half the fitted front + 2 m, every arm run",
      form="count-cells", rule="every run", base="-", arm="SLIDE on 8 cells (crossing his-80 aside 75 m; terminus along-20 43 m)",
      verdict="FAIL", noise=CELLS, **G),
    L(line="A deciding 4: the nearest squad lands in front in >= 90 % of runs every cell", form="share", rule=">= 90 % every cell",
      base="0-100 % (locks his-r-1 0 %)", arm="100 % on all 25 cells", verdict="PASS", noise=DET, **G),
    L(line="A deciding 6 (R44.5 / R44.6): reach-80 cells move every squad in >= 90 %; reach-20 cells hold only squads already in the "
      "column's length", form="count-cells", rule="every cell", base="-", arm="HELD on crossing across-20 (all-move 0 %), crossing "
      "his-80 (25 %), locks along-20 (4 %), locks his-20 (0 %)", verdict="FAIL", noise=CELLS, **G),
    L(line="A guard friend_contacts (pooled) <= 23710", form="total", rule="<= 23710", base="21550", arm="12105", verdict="PASS",
      noise=DET, **G),
    L(line="A guard all-in / never-in per cell", form="count-cells", rule="every cell", base="-", arm="GUARD on 5 cells (crossing "
      "his-20, locks across-20, terminus across-20 / across-80, yard_open across-80)", verdict="FAIL", noise=CELLS, **G),
    L(line="B deciding: places outside the street corridor (click cells) <= 2", form="total", rule="<= 2.0", base="8", arm="26",
      verdict="FAIL", noise=DET, **G),
    L(line="B deciding: metres driven outside the corridor after being in it (click cells) <= 178", form="total", rule="<= 178",
      base="356", arm="3489", verdict="FAIL", noise=DET, **G),
    L(line="C fights", form="reported", rule="-", base="-", arm="NO DATA (runner: fight budget 2500 < army 2970; not re-run, A and "
      "B decide)", verdict="NOT JUDGED", noise=NONE, **G),
]

# --------------------------------------------- Bar S v3, his first squad's seats (manoeuvre; READ R44.7: FAILS as filed) ---
s = (src44 + " Rulings R44.7 (FAILS as filed on the per-arena wedged guard) and " + REF +
     "manoeuvre/barsv3-builder2-9215b8ab9/judge-deciding-v3.txt")
S = {"round": 44, "stream": "manoeuvre", "item": "S v3 (the scoped round-43 four + backout + parkedpass)", "commit": "9215b8ab9",
     "machine": "builder2", "n": "10901-10924, 72 paired cells (Locks, Crossing, Terminus)", "source": s}
LINES += [
    L(line="D1 seated within the bound by 15 s: ARM > BASE by >= 2 se", form="mean", rule=">= +2 se", base="191",
      arm="383 (paired +2.667 a run, se 0.182, +14.6 se)", verdict="PASS", noise=gain(0.182, -2.667, k=2.0), **S),
    L(line="D2 start-zone yield + blocked s: ARM < BASE by >= 2 se", form="mean", rule="<= -2 se", base="1415.3",
      arm="1019.6 (paired -5.496 s a run, se 1.354, -4.1 se)", verdict="PASS", noise=gain(1.354, -5.496, k=2.0), **S),
    L(line="G crossing yield+blocked s <= +2 se", form="mean", rule="<= +2 se", base="424.5", arm="336.9 (-3.650, se 1.973)",
      verdict="PASS", noise=up(1.973, -3.650, k=2.0), **S),
    L(line="G crossing k-turn s <= +2 se", form="mean", rule="<= +2 se", base="558.9", arm="460.9 (-4.083, se 0.719)",
      verdict="PASS", noise=up(0.719, -4.083, k=2.0), **S),
    L(line="G locks yield+blocked s <= +2 se", form="mean", rule="<= +2 se", base="415.7", arm="426.0 (+0.429, se 2.117)",
      verdict="PASS", noise=up(2.117, 0.429, k=2.0), **S),
    L(line="G locks k-turn s <= +2 se", form="mean", rule="<= +2 se", base="193.3", arm="148.6 (-1.863, se 1.719)",
      verdict="PASS", noise=up(1.719, -1.863, k=2.0), **S),
    L(line="G terminus yield+blocked s <= +2 se", form="mean", rule="<= +2 se", base="575.1", arm="256.7 (-13.267, se 2.075)",
      verdict="PASS", noise=up(2.075, -13.267, k=2.0), **S),
    L(line="G terminus k-turn s <= +2 se", form="mean", rule="<= +2 se", base="799.4", arm="387.9 (-17.146, se 2.283)",
      verdict="PASS", noise=up(2.283, -17.146, k=2.0), **S),
    L(line="G per-arena wedged guard (filed for v3)", form="mean", rule="<= +2 se per arena", base="-",
      arm="crossing +2.6 se; Locks +9.2 s a run (+5.5 se); v3core Locks +7.3 se", verdict="FAIL",
      noise=dict(NONE, note="quoted as z only in R44.7"), **S),
    L(line="G5 / G6 / G7, fights G1-G4", form="reported", rule="as filed", base="G5 74.0 s; deaths 785", arm="G5 70.0 s; deaths 774",
      verdict="PASS", noise=NONE, source=WS + " Round 44 Rulings R44.15 (record)",
      **{k: v for k, v in S.items() if k != "source"}),
]

# ------------------------------- Bar A6 v3, the street hold's way read (manoeuvre stretch; READ R44.19: FAILS guard 2b) ---
a = (src44 + " Rulings R44.19 (FAILS as filed; holdway stays OFF) and " + REF + "manoeuvre/barsa6v3-builder2-9215b8ab9/")
A = {"round": 44, "stream": "manoeuvre", "item": "A6 v3 --traffic-on=holdway (decided on the side stage's jam_s)", "commit": "9215b8ab9",
     "machine": "builder2", "n": "10949-10972, n 24 (E1 on 10973-10996)", "source": a}
LINES += [
    L(line="(1) side-stage jam_s: ARM < BASE by >= 2 se", form="total", rule="<= -2 se", base="348 crew-s",
      arm="43 crew-s (-25.4 s a run, -5.7 se)", verdict="PASS", noise=dict(NONE, note="quoted as z only in R44.19"), **A),
    L(line="2b head-on mechanism guard: held_on_s within BASE +/- 2 se (two-sided)", form="total", rule="+/- 2 se",
      base="769", arm="459 (-2.26 se)", verdict="FAIL", noise=dict(NONE, note="quoted as z only in R44.19"), **A),
    L(line="side guards; E1 byte-identical", form="reported", rule="as filed", base="-",
      arm="every side guard PASS; E1 byte-identical", verdict="PASS", noise=DET, **A),
    L(line="reported (head-on): last arrival, mouth touches", form="reported", rule="-", base="-",
      arm="last arrival 13 s sooner; +19 touches a run at the mouth (+1.0 se, inside its line)", verdict="REPORTED", noise=NONE, **A),
]

# --------------------------------------- Bar B1, his War Rig backs out of the box first (manoeuvre; READ R44.25: FAILS D2) ---
b = (src44 + " Rulings R44.25 (FAILS as filed; backout stays OFF) and " + REF +
     "manoeuvre/barsb1-builder0+builder2-9111520bf/ (README.md, judge-*.txt)")
B = {"round": 44, "stream": "manoeuvre", "item": "B1 --traffic-on=backout (backout alone, twin r3 in both arms)",
     "commit": "9111520bf", "machine": "builder0 light + builder2 (per leg: meta.txt)",
     "n": "11101-11148: his start 1 run; corpus 48 jittered poses; workload / group / fights per the bar", "source": b}
POSES = {"kind": "none", "note": "per-pose verdicts on a deterministic staged corpus: a share of poses, not a sample mean"}
LINES += [
    L(line="D1 his start (Locks 56416, Green_Guns_2): reverses before tick 15 and past the box before tick 110; base must not do both",
      form="reported", rule="< 15 and < 110", base="reverse t44, past t140", arm="reverse t4, past t93", verdict="PASS",
      noise=DET, **B),
    L(line="D2 corpus, base-stuck poses (floor 8): ON clears sooner in >= 80 % and median <= -1.0 s", form="share",
      rule=">= 80 %, median <= -1.0 s", base="21 base-stuck poses", arm="15 of 21 = 71 %, median -1.73 s (losing: pose 13 x3, the "
      "look never fires; crossing crawl poses 10 / 6, +1.7 to +5.3 s)", verdict="FAIL", noise=POSES, **B),
    L(line="D2 corpus, cost ceiling on the other poses: worst <= +3.0 s, median <= +1.0 s", form="reported",
      rule="<= +3.0 / <= +1.0 s", base="27 poses", arm="worst +1.9 s, median -0.57 s", verdict="PASS", noise=POSES, **B),
    L(line="G workload yield+blocked s per arena: ARM - BASE <= +2 se", form="mean", rule="<= +2 se", base="crossing 446.8, locks "
      "416.0, terminus 674.6", arm="crossing -3.3 se, locks -1.4 se, terminus -5.4 se", verdict="PASS", noise=NONE, **B),
    L(line="G workload k-turn s per arena: ARM - BASE <= +2 se", form="mean", rule="<= +2 se", base="crossing 555.3, locks 201.6, "
      "terminus 799.3", arm="crossing -1.3 se, locks +1.3 se, terminus -4.8 se", verdict="PASS", noise=NONE, **B),
    L(line="G workload seated by 15 s: ARM - BASE >= -2 se", form="mean", rule=">= -2 se", base="218", arm="215 (paired -0.042, "
      "se 0.129, -0.3 se)", verdict="PASS", noise=up(0.129, -0.042, k=2.0), **B),
    L(line="G never-arrived and wedged s (workload)", form="mean", rule="no worse by 2 se", base="-", arm="never-arrived -0.83 a "
      "run (se 0.18); wedged -2.58 s a run (se 1.01)", verdict="PASS", noise=NONE, **B),
    L(line="G other crews' reversing ticks (15 s) per arena: <= +2 se; their seated-by-15 s >= -2 se", form="mean",
      rule="<= +2 se / >= -2 se", base="-", arm="crossing -1.3 / -1.4, locks -1.6 / +0.0, terminus -0.6 / +2.2 se",
      verdict="PASS", noise=NONE, **B),
    L(line="G nose-on crews' time to clear 8 m: ARM < BASE by >= 2 se", form="mean", rule="<= -2 se",
      base="271.1 ticks a crew", arm="209.1 (paired -61.98, se 16.56, -3.7 se)", verdict="PASS", noise=gain(16.56, 61.98, k=2.0),
      **B),
    L(line="G group G5 / G6 / G7 (11125-11136): every-squad-in, never-in, friendly contacts", form="reported", rule="no worse",
      base="71.2 s / 0.79 / 640504", arm="71.2 s / 0.79 / 640504 (identical arms)", verdict="PASS", noise=DET, **B),
    L(line="G G1 v9 corridor (C44.3): ORDERS_PROBE_SQUAD rows byte-identical", form="count-runs", rule="all identical",
      base="180 rows", arm="180 / 180 identical; friend contacts 1659 = 1659", verdict="PASS", noise=DET, **B),
    L(line="G fights G1-G4 (11137-11142): give-way deaths, stuck deaths, contacts, kill share", form="reported",
      rule="each inside its line", base="54 / 151 / 366752 / 0.498-0.502", arm="50 / 159 / 371073 / moved 0.003",
      verdict="PASS", noise=NONE, **B),
    L(line="read (not a guard): fights' moving-stuck seconds", form="reported", rule="-", base="189.3 s",
      arm="248.2 s (+3.27 s a fight, se 3.07, 1.1 se)", verdict="NOT JUDGED", noise=NONE, **B),
]

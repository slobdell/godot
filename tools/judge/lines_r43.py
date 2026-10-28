#!/usr/bin/env python3
"""Every judged bar line of round 43, as data (round 43 native N4).

The same fields, helpers and noise kinds as `lines_r31_34.py` (read its docstring). Lines are added as each bar's VERDICT lands
in *Bars (round 43)* / *Rulings (round 43)* in `_agents/workstreams.md` (or the stream's own report); nothing is re-measured.
Round 43's bars by the seed registry: engage A (10301-10324 deciding, 10325-10348 fight guards + A's pooled extension, 10349-10372
G1-G5), engage A6 (10373-10396; guards 10397-10400 + 10573-10592), manoeuvre S (10401-10424; guards 10425-10448; bridge 10449-10472),
camera K5 (10501-10536 an arm; K5 v2 10537-10572); native none. Read so far: A, A6, A6 v2, A7 (1-9), K5; not yet: S, S5, K5 v2,
A7 lines 10-11.
"""
from lines_r31_34 import DET, L, band, gain, se_line, up, within  # noqa: F401

WS = "_agents/workstreams.md"
src43 = WS + " Round 43"
NONE = {"kind": "none"}
LINES = []

# ------------------------------------------------- Bar A, the street hold's far crews (engage; READ R43.18: FAILS as filed) ---
a = (src43 + " Bars 'FILED Bar A, the street hold's far crews' (FILED 677199e2b on tree 9e8313f8d) and 'READ (R43.18): FAILS as "
     "filed'; the table in streams/engage.md (stream/engage)")
A_N = "three head-on stages (terminus west, terminus east, Locks' lock), 10301-10324, n 24 paired, native on, no timeout"
A = {"round": 43, "stream": "engage", "item": "A --traffic-on=holdfar", "commit": "9e8313f8d", "machine": "builder2",
     "n": A_N, "source": a}
LINES += [
    L(line="(1) far_arrive_s: the far crews' mean arrival ARM < BASE by >= 2 se", form="mean", rule="-2 se",
      base="1294.0 (53.9 s a run)", arm="1236.5 (51.5 s); paired -2.40, se 1.38 (z -1.73)", verdict="FAIL",
      noise=gain(1.38, -2.40, k=2.0), **A),
    L(line="G2 contacts_mouth ARM <= BASE + 1.645 se", form="total", rule="<= base + 1.645 se", base="622",
      arm="626 (+0.17 a run, se 1.39)", verdict="PASS", noise=up(1.39, 0.17), **A),
    L(line="G3 contacts_far ARM <= BASE + max(1.645 se, 2 touches)", form="total", rule="<= base + 2", base="141",
      arm="145 (+0.17 a run, se 0.21)", verdict="PASS", noise=up(0.21, 0.17), **A),
    L(line="G4 jam_s ARM <= BASE + 1.645 se", form="total", rule="<= base + 1.645 se", base="620", arm="560 (-2.50, se 1.17)",
      verdict="PASS", noise=up(1.17, -2.50), **A),
    L(line="G5 last_a_s ARM <= BASE + 1.645 se", form="mean", rule="<= base + 1.645 se", base="1517", arm="1490 (-1.12, se 2.07)",
      verdict="PASS", noise=up(2.07, -1.12), **A),
    L(line="exercised floor: the rule acts on >= 16 of 24 seeds", form="count-runs", rule=">= 16", base="23 verdicts",
      arm="16 (far_released 18 + far_held 15 crews)", verdict="PASS", noise=DET, **A),
    L(line="reported: held_s, a_held_s, away_s / away_m, stuck_s, contacts, last_b_s", form="reported", rule="-",
      base="held_s 2005; a_held_s 1162", arm="held_s 1686 (-13.3 a run, z -3.65); a_held_s 860 (z -3.41)", verdict="REPORTED",
      noise=NONE, **A),
]

# ----------------------------------------- Bar A6, the street-hold verdict by ordered way (engage; READ R43.20: FAILS guard 2b) ---
a6 = (src43 + " Bars 'FILED Bar A6' (FILED a72983638 on tree 98739047a) and 'READ (R43.20): FAILS guard 2b'")
A6 = {"round": 43, "stream": "engage", "item": "A6 --traffic-on=holdway", "commit": "98739047a", "machine": "builder2",
      "n": "10373-10396, n 24 (12 terminus_side + 12 head-on), native both arms, no timeout", "source": a6}
LINES += [
    L(line="(1) off_arrive_s (side seeds): ARM < BASE by >= 2 se", form="mean", rule="-2 se", base="49.5 s a run",
      arm="37.9 s (paired -11.58, se 4.07, z -2.84)", verdict="PASS", noise=gain(4.07, -11.58, k=2.0), **A6),
    L(line="2a verdicts (head-on) within BASE +/- 2 se", form="mean", rule="+/- 2 se", base="-", arm="-0.25 (se 0.18)",
      verdict="PASS", noise=within(0.18, -0.25, k=2.0), **A6),
    L(line="2b held_on_s (head-on crews whose routes cross the street) within BASE +/- 2 se", form="mean", rule="+/- 2 se",
      base="-", arm="-40.8 s (se 13.3, z -3.07): real head-on crews released", verdict="FAIL", noise=within(13.3, -40.8, k=2.0),
      **A6),
    L(line="3-6 contacts_mouth, contacts_far (+2 floor), jam_s, last_a_s", form="total", rule="<= base + 1.645 se", base="-",
      arm="all within (jam_s -9.29, better)", verdict="PASS", noise=NONE, **A6),
]

# ------------------------------------------ Bar A6 v2, two arms v one BASE (engage; READ R43.21: FAILS line 1 in both arms) ---
a6b = (src43 + " Bars 'FILED Bar A6 v2, two arms' (FILED d4a91fc6b on tree 13fbe1a5d) and 'READ (R43.21): FAILS line 1 in both "
       "arms'")
A6B = {"round": 43, "stream": "engage", "commit": "13fbe1a5d", "machine": "builder2",
       "n": "10601-10624, n 24 (12 side + 12 head-on), native, no timeout", "source": a6b}
LINES += [
    L(item="A6 v2 ARM-W (ordered way)", line="(1) off_arrive_s (side): ARM < BASE by >= 2 se", form="mean", rule="-2 se",
      base="59.8 s a run", arm="-6.33 s (se 5.16, z -1.23)", verdict="FAIL", noise=gain(5.16, -6.33, k=2.0), **A6B),
    L(item="A6 v2 ARM-WR (ordered way + route release)", line="(1) off_arrive_s (side): ARM < BASE by >= 2 se", form="mean",
      rule="-2 se", base="59.8 s a run", arm="-4.46 s (se 4.96, z -0.90)", verdict="FAIL", noise=gain(4.96, -4.46, k=2.0), **A6B),
    L(item="A6 v2 ARM-W (ordered way)", line="2b held_on_s within BASE +/- 2 se", form="mean", rule="+/- 2 se", base="-",
      arm="-6.25 s (se 7.70)", verdict="PASS", noise=within(7.70, -6.25, k=2.0), **A6B),
    L(item="A6 v2 ARM-WR (ordered way + route release)", line="2b held_on_s within BASE +/- 2 se", form="mean", rule="+/- 2 se",
      base="-", arm="-20.5 s (se 11.85, z -1.73)", verdict="PASS", noise=within(11.85, -20.5, k=2.0), **A6B),
    L(item="A6 v2 ARM-WR (ordered way + route release)", line="10 perf: the verdict's find_path cost (ON check perf-judge <= 1.05x)",
      form="reported", rule="<= 1.05x", base="-", arm="0.59 ms a verdict, 3.3 queries", verdict="REPORTED", noise=NONE, **A6B),
]

# --------------------------------------------- Bar A7, across water: gun on, hull still (engage; READ R43.23: lines 1-9 PASS) ---
a7 = src43 + " Bars 'Bar A7' and 'READ lines 1-8 (R43.23): PASS' (+ line 9)"
A7 = {"round": 43, "stream": "engage", "item": "A7 --engage-water", "commit": "8ac00d19b", "machine": "builder2",
      "n": "10649-10672, n 24 paired, both arms GDScript decide (native's twin 457effa1a makes it the native read)", "source": a7}
LINES += [
    L(line="(1) hop_s: combat hops toward a contact across water, ARM < BASE by >= 2 se", form="total", rule="-2 se",
      base="34.8 s a run", arm="0.7 s (-34.1, se 2.85, z -12.0)", verdict="PASS", noise=gain(2.85, -34.1, k=2.0), **A7),
    L(line="(2) off_order_m", form="mean", rule="-2 se", base="21.5 m", arm="10.6 m (-10.9, se 4.33, z -2.52)", verdict="PASS",
      noise=gain(4.33, -10.9, k=2.0), **A7),
    L(line="3-8 damage, first hit, deaths, kills, last_a, named-attack deaths", form="mean", rule="as filed", base="-",
      arm="damage +122 (se 108); first hit +0.45 s (se 0.68); deaths 64 -> 48 (z -2.9); kills 49 -> 57; last_a -5.6 s; "
      "named-attack deaths 60 -> 57 (se 0.31)", verdict="PASS", noise=NONE, **A7),
    L(line="9 Bar E1's probe byte-identical ON v OFF (10673-10696)", form="deterministic", rule="identical", base="stuck 128.5",
      arm="128.5 crew-s; first hit 7.02 = 7.02 s; deaths 25 = 25", verdict="PASS", noise=DET, **A7),
]

# --------------------------------------------------------- Bar K5, the corner swing (camera; READ R43.27: FAILS 6 lines) ---
k5 = src43 + " Bars 'FILED Bar K5, the corner swing' (FILED eb6deaf78; series 65e6e7e92) and 'READ (R43.27): FAILS 6 lines'"
K5 = {"round": 43, "stream": "camera", "item": "K5 --camera-corner", "commit": "08931da4e", "machine": "builder2",
      "n": "10501-10536, n 36 an arm a workload, J8", "source": k5}
LINES += [
    L(line="D1 toward the hidden side, CORNER pooled ARM >= BASE + 10 points and ARM > BASE each arena", form="share",
      rule="+10 points; each arena", base="56.7 % (Locks 27.6, Terminus 85.0)", arm="65.6 % (+8.9; Locks 48.4, Terminus 83.3)",
      verdict="FAIL", noise=NONE, **K5),
    L(line="D2 facing the building after the corner opens, EMPTY pooled ARM <= 0.75 x BASE", form="share", rule="<= 0.75 x",
      base="11.4 %", arm="13.8 %", verdict="FAIL", noise=NONE, **K5),
    L(line="D3 seen -> on screen ARM mean <= BASE", form="mean", rule="<= base", base="3.98 s", arm="0.49 s", verdict="PASS",
      noise=NONE, **K5),
    L(line="G0 no fog cheat: per-frame yaw identical CORNER v EMPTY to the first known enemy", form="count-runs", rule="72/72",
      base="-", arm="72/72 identical", verdict="PASS", noise=DET, **K5),
    L(line="G1 the empty corner not seasick: reversals <= BASE + 1", form="mean", rule="<= base + 1", base="Terminus EMPTY 2.76",
      arm="4.38", verdict="FAIL", noise=NONE, **K5),
    L(line="G4 no swinging on every workload", form="mean", rule="as filed", base="ambush 2.91; attack 5.98",
      arm="ambush 4.73; attack 7.01", verdict="FAIL", noise=NONE, **K5),
    L(line="G2 K4 v2's lines, G3 K3 v2's lines, G5 own squad on screen, G6 runs clean", form="reported", rule="as filed", base="-",
      arm="all PASS", verdict="PASS", noise=NONE, **K5),
]

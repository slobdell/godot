#!/usr/bin/env python3
"""Every judged bar line of round 43, as data (round 43 native N4).

The same fields, helpers and noise kinds as `lines_r31_34.py` (read its docstring). Lines are added as each bar's VERDICT lands
in *Bars (round 43)* / *Rulings (round 43)* in `_agents/workstreams.md` (or the stream's own report); nothing is re-measured.
Round 43's bars by the seed registry: engage A (10301-10324 deciding, 10325-10348 fight guards + A's pooled extension, 10349-10372
G1-G5), engage A6 (10373-10396; guards 10397-10400 + 10573-10592), manoeuvre S (10401-10424; guards 10425-10448; bridge 10449-10472),
camera K5 (10501-10536 an arm; K5 v2 10537-10572); native none. Filed and not yet read (no lines yet): K5, A6.
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

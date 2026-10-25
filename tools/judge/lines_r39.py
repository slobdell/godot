#!/usr/bin/env python3
"""Every judged bar line of round 39, as data (round 40 native, close step 5b owed since round 37).

The same fields, helpers and noise kinds as `lines_r31_34.py` (read its docstring). Every quoted number is the streams' own,
from *Bars (round 39)* and *Rulings (round 39)* in `_agents/workstreams.md`; nothing is re-measured. A line's noise is the se
its ruling PRINTED (kind `se`; "-4.3 se" with its difference gives se = |d| / 4.3); counts, medians and cells with no se carry
`none`. Doctrine's bars were judged at 2 paired se (k = 2), the rest at 1.645.
"""
from lines_r31_34 import DET, L, gain, up, within  # noqa: F401

WS = "_agents/workstreams.md"
src39 = WS + " Round 39"
NONE = {"kind": "none"}
LINES = []

# ---------------------------------------------------------------- D2s halt dwell 1.0 (doctrine) -------------------------
d2s = src39 + " Bars 'D2s RESULT'; reverted e453dc541"
LINES += [
    L(round=39, stream="doctrine", item="D2s HALT_DWELL 1.0", commit="d1822fd27", line="full check: scenario_cover fights_from_cover hidden >= 50 % of 40 s",
      form="deterministic", n="the scenario", rule=">= 50 %", base="86 % (dwell 2.0)", arm="32 %; hurt tank's longest hidden 50 ticks (bar 60)",
      verdict="FAIL (reverted; the dwell stays 2.0)", source=d2s, noise=DET),
]

# ---------------------------------------------------------------- D3 defend split (doctrine) ----------------------------
d3lab = src39 + " Bars 'D3 RESULT (lab guard)'; hold_fire_probe a24f4f298"
d3 = src39 + " Bars 'D3 RESULT (powered series)'; 773412e49"
LINES += [
    L(round=39, stream="doctrine", item="D3 defend split (lab guard)", commit="a24f4f298", line="guard: turtle-line CPU `hold` <= OFF + 10 pts",
      form="share", n="2601-2602 x 5 maps x both sides, 20 fights a line an arm", rule="<= 32.7 %", base="22.7 %", arm="37.6 % (+14.9)",
      verdict="FAIL", source=d3lab, noise={"kind": "none", "note": "a fixed-points bound; no se printed"}),
    L(round=39, stream="doctrine", item="D3 defend split", commit="773412e49", line="DECIDING blob win rate down > 2 paired se AND McNemar p < 0.05",
      form="share", n="6301-6340 + 6401-6440 x 5 maps x both sides, 800 fights a line an arm, paired", rule="drop > 2 se, p < 0.05",
      base="39 %", arm="39 % (+0.3, se 1.6; flips 72/74; p 0.60)", verdict="FAIL (SPLIT stays OFF)", source=d3, machine="builder2",
      noise=gain(1.6, 0.3, k=2.0)),
    L(round=39, stream="doctrine", item="D3 defend split", commit="773412e49", line="G1: turtle win rate not up > 2 se",
      form="share", n="800 fights a line an arm", rule="<= base + 2 se", base="36 %", arm="31 % (-4.7, se 1.2)", verdict="PASS",
      source=d3, machine="builder2", noise=up(1.2, -4.7, k=2.0)),
    L(round=39, stream="doctrine", item="D3 defend split", commit="773412e49", line="G2t: turtle-line kills a fight within 2 se",
      form="mean", n="800 fights a line an arm", rule="within 2 se", base="-", arm="-0.69 a fight (-4.3 se); losses -1.13",
      verdict="FAIL", source=d3, machine="builder2", noise=within(0.69 / 4.3, -0.69, k=2.0)),
    L(round=39, stream="doctrine", item="D3 defend split", commit="773412e49", line="G2: median length per faction within 2 se (turtle gangs)",
      form="median", n="800 fights a line an arm", rule="within 2 se", base="-", arm="-29 s (5.8 se); blob gangs +7 s, blob law -8 s",
      verdict="FAIL", source=d3, machine="builder2", noise=within(29.0 / 5.8, -29.0, k=2.0)),
]

# ---------------------------------------------------------------- S1 route-clear (settle) -------------------------------
s1 = src39 + " Bars 'S1 route-clear ... RESULT FAILED'; 6ab14f1ac"
LINES += [
    L(round=39, stream="settle", item="S1 route-clear", commit="6ab14f1ac", line="DECIDING 5-squad never-in no more than base",
      form="count-cells", n="6001-6024 cells", rule="<= base", base="1", arm="3 (terminus 5 click s6003, terminus 5 route s6003, crossing 5 route s6009)",
      verdict="FAIL (stays OFF)", source=s1, noise=NONE),
    L(round=39, stream="settle", item="S1 route-clear", commit="6ab14f1ac", line="guards: all-in, contacts, fights",
      form="total", n="6001-6024 cells", rule="no worse", base="all-in 25.8 s; contacts 11944", arm="24.7 s; 10623; fights flat",
      verdict="PASS (a failed bar's guards decide nothing)", source=s1, noise=NONE),
]

# ---------------------------------------------------------------- H v2 DEPLOY_HOLD (settle) -----------------------------
h2 = src39 + " Bars 'H v2 RESULT'; cd7a272d0, ship 2478e2eef"
LINES += [
    L(round=39, stream="settle", item="H v2 DEPLOY_HOLD", commit="cd7a272d0", line="counter: main loss re-lays >= 20",
      form="total", n="6025-6048, 72 fights an arm", rule=">= 20", base="288", arm="-", verdict="PASS (the workload exists)", source=h2, noise=DET),
    L(round=39, stream="settle", item="H v2 DEPLOY_HOLD", commit="cd7a272d0", line="DECIDING held's loss re-lays <= 20 % of main's",
      form="total", n="72 fights an arm", rule="<= 57.6", base="288", arm="0 (367 crews moved -> 0)", verdict="PASS (ships ON)", source=h2,
      noise={"kind": "none", "note": "288 -> 0; no se needed or printed"}),
    L(round=39, stream="settle", item="H v2 DEPLOY_HOLD", commit="cd7a272d0", line="guard: other-cause re-lays <= main + 3",
      form="total", n="72 fights an arm", rule="<= 3", base="0", arm="0", verdict="PASS", source=h2, noise=DET),
    L(round=39, stream="settle", item="H v2 DEPLOY_HOLD", commit="cd7a272d0", line="guards: kills and losses both sides within 1.645 se; 0 never started",
      form="mean", n="72 fights an arm", rule="within 1.645 se", base="his kills 5.39, losses 6.99; CPU losses 5.44",
      arm="5.31; 6.64; 5.33; 0 unstarted", verdict="PASS", source=h2, noise={"kind": "none", "note": "inside 1.645 se; se not printed"}),
]

# ---------------------------------------------------------------- M1 giveway-chain (manoeuvre) --------------------------
m1 = src39 + " Bars 'M1 RESULT'; tree 879caa818"
LINES += [
    L(round=39, stream="manoeuvre", item="M1 giveway-chain", commit="879caa818", line="DECIDING chained seat drift down beyond 1.645 se",
      form="total", n="terminus/locks/sumps x 6101-6112, 36 paired fights", rule="drop > 1.645 se", base="1248.9 m", arm="42.7 m (-8.4 se)",
      verdict="PASS", source=m1, noise=gain((1248.9 - 42.7) / 8.4, 42.7 - 1248.9)),
    L(round=39, stream="manoeuvre", item="M1 giveway-chain", commit="879caa818", line="G1-G4: give-way deaths, stuck, contacts",
      form="total", n="36 paired fights", rule="<= base + 1.645 se each", base="deaths 90; stuck 260; contacts 27012", arm="106; 265; 26969",
      verdict="PASS", source=m1, noise=NONE),
    L(round=39, stream="manoeuvre", item="M1 giveway-chain", commit="879caa818", line="G5: orders-probe never-in no more than base",
      form="count-cells", n="6113-6124, 144 paired runs", rule="<= base", base="2",
      arm="7 (new: locks 3 click s6124, locks 3 route s6113, terminus 5 route s6117/s6118/s6121)", verdict="FAIL (stays OFF)", source=m1, noise=NONE),
    L(round=39, stream="manoeuvre", item="M1 giveway-chain", commit="879caa818", line="G6: all-in median no worse",
      form="median", n="144 paired runs", rule="no worse", base="-", arm="+0.0 s", verdict="PASS", source=m1, noise=NONE),
]

# ---------------------------------------------------------------- G1 v5 group lead (orders) -----------------------------
g1 = src39 + " Bars 'G1 v5 RESULT'; game 632724c90, probe e7c896c8f; references/round39/orders/g1v5-judged-e7c896c8f/"
LINES += [
    L(round=39, stream="orders", item="G1 v5 GROUP LEAD", commit="e7c896c8f", line="DECIDING places outside (click cells) <= 25 % of base",
      form="total", n="6201-6212, n 12 a cell, streets 384/384 + his 48/48", rule="<= 25", base="100", arm="28 (locks 5 8 -> 8, his 5 36 -> 12)",
      verdict="FAIL (stays OFF)", source=g1, noise=NONE),
    L(round=39, stream="orders", item="G1 v5 GROUP LEAD", commit="e7c896c8f", line="guard: twitch per cell no worse (terminus_his 5 click)",
      form="median", n="12 seeds", rule="as filed", base="2.0", arm="8.2 (squad 2 twitches 28.4 m on all 12 seeds: one deterministic layout)",
      verdict="FAIL", source=g1, noise=DET),
    L(round=39, stream="orders", item="G1 v5 GROUP LEAD", commit="e7c896c8f", line="route_left <= 50 %; re-dealt 0; contacts <= base x 1.1 + 5",
      form="total", n="12 seeds a cell", rule="as filed", base="route_left 6490; re-dealt 48; contacts 14280", arm="1832; 0; 11413",
      verdict="PASS", source=g1, noise=NONE),
]

# ---------------------------------------------------------------- G3 v6 place-clear seat (orders) -----------------------
g3 = src39 + " Bars 'G3 v6 RESULT'; game 632724c90, probe e7c896c8f, builder2 J14"
LINES += [
    L(round=39, stream="orders", item="G3 v6 PLACE_CLEAR SEAT", commit="e7c896c8f", line="DECIDING pairs < 12 m <= 25 % of base",
      form="total", n="6213-6224, streets 384/384 + his 48/48", rule="<= 12.0", base="48", arm="12", verdict="PASS", source=g3,
      machine="builder2", noise=NONE),
    L(round=39, stream="orders", item="G3 v6 PLACE_CLEAR SEAT", commit="e7c896c8f", line="guards: never-in and twitch per cell (crossing 5 route)",
      form="deterministic", n="12 seeds a cell", rule="no worse", base="never-in 0; twitch 18.9", arm="1 (s6213 squads 4-5); 22.9 (s6220 squad 5 42.5 v 0.1)",
      verdict="FAIL (stays OFF)", source=g3, machine="builder2", noise=DET),
]

# ---------------------------------------------------------------- measurements reported (no bar) ------------------------
LINES += [
    L(round=39, stream="native", item="CP39.0 guard base (rules ON v OFF)", commit="8952c3d64", line="blob win rate, rules ON v 686150ed2 OFF",
      form="share", n="320 fights (2601-2608 x 5 maps x both sides x blob/turtle)", rule="-", base="-",
      arm="-5.6 points (se 2.9; flips 16/7; McNemar p 0.047); kr 0.85 -> 0.78", verdict="REPORTED (R39.2; the base every rules-ON bar pairs with)",
      source=src39 + " R39.2", machine="builder2", noise={"kind": "none", "note": "se 2.9 printed; a measurement, no bar"}),
    L(round=39, stream="native", item="N4 trig A/B (CORE-MATH v libm)", commit="6a1c77752", line="perf-judge us/tick, cr minus libm",
      form="mean", n="3 rounds alternating, quiet window", rule="-", base="libm 7,693 (sd 16)", arm="cr 7,862 (sd 72); +169 (+93, +225, +189)",
      verdict="REPORTED (R39.10)", source=src39 + " R39.10", noise=NONE),
]

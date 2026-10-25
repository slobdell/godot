#!/usr/bin/env python3
"""Every judged bar line of round 37, as data (round 40 native, close step 5b owed since round 37).

The same fields, helpers and noise kinds as `lines_r31_34.py` (read its docstring). Every quoted number is the streams' own,
from *Rulings (round 37)* in `_agents/workstreams.md` (R37.17, .22, .24, .25, .28, .30, .32, .33, .34, .37, .38, .40, .44);
nothing is re-measured. The guard-line bars (Bar R, Bar K) are paired against CP37.1's base (R37.14, 320 fights) and their
deciding line is a blob win-rate drop beyond 2 paired se (k = 2); the rest judge at 1.645.
"""
from lines_r31_34 import DET, L, gain, limit, up, within  # noqa: F401

WS = "_agents/workstreams.md"
src37 = WS + " Round 37"
NONE = {"kind": "none"}
LINES = []

# ---------------------------------------------------------------- Bar R: R1-R3 and the package (rules) -----------------
r_src = src37 + " R37.22 / R37.24 / R37.25 / R37.33; pair tree 75c3e74e0 v 9d325e291's 320 fights"
for ruling, arm_flag, arm, se, d, extra in (
        ("R37.22", "sight", "47 % (-0.6, se 3.5; flips 17/16; p 0.50)", 3.5, -0.6, "kr +0.004 (se 0.031)"),
        ("R37.24", "spread", "46 % (-1.2, se 3.5; flips 15/13; p 0.43)", 3.5, -1.2, "kr -0.025 (se 0.017)"),
        ("R37.25", "pin_slow", "44 % (-3.1, se 2.5; flips 14/9; p 0.20)", 2.5, -3.1, "kr -0.019 (se 0.024)"),
        ("R37.33", "sight,spread,pin_slow", "43 % (-4.4, se 3.4; flips 18/11; p 0.13)", 3.4, -4.4, "kr -0.036 (se 0.027)")):
    LINES.append(L(round=37, stream="rules", item="Bar R --rules-on=%s" % arm_flag, commit="75c3e74e0",
                   line="DECIDING blob win rate down > 2 paired se (McNemar)", form="share", n="320 fights paired",
                   rule="drop > 2 se", base="48 %", arm=arm + "; " + extra + "; turtle 39 % flat", verdict="NOT MET (stays OFF)",
                   source=src37 + " " + ruling + "; " + r_src, machine="builder2", noise=gain(se, d, k=2.0)))

# ---------------------------------------------------------------- Bar K: K2 hull-down (cover) ---------------------------
k_src = src37 + " R37.44; stream/cover 43d16acc4"
LINES += [
    L(round=37, stream="cover", item="Bar K K2 hull-down", commit="43d16acc4", line="DECIDING blob win rate down > 2 paired se",
      form="share", n="320 fights an arm (2601-08 + 2701-08, both sides)", rule="drop > 2 se", base="45 %", arm="44 % (-1.3, se 0.9; flips 2/0; p 0.25)",
      verdict="FAIL (K2 stays OFF)", source=k_src, machine="builder2", noise=gain(0.9, -1.3, k=2.0)),
    L(round=37, stream="cover", item="Bar K K2 hull-down", commit="43d16acc4", line="guards: turtle win rate, kills and length per faction",
      form="share", n="320 fights", rule="as filed", base="turtle 36 %", arm="37 % (+0.6, se 1.1); kills, length within 3 %",
      verdict="PASS", source=k_src, machine="builder2", noise=up(1.1, 0.6, k=2.0)),
]

# ---------------------------------------------------------------- O1 halt terrain anchor / latch (orders) ---------------
o17 = src37 + " R37.17; f4365153f, references/round37/orders/o1-judged-builder0-f4365153f/verdict.txt"
o37 = src37 + " R37.37; c14ec0d80"
o40 = src37 + " R37.40; 1ebd7e550, references/round37/orders/o1latch-reread-builder0-1ebd7e550/"
LINES += [
    L(round=37, stream="orders", item="O1 HALT_TERRAIN=anchor", commit="f4365153f", line="DECIDING relays <= 25 % of base; shape flips <= 1",
      form="total", n="12 cells x 3701-3712, 1152 squad rows", rule="<= 74.5; <= 1", base="298; 114", arm="0; 0 (reseats 258 -> 3)",
      verdict="PASS", source=o17, noise=NONE),
    L(round=37, stream="orders", item="O1 HALT_TERRAIN=anchor", commit="f4365153f", line="guard: twitch locks 5 route <= base + 3 m",
      form="median", n="12 seeds", rule="<= 6.9 m", base="3.9 m", arm="10.6 m", verdict="FAIL", source=o17, noise=DET),
    L(round=37, stream="orders", item="O1 HALT_TERRAIN=anchor", commit="f4365153f", line="guard: CPU friendly contacts <= line",
      form="total", n="3 cases x 3701-3706, 18 fights an arm", rule="<= 1836.5", base="1665", arm="1933 (+14.9 a fight, se 11.2)",
      verdict="FAIL", source=o17, noise=limit(1836.5 - 1665.0, 1933.0 - 1665.0)),
    L(round=37, stream="orders", item="O1-latch", commit="c14ec0d80", line="DECIDING no-fight relays; shape flips",
      form="total", n="3761-3772", rule="<= 32", base="128; 34", arm="2; 1", verdict="PASS", source=o37, noise=NONE),
    L(round=37, stream="orders", item="O1-latch", commit="c14ec0d80", line="guard: terminus 5-squad click twitch <= base + 3 m",
      form="median", n="12 seeds", rule="<= 19.8 m", base="16.8 m", arm="28.0 m (traced: the deploy's seat deal, on main too)",
      verdict="FAIL", source=o37, noise=DET),
    L(round=37, stream="orders", item="O1-latch", commit="c14ec0d80", line="fight read: relays <= line; his kills / losses, CPU losses within guard",
      form="total", n="3773-3784", rule="<= 110.5", base="442; kills 5.14, losses 6.78, CPU 5.22", arm="95; 4.72, 7.11, 4.81",
      verdict="PASS", source=o37, noise=NONE),
    L(round=37, stream="orders", item="O1-latch re-read (place + twitch)", commit="1ebd7e550", line="DECIDING relays <= limit; every cell's place + twitch",
      form="total", n="12 cells x 3821-3832", rule="<= 35.8", base="143; shape flips 19", arm="2; 1; all 12 cells pass",
      verdict="PASS (ships ON)", source=o40, noise=NONE),
]

# ---------------------------------------------------------------- O2 / O3 / O5 / O7 (orders) ---------------------------
o28 = src37 + " R37.28; c14ec0d80, references/round37/orders/*-judged-builder0-c14ec0d80/"
o32 = src37 + " R37.32; c14ec0d80, references/round37/orders/o5-judged-builder0-c14ec0d80/"
o38 = src37 + " R37.38; 1ebd7e550, references/round37/orders/o7-judged-builder0-1ebd7e550/"
LINES += [
    L(round=37, stream="orders", item="O2 PARKED_HOLD", commit="c14ec0d80", line="DECIDING off_idle_s a fight down beyond 1.645 se",
      form="mean", n="36 fights", rule="<= 86.3", base="172.6", arm="20.0 (drop 152.6 v 40.3)", verdict="PASS (held: re-deals 50 -> 105 real)",
      source=o28, noise=gain(40.3 / 1.645, 20.0 - 172.6)),
    L(round=37, stream="orders", item="O2 PARKED_HOLD", commit="c14ec0d80", line="guards: his kills, his losses, CPU losses within 1.645 se",
      form="mean", n="36 fights", rule="within 1.645 se", base="5.81; 6.11; 5.83", arm="5.47; 6.56; 5.47", verdict="PASS", source=o28, noise=NONE),
    L(round=37, stream="orders", item="O3 UNTANGLE_WHOLE", commit="c14ec0d80", line="DECIDING squads arriving short",
      form="total", n="12 cells", rule="as filed", base="46", arm="0", verdict="PASS", source=o28, noise=NONE),
    L(round=37, stream="orders", item="O3 UNTANGLE_WHOLE", commit="c14ec0d80", line="guards Crossing 5: crossed, never-in, twitch",
      form="deterministic", n="12 seeds", rule="no worse; <= base + 3 m", base="0; 0; 21.2 / 17.6 m", arm="2; 2; 25.5 / 22.3 m",
      verdict="FAIL", source=o28, noise=DET),
    L(round=37, stream="orders", item="O5 SEAT_ASIDE", commit="c14ec0d80", line="DECIDING CPU screen give-ways >= 50 % fewer",
      form="total", n="1811-1822, 36 fights an arm", rule="<= 638.5", base="1,277", arm="988 (-23 %)", verdict="FAIL (stays OFF)",
      source=o32, noise=NONE),
    L(round=37, stream="orders", item="O7 group-lay=column", commit="1ebd7e550", line="DECIDING places outside; metres outside",
      form="total", n="3801-3812", rule="<= 21; <= 16,759 m", base="84; 33,518 m", arm="45; 32,505 m", verdict="FAIL", source=o38, noise=NONE),
    L(round=37, stream="orders", item="O7 group-lay=column", commit="1ebd7e550", line="guards: probe cells; yard_open identical",
      form="deterministic", n="12 seeds a cell", rule="as filed", base="96/96 identical", arm="6 cells fail; 44/96 identical",
      verdict="FAIL", source=o38, noise=DET),
]

# ---------------------------------------------------------------- M1 sidestand / M5a seatstep (manoeuvre) --------------
m34 = src37 + " R37.34; ON 339d3f2e2 v BASE b822e6696, references/round37/manoeuvre/m1-series/"
m30 = src37 + " R37.30; ON 7ebbc7bdd v BASE 936612334, references/round37/manoeuvre/m5-series/"
LINES += [
    L(round=37, stream="manoeuvre", item="M1 sidestand", commit="339d3f2e2", line="(0) side re-stands; guards: far loops <= base + 1.645 se",
      form="total", n="72 fight pairs + 128 hull-rest pairs a task", rule="<= base + 18.9", base="far loops 61; unstick 2,802", arm="38 (-23); 2,738",
      verdict="PASS (ships ON)", source=m34, noise=up(18.9 / 1.645, -23.0)),
    L(round=37, stream="manoeuvre", item="M5a seatstep", commit="7ebbc7bdd", line="DECIDING seat metres down beyond 1.645 se",
      form="total", n="72 jam pairs", rule="drop > 3,051.3 m", base="43,206.5 m", arm="39,519.1 m (-8.5 %)", verdict="PASS", source=m30,
      machine="builder2", noise=gain(3051.3 / 1.645, 39519.1 - 43206.5)),
    L(round=37, stream="manoeuvre", item="M5a seatstep", commit="7ebbc7bdd", line="guard: team 1 kills within 1.645 se",
      form="total", n="72 jam pairs", rule="-81.0", base="1,411", arm="1,322 (-89)", verdict="FAIL", source=m30, machine="builder2",
      noise=within(81.0 / 1.645, -89.0)),
    L(round=37, stream="manoeuvre", item="M5a seatstep", commit="7ebbc7bdd", line="guard: hull-rest never-settled per task <= +4.9",
      form="count", n="128 pairs a task", rule="<= +4.9", base="faced_ambush 5; faced_attack_move 17", arm="10; 23", verdict="FAIL",
      source=m30, machine="builder2", noise=NONE),
]

# ---------------------------------------------------------------- measurements reported (no bar) ------------------------
LINES += [
    L(round=37, stream="native", item="CP37.1 guard base", commit="9d325e291", line="the blob and turtle lines",
      form="share", n="5 maps x 2601-2608 + 2701-2708 x both sides, 320 fights", rule="-", base="-",
      arm="blob 48 % (+-11), kr 0.88; turtle 39 % (+-15), kr 0.80; A/A blob 49/46 %", verdict="REPORTED (R37.14: the base Bars R and K pair with)",
      source=src37 + " R37.14", machine="builder2", noise=NONE),
]

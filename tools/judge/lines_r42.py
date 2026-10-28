#!/usr/bin/env python3
"""Every judged bar line of round 42, as data (round 42 native N3).

The same fields, helpers and noise kinds as `lines_r31_34.py` (read its docstring). Lines are added as each bar's VERDICT lands
in *Bars (round 42)* / *Rulings (round 42)* in `_agents/workstreams.md` (or the stream's own final report); nothing is re-measured.
Round 42's bars by the seed registry: engage E1 (9601-9624 deciding, 9625-9648 fight guards), camera K4 (9701-9736 an arm),
manoeuvre Q5 (9801-9824) and Q6 (9825-9848), balance B7 (9901-9940) and B8 (10001-10040 + 10101-10140; 10201-10240 dev, never a
bar); carried: Bar B2s v2 (8801-8840 + 8901-8940), Bar B5 t50 (9201-9240 + 9301-9340, only on his yes).
"""
from lines_r31_34 import DET, L, band, gain, se_line, up, within  # noqa: F401

WS = "_agents/workstreams.md"
src42 = WS + " Round 42"
NONE = {"kind": "none"}
LINES = []

# ---------------------------------------------------------------- Bar E1, the attack order gets a clear shot (engage) ---
e1 = (src42 + " Bars 'Bar E1' (FILED b37e7f4a4 / docs ab7269d4f; amended before any number, frozen tree 57e2e7eb5, then 4658fa514) "
      "and Rulings 'R42.12 ... deciding read: PASS' / 'R42.13 ... G3 PASSES on the paired mean; Bar E1 PASSES; flip ON'")
E1_N = "engage-bar 9601-9624, n 24 paired, 60 s windows, native off, J4"
E1_G = "locks, kinds none, green side, 9625-9648, 600 s, n 24 paired, native on"
LINES += [
    L(round=42, stream="engage", item="E1 --attack-shot", commit="5e9518da0",
      line="(1) stuck crew-seconds ON <= 0.25 x OFF AND paired mean < 0 by >= 2 se", form="total", n=E1_N,
      rule="<= 149.6 s and -2 se", base="598.4 s", arm="28.8 s (0.048x); paired -23.7 a run, se 6.6 (z -3.6)",
      verdict="PASS", source=e1, noise=gain(6.6, -23.7, k=2.0)),
    L(round=42, stream="engage", item="E1 --attack-shot", commit="5e9518da0",
      line="(2) seconds to each crew's first hit ON < OFF by >= 2 se", form="mean", n=E1_N, rule="-2 se", base="13.5 s",
      arm="4.0 s (-9.4, se 2.4, z -3.9)", verdict="PASS", source=e1, noise=gain(2.4, -9.4, k=2.0)),
    L(round=42, stream="engage", item="E1 --attack-shot", commit="5e9518da0",
      line="(3) deaths moving for a shot ON <= OFF + max(1.645 se, 2 crews); all deaths reported", form="total", n=E1_N,
      rule="<= 3", base="1 (all deaths 39)", arm="0 (all deaths 31; crews never hitting 32 -> 14 of 91)", verdict="PASS",
      source=e1, noise=NONE),
    L(round=42, stream="engage", item="E1 --attack-shot", commit="5e9518da0",
      line="(4) spots never reached, dither (cap 2.0), line flips reported", form="reported", n=E1_N, rule="dither <= 2.0",
      base="never 0; dither 0.00; flips 1.20", arm="never 2; dither 0.00; flips 1.25", verdict="REPORTED", source=e1, noise=NONE),
    L(round=42, stream="engage", item="E1 --attack-shot", commit="5e9518da0",
      line="(8) cost: lines a plan tick in the ON arm <= crews + 1 (series mean), OFF 0, the ON check's perf-judge PASS",
      form="mean", n=E1_N, rule="<= 4.8", base="0", arm="3.35", verdict="PASS", source=e1, noise=NONE),
    L(round=42, stream="engage", item="E1 --attack-shot", commit="5e9518da0",
      line="(9) SUPPRESS share of stuck seconds (R42.6)", form="reported", n=E1_N, rule="-", base="15.0 of 598.4 s (3 %)",
      arm="23.3 of 28.8 s (81 %; seeds 9609, 9619) -> Bar E2", verdict="REPORTED", source=e1, noise=NONE),
    L(round=42, stream="engage", item="E1 --attack-shot", commit="b08d54df3",
      line="G1 kills a fight within OFF +/- 1.645 paired se", form="mean", n=E1_G, rule="+/- 2.03", base="18.96",
      arm="19.79 (+0.83, se 1.24)", verdict="PASS", source=e1, machine="builder2", noise=within(1.24, 0.83)),
    L(round=42, stream="engage", item="E1 --attack-shot", commit="b08d54df3",
      line="G2 losses a fight within OFF +/- 1.645 paired se", form="mean", n=E1_G, rule="+/- 1.63", base="18.62",
      arm="18.54 (-0.08, se 0.99)", verdict="PASS", source=e1, machine="builder2", noise=within(0.99, -0.08)),
    L(round=42, stream="engage", item="E1 --attack-shot", commit="b08d54df3",
      line="G3 fight length within OFF +/- 1.645 paired se (read on the paired mean, R42.13)", form="mean", n=E1_G,
      rule="+/- 11.6 s", base="medians 181.0 s", arm="medians 193.4 s (+12.4, the tool's mismatch); paired mean +4.8 s, se 7.05 "
      "(z 0.69; 9 longer, 9 shorter, 6 identical)", verdict="PASS", source=e1, machine="builder2", noise=within(7.05, 4.8)),
    L(round=42, stream="engage", item="E1 --attack-shot", commit="b08d54df3",
      line="G4 kill ratio within OFF +/- 1.645 paired se", form="mean", n=E1_G, rule="+/- 2.42", base="1.02",
      arm="1.07 (+0.05, se 1.47)", verdict="PASS", source=e1, machine="builder2", noise=within(1.47, 0.05)),
    L(round=42, stream="engage", item="E1 --attack-shot", commit="b08d54df3",
      line="G5 no missing result, no SCRIPT ERROR", form="count-runs", n=E1_G, rule="48/48", base="-", arm="48/48",
      verdict="PASS", source=e1, machine="builder2", noise=DET),
]

# ---------------------------------------------------------------- Bar Q6, the deck-mouth wait (manoeuvre) --------------
q6 = (src42 + " Bars 'Bar Q6' (FILED 7569747ce = the frozen tree, code ac64ce939) and Rulings 'R42.15 ... Bar Q6 FAILS'; overrides "
      "tree d9382eed7; judges in _agents/streams/references/round42/manoeuvre/barq6-builder0-7569747ce/ (judge-bridge-main / "
      "-overrides / -drill-overrides-on / -group / -fights.txt)")
Q6_N = "72 runs paired, 9825-9836 x ticks {1,8,15} x both sides"
LINES += [
    L(round=42, stream="manoeuvre", item="Q6 --traffic-on=deckwait", commit="7569747ce",
      line="DECIDING 1 bridge-pooled 18/18 under the overrides ON (the drill)", form="count-runs", n="18 drill runs, seeds 1-3",
      rule="18/18", base="-", arm="18/18", verdict="PASS", source=q6, noise=DET),
    L(round=42, stream="manoeuvre", item="Q6 --traffic-on=deckwait", commit="7569747ce",
      line="DECIDING 2a (main) pooled rim ON <= OFF", form="total", n=Q6_N, rule="<= 31.1 s", base="31.1 s",
      arm="35.7 s (+15 %); per-run mean +0.06 s, se 0.05 (+1.2 se)", verdict="FAIL", source=q6,
      noise=se_line(0.05, 0.0, -0.064, "per run")),
    L(round=42, stream="manoeuvre", item="Q6 --traffic-on=deckwait", commit="d9382eed7",
      line="DECIDING 2a (overrides tree) pooled rim ON <= OFF", form="total", n=Q6_N, rule="<= 34.3 s", base="34.3 s",
      arm="41.1 s (+20 %); per-run mean +0.09 s, se 0.10 (+1.0 se)", verdict="FAIL", source=q6,
      noise=se_line(0.10, 0.0, -0.094, "per run")),
    L(round=42, stream="manoeuvre", item="Q6 --traffic-on=deckwait", commit="7569747ce",
      line="DECIDING 2b every surviving crew crosses, both trees", form="count-cells", n="72 runs an arm a tree", rule="72/72",
      base="main 72/72; overrides 72/72", arm="main 72/72; overrides 72/72", verdict="PASS", source=q6, noise=DET),
    L(round=42, stream="manoeuvre", item="Q6 --traffic-on=deckwait", commit="7569747ce",
      line="DECIDING 2c worst crew <= 3 s, both trees", form="deterministic", n="72 runs an arm a tree", rule="<= 3 s",
      base="main 1.9 s; overrides 2.2 s", arm="main 2.5 s; overrides 6.1 s (locks green s9836 t15; rust s9829 t1 3.1 s)",
      verdict="FAIL (overrides tree)", source=q6, noise=DET),
    L(round=42, stream="manoeuvre", item="Q6 --traffic-on=deckwait", commit="7569747ce",
      line="arrival guard (main): paired per-run arrival ON <= OFF + 1.645 se", form="mean", n=Q6_N, rule="<= +1.00 s",
      base="35.8 s", arm="36.9 s (+1.11, se 0.61)", verdict="FAIL", source=q6, noise=up(0.61, 1.11)),
    L(round=42, stream="manoeuvre", item="Q6 --traffic-on=deckwait", commit="d9382eed7",
      line="arrival guard (overrides tree): paired per-run arrival ON <= OFF + 1.645 se", form="mean", n=Q6_N,
      rule="<= +1.05 s", base="32.8 s", arm="33.7 s (+0.93, se 0.64)", verdict="PASS", source=q6, noise=up(0.64, 0.93)),
    L(round=42, stream="manoeuvre", item="Q6 --traffic-on=deckwait", commit="7569747ce",
      line="G5 group order: every-squad-in mean ARM <= BASE + 1.645 se (never-in reads 90 s)", form="mean",
      n="48 paired runs, 4 maps x 9837-9848", rule="<= 74.6 s", base="72.3 s", arm="74.1 s", verdict="PASS", source=q6,
      noise=up(1.39, 74.1 - 72.3)),
    L(round=42, stream="manoeuvre", item="Q6 --traffic-on=deckwait", commit="7569747ce",
      line="G6 group order: never-in squads a run ARM <= BASE + 1.645 se", form="mean", n="48 paired runs", rule="<= 1.22",
      base="1.04 (22 runs never-in)", arm="1.02 (22)", verdict="PASS", source=q6, noise=up(0.109, 1.02 - 1.04)),
    L(round=42, stream="manoeuvre", item="Q6 --traffic-on=deckwait", commit="7569747ce",
      line="G7 group order: friendly contact ticks ARM <= 1.05 x BASE", form="total", n="48 paired runs", rule="<= 718,393",
      base="684,184", arm="687,995 (+0.6 %)", verdict="PASS", source=q6, noise=NONE),
    L(round=42, stream="manoeuvre", item="Q6 --traffic-on=deckwait", commit="7569747ce",
      line="fight guards G1-G4 (wedge trace): give-way deaths, stuck deaths, contacts, kill share / deaths", form="total",
      n="18 paired fights, locks / terminus / sumps x 9837-9842", rule="G1 +19.7; G2 +23.4; G3 <= 512,523; G4 0.03 / +-40",
      base="39; 166; 465,930; 0.49 / 0.51; 805", arm="51; 162; 472,207; 0.53 / 0.47 (worst move 0.040, G4 FAIL); 807",
      verdict="FAIL (G4)", source=q6, noise=NONE),
    L(round=42, stream="manoeuvre", item="Q6 --traffic-on=deckwait", commit="7569747ce",
      line="reported: deck-jam seconds, both trees", form="reported", n=Q6_N, rule="-", base="main 49.2; overrides 51.1",
      arm="main 61.2; overrides 75.0", verdict="REPORTED", source=q6, noise=NONE),
]

# ---------------------------------------------------------------- Bar K4, the camera looks where the danger is (camera) -
k4 = (src42 + " Bars 'Bar K4' (FILED 76cb5053b Status; amended 4fd517b83, settled 0e4d4f732) and Rulings 'R42.16 ... Bar K4 FAILS on "
      "D2 (rear lane) and G1 (snaps)'; table in stream/camera c28470f2f _agents/streams/camera.md 'Bar K4 result'; both arms 0e4d4f732, "
      "builder0 light J4, headless 1920x1080 @60, Terminus")
K4_N = "Terminus 9701-9736, 36 runs an arm a workload (AMBUSH / RETREAT / ATTACK)"
LINES += [
    L(round=42, stream="camera", item="K4 --camera-danger", commit="0e4d4f732",
      line="D1 latency first shot -> shooter on screen (never = 20 s), AMBUSH + RETREAT pooled, ARM < BASE by >= 2 se of the "
      "difference", form="mean", n=K4_N + "; episodes 125 / 60", rule="-2 se", base="12.29 +- 0.80 s", arm="5.63 +- 0.97 s (5.3 se)",
      verdict="PASS", source=k4, noise=gain((0.80 ** 2 + 0.97 ** 2) ** 0.5, 5.63 - 12.29, k=2.0)),
    L(round=42, stream="camera", item="K4 --camera-danger", commit="0e4d4f732",
      line="D2 AMBUSH REAR lane alone: ARM latency mean < BASE AND ARM blind % <= BASE", form="mean", n="12 rear-lane seeds an arm",
      rule="< 6.5 s; <= 0.8 %", base="6.5 +- 1.9 s (3 never); blind 0.8 %", arm="6.6 +- 1.4 s (7 never); blind 3.2 %",
      verdict="FAIL", source=k4, noise=NONE),
    L(round=42, stream="camera", item="K4 --camera-danger", commit="0e4d4f732",
      line="D2 RETREAT alone: ARM latency mean < BASE AND ARM blind % <= BASE", form="mean", n="36 retreat runs an arm",
      rule="< 16.2 s; <= 9.5 %", base="16.2 +- 0.8 s (62 never); blind 9.5 %", arm="8.0 +- 2.7 s (3 never); blind 0.7 %",
      verdict="PASS", source=k4, noise=NONE),
    L(round=42, stream="camera", item="K4 --camera-danger", commit="0e4d4f732",
      line="D3 facing the wall: pooled and RETREAT alone ARM <= half BASE", form="total", n=K4_N, rule="<= 13.4 %; <= 18.9 %",
      base="26.7 %; retreat 37.8 %", arm="7.0 %; retreat 0.0 %", verdict="PASS", source=k4, noise=NONE),
    L(round=42, stream="camera", item="K4 --camera-danger", commit="0e4d4f732",
      line="G1 K3 v2 lines 1-3 on ATTACK: clicks >= 70 %, slip p95 <= 40 px, jerks <= 3/min, no automatic source > 1.5/min, "
      "snaps 0 everywhere", form="total", n=K4_N, rule=">= 70 %; <= 40 px; <= 3.0; <= 1.5; 0",
      base="79.7 %; 34.7 px; 0.33; 0.27; 0", arm="82.7 %; 31.5 px; 1.50; solid 1.500; 2 snaps (attack s9721, s9731; + ambush s9732)",
      verdict="FAIL (snaps)", source=k4, noise=NONE),
    L(round=42, stream="camera", item="K4 --camera-danger", commit="0e4d4f732",
      line="G2 held for his aim <= 25 % of play (ATTACK)", form="total", n=K4_N, rule="<= 25 %", base="15.2 %", arm="16.0 %",
      verdict="PASS", source=k4, noise=NONE),
    L(round=42, stream="camera", item="K4 --camera-danger", commit="0e4d4f732",
      line="G3 action share ARM >= BASE - 10 points (ATTACK)", form="total", n=K4_N, rule=">= 32.9 %", base="42.9 %",
      arm="47.5 %", verdict="PASS", source=k4, noise=NONE),
    L(round=42, stream="camera", item="K4 --camera-danger", commit="0e4d4f732",
      line="G4 yaw reversals/min ARM <= BASE + 1 on each workload (attack / ambush / retreat)", form="total", n=K4_N,
      rule="<= 11.64 / 6.32 / 2.48", base="10.64 / 5.32 / 1.48", arm="4.95 / 2.58 / 1.55", verdict="PASS", source=k4, noise=NONE),
    L(round=42, stream="camera", item="K4 --camera-danger", commit="0e4d4f732",
      line="G5 own squad on screen (not behind an uncut wall) ARM >= BASE - 5 points on each workload", form="total", n=K4_N,
      rule=">= 92.0 / 94.5 / 92.6 %", base="97.0 / 99.5 / 97.6 %", arm="96.3 / 96.4 / 94.6 %", verdict="PASS", source=k4,
      noise=NONE),
    L(round=42, stream="camera", item="K4 --camera-danger", commit="0e4d4f732",
      line="G6 every run ok, no SCRIPT ERROR, every scenario staged", form="count-runs", n="216 runs", rule="all",
      base="-", arm="216 ok, 0 SCRIPT ERROR, 72/72 staged", verdict="PASS", source=k4, noise=DET),
]

# ---------------------------------------------------------------- Bar K4 v2, the LAST re-file (camera) -------------------
k4v2 = (src42 + " Bars 'Bar K4 v2' (FILED 4165f4619 Status; R42.16 + R42.18) and Rulings 'R42.22 ... Bar K4 v2 PASSES every line; "
        "--camera-danger ships ON'; both arms ef55e64b8 (green ALL JUDGED), builder0 light J4, Terminus; ships c27f8011c")
K4V2_N = "Terminus 9737-9772, 36 runs an arm a workload (AMBUSH / RETREAT / ATTACK), 216 runs ok"
LINES += [
    L(round=42, stream="camera", item="K4 v2 --camera-danger", commit="ef55e64b8",
      line="D1 latency first shot -> shooter on screen, AMBUSH + RETREAT pooled, ARM < BASE by >= 2 se of the difference",
      form="mean", n=K4V2_N, rule="-2 se", base="11.61 s", arm="5.60 s (4.9 se)", verdict="PASS", source=k4v2,
      noise=gain((11.61 - 5.60) / 4.9, 5.60 - 11.61, k=2.0)),
    L(round=42, stream="camera", item="K4 v2 --camera-danger", commit="ef55e64b8",
      line="D2 AMBUSH REAR lane alone: ARM latency mean < BASE AND ARM blind as a share of time under fire <= BASE (R42.18)",
      form="mean", n="rear-lane seeds, 36 ambush runs an arm", rule="< 14.03 s; <= 16.4 %", base="14.03 s; blind 16.4 % (of play 6.5)",
      arm="4.77 s; blind 14.0 % (of play 6.4)", verdict="PASS", source=k4v2, noise=NONE),
    L(round=42, stream="camera", item="K4 v2 --camera-danger", commit="ef55e64b8",
      line="D2 RETREAT alone: ARM latency mean < BASE AND ARM blind as a share of time under fire <= BASE", form="mean",
      n="36 retreat runs an arm", rule="< 13.94 s; <= 19.3 %", base="13.94 s; blind 19.3 % (of play 8.9)",
      arm="9.06 s; blind 2.9 % (of play 1.3)", verdict="PASS", source=k4v2, noise=NONE),
    L(round=42, stream="camera", item="K4 v2 --camera-danger", commit="ef55e64b8",
      line="D3 facing the wall: pooled and RETREAT alone ARM <= half BASE", form="total", n=K4V2_N, rule="<= 13.2 %; <= 13.9 %",
      base="26.4 %; retreat 27.8 %", arm="9.2 %; retreat 0.0 %", verdict="PASS", source=k4v2, noise=NONE),
    L(round=42, stream="camera", item="K4 v2 --camera-danger", commit="ef55e64b8",
      line="G1 K3 v2 lines 1-3 on ATTACK: clicks on the unit >= 70 %, slip p95 <= 40 px, jerks <= 3/min, no automatic source > "
      "1.5/min, snaps 0 everywhere", form="total", n=K4V2_N, rule=">= 70 %; <= 40 px; <= 3.0; <= 1.5; 0",
      base="83.8 %; 31.2 px; 0.19/min; 0", arm="76.1 %; 33.5 px; 0.84/min (solid); snaps 0 (ambush solid jerks 1.88/min, reported)",
      verdict="PASS", source=k4v2, noise=NONE),
    L(round=42, stream="camera", item="K4 v2 --camera-danger", commit="ef55e64b8",
      line="G2 held for his aim <= 25 % of play (ATTACK)", form="total", n=K4V2_N, rule="<= 25 %", base="15.0 %", arm="15.9 %",
      verdict="PASS", source=k4v2, noise=NONE),
    L(round=42, stream="camera", item="K4 v2 --camera-danger", commit="ef55e64b8",
      line="G3 action share ARM >= BASE - 10 points (ATTACK)", form="total", n=K4V2_N, rule=">= 30.8 %", base="40.8 %",
      arm="49.2 %", verdict="PASS", source=k4v2, noise=NONE),
    L(round=42, stream="camera", item="K4 v2 --camera-danger", commit="ef55e64b8",
      line="G4 yaw reversals/min ARM <= BASE + 1 on each workload (attack / ambush / retreat)", form="total", n=K4V2_N,
      rule="<= 11.8 / 5.8 / 3.8", base="10.8 / 4.8 / 2.8", arm="5.5 / 3.0 / 1.7", verdict="PASS", source=k4v2, noise=NONE),
    L(round=42, stream="camera", item="K4 v2 --camera-danger", commit="ef55e64b8",
      line="G5 own squad on screen (not behind an uncut wall) ARM >= BASE - 5 points on each workload", form="total", n=K4V2_N,
      rule=">= 91.8 / 93.7 / 91.2 %", base="96.8 / 98.7 / 96.2 %", arm="95.9 / 97.2 / 94.7 %", verdict="PASS", source=k4v2,
      noise=NONE),
    L(round=42, stream="camera", item="K4 v2 --camera-danger", commit="ef55e64b8",
      line="G6 every run ok, no SCRIPT ERROR, every scenario staged", form="count-runs", n="216 runs", rule="all",
      base="-", arm="216 ok, 72/72 staged", verdict="PASS", source=k4v2, noise=DET),
]

# ---------------------------------------------------------------- Bar E2, the SUPPRESS stand (engage): INCONCLUSIVE -------
e2 = (src42 + " Bars 'Bar E2' (FILED in Status at eb4024fe3; R42.12, R42.14 dominance form) and Rulings 'R42.19' (9649-9672: 0 of 24 "
      "exercised, extended as filed) / 'R42.20 ... Bar E2 INCONCLUSIVE on the pooled n 48; v2 stays OFF'")
E2_N = "engage-probe 9649-9696 pooled, n 48 paired, 60 s, natural draw, native off, builder0 light J4"
LINES += [
    L(round=42, stream="engage", item="E2 --attack-shot-suppress", commit="dcf83c66a",
      line="deciding 1 (dominance): stuck_suppress ON <= 0.25 x OFF AND no seed worse (ON <= OFF + 0.5 s every seed), exercised "
      "floor >= 3 seeds with OFF >= 2 s (fewer -> extend to n 48; still fewer -> INCONCLUSIVE)", form="total", n=E2_N,
      rule="floor 3 exercised seeds", base="stuck_suppress 13.6 crew-s (1 seed, 9695)", arm="0.0 crew-s; 47 of 48 seeds byte-identical",
      verdict="NULL (INCONCLUSIVE: 1 of 48 seeds exercised; no ship, R42.20)", source=e2, noise=NONE),
    L(round=42, stream="engage", item="E2 --attack-shot-suppress", commit="dcf83c66a",
      line="reported (the guards' reads, not judged on an inconclusive bar): all stuck crew-s, first hit, deaths, hits, lines a tick",
      form="reported", n=E2_N, rule="-", base="stuck 20.2; first hit 8.05 s; deaths 59; hits 6546; lines a tick 3.07",
      arm="stuck 6.5; first hit 8.03 s; deaths 59; hits 6552; lines a tick 3.07 (seed 9695: stuck 13.8 -> 0.1 s, first hit 25.9 -> 21.5 s)",
      verdict="REPORTED", source=e2, noise=NONE),
]

# ---------------------------------------------------------------- Bar B7, the CPU counter-lineup (balance) ---------------
b7 = (src42 + " Bars 'Bar B7' (FILED fa9006e69; amended by R42.3 before any read: per faction) and Rulings 'R42.21 ... Bar B7 PASSES for "
      "Condemned and Gangs; ... Syndicate ... FAIL'; frozen fb9e2a95a (green builder0 3298/0); verdict logs references/round42/balance/"
      "bar-b7-verdict-{as-run,g3-fixed}.log")
B7_N = "9901-9940 x 4 factions x Green/Rust x one arena a seed, 320 fights an arm, paired, n 80 a faction, se by seed bootstrap"
LINES += [
    L(round=42, stream="balance", item="B7 --cpu-counter", commit="fb9e2a95a",
      line="DECIDING (per faction, R42.3): Condemned all-tanks win share ARM <= 60 % AND paired change < 0 by >= 2 se", form="share",
      n=B7_N, rule="<= 60 %; -2 se", base="75 %", arm="46 % (-28.8, se 7.5)", verdict="PASS (ships ON for Condemned)", source=b7,
      machine="builder2", noise=gain(7.5, -28.8, k=2.0)),
    L(round=42, stream="balance", item="B7 --cpu-counter", commit="fb9e2a95a",
      line="DECIDING: Gangs all-tanks win share ARM <= 60 % AND paired change < 0 by >= 2 se", form="share", n=B7_N,
      rule="<= 60 %; -2 se", base="76 %", arm="60 % (-16.2, se 6.9; at the 60 % line)", verdict="PASS (ships ON for Gangs)", source=b7,
      machine="builder2", noise=gain(6.9, -16.2, k=2.0)),
    L(round=42, stream="balance", item="B7 --cpu-counter", commit="fb9e2a95a",
      line="DECIDING: Syndicate all-tanks win share ARM <= 60 % AND paired change < 0 by >= 2 se", form="share", n=B7_N,
      rule="<= 60 %; -2 se", base="92 %", arm="78 % (-15.0, se 4.6: the drop clears 2 se, the share misses the 60 % line by 18)",
      verdict="FAIL (Syndicate's counter stays OFF)", source=b7, machine="builder2", noise=up(4.6, 78.0 - 60.0, k=2.0)),
    L(round=42, stream="balance", item="B7 --cpu-counter", commit="fb9e2a95a",
      line="reported: Law (not firing, R42.9) and the pooled shares", form="reported", n=B7_N, rule="-",
      base="Law 91 %; firing factions pooled 81 %; all four 84 %", arm="Law 91 %; pooled 61 %; all four 69 %; fires 80/80 a firing "
      "faction, 0/80 Law", verdict="REPORTED", source=b7, machine="builder2", noise=NONE),
    L(round=42, stream="balance", item="B7 --cpu-counter", commit="fb9e2a95a",
      line="G1: CPU v CPU plain deal mirrored, GUARD_RESULT identical ON v OFF", form="deterministic", n="9901-9910 terminus, 40 fights",
      rule="40/40 identical", base="-", arm="40/40 identical", verdict="PASS", source=b7, machine="builder2", noise=DET),
    L(round=42, stream="balance", item="B7 --cpu-counter", commit="fb9e2a95a",
      line="G2: fight length median within +/-20 %", form="median", n=B7_N, rule="+/-20 %", base="-", arm="-1.2 % / -3.5 %",
      verdict="PASS", source=b7, machine="builder2", noise=band(20.0, -3.5)),
    L(round=42, stream="balance", item="B7 --cpu-counter", commit="fb9e2a95a",
      line="G3: 0 load errors, every countered army within the fielded cap (ARMY_CAP_FIELDED = Army.MAX_ARMY_UNITS 45)",
      form="deterministic", n="320 armies loaded", rule="0 over 45", base="OFF's own rolls reach 45",
      arm="0 over 45 (largest 44); the as-run judge compared against units=25 and printed FAIL 134/320, read as filed (lesson 318)",
      verdict="PASS", source=b7, machine="builder2", noise=DET),
    L(round=42, stream="balance", item="B7 --cpu-counter", commit="fb9e2a95a",
      line="G4: test_army_counter + test_tactics_mono_army green; the ship commit's full check", form="deterministic",
      n="b3841b301 builder0 check", rule="green", base="-", arm="exited 0, 3299 passed / 0 failed", verdict="PASS", source=b7, noise=DET),
]

# ---------------------------------------------------------------- B8, Law's and Syndicate's artillery (balance): DEV read -
b8 = src42 + " Rulings 'R42.9 ... B8: +/-15 % on Law's and Syndicate's artillery doesn't change who wins; no Bar B8' (dev screen, never a bar)"
B8_N = "9d8e26e44, 10201-10220 x 5 arenas x mono on both teams, n 200 an arm, guard none, paired"
LINES += [
    L(round=42, stream="balance", item="B8 artillery +/-15 % (dev)", commit="9d8e26e44",
      line="dev: all-tanks win share v Law's barrage lineup with the Gas Rocket Truck damage +15 % / cost -15 % (each alone); the "
      "counter fires for a faction only if ON <= OFF - 2 se here (R42.3)", form="share", n=B8_N, rule="-2 se to fire",
      base="96 %", arm="92 % each (paired -5, se 3)", verdict="REPORTED (dev; Law's counter does not fire)", source=b8,
      machine="builder2", noise=gain(3.0, -5.0, k=2.0)),
    L(round=42, stream="balance", item="B8 artillery +/-15 % (dev)", commit="9d8e26e44",
      line="dev: all-tanks win share v the Syndicate's barrage lineup with the Missile Ring cost -15 % + hull/shield +15 %",
      form="share", n=B8_N, rule="-2 se to fire", base="84 %", arm="86 % (+2, se 3)",
      verdict="REPORTED (dev; nothing ships)", source=b8, machine="builder2", noise=gain(3.0, 2.0, k=2.0)),
]

# ---------------------------------------------------------------- Bar B2s v2, the stat change re-read on fresh seeds (balance)
b2v2 = (src42 + " Bars 'Bar B2s v2' (FILED 8165a8830 round 40, R40.19; re-armed R42.15) and Rulings 'R42.23 ... Bar B2s v2 FAILS 17/18'; "
        "BASE c0b61be2e v ARM 7aceba95f (fm_c5r2_lawt5); verdict references/round42/balance/bar-b2s-v2-verdict.log")
b2v2n = "1600 fights an arm (8801-8840 + 8901-8940, 80/80 seeds, 0 lost), builder2 J24"
B2 = dict(round=42, stream="balance", item="B2s v2 fm_c5r2_lawt5", commit="7aceba95f", source=b2v2, machine="builder2")
LINES += [
    L(line="DECIDING flatness (RMS over 16 cells) down > 2 paired se", form="mean", n=b2v2n, rule="drop > 2 se", base="18.5",
      arm="11.6 (-6.93 +/- 2.00)", verdict="PASS", noise=gain(2.00, -6.93, k=2.0), **B2),
    L(line="DECIDING blob v a Gangs CPU toward the line mean", form="share", n="the cell's fights", rule="toward the mean", base="80 %",
      arm="54 %", verdict="PASS", noise=NONE, **B2),
    L(line="DECIDING blob v a Syndicate CPU toward the line mean", form="share", n="the cell's fights", rule="toward the mean",
      base="11 %", arm="42 %", verdict="PASS", noise=NONE, **B2),
    L(line="G1: blob line win rate not up > 2 se", form="share", n="800 fights", rule="<= base + 2 se", base="-",
      arm="-4.50 +/- 1.92", verdict="PASS", noise=up(1.92, -4.50, k=2.0), **B2),
    L(line="G2: turtle line win rate not up > 2 se", form="share", n="800 fights", rule="<= base + 2 se", base="-",
      arm="-1.62 +/- 1.31", verdict="PASS", noise=up(1.31, -1.62, k=2.0), **B2),
    L(line="G3: blob median length within +/-15 % (or <= 2 se)", form="median", n="800 fights", rule="+/-15 % or <= 2 se", base="-",
      arm="+5.82 % +/- 2.06", verdict="PASS", noise=se_line(2.06, 15.0, 15.0 - 5.82), **B2),
    L(line="G3: blob median length a guard faction within +/-20 % (or <= 2 se)", form="median", n="190-210 fights a faction",
      rule="+/-20 % or <= 2 se", base="-", arm="Condemned +5.44 +/- 4.67; Gangs +12.40 +/- 5.37; Law +5.82 +/- 3.61; Syndicate -10.34 +/- 3.82",
      verdict="PASS", noise=se_line(5.37, 20.0, 20.0 - 12.40, "the Gangs cell, the closest"), **B2),
    L(line="G3: turtle median length within +/-15 % (or <= 2 se)", form="median", n="800 fights", rule="+/-15 % or <= 2 se", base="-",
      arm="+0.26 % +/- 0.15", verdict="PASS", noise=se_line(0.15, 15.0, 15.0 - 0.26), **B2),
    L(line="G3: turtle median length a guard faction within +/-20 % (or <= 2 se): Gangs", form="median", n="210 fights",
      rule="+/-20 % or <= 2 se", base="-", arm="+20.75 % +/- 7.71 (0.75 over, inside one se)",
      verdict="FAIL (the bar fails 17/18; fm_c5r2_lawt5 stays unshipped, R42.23)", noise=se_line(7.71, 20.0, 20.0 - 20.75), **B2),
    L(line="G3: turtle median length a guard faction within +/-20 %: Condemned / Law / Syndicate", form="median",
      n="190-210 fights a faction", rule="+/-20 % or <= 2 se", base="-",
      arm="Condemned +0.05 +/- 0.14; Law +0.34 +/- 0.24; Syndicate -18.20 +/- 12.20", verdict="PASS",
      noise=se_line(12.20, 20.0, 20.0 - 18.20, "the Syndicate cell, the closest"), **B2),
    L(line="G4: time-cap share not up > 2 se", form="share", n=b2v2n, rule="<= base + 2 se", base="-", arm="-0.06 +/- 0.21",
      verdict="PASS", noise=up(0.21, -0.06, k=2.0), **B2),
    L(line="G5: none-line flatness not worse > 2 se", form="mean", n="200 fights (none line, one side)", rule="<= base + 2 se",
      base="-", arm="-17.74 +/- 5.16", verdict="PASS", noise=up(5.16, -17.74, k=2.0), **B2),
    L(line="G6: perf-judge (read from the ARM's check)", form="deterministic", n="the ARM's builder0 check", rule="PASS", base="-",
      arm="PASS", verdict="PASS", noise=DET, **{k: v for k, v in B2.items() if k != "machine"}),
    L(line="G7: full check, the sim baseline adopted on purpose; bridge-pooled is the ship gate, not the bar's (R42.15)",
      form="deterministic", n="ARM's check (3300/0)", rule="green but sim-baseline", base="-",
      arm="exited 2: sim-baseline (expected) and bridge-pooled (the drill crew rust s2 t15, CP42.1 not reached)", verdict="PASS",
      noise=DET, **{k: v for k, v in B2.items() if k != "machine"}),
    L(line="G8: mono-tank line win share not up > 2 se", form="share", n="800 fights", rule="<= base + 2 se", base="-",
      arm="-1.62 +/- 0.92", verdict="PASS", noise=up(0.92, -1.62, k=2.0), **B2),
]

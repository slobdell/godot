#!/usr/bin/env python3
"""Every judged bar line of round 38, as data (round 40 native, close step 5b owed since round 37).

The same fields, helpers and noise kinds as `lines_r31_34.py` (read its docstring). Every quoted number is the streams' own,
from *Rulings (round 38)* in `_agents/workstreams.md` (R38.4, .9, .12, .14, .15, .17, .24, .29, .33, .34, .36, .39, .41, .42,
.48, .51); nothing is re-measured. A line's noise is the se its ruling PRINTED (kind `se`; "-3.8 paired se" with its difference
gives se = |d| / 3.8); counts and per-cell lines with no se carry `none`. Doctrine judged at 2 paired se (k = 2).
"""
from lines_r31_34 import DET, L, gain, up, within  # noqa: F401

WS = "_agents/workstreams.md"
src38 = WS + " Round 38"
NONE = {"kind": "none"}
LINES = []

# ---------------------------------------------------------------- F3 repair under fire (feedback) ------------------------
f3 = src38 + " R38.4; f0ad5a44d, 320 paired guard fights"
LINES += [
    L(round=38, stream="feedback", item="F3 repair under fire", commit="f0ad5a44d", line="DECIDING gang hp mended a fight up",
      form="mean", n="320 paired guard fights (120 with gangs)", rule="up beyond 1.645 se", base="399.6", arm="556.5 (+157, se 50)",
      verdict="PASS (ships ON)", source=f3, machine="builder2", noise=gain(50.0, -157.0)),
    L(round=38, stream="feedback", item="F3 repair under fire", commit="f0ad5a44d", line="guard: turtle win rate not up",
      form="share", n="320 paired fights", rule="<= base + 1.645 se", base="40 %", arm="41 % (+1.2, se 0.9; McNemar p 0.94)",
      verdict="PASS", source=f3, machine="builder2", noise=up(0.9, 1.2)),
    L(round=38, stream="feedback", item="F3 repair under fire", commit="f0ad5a44d", line="guards: blob win rate; kills and median length per faction",
      form="share", n="320 paired fights", rule="flat", base="blob 49 %; gangs blob kills 51.0, length 102 s", arm="48 %; 51.2; 99 s",
      verdict="PASS", source=f3, machine="builder2", noise=NONE),
]

# ---------------------------------------------------------------- S1 / S2 deploy fit and latch (settle) ------------------
s9 = src38 + " R38.9; e42ff30eb, 12 cells x 3861-3872"
s15 = src38 + " R38.15; cbb2ece52, references/round38/settle/s2-reread-judged-builder2-cbb2ece52/"
s17 = src38 + " R38.17; cbb2ece52, references/round38/settle/s1v2-judged-builder2-cbb2ece52/"
s33 = src38 + " R38.33; fac47b5d2, references/round38/settle/s2v4-judged-builder2-fac47b5d2"
s34 = src38 + " R38.34; 4ec06dd97, references/round38/settle/s1v3-judged-builder2-4ec06dd97"
s36 = src38 + " R38.36; fdeb18ce6, seeds 4401-4424"
s42 = src38 + " R38.42; b3ad7baa4, references/round38/settle/hs3-judged-builder0-b3ad7baa4/"
LINES += [
    L(round=38, stream="settle", item="S1 DEPLOY_FIT", commit="e42ff30eb", line="DECIDING squads with a crew moved >= 25 m <= 50 % of base",
      form="total", n="576 squads an arm", rule="<= 83", base="166", arm="125 (-25 %)", verdict="FAIL", source=s9, machine="builder2", noise=NONE),
    L(round=38, stream="settle", item="S1 DEPLOY_FIT", commit="e42ff30eb", line="guard: never-in no more (locks 3 route)",
      form="count-cells", n="12 seeds a cell", rule="<= base", base="1", arm="2 (s3871 squad 1)", verdict="FAIL", source=s9, machine="builder2", noise=NONE),
    L(round=38, stream="settle", item="S2 DEPLOY_LATCH", commit="e42ff30eb", line="DECIDING shape flips no-fight and fight <= 25 % of base",
      form="total", n="576 squads an arm", rule="<= 25 % (+1)", base="58; 37", arm="0; 0 (reseats 124 -> 0)", verdict="PASS", source=s9,
      machine="builder2", noise=NONE),
    L(round=38, stream="settle", item="S2 DEPLOY_LATCH", commit="e42ff30eb", line="guard: never-in no more (crossing 5 click)",
      form="count-cells", n="12 seeds a cell", rule="<= base", base="0", arm="1 (s3866 squad 4)", verdict="FAIL (traced: a spot 0.4 m from a parked tank)",
      source=s9, machine="builder2", noise=NONE),
    L(round=38, stream="settle", item="S2 re-read", commit="cbb2ece52", line="DECIDING shape flips; never-in fresh <= main and pooled <= main + 1",
      form="total", n="576 squads an arm, 3903-3914", rule="as filed", base="no-fight 56, fight 107; never-in fresh 9, pooled 15",
      arm="0, 0; fresh 8, pooled 15 (read as main v latch)", verdict="PASS", source=s15, machine="builder2", noise=NONE),
    L(round=38, stream="settle", item="S2 re-read", commit="cbb2ece52", line="guard: first shape differs <= 3 % of squads",
      form="total", n="576 squads", rule="<= 17.3", base="-", arm="18", verdict="FAIL (by one squad)", source=s15, machine="builder2", noise=NONE),
    L(round=38, stream="settle", item="S1 v2", commit="cbb2ece52", line="DECIDING squads with a deploy leg >= 25 m <= 50 % of base",
      form="total", n="573 deploys, 3921-3944", rule="<= 28", base="56", arm="10", verdict="PASS", source=s17, machine="builder2", noise=NONE),
    L(round=38, stream="settle", item="S1 v2", commit="cbb2ece52", line="guard: never-in no more",
      form="count-cells", n="fresh seeds", rule="<= base", base="1", arm="2 (crossing 5 route s3931 squad 4)", verdict="FAIL", source=s17,
      machine="builder2", noise=NONE),
    L(round=38, stream="settle", item="S2 v4 latch anchor", commit="fac47b5d2", line="DECIDING shape flips no-fight <= 13.8, fight <= 9.2; reseats",
      form="total", n="576 squads an arm, 4301-4324", rule="as filed", base="51; 33; reseats 89", arm="0; 0; 0", verdict="PASS (ships ON)",
      source=s33, machine="builder2", noise=NONE),
    L(round=38, stream="settle", item="S2 v4 latch anchor", commit="fac47b5d2", line="guards: never-in, per-cell probe guards, contacts, fights, census",
      form="total", n="576 squads; fights n 36 + 36", rule="as filed", base="never-in 5; contacts 12,435; census 701", arm="5; 11,762; 701",
      verdict="PASS", source=s33, machine="builder2", noise=NONE),
    L(round=38, stream="settle", item="S1 v3", commit="4ec06dd97", line="DECIDING deploy leg >= 25 m squads <= 50 % of base",
      form="total", n="570 deploys, 4201-4224", rule="<= 28.5", base="57", arm="18", verdict="PASS", source=s34, machine="builder2", noise=NONE),
    L(round=38, stream="settle", item="S1 v3", commit="4ec06dd97", line="guards: twitch >= 15 m, never-in, first shape, contacts, fights",
      form="total", n="576 squads; fights n 36 + 36", rule="as filed", base="twitch 111; never-in 5; contacts 12,652",
      arm="79; 4; first shape 10/576; 12,025", verdict="PASS", source=s34, machine="builder2", noise=NONE),
    L(round=38, stream="settle", item="S1 v4 (S1 on the latch-ON base)", commit="fdeb18ce6", line="guard: never-in no more",
      form="count-cells", n="576 squads an arm, 4401-4424", rule="<= base", base="3", arm="4 (terminus 5 route s4410 squad 5)",
      verdict="FAIL (S1 stays OFF)", source=s36, machine="builder2", noise=NONE),
    L(round=38, stream="settle", item="H held v latch", commit="b3ad7baa4", line="DECIDING re-deals <= line",
      form="total", n="3 cells x 3 squads x 3891-3902, n 36 an arm", rule="<= 51", base="85", arm="54", verdict="FAIL (narrow)", source=s42, noise=NONE),
    L(round=38, stream="settle", item="S3 o2 v held", commit="b3ad7baa4", line="DECIDING off_idle a fight down",
      form="mean", n="n 36 an arm", rule="as filed", base="102.2 s", arm="31.0 s", verdict="PASS", source=s42, noise=NONE),
    L(round=38, stream="settle", item="S3 o2 v held", commit="b3ad7baa4", line="guards: re-deals <= line; his losses within +-1.645 se",
      form="total", n="n 36 an arm", rule="<= 62.4; two-sided", base="54; losses 7.94", arm="67; 7.03 (se 0.34)", verdict="FAIL", source=s42,
      noise=within(0.34, 7.03 - 7.94)),
]

# ---------------------------------------------------------------- G1 / G3 group click (orders) --------------------------
o12 = src38 + " R38.12; tree 4a765e6e2, references/round38/orders/g1-judged-builder0-4a765e6e2/"
o39 = src38 + " R38.39; df9abb922"
o51 = src38 + " R38.51; game ab31e9bc2, 5725a5a57"
LINES += [
    L(round=38, stream="orders", item="G1 (amended)", commit="4a765e6e2", line="DECIDING places outside, metres outside, re-dealt, contacts",
      form="total", n="3881-3892, n 12 a cell", rule="as filed", base="84; 6,223 m; 58; 14,004", arm="18 (line 21); 1,393 (line 3,111); 0; 10,622",
      verdict="PASS", source=o12, noise=NONE),
    L(round=38, stream="orders", item="G1 (amended)", commit="4a765e6e2", line="guards: twitch per cell (crossing 3 route; his 3 click); yard_open identical",
      form="deterministic", n="12 seeds a cell", rule="<= base + 3 m; identical", base="5.8; 2.3; 192/192", arm="10.5; 11.4; 177/192",
      verdict="FAIL", source=o12, noise=DET),
    L(round=38, stream="orders", item="G3 place-clear", commit="a67afc951", line="DECIDING close pairs <= line; offsets",
      form="total", n="4101-4112, n 12 a cell, 18 cells", rule="<= 13.0", base="52", arm="4; 0/864 > 40 m further", verdict="PASS", source=o39, noise=NONE),
    L(round=38, stream="orders", item="G3 place-clear", commit="a67afc951", line="guards: never-in; twitch (crossing 5 click, his 5 click)",
      form="deterministic", n="12 seeds a cell", rule="no worse; <= base + 3 m", base="3; 20.4; 13.8", arm="4; 26.4; 26.0",
      verdict="FAIL", source=o39, noise=DET),
    L(round=38, stream="orders", item="G1 v3", commit="b55757fee", line="DECIDING places outside, metres outside, re-dealt",
      form="total", n="3951-3962, n 12 a cell", rule="as filed", base="99; 6,567 m; 71", arm="18 (line 24.8); 1,233 (line 3,283); 0",
      verdict="PASS", source=o39, noise=NONE),
    L(round=38, stream="orders", item="G1 v3", commit="b55757fee", line="guard: never-in no more (crossing 5 route; locks 3 click)",
      form="count-cells", n="12 seeds a cell", rule="<= base", base="1; 0", arm="2 (s3951 squad 5); 1 (s3960 squad 3)", verdict="FAIL",
      source=o39, noise=NONE),
    L(round=38, stream="orders", item="G3 v5", commit="5725a5a57", line="DECIDING pairs < 12 m",
      form="total", n="5201-5212, n 12, 18 cells", rule="as filed", base="48", arm="3", verdict="PASS", source=o51, noise=NONE),
    L(round=38, stream="orders", item="G3 v5", commit="5725a5a57", line="guard: twitch crossing 3 route <= base + 3 m",
      form="deterministic", n="12 seeds", rule="<= 8.5", base="5.5", arm="8.8 (squad 2 16-23 m on 5 seeds)", verdict="FAIL", source=o51, noise=DET),
    L(round=38, stream="orders", item="G1 v4", commit="5725a5a57", line="DECIDING places outside <= 20.5; route_left_m <= 2,487",
      form="total", n="4701-4712, n 12, 14 cells + yard_open", rule="as filed", base="82; 4,974", arm="20; 1,328", verdict="PASS", source=o51, noise=NONE),
    L(round=38, stream="orders", item="G1 v4", commit="5725a5a57", line="guard: never-in no more (crossing 3 click)",
      form="count-cells", n="12 seeds", rule="<= base", base="0", arm="1 (s4710 squad 2)", verdict="FAIL", source=o51, noise=NONE),
]

# ---------------------------------------------------------------- M5 v2 seatstep (manoeuvre) ----------------------------
m5 = src38 + " R38.24; ON 269d593c5 v BASE 226e4c190, references/round38/manoeuvre/m5-series/README.md"
LINES += [
    L(round=38, stream="manoeuvre", item="M5 v2 seatstep", commit="269d593c5", line="DECIDING seat metres down beyond 1.645 se",
      form="total", n="120 jam pairs", rule="drop > 4,881 m", base="76,032 m", arm="72,255 m (-5.0 %)", verdict="FAIL (stays OFF)", source=m5,
      noise=gain(4881.0 / 1.645, 72255.0 - 76032.0)),
    L(round=38, stream="manoeuvre", item="M5 v2 seatstep", commit="269d593c5", line="guards (a): kill share within 1.645 se; total deaths",
      form="share", n="120 jam pairs", rule="as filed", base="0.521", arm="0.527; deaths +6", verdict="PASS", source=m5, noise=NONE),
    L(round=38, stream="manoeuvre", item="M5 v2 seatstep", commit="269d593c5", line="guard (e): never-settled faced_attack_move <= the floor line",
      form="count", n="768 hull-rest runs an arm", rule="<= +3.3", base="-", arm="+4", verdict="FAIL", source=m5, noise=NONE),
]

# ---------------------------------------------------------------- D2 / D2b / D2c defend posture (doctrine) -------------
d14 = src38 + " R38.14; acbdef4c5, 320 fights paired with 1c484a525"
d29 = src38 + " R38.29; c475c3163, 4801-4808 + 4901-4908"
d41 = src38 + " R38.41; 5a9464679, 5001-5008 + 5101-5108"
LINES += [
    L(round=38, stream="doctrine", item="D2 CPU_DEFEND", commit="acbdef4c5", line="DECIDING blob win rate down > 2 paired se AND McNemar p < 0.05",
      form="share", n="320 fights an arm", rule="drop > 2 se", base="49 %", arm="44 % (-4.4, se 2.9; p 0.105)", verdict="FAIL (ships OFF)",
      source=d14, machine="builder2", noise=gain(2.9, -4.4, k=2.0)),
    L(round=38, stream="doctrine", item="D2 CPU_DEFEND", commit="acbdef4c5", line="guard: turtle-line kills a fight within 2 se",
      form="mean", n="320 fights", rule="within 2 se", base="32.4", arm="26.2 (-3.8 se)", verdict="FAIL", source=d14, machine="builder2",
      noise=within(6.2 / 3.8, -6.2, k=2.0)),
    L(round=38, stream="doctrine", item="D2b trigger", commit="c475c3163", line="DECIDING blob win rate down > 2 paired se AND McNemar p < 0.05",
      form="share", n="320 fights an arm, fresh seeds", rule="drop > 2 se", base="47 %", arm="44 % (0.9 se; p 0.22)", verdict="FAIL",
      source=d29, machine="builder2", noise=gain(3.0 / 0.9, -3.0, k=2.0, note="se from the rounded -3 points at 0.9 se")),
    L(round=38, stream="doctrine", item="D2b trigger", commit="c475c3163", line="G2t turtle kills a fight; G3 none median length <= x1.2",
      form="mean", n="320 fights", rule="within 2 se; <= x1.2", base="-; 130 s", arm="-1.94 (-2.8 se); 170 s (+31 %)", verdict="FAIL",
      source=d29, machine="builder2", noise=within(1.94 / 2.8, -1.94, k=2.0)),
    L(round=38, stream="doctrine", item="D2c SPLIT", commit="5a9464679", line="DECIDING blob win rate down > 2 paired se AND McNemar p < 0.05",
      form="share", n="320 fights an arm, fresh seeds", rule="drop > 2 se", base="51 %", arm="47 % (-4.4, se 3.8; p 0.13)", verdict="FAIL (ships OFF)",
      source=d41, machine="builder2", noise=gain(3.8, -4.4, k=2.0)),
    L(round=38, stream="doctrine", item="D2c SPLIT", commit="5a9464679", line="G1, G2t, G3 guards",
      form="share", n="320 fights", rule="as filed", base="turtle 39 %; none median 159 s", arm="35 %; turtle kills -0.56 (1.6 se); 168 s",
      verdict="PASS (every guard held)", source=d41, machine="builder2", noise=within(0.56 / 1.6, -0.56, k=2.0)),
    L(round=38, stream="doctrine", item="D3 rules / hulldown / package (a read)", commit="c475c3163", line="any arm moves a win rate by 2 se",
      form="share", n="320 fights an arm, paired with OFF", rule="-", base="blob 47 %", arm="rules 43 % (1.4 se); package 42 % (1.7 se)",
      verdict="REPORTED (R38.48: fight length moves, not results)", source=src38 + " R38.48", machine="builder2", noise=NONE),
]

#!/usr/bin/env python3
"""Every judged bar line of round 40, as data (round 40 native, close step 5b).

The same fields, helpers and noise kinds as `lines_r31_34.py` (read its docstring). Every quoted number is the streams' own,
from *Bars (round 40)* and *Rulings (round 40)* in `_agents/workstreams.md` (G3 v9's from orders' final report, round40/orders
`_agents/streams/orders.md`); nothing is re-measured. A line's noise is the se its verdict PRINTED (B2s's "d +/- se", M1 v2's and
M3's paired se); counts and cells with no se carry `none`. M1 v2, M3 and B2s judged at 2 paired se (k = 2); the rest are counts
against fixed lines.
"""
from lines_r31_34 import DET, L, gain, se_line, up  # noqa: F401

WS = "_agents/workstreams.md"
src40 = WS + " Round 40"
NONE = {"kind": "none"}
LINES = []

# ---------------------------------------------------------------- Bar T1, the deploy trigger (settle) ------------------
t1 = src40 + " Bars 'Bar T1 ... VERDICT PASS'; filed a03250e13, code afd436ca3"
LINES += [
    L(round=40, stream="settle", item="T1 --deploy-arrive=settled", commit="afd436ca3", line="DECIDING cap deploys <= 50 % of main, main >= 20",
      form="total", n="12 street cells x 8001-8012, 576 squads an arm + 36/36 fights", rule="<= 132.5", base="265", arm="83 (31 %)",
      verdict="PASS (ships ON = CP40.1)", source=t1, noise=NONE),
    L(round=40, stream="settle", item="T1 --deploy-arrive=settled", commit="afd436ca3",
      line="guards: arrival-to-deploy, never-in, all-in mean, twitch >= 15 m, places outside, flips, first shape, contacts, fights",
      form="total", n="576 squads + 36 fights an arm", rule="as filed", base="6.26 s; 3; 28.6 s; 113; 80; 0; -; 13,576",
      arm="4.42 s; 1; 29.0 s (<= 32.4); 110; 80; 0; 6/576; 13,394; fights within", verdict="PASS", source=t1, noise=NONE),
]

# ---------------------------------------------------------------- Bar M1 v2, give-way limit with release (manoeuvre) ----
m1 = src40 + " Bars 'Bar M1 v2 ... VERDICT FAIL on G5 alone'; 479bf90f9 (+ pair/native-chainrelease 18e5dbca8)"
LINES += [
    L(round=40, stream="manoeuvre", item="M1 v2 --giveway-chain=v2", commit="479bf90f9", line="DECIDING chained drift ON <= 0.5 x OFF and <= -2 se",
      form="total", n="36 census fights, 8101-8112", rule="<= 442.0 m and -2 se", base="884.0 m", arm="190.4 m (-78.5 %, -9.1 se)",
      verdict="PASS", source=m1, noise=gain((884.0 - 190.4) / 9.1, 190.4 - 884.0, k=2.0)),
    L(round=40, stream="manoeuvre", item="M1 v2 --giveway-chain=v2", commit="479bf90f9", line="G5: orders-probe never-in ON <= OFF",
      form="count-cells", n="144 probe runs, 8113-8124", rule="<= base", base="2",
      arm="5 (crossing 5 click s8120 sq4, locks 3 click s8119 sq1, terminus 5 route s8114 sq1, s8118 sq5, s8119 sq5)",
      verdict="FAIL (stays OFF)", source=m1, noise=NONE),
    L(round=40, stream="manoeuvre", item="M1 v2 --giveway-chain=v2", commit="479bf90f9",
      line="G1-G4, G6, G7: give-way / stuck deaths, contacts, kill share, all-in median, last squad in",
      form="total", n="36 fights + 144 runs", rule="as Bar M1; G7 paired mean <= +2.0 s", base="91; 242; 24,051",
      arm="86; 229 (line +33.5); 23,279; kill share 0.018; +0.0 s; +0.3 s", verdict="PASS", source=m1, noise=NONE),
]

# ---------------------------------------------------------------- Bar G1 v6 (orders) ------------------------------------
g1 = src40 + " Bars 'Bar G1 v6 ... VERDICT FAIL on one guard'; frozen c7d642aeb (= green 8bbafb376 + docs)"
LINES += [
    L(round=40, stream="orders", item="G1 v6 --group-sides=both", commit="c7d642aeb", line="DECIDING places outside (click, new corridor read)",
      form="total", n="8201-8212, n 12 a cell", rule="<= 16.2", base="65", arm="8 (old read 98 -> 17)", verdict="PASS",
      source=g1, machine="builder2", noise=NONE),
    L(round=40, stream="orders", item="G1 v6 --group-sides=both", commit="c7d642aeb", line="route_left; re-dealt; contacts; yard_open identical; never-in not up",
      form="total", n="12 seeds a cell", rule="as filed", base="3,864; 48; 14,781", arm="589; 0; 11,799; identical; not up",
      verdict="PASS", source=g1, machine="builder2", noise=NONE),
    L(round=40, stream="orders", item="G1 v6 --group-sides=both", commit="c7d642aeb", line="guard: terminus 5 route twitch (median of each run's worst) <= base + 3 m",
      form="median", n="12 seeds", rule="<= 23.6 m", base="20.6 m", arm="25.4 m (s8203/8205/8206/8208 differ)",
      verdict="FAIL (stays OFF)", source=g1, machine="builder2", noise=DET),
]

# ---------------------------------------------------------------- Bar S1 v3, per-crew corridors (settle) ----------------
s1 = src40 + " Bars 'Bar S1 v3 ... VERDICT FAIL on one guard'; afd436ca3's code frozen at 8ca1b1e31"
LINES += [
    L(round=40, stream="settle", item="S1 v3 --seat-route-clear=v3", commit="8ca1b1e31", line="DECIDING 5-squad never-in <= main - 1, main >= 2, none new",
      form="count-cells", n="8013-8024, 576 squads + 36/36 fights", rule="<= 3", base="4", arm="0, none new", verdict="PASS",
      source=s1, noise=NONE),
    L(round=40, stream="settle", item="S1 v3 --seat-route-clear=v3", commit="8ca1b1e31", line="guard: squads twitching >= 15 m not up",
      form="total", n="576 squads an arm", rule="<= 88", base="88", arm="99", verdict="FAIL (stays OFF)", source=s1, noise=NONE),
    L(round=40, stream="settle", item="S1 v3 --seat-route-clear=v3", commit="8ca1b1e31", line="guards: never-in all cells, all-in, flips, first shape, contacts, fights",
      form="total", n="576 squads + 36 fights", rule="as filed", base="5; 25.7 s; 0; -; 12,235", arm="0; 24.8 s; 0; 6/576; 11,418",
      verdict="PASS", source=s1, noise=NONE),
]

# ---------------------------------------------------------------- G3 v8 dev gate, Bar G3 v9 (orders) --------------------
g3v8 = src40 + " R40.13 (G3 v8 dev read FAILED); 5bc304738"
g3v9 = ("round40/orders _agents/streams/orders.md 'REPORT (2026-10-25): Bar G3 v9 FAILS'; " + src40 +
        " Bars 'Bar G3 v9' (filed 893180a31); references/round40/orders/g3v9-judged-builder0-893180a31/")
LINES += [
    L(round=40, stream="orders", item="G3 v8 (dev gate read)", commit="5bc304738", line="dev gate: pairs < 12 m <= 25 % of base before a bar",
      form="total", n="3804-3809, n 6 (dev)", rule="<= 6.2", base="25", arm="10 (the road test reads each road 17-20 m wide)",
      verdict="FAIL (dev gate; no bar filed)", source=g3v8, machine="builder2", noise=NONE),
    L(round=40, stream="orders", item="G3 v9 --place-clear-lane=column", commit="893180a31", line="DECIDING pairs < 12 m <= 25 % of base",
      form="total", n="8213-8224, n 12 a cell", rule="<= 12.0", base="48", arm="13 (12 main's own on crossing route; 1 new s8220)",
      verdict="FAIL (stays OFF)", source=g3v9, noise=NONE),
    L(round=40, stream="orders", item="G3 v9 --place-clear-lane=column", commit="893180a31", line="guard: never-in no more than base",
      form="count-cells", n="12 seeds a cell", rule="<= 5", base="5", arm="6 (crossing 5 click s8220 Delta)", verdict="FAIL",
      source=g3v9, noise=DET),
    L(round=40, stream="orders", item="G3 v9 --place-clear-lane=column", commit="893180a31", line="guards: offsets, contacts",
      form="total", n="12 seeds a cell", rule="as filed", base="contacts 15,046", arm="worst offset +24.0 m (0 of 864 > 40 m); 15,049",
      verdict="PASS", source=g3v9, noise=NONE),
]

# ---------------------------------------------------------------- Bar cap deal (settle) ---------------------------------
cd = src40 + " Bars 'Bar cap deal ... VERDICT FAIL'; gate and frozen tree 95276e979"
LINES += [
    L(round=40, stream="settle", item="cap deal --cap-deal=street", commit="95276e979", line="DECIDING 1: deploy legs >= 25 m <= 0.75 x main (main >= 20)",
      form="total", n="8725-8748, 576 squads + 36/36 fights a read", rule="<= 44.2", base="59", arm="45 (-24 %)",
      verdict="FAIL (stays OFF)", source=cd, machine="builder2", noise=NONE),
    L(round=40, stream="settle", item="cap deal --cap-deal=street", commit="95276e979", line="DECIDING 2: twitch >= 15 m <= main",
      form="total", n="576 squads", rule="<= 99", base="99", arm="92", verdict="PASS", source=cd, machine="builder2", noise=NONE),
    L(round=40, stream="settle", item="cap deal --cap-deal=street", commit="95276e979",
      line="guards: never-in, all-in, places outside, flips, contacts, six fight guards",
      form="total", n="576 squads + 36 fights", rule="as filed", base="7; 26.7 s; 100; 0", arm="6 (none new); 26.0 s; 100; 0; all pass",
      verdict="PASS", source=cd, machine="builder2", noise=NONE),
]

# ---------------------------------------------------------------- Bar M3, wedge re-route (manoeuvre) --------------------
m3 = src40 + " Bars 'Bar M3 ... VERDICT FAIL on D'; code b21565b37, series 8c8d9035b (GDScript drive both arms)"
LINES += [
    L(round=40, stream="manoeuvre", item="M3 --giveway-reroute=any", commit="b21565b37", line="DECIDING long-episode seconds ON <= 0.8 x OFF at >= 2 se",
      form="total", n="36 paired fights, 8601-8612", rule="<= 435.3 s", base="544.1 s",
      arm="554.0 s (+1.8 %; paired +0.28 s a fight, se 5.83)", verdict="FAIL (stays OFF)", source=m3,
      noise=gain(5.83, 0.28, k=2.0)),
    L(round=40, stream="manoeuvre", item="M3 --giveway-reroute=any", commit="b21565b37",
      line="G1-G7: give-way / stuck deaths, contact ticks, kill share, deaths, never-in, all-in / last-in",
      form="total", n="36 fights + 144 probe runs (8613-8624)", rule="as filed", base="84; 248; 829,543; deaths 1,458; never-in 3",
      arm="87; 213; 820,818; kill share 0.028; 1,435; 3; +0.0 s", verdict="PASS", source=m3, noise=NONE),
]

# ---------------------------------------------------------------- Bar B2s, the stat change (balance) --------------------
b2 = src40 + " R40.19 (+ its full verdict); BASE 5be511659 v ARM 66c4839a2 (fm_law_c5r2); Bars 'Bar B2s'"
b2n = "1600 fights an arm (8301-8340 + 8401-8440, 80/80 seeds)"
LINES += [
    L(round=40, stream="balance", item="B2s fm_law_c5r2", commit="66c4839a2", line="DECIDING flatness (RMS over 16 cells) down > 2 paired se",
      form="mean", n=b2n, rule="drop > 2 se", base="18.5", arm="8.9 (-9.6 +/- 2.2)", verdict="PASS", source=b2, machine="builder2",
      noise=gain(2.2, -9.6, k=2.0)),
    L(round=40, stream="balance", item="B2s fm_law_c5r2", commit="66c4839a2", line="G1: blob line win rate not up > 2 se",
      form="share", n=b2n, rule="<= base + 2 se", base="41 %", arm="35 % (-6.4 +/- 2.2)", verdict="PASS", source=b2, machine="builder2",
      noise=up(2.2, -6.4, k=2.0)),
    L(round=40, stream="balance", item="B2s fm_law_c5r2", commit="66c4839a2", line="G2: turtle line win rate not up > 2 se",
      form="share", n=b2n, rule="<= base + 2 se", base="34 %", arm="34 % (+0.4 +/- 1.4)", verdict="PASS", source=b2, machine="builder2",
      noise=up(1.4, 0.4, k=2.0)),
    L(round=40, stream="balance", item="B2s fm_law_c5r2", commit="66c4839a2", line="G3: median length a line within +/-15 % (or <= 2 se)",
      form="median", n=b2n, rule="+/-15 % or <= 2 se", base="-", arm="blob +10.4 % +/- 2.3", verdict="PASS", source=b2, machine="builder2",
      noise=se_line(2.3, 15.0, 15.0 - 10.4)),
    L(round=40, stream="balance", item="B2s fm_law_c5r2", commit="66c4839a2", line="G3: median length a guard faction within +/-20 % (or <= 2 se)",
      form="median", n=b2n, rule="+/-20 % or <= 2 se", base="-", arm="Law blob cell +24.6 % +/- 3.6", verdict="FAIL (the bar fails; fm_law_c5r2 stays OFF)",
      source=b2, machine="builder2", noise=se_line(3.6, 20.0, 20.0 - 24.6)),
    L(round=40, stream="balance", item="B2s fm_law_c5r2", commit="66c4839a2", line="G4: time-cap share not up > 2 se",
      form="share", n=b2n, rule="<= base + 2 se", base="-", arm="+0.06 +/- 0.18", verdict="PASS", source=b2, machine="builder2",
      noise=up(0.18, 0.06, k=2.0)),
    L(round=40, stream="balance", item="B2s fm_law_c5r2", commit="66c4839a2", line="G5: none-line flatness not worse > 2 se",
      form="mean", n="100 fights (none line, one side)", rule="<= base + 2 se", base="-", arm="-4.89 +/- 3.91", verdict="PASS",
      source=b2, machine="builder2", noise=up(3.91, -4.89, k=2.0)),
    L(round=40, stream="balance", item="B2s fm_law_c5r2", commit="66c4839a2", line="G6: perf-judge",
      form="deterministic", n="the judged run", rule="PASS", base="-", arm="PASS", verdict="PASS", source=b2, noise=DET),
    L(round=40, stream="balance", item="B2s fm_law_c5r2", commit="66c4839a2", line="G7: full check, the sim baseline adopted on purpose",
      form="deterministic", n="ARM's check (3212/0)", rule="green but sim-baseline (recorded twice, agreeing)", base="-",
      arm="green but sim-baseline (13 maps moved)", verdict="PASS", source=b2, noise=DET),
    L(round=40, stream="balance", item="B2s fm_law_c5r2", commit="66c4839a2", line="G8: mono-tank line win share not up > 2 se",
      form="share", n="800 fights", rule="<= base + 2 se", base="-", arm="-1.38 +/- 1.20 (mono wins 84 %)", verdict="PASS",
      source=b2, machine="builder2", noise=up(1.20, -1.38, k=2.0)),
]

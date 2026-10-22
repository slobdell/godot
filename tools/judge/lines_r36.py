#!/usr/bin/env python3
"""Every judged bar line of round 36, as data (round 37 native N6: the re-render round 36's close skipped, close step 5b).

The same fields, helpers and noise kinds as `lines_r31_34.py` (read its docstring). Every quoted number is the streams' own,
from *Bars (round 36)* and *Rulings (round 36)* in `_agents/workstreams.md` (R36.2 / R36.6 / R36.8 / R36.23 / R36.27 / R36.32);
nothing is re-measured. Round 36's series kept their rows on stream branches (`round36/*`), so a line's noise is the se or the
bound its ruling PRINTED (kind `se`; a bound quoted alone gives se = bound / k).
"""
from lines_r31_34 import DET, K, L, gain, limit, se_line, up  # noqa: F401

WS = "_agents/workstreams.md"
src36 = WS + " Round 36"
LINES = []

# ---------------------------------------------------------------- X3b DEPLOY_PASS (orders) ------------------------------
x3b = src36 + " Bars 'X3b DEPLOY_PASS'; R36.2; references/round36/orders/x3b-lab-builder0-61b6181e2/"
LINES += [
    L(round=36, stream="orders", item="X3b DEPLOY_PASS", commit="61b6181e2", line="workload exists: >= 3 jam cells of 32 (off all-in >= nostep + 3 s)",
      form="count-cells", n="32 fixed cells x {off, on, nostep}", rule=">= 3 of 32", base="-", arm="0 of 32",
      verdict="NULL (no workload: the precondition the bar named was not met; closed, DEPLOY_PASS deleted)", source=x3b, noise=DET),
]

# ---------------------------------------------------------------- O2 DEPLOY_COMPACT (orders) ----------------------------
o2 = src36 + " Bars 'O2 DEPLOY_COMPACT'; R36.6; stream/orders 1bcd704cd compact_judge.py"
LINES += [
    L(round=36, stream="orders", item="O2 DEPLOY_COMPACT", commit="1bcd704cd", line="GAIN (a) median worst deploy leg >= 20 % lower",
      form="median", n="12 street cells x 3681-3686 (576 squad rows)", rule="<= 10.7 m", base="13.4 m", arm="11.4 m (-14.9 %)",
      verdict="FAIL", source=o2, noise={"kind": "none", "note": "medians per cell; no se printed"}),
    L(round=36, stream="orders", item="O2 DEPLOY_COMPACT", commit="1bcd704cd", line="GAIN (b) summed median twitch >= 15 % lower",
      form="total", n="12 cells x 6 seeds", rule="<= 143.4 m", base="168.7 m", arm="177.0 m (+4.9 %)", verdict="FAIL", source=o2,
      noise={"kind": "none", "note": "sum of cell medians; no se printed"}),
    L(round=36, stream="orders", item="O2 DEPLOY_COMPACT", commit="1bcd704cd", line="guards per cell: twitch <= main + 3 m; never-in no more",
      form="deterministic", n="12 cells", rule="as filed", base="-", arm="Crossing 5 click 29.8 -> 34.1, Terminus 5 route 18.6 -> 29.7; never-in 1 -> 2",
      verdict="FAIL", source=o2, noise=DET),
    L(round=36, stream="orders", item="O2 DEPLOY_COMPACT", commit="1bcd704cd", line="own-squad closest crews at the end >= 9 m centre to centre (orchestrator's)",
      form="deterministic", n="12 cells", rule=">= 9 m every cell", base="3.8-8.6 m (main fails it too)", arm="-",
      verdict="NOT READABLE (ill-posed: read at the window's end it fails main; R36.6)", source=o2, noise=DET),
]

# ---------------------------------------------------------------- T8 (traffic) ------------------------------------------
t8 = src36 + " R36.8; stream/traffic references/round36/traffic/t8_series_a2de32420/"
LINES += [
    L(round=36, stream="traffic", item="T8 hold release", commit="a2de32420", line="G DECIDING deaths while held (held_3s): arm < base by more than 1.645 se",
      form="total", n="140 fights paired (5 fixed arenas x 1800-1827)", rule="drop > 1.645 se", base="253", arm="109 (se 21.3, 6.8 se)",
      verdict="PASS", source=t8, machine="builder2", noise=gain(21.3, 109.0 - 253.0)),
    L(round=36, stream="traffic", item="T8 hold release", commit="a2de32420", line="guard: jam deaths <= base + 1.645 se",
      form="total", n="140 fights paired", rule="<= 295.5", base="267", arm="278", verdict="PASS", source=t8, machine="builder2",
      noise=limit(295.5 - 267.0, 278.0 - 267.0)),
    L(round=36, stream="traffic", item="T8 hold release", commit="a2de32420", line="guard: kills within +-86",
      form="total", n="140 fights paired", rule="+-86", base="5812", arm="5752 (-60)", verdict="PASS", source=t8, machine="builder2",
      noise=se_line(86.0 / K, 86.0, 86.0 - 60.0)),
    L(round=36, stream="traffic", item="T8 hold release", commit="a2de32420", line="guards: stuck, open, far loops, hit rate, friendly contacts, deaths a team, crossing arrivals",
      form="total", n="140 fights paired", rule="<= base + 1.645 se each", base="stuck 871; open 4731; far loops 168",
      arm="stuck 812; open 4728; far loops 126; hit 0.725 -> 0.729; contacts +2.1 %; 180/180 arrivals", verdict="PASS", source=t8,
      machine="builder2"),
]

# ---------------------------------------------------------------- T10 seatyield + seathold (traffic) --------------------
t10 = src36 + " Bars 'T10'; R36.19 (resized), R36.23; stream/traffic 0ca19d829"
LINES += [
    L(round=36, stream="traffic", item="T10 seatyield + seathold", commit="0ca19d829", line="DECIDING away_m over restricted squads: drop > 1.645 se",
      form="total", n="24 fresh seeds 3641-3664 (940 of 1152 restricted squads)", rule="drop > 898 m", base="4129.8 m", arm="3551.4 m (drop 578.4, se 546.1)",
      verdict="FAIL", source=t10, machine="builder2", noise=gain(546.1, 3551.4 - 4129.8)),
    L(round=36, stream="traffic", item="T10 seatyield + seathold", commit="0ca19d829", line="guard: deploy_s <= base + 1.645 se",
      form="total", n="24 seeds", rule="<= 22711", base="22482", arm="22543", verdict="PASS (a failed bar's guards decide nothing)", source=t10,
      machine="builder2", noise=limit(22711.0 - 22482.0, 22543.0 - 22482.0)),
    L(round=36, stream="traffic", item="T10 seatyield + seathold", commit="0ca19d829", line="guards: arrivals, twitch_m",
      form="total", n="24 seeds", rule="no worse at 1.645 se", base="1144; 8025", arm="1147; 7527", verdict="PASS", source=t10, machine="builder2"),
]

# ---------------------------------------------------------------- S1 stallnet (manoeuvre) ---------------------------------
s1 = src36 + " Bars 'S1 stallnet'; R36.27; references/round36/manoeuvre/s1-series/ (f5d5e674e)"
LINES += [
    L(round=36, stream="manoeuvre", item="S1 stallnet", commit="78a93fdb4", line="DECIDING lab: pinch stage ON escapes <= 3.0 s, base never in 20 s",
      form="deterministic", n="the stage, both paths", rule="as filed", base="never", arm="escapes", verdict="PASS (the stage injects the pop)",
      source=s1, noise=DET),
    L(round=36, stream="manoeuvre", item="S1 stallnet", commit="78a93fdb4", line="guard: unstick fires <= base + 1.645 se",
      form="total", n="72 fight pairs (locks/terminus/sumps x 6240-6263)", rule="<= base + 15576", base="157717", arm="192380 (+34663)",
      verdict="FAIL", source=s1, noise=limit(15576.0, 34663.0)),
    L(round=36, stream="manoeuvre", item="S1 stallnet", commit="78a93fdb4", line="guard: team 0 kills >= base - 1.645 se",
      form="total", n="72 fight pairs", rule=">= base - 41.8", base="1607", arm="1557 (-50)", verdict="FAIL", source=s1,
      noise=se_line(41.8 / K, 41.8, 41.8 - 50.0)),
    L(round=36, stream="manoeuvre", item="S1 stallnet", commit="78a93fdb4", line="guards: (d) (e) (f) (i) (q) (r) (s), give-ways (hull-rest 6201-6232 x 4 x 6)",
      form="total", n="128 pairs a task; 72 fight pairs", rule="within 1.645 se each", base="-", arm="every other guard passes", verdict="PASS",
      source=s1),
]

# ---------------------------------------------------------------- S2a h1bside + yieldgap (manoeuvre) ----------------------
s2a = src36 + " Bars 'S2a h1bside'; R36.32; references/round36/manoeuvre/s2a-series/ (59dc89ba8)"
LINES += [
    L(round=36, stream="manoeuvre", item="S2a h1bside + yieldgap", commit="bf678480c", line="far loops <= base + 1.645 se (and down)",
      form="total", n="72 fight pairs + 128 hull-rest pairs a task", rule="bound 38.6", base="91", arm="35 (-56)", verdict="PASS",
      source=s2a, machine="builder2", noise=gain(38.6 / K, 35.0 - 91.0)),
    L(round=36, stream="manoeuvre", item="S2a h1bside + yieldgap", commit="bf678480c", line="guard: unstick fires in wedged episodes <= base + 1.645 se (rebuilt by seed, ruled)",
      form="total", n="72 fight pairs", rule="<= base + 1648", base="28415", arm="27223 (-1192)", verdict="PASS", source=s2a, machine="builder2",
      noise=limit(1648.0, -1192.0)),
    L(round=36, stream="manoeuvre", item="S2a h1bside + yieldgap", commit="bf678480c", line="guards: kills, deaths, hit rate both teams; (d) (e) (f) all 6 tasks",
      form="total", n="72 fight pairs; 128 pairs a task", rule="within 1.645 se each", base="-", arm="flat; pass", verdict="PASS",
      source=s2a, machine="builder2"),
    L(round=36, stream="manoeuvre", item="S2a h1bside + yieldgap", commit="bf678480c", line="player line: crews left > 25 m behind (paired)",
      form="count-runs", n="768 runs", rule="-", base="77", arm="65", verdict="REPORTED", source=s2a, machine="builder2"),
]

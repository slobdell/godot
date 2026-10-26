#!/usr/bin/env python3
"""Every judged bar line of rounds 27-34, as data (sizing S1; rounds 31-34 are in `lines_r31_34.py`, C35.9). Quoted
numbers are the streams' own, from the Bars blocks in `_agents/workstreams.md` (Round 27 / 28 / 29 / 30) and the tables
under `_agents/streams/references/`; the `noise` spec tells `inventory.py` how to read the line's noise from rows where
rows exist, or carries the se the table printed. Nothing here is re-measured; `inventory.py` reproduces the quoted
totals from the rows as a check.

Fields: round, stream, item, commit, line (the bar's words), form (total | mean | median | count-runs | count-cells |
count-crews | share | episodes | deterministic | reported), n, rule (the threshold as written), base, arm, verdict,
source. `noise` kinds:
  traffic   {base, arm, case, metric, stat: total|median|mean, x, pass_dir}   rows under references/round2x/traffic
  se        {se, x, clear}          an se the table printed, for the SUM over the paired runs
  fisher    {a, n1, c, n2}          two arms' counts of runs (a of n1 in the arm, c of n2 in the control)
  mcnemar   {b, c}                  paired cells: arm won where base lost (b) and the reverse (c)
  binom     {k, n, K}               one arm's count against a threshold K ("on side >= 12/18")
  poisson   {a, b, x}               two counts of episodes with no per-run rows
  aa        {swing, x}              an A/A swing measured on the same probe stands in for the se
  none      {}                      no noise estimate possible (deterministic cells; reported lines)
  jsonl     {base, arm, key, metric, x | x_se, pass_dir, where?}   two jsonl files paired on key fields (census, ApproachStage)
  terminus  {path, squad, metric, x | x_se, pass_dir}   a Terminus judged text (both formats, rows.terminus_rows)
  guard_line {path, tag, name, x_se, pass_dir}  a FIGHT_GUARD / PINNED line's printed base, new and paired se
  cells     {path, cell, metric, stat, x | x_share, pass_dir}   brains' gate-series cell, off v on per (seed, tick)
  arrive    {off, on, metric, stat, x_share, pass_dir}   the arrive series over the cells complete in both arms
  bridge108 {control, on}           his bridge 108 by bridge_verdict's rule, McNemar over the discordant cells
  m1_guard  {path, task, x | x_se, clear | diff}   the hull-rest guard: all-class se from the M1_CLASS lines
A line's margin may combine `x_share` of the base (`x_base: median` for the base median) and `x_se` se (round 30's
`<= 0.10 x base median + 1.645 se`); `where` filters jsonl rows ({"approach": "east"}).
`x` is the line's distance from "no change" in the stat's units (the guard's X, 25 % of base, ...); `clear` is how far
the observed value passed (+) or failed (-) the line, in the same units. Both are what "inside the noise" is judged on.
"""

R27 = "_agents/streams/references/round27/"
R28 = "_agents/streams/references/round28/"
R29 = "_agents/streams/references/round29/"
R30 = "_agents/streams/references/round30/"
WS = "_agents/workstreams.md"


def L(**kw):
    kw.setdefault("machine", "builder0")
    kw.setdefault("noise", {"kind": "none"})
    return kw


def T(base, arm, case, metric, stat, x, pass_dir, **kw):
    """A traffic-series line read from rows: pass_dir 'down' (a fall passes), 'up' (a rise passes), 'notup', 'notdown'."""
    return dict(kind="traffic", base=base, arm=arm, case=case, metric=metric, stat=stat, x=x, pass_dir=pass_dir, **kw)


CPT_B, CPT_A = R29 + "traffic/judged_base_3a94f38d_seeds131415.jsonl", R29 + "traffic/judged_hold_3a94f38d_seeds131415.jsonl"
T3_B, T3_A = R29 + "traffic/t3_judged_base_d9b3339c_seeds222324.jsonl", R29 + "traffic/t3_judged_arm_d9b3339c_seeds222324.jsonl"
V3_B, V3_A = R28 + "traffic/judged-jbase-672eb785-seeds456.jsonl", R28 + "traffic/judged-jv3-672eb785-seeds456.jsonl"
T1B_B, T1B_A = R28 + "traffic/t1b-cbase-474558f8-seeds101112.jsonl", R28 + "traffic/t1b-ct1b-474558f8-seeds101112.jsonl"
M1 = R29 + "manoeuvre/m1_judged.txt"

LINES = []

# ---------------------------------------------------------------- round 27 --------------------------------------
src27 = WS + " Round 27 Bars"
LINES += [
    L(round=27, stream="scout", item="CP-S v1", commit="main c37605f0 base", line="census gun on target +5 pts (2..5 with a note)",
      form="mean", n="12 seeds paired", rule=">= +5 pts", base="18.4 %", arm="18.8 % (+1.34)", verdict="FAIL",
      source=src27 + " 'CP-S v1 FAILED'", noise={"kind": "se", "se": 3.06, "x": 5.0, "clear": 1.34 - 5.0}),
    L(round=27, stream="scout", item="CP-S v2", commit="90413868", line="gun on target in reach during ENGAGE >= +5 pts outside 2 se",
      form="mean", n="21 seeds paired (13-36)", rule=">= +5 pts and > 2 se", base="-", arm="+16.14 pts", verdict="PASS",
      source=src27 + " 'CP-S v2 PASSED'", noise={"kind": "se", "se": 5.16, "x": 5.0, "clear": 16.14 - 5.0}),
    L(round=27, stream="scout", item="CP-S v2", commit="90413868", line="guard: all fight-s on target not worse beyond 2 se",
      form="mean", n="22 seeds", rule=">= -2 se", base="-", arm="+5.21 pts", verdict="PASS",
      source=src27, noise={"kind": "se", "se": 1.66, "x": 2 * 1.66, "clear": 5.21 + 2 * 1.66}),
    L(round=27, stream="scout", item="CP-S v2", commit="90413868", line="guard: fight-option enemy contacts not up beyond 2 se",
      form="mean", n="22 seeds", rule="<= +2 se", base="-", arm="-6.27/seed", verdict="PASS",
      source=src27, noise={"kind": "se", "se": 3.47, "x": 2 * 3.47, "clear": 6.27 + 2 * 3.47}),
    L(round=27, stream="scout", item="CP-S v2", commit="90413868", line="guard: in-reach ENGAGE share not down beyond 2 se",
      form="mean", n="22 seeds", rule=">= -2 se", base="-", arm="-3.42 pts", verdict="PASS (close)",
      source=src27, noise={"kind": "se", "se": 2.01, "x": 2 * 2.01, "clear": -3.42 + 2 * 2.01}),
    L(round=27, stream="scout", item="S4", commit="0b4c2879", line="gang_scout his case: contact runs -> 0 of 18 (partial >= -50 %)",
      form="count-runs", n="18 runs a case", rule="0/18", base="9/18", arm="0/18", verdict="PASS",
      source=src27 + " 'Scout S4 NOT SHIPPED'", noise={"kind": "fisher", "a": 0, "n1": 18, "c": 9, "n2": 18}),
    L(round=27, stream="scout", item="S4", commit="0b4c2879", line="crossing targets' standing shots (cross 5 m 0.52 -> 0.46; 10 m 0.63 -> 0.50): 3 of 5 scenario bars",
      form="share", n="18 runs a case", rule="5/5 bars", base="0.52 / 0.63", arm="0.46 / 0.50", verdict="FAIL",
      source=src27, noise={"kind": "none"}),
    L(round=27, stream="scout", item="S4", commit="0b4c2879", line="blind census seeds 37-60: contacts not worse beyond 2 se",
      form="mean", n="24 seeds (13 gang)", rule="<= +2 se", base="-", arm="+0.08/seed", verdict="PASS (no effect)",
      source=src27, noise={"kind": "se", "se": 0.66, "x": 2 * 0.66, "clear": -0.08 + 2 * 0.66}),
    L(round=27, stream="brains", item="B2 v3", commit="787cd2e4", line="arrive series: cells lost <= 1 (8 m line)",
      form="count-cells", n="100 cells paired, seeds 1-4", rule="<= 1 lost", base="86", arm="89 (4 lost)", verdict="FAIL",
      source=src27 + " 'B2 v3 FAILED'", noise={"kind": "mcnemar", "b": 7, "c": 4}),
    L(round=27, stream="brains", item="B2 v3", commit="787cd2e4", line="arrive series: median all_in_s <= +10 %",
      form="median", n="100 cells", rule="<= +10 %", base="-", arm="+13.4 %", verdict="FAIL", source=src27, noise={"kind": "none"}),
    L(round=27, stream="brains", item="B2 v4", commit="730788b1", line="arrive series fresh 5-8: cells lost <= 1",
      form="count-cells", n="100 cells", rule="<= 1 lost", base="83", arm="85 (4 gained, 2 lost)", verdict="FAIL",
      source=src27 + " 'B2 v4 FAILED'", noise={"kind": "mcnemar", "b": 4, "c": 2}),
    L(round=27, stream="brains", item="B2 v4", commit="730788b1", line="Sumps cell seed 1: arrives in >= 5 of 6 ticks",
      form="count-runs", n="6 ticks (and seeds 1-4: 24)", rule=">= 5/6", base="14/24", arm="21/24 (seed 1 t1 never)", verdict="FAIL",
      source=src27, noise={"kind": "fisher", "a": 21, "n1": 24, "c": 14, "n2": 24}),
    L(round=27, stream="brains", item="B2 v5", commit="3e54110e", line="arrive series fresh 9-12: arrivals >= main's, lost <= 1, median <= +10 %",
      form="count-cells", n="100 cells", rule=">= 88, <= 1 lost", base="88", arm="95 (8 gained, 1 lost), median +0.0 %", verdict="PASS",
      source=src27 + " 'B2 v5'", noise={"kind": "mcnemar", "b": 8, "c": 1}),
    L(round=27, stream="brains", item="B2 v5", commit="3e54110e", line="his bridge 108 <= 1 run a side worse",
      form="deterministic", n="108 cells", rule="= control", base="106", arm="106", verdict="PASS", source=src27, noise={"kind": "none"}),
    L(round=27, stream="brains", item="B2 v5", commit="3e54110e", line="CPU side arrive (seeds 9-10): reported",
      form="reported", n="50 cells", rule="-", base="43", arm="45 (2 lost)", verdict="REPORTED", source=src27, noise={"kind": "mcnemar", "b": 4, "c": 2}),
    L(round=27, stream="brains", item="live flank fix (1st stage)", commit="33bf5862", line="reached the side >= 12/18 (every arm 0/18, alive 0.00: unwinnable)",
      form="count-runs", n="18", rule=">= 12/18", base="0/18 clicked", arm="0/18", verdict="VOID (lesson 295)",
      source=src27 + " 'Live-flank fix: PARTIAL'", noise={"kind": "none"}),
    L(round=27, stream="brains", item="live flank fix (even stage)", commit="370fc64d", line="on side >= 12/18, fresh seeds 4-6",
      form="count-runs", n="18 an arm", rule=">= 12/18", base="0/18 (clicked 89 deg)", arm="0/18 (65 deg)", verdict="FAIL",
      source=src27 + " 'Live-flank fix PARKED FOR GOOD'", noise={"kind": "fisher", "a": 0, "n1": 18, "c": 0, "n2": 18}),
    L(round=27, stream="brains", item="live flank fix (even stage)", commit="370fc64d", line="kills >= control - 2; alive >= control - 0.5",
      form="mean", n="18", rule=">= -2 kills, >= -0.5 alive", base="B0 rule kills 15, alive 2.78", arm="kills 10, alive 1.83", verdict="FAIL",
      source=src27, noise={"kind": "none"}),
    L(round=27, stream="brains", item="B3 make-room", commit="main 3dc04293", line="arrive series fresh 13-16: 8 m line on v off (kept)",
      form="count-cells", n="100 cells paired", rule="not worse", base="93", arm="97 (gained 5, lost 1)", verdict="KEPT",
      source=src27 + " 'B3: make-room KEPT'", noise={"kind": "mcnemar", "b": 5, "c": 1}),
    L(round=27, stream="orders", item="O3 hull at rest", commit="9c6f3381", line="report: drawn v clicked hull medians per class (permutation p)",
      form="reported", n="313 crews a task an arm (144 runs)", rule="-", base="clicked", arm="drawn", verdict="REPORTED",
      source=R27 + "orders_hull_rest.txt", noise={"kind": "none"}),
]

# ---------------------------------------------------------------- round 28 --------------------------------------
src28 = WS + " Round 28 Bars"
for case, base_t, arm_t, pct in (("terminus/cross", 183, 199, "+8.7 %"), ("terminus/head", 871, 419, "-52 %"),
                                  ("yard_open/cross", 309, 205, "-34 %"), ("yard_open/head", 122, 118, "-3 %")):
    LINES.append(L(round=28, stream="traffic", item="T1 v3", commit="672eb785", line="%s fast friendly contacts down >= 25 %% (3 of 4 cases)" % case,
                   form="total", n="18 runs paired (seeds 4-6 x 6 ticks)", rule="<= -25 %", base=str(base_t), arm="%d (%s)" % (arm_t, pct),
                   verdict="PASS" if arm_t <= 0.75 * base_t else "FAIL", source=src28 + " 'Traffic T1 v3 FAILED'; " + R28 + "traffic/README.md",
                   noise=T(V3_B, V3_A, case, "fast", "total", 0.25 * base_t, "down")))
for case in ("terminus/cross", "terminus/head", "yard_open/cross", "yard_open/head"):
    LINES.append(L(round=28, stream="traffic", item="T1 v3", commit="672eb785", line="%s all-in median <= base + 20 %%" % case,
                   form="median", n="18 runs paired", rule="<= +20 %", base="(rows)", arm="(rows; worst case +19.9 %)", verdict="PASS",
                   source=src28, noise=T(V3_B, V3_A, case, "allin", "median", None, "notup", x_share=0.20)))
    LINES.append(L(round=28, stream="traffic", item="T1 v3", commit="672eb785", line="%s crews in >= base - 2" % case,
                   form="total", n="18 runs paired", rule=">= -2", base="(rows)", arm="(rows)", verdict="PASS",
                   source=src28, noise=T(V3_B, V3_A, case, "arrived", "total", 2, "notdown")))
LINES += [
    L(round=28, stream="traffic", item="T1b", commit="474558f8", line="Terminus head-on fast contacts down >= 25 %",
      form="total", n="18 runs paired (seeds 10-12)", rule="<= -25 %", base="872", arm="440 (-50 %)", verdict="PASS",
      source=src28 + " 'Traffic T1b FAILED'", noise=T(T1B_B, T1B_A, "terminus/head", "fast", "total", 0.25 * 872, "down")),
    L(round=28, stream="traffic", item="T1b", commit="474558f8", line="Terminus head-on crews in >= base - 2",
      form="total", n="18 runs paired", rule=">= 171", base="173", arm="170", verdict="FAIL",
      source=src28, noise=T(T1B_B, T1B_A, "terminus/head", "arrived", "total", 2, "notdown")),
    L(round=28, stream="traffic", item="T1b", commit="474558f8", line="Terminus head-on all-in median <= base + 20 %",
      form="median", n="18 runs paired", rule="<= +20 %", base="(rows)", arm="+26 %", verdict="FAIL",
      source=src28, noise=T(T1B_B, T1B_A, "terminus/head", "allin", "median", None, "notup", x_share=0.20)),
    L(round=28, stream="traffic", item="T1b", commit="474558f8", line="friendly-stuck <= base x 1.2 + 10 (Terminus head-on)",
      form="total", n="18 runs paired", rule="<= 764.8", base="629", arm="839", verdict="FAIL",
      source=src28, noise=T(T1B_B, T1B_A, "terminus/head", "fstuck", "total", 0.2 * 629 + 10, "notup")),
    L(round=28, stream="traffic", item="T1b", commit="474558f8", line="the other three cases not worse (fast <= +10 %, crews >= -2)",
      form="total", n="18 runs a case", rule="<= +10 %", base="(rows)", arm="identical (rule never fires there)", verdict="PASS",
      source=src28, noise=T(T1B_B, T1B_A, "yard_open/cross", "fast", "total", 0.1 * 232, "notup")),
    L(round=28, stream="scout", item="CP-S1", commit="game c138e589", line="fixed-gun gun on point during SUPPRESS >= +10 pts outside 2 se (+5..+10 with a note)",
      form="mean", n="13 seeds paired (61-84)", rule=">= +5 and > 2 se", base="-", arm="+6.32 pts", verdict="FAIL (inside 2 se)",
      source=src28 + " 'Scout CP-S1 NOT SHIPPED'", noise={"kind": "se", "se": 5.17, "x": 2 * 5.17, "clear": 6.32 - 2 * 5.17}),
    L(round=28, stream="scout", item="CP-S1", commit="game c138e589", line="reported: fixed-gun kills 77 -> 57 (-1.0/seed)",
      form="mean", n="13 seeds", rule="-", base="77", arm="57", verdict="REPORTED", source=src28,
      noise={"kind": "se", "se": 0.5 * 13 ** 0.5, "x": 0.0, "clear": -20.0}),
    L(round=28, stream="scout", item="S3", commit="de45a69f", line="gang_scout his case: contact runs <= 4/18 (off >= 7)",
      form="count-runs", n="18 runs", rule="<= 4/18", base="9/18", arm="0/18", verdict="PASS",
      source=src28 + " 'Scout S3 SHIPPED'", noise={"kind": "fisher", "a": 0, "n1": 18, "c": 9, "n2": 18}),
    L(round=28, stream="scout", item="S3", commit="de45a69f", line="blind census 109-132: gang contacts not worse beyond 2 se",
      form="mean", n="24 seeds", rule="<= +2 se", base="-", arm="-0.31/seed", verdict="PASS",
      source=src28, noise={"kind": "se", "se": 0.24, "x": 2 * 0.24, "clear": 0.31 + 2 * 0.24}),
    L(round=28, stream="scout", item="S3", commit="de45a69f", line="blind census: in-reach on target not worse beyond 2 se",
      form="mean", n="24 seeds", rule=">= -2 se", base="-", arm="-0.49", verdict="PASS",
      source=src28, noise={"kind": "se", "se": 1.71, "x": 2 * 1.71, "clear": -0.49 + 2 * 1.71}),
    L(round=28, stream="scout", item="S3", commit="de45a69f", line="blind census: kills not worse beyond 2 se (33 -> 28, noted)",
      form="total", n="24 seeds", rule=">= -2 se", base="33", arm="28", verdict="PASS (noted)", source=src28, noise={"kind": "none"}),
    L(round=28, stream="manoeuvre", item="M2 (lift + fill)", commit="27b56521", line="creep episodes down >= 50 % (30-50 with a note)",
      form="episodes", n="census seeds (untraced)", rule="<= -50 %", base="148", arm="123 (-17 %)", verdict="FAIL",
      source=src28 + " 'Manoeuvre M2 FAILED'", noise={"kind": "poisson", "a": 148, "b": 123, "x": 74.0, "pass_dir": "down"}),
    L(round=28, stream="manoeuvre", item="M2 (lift + fill)", commit="27b56521", line="Terminus rigs arrived >= base; wall contacts <= +10 %",
      form="total", n="4 rig runs", rule=">= 55; <= 1977", base="55/64; 1797", arm="51/64; 3261", verdict="FAIL",
      source=src28, noise={"kind": "poisson", "a": 1797, "b": 3261, "x": 179.7, "pass_dir": "notup"}),
    L(round=28, stream="manoeuvre", item="M2 (a) lift alone", commit="27b56521+", line="creep episodes down >= 30 % floor",
      form="episodes", n="census", rule="<= -30 %", base="148", arm="-20 %", verdict="FAIL",
      source=src28 + " 'Manoeuvre M2 NOT SHIPPED'", noise={"kind": "poisson", "a": 148, "b": 118, "x": 44.4, "pass_dir": "down"}),
    L(round=28, stream="manoeuvre", item="M2 (a) lift alone", commit="27b56521+", line="rigs' wall contact-ticks <= +10 %",
      form="total", n="rig runs", rule="<= 1977", base="1797", arm="4136", verdict="FAIL", source=src28,
      noise={"kind": "poisson", "a": 1797, "b": 4136, "x": 179.7, "pass_dir": "notup"}),
    L(round=28, stream="manoeuvre", item="M1 (1st judged)", commit="748735c9", line="point tasks: >= 70 % of wheeled turret crews within 15 deg",
      form="share", n="~155 crews a task", rule=">= 70 %", base="-", arm="55-67 %", verdict="FAIL",
      source=src28 + " 'M1 first judged run'", noise={"kind": "binom", "k": 100, "n": 155, "K": 109}),
    L(round=28, stream="manoeuvre", item="M1 (1st judged)", commit="748735c9", line="line tasks = hover/turret's error +-5 deg (partial rule)",
      form="median", n="~155 crews a task", rule="+-5 deg of hover", base="hover 28.1-28.7", arm="27.6-27.9", verdict="PASS",
      source=src28, noise={"kind": "none"}),
    L(round=28, stream="manoeuvre", item="M1 (last, r28)", commit="140275af", line="point tasks: >= 70 % within 15 deg (move 70, right 69, attack-move 64)",
      form="share", n="155 crews a task (13 runs with the class)", rule=">= 70 %", base="25-26 %", arm="64-70 %", verdict="FAIL (2 of 3)",
      source=src28 + " 'Manoeuvre M1 NOT SHIPPED'; " + R28 + "manoeuvre/m1_last_attempt_drawn.txt",
      noise={"kind": "binom", "k": 99, "n": 155, "K": 109}),
    L(round=28, stream="manoeuvre", item="M1 (last, r28)", commit="140275af", line="crews still moving at 75 s <= base + 5 every task",
      form="total", n="144 runs an arm (24 a task)", rule="<= +5", base="23 / 49 / 17 / 23 / 29 / 28", arm="+4 +3 +14 +25 +12 +8", verdict="FAIL",
      source=src28 + "; " + R28 + "manoeuvre/m1_last_attempt_drawn.txt M1_MOVING",
      noise={"kind": "aa", "swing": 17.0, "x": 5.0, "note": "round 28's re-run on the same seeds moved the count by up to +-17 (M1 r29 bar text)"}),
    L(round=28, stream="brains", item="B1 (a) even", commit="f3a0145d", line="on side (median hit bearing <= 35 deg) >= 12/18",
      form="count-runs", n="18 runs paired (seeds 7-9)", rule=">= 12/18", base="clicked 0/18", arm="10/18", verdict="FAIL",
      source=src28 + " 'Brains B1 NOT SHIPPED'; " + R28 + "brains_b1_judged_a_even.jsonl",
      noise={"kind": "binom", "k": 10, "n": 18, "K": 12, "fisher": {"a": 10, "n1": 18, "c": 0, "n2": 18}}),
    L(round=28, stream="brains", item="B1 (a) even", commit="f3a0145d", line="fight guard: kills >= clicked - 2; alive >= clicked - 0.5",
      form="mean", n="18 runs paired", rule=">= -2; >= -0.5", base="killed 4, alive 1.50", arm="killed 10, alive 2.00", verdict="PASS",
      source=src28, noise={"kind": "approach", "path": R28 + "brains_b1_judged_a_even.jsonl", "metric": "alive", "x": 0.5}),
    L(round=28, stream="brains", item="B1 (c) moving", commit="f3a0145d", line="on side >= 9/18",
      form="count-runs", n="18 runs paired", rule=">= 9/18", base="0/18", arm="4/18", verdict="FAIL",
      source=src28 + "; " + R28 + "brains_b1_judged_c_moving.jsonl",
      noise={"kind": "binom", "k": 4, "n": 18, "K": 9, "fisher": {"a": 4, "n1": 18, "c": 0, "n2": 18}}),
    L(round=28, stream="brains", item="B1 (c) moving", commit="f3a0145d", line="fight guard: killed >= clicked - 2 runs; alive >= clicked - 0.5",
      form="mean", n="18 runs paired", rule=">= -0.5 alive", base="killed 18, alive 4.89", arm="killed 10, alive 2.39", verdict="FAIL",
      source=src28, noise={"kind": "approach", "path": R28 + "brains_b1_judged_c_moving.jsonl", "metric": "alive", "x": 0.5}),
    L(round=28, stream="brains", item="B2 battery", commit="88b6a724", line="first round <= clicked + 10 s (+10..15 with a note)",
      form="median", n="18 runs (tuning seeds 4-6)", rule="<= +15 s", base="2.3 s", arm="25.8 s (+23.5)", verdict="FAIL (parked, not judged)",
      source=src28 + " 'Brains B2 PARKED'", noise={"kind": "none"}),
    L(round=28, stream="brains", item="B2 battery", commit="88b6a724", line="fires from the side >= 15/18; alive >= clicked - 0.5",
      form="count-runs", n="18", rule=">= 15/18", base="-", arm="18/18; alive 3.00 = 3.00", verdict="PASS", source=src28,
      noise={"kind": "binom", "k": 18, "n": 18, "K": 15}),
    L(round=28, stream="brains", item="B3 CPU screens", commit="b95a3d6e", line="enemy hull contacts under an ordered MOVE down >= 50 % (all units)",
      form="mean", n="12 seeds paired (13-24)", rule="<= -50 %", base="9.25/seed", arm="2.33/seed (-75 %, se 2.71)", verdict="PASS",
      source=src28 + " 'Brains B3 judged'; " + R28 + "b3_contact_census/",
      noise={"kind": "census", "off": R28 + "b3_contact_census", "on": R28 + "b3_contact_census", "tag": "CONTACT_CENSUS",
             "off_pattern": r"off-(\d+)\.log$", "on_pattern": r"on-(\d+)\.log$", "metric": "under_move", "x_share": 0.5, "pass_dir": "down"}),
    L(round=28, stream="brains", item="B3 CPU screens", commit="b95a3d6e", line="recon deaths not up",
      form="mean", n="12 seeds paired", rule="<= base", base="5.00/seed", arm="4.58/seed", verdict="PASS",
      source=src28, noise={"kind": "census", "off": R28 + "b3_contact_census", "on": R28 + "b3_contact_census", "tag": "CONTACT_CENSUS",
                           "off_pattern": r"off-(\d+)\.log$", "on_pattern": r"on-(\d+)\.log$", "metric": "recon_deaths", "x": 0.0, "pass_dir": "notup"}),
    L(round=28, stream="brains", item="B3 CPU screens", commit="b95a3d6e", line="CPU win rate within noise: the same side wins 12/12",
      form="count-runs", n="12 seeds paired", rule="within noise", base="-", arm="12/12 same winner", verdict="PASS", source=src28,
      noise={"kind": "none"}),
    L(round=28, stream="brains", item="B3 shipped line", commit="6efe3450", line="scout-census fixed guns: contacts under MOVE 36 -> 0 (3.00 -> 0.00/seed)",
      form="mean", n="12 seeds paired", rule="<= -50 %", base="36 (3.00/seed)", arm="0", verdict="PASS",
      source=src28 + " 'Brains B3 SHIPPED'", noise={"kind": "se", "se": 1.50 * 12 ** 0.5, "x": 18.0, "clear": 36.0 - 18.0}),
    L(round=28, stream="brains", item="B3 shipped line", commit="6efe3450", line="all fixed-gun contacts 93 -> 24 (reported)",
      form="total", n="12 seeds paired", rule="-", base="93", arm="24", verdict="REPORTED",
      source=src28 + "; " + R28 + "b3_scout_census_*/", noise={"kind": "census", "off": R28 + "b3_scout_census_off", "on": R28 + "b3_scout_census_on",
                                                                "tag": "SCOUT_CENSUS", "off_pattern": r"(\d+)\.log$", "on_pattern": r"(\d+)\.log$",
                                                                "metric": "contacts", "x": 0.0, "pass_dir": "down"}),
    L(round=28, stream="brains", item="B4 bridge re-issue", commit="254fd98f", line="his bridge 108/108 (107 with a note)",
      form="deterministic", n="108 cells", rule=">= 107, no new failing cell", base="106/108", arm="106/108 (2 new cells fail)", verdict="FAIL",
      source=src28 + " 'Brains B4 FAILED'", noise={"kind": "none"}),
]

# ---------------------------------------------------------------- round 29 --------------------------------------
src29 = WS + " Round 29 Bars"
LINES += [
    L(round=29, stream="traffic", item="CP-T", commit="3a94f38d", line="Terminus head-on crews in >= base - 2",
      form="total", n="18 runs paired (13-15 x 6)", rule=">= 174", base="176", arm="177", verdict="PASS",
      source=src29 + " 'Traffic CP-T JUDGED'; " + R29 + "traffic/verdict_3a94f38d.txt", noise=T(CPT_B, CPT_A, "terminus/head", "arrived", "total", 2, "notdown")),
    L(round=29, stream="traffic", item="CP-T", commit="3a94f38d", line="Terminus head-on between-squad fast down >= 25 %",
      form="total", n="18 runs paired", rule="<= 356", base="475", arm="91 (-81 %)", verdict="PASS",
      source=src29, noise=T(CPT_B, CPT_A, "terminus/head", "xfast", "total", 0.25 * 475, "down")),
    L(round=29, stream="traffic", item="CP-T", commit="3a94f38d", line="Terminus head-on all-in median <= base + 20 %",
      form="median", n="18 runs paired", rule="<= 73.0 s", base="60.8 s", arm="59.3 s", verdict="PASS",
      source=src29, noise=T(CPT_B, CPT_A, "terminus/head", "allin", "median", None, "notup", x_share=0.20)),
    L(round=29, stream="traffic", item="CP-T", commit="3a94f38d", line="Terminus head-on: no wedge (no run > 1 crew never in where base had none)",
      form="count-runs", n="18 runs paired", rule="0 wedges", base="-", arm="none", verdict="PASS", source=src29, noise={"kind": "none"}),
    L(round=29, stream="traffic", item="CP-T", commit="3a94f38d", line="other three cases: fast and all-in within 2 se, crews >= base - 2",
      form="total", n="18 runs a case", rule="within 2 se", base="(rows)", arm="identical (2 se 0.0)", verdict="PASS",
      source=src29, noise=T(CPT_B, CPT_A, "terminus/cross", "fast", "total", 0.0, "notup")),
    L(round=29, stream="traffic", item="CP-T", commit="3a94f38d", line="CPU mirror Terminus head-on: no worse on (1)-(4)",
      form="total", n="18 runs paired (rust)", rule="(1)-(4)", base="475 / 176 / 60.8", arm="58 / 178 / 59.1", verdict="PASS",
      source=src29, noise=T(R29 + "traffic/judged_cpu_base_3a94f38d_seeds131415.jsonl", R29 + "traffic/judged_cpu_hold_3a94f38d_seeds131415.jsonl",
                            "terminus/head", "xfast", "total", 0.25 * 475, "down")),
    L(round=29, stream="traffic", item="T1c", commit="761bd727", line="set-up give-ways in the arm = 0 (> 0 in base, else NULL)",
      form="total", n="9 census runs paired (seeds 4-6)", rule="= 0", base="25", arm="9", verdict="FAIL",
      source=src29 + " 'Traffic T1c JUDGED'; " + R29 + "traffic/t1c_census_*", noise={"kind": "jsonl", "base": R29 + "traffic/t1c_census_base_761bd727_seeds456.jsonl",
                                                                                          "arm": R29 + "traffic/t1c_census_arm_761bd727_seeds456.jsonl", "key": ["seed", "credits", "units"],
                                                                                          "metric": "deployed_yields", "x": 25.0, "pass_dir": "down"}),
    L(round=29, stream="traffic", item="T1c", commit="761bd727", line="friendly-stuck <= base x 1.2 + 10",
      form="total", n="9 runs paired", rule="<= 368.8", base="299", arm="295", verdict="PASS", source=src29,
      noise={"kind": "jsonl", "base": R29 + "traffic/t1c_census_base_761bd727_seeds456.jsonl", "arm": R29 + "traffic/t1c_census_arm_761bd727_seeds456.jsonl",
             "key": ["seed", "credits", "units"], "metric": "stuck_friend_s", "x": 0.2 * 299 + 10, "pass_dir": "notup"}),
    L(round=29, stream="traffic", item="T1c", commit="761bd727", line="fast contacts <= base x 1.1 + 5",
      form="total", n="9 runs paired", rule="<= 515", base="464", arm="480", verdict="PASS", source=src29,
      noise={"kind": "jsonl", "base": R29 + "traffic/t1c_census_base_761bd727_seeds456.jsonl", "arm": R29 + "traffic/t1c_census_arm_761bd727_seeds456.jsonl",
             "key": ["seed", "credits", "units"], "metric": "contacts_friend_fast", "x": 0.1 * 464 + 5, "pass_dir": "notup"}),
    L(round=29, stream="traffic", item="T1c", commit="761bd727", line="artillery fire not down > 2 se",
      form="total", n="9 runs paired", rule=">= -2 se", base="130", arm="120 (diff -10, 2 se 26)", verdict="PASS", source=src29,
      noise={"kind": "jsonl", "base": R29 + "traffic/t1c_census_base_761bd727_seeds456.jsonl", "arm": R29 + "traffic/t1c_census_arm_761bd727_seeds456.jsonl",
             "key": ["seed", "credits", "units"], "metric": "art_shots", "x": None, "x_se": 2.0, "pass_dir": "notdown"}),
    L(round=29, stream="traffic", item="T3", commit="d9b3339c", line="between-squad fast pooled over the two crossings down >= 25 %",
      form="total", n="36 runs paired (2 cases x 18)", rule="<= 154.5", base="206", arm="95 (-54 %)", verdict="PASS",
      source=src29 + " 'Traffic T3 JUDGED'; " + R29 + "traffic/t3_verdict_d9b3339c.txt",
      noise=T(T3_B, T3_A, ["terminus/cross", "yard_open/cross"], "xfast", "total", 0.25 * 206, "down")),
    L(round=29, stream="traffic", item="T3", commit="d9b3339c", line="Terminus crossing between-squad fast not up",
      form="total", n="18 runs paired", rule="<= 92", base="92", arm="39", verdict="PASS", source=src29,
      noise=T(T3_B, T3_A, "terminus/cross", "xfast", "total", 0.0, "notup")),
    L(round=29, stream="traffic", item="T3", commit="d9b3339c", line="yard crossing between-squad fast not up",
      form="total", n="18 runs paired", rule="<= 114", base="114", arm="56", verdict="PASS", source=src29,
      noise=T(T3_B, T3_A, "yard_open/cross", "xfast", "total", 0.0, "notup")),
    L(round=29, stream="traffic", item="T3", commit="d9b3339c", line="Terminus crossing crews in >= base - 2",
      form="total", n="18 runs paired", rule=">= 174", base="176", arm="180", verdict="PASS", source=src29,
      noise=T(T3_B, T3_A, "terminus/cross", "arrived", "total", 2, "notdown")),
    L(round=29, stream="traffic", item="T3", commit="d9b3339c", line="Terminus crossing all-in median <= base + 20 %",
      form="median", n="18 runs paired", rule="<= 47.3 s", base="39.4 s", arm="48.3 s (+23 %)", verdict="FAIL", source=src29,
      noise=T(T3_B, T3_A, "terminus/cross", "allin", "median", None, "notup", x_share=0.20)),
    L(round=29, stream="traffic", item="T3", commit="d9b3339c", line="yard crossing crews in >= base - 2",
      form="total", n="18 runs paired", rule=">= 169", base="171", arm="167", verdict="FAIL", source=src29,
      noise=T(T3_B, T3_A, "yard_open/cross", "arrived", "total", 2, "notdown")),
    L(round=29, stream="traffic", item="T3", commit="d9b3339c", line="yard crossing all-in median <= base + 20 %",
      form="median", n="18 runs paired", rule="<= 83.0 s", base="69.2 s", arm="74.8 s", verdict="PASS", source=src29,
      noise=T(T3_B, T3_A, "yard_open/cross", "allin", "median", None, "notup", x_share=0.20)),
    L(round=29, stream="traffic", item="T3", commit="d9b3339c", line="yard crossing: no wedge",
      form="count-runs", n="18 runs paired", rule="0 wedges", base="-", arm="s22/t6 (2 out)", verdict="FAIL", source=src29, noise={"kind": "none"}),
    L(round=29, stream="traffic", item="T3", commit="d9b3339c", line="Terminus crossing same-squad fast <= base x 1.2 + 10",
      form="total", n="18 runs paired", rule="<= 170.8", base="134", arm="145", verdict="PASS", source=src29,
      noise=T(T3_B, T3_A, "terminus/cross", "ownfast", "total", 0.2 * 134 + 10, "notup")),
    L(round=29, stream="traffic", item="T3", commit="d9b3339c", line="yard crossing same-squad fast <= base x 1.2 + 10",
      form="total", n="18 runs paired", rule="<= 226", base="180", arm="130", verdict="PASS", source=src29,
      noise=T(T3_B, T3_A, "yard_open/cross", "ownfast", "total", 0.2 * 180 + 10, "notup")),
    L(round=29, stream="traffic", item="T3", commit="d9b3339c", line="Terminus head-on fast within 2 se",
      form="total", n="18 runs paired", rule="within 2 se", base="322", arm="322 (2 se 0.0)", verdict="PASS", source=src29,
      noise=T(T3_B, T3_A, "terminus/head", "fast", "total", None, "notup", x_se=2.0)),
    L(round=29, stream="traffic", item="T3", commit="d9b3339c", line="yard head-on fast within 2 se",
      form="total", n="18 runs paired", rule="within 2 se", base="132", arm="135 (2 se 10.2)", verdict="PASS", source=src29,
      noise=T(T3_B, T3_A, "yard_open/head", "fast", "total", None, "notup", x_se=2.0)),
    L(round=29, stream="traffic", item="T3", commit="d9b3339c", line="head-on cases: crews >= base - 2, all-in <= +20 %",
      form="total", n="18 runs a case", rule=">= -2", base="177 / 180", arm="176 / 179", verdict="PASS", source=src29,
      noise=T(T3_B, T3_A, "yard_open/head", "arrived", "total", 2, "notdown")),
]
# M1 round 29: the guard per task, the class rows, the clicked A/A, the point/line tasks
m1src = src29 + " 'Manoeuvre M1 JUDGED'; " + M1
for task, d in (("faced_ambush", -3), ("faced_attack_move", 8), ("faced_move", -4), ("faced_right", 3), ("faced_screen", 2), ("faced_support_by_fire", 8)):
    LINES.append(L(round=29, stream="manoeuvre", item="M1", commit="d7385da2", line="%s: crews still moving at 75 s (all classes) <= base + 5" % task,
                   form="total", n="48 runs an arm a task (27 paired with wheeled turrets)", rule="<= +5", base="(M1_MOVING)", arm="%+d" % d,
                   verdict="PASS" if d <= 5 else "FAIL", source=m1src, noise={"kind": "m1_guard", "path": M1, "task": task, "x": 5.0, "clear": 5.0 - d}))
LINES += [
    L(round=29, stream="manoeuvre", item="M1", commit="d7385da2", line="every class M1 never commands within 2 se of base (orchestrator's rule a)",
      form="total", n="27 / 20 / 12 / 4 runs paired", rule="within 2 se", base="(M1_CLASS)", arm="all 24 rows yes", verdict="PASS",
      source=m1src, noise={"kind": "none"}),
    L(round=29, stream="manoeuvre", item="M1", commit="d7385da2", line="point tasks: wheeled turret at rest median <= 15 deg, >= 70 % within 15 deg",
      form="share", n="310 crews a task", rule="<= 15 deg; >= 70 %", base="41-59 deg; 14-32 %", arm="3.2-3.3 deg; 80-82 %", verdict="PASS",
      source=m1src, noise={"kind": "binom", "k": 250, "n": 310, "K": 217}),
    L(round=29, stream="manoeuvre", item="M1", commit="d7385da2", line="line tasks = hover/turret +-5 deg",
      form="median", n="310 crews a task", rule="+-5 deg", base="hover 28.1-28.8", arm="27.6-28.0", verdict="PASS", source=m1src, noise={"kind": "none"}),
    L(round=29, stream="manoeuvre", item="M1", commit="d7385da2", line="clicked medians within +-5 deg of base (M1 never acts on clicked: an A/A)",
      form="median", n="651 crews a task (310 wheeled turret)", rule="+-5 deg", base="base_clicked", arm="4 tasks outside (3 lower)", verdict="FAIL",
      source=m1src, noise={"kind": "m1_clicked", "path": M1, "x": 5.0}),
    L(round=29, stream="manoeuvre", item="M1", commit="d7385da2", line="wheeled-turret at-rest share not down > 5 pts v base any task",
      form="share", n="310 crews a task", rule=">= -5 pts", base="76-93 %", arm="-3.9 .. +3.9 pts", verdict="PASS",
      source=m1src, noise={"kind": "binom", "k": 237, "n": 310, "K": 237 - 15}),
    L(round=29, stream="manoeuvre", item="M1", commit="d7385da2", line="settle paired median <= +6 s",
      form="median", n="27 runs paired a task", rule="<= +6 s", base="75.0 (never in 17-25 of 27)", arm="75.0 (+0.0)", verdict="PASS (censored)",
      source=m1src, noise={"kind": "none", "note": "both arms at the 75 s window in most runs: the line is censored and measures nothing"}),
    L(round=29, stream="brains", item="B1", commit="c2ae6e68", line="median shooter bearing <= 35 deg in >= 16/18 runs",
      form="count-runs", n="18 runs paired (13-15 x 6)", rule=">= 16/18", base="clicked 0/18", arm="18/18", verdict="PASS",
      source=src29 + " 'Brains B1 JUDGED'", noise={"kind": "binom", "k": 18, "n": 18, "K": 16, "fisher": {"a": 18, "n1": 18, "c": 0, "n2": 18}}),
    L(round=29, stream="brains", item="B1", commit="c2ae6e68", line="rounds by a crew > 35 deg off the side = 0",
      form="total", n="18 runs", rule="= 0", base="-", arm="0", verdict="PASS", source=src29, noise={"kind": "none"}),
    L(round=29, stream="brains", item="B1", commit="c2ae6e68", line="alive >= clicked - 0.5 (mean)",
      form="mean", n="18 runs paired", rule=">= -0.5", base="3.00", arm="3.00", verdict="PASS", source=src29, noise={"kind": "none"}),
    L(round=29, stream="brains", item="B1", commit="c2ae6e68", line="first-round median <= clicked + 30 s",
      form="median", n="18 runs paired", rule="<= +30 s", base="2.3 s", arm="27.1 s (+24.8, worst 30.9)", verdict="PASS", source=src29, noise={"kind": "none"}),
    L(round=29, stream="brains", item="B2 (a)", commit="fa099d5b", line="even roster on side >= 12/18",
      form="count-runs", n="18 runs paired (10-12 x 6)", rule=">= 12/18", base="clicked 0/18", arm="14/18", verdict="PASS",
      source=src29 + " 'Brains B2 JUDGED'", noise={"kind": "binom", "k": 14, "n": 18, "K": 12, "fisher": {"a": 14, "n1": 18, "c": 0, "n2": 18}}),
    L(round=29, stream="brains", item="B2 (a)", commit="fa099d5b", line="fight guard: kills >= clicked - 2; alive >= clicked - 0.5; side/rear >= clicked",
      form="mean", n="18 runs paired", rule=">= -2; >= -0.5; >=", base="kills 4, alive 1.11, 0.82", arm="kills 8, alive 1.78, 0.88", verdict="PASS",
      source=src29, noise={"kind": "none"}),
    L(round=29, stream="brains", item="B2 (c)", commit="fa099d5b", line="CPU-commanded target: fight guard + side/rear >= clicked + latch fires",
      form="mean", n="18 runs paired", rule="guards", base="kills 18, alive 4.78", arm="kills 18, alive 5.00, latch 18/18", verdict="PASS",
      source=src29, noise={"kind": "none"}),
    L(round=29, stream="manoeuvre", item="M2", commit="7b895eed", line="open+static creep episodes down >= 50 %",
      form="episodes", n="census seeds 8-13 + sim 6-8", rule="<= 62.5", base="125", arm="75 (-40 %)", verdict="FAIL",
      source=src29 + " 'Manoeuvre M2 JUDGED'; " + R29 + "manoeuvre/m2_judged.txt", noise={"kind": "poisson", "a": 125, "b": 75, "x": 62.5, "pass_dir": "down"}),
    L(round=29, stream="manoeuvre", item="M2", commit="7b895eed", line="> 3-leg episodes not up",
      form="episodes", n="census", rule="<= 386", base="386", arm="308", verdict="PASS", source=src29, noise={"kind": "poisson", "a": 386, "b": 308, "x": 0.0, "pass_dir": "notup"}),
    L(round=29, stream="manoeuvre", item="M2", commit="7b895eed", line="Terminus arrivals >= base (mixed 133, rigs 82)",
      form="total", n="6 seeds x 2 squads", rule=">= base", base="133/144; 82/96", arm="132/144; 75/96", verdict="FAIL",
      source=src29, noise={"kind": "se", "se": 1.47 * 6 ** 0.5, "x": 0.0, "clear": -1.0, "note": "se borrowed from M4's Terminus mixed rows (same probe, same n)"}),
    L(round=29, stream="manoeuvre", item="M2", commit="7b895eed", line="Terminus wall contact-ticks <= base + 10 % (mixed; rigs)",
      form="total", n="6 seeds a squad", rule="<= 1686; <= 4332", base="1533; 3938", arm="959; 6494", verdict="FAIL (rigs)",
      source=src29, noise={"kind": "se", "se": 1110.6 * 6 ** 0.5, "x": 393.8, "clear": 4332 - 6494, "note": "se borrowed from M4's Terminus rigs rows (same probe, same n)"}),
    L(round=29, stream="manoeuvre", item="M2", commit="7b895eed", line="friendly creep episodes not up > 10 %",
      form="episodes", n="census", rule="<= 137", base="125", arm="113", verdict="PASS", source=src29, noise={"kind": "poisson", "a": 125, "b": 113, "x": 12.5, "pass_dir": "notup"}),
    L(round=29, stream="manoeuvre", item="M2", commit="7b895eed", line="bridge-pooled 18/18",
      form="deterministic", n="18 cells", rule="18/18", base="18/18", arm="18/18", verdict="PASS", source=src29, noise={"kind": "none"}),
    L(round=29, stream="manoeuvre", item="M4", commit="9db2a57c", line="(b1) Terminus rigs arrivals >= base",
      form="total", n="6 seeds paired (14-19)", rule=">= 81", base="81/96", arm="64/96 (lower on all 6)", verdict="FAIL",
      source=src29 + " 'Manoeuvre M4 JUDGED'; " + R29 + "manoeuvre/m4_judged.txt",
      noise={"kind": "terminus", "path": R29 + "manoeuvre/m4_judged.txt", "squad": "rigs", "metric": "arrived", "x": 0.0, "pass_dir": "notdown"}),
    L(round=29, stream="manoeuvre", item="M4", commit="9db2a57c", line="(b1) Terminus rigs wall+hull contact-ticks down",
      form="total", n="6 seeds paired", rule="< 5337", base="5337", arm="8542 (1044 -> 3882 without each arm's 2 worst)", verdict="FAIL",
      source=src29, noise={"kind": "terminus", "path": R29 + "manoeuvre/m4_judged.txt", "squad": "rigs", "metric": "contacts", "x": 0.0, "pass_dir": "down"}),
    L(round=29, stream="manoeuvre", item="M4", commit="9db2a57c", line="(b1) Terminus mixed arrivals >= base; contact-ticks down",
      form="total", n="6 seeds paired", rule=">= 137; < 720", base="137/144; 720", arm="132/144; 3486", verdict="FAIL",
      source=src29, noise={"kind": "terminus", "path": R29 + "manoeuvre/m4_judged.txt", "squad": "mixed", "metric": "contacts", "x": 0.0, "pass_dir": "down"}),
    L(round=29, stream="manoeuvre", item="M4", commit="9db2a57c", line="(b2) pinned crew-seconds down by > 2 se (paired)",
      form="total", n="144 runs paired (seeds 34-39)", rule="< -2 se", base="2902", arm="1040 (-1862, se 460)", verdict="PASS",
      source=src29, noise={"kind": "se", "se": 459.6, "x": 2 * 459.6, "clear": 1862 - 2 * 459.6}),
    L(round=29, stream="manoeuvre", item="M4", commit="9db2a57c", line="(b2) pinned crews (count) down",
      form="total", n="144 runs paired", rule="down", base="69", arm="33 (-36, se 10.9)", verdict="PASS", source=src29,
      noise={"kind": "se", "se": 10.9, "x": 0.0, "clear": 36.0}),
    L(round=29, stream="manoeuvre", item="M4", commit="9db2a57c", line="(b3) bridge-pooled 18/18",
      form="deterministic", n="18 cells", rule="18/18", base="18/18", arm="17/18 (rust t15 s2 crossed 3 of 4)", verdict="FAIL",
      source=src29, noise={"kind": "mcnemar", "b": 0, "c": 1}),
    L(round=29, stream="manoeuvre", item="M4", commit="9db2a57c", line="fights guard: kills within 2 se (paired)",
      form="total", n="24 fights paired (109-132)", rule="within 2 se", base="1001", arm="984 (-17, se 21.5)", verdict="PASS",
      source=src29, noise={"kind": "se", "se": 21.5, "x": 2 * 21.5, "clear": 2 * 21.5 - 17}),
    L(round=29, stream="manoeuvre", item="M4", commit="9db2a57c", line="fights guard: deaths within 2 se",
      form="total", n="24 fights paired", rule="within 2 se", base="1010", arm="988 (-22, se 22.2)", verdict="PASS",
      source=src29, noise={"kind": "se", "se": 22.2, "x": 2 * 22.2, "clear": 2 * 22.2 - 22}),
    L(round=29, stream="manoeuvre", item="M4", commit="9db2a57c", line="fights guard: hit rate within 2 se (paired mean)",
      form="mean", n="24 fights paired", rule="within 2 se", base="0.717", arm="0.714 (-0.003, se 0.012)", verdict="PASS",
      source=src29, noise={"kind": "se", "se": 0.012, "x": 0.024, "clear": 0.024 - 0.003}),
    L(round=29, stream="manoeuvre", item="M4", commit="9db2a57c", line="reported: hits -3579 (se 1774), touch shots -400 (se 170), touch hits -313 (se 153): OUTSIDE 2 se",
      form="total", n="24 fights paired", rule="-", base="19749", arm="16170", verdict="REPORTED (outside 2 se)", source=src29,
      noise={"kind": "se", "se": 1773.6, "x": 2 * 1773.6, "clear": 2 * 1773.6 - 3579}),
    L(round=29, stream="brains", item="B5c", commit="053beffb", line="yard crossing last-crew-in median on <= off - 5 s",
      form="median", n="12 runs an arm (23-24 x 6)", rule="<= off - 5 s", base="never (7/12 runs never all in)", arm="21.95 s", verdict="PASS",
      source=src29 + " 'Brains B5c JUDGED'; archive/round29/brains.md B5c", noise={"kind": "fisher", "a": 12, "n1": 12, "c": 5, "n2": 12, "note": "read as all-in runs 12/12 v 5/12"}),
    L(round=29, stream="brains", item="B5c", commit="053beffb", line="yard crossing crews >= off every run",
      form="count-runs", n="12 runs", rule="12/12", base="-", arm="10/10 in all 12", verdict="PASS", source=src29, noise={"kind": "none"}),
    L(round=29, stream="brains", item="B5c", commit="053beffb", line="Sumps all-within-8 m median <= off; no run > 5 s later",
      form="median", n="12 runs an arm (seeds 2-13)", rule="<= 38.8 s", base="38.8 s", arm="36.0 s (seed 3 never -> 36.5)", verdict="PASS",
      source=src29, noise={"kind": "none", "note": "no rows kept; the narrow fix a8df3dc3 moved Sumps 6 by 0.3 s and yard 23 by -3.6..+17.8 s: the cells' own swing"}),
    L(round=29, stream="brains", item="B5c", commit="053beffb", line="Sumps guns_on_arc >= off - 0.05",
      form="share", n="12 runs", rule=">= 0.89", base="0.94", arm="0.94", verdict="PASS", source=src29, noise={"kind": "none"}),
    L(round=29, stream="brains", item="B5c", commit="053beffb", line="arrive series within 8 m >= control - 1; median +-2 %",
      form="count-cells", n="100 cells paired (25-28)", rule=">= 88", base="89/100 (29.1 s)", arm="100/100 (24.8 s)", verdict="PASS",
      source=src29, noise={"kind": "mcnemar", "b": 11, "c": 0}),
    L(round=29, stream="brains", item="B5c", commit="053beffb", line="Terminus (reported): crews arrived",
      form="reported", n="3 seeds", rule="-", base="10/10/9", arm="10/10/10", verdict="REPORTED", source=src29, noise={"kind": "none"}),
    L(round=29, stream="brains", item="B5c", commit="053beffb", line="bridge-pooled 18/18 switch on; the 180 deg facing test (round 8's) on the default path",
      form="deterministic", n="18 cells + 1 test", rule="18/18, test green", base="18/18", arm="18/18; test_wheeled_arrival RED (dot 0.50)", verdict="FAIL (parked)",
      source=src29 + " 'Brains B5c PARKED'", noise={"kind": "none"}),
    L(round=29, stream="brains", item="B5c narrow fix", commit="a8df3dc3", line="judged cells identical to the on-arm (yard 23 t1 21.7 -> 32.8, t3 22.1 -> 39.9, t6 20.7 -> 24.2, t8 24.8 -> 25.6, t11 26.7 -> 23.1; Sumps 6 35.47 -> 35.17)",
      form="deterministic", n="6 cells re-run", rule="identical", base="on-arm", arm="5 of 6 moved", verdict="FAIL (parked)",
      source="archive/round29/brains.md B5c", noise={"kind": "aa", "swing": 17.8, "x": 5.0, "note": "two near-identical rules on the same yard cells: the cell's own swing is -3.6..+17.8 s"}),
]

# ---------------------------------------------------------------- round 30 --------------------------------------
# Added at round 30's CLOSE (judging.md *How to write a bar* step 8; the Bars block of `_agents/workstreams.md` Round 30).
src30 = WS + " Round 30 Bars"
T3B_B, T3B_A = R30 + "traffic/t3b_judged_base_cf124433_seeds313233.jsonl", R30 + "traffic/t3b_judged_arm_cf124433_seeds313233.jsonl"
T1CB_B, T1CB_A = R30 + "traffic/t1cb_judged_census_base_16780030_seeds789_131415.jsonl", R30 + "traffic/t1cb_judged_census_arm_16780030_seeds789_131415.jsonl"
T1CB_AB, T1CB_AA = R30 + "traffic/t1cb_judged_approach_base_16780030_seeds789_131415.jsonl", R30 + "traffic/t1cb_judged_approach_arm_16780030_seeds789_131415.jsonl"
M4B1, M4B2 = R30 + "manoeuvre/m4b_run1_judged.txt", R30 + "manoeuvre/m4b_run2_judged.txt"
M1B, M2B, KTA = R30 + "manoeuvre/m1b_judged.txt", R30 + "manoeuvre/m2b_judged.txt", R30 + "manoeuvre/kturnarc_judged.txt"
M2B_CB, M2B_CN = R30 + "manoeuvre/m2b_census_base.jsonl", R30 + "manoeuvre/m2b_census_new.jsonl"
GATE = R30 + "brains/b5c-v4-gate-series-19eca15a.jsonl"
ARR_OFF, ARR_ON = R30 + "brains/b5c-v4-arrive-off-19eca15a.jsonl", R30 + "brains/b5c-v4-arrive-on-19eca15a.jsonl"
B108_C, B108_ON = R30 + "brains/b3b-bridge108-control-4bc708d7.jsonl", R30 + "brains/b3b-bridge108-on-4bc708d7.jsonl"
CENSUS_KEY = ["arena", "seed", "credits", "units"]


def J(base, arm, metric, pass_dir, key=CENSUS_KEY, **kw):
    return dict(kind="jsonl", base=base, arm=arm, key=key, metric=metric, pass_dir=pass_dir, **kw)


def TM(path, squad, metric, pass_dir, **kw):
    return dict(kind="terminus", path=path, squad=squad, metric=metric, pass_dir=pass_dir, **kw)


def G(path, tag, name, pass_dir, x_se=2.0, **kw):
    return dict(kind="guard_line", path=path, tag=tag, name=name, pass_dir=pass_dir, x_se=x_se, **kw)


t3b = src30 + " 'Traffic T3b JUDGED'; " + R30 + "traffic/t3b_verdict_cf124433.txt"
LINES += [
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="between-squad fast pooled over the two crossings down >= 25 %",
      form="total", n="36 runs paired (seeds 31-33 x 6, 2 cases)", rule="<= 132", base="176", arm="96 (-45 %)", verdict="PASS",
      source=t3b, noise=T(T3B_B, T3B_A, ["terminus/cross", "yard_open/cross"], "xfast", "total", 0.25 * 176, "down")),
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="Terminus crossing between-squad fast <= base + 19.1 (row 38's 1.645 se)",
      form="total", n="18 runs paired", rule="<= 95.1", base="76", arm="50", verdict="PASS", source=t3b,
      noise=T(T3B_B, T3B_A, "terminus/cross", "xfast", "total", 19.1, "notup")),
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="yard crossing between-squad fast <= base + 12.6 (row 44's 1.645 se)",
      form="total", n="18 runs paired", rule="<= 112.6", base="100", arm="46", verdict="PASS", source=t3b,
      noise=T(T3B_B, T3B_A, "yard_open/cross", "xfast", "total", 12.6, "notup")),
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="Terminus crossing crews in >= base - 4.07 (row 41's 1.645 se)",
      form="total", n="18 runs paired", rule=">= 171.9", base="176", arm="176", verdict="PASS", source=t3b,
      noise=T(T3B_B, T3B_A, "terminus/cross", "arrived", "total", 4.07, "notdown")),
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="yard crossing crews in >= base - 4.77 (row 47's 1.645 se)",
      form="total", n="18 runs paired", rule=">= 163.2", base="168", arm="166", verdict="PASS", source=t3b,
      noise=T(T3B_B, T3B_A, "yard_open/cross", "arrived", "total", 4.77, "notdown")),
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="Terminus head-on crews in >= base - 6.81 (row 35's 1.645 se)",
      form="total", n="18 runs paired", rule=">= 172.2", base="179", arm="178", verdict="PASS", source=t3b,
      noise=T(T3B_B, T3B_A, "terminus/head", "arrived", "total", 6.81, "notdown")),
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="yard head-on crews in >= base - 1.64 (row 53's 1.645 se)",
      form="total", n="18 runs paired", rule=">= 176.4", base="178", arm="180", verdict="PASS", source=t3b,
      noise=T(T3B_B, T3B_A, "yard_open/head", "arrived", "total", 1.64, "notdown")),
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="Terminus crossing same-squad fast <= base + 43.7 (row 40's 1.645 se)",
      form="total", n="18 runs paired", rule="<= 213.7", base="170", arm="187", verdict="PASS", source=t3b,
      noise=T(T3B_B, T3B_A, "terminus/cross", "ownfast", "total", 43.7, "notup")),
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="yard crossing same-squad fast <= base + 52.6 (row 46's 1.645 se)",
      form="total", n="18 runs paired", rule="<= 192.6", base="140", arm="122", verdict="PASS", source=t3b,
      noise=T(T3B_B, T3B_A, "yard_open/cross", "ownfast", "total", 52.6, "notup")),
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="Terminus crossing clock: mean paired cross_clear_s <= 0.10 x base median + 1.645 se (judged se)",
      form="mean", n="18 runs paired", rule="<= +2.92 s", base="median 11.9 s", arm="12.6 s; mean paired -1.17 s (se 1.05)", verdict="PASS", source=t3b,
      noise=T(T3B_B, T3B_A, "terminus/cross", "xclear", "mean", None, "notup", x_share=0.10, x_base="median", x_se=1.645)),
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="yard crossing clock: mean paired cross_clear_s <= 0.10 x base median + 1.645 se (judged se)",
      form="mean", n="18 runs paired", rule="<= +1.18 s", base="median 8.2 s", arm="10.9 s; mean paired +2.80 s (se 0.22)", verdict="FAIL", source=t3b,
      noise=T(T3B_B, T3B_A, "yard_open/cross", "xclear", "mean", None, "notup", x_share=0.10, x_base="median", x_se=1.645)),
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="Terminus head-on fast within 1.645 se of base (row 33's +194.4)",
      form="total", n="18 runs paired", rule="<= 529.4", base="335", arm="326", verdict="PASS", source=t3b,
      noise=T(T3B_B, T3B_A, "terminus/head", "fast", "total", 194.4, "notup")),
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="yard head-on fast within 1.645 se of base (row 51's +8.4)",
      form="total", n="18 runs paired", rule="<= 116.4", base="108", arm="114", verdict="PASS", source=t3b,
      noise=T(T3B_B, T3B_A, "yard_open/head", "fast", "total", 8.4, "notup")),
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="Terminus head-on between-squad fast within 1.645 se (row 32's +116.5)",
      form="total", n="18 runs paired", rule="<= 206.5", base="90", arm="71", verdict="PASS", source=t3b,
      noise=T(T3B_B, T3B_A, "terminus/head", "xfast", "total", 116.5, "notup")),
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="yard head-on between-squad fast within 1.645 se (row 50's +5.8)",
      form="total", n="18 runs paired", rule="<= 57.8", base="52", arm="55", verdict="PASS", source=t3b,
      noise=T(T3B_B, T3B_A, "yard_open/head", "xfast", "total", 5.8, "notup")),
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="Terminus head-on all-in median within 1.645 se (row 36's +9.62 s)",
      form="median", n="18 runs paired", rule="<= 69.4 s", base="59.8 s", arm="59.8 s", verdict="PASS", source=t3b,
      noise=T(T3B_B, T3B_A, "terminus/head", "allin", "median", 9.62, "notup")),
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="yard head-on all-in median within 1.645 se (row 54's +3.82 s)",
      form="median", n="18 runs paired", rule="<= 37.5 s", base="33.7 s", arm="37.2 s", verdict="PASS", source=t3b,
      noise=T(T3B_B, T3B_A, "yard_open/head", "allin", "median", 3.82, "notup")),
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="no wedge in any of the four cases (worst run's trace read first: Terminus s33/t1, every crew in)",
      form="count-runs", n="72 runs paired", rule="0 wedges", base="-", arm="none", verdict="PASS", source=t3b, noise={"kind": "none"}),
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="reported: Terminus crossing all-in median (CP-N se 7.0 s)",
      form="median", n="18 runs paired", rule="-", base="50.8 s", arm="42.8 s", verdict="REPORTED", source=t3b,
      noise=T(T3B_B, T3B_A, "terminus/cross", "allin", "median", 0.0, "notup")),
    L(round=30, stream="traffic", item="T3b", commit="cf124433", line="reported: yard crossing all-in median (at the 90 s cap both arms)",
      form="median", n="18 runs paired", rule="-", base="90.0 s", arm="90.0 s", verdict="REPORTED", source=t3b,
      noise={"kind": "none", "note": "censored: the median sits at the run's 90 s cap in both arms"}),
]
t1cb = src30 + " 'Traffic T1c-b JUDGED'; " + R30 + "traffic/t1cb_judged_*"
LINES += [
    L(round=30, stream="traffic", item="T1c-b", commit="16780030", line="runs with any repack while firing: arm 0/9 and Fisher p <= 0.05 v base",
      form="count-runs", n="9 census runs paired (seeds 7-9 x 3 arenas)", rule="0/9, p <= 0.05", base="4/9", arm="0/9 (p 0.041)", verdict="PASS",
      source=t1cb, noise={"kind": "fisher", "a": 0, "n1": 9, "c": 4, "n2": 9}),
    L(round=30, stream="traffic", item="T1c-b", commit="16780030", line="repacks while firing, total = 0 (the defect)",
      form="total", n="9 runs paired", rule="= 0", base="11", arm="0", verdict="PASS", source=t1cb,
      noise=J(T1CB_B, T1CB_A, "repacks_while_firing", "down", x=11.0)),
    L(round=30, stream="traffic", item="T1c-b", commit="16780030", line="friendly-stuck <= base + 1.645 se (the judged run's paired se)",
      form="total", n="9 runs paired", rule="<= base + 1.645 se", base="496", arm="404", verdict="PASS", source=t1cb,
      noise=J(T1CB_B, T1CB_A, "stuck_friend_s", "notup", x_se=1.645)),
    L(round=30, stream="traffic", item="T1c-b", commit="16780030", line="fast friendly <= base + 27.1 (row 83)",
      form="total", n="9 runs paired", rule="<= 616.1", base="589", arm="563", verdict="PASS", source=t1cb,
      noise=J(T1CB_B, T1CB_A, "contacts_friend_fast", "notup", x=27.1)),
    L(round=30, stream="traffic", item="T1c-b", commit="16780030", line="artillery shots not down > 21.6 (row 82; one Parade run 171 -> 26 carried it)",
      form="total", n="9 runs paired", rule=">= 296.4", base="318", arm="163", verdict="FAIL", source=t1cb,
      noise=J(T1CB_B, T1CB_A, "art_shots", "notdown", x=21.6)),
    L(round=30, stream="traffic", item="T1c-b", commit="16780030", line="ApproachStage drawn artillery: repacks <= base (any arm repack traced as not a give-way)",
      form="total", n="18 runs paired (seeds 13-15 x 6, drawn)", rule="<= 8", base="8", arm="2", verdict="PASS", source=t1cb,
      noise=J(T1CB_AB, T1CB_AA, "repacks", "notup", key=["seed", "start_tick", "approach"], where={"approach": "east"}, x=0.0)),
    L(round=30, stream="traffic", item="T1c-b", commit="16780030", line="ApproachStage drawn: from the side 18/18; first round <= clicked + 30 s; alive >= clicked - 0.5",
      form="count-runs", n="18 runs paired", rule="18/18; <= +30 s; >= -0.5", base="18/18, 27.1 s, 3.00", arm="18/18, 27.1 s, 3.00 (14 of 18 rows byte-identical)",
      verdict="PASS", source=t1cb, noise={"kind": "none", "note": "the arms agree run for run on every line: an equality check, not a sample"}),
    L(round=30, stream="traffic", item="T1c-b", commit="16780030", line="bridge-pooled 18/18 rule on",
      form="deterministic", n="18 cells", rule="18/18", base="18/18", arm="18/18", verdict="PASS", source=t1cb, noise={"kind": "none"}),
    L(round=30, stream="traffic", item="T1c-b", commit="16780030", line="the four traffic-series cases rule on, seeds 31-33, equal row for row to T3b's judged base rows",
      form="deterministic", n="72 rows", rule="equal", base="T3b base", arm="equal field for field", verdict="PASS", source=t1cb, noise={"kind": "none"}),
]
m4b1 = src30 + " 'Manoeuvre M4b JUDGED (first run)'; " + M4B1
LINES += [
    L(round=30, stream="manoeuvre", item="M4b run 1", commit="e8bfef2e", line="(b1) Terminus rigs arrivals not down beyond 1 se (down beyond 2 se = the gate missed)",
      form="total", n="13 seeds paired (23-35)", rule=">= base - 3.72", base="185/208", arm="181/208 (-4, se 3.72: -1.1 se)", verdict="FAIL (undecided at 13 seeds)",
      source=m4b1, noise={"kind": "se", "se": 3.72, "x": 3.72, "clear": 3.72 - 4.0, "note": "run 1's table carries totals and discordant seeds only, so the printed se stands in for rows"}),
    L(round=30, stream="manoeuvre", item="M4b run 1", commit="e8bfef2e", line="(b1) Terminus mixed arrivals not down beyond 1 se",
      form="total", n="13 seeds paired", rule=">= base - 3.49", base="282/312", arm="288/312 (+6, se 3.49)", verdict="PASS",
      source=m4b1, noise={"kind": "se", "se": 3.49, "x": 3.49, "clear": 3.49 + 6.0}),
    L(round=30, stream="manoeuvre", item="M4b run 1", commit="e8bfef2e", line="reported, and decisive: rigs' wall contact-ticks (+141 %, +3.1 se paired; two worst dropped 4601 -> 11966)",
      form="total", n="13 seeds paired", rule="-", base="7456", arm="17970", verdict="REPORTED (decisive: the gate not passed)",
      source=m4b1, noise={"kind": "se", "se": 10514.0 / 3.1, "x": 0.0, "clear": -10514.0, "note": "the se is the quoted +3.1 se read back"}),
    L(round=30, stream="manoeuvre", item="M4b run 1", commit="e8bfef2e", line="reported: mixed wall contact-ticks (+17 %, 1.7 se)",
      form="total", n="13 seeds paired", rule="-", base="1403", arm="1642", verdict="REPORTED",
      source=m4b1, noise={"kind": "se", "se": 239.0 / 1.7, "x": 0.0, "clear": -239.0}),
    L(round=30, stream="manoeuvre", item="M4b run 1", commit="e8bfef2e", line="(b5) a rig's mean speed while touching a wall within 2 se of base",
      form="mean", n="32 runs paired", rule="within 2 se", base="5.23 m/s", arm="5.62 m/s (+0.39, se 0.30)", verdict="PASS",
      source=m4b1, noise={"kind": "se", "se": 0.30, "x": 0.60, "clear": 0.60 - 0.39}),
]
m4b2 = src30 + " 'Manoeuvre M4b, the SECOND and LAST attempt: Run 2 JUDGED'; " + M4B2
parked = " (M4b parked: the pair check found a regression the series did not cover)"
LINES += [
    L(round=30, stream="manoeuvre", item="M4b run 2", commit="77a1603f", line="(b1) Terminus rigs arrivals not down beyond 1.645 se",
      form="total", n="13 seeds paired (62-74)", rule=">= base - 1.645 se", base="178/208", arm="178/208 (identical)", verdict="PASS" + parked,
      source=m4b2, noise=TM(M4B2, "rigs", "arrived", "notdown", x_se=1.645)),
    L(round=30, stream="manoeuvre", item="M4b run 2", commit="77a1603f", line="(b1') Terminus rigs wall contact-ticks <= base + 1.645 se, with and without two worst",
      form="total", n="13 seeds paired", rule="<= base + 1.645 se", base="13411", arm="13411 (identical)", verdict="PASS" + parked,
      source=m4b2, noise=TM(M4B2, "rigs", "contacts", "notup", x_se=1.645)),
    L(round=30, stream="manoeuvre", item="M4b run 2", commit="77a1603f", line="(i) every rig run byte-identical to its base run (one leak = the gate missed)",
      form="deterministic", n="13 runs", rule="identical", base="-", arm="drive, leg and state lines equal; only the reader's printed `real` column differs", verdict="PASS" + parked,
      source=m4b2, noise={"kind": "none"}),
    L(round=30, stream="manoeuvre", item="M4b run 2", commit="77a1603f", line="(b1) Terminus mixed arrivals not down beyond 1.645 se",
      form="total", n="13 seeds paired", rule=">= base - 4.7", base="295/312", arm="293/312 (-2, se 2.89)", verdict="PASS" + parked,
      source=m4b2, noise=TM(M4B2, "mixed", "arrived", "notdown", x_se=1.645)),
    L(round=30, stream="manoeuvre", item="M4b run 2", commit="77a1603f", line="(b1') Terminus mixed wall contact-ticks <= base + 1.645 se",
      form="total", n="13 seeds paired", rule="<= base + 423", base="2093", arm="1915 (-178, se 257)", verdict="PASS" + parked,
      source=m4b2, noise=TM(M4B2, "mixed", "contacts", "notup", x_se=1.645)),
    L(round=30, stream="manoeuvre", item="M4b run 2", commit="77a1603f", line="(b2) pinned crew-seconds DOWN beyond 2 se (paired, n = 144)",
      form="total", n="144 runs paired (hull-rest seeds 54-59)", rule="< -2 se", base="2596", arm="658 (-1938, se 422)", verdict="PASS" + parked,
      source=m4b2, noise=G(M4B2, "PINNED", "all", "down")),
    L(round=30, stream="manoeuvre", item="M4b run 2", commit="77a1603f", line="(b2, j) the hulls the fix reaches (<= 10 m): pinned crew-seconds down beyond 2 se",
      form="total", n="144 runs paired", rule="< -2 se", base="2596", arm="556 (se 412)", verdict="PASS" + parked,
      source=m4b2, noise=G(M4B2, "PINNED", "short", "down")),
    L(round=30, stream="manoeuvre", item="M4b run 2", commit="77a1603f", line="(j) rigs apart: pinned crew-seconds unchanged within 2 se (their rule is bit for bit the old one)",
      form="total", n="144 runs paired", rule="within 2 se", base="0", arm="102 (se 72)", verdict="PASS" + parked,
      source=m4b2, noise=G(M4B2, "PINNED", "rigs", "notup")),
    L(round=30, stream="manoeuvre", item="M4b run 2", commit="77a1603f", line="(b4) tracks apart: pinned crew-seconds within 2 se",
      form="total", n="144 runs paired", rule="within 2 se", base="122", arm="108 (se 94)", verdict="PASS" + parked,
      source=m4b2, noise=G(M4B2, "PINNED", "tracks", "notup")),
    L(round=30, stream="manoeuvre", item="M4b run 2", commit="77a1603f", line="reported: pinned crews (count) and STUCK crew-seconds",
      form="total", n="144 runs paired", rule="-", base="65; 6631", arm="14 (se 10.2); 4794 (-28 %, se 628)", verdict="REPORTED",
      source=m4b2, noise=G(M4B2, "PINNED", "stuck", "down", x_se=0.0)),
    L(round=30, stream="manoeuvre", item="M4b run 2", commit="77a1603f", line="(b3) bridge-pooled 18/18",
      form="deterministic", n="18 cells", rule="18/18", base="18/18", arm="18/18", verdict="PASS" + parked, source=m4b2, noise={"kind": "none"}),
    L(round=30, stream="manoeuvre", item="M4b run 2", commit="77a1603f", line="fights guard: kills within 2 se (paired)",
      form="total", n="24 fights paired (157-180)", rule="within 2 se", base="967", arm="971 (+4, se 33.6)", verdict="PASS" + parked,
      source=m4b2, noise=G(M4B2, "FIGHT_GUARD", "kills", "notdown")),
    L(round=30, stream="manoeuvre", item="M4b run 2", commit="77a1603f", line="fights guard: deaths within 2 se",
      form="total", n="24 fights paired", rule="within 2 se", base="975", arm="975 (+0, se 34.1)", verdict="PASS" + parked,
      source=m4b2, noise=G(M4B2, "FIGHT_GUARD", "deaths", "notup")),
    L(round=30, stream="manoeuvre", item="M4b run 2", commit="77a1603f", line="fights guard: hit rate within 2 se (paired mean)",
      form="mean", n="24 fights paired", rule="within 2 se", base="0.710", arm="0.710 (+0.001, se 0.018)", verdict="PASS" + parked,
      source=m4b2, noise=G(M4B2, "FIGHT_GUARD", "hit rate", "notdown")),
    L(round=30, stream="manoeuvre", item="M4b run 2", commit="77a1603f", line="reported: hit rate on touching targets",
      form="mean", n="24 fights paired", rule="-", base="0.645", arm="0.670 (+0.025, se 0.036)", verdict="REPORTED",
      source=m4b2, noise=G(M4B2, "FIGHT_GUARD", "hit rate on touching targets", "notdown", x_se=0.0)),
    L(round=30, stream="manoeuvre", item="M4b run 2", commit="77a1603f", line="(b5) brush speed while touching within 2 se (a first measurement)",
      form="mean", n="26 runs paired", rule="within 2 se", base="5.37 m/s", arm="5.43 m/s (+0.07, se 0.09)", verdict="PASS" + parked,
      source=m4b2, noise={"kind": "se", "se": 0.09, "x": 0.18, "clear": 0.18 - 0.07}),
]
m1b = src30 + " 'Manoeuvre M1b(1) JUDGED'; " + M1B
for task, d in (("faced_ambush", -1), ("faced_attack_move", -10), ("faced_move", -10), ("faced_right", 5), ("faced_screen", -4), ("faced_support_by_fire", -3)):
    LINES.append(L(round=30, stream="manoeuvre", item="M1b", commit="55622870", line="%s: crews still moving at 75 s (all classes, drawn) <= base + 2 se (M1_CLASS's se)" % task,
                   form="total", n="24 runs an arm a task (15 paired with wheeled turrets)", rule="<= +2 se", base="(M1_MOVING)", arm="%+d" % d,
                   verdict="PASS", source=m1b, noise={"kind": "m1_guard", "path": M1B, "task": task, "x_se": 2.0, "diff": d}))
LINES += [
    L(round=30, stream="manoeuvre", item="M1b", commit="55622870", line="(a) at-rest hull-error median per task, ALL classes, drawn: not worse at permutation p < 0.05",
      form="median", n="303 crews a task", rule="p >= 0.05 every task", base="33.8 / 23.1 / 8.3 / 8.9 / 30.8 / 33.2 deg", arm="33.3 / 15.9 / 7.0 / 7.5 / 30.4 / 32.9 (p 0.38-0.91)",
      verdict="PASS", source=m1b, noise={"kind": "none", "note": "a permutation p per task (M1_HULL); no per-run rows"}),
    L(round=30, stream="manoeuvre", item="M1b", commit="55622870", line="(a) at-rest medians per task, ALL classes, clicked: not worse at p < 0.05 (an A/A: the anchor acts on drawn facings)",
      form="median", n="303 crews a task", rule="p >= 0.05", base="36.7 / 60.9 / 42.2 / 41.7 / 41.9 / 35.7 deg", arm="37.9 / 62.7 / 41.3 / 42.1 / 42.3 / 35.3 (p 0.57-0.92)",
      verdict="PASS", source=m1b, noise={"kind": "none", "note": "a permutation p per task (M1_HULL); the clicked pair is this probe's A/A: wheeled-turret clicked medians moved -6.2..+8.4 deg between arms that differ only in the drawn path (A/A block)"}),
    L(round=30, stream="manoeuvre", item="M1b", commit="55622870", line="reported: the 18 class x task moving lines; wheels/turret faced_right 11 -> 26 (+15, se 6.5: 2.3 se; 13 pinned + 13 driving, 0 face legs)",
      form="total", n="15 runs paired with the class", rule="-", base="11", arm="26 (+15, se 6.5)", verdict="REPORTED",
      source=m1b, noise={"kind": "se", "se": 6.5, "x": 2 * 6.5, "clear": 2 * 6.5 - 15.0}),
    L(round=30, stream="manoeuvre", item="M1b", commit="55622870", line="(c) reported: clicked support-by-fire's -17.8 deg (M1's A/A) reproduced or not",
      form="median", n="165 wheeled-turret crews", rule="-", base="50.6 deg (base_clicked)", arm="55.0 (p 0.79): not reproduced", verdict="REPORTED",
      source=m1b, noise={"kind": "none"}),
    L(round=30, stream="manoeuvre", item="M1b", commit="55622870", line="(d) Terminus rigs arrivals not down beyond 1 se (sequential.py arrived:guard:0.10: SERIES PASS at run 10 of 13)",
      form="total", n="13 seeds paired (36-48)", rule=">= base - 1 se", base="176/208", arm="179/208 (+3, se 5.13)", verdict="PASS",
      source=m1b, noise=TM(M1B, "rigs", "arrived", "notdown", x_se=1.0)),
    L(round=30, stream="manoeuvre", item="M1b", commit="55622870", line="(d) Terminus mixed arrivals not down beyond 1 se (SERIES PASS at run 6 of 13)",
      form="total", n="13 seeds paired", rule=">= base - 1 se", base="284/312", arm="286/312 (+2, se 3.56)", verdict="PASS",
      source=m1b, noise=TM(M1B, "mixed", "arrived", "notdown", x_se=1.0)),
    L(round=30, stream="manoeuvre", item="M1b", commit="55622870", line="reported: Terminus wall contact-ticks, rigs (-14 %, se 2221)",
      form="total", n="13 seeds paired", rule="-", base="8945", arm="7662", verdict="REPORTED", source=m1b, noise=TM(M1B, "rigs", "contacts", "notup", x=0.0)),
    L(round=30, stream="manoeuvre", item="M1b", commit="55622870", line="reported: Terminus wall contact-ticks, mixed (-30 %, se 481)",
      form="total", n="13 seeds paired", rule="-", base="2475", arm="1738", verdict="REPORTED", source=m1b, noise=TM(M1B, "mixed", "contacts", "notup", x=0.0)),
    L(round=30, stream="manoeuvre", item="M1b", commit="55622870", line="(e) bridge-pooled 18/18; (h) rigs seed 21 byte-identical both arms",
      form="deterministic", n="18 cells + 1 run", rule="18/18; identical", base="18/18", arm="18/18; identical", verdict="PASS", source=m1b, noise={"kind": "none"}),
]
m2b = src30 + " 'Manoeuvre M2b JUDGED, NOT MET'; " + M2B
LINES += [
    L(round=30, stream="manoeuvre", item="M2b", commit="1f1c9835", line="(a) open+static creep episodes down >= 50 % (census 14-19 + sim 9-11, paired per run)",
      form="total", n="15 runs paired", rule="<= 26.5", base="53", arm="37 (-30 %, se 9.8)", verdict="FAIL",
      source=m2b, noise=J(M2B_CB, M2B_CN, "creep_open_static", "down", key=["log"], x=0.5 * 53)),
    L(round=30, stream="manoeuvre", item="M2b", commit="1f1c9835", line="(b) > 3-leg episodes not up beyond 2 se",
      form="total", n="15 runs paired", rule="<= base + 2 se", base="111", arm="89", verdict="PASS",
      source=m2b, noise=J(M2B_CB, M2B_CN, "over3", "notup", key=["log"], x_se=2.0)),
    L(round=30, stream="manoeuvre", item="M2b", commit="1f1c9835", line="(b) reported: friendly creep episodes not up > 10 %",
      form="total", n="15 runs paired", rule="<= 99 (reported)", base="90", arm="100 (+11 %, se 19)", verdict="REPORTED",
      source=m2b, noise=J(M2B_CB, M2B_CN, "friendly", "notup", key=["log"], x=9.0)),
    L(round=30, stream="manoeuvre", item="M2b", commit="1f1c9835", line="(c) Terminus rigs arrivals not down beyond 1.645 se (the SPRT at the full grid read PASS; truncation decides by the fixed test)",
      form="total", n="13 seeds paired (49-61)", rule=">= base - 8.2", base="181/208", arm="172/208 (-9, se 4.97: 1.8 se down)", verdict="FAIL",
      source=m2b, noise=TM(M2B, "rigs", "arrived", "notdown", x_se=1.645)),
    L(round=30, stream="manoeuvre", item="M2b", commit="1f1c9835", line="(c) Terminus mixed arrivals not down beyond 1.645 se (SERIES PASS at run 6)",
      form="total", n="13 seeds paired", rule=">= base - 7.0", base="292/312", arm="293/312 (+1, se 4.28)", verdict="PASS",
      source=m2b, noise=TM(M2B, "mixed", "arrived", "notdown", x_se=1.645)),
    L(round=30, stream="manoeuvre", item="M2b", commit="1f1c9835", line="(h) reported: rigs' wall contact-ticks under the lift (+34 %, se 3034; worst run seed 51: 1765 of 1848 ticks on one wall)",
      form="total", n="13 seeds paired", rule="-", base="10400", arm="13953", verdict="REPORTED", source=m2b, noise=TM(M2B, "rigs", "contacts", "notup", x=0.0)),
    L(round=30, stream="manoeuvre", item="M2b", commit="1f1c9835", line="(d) kturn_aborted not up; (e) bridge-pooled 18/18",
      form="deterministic", n="13 seeds; 18 cells", rule="<= 9; 18/18", base="9; 18/18", arm="9; 18/18", verdict="PASS", source=m2b, noise={"kind": "none"}),
    L(round=30, stream="manoeuvre", item="M2b", commit="1f1c9835", line="brush speed while touching within 2 se",
      form="mean", n="24 runs paired", rule="within 2 se", base="5.74 m/s", arm="5.78 m/s (+0.04, se 0.47)", verdict="PASS",
      source=m2b, noise={"kind": "se", "se": 0.47, "x": 0.94, "clear": 0.94 - 0.04}),
]
kta = src30 + " 'kturnarc JUDGED'; " + KTA
LINES += [
    L(round=30, stream="manoeuvre", item="kturnarc", commit="e7a58262", line="(c) Terminus rigs arrivals not down beyond 1.645 se (SERIES PASS at run 6)",
      form="total", n="13 seeds paired (75-87)", rule=">= base - 12.1", base="178/208", arm="181/208 (+3, se 7.38)", verdict="PASS",
      source=kta, noise=TM(KTA, "rigs", "arrived", "notdown", x_se=1.645)),
    L(round=30, stream="manoeuvre", item="kturnarc", commit="e7a58262", line="(c) Terminus mixed arrivals not down beyond 1.645 se (SERIES PASS at run 6)",
      form="total", n="13 seeds paired", rule=">= base - 5.5", base="291/312", arm="288/312 (-3, se 3.34)", verdict="PASS",
      source=kta, noise=TM(KTA, "mixed", "arrived", "notdown", x_se=1.645)),
    L(round=30, stream="manoeuvre", item="kturnarc", commit="e7a58262", line="reported: Terminus wall contact-ticks, rigs (-4 %, se 3836) and mixed (+7 %, se 437)",
      form="total", n="13 seeds paired", rule="-", base="12184; 1861", arm="11755; 1991", verdict="REPORTED", source=kta, noise=TM(KTA, "rigs", "contacts", "notup", x=0.0)),
    L(round=30, stream="manoeuvre", item="kturnarc", commit="e7a58262", line="(d) kturn_aborted not up (22 -> 21; k-turns 398 -> 396); (e) bridge-pooled 18/18",
      form="deterministic", n="13 seeds; 18 cells", rule="<= 22; 18/18", base="22; 18/18", arm="21; 18/18", verdict="PASS", source=kta, noise={"kind": "none"}),
]
b5c4 = src30 + " 'Brains B5c-v4 JUDGED'; " + R30 + "brains/b5c-v4-*-19eca15a.jsonl"
parked_b = " (B5c-v4 parked: the pair check's pursuit test)"
LINES += [
    L(round=30, stream="brains", item="B5c-v4", commit="19eca15a", line="yard crossing: every crew in, on v off (the deciding line)",
      form="count-runs", n="12 runs an arm (seeds 25-26 x 6)", rule="12/12 v off", base="1/12", arm="12/12 (p 0.0000)", verdict="PASS" + parked_b,
      source=b5c4, noise={"kind": "fisher", "a": 12, "n1": 12, "c": 1, "n2": 12}),
    L(round=30, stream="brains", item="B5c-v4", commit="19eca15a", line="yard crossing: crews on >= off every run; last-crew median on <= off - 5 s (never = 90 s)",
      form="median", n="12 runs an arm", rule="12/12; <= 85 s", base="never (11 of 12 runs)", arm="19.0 s; 12/12", verdict="PASS" + parked_b,
      source=b5c4, noise={"kind": "none", "note": "censored: the off arm never gets every crew in on 11 of 12 runs, so the median line reads 90 -> 19 whatever the noise; the count above decides"}),
    L(round=30, stream="brains", item="B5c-v4", commit="19eca15a", line="Sumps cell: all-within-8 m median on <= off (never = 90 s)",
      form="median", n="12 runs an arm (seeds 14-15 x 6)", rule="<= 37.5 s", base="37.5 s", arm="24.5 s", verdict="PASS" + parked_b,
      source=b5c4, noise={"kind": "cells", "path": GATE, "cell": "sumps", "metric": "all_in8_or_end", "stat": "median", "x": 0.0, "pass_dir": "notup"}),
    L(round=30, stream="brains", item="B5c-v4", commit="19eca15a", line="Sumps cell: no run > 5 s later; guns_on_arc >= off - 0.05",
      form="mean", n="12 runs paired", rule="0 runs > +5 s; >= 0.891", base="0.941", arm="0.941; 0 runs later", verdict="PASS" + parked_b,
      source=b5c4, noise={"kind": "cells", "path": GATE, "cell": "sumps", "metric": "guns_on_arc", "stat": "mean", "x": 0.05, "pass_dir": "notdown"}),
    L(round=30, stream="brains", item="B5c-v4", commit="19eca15a", line="Terminus head-on seeds 3/5/6/7 t11 (reported, n = 1 each): crews arrived on >= off",
      form="reported", n="4 runs an arm", rule="-", base="10/10 x 4; last 56.8/82.2/47.0/52.7 s", arm="10/10 x 4; 50.1/56.2/45.6/43.7 s", verdict="REPORTED",
      source=b5c4, noise={"kind": "none"}),
    L(round=30, stream="brains", item="B5c-v4", commit="19eca15a", line="arrive series (fresh seeds 29-32): within 8 m on >= off - 1",
      form="count-cells", n="100 cells paired", rule=">= 90", base="91/100", arm="99/100 (McNemar 8 v 0)", verdict="PASS" + parked_b,
      source=b5c4, noise={"kind": "mcnemar", "b": 8, "c": 0}),
    L(round=30, stream="brains", item="B5c-v4", commit="19eca15a", line="arrive series: all-within-8 m median no slower than +2 % (over the cells complete in both arms)",
      form="median", n="91 complete pairs of 100", rule="<= +2 %", base="29.6 s", arm="24.5 s (-17 %, se 1.6)", verdict="PASS" + parked_b,
      source=b5c4, noise={"kind": "arrive", "off": ARR_OFF, "on": ARR_ON, "metric": "all_in8_s", "stat": "median", "x_share": 0.02, "pass_dir": "notup"}),
    L(round=30, stream="brains", item="B5c-v4", commit="19eca15a", line="counters > 0 every on run, 0 every off run; bridge-pooled 18/18 rule on; screen-slots s61 A_2 in; heading tests 24/0 + native's mirror",
      form="deterministic", n="24 cells + 18 + 1 + 24 tests", rule="all", base="-", arm="all met (A_4 ends 5.4 m off in BOTH arms: B4 not wholly fixed)", verdict="PASS" + parked_b,
      source=b5c4, noise={"kind": "none"}),
]
b3b = src30 + " 'Brains B3b JUDGED, NOT SHIPPED'; " + R30 + "brains/b3b-bridge108-*-4bc708d7.jsonl"
LINES += [
    L(round=30, stream="brains", item="B3b", commit="4bc708d7", line="his bridge 108/108 (the full 108, deterministic; control = main's rules reported)",
      form="deterministic", n="108 cells", rule="108/108", base="106/108 (green t5 s2, rust t9 s2)", arm="107/108 (green t18 s3 new)", verdict="FAIL",
      source=b3b, noise={"kind": "bridge108", "control": B108_C, "on": B108_ON}),
]

# ---------------------------------------------------------------- rounds 31-34 (C35.9) --------------------------
import lines_r31_34  # noqa: E402  (the same fields; owed since round 31, filed by native in round 35)

LINES += lines_r31_34.LINES

# ---------------------------------------------------------------- round 36 (round 37 native N6) ------------------------
import lines_r36  # noqa: E402  (the same fields; round 36's close skipped the re-render, close step 5b)

LINES += lines_r36.LINES

# ---------------------------------------------------------------- rounds 37-39 (round 40 native) ----------------------------
import lines_r37  # noqa: E402  (the same fields; rounds 37-39's closes skipped the re-render, close step 5b)
import lines_r38  # noqa: E402
import lines_r39  # noqa: E402

LINES += lines_r37.LINES + lines_r38.LINES + lines_r39.LINES

# ---------------------------------------------------------------- round 40 (round 40 native, close step 5b) ---------------
import lines_r40  # noqa: E402  (the same fields)

LINES += lines_r40.LINES

#!/usr/bin/env python3
"""Every judged bar line of rounds 31-34, as data (C35.9, native for planner: the inventory's owed rows).

The same fields and noise kinds as `lines.py` (read its docstring). Quoted numbers are the streams' own, from the Bars
and Rulings blocks in `_agents/workstreams.md` (Round 31 / 32 / 33 / 34) and the archived briefs' Status sections;
nothing here is re-measured. Most of these series kept their rows on stream branches, not on main, so a line's noise is
the se its table PRINTED (kind `se`), read back into the line's own units with four helpers:

  up(se, d)     a guard "arm <= base + k se":            x = k se, clear = x - d
  down(se, d)   a guard "arm >= base - k se":            x = k se, clear = d + x
  gain(se, d)   a gain "arm below base beyond k se":     x = k se, clear = -d - x   (d is arm - base, negative for a drop)
  within(se, d) a guard "within base +- k se":           x = k se, clear = x - |d|

where the bar's own k is passed (1.645 unless the bar said 2). When a bar gave only its LIMIT (a band of +-123, a
line of +5.8), se = limit / k. Where the rows are on main the row readers are used instead (`terminus`, `bridge108`,
`arrive`, `cells`, `guard_line`). Counts carry `fisher` / `mcnemar`; deterministic cells, named cases and lines whose
table printed no se carry `none`.

A verdict starting with PASS / FAIL counts as judged; NULL (a precondition the bar named was not met), NOT READABLE
(R32.7) and REPORTED do not.
"""
K = 1.645

R31 = "_agents/streams/references/round31/"
R32 = "_agents/streams/references/round32/"
R33 = "references/round33/"
WS = "_agents/workstreams.md"


def L(**kw):
    kw.setdefault("machine", "builder0")
    kw.setdefault("noise", {"kind": "none"})
    return kw


def se_line(se, x, clear, note=None):
    out = {"kind": "se", "se": se, "x": x, "clear": clear}
    if note:
        out["note"] = note
    return out


def up(se, d, k=K, **kw):
    return se_line(se, k * se, k * se - d, **kw)


def down(se, d, k=K, **kw):
    return se_line(se, k * se, d + k * se, **kw)


def gain(se, d, k=K, **kw):
    return se_line(se, k * se, -d - k * se, **kw)


def gain_up(se, d, x, **kw):
    """A gain line with a fixed needed rise x (B9's E > +0.511)."""
    return se_line(se, x, d - x, **kw)


def within(se, d, k=K, **kw):
    return se_line(se, k * se, k * se - abs(d), **kw)


def limit(lim, d, k=K, **kw):
    """A guard quoted only by its limit (arm - base <= lim): se = lim / k."""
    return se_line(lim / k, lim, lim - d, **kw)


def band(lim, d, k=K, **kw):
    """A two-sided guard quoted only by its band (+-lim)."""
    return se_line(lim / k, lim, lim - abs(d), **kw)


CENSUS_KEY = ["arena", "seed", "credits", "units"]


def T(base, arm, case, metric, stat, x, pass_dir, **kw):
    """A traffic-series line read from rows (lines.py's T)."""
    return dict(kind="traffic", base=base, arm=arm, case=case, metric=metric, stat=stat, x=x, pass_dir=pass_dir, **kw)


def J(base, arm, metric, pass_dir, key=CENSUS_KEY, **kw):
    return dict(kind="jsonl", base=base, arm=arm, key=key, metric=metric, pass_dir=pass_dir, **kw)


def TM(path, squad, metric, pass_dir, **kw):
    return dict(kind="terminus", path=path, squad=squad, metric=metric, pass_dir=pass_dir, **kw)


def G(path, tag, name, pass_dir, x_se=K, **kw):
    return dict(kind="guard_line", path=path, tag=tag, name=name, pass_dir=pass_dir, x_se=x_se, **kw)


DET = {"kind": "none", "note": "deterministic cells or a named case: not a sample"}
LINES = []

# ---------------------------------------------------------------- round 31 --------------------------------------
src31 = WS + " Round 31 Bars"
T3BC_B, T3BC_A = R31 + "traffic/t3bc_judged_base_f5dc4147_seeds414243.jsonl", R31 + "traffic/t3bc_judged_arm_f5dc4147_seeds414243.jsonl"
t3bc = src31 + " 'Traffic T3b-c bar' JUDGED; " + R31 + "traffic/t3bc_verdict_f5dc4147.txt (copied from round31/traffic, PROVENANCE.md)"
LINES += [
    L(round=31, stream="traffic", item="T3b-c", commit="f5dc4147", line="(2) Terminus crossing clock: mean paired diff <= 0.10 x base median + 1.645 se",
      form="mean", n="18 runs paired (seeds 41-43 x 6)", rule="<= +2.07 s", base="median 11.7 s", arm="+2.61 s (se 0.55)", verdict="FAIL",
      source=t3bc, noise=se_line(0.55, 2.07, 2.07 - 2.61)),
    L(round=31, stream="traffic", item="T3b-c", commit="f5dc4147", line="(2) yard crossing clock: mean paired diff <= 3.0 s + 1.645 se (his call)",
      form="mean", n="18 runs paired", rule="<= +3.43 s", base="-", arm="+3.38 s (se 0.26)", verdict="PASS",
      source=t3bc, noise=se_line(0.26, 3.43, 3.43 - 3.38)),
    L(round=31, stream="traffic", item="T3b-c", commit="f5dc4147", line="(1) between-squad fast pooled over the crossings down >= 25 %",
      form="total", n="36 runs paired", rule="<= 143", base="(rows)", arm="(rows; -39 %)", verdict="PASS", source=t3bc,
      noise=T(T3BC_B, T3BC_A, ["terminus/cross", "yard_open/cross"], "xfast", "total", 0.25 * 191, "down")),
    L(round=31, stream="traffic", item="T3b-c", commit="f5dc4147", line="(3) Terminus crossing crews >= base - 1.645 se",
      form="total", n="18 runs paired", rule=">= base - 1.645 se", base="(rows)", arm="(rows)", verdict="PASS", source=t3bc,
      noise=T(T3BC_B, T3BC_A, "terminus/cross", "arrived", "total", None, "notdown", x_se=K)),
    L(round=31, stream="traffic", item="T3b-c", commit="f5dc4147", line="(3) yard crossing crews >= base - 1.645 se",
      form="total", n="18 runs paired", rule=">= base - 1.645 se", base="(rows)", arm="(rows)", verdict="PASS", source=t3bc,
      noise=T(T3BC_B, T3BC_A, "yard_open/cross", "arrived", "total", None, "notdown", x_se=K)),
    L(round=31, stream="traffic", item="T3b-c", commit="f5dc4147", line="(4)-(6) no wedge, same-squad fast, the head-on cases",
      form="deterministic", n="18 runs a case", rule="as round 30's T3b", base="-", arm="all met (the base had two wedges, the arm none)",
      verdict="PASS", source=t3bc, noise={"kind": "none"}),
]
T1_B, T1_A = R31 + "traffic/t1cb2_judged_census_base_33cb2da5_seeds41-46.jsonl", R31 + "traffic/t1cb2_judged_census_arm_33cb2da5_seeds41-46.jsonl"
t1cb2 = src31 + " 'Traffic T1c-b2 bar'; base and arm REPORTED; " + R31 + "traffic/t1cb2_* (copied from round31/traffic)"
LINES += [
    L(round=31, stream="traffic", item="T1c-b2", commit="33cb2da5", line="(1) DECIDING runs with a repack while firing: arm 0/18, Fisher p <= 0.05, base >= 8/18",
      form="count-runs", n="18 runs an arm (seeds 41-46 x 3 arenas)", rule="0/18; base >= 8/18", base="6/18", arm="0/18 (p 0.0095)",
      verdict="NULL (the base read 6/18, under the filed precondition; parked as filed, lesson 300)", source=t1cb2,
      noise={"kind": "fisher", "a": 0, "n1": 18, "c": 6, "n2": 18}),
    L(round=31, stream="traffic", item="T1c-b2", commit="33cb2da5", line="(2) friendly-stuck <= base + 1.645 se (row sd 32.2 -> +225)",
      form="total", n="18 runs paired", rule="<= base + 225", base="746", arm="787 (+41)", verdict="REPORTED (line (1) NULL)",
      source=t1cb2, noise=J(T1_B, T1_A, "stuck_friend_s", "notup", x=225.0)),
    L(round=31, stream="traffic", item="T1c-b2", commit="33cb2da5", line="(3) fast friendly <= base + 1.645 se (sd 6.84 -> +47.7)",
      form="total", n="18 runs paired", rule="<= base + 47.7", base="1021", arm="997 (-24)", verdict="REPORTED (line (1) NULL)",
      source=t1cb2, noise=J(T1_B, T1_A, "contacts_friend_fast", "notup", x=47.7)),
    L(round=31, stream="traffic", item="T1c-b2", commit="33cb2da5", line="(4) artillery shots, REPORTED before numbers",
      form="total", n="18 runs paired", rule="-", base="434", arm="437", verdict="REPORTED",
      source=t1cb2, noise=J(T1_B, T1_A, "art_shots", "notdown", x=0.0)),
]
m1b2 = src31 + " 'Manoeuvre M1b(2)' JUDGED run 1 / attempt 2; " + R31 + "manoeuvre/m1b2_*"
LINES += [
    L(round=31, stream="manoeuvre", item="M1b(2) run 1", commit="6efd1ed9", line="(a) attack-move, wheeled turret at rest: median <= 15 deg AND >= 70 % within 15 deg",
      form="share", n="144 runs an arm (hull-rest 76-81)", rule="<= 15 deg; >= 70 %", base="-", arm="4.6 deg; 78 %", verdict="PASS", source=m1b2),
    L(round=31, stream="manoeuvre", item="M1b(2) run 1", commit="6efd1ed9", line="(a) move, wheeled turret at rest: median <= 15 deg AND >= 70 % within 15 deg",
      form="share", n="144 runs an arm", rule="<= 15 deg; >= 70 %", base="32 % within", arm="4.3 deg; 68 %", verdict="FAIL", source=m1b2),
    L(round=31, stream="manoeuvre", item="M1b(2) run 1", commit="6efd1ed9", line="(a) right, wheeled turret at rest: median <= 15 deg AND >= 70 % within 15 deg",
      form="share", n="144 runs an arm", rule="<= 15 deg; >= 70 %", base="31 % within", arm="6.9 deg; 55 %", verdict="FAIL", source=m1b2),
    L(round=31, stream="manoeuvre", item="M1b(2) run 1", commit="6efd1ed9", line="(b) drawn line tasks: hull error not worse (permutation p >= 0.05)",
      form="median", n="144 runs an arm", rule="p >= 0.05", base="66.3 / 37.0 / 73.6 deg", arm="27.6 / 27.4 / 28.6 (p < 0.01, better)", verdict="PASS", source=m1b2),
    L(round=31, stream="manoeuvre", item="M1b(2) run 1", commit="6efd1ed9", line="(d) crews still moving at 75 s, every task: <= base + 1.645 se (M1_CLASS's se)",
      form="total", n="144 runs an arm", rule="<= +1.645 se", base="(M1_MOVING)", arm="every task under its line (ambush by 0.4)", verdict="PASS", source=m1b2,
      noise={"kind": "none", "note": "per-task margins not all quoted; the closest was ambush, 0.4 inside"}),
    L(round=31, stream="manoeuvre", item="M1b(2) run 1", commit="6efd1ed9", line="(g) Terminus mixed arrivals not down beyond 1.645 se",
      form="total", n="13 seeds paired (93-105)", rule=">= base - 1.645 se", base="292/312", arm="293/312", verdict="PASS", source=m1b2,
      noise=TM(R31 + "manoeuvre/m1b2_terminus_judged.txt", "mixed", "arrived", "notdown", x_se=K)),
    L(round=31, stream="manoeuvre", item="M1b(2) run 1", commit="6efd1ed9", line="(g) Terminus rigs arrivals not down beyond 1.645 se",
      form="total", n="13 seeds paired", rule=">= base - 1.645 se", base="175/208", arm="183/208", verdict="PASS", source=m1b2,
      noise=TM(R31 + "manoeuvre/m1b2_terminus_judged.txt", "rigs", "arrived", "notdown", x_se=K)),
    L(round=31, stream="manoeuvre", item="M1b(2) run 1", commit="6efd1ed9", line="(f) bridge-pooled 18/18",
      form="deterministic", n="18 cells", rule="18/18", base="18/18", arm="18/18", verdict="PASS", source=m1b2, noise=DET),
    L(round=31, stream="manoeuvre", item="M1b(2) attempt 2", commit="25ef8f7e", line="(g) Terminus mixed arrivals not down beyond 1.645 se",
      form="total", n="13 seeds paired (146-158)", rule=">= base - 7.5", base="293/312", arm="285/312 (-8, se 4.55)", verdict="FAIL", source=m1b2,
      noise=TM(R31 + "manoeuvre/m1b2_run2_terminus_judged.txt", "mixed", "arrived", "notdown", x_se=K)),
    L(round=31, stream="manoeuvre", item="M1b(2) attempt 2", commit="25ef8f7e", line="(g) Terminus rigs arrivals not down beyond 1.645 se",
      form="total", n="13 seeds paired", rule=">= base - 1.645 se", base="177/208", arm="179/208", verdict="PASS", source=m1b2,
      noise=TM(R31 + "manoeuvre/m1b2_run2_terminus_judged.txt", "rigs", "arrived", "notdown", x_se=K)),
]
cph = src31 + " 'Manoeuvre CP-H bar' VERDICT; " + R31 + "manoeuvre/cph_*.txt (several arms per file: printed se)"
LINES += [
    L(round=31, stream="manoeuvre", item="CP-H", commit="130a069b", line="(a) Terminus mixed arrivals not down beyond 1.645 se",
      form="total", n="13 seeds paired (110-122)", rule=">= base - 8.2", base="285/312", arm="286/312 (+1, se 4.98)", verdict="PASS", source=cph, noise=down(4.98, 1.0)),
    L(round=31, stream="manoeuvre", item="CP-H", commit="130a069b", line="(a) Terminus rigs arrivals not down beyond 1.645 se",
      form="total", n="13 seeds paired", rule=">= base - 7.0", base="181/208", arm="177/208 (-4, se 4.26)", verdict="PASS", source=cph, noise=down(4.26, -4.0)),
    L(round=31, stream="manoeuvre", item="CP-H", commit="130a069b", line="(b) Terminus mixed wall contact-ticks <= base + 1.645 se",
      form="total", n="13 seeds paired", rule="<= base + 356", base="1979", arm="2158 (+179, se 216.6)", verdict="PASS", source=cph, noise=up(216.6, 179.0)),
    L(round=31, stream="manoeuvre", item="CP-H", commit="130a069b", line="(b) Terminus rigs wall contact-ticks <= base + 1.645 se",
      form="total", n="13 seeds paired", rule="<= base + 4144", base="6800", arm="8914 (+2114, se 2519)", verdict="PASS", source=cph, noise=up(2519.2, 2114.0)),
    L(round=31, stream="manoeuvre", item="CP-H", commit="130a069b", line="(c) hull-rest pinned crew-seconds, hulls <= 10 m: DOWN beyond 2 se",
      form="total", n="144 runs paired (84-89)", rule="< -2 se", base="2453", arm="307 (-2146, se 426)", verdict="PASS", source=cph, noise=gain(426.3, -2146.0, k=2.0)),
    L(round=31, stream="manoeuvre", item="CP-H", commit="130a069b", line="(c) reported: pinned crew-seconds, rigs",
      form="total", n="144 runs paired", rule="-", base="653", arm="26 (se 274)", verdict="REPORTED", source=cph, noise=se_line(273.6, 0.0, 627.0)),
    L(round=31, stream="manoeuvre", item="CP-H", commit="130a069b", line="(d) crews still moving at 75 s per task <= base + 1.645 se (closest: ambush +2 v +5)",
      form="total", n="144 runs paired", rule="<= +1.645 se", base="(M1_MOVING)", arm="ambush +2; the rest -8 to -14", verdict="PASS", source=cph, noise=limit(5.0, 2.0)),
    L(round=31, stream="manoeuvre", item="CP-H", commit="130a069b", line="(e) reported: stuck crew-seconds",
      form="total", n="144 runs paired", rule="-", base="6578", arm="3737 (se 709)", verdict="REPORTED", source=cph, noise=se_line(708.6, 0.0, 2841.0)),
    L(round=31, stream="manoeuvre", item="CP-H", commit="130a069b", line="(g) fights kills within 1.645 se",
      form="total", n="24 fights paired (214-237)", rule="within 1.645 se", base="987", arm="1001 (+14, se 14.9)", verdict="PASS", source=cph, noise=within(14.9, 14.0)),
    L(round=31, stream="manoeuvre", item="CP-H", commit="130a069b", line="(g) fights deaths within 1.645 se",
      form="total", n="24 fights paired", rule="within 1.645 se", base="996", arm="1013 (+17, se 15.4)", verdict="PASS", source=cph, noise=within(15.4, 17.0)),
    L(round=31, stream="manoeuvre", item="CP-H", commit="130a069b", line="(g) fights hit rate within 1.645 se",
      form="mean", n="24 fights paired", rule="within 1.645 se", base="0.677", arm="0.689 (+0.012, se 0.019)", verdict="PASS", source=cph, noise=within(0.019, 0.012)),
    L(round=31, stream="manoeuvre", item="CP-H", commit="130a069b", line="(f) bridge-pooled 18/18; (h) the whole suite on native's ON pair",
      form="deterministic", n="18 cells; the suite", rule="18/18; green", base="-", arm="18/18; 2641/0", verdict="PASS", source=cph, noise=DET),
]
b3b2b = src31 + " 'Brains B3b-2b' JUDGED; " + R31 + "brains/b3b2b-*"
LINES += [
    L(round=31, stream="brains", item="B3b-2b", commit="5ed61f91", line="(1) his bridge, the full 108: on 108/108",
      form="deterministic", n="108 cells", rule="108/108", base="106/108", arm="108/108", verdict="PASS", source=b3b2b,
      noise={"kind": "bridge108", "control": R31 + "brains/b3b2b-b108-ctrl.jsonl", "on": R31 + "brains/b3b2b-b108-on.jsonl"}),
    L(round=31, stream="brains", item="B3b-2b", commit="5ed61f91", line="(3) arrive series: every crew within 8 m on >= control - 1 AND discordant against <= 1",
      form="count-cells", n="100 cells paired (seeds 41-44)", rule=">= 96; against <= 1", base="97/100", arm="90/100 (9 against v 2 for)", verdict="FAIL",
      source=b3b2b, noise={"kind": "mcnemar", "b": 2, "c": 9}),
    L(round=31, stream="brains", item="B3b-2b", commit="5ed61f91", line="(3) reported: all-within-8 m paired median over the cells complete in both arms",
      form="median", n="cells complete in both", rule="-", base="(rows)", arm="(rows)", verdict="REPORTED", source=b3b2b,
      noise={"kind": "arrive", "off": R31 + "brains/b3b2b-arrive-ctrl.jsonl", "on": R31 + "brains/b3b2b-arrive-on.jsonl",
             "metric": "all_in8_s", "stat": "median", "x_share": 0.02, "pass_dir": "notup"}),
    L(round=31, stream="brains", item="B3b-2b", commit="5ed61f91", line="(2) bridge-pooled 18/18; (4) crossing counters > 0 on the 108, 0 on the arrive runs",
      form="deterministic", n="18 cells; 308 runs", rule="all", base="-", arm="met", verdict="PASS", source=b3b2b, noise=DET),
]
cpp1 = src31 + " 'Planner CP-P1 bar' JUDGED runs 1 and 2, VERDICT; references/round31/planner/series2-fresh/"
LINES += [
    L(round=31, stream="planner", item="CP-P1 run 1", commit="0fcdd5dd", line="(a) Terminus rig arrivals: mean paired not down beyond 1.645 se",
      form="mean", n="13 seeds paired (133-145)", rule=">= -0.979 a seed", base="178/208", arm="159/208 (-1.462 a seed, se 0.595)", verdict="FAIL",
      source=cpp1, noise=se_line(0.595, 0.979, -1.462 + 0.979)),
    L(round=31, stream="planner", item="CP-P1 run 2", commit="35f5df92", line="(a) Terminus rig arrivals: mean paired not down beyond 1.645 se",
      form="mean", n="13 seeds paired (172-184)", rule=">= -0.823 a seed", base="180/208", arm="172/208 (-0.615 a seed, se 0.500)", verdict="PASS",
      source=cpp1, noise=se_line(0.500, 0.823, -0.615 + 0.823)),
    L(round=31, stream="planner", item="CP-P1 run 2", commit="35f5df92", line="(a) mixed squad: identical both arms (the seam never fires: a leak check)",
      form="deterministic", n="13 seeds", rule="identical", base="289/312", arm="289/312", verdict="PASS", source=cpp1, noise=DET),
    L(round=31, stream="planner", item="CP-P1 run 2", commit="35f5df92", line="(b) rig wall contact-ticks: arm <= base + 1.645 se (paired a seed)",
      form="mean", n="13 seeds paired", rule="<= +347 a seed", base="median 855", arm="median 533 (paired -282.2, se 211.2)", verdict="PASS",
      source=cpp1, noise=up(211.2, -282.2)),
    L(round=31, stream="planner", item="CP-P1 run 2", commit="35f5df92", line="(d) wheeled turret crews moving at 75 s per task <= base + 1.645 se (closest attack_move)",
      form="total", n="144 runs paired (hull-rest 60-65)", rule="<= +9.05", base="-", arm="+8", verdict="PASS", source=cpp1, noise=limit(9.05, 8.0)),
    L(round=31, stream="planner", item="CP-P1 run 2", commit="35f5df92", line="(d) wheeled turret crews moving at 75 s, SBF <= base + 1.645 se",
      form="total", n="144 runs paired", rule="<= +8.39", base="-", arm="+8", verdict="PASS", source=cpp1, noise=limit(8.39, 8.0)),
    L(round=31, stream="planner", item="CP-P1 run 2", commit="35f5df92", line="(e) fights kills within 1.645 se",
      form="mean", n="24 fights paired (181-204)", rule="within 1.645 se", base="-", arm="-4 (se 4.5)", verdict="PASS", source=cpp1, noise=within(4.5, -4.0)),
    L(round=31, stream="planner", item="CP-P1 run 2", commit="35f5df92", line="(e) fights deaths within 1.645 se",
      form="mean", n="24 fights paired", rule="within 1.645 se", base="-", arm="-4 (se 3.4)", verdict="PASS", source=cpp1, noise=within(3.4, -4.0)),
    L(round=31, stream="planner", item="CP-P1 run 2", commit="a1d9e1fc", line="(f) cost: SLICE x warm per-expansion median <= 0.5 ms (not in the ship clause)",
      form="deterministic", n="2 seeds (pinned 0-3)", rule="<= 0.5 ms", base="-", arm="0.526 ms (92721, load 16.7); 0.372 (31337)",
      verdict="FAIL (not in the ship clause; an upper bound, R31.6)", source=cpp1, noise={"kind": "none"}),
    L(round=31, stream="planner", item="CP-P1 run 2", commit="35f5df92", line="(c) scenario_cp2 identical; (e) bridge 18/18; the rig 180 deg",
      form="deterministic", n="cells", rule="all", base="-", arm="met", verdict="PASS", source=cpp1, noise=DET),
]
v5 = src31 + " 'Brains B5c-v5 bar' JUDGED; " + R31 + "brains/b5c-v5-*-e675a28a"
LINES += [
    L(round=31, stream="brains", item="B5c-v5", commit="e675a28a", line="(1) pursuit: >= 21/24 as written AND >= 19/24 nudged",
      form="deterministic", n="24 cells x 2", rule=">= 21; >= 19", base="-", arm="24/24; 24/24", verdict="PASS", source=v5, noise=DET),
    L(round=31, stream="brains", item="B5c-v5", commit="e675a28a", line="(2) yard crossing: runs with every crew in on >= off (DECIDING)",
      form="count-runs", n="12 runs an arm (seeds 27-28 x 6)", rule=">= off", base="1/12", arm="11/12", verdict="PASS", source=v5,
      noise={"kind": "fisher", "a": 11, "n1": 12, "c": 1, "n2": 12}),
    L(round=31, stream="brains", item="B5c-v5", commit="e675a28a", line="(3) Sumps all-within-8 m median on <= off",
      form="median", n="12 runs paired (seeds 16-17 x 6)", rule="<= off", base="24.9 s", arm="24.8 s", verdict="PASS", source=v5,
      noise={"kind": "cells", "path": R31 + "brains/b5c-v5-gate-sumps-terminus-e675a28a.jsonl", "cell": "sumps", "metric": "all_in8_or_end",
             "stat": "median", "x": 0.0, "pass_dir": "notup"}),
    L(round=31, stream="brains", item="B5c-v5", commit="e675a28a", line="(3) Sumps: no run more than 5 s later",
      form="deterministic", n="12 runs", rule="0 runs > +5 s", base="-", arm="s17 t11 58.3 v 36.0 s (+22.3)", verdict="FAIL", source=v5, noise=DET),
    L(round=31, stream="brains", item="B5c-v5", commit="e675a28a", line="(3) Sumps guns_on_arc >= off - 0.05",
      form="mean", n="12 runs paired", rule=">= off - 0.05", base="0.939", arm="0.939", verdict="PASS", source=v5,
      noise={"kind": "cells", "path": R31 + "brains/b5c-v5-gate-sumps-terminus-e675a28a.jsonl", "cell": "sumps", "metric": "guns_on_arc",
             "stat": "mean", "x": 0.05, "pass_dir": "notdown"}),
]

# ---------------------------------------------------------------- round 32 --------------------------------------
src32 = WS + " Round 32 Bars"
R32T = "references/round32/traffic/"
T3R_B, T3R_A = R32T + "t3bc_r32_base_b5882c9c.jsonl.gz", R32T + "t3bc_r32_arm_b5882c9c.jsonl.gz"
t3r32 = src32 + " C32.1; HANDOFF 'T3b-c SHIPPED ON'; " + R32T + "t3bc_r32_verdict_b5882c9c.txt"
LINES += [
    L(round=32, stream="traffic", item="T3b-c re-judge (C32.1)", commit="b5882c9c", line="(2) Terminus crossing clock: mean paired <= 3.0 s + 1.645 se (his round-32 yes)",
      form="mean", n="18 runs paired (seeds 41-43 x 6)", rule="<= +3.90 s", base="median 11.7 s", arm="+2.61 s (se 0.55)", verdict="PASS",
      source=t3r32, noise=se_line(0.55, 3.90, 3.90 - 2.61)),
    L(round=32, stream="traffic", item="T3b-c re-judge (C32.1)", commit="b5882c9c", line="(2) yard crossing clock: mean paired <= 3.0 s + 1.645 se",
      form="mean", n="18 runs paired", rule="<= +3.43 s", base="median 8.1 s", arm="+3.38 s (se 0.26)", verdict="PASS",
      source=t3r32, noise=se_line(0.26, 3.43, 3.43 - 3.38)),
    L(round=32, stream="traffic", item="T3b-c re-judge (C32.1)", commit="b5882c9c", line="(1) between-squad fast pooled over the crossings down >= 25 %",
      form="total", n="36 runs paired", rule="<= 143", base="(rows)", arm="(rows; -39 %)", verdict="PASS", source=t3r32,
      noise=T(T3R_B, T3R_A, ["terminus/cross", "yard_open/cross"], "xfast", "total", 0.25 * 191, "down")),
    L(round=32, stream="traffic", item="T3b-c re-judge (C32.1)", commit="b5882c9c", line="Terminus head-on crews >= base - 1.645 se",
      form="total", n="18 runs paired", rule=">= base - 6.81", base="(rows)", arm="(rows)", verdict="PASS", source=t3r32,
      noise=T(T3R_B, T3R_A, "terminus/head", "arrived", "total", None, "notdown", x_se=K)),
]
T1R_B, T1R_A = R32T + "t1cb2_r32_census_base_cf81aedc.jsonl.gz", R32T + "t1cb2_r32_census_arm_cf81aedc.jsonl.gz"
t1r32 = src32 + " C32.1; HANDOFF 'T1c-b2 re-judged PASS'; " + R32T + "t1cb2_r32_*_cf81aedc"
LINES += [
    L(round=32, stream="traffic", item="T1c-b2 re-judge (C32.1)", commit="cf81aedc", line="(1) DECIDING runs with a repack while firing: arm 0/18, Fisher p <= 0.05",
      form="count-runs", n="18 runs an arm (census s41-46 x 3)", rule="0/18; p <= 0.05", base="5/18", arm="0/18 (p 0.023)", verdict="PASS", source=t1r32,
      noise={"kind": "fisher", "a": 0, "n1": 18, "c": 5, "n2": 18}),
    L(round=32, stream="traffic", item="T1c-b2 re-judge (C32.1)", commit="cf81aedc", line="(2) friendly-stuck <= base + 225",
      form="total", n="18 runs paired", rule="<= base + 225", base="(rows)", arm="(rows)", verdict="PASS", source=t1r32,
      noise=J(T1R_B, T1R_A, "stuck_friend_s", "notup", x=225.0)),
    L(round=32, stream="traffic", item="T1c-b2 re-judge (C32.1)", commit="cf81aedc", line="(3) fast friendly <= base + 47.7",
      form="total", n="18 runs paired", rule="<= base + 47.7", base="(rows)", arm="(rows)", verdict="PASS", source=t1r32,
      noise=J(T1R_B, T1R_A, "contacts_friend_fast", "notup", x=47.7)),
]
b3b2c = src32 + " 'B3b-2c'; HANDOFF 'B3b-2c SHIPPED ON'; " + R32 + "brains/b3b2c-*-cbddb940"
LINES += [
    L(round=32, stream="brains", item="B3b-2c", commit="5f0ed865", line="(1) his bridge, the full 108: on 108/108 or >= control",
      form="deterministic", n="108 cells", rule="108/108", base="107/108", arm="108/108", verdict="PASS", source=b3b2c,
      noise={"kind": "bridge108", "control": R32 + "brains/b3b2c-b108-ctrl-cbddb940.jsonl", "on": R32 + "brains/b3b2c-b108-on-cbddb940.jsonl"}),
    L(round=32, stream="brains", item="B3b-2c", commit="5f0ed865", line="(3) arrive series: on >= control - 1 AND discordant against <= 1",
      form="count-cells", n="100 cells paired (seeds 45-48)", rule=">= 89; against <= 1", base="90/100", arm="90/100 (0 v 0 discordant)", verdict="PASS",
      source=b3b2c, noise={"kind": "mcnemar", "b": 0, "c": 0}),
    L(round=32, stream="brains", item="B3b-2c", commit="5f0ed865", line="(3) reported: the paired all-within-8 m median",
      form="median", n="cells complete in both", rule="<= +2 % (reported)", base="(rows)", arm="(rows)", verdict="REPORTED", source=b3b2c,
      noise={"kind": "arrive", "off": R32 + "brains/b3b2c-arrive-ctrl-cbddb940.jsonl", "on": R32 + "brains/b3b2c-arrive-on-cbddb940.jsonl",
             "metric": "all_in8_s", "stat": "median", "x_share": 0.02, "pass_dir": "notup"}),
]
cpq = src32 + " 'CP-Q' JUDGED"
LINES += [
    L(round=32, stream="planner", item="CP-Q", commit="65cc43dd", line="(1) abandoned <= 5 % of asks, drawn and clicked",
      form="share", n="hull-rest gangs 66-71", rule="<= 5 % each", base="18.6 % / 14.5 %", arm="1.0 % / 3.7 %", verdict="PASS", source=cpq),
    L(round=32, stream="planner", item="CP-Q", commit="65cc43dd", line="(3) faced_move crews moving at 75 s <= base + 1.645 se",
      form="total", n="hull-rest, a task", rule="<= +2.96", base="-", arm="+5", verdict="FAIL", source=cpq, noise=limit(2.96, 5.0)),
    L(round=32, stream="planner", item="CP-Q", commit="65cc43dd", line="(3) faced_screen crews moving at 75 s <= base + 1.645 se",
      form="total", n="hull-rest, a task", rule="<= +2.14", base="-", arm="+3", verdict="FAIL", source=cpq, noise=limit(2.14, 3.0)),
    L(round=32, stream="planner", item="CP-Q", commit="65cc43dd", line="(3) faced SBF drawn at-rest error not worse (p >= 0.05)",
      form="median", n="hull-rest, a task", rule="p >= 0.05", base="74.3 deg", arm="106.8 deg (p 0.035)", verdict="FAIL", source=cpq,
      noise={"kind": "none", "note": "a permutation p; P1's A/A later showed round 32's (3) misses inside the probe's null swing (R33.13's bar)"}),
    L(round=32, stream="planner", item="CP-Q", commit="65cc43dd", line="(4) Terminus rig arrivals not down beyond 1.645 se",
      form="total", n="13 seeds paired (205-217)", rule=">= base - 1.645 se", base="180", arm="187", verdict="PASS", source=cpq),
]
b10 = src32 + " 'B10' JUDGED; " + R32 + "brains/b10-*-8e43cc5c"
LINES += [
    L(round=32, stream="brains", item="B10", commit="8e43cc5c", line="(1) flipping-crew runs on <= off AND drift on < off",
      form="total", n="28 runs an arm", rule="<=; <", base="2; 138", arm="0; 107", verdict="PASS", source=b10),
    L(round=32, stream="brains", item="B10", commit="8e43cc5c", line="(2) Sumps: no run more than 5 s later",
      form="deterministic", n="12 runs", rule="0 runs > +5 s", base="69.4 s (s19 t8)", arm="89.3 s (+19.9)", verdict="FAIL", source=b10, noise=DET),
    L(round=32, stream="brains", item="B10", commit="8e43cc5c", line="(3) arrive: on >= off - 1, discordant against <= 1",
      form="count-cells", n="100 cells paired (49-52)", rule=">= 92", base="93/100", arm="93/100 (0 v 0)", verdict="PASS", source=b10,
      noise={"kind": "mcnemar", "b": 0, "c": 0}),
]
t4r32 = src32 + " 'T4-ON' JUDGED; references/round32/traffic/t4_r32/"
LINES += [
    L(round=32, stream="traffic", item="T4-ON", commit="0adc6deb", line="(1) DECIDING mixed stuck crew-s down beyond 1.645 se",
      form="total", n="24 seeds paired (41-64)", rule="< -347", base="607", arm="313 (-294, se 211)", verdict="FAIL", source=t4r32, noise=gain(211.0, -294.0)),
    L(round=32, stream="traffic", item="T4-ON", commit="0adc6deb", line="(5) yard head-on between-squad fast within T3b-c's guard",
      form="total", n="18 runs paired", rule="<= base + 5.8", base="53", arm="59 (+6)", verdict="FAIL", source=t4r32, noise=limit(5.8, 6.0)),
    L(round=32, stream="traffic", item="T4-ON", commit="0adc6deb", line="(5) yard head-on all-in median within T3b-c's guard",
      form="median", n="18 runs paired", rule="<= base + 3.82 s", base="33.8 s", arm="38.0 s (+4.2)", verdict="FAIL", source=t4r32, noise=limit(3.82, 4.2)),
    L(round=32, stream="traffic", item="T4-ON", commit="0adc6deb", line="(2) rigs stuck not up; (3) pinned not up; (4) arrivals",
      form="total", n="24 seeds paired", rule="<= base + 1.645 se", base="627; 316", arm="459; 17", verdict="PASS", source=t4r32),
]
b11 = src32 + " 'B11' JUDGED; " + R32 + "brains/b11-*-ffba7f77"
LINES += [
    L(round=32, stream="brains", item="B11", commit="ffba7f77", line="(1) DECIDING crews > 90 deg off, pooled, on < off",
      form="total", n="144 runs an arm (350-355)", rule="<", base="391", arm="377", verdict="PASS", source=b11),
    L(round=32, stream="brains", item="B11", commit="ffba7f77", line="(2) s66 Green_Guns_5 <= 90 deg in >= 2 of 3 on-repeats",
      form="deterministic", n="3 repeats", rule=">= 2 of 3", base="-", arm="104.5 / 125.8 / 122.4 deg", verdict="FAIL", source=b11, noise=DET),
    L(round=32, stream="brains", item="B11", commit="ffba7f77", line="(3) no class's median worse (p < 0.05): wheels/fixed faced_move",
      form="median", n="144 runs an arm", rule="p >= 0.05", base="3.0 deg", arm="7.5 deg (p 0.000)", verdict="FAIL", source=b11,
      noise={"kind": "none", "note": "a permutation p"}),
    L(round=32, stream="brains", item="B11", commit="ffba7f77", line="(3) never-settled on <= off + 2",
      form="total", n="144 runs an arm", rule="<= off + 2", base="73", arm="85", verdict="FAIL", source=b11),
]
swap = src32 + " 'C32.10 seat swap' amended G, JUDGED; archive/round32/manoeuvre.md"
LINES += [
    L(round=32, stream="manoeuvre", item="C32.10 swap", commit="a13a9399", line="G: swap-arm far loops <= 50 % of the h1b arm's AND swaps taken >= 1",
      form="total", n="24 fights (400-423)", rule="<= 3; >= 1", base="6", arm="6; swaps 0 (all 24 fights bit-identical)", verdict="FAIL",
      source=swap, noise={"kind": "none", "note": "identical arms: the swap never arose (an equality, not a sample)"}),
]
h1b = src32 + " 'H1b'; R32.7; archive/round32/manoeuvre.md 'H1b report'"
LINES += [
    L(round=32, stream="manoeuvre", item="H1b", commit="273654e6", line="(1) loops - far = 0 and far <= base (fresh Terminus, named hunt seeds, fights)",
      form="deterministic", n="13 + 20 + 3 cells", rule="0; <=", base="137 rigs", arm="0 every cell; far 101 rigs, 12 mixed", verdict="PASS", source=h1b, noise=DET),
    L(round=32, stream="manoeuvre", item="H1b", commit="273654e6", line="(2) hull-rest pinned crew-s (<= 10 m) <= base + 1.645 se",
      form="total", n="144 runs paired (313-318)", rule="<= base + 351", base="545", arm="366 (-179, se 213.3)", verdict="PASS", source=h1b, noise=up(213.3, -179.0)),
    L(round=32, stream="manoeuvre", item="H1b", commit="273654e6", line="(2) hull-rest stuck crew-s <= base + 1.645 se (R32.7's fixed reader)",
      form="total", n="144 runs paired", rule="<= 3300", base="2598", arm="3233 (+635, se 427.0)", verdict="PASS", source=h1b, noise=up(427.0, 635.0)),
    L(round=32, stream="manoeuvre", item="H1b", commit="273654e6", line="(3) Terminus STUCK on 300-312 (the reader defective after its number)",
      form="total", n="13 seeds", rule="<= base + 1.645 se", base="257", arm="380 (as filed); offline 192 -> 121", verdict="NOT READABLE (R32.7)", source=h1b),
    L(round=32, stream="manoeuvre", item="H1b", commit="273654e6", line="(3) Terminus STUCK re-run, fresh 360-372, fixed reader, per squad",
      form="total", n="13 seeds paired", rule="<= base + 1.645 se", base="323; 64", arm="323; 64 (identical)", verdict="PASS", source=h1b,
      noise={"kind": "none", "note": "identical arms (diff 0, se 0): an equality, not a sample"}),
    L(round=32, stream="manoeuvre", item="H1b", commit="273654e6", line="(4) Terminus rig arrivals not down beyond 1.645 se (mean paired)",
      form="mean", n="13 seeds paired (300-312)", rule=">= -0.31 a seed", base="177", arm="179 (+0.15, se 0.19)", verdict="PASS", source=h1b, noise=down(0.19, 0.15)),
    L(round=32, stream="manoeuvre", item="H1b", commit="273654e6", line="(5) fights kills, deaths, hit rate within 1.645 se",
      form="total", n="23 fights paired (320-343)", rule="within 1.645 se", base="914; 918; 0.717", arm="identical", verdict="PASS", source=h1b,
      noise={"kind": "none", "note": "identical arms: an equality, not a sample"}),
]

# ---------------------------------------------------------------- round 33 --------------------------------------
src33 = WS + " Round 33 Bars / Rulings"
b10b = src33 + " R33.18, R33.22; references/round33/brains/b10b_rejudge_f91b61c7_builder2.txt"
LINES += [
    L(round=33, stream="brains", item="B10b", commit="99e867ee", line="(2) Sumps s19 t8: on all-within-8 m <= off + 5 s",
      form="deterministic", n="1 named case (native path)", rule="<= off + 5", base="69.4 s", arm="100.8 s", verdict="FAIL", source=b10b, noise=DET),
    L(round=33, stream="brains", item="B10b re-judge", commit="f91b61c7", line="(3) pooled drift moves on < off (strict)",
      form="total", n="28 runs an arm", rule="<", base="112", arm="112 (all 28 runs identical)", verdict="FAIL", source=b10b, machine="builder2",
      noise={"kind": "none", "note": "identical arms: the latch never acts on main + R4"}),
    L(round=33, stream="brains", item="B10b re-judge", commit="f91b61c7", line="(4) arrive: all-within-8 m on >= off - 1.645 se",
      form="count-cells", n="100 cells paired (53-56)", rule=">= 98.0", base="98/100", arm="98/100 (0 discordant)", verdict="PASS", source=b10b, machine="builder2",
      noise={"kind": "mcnemar", "b": 0, "c": 0}),
]
p2 = src33 + " R33.13"
LINES += [
    L(round=33, stream="planner", item="P2 (CP-Q)", commit="c75f20a6", line="(1) abandoned share <= 5 % AND below base (Fisher one-sided p <= 0.05), drawn",
      form="share", n="72 runs paired (72-83)", rule="p <= 0.05", base="1.0 %", arm="0.9 % (p 0.44)", verdict="FAIL", source=p2),
    L(round=33, stream="planner", item="P2 (CP-Q)", commit="c75f20a6", line="(1) abandoned share <= 5 % AND below base, clicked",
      form="share", n="72 runs paired", rule="p <= 0.05", base="1.6 %", arm="0.9 % (p 0.06)", verdict="FAIL", source=p2),
    L(round=33, stream="planner", item="P2 (CP-Q)", commit="c75f20a6", line="(3a) drawn at-rest hull error: mean paired per-run median diff <= +1.645 se",
      form="mean", n="72 runs paired", rule="<= +4.50 deg", base="-", arm="+5.43 deg", verdict="FAIL", source=p2, noise=limit(4.50, 5.43)),
    L(round=33, stream="planner", item="P2 (CP-Q)", commit="c75f20a6", line="(2) hold medians; (3b) settle; (3c) moving at 75 s",
      form="mean", n="72 runs paired", rule="as filed", base="-", arm="met", verdict="PASS", source=p2),
]
pr = src33 + " R33.12, R33.36, R33.37; _agents/streams/references/round33/traffic/"
LINES += [
    L(round=33, stream="traffic", item="parkedroom v1", commit="aff64e2b", line="L1 gain: parked far loops arm <= 50 % base AND (base - arm) - k se > 0",
      form="total", n="72 fights paired (700-723 x 3)", rule="drop > 33.4", base="22", arm="25 (+3, se 20.3)", verdict="FAIL", source=pr, noise=gain(20.3, 3.0)),
    L(round=33, stream="traffic", item="parkedroom v1", commit="aff64e2b", line="L6 the parked crew back within 3 m of its post at 30 s >= 90 %",
      form="share", n="2175 room give-ways", rule=">= 90 %", base="-", arm="212/2175", verdict="FAIL", source=pr),
    L(round=33, stream="traffic", item="parkedroom v2", commit="e7b202760", line="L1a hold-post loops; L1b parked loops; L2 all far loops",
      form="total", n="144 fights paired (724-771 x 3)", rule="as filed", base="39; 51; 83", arm="1; 39; 95", verdict="PASS", source=pr, machine="builder2"),
    L(round=33, stream="traffic", item="parkedroom v2", commit="e7b202760", line="L3 hit rate within base +- k se (two-sided)",
      form="mean", n="144 fights paired", rule="within", base="0.714", arm="0.731 (better: outside the two-sided line)", verdict="FAIL", source=pr, machine="builder2"),
    L(round=33, stream="traffic", item="parkedroom v2", commit="e7b202760", line="L6 back at the post >= 90 %",
      form="share", n="395 rooms", rule=">= 90 %", base="-", arm="63 %", verdict="FAIL", source=pr, machine="builder2"),
    L(round=33, stream="traffic", item="parkedroom v3", commit="6d0e00652", line="L1a hold-post loops; L1b parked; L2 all far loops; L4; L5",
      form="total", n="144 fights paired (820-867 x 3)", rule="as filed", base="59; 224; 411", arm="18; 63; 201; L4 identical; L5 0/9", verdict="PASS", source=pr, machine="builder2"),
    L(round=33, stream="traffic", item="parkedroom v3", commit="6d0e00652", line="L3 kills no worse: >= base - k se",
      form="total", n="144 fights paired", rule=">= base - 67.3", base="2072", arm="1992 (-80, se 40.9)", verdict="FAIL", source=pr, machine="builder2", noise=down(40.9, -80.0)),
    L(round=33, stream="traffic", item="parkedroom v3", commit="6d0e00652", line="L6 at the post or inside its hold line >= 90 %",
      form="share", n="448 rooms", rule=">= 90 %", base="-", arm="89.96 % (403/448)", verdict="FAIL", source=pr, machine="builder2"),
    L(round=33, stream="traffic", item="item 4 (fire mission)", commit="23251f069", line="line 2 fire-post loops down (as filed: both kinds)",
      form="total", n="72 fights paired (772-795 x 3)", rule="drop > 1.645 se", base="34", arm="29 (se 14.4)", verdict="FAIL", source=pr, machine="builder2", noise=gain(14.4, -5.0)),
    L(round=33, stream="traffic", item="item 4 re-judge", commit="23251f069", line="line 2 IDLE fire-post loops ON = 0 and <= base",
      form="total", n="72 fights paired (796-819 x 3)", rule="= 0", base="20", arm="0 (all kinds 68 -> 11)", verdict="PASS", source=pr, machine="builder2"),
    L(round=33, stream="traffic", item="item 4", commit="23251f069", line="lines 3-6: shots, first shot",
      form="total", n="72 fights paired", rule="as filed", base="595; 2.8 s", arm="594; 2.8 s", verdict="PASS", source=pr, machine="builder2"),
]
t4r33 = src33 + " R33.14, R33.17, R33.30; references/round33/traffic/ov_t4_bar.md"
LINES += [
    L(round=33, stream="traffic", item="T4 body guard", commit="bbb4d2db", line="(2') every cell's body-ON alone_s ghost ON <= ghost OFF + 3.0 s",
      form="deterministic", n="9 cells (seeds 1-3 x 3 fronts)", rule="<= +3.0 s", base="7.0 s (rts_camera s3)", arm="12.5 s", verdict="FAIL", source=t4r33, noise=DET),
    L(round=33, stream="traffic", item="T4 third try", commit="aacdfb4b6", line="G1 median alone_s ghost ON <= OFF + 3 s",
      form="median", n="12 seeds (body_probe children)", rule="<= +3 s", base="15.5 s", arm="14.0 s", verdict="PASS", source=t4r33, machine="builder2", noise=DET),
    L(round=33, stream="traffic", item="T4 third try", commit="aacdfb4b6", line="G2 at most 2 seeds worse by more than 3 s",
      form="count-cells", n="12 seeds", rule="<= 2", base="-", arm="4 (s7 +6.5, s8 +4.0, s9 +3.5, s14 +4.0)", verdict="FAIL", source=t4r33, machine="builder2", noise=DET),
]
cpf = src33 + " R33.21, R33.34; references/round33/manoeuvre/cpf-series/, cpf3b-series/"
LINES += [
    L(round=33, stream="manoeuvre", item="CP-F", commit="b4bf8f2c", line="(a) attack-move wheels/turret >= 70 % within 15 deg",
      form="share", n="144 runs an arm (440-445)", rule=">= 70 %", base="-", arm="69.5 %", verdict="FAIL", source=cpf,
      noise={"kind": "none", "note": "hull-rest ran wall-clock paced on a loaded builder0 (R33.21's caveat)"}),
    L(round=33, stream="manoeuvre", item="CP-F", commit="b4bf8f2c", line="(b) ambush wheels/fixed not worse (p < 0.05)",
      form="median", n="144 runs an arm", rule="p >= 0.05", base="2.6 deg", arm="3.9 deg (p 0.042)", verdict="FAIL", source=cpf),
    L(round=33, stream="manoeuvre", item="CP-F", commit="b4bf8f2c", line="(d) crews still moving: ambush, move, screen <= base + 1.645 se",
      form="total", n="144 runs an arm", rule="<= limits", base="-", arm="+14, +13, +20", verdict="FAIL", source=cpf),
    L(round=33, stream="manoeuvre", item="CP-F", commit="b4bf8f2c", line="(e) never-settled on move <= base + 1.645 se",
      form="total", n="144 runs an arm", rule="<= +2.6", base="-", arm="+3", verdict="FAIL", source=cpf, noise=limit(2.6, 3.0)),
    L(round=33, stream="manoeuvre", item="CP-F", commit="b4bf8f2c", line="(i) fights kills within 1.645 se",
      form="total", n="21 fights paired (470-493)", rule="within 1.645 se", base="(FIGHT_GUARD)", arm="(FIGHT_GUARD)", verdict="PASS", source=cpf,
      noise=G(R33 + "manoeuvre/cpf-series/fights.txt", "FIGHT_GUARD", "kills", "notdown")),
    L(round=33, stream="manoeuvre", item="CP-F", commit="b4bf8f2c", line="(i) fights deaths within 1.645 se",
      form="total", n="21 fights paired", rule="within 1.645 se", base="(FIGHT_GUARD)", arm="(FIGHT_GUARD)", verdict="PASS", source=cpf,
      noise=G(R33 + "manoeuvre/cpf-series/fights.txt", "FIGHT_GUARD", "deaths", "notup")),
    L(round=33, stream="manoeuvre", item="CP-F attempt 3", commit="22e9cab4e", line="(a) within 15 deg: move, right, attack-move >= 70 %",
      form="share", n="64 pairs a task, 21 distinct (460-475)", rule=">= 70 %", base="-", arm="93.8 %, 96.0 %, 80.2 %", verdict="PASS", source=cpf, machine="builder2"),
    L(round=33, stream="manoeuvre", item="CP-F attempt 3", commit="22e9cab4e", line="(d) attack-move, all classes: moving at the judge <= base + 1.645 se",
      form="total", n="21 distinct pairs", rule="<= +6.5", base="-", arm="+7", verdict="FAIL", source=cpf, machine="builder2", noise=limit(6.5, 7.0)),
    L(round=33, stream="manoeuvre", item="CP-F attempt 3", commit="22e9cab4e", line="(j) hull_turns > 0 and hull_holds > 0 (as written)",
      form="deterministic", n="383 judged runs", rule="> 0", base="-", arm="hull_holds 0 (1 run had the quiet enemy in sight)", verdict="FAIL", source=cpf, machine="builder2", noise=DET),
    L(round=33, stream="manoeuvre", item="CP-F attempt 3", commit="22e9cab4e", line="(g) Terminus arrivals, mixed and rigs, not down beyond 1.645 se",
      form="total", n="13 seeds paired", rule=">= base - 1.645 se", base="295; 177", arm="300; 182", verdict="PASS", source=cpf, machine="builder2"),
    L(round=33, stream="manoeuvre", item="CP-F attempt 3", commit="22e9cab4e", line="(i) fights kills within 1.645 se",
      form="total", n="23 fights paired", rule="within 1.645 se", base="(FIGHT_GUARD)", arm="(FIGHT_GUARD)", verdict="PASS", source=cpf, machine="builder2",
      noise=G(R33 + "manoeuvre/cpf3b-series/lines_guards.txt", "FIGHT_GUARD", "kills", "notdown")),
    L(round=33, stream="manoeuvre", item="CP-F attempt 3", commit="22e9cab4e", line="(i) fights deaths within 1.645 se",
      form="total", n="23 fights paired", rule="within 1.645 se", base="(FIGHT_GUARD)", arm="(FIGHT_GUARD)", verdict="PASS", source=cpf, machine="builder2",
      noise=G(R33 + "manoeuvre/cpf3b-series/lines_guards.txt", "FIGHT_GUARD", "deaths", "notup")),
]
p3 = src33 + " R33.19, R33.26, R33.28; references/round33/planner/p3-*"
LINES += [
    L(round=33, stream="planner", item="P3", commit="bca4eaca", line="(3) Terminus rig arrivals not down beyond 1.645 se (paired a seed)",
      form="mean", n="13 seeds paired (231-243)", rule=">= -0.90 a seed", base="181/208", arm="175/208 (-0.46, se 0.55)", verdict="PASS", source=p3, noise=down(0.55, -0.46)),
    L(round=33, stream="planner", item="P3", commit="bca4eaca", line="(2c) clicked: face plans' furthest-from-home p90 <= base p90",
      form="median", n="18 v 27 plans", rule="<= base p90", base="12.8 m", arm="15.4 m", verdict="FAIL", source=p3,
      noise={"kind": "none", "note": "unpaired: R34.5 retired the line (faces planned in one arm only); face_pairs.py judges since"}),
    L(round=33, stream="planner", item="P3 v2 pinned", commit="c3acd47a2", line="(2c) clicked: p90 furthest-from-home <= base p90",
      form="median", n="14 v 10 plans", rule="<= base p90", base="4.9 m", arm="6.3 m (max 12.4 v 5.7)", verdict="FAIL", source=p3, machine="builder2",
      noise={"kind": "none", "note": "unpaired (R34.5)"}),
    L(round=33, stream="planner", item="P3 v2 pinned", commit="c3acd47a2", line="(3) Terminus rig arrivals not down beyond 1.645 se",
      form="total", n="13 seeds paired", rule=">= base - 1.645 se", base="179", arm="178", verdict="PASS", source=p3, machine="builder2"),
    L(round=33, stream="planner", item="P3 v2 pairs", commit="923fcb97f", line="(2c) both-planned faces, drawn: median and p90 hull_far <= base + 1.645 se",
      form="median", n="19 faces", rule="<= + 1.645 se", base="3.0 m; p90 8.5", arm="2.8 m; p90 8.5", verdict="PASS", source=p3, machine="builder2"),
    L(round=33, stream="planner", item="P3 v2 pairs", commit="923fcb97f", line="(2c) both-planned faces, clicked: median and p90 hull_far <= base + 1.645 se",
      form="median", n="21 faces", rule="<= + 1.645 se", base="1.6 m; p90 6.3", arm="1.6 m; p90 6.3", verdict="PASS", source=p3, machine="builder2"),
    L(round=33, stream="planner", item="P3 v2 pairs", commit="923fcb97f", line="(2c) candidate-only faces, clicked (a class under 2 faces)",
      form="median", n="1 face", rule=">= 2 faces to judge", base="-", arm="1 face", verdict="REPORTED (NOT JUDGED by the filed text)", source=p3, machine="builder2"),
    L(round=33, stream="planner", item="P3 v2 pairs", commit="923fcb97f", line="(3) Terminus rig arrivals not down beyond 1.645 se",
      form="total", n="13 seeds paired (270-282)", rule=">= base - 1.645 se", base="170", arm="172", verdict="PASS", source=p3, machine="builder2"),
]
br33 = src33 + " Bars; archive/round33/brains.md (R33.9, R4, battery, overnight report)"
LINES += [
    L(round=33, stream="brains", item="R33.9 arrival latch", commit="429ebc4b", line="(a) gangs s40 Battery arrive-flips 0 on; re-seats on < off",
      form="deterministic", n="1 named cell", rule="0; <", base="39; 302", arm="0; 6", verdict="PASS", source=br33, noise=DET),
    L(round=33, stream="brains", item="R33.9 arrival latch", commit="429ebc4b", line="(b) squad-arrive all-within-8 m on >= off - 1.645 se",
      form="count-cells", n="100 cells paired (57-60)", rule=">= 88.8", base="93", arm="93", verdict="PASS", source=br33, noise=limit(93 - 88.8, 0.0)),
    L(round=33, stream="brains", item="R4 (B5c-v6 narrowed)", commit="45d5f1ea", line="(1) named cases: yard s27 t8, Sumps s17 t11, yard head-on s42 t3",
      form="deterministic", n="3 named cases", rule="as filed", base="22.1; 58.3; 17.1 s", arm="22.1; 58.3; 17.1 s (circle reverses 0 v 2)", verdict="PASS", source=br33, noise=DET),
    L(round=33, stream="brains", item="R4 (B5c-v6 narrowed)", commit="45d5f1ea", line="(3) yard crossing: every crew in on >= off (DECIDING)",
      form="count-runs", n="12 runs an arm", rule=">= off", base="12/12", arm="12/12", verdict="PASS", source=br33, noise={"kind": "fisher", "a": 12, "n1": 12, "c": 12, "n2": 12}),
    L(round=33, stream="brains", item="R4 (B5c-v6 narrowed)", commit="45d5f1ea", line="(4) Sumps median on <= off, no run 5 s later, guns_on_arc",
      form="median", n="12 runs paired", rule="<= off", base="24.0 s; 0.950", arm="24.0 s; 0.950", verdict="PASS", source=br33,
      noise={"kind": "none", "note": "identical arms here (R4 did not fire on the Sumps cells)"}),
    L(round=33, stream="brains", item="R4 (B5c-v6 narrowed)", commit="45d5f1ea", line="(6) arrive all-within-8 m on >= off - 1.645 se",
      form="count-cells", n="100 cells paired (61-64)", rule=">= 97.0", base="97", arm="97 (0 discordant)", verdict="PASS", source=br33, noise={"kind": "mcnemar", "b": 0, "c": 0}),
    L(round=33, stream="brains", item="battery (three switches)", commit="ee18403b9", line="(2) never-past battery askers on <= off",
      form="total", n="18 census runs (47-52)", rule="<=", base="1", arm="2", verdict="FAIL", source=br33, machine="builder2"),
    L(round=33, stream="brains", item="battery (three switches)", commit="ee18403b9", line="(2) first shot median on <= off + 5 s",
      form="median", n="18 census runs", rule="<= 8.3 s", base="3.3 s", arm="9.0 s", verdict="FAIL", source=br33, machine="builder2"),
    L(round=33, stream="brains", item="battery (three switches)", commit="ee18403b9", line="(2) set-ups > 8 m, shots >= off - 5 %, repack 0, friendly-stuck",
      form="total", n="18 census runs", rule="as filed", base="186/344; 446", arm="7/99; 441; 0; 637 (limit 931)", verdict="PASS", source=br33, machine="builder2"),
    L(round=33, stream="brains", item="battery (a) alone", commit="1ea8ce40", line="(2) never-past askers, set-ups > 8 m, shots, repack, friendly-stuck, first shot",
      form="total", n="18 census runs (53-58)", rule="as filed", base="0; 118/193; 240; 2.5 s", arm="0; 39/86; 377; 0; 525 (limit 687); 3.0 s (limit 7.5)",
      verdict="PASS", source=br33, machine="builder2"),
    L(round=33, stream="brains", item="scout fights back", commit="0565d1a8", line="(1)(a) pooled scout shots ON >= 1.5 x OFF",
      form="total", n="24 cells x 13 seeds (60-72)", rule=">= 1.5 x", base="3158", arm="5121 (x1.62)", verdict="PASS", source=src33 + " R33.31", machine="builder2"),
    L(round=33, stream="brains", item="scout fights back", commit="0565d1a8", line="(1)(b) damage median ON <= OFF, no cell worse by > 20 %",
      form="median", n="24 cells", rule="<=; 0 cells", base="186", arm="190; 3 cells > 20 % worse", verdict="FAIL", source=src33 + " R33.31", machine="builder2"),
    L(round=33, stream="brains", item="War Rig 4-of-5", commit="befd86c2", line="every element in, on v off",
      form="count-runs", n="10 runs an arm (seeds 8-14)", rule=">= off", base="5/10", arm="10/10", verdict="PASS", source=br33, machine="builder2",
      noise={"kind": "fisher", "a": 10, "n1": 10, "c": 5, "n2": 10}),
    L(round=33, stream="brains", item="rejoin", commit="d5c98eb7", line="(a) one-crew elements after the first minute ON < OFF; (b) kills, deaths within 1.645 se",
      form="total", n="16 respawn fights (584-587 x 4)", rule="<; within", base="1595", arm="2; kills and deaths within noise", verdict="PASS", source=br33, machine="builder2"),
    L(round=33, stream="brains", item="herringbone halt", commit="3baf3a06", line="(1) Hunters seat jumps >= 8 m after arrival ON <= 25 % of OFF",
      form="total", n="6 seeds (526, 527, 528, 537, 542, 550)", rule="<= 25 %", base="2342", arm="107", verdict="PASS", source=br33),
    L(round=33, stream="brains", item="herringbone halt", commit="3baf3a06", line="(2) squad-arrive all-within-8 m ON >= OFF - 1.645 se",
      form="count-cells", n="100 cells", rule=">= off - 1.645 se", base="97", arm="97 (identical: its halts aren't the drill)", verdict="PASS", source=br33,
      noise={"kind": "mcnemar", "b": 0, "c": 0}),
]
c339 = src33 + " R33.24, R33.38, R33.39; references/round33/manoeuvre/c339-judged/, c339-narrow/"
LINES += [
    L(round=33, stream="manoeuvre", item="C33.9", commit="781801da0", line="(a) in-reach in-arc share >= 25 %",
      form="share", n="288 rows (31-36)", rule=">= 25 %", base="3.7 %", arm="23.9 %", verdict="FAIL", source=c339, machine="builder2"),
    L(round=33, stream="manoeuvre", item="C33.9", commit="781801da0", line="(b) shots up; (c) in-reach exchange, no cell worse; (d), (d2), (e), (g)",
      form="total", n="288 rows", rule="as filed", base="2 shots; 0.20", arm="10; 1.77; 0 reverse; 25.8 m; identical", verdict="PASS", source=c339, machine="builder2"),
    L(round=33, stream="manoeuvre", item="C33.9", commit="781801da0", line="(c-out) out-of-reach hits: no cell worse by more than the line",
      form="total", n="288 rows", rule="as filed", base="42", arm="57 (worst +37 %)", verdict="FAIL", source=c339, machine="builder2"),
    L(round=33, stream="manoeuvre", item="C33.9 narrowed", commit="bd4f001fa", line="(d) reverse ticks unchanged (R33.38's re-read)",
      form="deterministic", n="the judged cells 31-36", rule="max 0", base="0", arm="max 23", verdict="FAIL", source=c339, machine="builder2", noise=DET),
    L(round=33, stream="manoeuvre", item="C33.9 narrowed", commit="fc809b60a", line="(c) worst in-reach cell; pooled exchange (R33.38's re-read)",
      form="total", n="the judged cells 31-36", rule="no cell worse", base="1.77", arm="1.58; worst cell -46 %", verdict="FAIL", source=c339, machine="builder2"),
]

# ---------------------------------------------------------------- round 34 --------------------------------------
src34 = WS + " Round 34 Bars / Rulings"
b1 = src34 + " 'Bar, brains B1' Verdict; references/round34/brains/scout2_*"
LINES += [
    L(round=34, stream="brains", item="B1 scout try 2", commit="5abdcd32e", line="(1)(a) duel set: engaged cells' pooled shots ON >= 1.25 x OFF",
      form="total", n="24 duel cells x 7 seeds (73-79)", rule=">= 1.25 x", base="1139", arm="1950 (x1.71)", verdict="PASS", source=b1, machine="builder2"),
    L(round=34, stream="brains", item="B1 scout try 2", commit="5abdcd32e", line="(1)(b) no cell (OFF hits >= 10) takes > 1.2 x OFF damage, both sets",
      form="median", n="48 cells", rule="0 cells", base="842", arm="825; 0 cells", verdict="PASS", source=b1, machine="builder2"),
    L(round=34, stream="brains", item="B1 scout try 2", commit="02b0c1267", line="(3) scout deaths: mean(ON - OFF) <= 1.645 se",
      form="mean", n="8 seeds paired (29-36)", rule="<= +1.75", base="140", arm="134 (mean -0.75)", verdict="PASS", source=b1, machine="builder2", noise=limit(1.75, -0.75)),
    L(round=34, stream="brains", item="B1 scout try 2", commit="02b0c1267", line="(3) team enemy-seen s: mean(ON - OFF) >= -1.645 se",
      form="mean", n="8 seeds paired", rule=">= -93.2", base="18413", arm="18403 (mean -1.2)", verdict="PASS", source=b1, machine="builder2",
      noise=se_line(93.2 / K, 93.2, 93.2 - 1.2)),
]
m0 = src34 + " R34.1, R34.10; references/round34/manoeuvre/m0-series/"
LINES += [
    L(round=34, stream="manoeuvre", item="M0 C33.9 second series", commit="c8fb8b6a3", line="(a) in-arc >= 23.9 % - k sd_boot (what he accepted)",
      form="share", n="12 seeds a cell (101-112), 576 rows", rule=">= 16.3 %", base="3.1 %", arm="74.2 % (sd_boot 4.6)", verdict="PASS", source=m0, machine="builder2",
      noise=se_line(4.6, (23.9 - K * 4.6) - 3.1, 74.2 - (23.9 - K * 4.6))),
    L(round=34, stream="manoeuvre", item="M0 C33.9 second series", commit="c8fb8b6a3", line="(b) shots; (c) exchange gain; in-reach hits and per-cell damage; (d), (d2), (e), (g)",
      form="total", n="576 rows", rule="as filed", base="1; 0.13; 8088", arm="10; 2.34; 5690; 0 reverse; 26.0 m; identical", verdict="PASS", source=m0, machine="builder2"),
    L(round=34, stream="manoeuvre", item="M0 C33.9 second series", commit="c8fb8b6a3", line="(c-out) out-of-reach hits taken ON <= OFF + k se",
      form="total", n="576 rows", rule="<= +437", base="3139", arm="4627 (+1488)", verdict="FAIL", source=m0, machine="builder2", noise=limit(437.0, 1488.0)),
    L(round=34, stream="manoeuvre", item="M0 C33.9 second series", commit="c8fb8b6a3", line="(c-out) pooled median <= 57 (what he accepted)",
      form="median", n="576 rows", rule="<= 57", base="46", arm="60 (+1.0 sd_boot over)", verdict="FAIL", source=m0, machine="builder2",
      noise=se_line(3.0, 57.0 - 46.0, 57.0 - 60.0, note="sd_boot read from '+3 hits, +1.0 sd_boot'")),
]
v4 = src34 + " R34.9, R34.13; references/round34/traffic/x3_v4_series_5914d3ac5.txt, x3_v4b_series_5914d3ac5.txt"
LINES += [
    L(round=34, stream="traffic", item="parkedroom v4", commit="5914d3ac5", line="L1a hold-post far loops <= 50 % of base",
      form="total", n="144 fights paired (868-915 x 3)", rule="<= 17", base="34", arm="18 (se 20.2)", verdict="FAIL", source=v4, machine="builder2",
      noise=se_line(20.2, 17.0, 16.0 - 17.0, note="the 50 % point line, as a drop: needed 17, got 16; 17 is 0.84 se (R34.9)")),
    L(round=34, stream="traffic", item="parkedroom v4", commit="5914d3ac5", line="L3 (a) deaths in the open within base +- k se",
      form="total", n="48 random fights", rule="+-54", base="-", arm="+51", verdict="PASS", source=v4, machine="builder2", noise=band(54.0, 51.0)),
    L(round=34, stream="traffic", item="parkedroom v4", commit="5914d3ac5", line="L1b, L2, L3 (b)(c), L4, L5, L6 at 45 s",
      form="total", n="144 fights paired", rule="as filed", base="92; 124; 410", arm="47; 60; 387; identical; 0/9; 94.2 %", verdict="PASS", source=v4, machine="builder2"),
    L(round=34, stream="traffic", item="parkedroom v4b", commit="5914d3ac5", line="L2 DECIDING gain: all far loops arm < base AND (base - arm) - k se > 0",
      form="total", n="144 fights paired (1100-1147 x 3)", rule="drop > 90.3", base="169", arm="127 (drop 42, se 54.9)", verdict="FAIL", source=v4, noise=gain(54.9, -42.0)),
    L(round=34, stream="traffic", item="parkedroom v4b", commit="5914d3ac5", line="L1a, L1b guards; L3; L4; L5; L6 93.3 %",
      form="total", n="144 fights paired", rule="as filed", base="82; 136", arm="21; 102; 0/9; 93.3 %", verdict="PASS", source=v4),
    L(round=34, stream="traffic", item="parkedroom v4b", commit="5914d3ac5", line="watch: jammed-by-friendly-traffic deaths alone",
      form="total", n="144 fights paired", rule="-", base="79", arm="116 (+37, se 12.6)", verdict="REPORTED", source=v4, noise=up(12.6, 37.0)),
]
t4r34 = src34 + " R34.11; references/round34/traffic/x4_t4_fourth_series_777820d7b.txt"
LINES += [
    L(round=34, stream="traffic", item="T4 fourth try", commit="777820d7b", line="T(1) DECIDING mixed friend-stuck crew-s: arm < base AND drop - k se > 0",
      form="total", n="48 seeds paired (940-987), 34 byte-identical", rule="drop > 346", base="307", arm="426 (+119, se 210.5)", verdict="FAIL", source=t4r34, machine="builder2",
      noise=gain(210.5, 119.0)),
    L(round=34, stream="traffic", item="T4 fourth try", commit="777820d7b", line="T(2)-T(4), T(6) within base +- k se",
      form="total", n="48 seeds; 24 fights", rule="as filed", base="597 (rigs stuck)", arm="848 (inside, the wrong way)", verdict="PASS", source=t4r34, machine="builder2"),
]
b6 = src34 + " R34.7; references/round34/brains/b6_series_a2add1d0f_builder2.txt"
LINES += [
    L(round=34, stream="brains", item="B6 halt shape early", commit="a2add1d0f", line="(1)(a) pooled drift moves ON <= 0.5 x OFF",
      form="total", n="28 runs an arm (Sumps/yard 610-611 x 6, Terminus 610-613)", rule="<= 52", base="104", arm="121", verdict="FAIL", source=b6, machine="builder2"),
    L(round=34, stream="brains", item="B6 halt shape early", commit="a2add1d0f", line="(1)(b) Sumps hollow runs ON <= OFF + 1",
      form="count-runs", n="12 runs an arm", rule="<= 1", base="0/12", arm="9/12", verdict="FAIL", source=b6, machine="builder2",
      noise={"kind": "fisher", "a": 9, "n1": 12, "c": 0, "n2": 12}),
    L(round=34, stream="brains", item="B6 halt shape early", commit="a2add1d0f", line="(2) choke guard: crossing-series all-across ON >= OFF - 1",
      form="count-runs", n="48 runs an arm", rule=">= off - 1", base="-", arm="identical row for row (the early lay never engaged)", verdict="PASS", source=b6, machine="builder2",
      noise={"kind": "none", "note": "identical arms: a trivial pass"}),
]
m3 = src34 + " 'M3 CP-F attempt 4' R34.18; references/round34/manoeuvre/cpf4-series/"
for task, d, lim in (("ambush", 7.0, 3.2), ("move", 9.0, 6.7), ("screen", 13.0, 5.4)):
    LINES.append(L(round=34, stream="manoeuvre", item="M3 CP-F attempt 4", commit="e76f6dab6",
                   line="(d) %s: movers by real_mps <= base + 1.645 sd_run sqrt(pairs) (M1's A/A)" % task, form="total", n="64 pairs a task (601-616)",
                   rule="<= +%.1f" % lim, base="-", arm="%+d" % d, verdict="FAIL", source=m3, machine="builder2", noise=limit(lim, d)))
LINES += [
    L(round=34, stream="manoeuvre", item="M3 CP-F attempt 4", commit="e76f6dab6", line="(e) attack-move never settled <= base + guard",
      form="total", n="64 pairs", rule="<= +4.9", base="-", arm="+6", verdict="FAIL", source=m3, machine="builder2", noise=limit(4.9, 6.0)),
    L(round=34, stream="manoeuvre", item="M3 CP-F attempt 4", commit="e76f6dab6", line="(g) Terminus mixed arrivals not down beyond 1.645 se",
      form="total", n="13 seeds paired (620-632)", rule=">= -4.6", base="-", arm="-5", verdict="FAIL", source=m3, machine="builder2",
      noise=se_line(4.6 / K, 4.6, -5.0 + 4.6)),
    L(round=34, stream="manoeuvre", item="M3 CP-F attempt 4", commit="e76f6dab6", line="(a) point tasks within 15 deg >= 70 %; (m) native twins",
      form="share", n="64 pairs a task", rule=">= 70 %; 0 mismatches", base="14-24 %", arm="82-94 %; 14/0", verdict="PASS", source=m3, machine="builder2"),
]
t6 = src34 + " R34.17, R34.20; references/round34/traffic/x6_series_ac1bf4692.txt, x6b_series_104ca5a11.txt"
LINES += [
    L(round=34, stream="traffic", item="T6 under fire", commit="ac1bf4692", line="G DECIDING jam-under-fire deaths: arm < base AND drop - k se > 0",
      form="total", n="140 fights (fixed arenas x 1300-1327)", rule="drop > 1.645 se", base="231", arm="72 (7 se)", verdict="PASS", source=t6, machine="builder2",
      noise=gain(159.0 / 7.0, -159.0, note="se read from '7 se'")),
    L(round=34, stream="traffic", item="T6 under fire", commit="ac1bf4692", line="guard: open deaths within base +- k se",
      form="total", n="140 fights", rule="+-123", base="-", arm="+169", verdict="FAIL", source=t6, machine="builder2", noise=band(123.0, 169.0)),
    L(round=34, stream="traffic", item="T6 under fire", commit="ac1bf4692", line="guard: kills within base +- k se",
      form="total", n="140 fights", rule="+-112", base="-", arm="+138", verdict="FAIL", source=t6, machine="builder2", noise=band(112.0, 138.0)),
    L(round=34, stream="traffic", item="T6 under fire", commit="ac1bf4692", line="guard: friendly contacts in the 3 s after a hit-ended give-way <= base + k se",
      form="total", n="140 fights", rule="<= base + k se", base="331", arm="1049 (5.7 se over)", verdict="FAIL", source=t6, machine="builder2"),
    L(round=34, stream="traffic", item="T6 under fire", commit="ac1bf4692", line="guard: stuck deaths <= base + k se",
      form="total", n="140 fights", rule="<= 877", base="-", arm="+124 over base", verdict="FAIL", source=t6, machine="builder2"),
    L(round=34, stream="traffic", item="T6b", commit="104ca5a11", line="G DECIDING jam-under-fire deaths: arm < base AND drop - k se > 0",
      form="total", n="140 fights (fixed arenas x 1500-1527)", rule="drop > 1.645 se", base="256", arm="121 (-53 %)", verdict="PASS", source=t6, machine="builder2"),
    L(round=34, stream="traffic", item="T6b", commit="104ca5a11", line="guard: stuck deaths <= base + k se",
      form="total", n="140 fights", rule="<= base + k se", base="902", arm="963 (+61, 1.9 se over the line)", verdict="FAIL", source=t6, machine="builder2",
      noise=se_line(61.0 / (K + 1.9), K * 61.0 / (K + 1.9), -1.9 * 61.0 / (K + 1.9), note="se read from '1.9 se over'")),
    L(round=34, stream="traffic", item="T6b", commit="104ca5a11", line="guards: far loops (by 0.1), contacts after a hit-ended give-way, open deaths, kills",
      form="total", n="140 fights", rule="as filed", base="96; 336", arm="192; 167; inside; equal", verdict="PASS", source=t6, machine="builder2"),
]
b9 = src34 + " R34.19; references/round34/brains/b9_lane_series/"
LINES += [
    L(round=34, stream="brains", item="B9 lane spread", commit="a82615a2b", line="DECIDING exchange gain E (ln-ratio, ruled v base) mean > 1.645 se",
      form="mean", n="120 fights an arm (locks/terminus/crossing x 1400-1439)", rule="> +0.511", base="A/A E +0.254 (se 0.292)", arm="+0.157 (se 0.310)",
      verdict="FAIL", source=b9, machine="builder2", noise=gain_up(0.310, 0.157, 0.511)),
    L(round=34, stream="brains", item="B9 lane spread", commit="a82615a2b", line="guards: jam and stuck deaths, far loops, first contact, fight length, piecemeal",
      form="total", n="120 fights an arm", rule="<= base + 1.645 se", base="-", arm="every guard passes", verdict="PASS", source=b9, machine="builder2"),
]
x1 = src34 + " 'X1 the stuck-death census' REPORTED; references/round34/traffic/x1_stuck_death_census.md"
LINES += [
    L(round=34, stream="traffic", item="X1 census (v3 + hand-back)", commit="v3", line="reported: deaths stuck or jammed",
      form="total", n="48 random fights paired (600-647)", rule="-", base="428", arm="443 (se 22.3)", verdict="REPORTED", source=x1, noise=se_line(22.3, 0.0, 0.0)),
    L(round=34, stream="traffic", item="X1 census (v3 + hand-back)", commit="v3", line="reported: deaths in the open",
      form="total", n="48 random fights paired", rule="-", base="1668", arm="1634 (se 43)", verdict="REPORTED", source=x1, noise=se_line(43.0, 0.0, 0.0)),
    L(round=34, stream="traffic", item="X1 census (v3 + hand-back)", commit="v3", line="reported: kills",
      form="total", n="48 random fights paired", rule="-", base="2065", arm="2051 (se 35)", verdict="REPORTED", source=x1, noise=se_line(35.0, 0.0, 0.0)),
]

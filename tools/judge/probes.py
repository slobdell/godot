#!/usr/bin/env python3
"""The probes this project's bars use, each metric's measured noise, and the sizing that follows (sizing S2, CP-N).

A PROBE is a runner whose rows the streams judge (traffic-series's four cases, the hull-rest probe, ...). For each
probe x metric this module knows (a) where the noise comes from: the judged pairs under references/ where the treatment
acted (pooled per-run paired sd), or the se a table printed when rows were not kept; (b) the base level per run; (c) the
form of the line a bar puts on it and the effect that bar names. `compute()` turns that into the table CP-N publishes:

  sd_run      per-run paired sd (the probe's noise, the number a bar should quote)
  base_run    the base arm's level per run (so an effect in % becomes an effect per run)
  icc         share of the paired noise that is between seeds (0: ticks are as good as seeds; > 0.3: add seeds first)
  n_today     the n the latest judged bar used (round 29's, or round 30's where that round re-ran the probe)
  mde_today   the smallest per-run effect n_today detects at 80 % power, 5 % one-sided, as a share of base
  effect      the effect the bar names (a share of base, or an absolute per run)
  n_needed    the paired n that detects that effect at 80 % / 5 %
  se_today    the se of the SUM (or of the median difference) at n_today: what the bar's guard line should be built on
  aa          the A/A evidence: the same arm's swing across seed sets, or 'owed' with the cost of two base runs

Everything is reproducible from `python3 tools/judge/table.py`; numbers carry their source pair and commit. Round 30's
judged pairs (T3b, T1c-b, M4b run 2, M1b, M2b, kturnarc, B5c-v4) were added at the round's close (judging.md step 8).
Round 33's (CP-F attempts 1 and 3, CP-Q, P3 v1/v2, C33.9 and its narrowings, parkedroom v1-v3 and item 4, the planner's
hull-rest A/A) were added in round 34 (planner, C34.8 (b)); rounds 31-32 were never ingested (judging.md says which).
"""
import math
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rows  # noqa: E402
import stats  # noqa: E402

R28 = "_agents/streams/references/round28/"
R29 = "_agents/streams/references/round29/"
R30 = "_agents/streams/references/round30/"
R31 = "_agents/streams/references/round31/"
R32 = "_agents/streams/references/round32/"
R32T = "references/round32/"  # round 32's traffic and planner rows are at the top level
R33 = "references/round33/"  # round 33 filed planner's and manoeuvre's rows at the top level
R33S = "_agents/streams/references/round33/"

# The judged traffic pairs (base, arm, label); a case x metric pools the per-run paired sd over the pairs where the arms acted.
TRAFFIC_PAIRS = [
    ("CP-T 3a94f38d s13-15", R29 + "traffic/judged_base_3a94f38d_seeds131415.jsonl", R29 + "traffic/judged_hold_3a94f38d_seeds131415.jsonl"),
    ("CP-T CPU 3a94f38d s13-15", R29 + "traffic/judged_cpu_base_3a94f38d_seeds131415.jsonl", R29 + "traffic/judged_cpu_hold_3a94f38d_seeds131415.jsonl"),
    ("T3 d9b3339c s22-24", R29 + "traffic/t3_judged_base_d9b3339c_seeds222324.jsonl", R29 + "traffic/t3_judged_arm_d9b3339c_seeds222324.jsonl"),
    ("T3 v1 fcddda26 s1-3", R29 + "traffic/t3_tuning_base_fcddda26_seeds123.jsonl", R29 + "traffic/t3_tuning_v1_fcddda26_seeds123.jsonl"),
    ("T1 v4 tuning 3cd5596b s1-3", R29 + "traffic/t0_3cd5596b_seeds123.jsonl", R29 + "traffic/tuning_v4_seeds123.jsonl"),
    ("T1 v3 672eb785 s4-6", R28 + "traffic/judged-jbase-672eb785-seeds456.jsonl", R28 + "traffic/judged-jv3-672eb785-seeds456.jsonl"),
    ("T1b 474558f8 s10-12", R28 + "traffic/t1b-cbase-474558f8-seeds101112.jsonl", R28 + "traffic/t1b-ct1b-474558f8-seeds101112.jsonl"),
    ("T3b cf124433 s31-33", R30 + "traffic/t3b_judged_base_cf124433_seeds313233.jsonl", R30 + "traffic/t3b_judged_arm_cf124433_seeds313233.jsonl"),
    # Round 35 (C35.9): T3b-c as shipped (C32.1's re-judge on the carried tree). Round 31's judged pair (f5dc4147, the same
    # seeds 41-43) reads the same totals line for line, so it is in the inventory only, not pooled twice.
    ("T3b-c b5882c9c s41-43 (round 32)", R32T + "traffic/t3bc_r32_base_b5882c9c.jsonl.gz", R32T + "traffic/t3bc_r32_arm_b5882c9c.jsonl.gz"),
]
# The same ARM on different seed sets (and commits): the A/A swing of a case total at n = 18. T3b's base (no flag at
# cf124433, where round 29's hold is the default) is a fourth hold-ON set.
TRAFFIC_AA = {
    "hold ON": [("3a94f38d s13-15", R29 + "traffic/judged_hold_3a94f38d_seeds131415.jsonl"),
                ("d9b3339c s22-24", R29 + "traffic/t3_judged_base_d9b3339c_seeds222324.jsonl"),
                ("fcddda26 s1-3", R29 + "traffic/t3_tuning_base_fcddda26_seeds123.jsonl"),
                ("cf124433 s31-33", R30 + "traffic/t3b_judged_base_cf124433_seeds313233.jsonl")],
    "hold OFF": [("3cd5596b s1-3", R29 + "traffic/t0_3cd5596b_seeds123.jsonl"),
                 ("3a94f38d s13-15", R29 + "traffic/judged_base_3a94f38d_seeds131415.jsonl"),
                 ("672eb785 s4-6", R28 + "traffic/judged-jbase-672eb785-seeds456.jsonl"),
                 ("474558f8 s10-12", R28 + "traffic/t1b-cbase-474558f8-seeds101112.jsonl")],
}
TRAFFIC_CASES = ("terminus/head", "terminus/cross", "yard_open/cross", "yard_open/head")
TRAFFIC_COST_MIN = 1.75  # builder0 minutes a traffic-series run, loaded (the brief: a case of 18 runs ~ 20-40 min)
ACTED_SHARE = 1.0 / 3.0  # a pair counts toward a case's noise only if the arms diverged in at least a third of its runs

# The judged traffic-census pairs (3 arenas x 3 seeds, n = 9), paired on arena + seed + roster.
CENSUS_PAIRS = [
    ("T1c 761bd727 seeds 4-6", R29 + "traffic/t1c_census_base_761bd727_seeds456.jsonl", R29 + "traffic/t1c_census_arm_761bd727_seeds456.jsonl"),
    ("T1c-b 16780030 seeds 7-9", R30 + "traffic/t1cb_judged_census_base_16780030_seeds789_131415.jsonl", R30 + "traffic/t1cb_judged_census_arm_16780030_seeds789_131415.jsonl"),
    # Round 35 (C35.9): T1c-b2 at round 31 (33cb2da5, rows copied from round31/traffic) and its round-32 re-judge (cf81aedc);
    # the same seeds 41-46 on two trees, whose runs differ (746 -> 787 v 789 -> 696 friendly-stuck).
    ("T1c-b2 33cb2da5 seeds 41-46 (round 31)", R31 + "traffic/t1cb2_judged_census_base_33cb2da5_seeds41-46.jsonl", R31 + "traffic/t1cb2_judged_census_arm_33cb2da5_seeds41-46.jsonl"),
    ("T1c-b2 cf81aedc seeds 41-46 (round 32)", R32T + "traffic/t1cb2_r32_census_base_cf81aedc.jsonl.gz", R32T + "traffic/t1cb2_r32_census_arm_cf81aedc.jsonl.gz"),
]
CENSUS_KEY = ["arena", "seed", "credits", "units"]

# The judged Terminus census pairs (rigs and mixed squads, one run a seed); round 30's at 13 seeds. M4b run 1's table
# (e8bfef2e) carries totals and discordant seeds only, so it is in the inventory with its printed se, not pooled here.
TERMINUS_PAIRS = [
    ("M4 9db2a57c seeds 14-19", R29 + "manoeuvre/m4_judged.txt"),
    ("M4b run 2 77a1603f seeds 62-74", R30 + "manoeuvre/m4b_run2_judged.txt"),
    ("M1b 55622870 seeds 36-48", R30 + "manoeuvre/m1b_judged.txt"),
    ("M2b 1f1c9835 seeds 49-61", R30 + "manoeuvre/m2b_judged.txt"),
    ("kturnarc e7a58262 seeds 75-87", R30 + "manoeuvre/kturnarc_judged.txt"),
]
TERMINUS_PAIRS += [
    ("CP-H 130a069b (round 31)", R31 + "manoeuvre/cph_terminus.txt"),
    ("M1b(2) run 1 6efd1ed9 (round 31)", R31 + "manoeuvre/m1b2_terminus_judged.txt"),
    ("M1b(2) run 2 25ef8f7e (round 31)", R31 + "manoeuvre/m1b2_run2_terminus_judged.txt"),
]
TERMINUS_N_TODAY = 13

# The hull-rest tables (M1_CLASS lines) and the paired n of the wheeled-turret class in each (the per-run convention).
HULL_REST_TABLES = [
    ("M1 d7385da2 seeds 22-33", R29 + "manoeuvre/m1_judged.txt", 27),
    ("M1b 55622870 seeds 48-53", R30 + "manoeuvre/m1b_judged.txt", 15),
]
HULL_REST_TABLES += [
    ("CP-H 130a069b seeds 84-89 (round 31)", R31 + "manoeuvre/cph_hull_rest.txt", 14),
    ("M1b(2) run 1 6efd1ed9 seeds 76-81 (round 31)", R31 + "manoeuvre/m1b2_run1_judged.txt", 17),
    ("M1b(2) run 2 25ef8f7e seeds 90-95 (round 31)", R31 + "manoeuvre/m1b2_run2_judged.txt", 14),
    ("CP-F b4bf8f2c GDScript (R33.21)", R33 + "manoeuvre/cpf-series/hull_rest_ab.txt", 14),
    ("CP-F b4bf8f2c native (R33.21)", R33 + "manoeuvre/cpf-series/hull_rest_ab_native.txt", 15),
    ("CP-F 3 22e9cab4e (R33.34)", R33 + "manoeuvre/cpf3b-series/hull_rest_ab.txt", 32),
    ("CP-Q c75f20a6 gangs (R33.13)", R33 + "planner/p2-c75f20a6/hull-ab.txt", 12),
    ("P3 bca4eaca gangs (R33.19)", R33 + "planner/p3-bca4eaca/hull-ab.txt", 12),
    # Round 35 (C35.9): round 32's two hull-rest pairs (old ruler, wall-clock paced like every pair before R33.21's pin).
    ("B11 ffba7f77 seeds 350-355 (round 32)", R32 + "brains/b11-ab-ffba7f77.txt", 15),
    ("CP-Q 65cc43dd gangs seeds 66-71 (round 32)", R32T + "planner/cpq-65cc43dd/hull-rest-tables.txt", 6),
]
HULL_REST_N_TODAY = 32  # CP-F attempt 3's grid (R33.34), the latest judged hull-rest bar

# The tables whose FIGHT_GUARD / PINNED lines print a paired se (rows not kept): the sd a run is se / sqrt(n).
GUARD_TABLES = [
    ("M4 9db2a57c (fights 109-132, pinned 34-39)", R29 + "manoeuvre/m4_judged.txt"),
    ("M4b run 2 77a1603f (fights 157-180, pinned 54-59)", R30 + "manoeuvre/m4b_run2_judged.txt"),
]

GUARD_TABLES += [
    ("CP-H 130a069b (fights, round 31)", R31 + "manoeuvre/cph_fights.txt"),
    ("CP-H 130a069b (pinned 84-89, round 31)", R31 + "manoeuvre/cph_hull_rest.txt"),
    ("CP-F b4bf8f2c (fights, R33.21)", R33 + "manoeuvre/cpf-series/fights.txt"),
    ("CP-F 3 22e9cab4e (fights, R33.34)", R33 + "manoeuvre/cpf3b-series/lines_guards.txt"),
]

# Round 33 (planner's Terminus series): the verdict prints a paired MEAN and its se a seed per squad
# (`PLANNER_SERIES_SQUAD rigs: n 13 | arrivals base 179 candidate 178 of 208, paired mean -0.077 se 0.560 ...`), not per-seed
# rows: sd a seed = se x sqrt(n). Only the two series series_verdict accepted (P3 bca4eaca's and CP-Q's were REFUSED by the
# tool before its seam=both mode: "the switch reached the base"). The mixed squad never fired the seam in either (se 0: an equality check, skipped).
TERMINUS_PRINTED = [
    ("P3 v2 pinned c3acd47a2 (R33.26)", R33 + "planner/p3-pinned-c3acd47a2/terminus-verdict.txt"),
    ("P3 v2 923fcb97f (R33.28)", R33 + "planner/p3-pairs-923fcb97f/terminus-verdict.txt"),
    ("CP-Q 65cc43dd seeds 205-217 (round 32)", R32T + "planner/cpq-65cc43dd/terminus-series.txt"),
]

# Round 33 (manoeuvre, C33.9): the scout orbit cells (subject x enemy x radius x post, 6 seeds a cell), one jsonl holding
# both arms (`on`). The turn-in acts only at the player post; the free-post rows are identical by construction.
ORBIT_CELLS = [
    ("C33.9 781801da0 seeds 31-36 (R33.24)", R33 + "manoeuvre/c339-judged/cells-31-36.jsonl"),
    ("C33.9 narrow bd4f001fa (R33.39)", R33 + "manoeuvre/c339-narrow/cells-31-36-bd4f001fa.jsonl"),
    ("C33.9 narrow fc809b60a (R33.39)", R33 + "manoeuvre/c339-narrow/cells-31-36-fc809b60a.jsonl"),
]
ORBIT_KEY = ["seed", "subject", "enemy", "radius"]

# Round 33 (traffic): the far census over terminus / locks / random fights, judged by far_ab's printed paired-sum lines
# (`L3 kills: base 2072, arm 1992 over 48 paired fights; drop 80, paired se of the sum 40.88 ...; fights differing 39`).
FAR_TABLES = [
    ("parkedroom v1 x3 (fights 72)", R33S + "traffic/x3_series_far_ab.txt"),
    ("parkedroom v2n (fights 820-867 x 3)", R33S + "traffic/ov_parkedroom_v2n_series.txt"),
    ("parkedroom v3 (fights 820-867 x 3, R33.37)", R33S + "traffic/ov_parkedroom_v3_series.txt"),
    ("item 4 series (R33.36)", R33S + "traffic/ov_item4_series.txt"),
    ("item 4 re-judge (R33.36)", R33S + "traffic/ov_item4_rejudge.txt"),
]

# Round 34 (manoeuvre M1, the new hull-rest ruler on main f97e5fdb1): its A/A, the OFF arm on seeds 201-209 v 210-218,
# 36 pairs a task (lab/m1-ruler e28ba432d, builder2; copied from stream/manoeuvre references/round34/manoeuvre/m1-aa/).
# "Still" reads REAL velocity (moving_real) and wedged hulls are their own count, so the hull-rest rows above (pairs of
# rounds 29-33) are the OLD ruler's and do not compare with these.
M1_AA = "references/round34/planner/sizing/m1-aa-e28ba432d-builder2.txt"

# Round 33 (planner P1): the hull-rest gangs A/A, fifo v fifo, per-cell sd a run printed (HULL_AA_CELL).
HULL_AA = R33 + "planner/aa-4bbe8322/hull-aa.txt"

# Brains' gate-series cells (one jsonl, both arms, `cell` + `arm` off/on) and arrive series (100 cells an arm, two jsonl).
# Round 35 (C35.9): round 31's and 32's brains pairs pool in (a pair counts where its arms acted in >= a third of its
# cells, as everywhere): B5c-v5's Sumps cells; B3b-2b's, B3b-2c's and B10's arrive series.
GATE_SERIES = [
    ("B5c-v4 19eca15a seeds 14-15 x 6", R30 + "brains/b5c-v4-gate-series-19eca15a.jsonl"),
    ("B5c-v5 e675a28a seeds 16-17 x 6 (round 31)", R31 + "brains/b5c-v5-gate-sumps-terminus-e675a28a.jsonl"),
]
ARRIVE_PAIRS = [
    ("B5c-v4 19eca15a seeds 29-32", R30 + "brains/b5c-v4-arrive-off-19eca15a.jsonl", R30 + "brains/b5c-v4-arrive-on-19eca15a.jsonl"),
    ("B3b-2b 5ed61f91 seeds 41-44 (round 31)", R31 + "brains/b3b2b-arrive-ctrl.jsonl", R31 + "brains/b3b2b-arrive-on.jsonl"),
    ("B3b-2c cbddb940 seeds 45-48 (round 32)", R32 + "brains/b3b2c-arrive-ctrl-cbddb940.jsonl", R32 + "brains/b3b2c-arrive-on-cbddb940.jsonl"),
    ("B10 8e43cc5c seeds 49-52 (round 32)", R32 + "brains/b10-arrive-off-8e43cc5c.jsonl", R32 + "brains/b10-arrive-on-8e43cc5c.jsonl"),
]


def case_acted(pairs):
    """Did the treatment touch this case? A run counts as touched when its arrival times or its fast contacts differ at all
    (any divergence of the trajectories moves an arrival time); the pair counts when at least ACTED_SHARE of its runs did."""
    touched = sum(1 for _k, b, a in pairs if abs(rows.all_in_s(a) - rows.all_in_s(b)) > 0.05 or a["contacts_fast"] != b["contacts_fast"])
    return touched >= ACTED_SHARE * len(pairs)


def pairs_acted(pairs, metrics):
    """The generic form: the arms differ in any of `metrics` in at least ACTED_SHARE of the runs."""
    touched = sum(1 for _k, b, a in pairs if any(rows.metric_fn(m)(a) != rows.metric_fn(m)(b) for m in metrics))
    return touched >= ACTED_SHARE * len(pairs)


def pooled_sd(sds_ns):
    num = sum((n - 1) * sd * sd for sd, n in sds_ns if n > 1)
    den = sum(n - 1 for sd, n in sds_ns if n > 1)
    return math.sqrt(num / den) if den else 0.0


def traffic_metric(root, case, metric, stat="total"):
    """Pool the per-run paired noise of one traffic case x metric over every judged pair where the arms acted. A pair
    whose rows predate the metric (the crossing clock is round 30's) is skipped."""
    sds, bases, iccs, used, med_sds, meds = [], [], [], [], [], []
    for label, base, arm in TRAFFIC_PAIRS:
        cases = rows.traffic_pairs(os.path.join(root, base), os.path.join(root, arm))
        if case not in cases:
            continue
        pairs = cases[case]
        if any(v is None for v in rows.values(pairs, metric, "base")):
            continue
        d = rows.diffs(pairs, metric)
        if not case_acted(pairs):
            continue  # the treatment barely touched this case: its near-zero sd is not the probe's noise under a change
        sds.append((stats.paired_sd(d), len(d)))
        bases.append(statistics.mean(rows.values(pairs, metric, "base")))
        iccs.append(stats.variance_components(rows.by_seed(pairs, metric))["icc"])
        used.append(label)
        if stat == "median":
            med_sds.append(stats.bootstrap_median_diff(rows.values(pairs, metric, "base"), rows.values(pairs, metric, "arm"), reps=1000)[3])
            meds.append(statistics.median(rows.values(pairs, metric, "base")))
    out = {"sd_run": pooled_sd(sds), "base_run": statistics.mean(bases) if bases else float("nan"),
           "icc": statistics.mean(iccs) if iccs else 0.0, "pairs": used, "n_pairs": len(used)}
    if stat == "median":
        out["median_sd_18"] = statistics.mean(med_sds) if med_sds else float("nan")
        out["base_median"] = statistics.mean(meds) if meds else float("nan")
    return out


def traffic_aa(root, case, metric, stat="total"):
    """{arm: [(label, value)]}: the same arm's case total (or median) on each seed set it was run on."""
    out = {}
    for arm, files in TRAFFIC_AA.items():
        vals = []
        for label, path in files:
            runs = [r for r in rows.read_jsonl(os.path.join(root, path)) if r.get("which") == "both" and not r.get("missing")
                    and r["arena"] + "/" + r["kind"] == case]
            f = rows.metric_fn(metric)
            v = [f(r) for r in runs]
            vals.append((label, statistics.median(v) if stat == "median" else sum(v)))
        out[arm] = vals
    return out


def census_metric(root, off_dir, on_dir, tag, off_pat, on_pat, metric):
    off = rows.census_pairs(os.path.join(root, off_dir), os.path.join(root, off_dir), tag, pattern=off_pat)
    on = {s: o for s, o, _ in rows.census_pairs(os.path.join(root, on_dir), os.path.join(root, on_dir), tag, pattern=on_pat)}
    pairs = [(s, o, on[s]) for s, o, _ in off if s in on]
    d = rows.diffs(pairs, metric)
    return {"sd_run": stats.paired_sd(d), "base_run": statistics.mean(rows.values(pairs, metric, "base")), "icc": 0.0,
            "pairs": ["B3 b95a3d6e seeds 13-24"], "n_pairs": 1, "n": len(d)}


def gun_on_target_pts(row, unit="gang_scout"):
    ps = [u for u in row["per_scout"].values() if u["unit"] == unit]
    fight = sum(u["fight_s"] for u in ps)
    return 100.0 * sum(u["on_target_s"] for u in ps) / fight if fight else 0.0


def approach_metric(root, path, metric, label):
    pairs = rows.approach_pairs(os.path.join(root, path))
    d = rows.diffs(pairs, metric)
    return {"sd_run": stats.paired_sd(d), "base_run": statistics.mean(rows.values(pairs, metric, "base")),
            "icc": stats.variance_components(rows.by_seed(pairs, metric))["icc"], "pairs": [label], "n_pairs": 1}


def terminus_metric(root, squad, metric):
    """Pool the per-seed paired noise of one Terminus squad x metric over the judged pairs where the arms acted (M4b run
    2's rigs replicate their base run by construction and are an equality check, not a sample)."""
    sds, bases, used = [], [], []
    for label, path in TERMINUS_PAIRS:
        table = rows.terminus_rows(os.path.join(root, path)).get(squad, [])
        if not table or not pairs_acted(table, ("arrived", "contacts")):
            continue
        d = rows.diffs(table, metric)
        sds.append((stats.paired_sd(d), len(d)))
        bases.append(statistics.mean(rows.values(table, metric, "base")))
        used.append(label)
    for label, path in TERMINUS_PRINTED:
        line = rows.planner_series_lines(os.path.join(root, path)).get(squad)
        se = line and (line["arrived_se"] if metric == "arrived" else line["contacts_se"])
        if not se:
            continue  # se 0: the seam never fired for this squad (an equality check, not a sample)
        sds.append((se * math.sqrt(line["n"]), line["n"]))
        if metric == "arrived":
            bases.append(line["base_arrived"])
        used.append(label + " (printed se)")
    return {"sd_run": pooled_sd(sds), "base_run": statistics.mean(bases) if bases else float("nan"), "icc": 0.0,
            "pairs": used, "n_pairs": len(used)}


def orbit_metric(root, metric):
    """Pool the per-run paired sd of one orbit-cell metric (player post only: where the turn-in acts) over the C33.9 pairs."""
    sds, bases, used, by_seed = [], [], [], {}
    for label, path in ORBIT_CELLS:
        rows_ = [r for r in rows.read_jsonl(os.path.join(root, path)) if r.get("player")]
        off = {tuple(str(r[f]) for f in ORBIT_KEY): r for r in rows_ if not r["on"]}
        on = {tuple(str(r[f]) for f in ORBIT_KEY): r for r in rows_ if r["on"]}
        pairs = [(k, off[k], on[k]) for k in off if k in on]
        if not pairs or not pairs_acted(pairs, (metric,)):
            continue
        d = rows.diffs(pairs, metric)
        sds.append((stats.paired_sd(d), len(d)))
        bases.append(statistics.mean(rows.values(pairs, metric, "base")))
        used.append(label)
        for seed, ds in rows.by_seed(pairs, metric).items():
            by_seed.setdefault((label, seed), []).extend(ds)
    icc = stats.variance_components(by_seed)["icc"] if by_seed else 0.0
    return {"sd_run": pooled_sd(sds), "base_run": statistics.mean(bases) if bases else float("nan"), "icc": icc,
            "pairs": used, "n_pairs": len(used)}


def far_metric(root, name):
    """Pool far_ab's printed paired se into a per-fight sd over the far-census pairs: sd = se / sqrt(n) for a sum, se x
    sqrt(n) for the hit rate's paired mean. A kills/deaths/hit-rate pair counts where the arms differed in >= ACTED_SHARE
    of its fights; the loop counts are rare events (a few fights differ), so every pair where any fight differed counts."""
    sds, bases, used = [], [], []
    for label, path in FAR_TABLES:
        line = rows.far_lines(os.path.join(root, path)).get(name)
        if not line or line["differing"] == 0:
            continue
        if not name.startswith("L1") and not name.startswith("L2") and line["differing"] < ACTED_SHARE * line["n"]:
            continue
        n = line["n"]
        if name == "hit rate":
            sds.append((line["se_mean"] * math.sqrt(n), n))
            bases.append(line["base"])
        else:
            sds.append((line["se"] / math.sqrt(n), n))
            bases.append(line["base"] / n)
        used.append("%s (%d of %d fights differ)" % (label, line["differing"], n))
    return {"sd_run": pooled_sd(sds), "base_run": statistics.mean(bases) if bases else float("nan"), "icc": 0.0,
            "pairs": used, "n_pairs": len(used)}


def m1_aa_metric(root, metric):
    """M1's A/A (the new ruler): a null change's per-run paired sd, pooled over its six tasks (36 pairs each)."""
    lines = [r for r in rows.m1_aa_lines(os.path.join(root, M1_AA)) if r["metric"] == metric]
    return {"sd_run": pooled_sd([(r["sd_run"], r["pairs"]) for r in lines]),
            "base_run": statistics.mean([r["a"] / r["pairs"] for r in lines]) if lines else float("nan"), "icc": 0.0,
            "pairs": ["M1 A/A e28ba432d seeds 201-209 v 210-218 (%d tasks x 36, builder2)" % len(lines)], "n_pairs": 1}


def hull_aa_metric(root, metric, klass="wheels/turret"):
    """The planner's hull-rest gangs A/A (fifo v fifo, both modes, six tasks, n 6 a cell): the per-run sd of a null
    change, pooled over the cells (no treatment: this IS the noise floor)."""
    cells = [c for c in rows.hull_aa_cells(os.path.join(root, HULL_AA)) if c["klass"] == klass and c["metric"] == metric]
    sds = [(c["sd_run"], c["n"]) for c in cells]
    return {"sd_run": pooled_sd(sds), "base_run": statistics.mean([c["base_median"] for c in cells]) if cells else float("nan"),
            "icc": 0.0, "pairs": ["hull-rest gangs A/A 4bbe8322 seeds 66-71 (%d cells, fifo v fifo)" % len(cells)], "n_pairs": 1}


def hull_rest_metric(root, klass):
    """Per-run sd of crews-still-moving from the M1_CLASS lines (se of the sum over n paired runs -> sd = se / sqrt(n)),
    pooled over the judged hull-rest tables."""
    sds, bases, used = [], [], []
    for label, path, _n_wt in HULL_REST_TABLES:
        cls = [c for c in rows.class_lines(os.path.join(root, path)) if c["klass"] == klass]
        if not cls:
            continue
        sds += [(c["se"] / math.sqrt(c["n"]), c["n"]) for c in cls]
        bases += [c["base"] / c["n"] for c in cls]
        used.append("%s (%d tasks, n %d)" % (label, len(cls), cls[0]["n"]))
    return {"sd_run": pooled_sd(sds), "base_run": statistics.mean(bases) if bases else float("nan"), "icc": 0.0,
            "pairs": used, "n_pairs": len(used)}


def hull_rest_all_classes(root):
    """All classes a task: se of the sum = sqrt(sum of the class se^2); the per-run sd uses the wheeled-turret n (the class
    the bars command; one run holds several classes, so no single n is exact)."""
    sds, bases, used = [], [], []
    for label, path, n_wt in HULL_REST_TABLES:
        cls = rows.class_lines(os.path.join(root, path))
        tasks = {}
        for c in cls:
            tasks.setdefault(c["task"], []).append(c)
        if not tasks:
            continue
        sds += [(math.sqrt(sum(c["se"] ** 2 for c in v)) / math.sqrt(n_wt), n_wt) for v in tasks.values()]
        bases += [sum(c["base"] for c in v) / n_wt for v in tasks.values()]
        used.append("%s (%d tasks, all classes, n %d)" % (label, len(tasks), n_wt))
    return {"sd_run": pooled_sd(sds), "base_run": statistics.mean(bases) if bases else float("nan"), "icc": 0.0,
            "pairs": used, "n_pairs": len(used)}


def guard_metric(root, tag, name, form="total"):
    """Pool a printed paired se (FIGHT_GUARD / PINNED lines) into a per-run sd over the tables that carry the line and
    whose arms differed: sd = se / sqrt(n) for a sum, se * sqrt(n) for a paired mean."""
    sds, bases, used = [], [], []
    for label, path in GUARD_TABLES:
        line = rows.guard_lines(os.path.join(root, path), tag).get(name)
        if not line or line["se"] <= 0:
            continue
        n = line["n"]
        sds.append((line["se"] * math.sqrt(n) if form == "mean" else line["se"] / math.sqrt(n), n))
        bases.append(line["base"] if form == "mean" else line["base"] / n)
        used.append("%s %s %s se %g" % (label, tag, name, line["se"]))
    return {"sd_run": pooled_sd(sds), "base_run": statistics.mean(bases) if bases else float("nan"), "icc": 0.0,
            "pairs": used, "n_pairs": len(used)}


def _pooled_pairs(pair_lists, metric, stat, n_today=None):
    """Pool [(label, [(key, base_row, arm_row)])] where the arms acted: per-pair paired sd, and for a median line the
    bootstrap sd of the median difference over the pairs' cells concatenated, rescaled from the pooled n to n_today
    (a median's sd scales as 1 / sqrt(n)) so it is the se a bar at n_today quotes."""
    sds, used, b_all, a_all = [], [], [], []
    for label, pairs in pair_lists:
        d = rows.diffs(pairs, metric)
        if not pairs or len(stats.acted(d)) < ACTED_SHARE * len(d):
            continue
        sds.append((stats.paired_sd(d), len(d)))
        b_all += rows.values(pairs, metric, "base")
        a_all += rows.values(pairs, metric, "arm")
        used.append("%s (n %d)" % (label, len(d)))
    out = {"sd_run": pooled_sd(sds), "base_run": statistics.mean(b_all) if b_all else float("nan"), "icc": 0.0,
           "pairs": used, "n_pairs": len(used), "n": len(b_all)}
    if stat == "median" and b_all:
        sd = stats.bootstrap_median_diff(b_all, a_all, reps=1000)[3]
        out["median_sd_18"] = sd * math.sqrt(len(b_all) / n_today) if n_today else sd
        out["base_median"] = statistics.median(b_all)
    return out


def cell_metric(root, cell, metric, stat, n_today=12):
    """A gate-series cell, off v on per (seed, tick), pooled over GATE_SERIES; a median line carries its bootstrap sd."""
    return _pooled_pairs([(label, rows.cell_pairs(os.path.join(root, path), cell)) for label, path in GATE_SERIES], metric, stat, n_today)


def arrive_metric(root, metric, stat, n_today=91):
    """The arrive series' all-within-8 m time over the cells both arms completed, pooled over ARRIVE_PAIRS."""
    lists = []
    for label, off, on in ARRIVE_PAIRS:
        pairs = [(k, o, n) for k, o, n in rows.arrive_pairs(os.path.join(root, off), os.path.join(root, on))
                 if o.get(metric) is not None and n.get(metric) is not None]
        lists.append((label, pairs))
    return _pooled_pairs(lists, metric, stat, n_today)


def arrive_discordant(root):
    """[(label, for, against)]: cells within 8 m in one arm only, per arrive pair (the count block's McNemar rows)."""
    out = []
    for label, off, on in ARRIVE_PAIRS:
        pairs = rows.arrive_pairs(os.path.join(root, off), os.path.join(root, on))
        won = sum(1 for _k, o, n in pairs if n.get("all_in8_s") is not None and o.get("all_in8_s") is None)
        lost = sum(1 for _k, o, n in pairs if o.get("all_in8_s") is not None and n.get("all_in8_s") is None)
        out.append((label, won, lost))
    return out


# ---- the probe table ---------------------------------------------------------------------------------------------
# Each entry: probe, metric, form, how the noise is read, n_today (runs the latest judged bar used), the bar's effect
# (share of base per run, or {"abs": per-run units}), the line's words, and the A/A status.

def build(root):
    specs = []
    for case in TRAFFIC_CASES:
        for metric, form, effect, words in (("xfast", "total", 0.25, "between-squad fast contacts down >= 25 %"),
                                            ("fast", "total", 0.25, "fast friendly contacts down >= 25 % (round 28's line)"),
                                            ("ownfast", "total", 0.20, "same-squad fast <= base x 1.2 + 10"),
                                            ("arrived", "total", {"abs": 2.0 / 18}, "crews in >= base - 2 (over 18 runs)"),
                                            ("allin", "median", 0.20, "all-in median <= base + 20 %"),
                                            ("fstuck", "total", 0.20, "friendly-stuck <= base x 1.2 + 10")):
            specs.append({"probe": "traffic-series " + case, "metric": metric, "form": form, "n_today": 18, "effect": effect, "line": words,
                          "read": lambda root=root, case=case, metric=metric, form=form: traffic_metric(root, case, metric, form),
                          "aa": lambda root=root, case=case, metric=metric, form=form: traffic_aa(root, case, metric, form),
                          "cost_min": TRAFFIC_COST_MIN, "unit": "run"})
        if case.endswith("/cross"):
            specs.append({"probe": "traffic-series " + case, "metric": "xclear (crossing clock, s)", "form": "mean", "n_today": 18, "effect": 0.10,
                          "line": "mean paired cross_clear_s <= 0.10 x base median + 1.645 se (T3b; the effect here is 10 % of the base MEAN)",
                          "read": lambda root=root, case=case: traffic_metric(root, case, "xclear", "mean"), "aa": None,
                          "cost_min": TRAFFIC_COST_MIN, "unit": "run"})
    specs.append({"probe": "traffic-series crossings pooled", "metric": "xfast", "form": "total", "n_today": 36, "effect": 0.25,
                  "line": "between-squad fast pooled over the two crossing cases down >= 25 % (T3, T3b)",
                  "read": lambda root=root: pooled_cases(root, ("terminus/cross", "yard_open/cross"), "xfast"), "aa": None,
                  "cost_min": TRAFFIC_COST_MIN, "unit": "run"})
    specs += [
        {"probe": "hull-rest probe (a task, OLD ruler)", "metric": "crews still moving at 75 s, wheeled turret", "form": "total", "n_today": HULL_REST_N_TODAY,
         "effect": {"abs": 5.0 / 27}, "line": "guard: <= base + 5 crews a task (M1); <= base + 2 se (M1b)", "read": lambda root=root: hull_rest_metric(root, "wheels/turret"),
         "aa": "clicked pairs (the rules never act on a clicked order): new_clicked - base_clicked moved the same class by -12..+10 a task at n = 27 (M1), see the A/A block for M1b",
         "cost_min": 2.5, "unit": "run with the class"},
        {"probe": "hull-rest probe (a task, OLD ruler)", "metric": "crews still moving at 75 s, all classes", "form": "total", "n_today": HULL_REST_N_TODAY,
         "effect": {"abs": 5.0 / 27}, "line": "guard: <= base + 5 crews a task, all classes (M1); <= base + 2 se (M1b)", "read": hull_rest_all_classes,
         "aa": "clicked pairs: all classes -16..+5 a task (M1 M1_MOVING new_clicked - base_clicked); M1b's in the A/A block", "cost_min": 2.5, "unit": "run"},
        {"probe": "hull-rest probe (a task, OLD ruler)", "metric": "hull error median, wheeled turret (310 crews)", "form": "median", "n_today": 27,
         "effect": None, "line": "clicked within +-5 deg of base; point tasks median <= 15 deg; per-class permutation p >= 0.05 (M1b)", "read": None,
         "aa": "clicked pair medians: wheeled turret -17.8..+6.3 deg (4 of 6 tasks outside +-5), ALL (651 crews) -5.8..-0.2 deg (M1); M1b's clicked pair -6.2..+8.4 deg wheeled turret, ALL within +-1.8", "cost_min": 2.5, "unit": "run"},
        {"probe": "hull-rest probe (a task, OLD ruler)", "metric": "share within 15 deg, wheeled turret", "form": "share", "n_today": 27,
         "effect": None, "line": ">= 70 % within 15 deg", "read": None,
         "aa": "owed: crews within a run are correlated, so the binomial +-2.6 pts (310 crews at 0.8) is a floor; two base runs of one task cost 2 x 48 runs ~ 4 box-hours",
         "cost_min": 2.5, "unit": "run"},
        {"probe": "hull-rest probe (a task, OLD ruler)", "metric": "settle time (75 s window)", "form": "median", "n_today": 27, "effect": None,
         "line": "settle paired median <= +6 s", "read": None, "aa": "censored: 17-25 of 27 runs never settle in the window in BOTH arms (M1); 9-13 of 15 (M1b); the line reads +0.0 whatever happens",
         "cost_min": 2.5, "unit": "run"},
        {"probe": "pinned probe (hull-rest seeds, 144 runs)", "metric": "pinned crew-seconds", "form": "total", "n_today": 144, "effect": 0.5,
         "line": "down by > 2 se (M4 b2, M4b b2); sized here for a -50 % effect", "read": lambda root=root: guard_metric(root, "PINNED", "all"),
         "aa": "owed (no base-v-base; two printed se pooled: 459.6 at M4, 422.1 at M4b run 2)", "cost_min": 0.42, "unit": "run"},
        {"probe": "pinned probe", "metric": "pinned crews (count)", "form": "total", "n_today": 144, "effect": 0.5, "line": "down (M4 b2); reported (M4b)",
         "read": lambda root=root: guard_metric(root, "PINNED", "crews"), "aa": "owed", "cost_min": 0.42, "unit": "run"},
        {"probe": "manoeuvre-fights (180 s)", "metric": "kills", "form": "total", "n_today": 24, "effect": 0.05, "line": "guard: within 2 se (M4, M4b); sized for a 5 % loss",
         "read": lambda root=root: guard_metric(root, "FIGHT_GUARD", "kills"), "aa": "owed", "cost_min": 3.5, "unit": "fight"},
        {"probe": "manoeuvre-fights (180 s)", "metric": "deaths", "form": "total", "n_today": 24, "effect": 0.05, "line": "guard: within 2 se",
         "read": lambda root=root: guard_metric(root, "FIGHT_GUARD", "deaths"), "aa": "owed", "cost_min": 3.5, "unit": "fight"},
        {"probe": "manoeuvre-fights (180 s)", "metric": "hit rate", "form": "mean", "n_today": 24, "effect": {"abs": 0.02}, "line": "guard: within 2 se; sized for -2 pts",
         "read": lambda root=root: guard_metric(root, "FIGHT_GUARD", "hit rate", "mean"), "aa": "owed", "cost_min": 3.5, "unit": "fight"},
        {"probe": "manoeuvre-fights (180 s)", "metric": "hits", "form": "total", "n_today": 24, "effect": 0.05, "line": "reported (outside 2 se at M4; within at M4b)",
         "read": lambda root=root: guard_metric(root, "FIGHT_GUARD", "hits"), "aa": "owed", "cost_min": 3.5, "unit": "fight"},
        {"probe": "Terminus census, rigs (a seed)", "metric": "arrived (of 16)", "form": "total", "n_today": TERMINUS_N_TODAY, "effect": 0.10,
         "line": "arrivals >= base (M2, M4); not down beyond 1 se / 1.645 se (M4b, M1b, M2b, kturnarc); sized for -10 %",
         "read": lambda root=root: terminus_metric(root, "rigs", "arrived"), "aa": "owed as a base-v-base; M4b run 2's rigs were byte-identical to their base (an equality check); five judged pairs pooled",
         "cost_min": 4.0, "unit": "run"},
        {"probe": "Terminus census, rigs (a seed)", "metric": "wall contact-ticks", "form": "total", "n_today": TERMINUS_N_TODAY, "effect": 0.10,
         "line": "<= base + 10 % (M2); down (M4); <= base + 1.645 se (M4b run 2); reported (M1b, M2b, kturnarc)",
         "read": lambda root=root: terminus_metric(root, "rigs", "contacts"), "aa": "owed; the base alone ranges 62..2345 a run (m4_judged.txt), 134..2921 (round 30)", "cost_min": 4.0, "unit": "run"},
        {"probe": "Terminus census, mixed (a seed)", "metric": "arrived (of 24)", "form": "total", "n_today": TERMINUS_N_TODAY, "effect": 0.10, "line": "arrivals >= base; not down beyond 1 se / 1.645 se (round 30)",
         "read": lambda root=root: terminus_metric(root, "mixed", "arrived"), "aa": "owed", "cost_min": 4.0, "unit": "run"},
        {"probe": "Terminus census, mixed (a seed)", "metric": "wall contact-ticks", "form": "total", "n_today": TERMINUS_N_TODAY, "effect": 0.10, "line": "<= base + 10 %; <= base + 1.645 se (M4b run 2)",
         "read": lambda root=root: terminus_metric(root, "mixed", "contacts"), "aa": "owed", "cost_min": 4.0, "unit": "run"},
        {"probe": "hull-rest A/A, M1's new ruler (a run)", "metric": "crews moving by real velocity", "form": "total", "n_today": 36,
         "effect": {"abs": 5.0 / 36}, "line": "reported (M1 A/A, round 34): the new ruler's null sd; CP-F 4's bars are sized on it",
         "read": lambda root=root: m1_aa_metric(root, "moving_real"),
         "aa": "this row IS an A/A (task totals swing 0-200 % between the two seed sets)", "cost_min": 2.5, "unit": "run"},
        {"probe": "hull-rest A/A, M1's new ruler (a run)", "metric": "wedged crews", "form": "total", "n_today": 36,
         "effect": {"abs": 5.0 / 36}, "line": "reported (M1 A/A): wedged hulls, now their own line (about half the old ruler's movers)",
         "read": lambda root=root: m1_aa_metric(root, "wedged"), "aa": "this row IS an A/A", "cost_min": 2.5, "unit": "run"},
        {"probe": "hull-rest A/A, M1's new ruler (a run)", "metric": "crews moving by commanded speed (the old reading)", "form": "total", "n_today": 36,
         "effect": {"abs": 5.0 / 36}, "line": "reported (M1 A/A): the old ruler's count on the new stage, for the comparison",
         "read": lambda root=root: m1_aa_metric(root, "moving"), "aa": "this row IS an A/A", "cost_min": 2.5, "unit": "run"},
        {"probe": "hull-rest gangs A/A (a run, fifo v fifo)", "metric": "crews still moving at 75 s, wheeled turret", "form": "total", "n_today": 12,
         "effect": {"abs": 1.0}, "line": "reported (P1 A/A, round 33): the null's sd a run; a pair whose own sd is far above it acted",
         "read": lambda root=root: hull_aa_metric(root, "moving"), "aa": "this row IS an A/A: the same arm twice (4bbe8322, 72 paired runs)",
         "cost_min": 2.5, "unit": "run"},
        {"probe": "hull-rest gangs A/A (a run, fifo v fifo)", "metric": "median rest error deg, wheeled turret", "form": "mean", "n_today": 12,
         "effect": {"abs": 5.0}, "line": "reported (P1 A/A); P3's faced-rest lines were sized on it (R33.26, R33.28)",
         "read": lambda root=root: hull_aa_metric(root, "rest_med"), "aa": "this row IS an A/A (4bbe8322)", "cost_min": 2.5, "unit": "run"},
        {"probe": "orbit cells (scout duel, player post, a seed)", "metric": "shots", "form": "total", "n_today": 72, "effect": 0.5,
         "line": "shots ON >= 1.5 x OFF over the player cells (C33.9 R33.24; scout try 2's (a))", "read": lambda root=root: orbit_metric(root, "shots"),
         "aa": "the free-post rows are byte-identical across arms (the turn-in never acts there): an equality check", "cost_min": 0.5, "unit": "cell-seed"},
        {"probe": "orbit cells (scout duel, player post, a seed)", "metric": "hits taken", "form": "total", "n_today": 72, "effect": 0.2,
         "line": "hits taken not up > 20 % a cell (C33.9; scout try 2's (b) on damage)", "read": lambda root=root: orbit_metric(root, "hits_taken"),
         "aa": "owed as a base-v-base", "cost_min": 0.5, "unit": "cell-seed"},
        {"probe": "orbit cells (scout duel, player post, a seed)", "metric": "damage dealt", "form": "total", "n_today": 72, "effect": 0.2,
         "line": "damage dealt v taken (R33.24's ratio line)", "read": lambda root=root: orbit_metric(root, "damage_dealt"),
         "aa": "owed", "cost_min": 0.5, "unit": "cell-seed"},
        {"probe": "orbit cells (scout duel, player post, a seed)", "metric": "gun in arc %", "form": "mean", "n_today": 72, "effect": {"abs": 5.0},
         "line": "in-arc % on in-reach cells >= 25 % (C33.9 (a): 23.9 FAILED)", "read": lambda root=root: orbit_metric(root, "in_arc_pct"),
         "aa": "owed", "cost_min": 0.5, "unit": "cell-seed"},
        {"probe": "far census (terminus / locks / random fights)", "metric": "parked far loops (L1)", "form": "total", "n_today": 144, "effect": 0.5,
         "line": "arm <= 50 % of base and drop > 1.645 se (parkedroom v1-v3)", "read": lambda root=root: far_metric(root, "L1 parked far loops"),
         "aa": "owed as a base-v-base; base totals across fight sets 22 / 51 / 224 / 90 (different trees and seeds)", "cost_min": 1.0, "unit": "fight"},
        {"probe": "far census (terminus / locks / random fights)", "metric": "all far loops (L2)", "form": "total", "n_today": 144, "effect": 0.2,
         "line": "arm <= base + 1.645 se (parkedroom v2/v3)", "read": lambda root=root: far_metric(root, "L2 all far loops"),
         "aa": "owed", "cost_min": 1.0, "unit": "fight"},
        {"probe": "far census (terminus / locks / random fights)", "metric": "kills (L3)", "form": "total", "n_today": 48, "effect": 0.03,
         "line": "within base +- 1.645 se (parkedroom v3: FAILED -3.9 %, R33.37; C34.2 re-forms it)", "read": lambda root=root: far_metric(root, "L3 kills"),
         "aa": "owed", "cost_min": 1.0, "unit": "fight"},
        {"probe": "far census (terminus / locks / random fights)", "metric": "deaths (L3)", "form": "total", "n_today": 48, "effect": 0.03,
         "line": "within base +- 1.645 se", "read": lambda root=root: far_metric(root, "L3 deaths"), "aa": "owed", "cost_min": 1.0, "unit": "fight"},
        {"probe": "far census (terminus / locks / random fights)", "metric": "hit rate (L3)", "form": "mean", "n_today": 48, "effect": {"abs": 0.01},
         "line": "arm >= base - 1.645 se", "read": lambda root=root: far_metric(root, "hit rate"), "aa": "owed", "cost_min": 1.0, "unit": "fight"},
        {"probe": "ApproachStage flank probe (a roster)", "metric": "on side (median hit bearing <= 35 deg), runs", "form": "count-runs", "n_today": 18,
         "effect": None, "line": ">= 12/18 (threshold) or v clicked 0/18 (comparison)", "read": None,
         "aa": "clicked arm 0/18 on every roster and round; the comparison form decides at n = 3-6 a side (Fisher, below)", "cost_min": 1.5, "unit": "run"},
        {"probe": "ApproachStage flank probe (a roster)", "metric": "alive (of 5)", "form": "mean", "n_today": 18, "effect": {"abs": 0.5},
         "line": "guard: alive >= clicked - 0.5", "read": lambda root=root: approach_metric(root, R28 + "brains_b1_judged_a_even.jsonl", "alive", "B1 f3a0145d (a) seeds 7-9"),
         "aa": "T1c-b's drawn artillery pair (16780030, seeds 13-15): alive 3.00 = 3.00, first round 27.1 = 27.1 s, 14 of 18 rows byte-identical (a traffic rule that barely touches the stage)", "cost_min": 1.5, "unit": "run"},
        {"probe": "ApproachStage flank probe (a roster)", "metric": "first shot s", "form": "mean", "n_today": 18, "effect": {"abs": 10.0},
         "line": "first round <= clicked + 10 s (B2 battery) / + 30 s (B1)", "read": lambda root=root: approach_metric(root, R28 + "brains_b1_judged_a_even.jsonl", "first_shot_s", "B1 f3a0145d (a)"),
         "aa": "owed", "cost_min": 1.5, "unit": "run"},
        {"probe": "ApproachStage flank probe (a roster)", "metric": "hit on side share", "form": "mean", "n_today": 18, "effect": {"abs": 0.05},
         "line": "side/rear share >= clicked", "read": lambda root=root: approach_metric(root, R28 + "brains_b1_judged_a_even.jsonl", "hit_on_side_share", "B1 f3a0145d (a)"),
         "aa": "owed", "cost_min": 1.5, "unit": "run"},
        {"probe": "ApproachStage flank probe (a roster)", "metric": "median hit bearing deg", "form": "mean", "n_today": 18, "effect": {"abs": 20.0},
         "line": "(the count line's underlying metric)", "read": lambda root=root: approach_metric(root, R28 + "brains_b1_judged_a_even.jsonl", "hit_off_median_deg", "B1 f3a0145d (a)"),
         "aa": "owed", "cost_min": 1.5, "unit": "run"},
        {"probe": "contact census (showmatch, a seed)", "metric": "enemy hull contacts under an ordered MOVE", "form": "total", "n_today": 12, "effect": 0.5,
         "line": "down >= 50 % (B3)", "read": lambda root=root: census_metric(root, R28 + "b3_contact_census", R28 + "b3_contact_census", "CONTACT_CENSUS", r"off-(\d+)\.log$", r"on-(\d+)\.log$", "under_move"),
         "aa": "owed", "cost_min": 4.0, "unit": "seed"},
        {"probe": "contact census (showmatch, a seed)", "metric": "recon deaths", "form": "total", "n_today": 12, "effect": 0.2,
         "line": "guard: not up (B3); sized for +20 %", "read": lambda root=root: census_metric(root, R28 + "b3_contact_census", R28 + "b3_contact_census", "CONTACT_CENSUS", r"off-(\d+)\.log$", r"on-(\d+)\.log$", "recon_deaths"),
         "aa": "owed", "cost_min": 4.0, "unit": "seed"},
        {"probe": "scout census (showmatch, a seed)", "metric": "fixed-gun contacts", "form": "total", "n_today": 12, "effect": 0.5,
         "line": "down (B3 shipped line: 93 -> 24)", "read": lambda root=root: census_metric(root, R28 + "b3_scout_census_off", R28 + "b3_scout_census_on", "SCOUT_CENSUS", r"(\d+)\.log$", r"(\d+)\.log$", "contacts"),
         "aa": "owed", "cost_min": 4.0, "unit": "seed"},
        {"probe": "scout census (showmatch, a seed)", "metric": "gang_scout gun on target, pts of fight time", "form": "mean", "n_today": 13, "effect": {"abs": 5.0},
         "line": ">= +5 pts outside 2 se (CP-S v1/v2, S1)", "read": lambda root=root: census_metric(root, R28 + "b3_scout_census_off", R28 + "b3_scout_census_on", "SCOUT_CENSUS", r"(\d+)\.log$", r"(\d+)\.log$", gun_on_target_pts),
         "aa": "owed", "cost_min": 4.0, "unit": "seed"},
        {"probe": "scout census (showmatch, a seed)", "metric": "kills", "form": "total", "n_today": 12, "effect": 0.2, "line": "guard: kills not down beyond 2 se",
         "read": lambda root=root: census_metric(root, R28 + "b3_scout_census_off", R28 + "b3_scout_census_on", "SCOUT_CENSUS", r"(\d+)\.log$", r"(\d+)\.log$", "kills"),
         "aa": "owed", "cost_min": 4.0, "unit": "seed"},
        {"probe": "traffic-census (3 arenas x seeds)", "metric": "artillery shots", "form": "total", "n_today": 9, "effect": 0.2, "line": "not down > 2 se (T1c); not down > 21.6 (T1c-b: FAILED on one run, 171 -> 26)",
         "read": lambda root=root: census_pooled(root, "art_shots"), "aa": "owed; T1c-b's pair alone has sd 48 a run (one Parade run carries it), T1c's 4.4", "cost_min": 5.0, "unit": "run"},
        {"probe": "traffic-census (3 arenas x seeds)", "metric": "fast friendly contacts", "form": "total", "n_today": 9, "effect": 0.1, "line": "<= base x 1.1 + 5 (T1c); <= base + 27.1 (T1c-b)",
         "read": lambda root=root: census_pooled(root, "contacts_friend_fast"), "aa": "owed", "cost_min": 5.0, "unit": "run"},
        {"probe": "traffic-census (3 arenas x seeds)", "metric": "friendly-stuck s", "form": "total", "n_today": 9, "effect": 0.2, "line": "<= base x 1.2 + 10 (T1c); <= base + 1.645 se (T1c-b)",
         "read": lambda root=root: census_pooled(root, "stuck_friend_s"), "aa": "owed", "cost_min": 5.0, "unit": "run"},
        {"probe": "traffic-census (3 arenas x seeds)", "metric": "runs with a repack while firing", "form": "count-runs", "n_today": 9, "effect": None,
         "line": "arm 0/9 and Fisher p <= 0.05 v base (T1c-b: 0/9 v 4/9, p 0.041)", "read": None,
         "aa": "the comparison decides at the n run (Fisher, below); a 0/9 v 3/9 would not (p 0.10)", "cost_min": 5.0, "unit": "run"},
        {"probe": "yard crossing cell (seeds x 6 ticks)", "metric": "runs with every crew in", "form": "count-runs", "n_today": 12, "effect": None,
         "line": "last crew in every run; median <= off - 5 s (B5c, B5c-v4)", "read": None,
         "aa": "the count decides: 12/12 v 5/12 (B5c, n = 9 a side) and 12/12 v 1/12 (B5c-v4, n = 5); the off arm never gets every crew in (11 of 12 runs at B5c-v4), so the median line is censored and has no noise estimate; the narrow fix re-run moved the same yard cells by -3.6..+17.8 s",
         "cost_min": 1.5, "unit": "run"},
        {"probe": "Sumps cell (seeds x 6 ticks, a run)", "metric": "all-within-8 m s (never = 90 s)", "form": "median", "n_today": 12, "effect": {"abs": 5.0},
         "line": "median on <= off; no run > 5 s later (B5c, B5c-v4); sized for the 5 s the lines name",
         "read": lambda root=root: cell_metric(root, "sumps", rows.all_in8_or_end, "median"),
         "aa": "owed as a base-v-base; judged pairs B5c-v4 (off 37.5 -> on 24.5 s) and B5c-v5 (24.9 -> 24.8 s, round 31; its s17 t11 +22.3 s failed the per-run line)", "cost_min": 1.5, "unit": "run"},
        {"probe": "Sumps cell (seeds x 6 ticks, a run)", "metric": "guns on arc (share)", "form": "mean", "n_today": 12, "effect": {"abs": 0.05},
         "line": "guns_on_arc >= off - 0.05 (B5c, B5c-v4)", "read": lambda root=root: cell_metric(root, "sumps", "guns_on_arc", "mean"),
         "aa": "owed; B5c-v4 read 0.941 = 0.941 and B5c-v5 0.939 = 0.939 (round 31): the arms differ by < 0.01 in every run", "cost_min": 1.5, "unit": "run"},
        {"probe": "arrive series (100 cells)", "metric": "cells within 8 m", "form": "count-cells", "n_today": 100, "effect": None,
         "line": ">= control - 1; 100/100 v 89/100 (B5c), 99 v 91 (B5c-v4), 95 v 88 (B2 v5), 97 v 93 (B3); 90 v 97 (B3b-2b, r31, FAILED); 90 = 90, 93 = 93 (B3b-2c, B10, r32: identical cells)", "read": None,
         "aa": "a rule that never acts gives 0 discordant cells (deterministic): McNemar on the discordants is the test; n for an 11 % one-way gain below",
         "cost_min": 1.2, "unit": "cell"},
        {"probe": "arrive series (100 cells)", "metric": "all-within-8 m s, cells complete in both arms", "form": "median", "n_today": 91, "effect": 0.02,
         "line": "median no slower than +2 % (B5c-v4: 29.6 -> 24.5 s over 91 complete pairs; B3b-2b r31 28.9 -> 28.1 over 88; reported since)",
         "read": lambda root=root: arrive_metric(root, "all_in8_s", "median"),
         "aa": "owed as a base-v-base; B3b-2c's and B10's arrive arms (round 32) were byte-identical in every cell, an equality and not an A/A (the rule never reached the arrive maps)", "cost_min": 1.2, "unit": "cell"},
        {"probe": "bridge-pooled (18 cells) / his bridge 108", "metric": "cells passed", "form": "deterministic", "n_today": 18, "effect": None,
         "line": "18/18; 108/108", "read": None,
         "aa": "not a sample: named cells on a deterministic sim; a new failing cell is a trace to read, not a statistic (B3b: 107/108 v control 106/108 is 2 cells gained, 1 lost: McNemar p 1.0, a coin, and the lost cell is a regression by name)",
         "cost_min": 0.19, "unit": "cell"},
    ]
    # Round 40 (native): the guard lines (CP37.1, every rules / cover / doctrine / balance bar since round 37), per fight.
    for kind in ("blob", "turtle"):
        for metric, form, effect, words in (("win", "mean", {"abs": 0.04}, "the guard's win share: a 4-point move (D2c / D3's sizing)"),
                                            ("kills", "mean", 0.05, "the guard's kills a fight within 2 se (G2t); sized for 5 %"),
                                            ("losses", "mean", 0.05, "the guard's losses a fight; sized for 5 %"),
                                            ("seconds", "mean", 0.10, "fight length (G2's median, read as a mean here); sized for 10 %")):
            specs.append({"probe": "guard line, %s (a fight)" % kind, "metric": metric, "form": form, "n_today": 160, "effect": effect,
                          "line": words, "read": lambda root=root, kind=kind, metric=metric: guard_fight_metric(root, kind, metric),
                          "aa": "OFF v OFF replays are byte-identical (R37.14: 0 flips), so the noise is the seed draw; read from mains' paired bases",
                          "cost_min": 3.3, "unit": "fight"})  # R39.1: doctrine's 3 arms x 1600 fights ~19 h at J14 on builder2
    return specs


# Round 40 (native): pairs of guard bases on main over the same fights (2601-2608 + 2701-2708, 5 maps, both sides, blob and turtle).
# Each pair is a real change (the mains differ), so its paired sd is the seed-to-seed noise of a change of that size; fights inside a
# seed are counted as independent (no icc: R37.14's per-seed se is the stricter read for a bar).
GUARD_BASE_PAIRS = [("9d325e291 -> 1c484a525 (round 37's merges)", "references/scoreboard/guards/9d325e291.fights.jsonl",
                     "references/scoreboard/guards/1c484a525.fights.jsonl"),
                    ("686150ed2 -> 8952c3d64 (R1-R3 ON, R39.2)", "references/scoreboard/guards/686150ed2.fights.jsonl",
                     "references/scoreboard/guards/8952c3d64.fights.jsonl")]


def guard_fight_value(row, metric):
    side = row["side"].lower()
    if metric == "win":
        return 1.0 if row["role"] == "guard" else 0.0
    if metric == "seconds":
        return float(row["seconds"])
    return float(row[metric][side])


def guard_fight_metric(root, kind, metric):
    lists = []
    for label, base, arm in GUARD_BASE_PAIRS:
        pairs = rows.jsonl_pairs(os.path.join(root, base), os.path.join(root, arm), ["guard", "arena", "seed", "side"], where={"guard": kind})
        lists.append((label, pairs))
    value = lambda r, metric=metric: guard_fight_value(r, metric)  # noqa: E731
    if metric != "win":
        return _pooled_pairs(lists, value, "mean")
    # A win is 0/1: most fights don't flip, and those zeros ARE the noise (a flip is the McNemar discordant), so no acted filter.
    sds, used, b_all = [], [], []
    for label, pairs in lists:
        sds.append((stats.paired_sd(rows.diffs(pairs, value)), len(pairs)))
        b_all += rows.values(pairs, value, "base")
        used.append("%s (n %d, flips %d)" % (label, len(pairs), len(stats.acted(rows.diffs(pairs, value)))))
    return {"sd_run": pooled_sd(sds), "base_run": statistics.mean(b_all), "icc": 0.0, "pairs": used, "n_pairs": len(used), "n": len(b_all)}


def pooled_cases(root, cases, metric):
    sds, bases, used = [], [], []
    for label, base, arm in TRAFFIC_PAIRS:
        cs = rows.traffic_pairs(os.path.join(root, base), os.path.join(root, arm))
        pairs = [p for c in cases if c in cs for p in cs[c]]
        d = rows.diffs(pairs, metric)
        if not pairs or not case_acted(pairs):
            continue
        sds.append((stats.paired_sd(d), len(d)))
        bases.append(statistics.mean(rows.values(pairs, metric, "base")))
        used.append(label)
    return {"sd_run": pooled_sd(sds), "base_run": statistics.mean(bases), "icc": 0.0, "pairs": used, "n_pairs": len(used)}


def jsonl_metric(root, base, arm, metric, label):
    pairs = rows.jsonl_pairs(os.path.join(root, base), os.path.join(root, arm), ["seed", "credits", "units"])
    d = rows.diffs(pairs, metric)
    return {"sd_run": stats.paired_sd(d), "base_run": statistics.mean(rows.values(pairs, metric, "base")), "icc": 0.0, "pairs": [label], "n_pairs": 1}


def census_pooled(root, metric):
    """Pool the traffic-census pairs (CENSUS_PAIRS) where the arms acted on `metric`'s neighbours (any field differs)."""
    sds, bases, used = [], [], []
    for label, base, arm in CENSUS_PAIRS:
        pairs = rows.jsonl_pairs(os.path.join(root, base), os.path.join(root, arm), CENSUS_KEY)
        if not pairs or not pairs_acted(pairs, ("contacts_friend_fast", "stuck_friend_s", "art_shots")):
            continue
        d = rows.diffs(pairs, metric)
        sds.append((stats.paired_sd(d), len(d)))
        bases.append(statistics.mean(rows.values(pairs, metric, "base")))
        used.append(label)
    return {"sd_run": pooled_sd(sds), "base_run": statistics.mean(bases) if bases else float("nan"), "icc": 0.0, "pairs": used, "n_pairs": len(used)}


def size_row(spec, read):
    """The sizing columns for one probe x metric from its noise reading."""
    sd, base, n = read["sd_run"], read["base_run"], spec["n_today"]
    out = dict(sd_run=sd, base_run=base, icc=read.get("icc", 0.0), pairs=read.get("pairs", []))
    out["se_today"] = sd * math.sqrt(n) if spec["form"] in ("total",) else sd / math.sqrt(n)
    if spec["form"] == "median":
        out["se_today"] = read.get("median_sd_18", float("nan"))
        if read.get("base_median") is not None:
            base = read["base_median"]
            out["base_run"] = base
    out["mde_today"] = stats.mde(sd, n)
    out["mde_today_share"] = out["mde_today"] / base if base else float("nan")
    effect = spec["effect"]
    if effect is None:
        out["effect_run"] = None
        out["n_needed"] = None
    else:
        out["effect_run"] = effect["abs"] if isinstance(effect, dict) else effect * base
        out["n_needed"] = stats.n_paired(sd, out["effect_run"]) if sd > 0 else 1
    if spec["form"] == "median" and not math.isnan(out["se_today"]):
        # a median line's n scales as (sd_median / x)^2 at 1.645 (a 5 % guard) for the effect named
        x = out["effect_run"]
        out["n_needed"] = max(8, math.ceil(n * (stats.Z_ALPHA_05 + stats.Z_POWER_80) ** 2 * (out["se_today"] / x) ** 2)) if x else None
        out["mde_today"] = (stats.Z_ALPHA_05 + stats.Z_POWER_80) * out["se_today"]
        out["mde_today_share"] = out["mde_today"] / base if base else float("nan")
    out["guard_today"] = stats.Z_ALPHA_05 * out["se_today"] if not math.isnan(out["se_today"]) else None
    return out

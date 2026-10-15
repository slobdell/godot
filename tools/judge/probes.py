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
TERMINUS_N_TODAY = 13

# The hull-rest tables (M1_CLASS lines) and the paired n of the wheeled-turret class in each (the per-run convention).
HULL_REST_TABLES = [
    ("M1 d7385da2 seeds 22-33", R29 + "manoeuvre/m1_judged.txt", 27),
    ("M1b 55622870 seeds 48-53", R30 + "manoeuvre/m1b_judged.txt", 15),
]
HULL_REST_N_TODAY = 15

# The tables whose FIGHT_GUARD / PINNED lines print a paired se (rows not kept): the sd a run is se / sqrt(n).
GUARD_TABLES = [
    ("M4 9db2a57c (fights 109-132, pinned 34-39)", R29 + "manoeuvre/m4_judged.txt"),
    ("M4b run 2 77a1603f (fights 157-180, pinned 54-59)", R30 + "manoeuvre/m4b_run2_judged.txt"),
]

GATE_SERIES = R30 + "brains/b5c-v4-gate-series-19eca15a.jsonl"
ARRIVE_OFF, ARRIVE_ON = R30 + "brains/b5c-v4-arrive-off-19eca15a.jsonl", R30 + "brains/b5c-v4-arrive-on-19eca15a.jsonl"


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
    return {"sd_run": pooled_sd(sds), "base_run": statistics.mean(bases) if bases else float("nan"), "icc": 0.0,
            "pairs": used, "n_pairs": len(used)}


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


def cell_metric(root, cell, metric, stat, label):
    """A gate-series cell (B5c-v4): off v on per (seed, tick); a median line carries its bootstrap sd."""
    pairs = rows.cell_pairs(os.path.join(root, GATE_SERIES), cell)
    d = rows.diffs(pairs, metric)
    b, a = rows.values(pairs, metric, "base"), rows.values(pairs, metric, "arm")
    out = {"sd_run": stats.paired_sd(d), "base_run": statistics.mean(b), "icc": stats.variance_components(rows.by_seed(pairs, metric))["icc"],
           "pairs": [label], "n_pairs": 1, "n": len(d)}
    if stat == "median":
        out["median_sd_18"] = stats.bootstrap_median_diff(b, a, reps=1000)[3]
        out["base_median"] = statistics.median(b)
    return out


def arrive_metric(root, metric, stat, label):
    """The arrive series' all-within-8 m time over the cells both arms completed (the stream's reading: 91 of 100 at B5c-v4)."""
    pairs = [(k, o, n) for k, o, n in rows.arrive_pairs(os.path.join(root, ARRIVE_OFF), os.path.join(root, ARRIVE_ON))
             if o.get(metric) is not None and n.get(metric) is not None]
    d = rows.diffs(pairs, metric)
    b, a = rows.values(pairs, metric, "base"), rows.values(pairs, metric, "arm")
    out = {"sd_run": stats.paired_sd(d), "base_run": statistics.mean(b), "icc": 0.0, "pairs": [label], "n_pairs": 1, "n": len(d)}
    if stat == "median":
        out["median_sd_18"] = stats.bootstrap_median_diff(b, a, reps=1000)[3]
        out["base_median"] = statistics.median(b)
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
        {"probe": "hull-rest probe (a task)", "metric": "crews still moving at 75 s, wheeled turret", "form": "total", "n_today": HULL_REST_N_TODAY,
         "effect": {"abs": 5.0 / 27}, "line": "guard: <= base + 5 crews a task (M1); <= base + 2 se (M1b)", "read": lambda root=root: hull_rest_metric(root, "wheels/turret"),
         "aa": "clicked pairs (the rules never act on a clicked order): new_clicked - base_clicked moved the same class by -12..+10 a task at n = 27 (M1), see the A/A block for M1b",
         "cost_min": 2.5, "unit": "run with the class"},
        {"probe": "hull-rest probe (a task)", "metric": "crews still moving at 75 s, all classes", "form": "total", "n_today": HULL_REST_N_TODAY,
         "effect": {"abs": 5.0 / 27}, "line": "guard: <= base + 5 crews a task, all classes (M1); <= base + 2 se (M1b)", "read": hull_rest_all_classes,
         "aa": "clicked pairs: all classes -16..+5 a task (M1 M1_MOVING new_clicked - base_clicked); M1b's in the A/A block", "cost_min": 2.5, "unit": "run"},
        {"probe": "hull-rest probe (a task)", "metric": "hull error median, wheeled turret (310 crews)", "form": "median", "n_today": 27,
         "effect": None, "line": "clicked within +-5 deg of base; point tasks median <= 15 deg; per-class permutation p >= 0.05 (M1b)", "read": None,
         "aa": "clicked pair medians: wheeled turret -17.8..+6.3 deg (4 of 6 tasks outside +-5), ALL (651 crews) -5.8..-0.2 deg (M1); M1b's clicked pair -6.2..+8.4 deg wheeled turret, ALL within +-1.8", "cost_min": 2.5, "unit": "run"},
        {"probe": "hull-rest probe (a task)", "metric": "share within 15 deg, wheeled turret", "form": "share", "n_today": 27,
         "effect": None, "line": ">= 70 % within 15 deg", "read": None,
         "aa": "owed: crews within a run are correlated, so the binomial +-2.6 pts (310 crews at 0.8) is a floor; two base runs of one task cost 2 x 48 runs ~ 4 box-hours",
         "cost_min": 2.5, "unit": "run"},
        {"probe": "hull-rest probe (a task)", "metric": "settle time (75 s window)", "form": "median", "n_today": 27, "effect": None,
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
         "read": lambda root=root: cell_metric(root, "sumps", rows.all_in8_or_end, "median", "B5c-v4 19eca15a seeds 14-15 x 6"),
         "aa": "owed as a base-v-base; one judged pair (off 37.5 -> on 24.5 s, 11 of 12 runs complete in both arms)", "cost_min": 1.5, "unit": "run"},
        {"probe": "Sumps cell (seeds x 6 ticks, a run)", "metric": "guns on arc (share)", "form": "mean", "n_today": 12, "effect": {"abs": 0.05},
         "line": "guns_on_arc >= off - 0.05 (B5c, B5c-v4)", "read": lambda root=root: cell_metric(root, "sumps", "guns_on_arc", "mean", "B5c-v4 19eca15a seeds 14-15 x 6"),
         "aa": "owed; the judged pair read 0.941 = 0.941 (the arms differ by < 0.01 in every run)", "cost_min": 1.5, "unit": "run"},
        {"probe": "arrive series (100 cells)", "metric": "cells within 8 m", "form": "count-cells", "n_today": 100, "effect": None,
         "line": ">= control - 1; 100/100 v 89/100 (B5c), 99 v 91 (B5c-v4), 95 v 88 (B2 v5), 97 v 93 (B3)", "read": None,
         "aa": "a rule that never acts gives 0 discordant cells (deterministic): McNemar on the discordants is the test; n for an 11 % one-way gain below",
         "cost_min": 1.2, "unit": "cell"},
        {"probe": "arrive series (100 cells)", "metric": "all-within-8 m s, cells complete in both arms", "form": "median", "n_today": 91, "effect": 0.02,
         "line": "median no slower than +2 % (B5c-v4: 29.6 -> 24.5 s over 91 complete pairs)",
         "read": lambda root=root: arrive_metric(root, "all_in8_s", "median", "B5c-v4 19eca15a seeds 29-32 (91 complete pairs)"),
         "aa": "owed as a base-v-base; one judged pair", "cost_min": 1.2, "unit": "cell"},
        {"probe": "bridge-pooled (18 cells) / his bridge 108", "metric": "cells passed", "form": "deterministic", "n_today": 18, "effect": None,
         "line": "18/18; 108/108", "read": None,
         "aa": "not a sample: named cells on a deterministic sim; a new failing cell is a trace to read, not a statistic (B3b: 107/108 v control 106/108 is 2 cells gained, 1 lost: McNemar p 1.0, a coin, and the lost cell is a regression by name)",
         "cost_min": 0.19, "unit": "cell"},
    ]
    return specs


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

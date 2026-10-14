#!/usr/bin/env python3
"""The probes this project's bars use, each metric's measured noise, and the sizing that follows (sizing S2, CP-N).

A PROBE is a runner whose rows the streams judge (traffic-series's four cases, the hull-rest probe, ...). For each
probe x metric this module knows (a) where the noise comes from: the judged pairs under references/ where the treatment
acted (pooled per-run paired sd), or the se a table printed when rows were not kept; (b) the base level per run; (c) the
form of the line a bar puts on it and the effect that bar names. `compute()` turns that into the table CP-N publishes:

  sd_run      per-run paired sd (the probe's noise, the number a bar should quote)
  base_run    the base arm's level per run (so an effect in % becomes an effect per run)
  icc         share of the paired noise that is between seeds (0: ticks are as good as seeds; > 0.3: add seeds first)
  n_today     the n the round-29 bars used
  mde_today   the smallest per-run effect n_today detects at 80 % power, 5 % one-sided, as a share of base
  effect      the effect the bar names (a share of base, or an absolute per run)
  n_needed    the paired n that detects that effect at 80 % / 5 %
  se_today    the se of the SUM (or of the median difference) at n_today: what the bar's guard line should be built on
  aa          the A/A evidence: the same arm's swing across seed sets, or 'owed' with the cost of two base runs

Everything is reproducible from `python3 tools/judge/table.py`; numbers carry their source pair and commit.
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

# The judged traffic pairs (base, arm, label); a case x metric pools the per-run paired sd over the pairs where the arms acted.
TRAFFIC_PAIRS = [
    ("CP-T 3a94f38d s13-15", R29 + "traffic/judged_base_3a94f38d_seeds131415.jsonl", R29 + "traffic/judged_hold_3a94f38d_seeds131415.jsonl"),
    ("CP-T CPU 3a94f38d s13-15", R29 + "traffic/judged_cpu_base_3a94f38d_seeds131415.jsonl", R29 + "traffic/judged_cpu_hold_3a94f38d_seeds131415.jsonl"),
    ("T3 d9b3339c s22-24", R29 + "traffic/t3_judged_base_d9b3339c_seeds222324.jsonl", R29 + "traffic/t3_judged_arm_d9b3339c_seeds222324.jsonl"),
    ("T3 v1 fcddda26 s1-3", R29 + "traffic/t3_tuning_base_fcddda26_seeds123.jsonl", R29 + "traffic/t3_tuning_v1_fcddda26_seeds123.jsonl"),
    ("T1 v4 tuning 3cd5596b s1-3", R29 + "traffic/t0_3cd5596b_seeds123.jsonl", R29 + "traffic/tuning_v4_seeds123.jsonl"),
    ("T1 v3 672eb785 s4-6", R28 + "traffic/judged-jbase-672eb785-seeds456.jsonl", R28 + "traffic/judged-jv3-672eb785-seeds456.jsonl"),
    ("T1b 474558f8 s10-12", R28 + "traffic/t1b-cbase-474558f8-seeds101112.jsonl", R28 + "traffic/t1b-ct1b-474558f8-seeds101112.jsonl"),
]
# The same ARM on different seed sets (and commits): the A/A swing of a case total at n = 18.
TRAFFIC_AA = {
    "hold ON": [("3a94f38d s13-15", R29 + "traffic/judged_hold_3a94f38d_seeds131415.jsonl"),
                ("d9b3339c s22-24", R29 + "traffic/t3_judged_base_d9b3339c_seeds222324.jsonl"),
                ("fcddda26 s1-3", R29 + "traffic/t3_tuning_base_fcddda26_seeds123.jsonl")],
    "hold OFF": [("3cd5596b s1-3", R29 + "traffic/t0_3cd5596b_seeds123.jsonl"),
                 ("3a94f38d s13-15", R29 + "traffic/judged_base_3a94f38d_seeds131415.jsonl"),
                 ("672eb785 s4-6", R28 + "traffic/judged-jbase-672eb785-seeds456.jsonl"),
                 ("474558f8 s10-12", R28 + "traffic/t1b-cbase-474558f8-seeds101112.jsonl")],
}
TRAFFIC_CASES = ("terminus/head", "terminus/cross", "yard_open/cross", "yard_open/head")
TRAFFIC_COST_MIN = 1.75  # builder0 minutes a traffic-series run, loaded (the brief: a case of 18 runs ~ 20-40 min)
ACTED_SHARE = 1.0 / 3.0  # a pair counts toward a case's noise only if the arms diverged in at least a third of its runs


def case_acted(pairs):
    """Did the treatment touch this case? A run counts as touched when its arrival times or its fast contacts differ at all
    (any divergence of the trajectories moves an arrival time); the pair counts when at least ACTED_SHARE of its runs did."""
    touched = sum(1 for _k, b, a in pairs if abs(rows.all_in_s(a) - rows.all_in_s(b)) > 0.05 or a["contacts_fast"] != b["contacts_fast"])
    return touched >= ACTED_SHARE * len(pairs)


def pooled_sd(sds_ns):
    num = sum((n - 1) * sd * sd for sd, n in sds_ns if n > 1)
    den = sum(n - 1 for sd, n in sds_ns if n > 1)
    return math.sqrt(num / den) if den else 0.0


def traffic_metric(root, case, metric, stat="total"):
    """Pool the per-run paired noise of one traffic case x metric over every judged pair where the arms acted."""
    sds, bases, iccs, used, med_sds = [], [], [], [], []
    for label, base, arm in TRAFFIC_PAIRS:
        cases = rows.traffic_pairs(os.path.join(root, base), os.path.join(root, arm))
        if case not in cases:
            continue
        pairs = cases[case]
        d = rows.diffs(pairs, metric)
        if not case_acted(pairs):
            continue  # the treatment barely touched this case: its near-zero sd is not the probe's noise under a change
        sds.append((stats.paired_sd(d), len(d)))
        bases.append(statistics.mean(rows.values(pairs, metric, "base")))
        iccs.append(stats.variance_components(rows.by_seed(pairs, metric))["icc"])
        used.append(label)
        if stat == "median":
            med_sds.append(stats.bootstrap_median_diff(rows.values(pairs, metric, "base"), rows.values(pairs, metric, "arm"), reps=1000)[3])
    out = {"sd_run": pooled_sd(sds), "base_run": statistics.mean(bases) if bases else float("nan"),
           "icc": statistics.mean(iccs) if iccs else 0.0, "pairs": used, "n_pairs": len(used)}
    if stat == "median":
        out["median_sd_18"] = statistics.mean(med_sds) if med_sds else float("nan")
        meds = [statistics.median(rows.values(rows.traffic_pairs(os.path.join(root, b), os.path.join(root, a))[case], metric, "base"))
                for l, b, a in TRAFFIC_PAIRS if l in used]
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
    table = rows.terminus_rows(os.path.join(root, R29 + "manoeuvre/m4_judged.txt"))[squad]
    d = rows.diffs(table, metric)
    return {"sd_run": stats.paired_sd(d), "base_run": statistics.mean(rows.values(table, metric, "base")), "icc": 0.0,
            "pairs": ["M4 9db2a57c seeds 14-19"], "n_pairs": 1}


def hull_rest_metric(root, klass):
    """Per-run sd of crews-still-moving from the M1_CLASS lines (se of the sum over n paired runs -> sd = se / sqrt(n))."""
    cls = [c for c in rows.class_lines(os.path.join(root, R29 + "manoeuvre/m1_judged.txt")) if c["klass"] == klass]
    sds = [(c["se"] / math.sqrt(c["n"]), c["n"]) for c in cls]
    return {"sd_run": pooled_sd(sds), "base_run": statistics.mean(c["base"] / c["n"] for c in cls), "icc": 0.0,
            "pairs": ["M1 d7385da2 seeds 22-33 (6 tasks)"], "n_pairs": 6, "n": cls[0]["n"] if cls else 0}


def hull_rest_all_classes(root):
    cls = rows.class_lines(os.path.join(root, R29 + "manoeuvre/m1_judged.txt"))
    tasks = {}
    for c in cls:
        tasks.setdefault(c["task"], []).append(c)
    sds = [(math.sqrt(sum(c["se"] ** 2 for c in v)) / math.sqrt(27), 27) for v in tasks.values()]
    return {"sd_run": pooled_sd(sds), "base_run": statistics.mean(sum(c["base"] for c in v) / 27 for v in tasks.values()), "icc": 0.0,
            "pairs": ["M1 d7385da2 seeds 22-33 (6 tasks, all classes)"], "n_pairs": 6, "n": 27}


# ---- the probe table ---------------------------------------------------------------------------------------------
# Each entry: probe, metric, form, how the noise is read, n_today (runs the round-29 bar used), the bar's effect
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
    specs.append({"probe": "traffic-series crossings pooled", "metric": "xfast", "form": "total", "n_today": 36, "effect": 0.25,
                  "line": "between-squad fast pooled over the two crossing cases down >= 25 % (T3)",
                  "read": lambda root=root: pooled_cases(root, ("terminus/cross", "yard_open/cross"), "xfast"), "aa": None,
                  "cost_min": TRAFFIC_COST_MIN, "unit": "run"})
    specs += [
        {"probe": "hull-rest probe (a task)", "metric": "crews still moving at 75 s, wheeled turret", "form": "total", "n_today": 27,
         "effect": {"abs": 5.0 / 27}, "line": "guard: <= base + 5 crews a task (M1)", "read": lambda root=root: hull_rest_metric(root, "wheels/turret"),
         "aa": "clicked pair (M1 never acts on clicked): new_clicked - base_clicked moved the same class by -12..+10 a task at n = 27 (M1_MOVING, m1_judged.txt)",
         "cost_min": 2.5, "unit": "run with the class"},
        {"probe": "hull-rest probe (a task)", "metric": "crews still moving at 75 s, all classes", "form": "total", "n_today": 27,
         "effect": {"abs": 5.0 / 27}, "line": "guard: <= base + 5 crews a task, all classes (M1)", "read": hull_rest_all_classes,
         "aa": "clicked pair: all classes -16..+5 a task (M1_MOVING new_clicked - base_clicked)", "cost_min": 2.5, "unit": "run"},
        {"probe": "hull-rest probe (a task)", "metric": "hull error median, wheeled turret (310 crews)", "form": "median", "n_today": 27,
         "effect": None, "line": "clicked within +-5 deg of base; point tasks median <= 15 deg", "read": None,
         "aa": "clicked pair medians: wheeled turret -17.8..+6.3 deg (4 of 6 tasks outside +-5), ALL (651 crews) -5.8..-0.2 deg", "cost_min": 2.5, "unit": "run"},
        {"probe": "hull-rest probe (a task)", "metric": "share within 15 deg, wheeled turret", "form": "share", "n_today": 27,
         "effect": None, "line": ">= 70 % within 15 deg", "read": None,
         "aa": "owed: crews within a run are correlated, so the binomial +-2.6 pts (310 crews at 0.8) is a floor; two base runs of one task cost 2 x 48 runs ~ 4 box-hours",
         "cost_min": 2.5, "unit": "run"},
        {"probe": "hull-rest probe (a task)", "metric": "settle time (75 s window)", "form": "median", "n_today": 27, "effect": None,
         "line": "settle paired median <= +6 s", "read": None, "aa": "censored: 17-25 of 27 runs never settle in the window in BOTH arms; the line reads +0.0 whatever happens",
         "cost_min": 2.5, "unit": "run"},
        {"probe": "pinned probe (hull-rest seeds, 144 runs)", "metric": "pinned crew-seconds", "form": "total", "n_today": 144, "effect": 0.5,
         "line": "down by > 2 se (M4 b2); sized here for a -50 % effect", "read": lambda root=root: {"sd_run": 459.6 / math.sqrt(144), "base_run": 2902 / 144, "icc": 0.0,
                                                                                                  "pairs": ["M4 9db2a57c seeds 34-39 (PINNED se 459.6)"], "n_pairs": 1},
         "aa": "owed (no base-v-base; the fight guard's se stands in for the probe's)", "cost_min": 0.42, "unit": "run"},
        {"probe": "pinned probe", "metric": "pinned crews (count)", "form": "total", "n_today": 144, "effect": 0.5, "line": "down (M4 b2)",
         "read": lambda root=root: {"sd_run": 10.9 / math.sqrt(144), "base_run": 69 / 144, "icc": 0.0, "pairs": ["M4 9db2a57c (PINNED crews se 10.9)"], "n_pairs": 1},
         "aa": "owed", "cost_min": 0.42, "unit": "run"},
        {"probe": "manoeuvre-fights (180 s)", "metric": "kills", "form": "total", "n_today": 24, "effect": 0.05, "line": "guard: within 2 se (M4); sized for a 5 % loss",
         "read": lambda root=root: {"sd_run": 21.5 / math.sqrt(24), "base_run": 1001 / 24, "icc": 0.0, "pairs": ["M4 9db2a57c FIGHT_GUARD seeds 109-132"], "n_pairs": 1},
         "aa": "owed", "cost_min": 3.5, "unit": "fight"},
        {"probe": "manoeuvre-fights (180 s)", "metric": "deaths", "form": "total", "n_today": 24, "effect": 0.05, "line": "guard: within 2 se",
         "read": lambda root=root: {"sd_run": 22.2 / math.sqrt(24), "base_run": 1010 / 24, "icc": 0.0, "pairs": ["M4 FIGHT_GUARD"], "n_pairs": 1},
         "aa": "owed", "cost_min": 3.5, "unit": "fight"},
        {"probe": "manoeuvre-fights (180 s)", "metric": "hit rate", "form": "mean", "n_today": 24, "effect": {"abs": 0.02}, "line": "guard: within 2 se; sized for -2 pts",
         "read": lambda root=root: {"sd_run": 0.012 * math.sqrt(24), "base_run": 0.717, "icc": 0.0, "pairs": ["M4 FIGHT_GUARD (paired mean se 0.012)"], "n_pairs": 1},
         "aa": "owed", "cost_min": 3.5, "unit": "fight"},
        {"probe": "manoeuvre-fights (180 s)", "metric": "hits", "form": "total", "n_today": 24, "effect": 0.05, "line": "reported (outside 2 se at M4)",
         "read": lambda root=root: {"sd_run": 1773.6 / math.sqrt(24), "base_run": 19749 / 24, "icc": 0.0, "pairs": ["M4 FIGHT_GUARD"], "n_pairs": 1},
         "aa": "owed", "cost_min": 3.5, "unit": "fight"},
        {"probe": "Terminus census, rigs (a seed)", "metric": "arrived (of 16)", "form": "total", "n_today": 6, "effect": 0.10, "line": "arrivals >= base (M2, M4); sized for -10 %",
         "read": lambda root=root: terminus_metric(root, "rigs", "arrived"), "aa": "owed (M2's and M4's bases differ by commit; two base runs = 2 x 6 runs ~ 50 box-min)",
         "cost_min": 4.0, "unit": "run"},
        {"probe": "Terminus census, rigs (a seed)", "metric": "wall contact-ticks", "form": "total", "n_today": 6, "effect": 0.10, "line": "<= base + 10 % (M2); down (M4)",
         "read": lambda root=root: terminus_metric(root, "rigs", "contacts"), "aa": "owed; the base alone ranges 62..2345 a run (m4_judged.txt)", "cost_min": 4.0, "unit": "run"},
        {"probe": "Terminus census, mixed (a seed)", "metric": "arrived (of 24)", "form": "total", "n_today": 6, "effect": 0.10, "line": "arrivals >= base",
         "read": lambda root=root: terminus_metric(root, "mixed", "arrived"), "aa": "owed", "cost_min": 4.0, "unit": "run"},
        {"probe": "Terminus census, mixed (a seed)", "metric": "wall contact-ticks", "form": "total", "n_today": 6, "effect": 0.10, "line": "<= base + 10 %",
         "read": lambda root=root: terminus_metric(root, "mixed", "contacts"), "aa": "owed", "cost_min": 4.0, "unit": "run"},
        {"probe": "ApproachStage flank probe (a roster)", "metric": "on side (median hit bearing <= 35 deg), runs", "form": "count-runs", "n_today": 18,
         "effect": None, "line": ">= 12/18 (threshold) or v clicked 0/18 (comparison)", "read": None,
         "aa": "clicked arm 0/18 on every roster and round; the comparison form decides at n = 3-6 a side (Fisher, below)", "cost_min": 1.5, "unit": "run"},
        {"probe": "ApproachStage flank probe (a roster)", "metric": "alive (of 5)", "form": "mean", "n_today": 18, "effect": {"abs": 0.5},
         "line": "guard: alive >= clicked - 0.5", "read": lambda root=root: approach_metric(root, R28 + "brains_b1_judged_a_even.jsonl", "alive", "B1 f3a0145d (a) seeds 7-9"),
         "aa": "owed", "cost_min": 1.5, "unit": "run"},
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
        {"probe": "traffic-census (3 arenas x seeds)", "metric": "artillery shots", "form": "total", "n_today": 9, "effect": 0.2, "line": "not down > 2 se (T1c)",
         "read": lambda root=root: jsonl_metric(root, R29 + "traffic/t1c_census_base_761bd727_seeds456.jsonl", R29 + "traffic/t1c_census_arm_761bd727_seeds456.jsonl", "art_shots", "T1c 761bd727 seeds 4-6"),
         "aa": "owed", "cost_min": 5.0, "unit": "run"},
        {"probe": "traffic-census (3 arenas x seeds)", "metric": "fast friendly contacts", "form": "total", "n_today": 9, "effect": 0.1, "line": "<= base x 1.1 + 5 (T1c)",
         "read": lambda root=root: jsonl_metric(root, R29 + "traffic/t1c_census_base_761bd727_seeds456.jsonl", R29 + "traffic/t1c_census_arm_761bd727_seeds456.jsonl", "contacts_friend_fast", "T1c 761bd727"),
         "aa": "owed", "cost_min": 5.0, "unit": "run"},
        {"probe": "yard / Sumps / Terminus cells (a cell)", "metric": "runs with every crew in", "form": "count-runs", "n_today": 12, "effect": None,
         "line": "last crew in every run; median <= off - 5 s (B5c)", "read": None,
         "aa": "the yard count (12/12 v 5/12) decides at n = 9 a side; the median has no rows: two base runs of a cell = 2 x 12 runs ~ 35 box-min; the narrow fix re-run moved the same yard cells by -3.6..+17.8 s",
         "cost_min": 1.5, "unit": "run"},
        {"probe": "arrive series (100 cells)", "metric": "cells within 8 m", "form": "count-cells", "n_today": 100, "effect": None,
         "line": ">= control - 1; 100/100 v 89/100 (B5c), 95 v 88 (B2 v5), 97 v 93 (B3)", "read": None,
         "aa": "a rule that never acts gives 0 discordant cells (deterministic): McNemar on the discordants is the test; n for an 11 % one-way gain below",
         "cost_min": 1.2, "unit": "cell"},
        {"probe": "bridge-pooled (18 cells) / his bridge 108", "metric": "cells passed", "form": "deterministic", "n_today": 18, "effect": None,
         "line": "18/18; 108/108", "read": None, "aa": "not a sample: named cells on a deterministic sim; a new failing cell is a trace to read, not a statistic",
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

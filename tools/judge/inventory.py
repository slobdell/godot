#!/usr/bin/env python3
"""Sizing S1: the inventory of every judged bar line of rounds 27-29 with its measured noise.

    python3 tools/judge/inventory.py [--csv OUT.csv] [--md OUT.md] [--root REPO]

Reads `lines.py` (the lines as the streams quoted them) and, for every line whose rows are kept under
`_agents/streams/references/`, computes the noise FROM THE ROWS: the paired se of the line's statistic (sum, mean or
bootstrap median difference over the (seed, tick) pairs), the exact p of a count line, the A/A swing where a base-v-base
pair exists. Two readings per line:

  line inside the noise   the line's margin from "no change" (x) is smaller than 1.645 se: a treatment that changes
                          NOTHING fails a guard, or passes a gain line, more than 5 % of the time at this n. The line
                          could not be judged at this n whatever the result was.
  verdict margin (se)     how many se the observed value cleared (+) or missed (-) the line by. |margin| < 1.645 means
                          the verdict itself could have gone the other way on another seed set.

For traffic lines the quoted totals are re-derived from the rows and printed beside the quote (a reader that disagrees
with the verdict scripts is wrong). Writes the csv the markdown is generated from; both default to
`_agents/streams/references/round30/sizing/`.
"""
import argparse
import csv
import math
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lines  # noqa: E402
import rows  # noqa: E402
import stats  # noqa: E402

Z = stats.Z_ALPHA_05
OUT_DIR = "_agents/streams/references/round30/sizing"


def threshold(base, x, pass_dir):
    """The pass threshold's value and the sign that turns (arm - threshold) into 'cleared by'."""
    if pass_dir in ("down", "notdown"):
        thr = base - x
    else:
        thr = base + x
    sign = 1.0 if pass_dir in ("up", "notdown") else -1.0  # arm above the threshold passes for up/notdown
    return thr, sign


def read_pairs_total(diffs, base_vals, arm_vals, spec):
    out = {}
    live = stats.acted(diffs)
    base_t, arm_t = sum(base_vals), sum(arm_vals)
    se = stats.paired_se_total(diffs)
    out.update(reproduced="rows: %s -> %s (n %d, %d runs where the arms differ)" % (fmt(base_t), fmt(arm_t), len(diffs), len(live)))
    if not live:
        out.update(se=0.0, how="identical arms: an equality check, not a sample", x=spec.get("x") or 0.0, inside="n/a", clear_se=None)
        return out
    x = spec.get("x")
    if x is None and spec.get("x_share") is not None:
        x = spec["x_share"] * base_t
    if x is None and spec.get("x_se") is not None:
        x = spec["x_se"] * se
    thr, sign = threshold(base_t, x, spec["pass_dir"])
    clear = sign * (arm_t - thr)
    out.update(se=se, how="paired se of the sum over %d runs (sd %.2f a run)" % (len(diffs), stats.paired_sd(diffs)) + zero_note(x), x=x,
               inside="Y" if x < Z * se else "N", clear_se=clear / se if se else None, threshold=thr)
    return out


def zero_note(x):
    return "; x = 0: a pure direction check, which a treatment that changes nothing fails half the time" if x == 0 else ""


def read_pairs_mean(diffs, base_vals, arm_vals, spec):
    out = {}
    live = stats.acted(diffs)
    n = len(diffs)
    base_m, arm_m = statistics.mean(base_vals), statistics.mean(arm_vals)
    se = stats.paired_se_mean(diffs)
    out.update(reproduced="rows: mean %.2f -> %.2f (n %d)" % (base_m, arm_m, n))
    if not live:
        out.update(se=0.0, how="identical arms", x=spec.get("x") or 0.0, inside="n/a", clear_se=None)
        return out
    x = spec.get("x")
    if x is None and spec.get("x_share") is not None:
        x = spec["x_share"] * base_m
    thr, sign = threshold(base_m, x, spec["pass_dir"])
    out.update(se=se, how="paired se of the mean over %d runs (sd %.2f a run)" % (n, stats.paired_sd(diffs)), x=x,
               inside="Y" if x < Z * se else "N", clear_se=sign * (arm_m - thr) / se if se else None, threshold=thr)
    return out


def read_pairs_median(base_vals, arm_vals, spec):
    out = {}
    diffs = [a - b for a, b in zip(arm_vals, base_vals)]
    base_m, arm_m = statistics.median(base_vals), statistics.median(arm_vals)
    out.update(reproduced="rows: median %.1f -> %.1f (n %d)" % (base_m, arm_m, len(diffs)))
    if not stats.acted(diffs):
        out.update(se=0.0, how="identical arms", x=0.0, inside="n/a", clear_se=None)
        return out
    point, lo, hi, sd = stats.bootstrap_median_diff(base_vals, arm_vals)
    x = spec.get("x")
    if x is None and spec.get("x_share") is not None:
        x = spec["x_share"] * base_m
    thr, sign = threshold(base_m, x, spec["pass_dir"])
    out.update(se=sd, how="bootstrap sd of the paired median difference (90 %% interval %+.1f..%+.1f)" % (lo, hi), x=x,
               inside="Y" if x < Z * sd else "N", clear_se=sign * (arm_m - thr) / sd if sd else None, threshold=thr)
    return out


def noise_of(line, root):
    spec = line["noise"]
    kind = spec["kind"]
    out = {"kind": kind, "se": None, "how": "", "x": spec.get("x"), "inside": "-", "clear_se": None, "p": None, "reproduced": "",
           "n_decides": None}
    path = lambda p: os.path.join(root, p)  # noqa: E731
    if kind == "none":
        out["how"] = spec.get("note", "no noise estimate: deterministic cells or a reported line")
        return out
    if kind == "se":
        se, x, clear = spec["se"], spec["x"], spec["clear"]
        out.update(se=se, how="the table's own se" + ("; " + spec["note"] if "note" in spec else ""), x=x,
                   inside=("Y" if x < Z * se else "N") if x is not None else "-", clear_se=clear / se if se else None)
        return out
    if kind == "aa":
        out.update(se=spec["swing"] / 2.0, how="A/A swing +-%.1f read as ~2 se; %s" % (spec["swing"], spec.get("note", "")), x=spec["x"],
                   inside="Y" if spec["x"] < spec["swing"] else "N")
        return out
    if kind == "fisher":
        two, one = stats.fisher_exact(spec["a"], spec["n1"] - spec["a"], spec["c"], spec["n2"] - spec["c"])
        out.update(p=one, how="Fisher exact %d/%d v %d/%d: one-sided p %.4f (two-sided %.4f)" % (spec["a"], spec["n1"], spec["c"], spec["n2"], one, two)
                   + ("; " + spec["note"] if "note" in spec else ""))
        out["n_decides"] = min_n_either_way(spec["a"] / spec["n1"], spec["c"] / spec["n2"])
        out["inside"] = "n/a"
        return out
    if kind == "mcnemar":
        p = stats.mcnemar_exact(spec["b"], spec["c"])
        out.update(p=p, how="McNemar exact over %d discordant cells (%d for, %d against): p %.4f" % (spec["b"] + spec["c"], spec["b"], spec["c"], p),
                   inside="n/a")
        return out
    if kind == "binom":
        k, n, K = spec["k"], spec["n"], spec["K"]
        p_hat = min(max(k / n, 1.0 / n), 1.0 - 1.0 / n)
        sd = math.sqrt(n * p_hat * (1.0 - p_hat))
        out.update(se=sd, how="binomial sd of the count at the observed rate %.2f (crews or runs read as independent: an upper bound on the certainty)" % (k / n),
                   x=None, inside="n/a", clear_se=(k - K) / sd)
        if "fisher" in spec:
            f = spec["fisher"]
            two, one = stats.fisher_exact(f["a"], f["n1"] - f["a"], f["c"], f["n2"] - f["c"])
            out["p"] = one
            out["how"] += "; v control Fisher one-sided p %.4f" % one
            out["n_decides"] = min_n_either_way(f["a"] / f["n1"], f["c"] / f["n2"])
        return out
    if kind == "poisson":
        a, b, x = spec["a"], spec["b"], spec["x"]
        sd = stats.poisson_diff_sd(a, b)
        thr, sign = threshold(a, x, spec["pass_dir"])
        out.update(se=sd, how="Poisson sd of a difference of counts, sqrt(a + b) (episodes are not independent: a lower bound on the noise)",
                   x=x, inside="Y" if x < Z * sd else "N", clear_se=sign * (b - thr) / sd)
        return out
    if kind == "traffic":
        cases = rows.traffic_pairs(path(spec["base"]), path(spec["arm"]))
        names = spec["case"] if isinstance(spec["case"], list) else [spec["case"]]
        pairs = [p for c in names for p in cases[c]]
        d = rows.diffs(pairs, spec["metric"])
        b, a = rows.values(pairs, spec["metric"], "base"), rows.values(pairs, spec["metric"], "arm")
        if spec["stat"] == "total":
            out.update(read_pairs_total(d, b, a, spec))
        elif spec["stat"] == "mean":
            out.update(read_pairs_mean(d, b, a, spec))
        else:
            out.update(read_pairs_median(b, a, spec))
        return out
    if kind == "jsonl":
        pairs = rows.jsonl_pairs(path(spec["base"]), path(spec["arm"]), spec["key"])
        d = rows.diffs(pairs, spec["metric"])
        b, a = rows.values(pairs, spec["metric"], "base"), rows.values(pairs, spec["metric"], "arm")
        out.update(read_pairs_total(d, b, a, spec))
        return out
    if kind == "census":
        off = rows.census_pairs(path(spec["off"]), path(spec["off"]), spec["tag"], pattern=spec["off_pattern"])
        on = rows.census_pairs(path(spec["on"]), path(spec["on"]), spec["tag"], pattern=spec["on_pattern"])
        off_by = {s: o for s, o, _ in off}
        on_by = {s: o for s, o, _ in on}
        pairs = [(s, off_by[s], on_by[s]) for s in sorted(off_by) if s in on_by]
        d = rows.diffs(pairs, spec["metric"])
        b, a = rows.values(pairs, spec["metric"], "base"), rows.values(pairs, spec["metric"], "arm")
        out.update(read_pairs_total(d, b, a, spec))
        return out
    if kind == "terminus":
        table = rows.terminus_rows(path(spec["path"]))[spec["squad"]]
        pairs = [(s, b, n) for s, b, n in table]
        d = rows.diffs(pairs, spec["metric"])
        b, a = rows.values(pairs, spec["metric"], "base"), rows.values(pairs, spec["metric"], "arm")
        out.update(read_pairs_total(d, b, a, spec))
        return out
    if kind == "approach":
        pairs = rows.approach_pairs(path(spec["path"]))
        d = rows.diffs(pairs, spec["metric"])
        b, a = rows.values(pairs, spec["metric"], "base"), rows.values(pairs, spec["metric"], "arm")
        spec = dict(spec, pass_dir="notdown")
        out.update(read_pairs_mean(d, b, a, spec))
        return out
    if kind == "m1_guard":
        cls = [c for c in rows.class_lines(path(spec["path"])) if c["task"] == spec["task"]]
        se_all = math.sqrt(sum(c["se"] ** 2 for c in cls))
        wt = [c for c in cls if c["klass"] == "wheels/turret"]
        out.update(se=se_all, how="all classes: sqrt(sum of M1_CLASS se^2) = %.1f; wheels/turret alone se %.1f (diff %+d)" % (
            se_all, wt[0]["se"] if wt else float("nan"), wt[0]["diff"] if wt else 0), x=spec["x"],
            inside="Y" if spec["x"] < Z * se_all else "N", clear_se=spec["clear"] / se_all if se_all else None,
            reproduced="M1_CLASS sum of diffs %+d" % sum(c["diff"] for c in cls))
        return out
    if kind == "m1_clicked":
        med = rows.hull_medians(path(spec["path"]), "M1_HULL")
        swings = {}
        for (task, klass, arm), v in med.items():
            if arm == "new_clicked" and klass in ("ALL", "wheels/turret"):
                swings[(task, klass)] = v - med[(task, klass, "base_clicked")]
        worst_all = max(abs(v) for (t, k), v in swings.items() if k == "ALL")
        worst_wt = max(abs(v) for (t, k), v in swings.items() if k == "wheels/turret")
        outside = sum(1 for (t, k), v in swings.items() if k == "wheels/turret" and abs(v) > spec["x"])
        out.update(se=worst_wt / 2.0, how="A/A: new_clicked - base_clicked medians, ALL worst %.1f deg, wheels/turret worst %.1f deg, %d of 6 tasks outside +-%g" % (
            worst_all, worst_wt, outside, spec["x"]), x=spec["x"], inside="Y" if worst_wt > spec["x"] else "N")
        return out
    raise ValueError("unknown noise kind %r" % kind)


def min_n_either_way(p_arm, p_control):
    """fisher_min_n in the observed direction (a line that counts contacts passes DOWN; one that counts on-side runs, UP)."""
    if p_arm == p_control:
        return None
    if p_arm > p_control:
        return stats.fisher_min_n(p_control, p_arm)
    return stats.fisher_min_n(1.0 - p_control, 1.0 - p_arm)


def fmt(v):
    if v is None:
        return ""
    if isinstance(v, float):
        return "%.2f" % v if abs(v) < 100 else "%.0f" % v
    return str(v)


COLUMNS = ["round", "stream", "item", "commit", "machine", "line", "form", "n", "rule", "base", "arm", "verdict", "noise_kind",
           "noise_se", "noise_how", "line_x", "line_inside_noise", "verdict_margin_se", "exact_p", "n_decides", "reproduced", "source"]


def build(root):
    table = []
    for line in lines.LINES:
        noise = noise_of(line, root)
        table.append({"round": line["round"], "stream": line["stream"], "item": line["item"], "commit": line["commit"],
                      "machine": line["machine"], "line": line["line"], "form": line["form"], "n": line["n"], "rule": line["rule"],
                      "base": line["base"], "arm": line["arm"], "verdict": line["verdict"], "noise_kind": noise["kind"],
                      "noise_se": fmt(noise["se"]), "noise_how": noise["how"], "line_x": fmt(noise["x"]),
                      "line_inside_noise": noise["inside"], "verdict_margin_se": fmt(noise["clear_se"]),
                      "exact_p": ("%.4f" % noise["p"]) if noise["p"] is not None else "", "n_decides": fmt(noise["n_decides"]),
                      "reproduced": noise["reproduced"], "source": line["source"]})
    return table


def write_csv(table, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=COLUMNS)
        writer.writeheader()
        for row in table:
            writer.writerow(row)


def write_md(table, path, csv_name):
    judged = [r for r in table if r["verdict"].split()[0] in ("PASS", "FAIL", "KEPT")]
    inside = [r for r in judged if r["line_inside_noise"] == "Y"]
    thin = [r for r in judged if r["verdict_margin_se"] not in ("", None) and abs(float(r["verdict_margin_se"])) < Z
            and r["line_inside_noise"] != "n/a"]
    for r in table:
        if r["base"].startswith("(rows)"):
            r["base"], r["arm"] = r["reproduced"].replace("rows: ", ""), r["arm"].replace("(rows; ", "(").replace("(rows)", "")
    with_noise = [r for r in table if r["line_inside_noise"] in ("Y", "N")]
    out = []
    out.append("# The inventory: every judged bar line of rounds 27–29, with its noise (sizing S1)\n")
    out.append("Generated by `python3 tools/judge/inventory.py` from `tools/judge/lines.py` (the lines as the streams quoted them in "
               "`_agents/workstreams.md` *Bars* and the tables under `references/round27..29/`) and the rows kept there; the csv beside "
               "this file (`%s`) is the full table, this page is its reading. Every number is the streams' own (builder0 unless the "
               "line says otherwise, the commit in its column); the noise columns are computed here from the rows.\n" % csv_name)
    out.append("**Columns.** *noise se*: the se of the line's statistic (a paired sum, mean or bootstrap median difference over the "
               "(seed, tick) pairs; the table's own se where no rows were kept; a binomial or Poisson sd for counts). *line x*: the line's "
               "margin from \"no change\" in the statistic's units (the guard's X, 25 % of the base, 2 se). **Line inside the noise = Y** "
               "when x < 1.645 se: a treatment that changes nothing fails that guard (or passes that gain line) more than 5 % of the time "
               "at that n, so the line could not be judged at that n whatever the result. *verdict margin (se)*: how many se the observed "
               "value cleared (+) or missed (−) the line by; |margin| < 1.645 means another seed set could have flipped the verdict. "
               "*exact p*: Fisher / McNemar for count lines. *n decides*: the n per arm at which a count line of the observed rates reaches "
               "80 % power (Fisher, one-sided 5 %).\n")
    out.append("## The count\n")
    out.append("| | lines |\n|---|---|")
    out.append("| judged lines listed (PASS / FAIL / KEPT) | %d |" % len(judged))
    out.append("| lines with a noise estimate (rows or a printed se) | %d |" % len(with_noise))
    out.append("| **judged pass lines INSIDE the noise** (x < 1.645 se; %d of them pure direction checks with x = 0) | **%d** |" % (
        sum(1 for r in inside if r["line_x"] in ("0", "0.00")), len(inside)))
    out.append("| judged verdicts within 1.645 se of their line (could flip on another seed set) | %d |" % len(thin))
    out.append("| lines where the arms were byte-identical (equality checks, 0 noise) | %d |" % sum(1 for r in table if r["noise_how"].startswith("identical")))
    out.append("| lines with no noise estimate possible (deterministic cells, reported, no rows) | %d |\n" % sum(1 for r in table if r["noise_kind"] == "none"))
    out.append("## Pass lines inside the noise\n")
    out.append("| round | stream | item | line | rule | result | verdict | x | se | margin (se) |\n|---|---|---|---|---|---|---|---|---|---|")
    for r in inside:
        out.append("| %d | %s | %s | %s | %s | %s → %s | %s | %s | %s | %s |" % (r["round"], r["stream"], r["item"], r["line"], r["rule"],
                                                                                r["base"], r["arm"], r["verdict"], r["line_x"], r["noise_se"],
                                                                                r["verdict_margin_se"]))
    out.append("\n## Verdicts that cleared their line by less than 1.645 se\n")
    out.append("| round | stream | item | line | result | verdict | margin (se) | how the noise was read |\n|---|---|---|---|---|---|---|---|")
    for r in thin:
        out.append("| %d | %s | %s | %s | %s → %s | %s | %s | %s |" % (r["round"], r["stream"], r["item"], r["line"], r["base"], r["arm"],
                                                                      r["verdict"], r["verdict_margin_se"], r["noise_how"]))
    out.append("\n## Every line\n")
    out.append("| round | stream | item | commit | line | form | n | rule | base → arm | verdict | noise kind | se | x | inside | margin (se) | p | n decides | from the rows |\n"
               "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for r in table:
        out.append("| %d | %s | %s | %s | %s | %s | %s | %s | %s → %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            r["round"], r["stream"], r["item"], r["commit"], r["line"], r["form"], r["n"], r["rule"], r["base"], r["arm"], r["verdict"],
            r["noise_kind"], r["noise_se"], r["line_x"], r["line_inside_noise"], r["verdict_margin_se"], r["exact_p"], r["n_decides"],
            r["reproduced"]))
    out.append("\n## How the noise was read, line by line\n")
    for r in table:
        if r["noise_how"]:
            out.append("- **R%d %s %s** — %s: %s" % (r["round"], r["stream"], r["item"], r["line"], r["noise_how"]))
    with open(path, "w") as handle:
        handle.write("\n".join(out) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=os.path.dirname(os.path.dirname(HERE)))
    parser.add_argument("--csv", default=None)
    parser.add_argument("--md", default=None)
    args = parser.parse_args()
    csv_path = args.csv or os.path.join(args.root, OUT_DIR, "inventory.csv")
    md_path = args.md or os.path.join(args.root, OUT_DIR, "inventory.md")
    table = build(args.root)
    write_csv(table, csv_path)
    write_md(table, md_path, os.path.basename(csv_path))
    inside = sum(1 for r in table if r["line_inside_noise"] == "Y")
    print("INVENTORY %d lines, %d with a noise estimate, %d pass lines inside the noise -> %s, %s" % (
        len(table), sum(1 for r in table if r["line_inside_noise"] in ("Y", "N")), inside, csv_path, md_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())

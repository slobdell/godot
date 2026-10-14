#!/usr/bin/env python3
"""Sizing S2 (CP-N): render the per-probe n table into `_agents/judging.md` (between its markers) and a csv.

    python3 tools/judge/table.py [--root REPO] [--doc _agents/judging.md] [--csv references/round30/sizing/table.csv]

Every number comes from `probes.py` (the rows under references/, or the se a judged table printed). The doc keeps
three generated blocks, each between `<!-- judge:NAME:begin -->` and `<!-- judge:NAME:end -->`:
  table    one row per probe x metric: noise a run, n today, the se to quote, the bar's effect, n needed, MDE, guard
  counts   count lines: the n at which two-arm run counts, one-arm thresholds and paired cells decide
  aa       the A/A evidence: the same traffic arm across seed sets; the hull-rest clicked pair; the yard cells
"""
import argparse
import csv
import math
import os
import re
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import probes  # noqa: E402
import rows  # noqa: E402
import stats  # noqa: E402

DOC = "_agents/judging.md"
CSV = "_agents/streams/references/round30/sizing/table.csv"
COLUMNS = ["probe", "metric", "form", "sd_run", "base_run", "icc", "n_today", "se_today", "line", "effect_run", "effect_share",
           "n_needed", "mde_today", "mde_today_share", "guard_today", "cost_today_min", "cost_needed_min", "aa", "pairs"]


def f1(v, nd=1):
    """nd decimals, but never fewer than three significant digits for a small value (a hit rate's se is 0.012, not 0.0)."""
    if v is None or (isinstance(v, float) and math.isnan(v)):
        return "–"
    if v != 0 and abs(v) < 10 ** (2 - nd):
        return "%.3g" % v
    return ("%%.%df" % nd) % v


def pct(v):
    return "–" if v is None or (isinstance(v, float) and math.isnan(v)) else "%.0f %%" % (100.0 * v)


def table_rows(root):
    out = []
    for spec in probes.build(root):
        row = {"probe": spec["probe"], "metric": spec["metric"], "form": spec["form"], "n_today": spec["n_today"], "line": spec["line"],
               "aa": spec["aa"] if isinstance(spec["aa"], str) else "", "pairs": ""}
        if spec["read"] is None:
            out.append(row)
            continue
        read = spec["read"](root) if spec["read"].__code__.co_argcount else spec["read"]()
        if not read.get("pairs") or read["sd_run"] == 0:
            row["aa"] = ("owed: no judged pair touched this case (every pair's arms were identical here), so its noise under a change is "
                         "unmeasured; two base runs of the case cost %d runs ~ %.0f box-min" % (2 * spec["n_today"], 2 * spec["n_today"] * spec["cost_min"]))
            out.append(row)
            continue
        size = probes.size_row(spec, read)
        row.update(sd_run=size["sd_run"], base_run=size["base_run"], icc=size["icc"], se_today=size["se_today"], effect_run=size["effect_run"],
                   effect_share=(size["effect_run"] / size["base_run"]) if size["effect_run"] is not None and size["base_run"] else None,
                   n_needed=size["n_needed"], mde_today=size["mde_today"], mde_today_share=size["mde_today_share"], guard_today=size["guard_today"],
                   cost_today_min=spec["n_today"] * spec["cost_min"] * 2, cost_needed_min=(size["n_needed"] * spec["cost_min"] * 2) if size["n_needed"] else None,
                   pairs="; ".join(size["pairs"]))
        if callable(spec.get("aa")):
            aa = spec["aa"](root)
            row["aa"] = "; ".join("%s: %s" % (arm, ", ".join("%s %s" % (lab, f1(v, 1) if spec["form"] == "median" else f1(v, 0)) for lab, v in vals))
                                  for arm, vals in aa.items())
        out.append(row)
    return out


def render_table(trows):
    lines = ["| probe | metric | form | noise: sd a run | base a run | icc | n today | **se at n today** (quote this) | the bar's line | effect named (a run) | **n that decides it** (80 % / 5 %) | MDE at n today | noise-sized guard at n today | box-min today → needed |",
             "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for r in trows:
        if "sd_run" not in r:
            lines.append("| %s | %s | %s | – | – | – | %d | – | %s | – | %s | – | – | – |" % (
                r["probe"], r["metric"], r["form"], r["n_today"], r["line"], "owed (A/A column)" if r["aa"].startswith("owed") else "see *Count lines* / A/A"))
            continue
        eff = "–" if r["effect_run"] is None else ("%s (%s)" % (f1(r["effect_run"], 2), pct(r["effect_share"])))
        guard = "–" if r["guard_today"] is None else ("base ± %s" % f1(r["guard_today"], 1))
        cost = "%s → %s" % (f1(r["cost_today_min"], 0), f1(r["cost_needed_min"], 0) if r["cost_needed_min"] else "–")
        n_needed = "–" if not r["n_needed"] else ("> 1000 (not affordable)" if r["n_needed"] > 1000 else f1(r["n_needed"], 0))
        lines.append("| %s | %s | %s | %s | %s | %s | %d | %s | %s | %s | **%s** | %s (%s) | %s | %s |" % (
            r["probe"], r["metric"], r["form"], f1(r["sd_run"], 2), f1(r["base_run"], 2), f1(r["icc"], 2), r["n_today"], f1(r["se_today"], 1),
            r["line"], eff, n_needed, f1(r["mde_today"], 2), pct(r["mde_today_share"]), guard, cost))
    return "\n".join(lines)


def render_counts():
    out = ["**Two arms' run counts (Fisher exact, one-sided 5 %), the n a side at which the OBSERVED rates reach 80 % power:**\n",
           "| observed (arm v control) | one-sided p at the n run | n a side that decides it |", "|---|---|---|"]
    for a, n1, c, n2, label in ((18, 18, 0, 18, "B1 r29 on side"), (14, 18, 0, 18, "B2 (a) r29"), (10, 18, 0, 18, "B1 (a) r28, failed its 12/18 threshold"),
                                (4, 18, 0, 18, "B1 (c) r28"), (12, 12, 5, 12, "B5c yard, every crew in"), (9, 18, 0, 18, "S3 / S4 contact runs (read as 0 v 9)"),
                                (21, 24, 14, 24, "B2 v4 Sumps cell"), (12, 12, 10, 12, "a 12/12 v 10/12 cell")):
        two, one = stats.fisher_exact(a, n1 - a, c, n2 - c)
        n = stats.fisher_min_n(c / n2, a / n1) if a / n1 > c / n2 else stats.fisher_min_n(1 - c / n2, 1 - a / n1)
        out.append("| %d/%d v %d/%d (%s) | %.4f | %s |" % (a, n1, c, n2, label, one, n if n else "not by 400"))
    out.append("\n**One arm against a threshold (\"on side ≥ 12/18\"): how often the line passes at a true rate p (binomial):**\n")
    out.append("| line | p = 0.5 | p = 0.6 | p = 0.67 | p = 0.8 | p = 0.9 |")
    out.append("|---|---|---|---|---|---|")
    for K, n in ((12, 18), (16, 18), (9, 18), (8, 12), (24, 36)):
        out.append("| ≥ %d/%d | %s |" % (K, n, " | ".join("%.2f" % stats.binom_tail(K, n, p) for p in (0.5, 0.6, 0.67, 0.8, 0.9))))
    out.append("\nA threshold at two thirds of 18 runs passes a true 50 %% rule a quarter of the time and fails a true 80 %% rule a tenth of the "
               "time: it separates 0.5 from 0.8, not 0.6 from 0.75. The comparison form (arm v clicked, Fisher) is what decided every "
               "flank line that passed; write the count line as the comparison plus the rate's exact 90 %% interval, and keep the threshold "
               "only where a minimum rate is itself the product promise (then size it: 0.67 v 0.5 at 80 %% power needs n ≈ %d).\n" % (
                   stats.fisher_min_n(0.5, 0.67) or 0))
    out.append("**Paired cells (the arrive series, the bridge cells): a rule that never acts leaves every cell identical, so the discordant "
               "cells carry the whole test (McNemar exact):**\n")
    out.append("| discordant cells (for v against) | exact p | reading |")
    out.append("|---|---|---|")
    for b, c, label in ((11, 0, "B5c arrive 100/100 v 89/100"), (8, 1, "B2 v5 95 v 88"), (5, 1, "B3 make-room 97 v 93"), (7, 4, "B2 v3 89 v 86"),
                        (4, 2, "B2 v4 85 v 83"), (0, 1, "M4 bridge 17/18 v 18/18"), (1, 0, "one cell gained")):
        out.append("| %d v %d (%s) | %.4f | %s |" % (b, c, label, stats.mcnemar_exact(b, c), "decided" if stats.mcnemar_exact(b, c) <= 0.05 else "not decided: a coin"))
    out.append("\nCells needed for a one-way gain (the arm wins cells the base loses, never the reverse) at 80 %% power: a %d %% gain needs %s cells, "
               "5 %% needs %s, 2 %% needs %s. A line \"lost ≤ 1\" is a direction check on the against-cells alone; \"≥ control − 1\" fails on one "
               "unlucky cell, which at 100 cells of an 11 %% base failure rate is a coin (p = 1.0 for 0 v 1)." % (
                   11, stats.mcnemar_min_n(0.11, 0.0), stats.mcnemar_min_n(0.05, 0.0), stats.mcnemar_min_n(0.02, 0.0)))
    return "\n".join(out)


def render_aa(root):
    out = ["**traffic-series, the same arm on different seed sets (and commits): the swing of a case total at n = 18.** A null's "
           "swing between seed sets is what a 'within 2 se' or '≥ base − 2' line must clear.\n",
           "| case | metric | hold ON (3 seed sets) | swing | hold OFF (4 seed sets) | swing |", "|---|---|---|---|---|---|"]
    for case in probes.TRAFFIC_CASES:
        for metric, stat in (("fast", "total"), ("xfast", "total"), ("arrived", "total"), ("allin", "median"), ("fstuck", "total")):
            aa = probes.traffic_aa(root, case, metric, stat)
            cells = []
            for arm in ("hold ON", "hold OFF"):
                vals = [v for _l, v in aa[arm]]
                if metric == "xfast" and arm == "hold OFF":
                    vals = [v for v in vals if v > 0]  # round 28's T0 predates the between-squad split (0 recorded)
                swing = (max(vals) - min(vals)) / statistics.mean(vals) if vals and statistics.mean(vals) else 0.0
                cells.append(", ".join(f1(v, 1 if stat == "median" else 0) for v in vals))
                cells.append("±%.0f %%" % (50.0 * swing))
            out.append("| %s | %s | %s | %s | %s | %s |" % (case, metric, *cells))
    out.append("\nThe hold-OFF sets span three rounds of other merges, so part of that swing is code, not seeds; the hold-ON sets are "
               "two commits a day apart. Read the swing as the A/A ceiling a bar's guard must sit above when it compares totals across "
               "seed sets; within one seed set, a case the rule never touches swings 0 (the sim is deterministic per flags).\n")
    med = rows.hull_medians(os.path.join(root, probes.R29 + "manoeuvre/m1_judged.txt"), "M1_HULL")
    mov = rows.moving_lines(os.path.join(root, probes.R29 + "manoeuvre/m1_judged.txt"))
    out.append("**hull-rest probe, the clicked pair at `d7385da2` (M1 never acts on a clicked order, so new_clicked v base_clicked is an A/A at "
               "n = 48 runs a task, 27 with wheeled turrets):**\n")
    out.append("| task | crews still moving: clicked new − base | hull-error median, ALL (651 crews) | wheels/turret (310 crews) |")
    out.append("|---|---|---|---|")
    for m in mov:
        t = m["task"]
        out.append("| %s | %+d | %+.1f° | %+.1f° |" % (t, m["new_clicked"] - m["base_clicked"], med[(t, "ALL", "new_clicked")] - med[(t, "ALL", "base_clicked")],
                                                       med[(t, "wheels/turret", "new_clicked")] - med[(t, "wheels/turret", "base_clicked")]))
    out.append("\nSo a +5 guard on crews-still-moving and a ±5° line on clicked medians were both inside this probe's A/A at the n M1 used.\n")
    out.append("**yard crossing cells (B5c):** two near-identical rules (`053beffb` judged, `a8df3dc3` the narrow fix) on the same yard-23 cells "
               "moved last-crew-in by −3.6, +0.8, +3.5, +11.1, +17.8 s (t11, t8, t6, t1, t3) and Sumps 6 by −0.3 s: a cell's own swing is "
               "about ±9 s, so a 'median ≤ off − 5 s' line over 12 cells (se ≈ 3 s) is at the edge; the count line (every crew in, 12/12 v 5/12) "
               "is what decided B5c.")
    return "\n".join(out)


def replace_block(text, name, body):
    begin, end = "<!-- judge:%s:begin -->" % name, "<!-- judge:%s:end -->" % name
    pattern = re.compile(re.escape(begin) + r".*?" + re.escape(end), re.S)
    if not pattern.search(text):
        raise SystemExit("judging.md has no %s block markers" % name)
    return pattern.sub(lambda _m: begin + "\n" + body + "\n" + end, text)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=os.path.dirname(os.path.dirname(HERE)))
    parser.add_argument("--doc", default=None)
    parser.add_argument("--csv", default=None)
    args = parser.parse_args()
    doc = args.doc or os.path.join(args.root, DOC)
    csv_path = args.csv or os.path.join(args.root, CSV)
    trows = table_rows(args.root)
    os.makedirs(os.path.dirname(csv_path), exist_ok=True)
    with open(csv_path, "w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=COLUMNS, lineterminator="\n", extrasaction="ignore")
        writer.writeheader()
        for r in trows:
            writer.writerow({k: (("%.4f" % v) if isinstance(v, float) else v) for k, v in r.items()})
    with open(doc) as handle:
        text = handle.read()
    text = replace_block(text, "table", render_table(trows))
    text = replace_block(text, "counts", render_counts())
    text = replace_block(text, "aa", render_aa(args.root))
    with open(doc, "w") as handle:
        handle.write(text)
    sized = [r for r in trows if r.get("n_needed")]
    print("TABLE %d probe x metric rows (%d sized) -> %s, %s" % (len(trows), len(sized), doc, csv_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())

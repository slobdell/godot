#!/usr/bin/env python3
"""Size a bar line from its probe's noise (sizing S3/S5): print the n that decides an effect, the MDE at an n, and the
variance-aware line, from rows, from a table row, or from a bare sd.

  size.py --sd 16.7 --effect 5.5 [--n 18]                      a paired per-run sd and effect -> n, MDE, guard
  size.py --probe "traffic-series terminus/head" --metric xfast --effect-share 0.25 [--n 18]
                                                               the same from references/round30/sizing/table.csv
  size.py --base B.jsonl --arm A.jsonl --case terminus/cross --metric allin [--stat total|median|mean]
          [--guard-share 0.2 | --gain-share 0.25 | --guard 5 | --gain 10]
                                                               read the noise from two traffic-series files and judge
                                                               the named line variance-aware (and show the point form)
  size.py --class-table m1_judged.txt --task faced_attack_move --guard 5
                                                               the hull-rest guard re-sized from the M1_CLASS lines
  size.py --count 12/12 5/12                                   two arms' run counts: Fisher p and the n that decides
  size.py --threshold 10/18 12                                 one arm against a threshold: binomial reading
  size.py --cells 11 0                                         paired cells for v against: McNemar p and the n for the gain
Options: --alpha 0.05 (one-sided false-pass), --power 0.8, --k 1.645 (the guard's multiple of se).
Every number is what the doc quotes; the doc's worked examples are these commands on files under references/.
"""
import argparse
import csv
import math
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rows  # noqa: E402
import stats  # noqa: E402

TABLE_CSV = os.path.join(os.path.dirname(os.path.dirname(HERE)), "_agents/streams/references/round30/sizing/table.csv")


def say(*parts):
    print("SIZE " + " ".join(str(p) for p in parts))


def from_sd(sd, effect, n, alpha, power, k, base=None):
    say("sd a run %.3f%s" % (sd, "" if base is None else ", base a run %.3f" % base))
    if effect:
        need = stats.n_paired(sd, effect, alpha, power)
        say("effect %.3f a run%s -> n that decides it at %.0f %% power, %.1f %% one-sided: %s" % (
            effect, "" if base is None else " (%.0f %% of base)" % (100.0 * effect / base), 100 * power, 100 * alpha, need))
    if n:
        m = stats.mde(sd, n, alpha, power)
        say("at n = %d: se of the sum %.2f, se of the mean %.3f, MDE %.3f a run%s" % (
            n, sd * math.sqrt(n), sd / math.sqrt(n), m, "" if base is None else " (%.0f %% of base)" % (100.0 * m / base)))
        say("variance-aware guard at n = %d: base %s %.2f on the sum (k = %.3f: a do-nothing treatment fails it %.1f %% of the time)" % (
            n, "+/-", k * sd * math.sqrt(n), k, 100.0 * (1.0 - stats.norm_cdf(k))))
        if effect:
            fp = stats.false_pass_at_null(effect, sd, n)
            say("the point form ('moved by >= the effect') at n = %d: a null passes it %.1f %%; a true effect of that size passes 50 %%, twice it %.0f %%" % (
                n, 100 * fp, 100 * stats.power_at(2 * effect, effect, sd, n)))


def from_table(probe, metric, effect_share, n, alpha, power, k, path):
    with open(path) as handle:
        table = list(csv.DictReader(handle))
    hit = [r for r in table if r["probe"] == probe and r["metric"] == metric]
    if not hit:
        raise SystemExit("no table row for %r / %r (rows: %s)" % (probe, metric, sorted({r["probe"] for r in table})))
    r = hit[0]
    if not r.get("sd_run"):
        raise SystemExit("the table has no noise for that row: %s" % r.get("aa", ""))
    sd, base = float(r["sd_run"]), float(r["base_run"])
    say("table row: %s / %s (pairs: %s)" % (probe, metric, r["pairs"]))
    from_sd(sd, effect_share * base if effect_share else None, n or int(r["n_today"]), alpha, power, k, base)


def from_rows(base_path, arm_path, case, metric, stat, args):
    cases = rows.traffic_pairs(base_path, arm_path)
    names = case.split(",")
    pairs = [p for c in names for p in cases[c]]
    d = rows.diffs(pairs, metric)
    b, a = rows.values(pairs, metric, "base"), rows.values(pairs, metric, "arm")
    n = len(d)
    say("%s %s: n %d paired runs, arms differ in %d" % (case, metric, n, len(stats.acted(d))))
    if stat == "median":
        point, lo, hi, sd = stats.bootstrap_median_diff(b, a)
        base_v, arm_v = statistics.median(b), statistics.median(a)
        say("medians %.1f -> %.1f (diff %+.1f); bootstrap sd of the paired median difference %.2f, 90 %% interval %+.1f..%+.1f" % (base_v, arm_v, point, sd, lo, hi))
        se = sd
    else:
        base_v, arm_v = (sum(b), sum(a)) if stat == "total" else (statistics.mean(b), statistics.mean(a))
        se = stats.paired_se_total(d) if stat == "total" else stats.paired_se_mean(d)
        say("%s %.2f -> %.2f (diff %+.2f); paired sd %.2f a run; se of the %s %.2f" % (stat, base_v, arm_v, arm_v - base_v, stats.paired_sd(d), stat, se))
    x = None
    if args.guard_share is not None or args.guard is not None:
        x = args.guard if args.guard is not None else args.guard_share * base_v
        line = base_v + x
        say("the point guard '<= base + %.2f': %s (observed %+.2f)" % (x, "PASS" if arm_v <= line else "FAIL", arm_v - base_v))
        say("inside the noise? x = %.2f v 1.645 se = %.2f: %s" % (x, stats.Z_ALPHA_05 * se, "YES, a null fails this guard %.0f %% of the time" % (
            100 * (1 - stats.norm_cdf(x / se))) if se and x < stats.Z_ALPHA_05 * se else "no"))
        vline = base_v + args.k * se
        say("variance-aware guard '<= base + %.3f se' = <= %.2f (+%.2f): %s; MDE (the harm it catches at %.0f %% power) %.2f" % (
            args.k, vline, vline - base_v, "PASS" if arm_v <= vline else "FAIL", 100 * args.power, (stats.norm_ppf(1 - args.alpha) + stats.norm_ppf(args.power)) * se))
    if args.gain_share is not None or args.gain is not None:
        x = args.gain if args.gain is not None else args.gain_share * base_v
        line = base_v - x
        say("the point gain line 'down >= %.2f': %s (observed %+.2f)" % (x, "PASS" if arm_v <= line else "FAIL", arm_v - base_v))
        say("inside the noise? x = %.2f v 1.645 se = %.2f: %s" % (x, stats.Z_ALPHA_05 * se, "YES, a null passes this line %.0f %% of the time" % (
            100 * (1 - stats.norm_cdf(x / se))) if se and x < stats.Z_ALPHA_05 * se else "no"))
        drop = base_v - arm_v
        say("variance-aware gain: the drop %.2f minus %.3f se (%.2f) = %.2f -> %s; AND the point >= %.2f: %s" % (
            drop, args.k, args.k * se, drop - args.k * se, "distinguishable from nothing" if drop - args.k * se > 0 else "NOT distinguishable from nothing",
            x, "yes" if drop >= x else "no"))
        if stat != "median":
            from_sd(stats.paired_sd(d), x / n if stat == "total" else x, n, args.alpha, args.power, args.k, base_v / n if stat == "total" else base_v)
    if x is None and stat != "median":
        from_sd(stats.paired_sd(d), None, n, args.alpha, args.power, args.k, base_v / n if stat == "total" else base_v)


def from_class_table(path, task, guard, k, alpha, power):
    cls = [c for c in rows.class_lines(path) if c["task"] == task]
    if not cls:
        raise SystemExit("no M1_CLASS lines for task %r" % task)
    se_all = math.sqrt(sum(c["se"] ** 2 for c in cls))
    diff = sum(c["diff"] for c in cls)
    n = cls[0]["n"]
    say("%s: classes %s" % (task, ", ".join("%s %+d (se %.1f, %d runs)" % (c["klass"], c["diff"], c["se"], c["n"]) for c in cls)))
    say("all classes: diff %+d, se of the sum %.1f (sqrt of the sum of the class se^2)" % (diff, se_all))
    say("the point guard '<= base + %g': %s" % (guard, "PASS" if diff <= guard else "FAIL"))
    say("inside the noise? x = %g v 1.645 se = %.1f: %s" % (guard, stats.Z_ALPHA_05 * se_all,
                                                              "YES, a null fails it %.0f %% of the time" % (100 * (1 - stats.norm_cdf(guard / se_all))) if guard < stats.Z_ALPHA_05 * se_all else "no"))
    say("variance-aware guard '<= base + %.3f se' = +%.1f: %s (k = 2: +%.1f, %s)" % (k, k * se_all, "PASS" if diff <= k * se_all else "FAIL", 2 * se_all,
                                                                                     "PASS" if diff <= 2 * se_all else "FAIL"))
    wt = [c for c in cls if c["klass"] == "wheels/turret"]
    if wt:
        c = wt[0]
        sd = c["se"] / math.sqrt(c["n"])
        say("wheels/turret alone: %+d v k se %.1f -> %s; per-run sd %.2f; a +%g total over %d runs is %.3f a run -> n that decides it %s; MDE at %d runs %+.1f crews" % (
            c["diff"], k * c["se"], "PASS" if c["diff"] <= k * c["se"] else "FAIL", sd, guard, c["n"], guard / c["n"], stats.n_paired(sd, guard / c["n"], alpha, power),
            c["n"], stats.mde(sd, c["n"], alpha, power) * c["n"]))
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sd", type=float)
    parser.add_argument("--effect", type=float)
    parser.add_argument("--n", type=int)
    parser.add_argument("--probe")
    parser.add_argument("--metric")
    parser.add_argument("--effect-share", type=float)
    parser.add_argument("--table", default=TABLE_CSV)
    parser.add_argument("--base")
    parser.add_argument("--arm")
    parser.add_argument("--case")
    parser.add_argument("--stat", default="total", choices=("total", "median", "mean"))
    parser.add_argument("--guard", type=float)
    parser.add_argument("--guard-share", type=float)
    parser.add_argument("--gain", type=float)
    parser.add_argument("--gain-share", type=float)
    parser.add_argument("--class-table")
    parser.add_argument("--task")
    parser.add_argument("--count", nargs=2, metavar=("ARM", "CONTROL"))
    parser.add_argument("--threshold", nargs=2, metavar=("K/N", "MIN"))
    parser.add_argument("--cells", nargs=2, type=int, metavar=("FOR", "AGAINST"))
    parser.add_argument("--alpha", type=float, default=0.05)
    parser.add_argument("--power", type=float, default=0.8)
    parser.add_argument("--k", type=float, default=stats.Z_ALPHA_05)
    args = parser.parse_args(argv)

    if args.count:
        (a, n1), (c, n2) = (tuple(int(x) for x in s.split("/")) for s in args.count)
        two, one = stats.fisher_exact(a, n1 - a, c, n2 - c)
        say("%d/%d v %d/%d: Fisher one-sided p %.4f (two-sided %.4f): %s at %.1f %%" % (a, n1, c, n2, one, two, "decided" if one <= args.alpha else "NOT decided", 100 * args.alpha))
        if a / n1 != c / n2:
            hi, lo = max(a / n1, c / n2), min(a / n1, c / n2)
            say("the n a side at which these rates reach %.0f %% power: %s" % (100 * args.power, stats.fisher_min_n(lo, hi, args.alpha, args.power)))
        return 0
    if args.threshold:
        k_, n = (int(x) for x in args.threshold[0].split("/"))
        K = int(args.threshold[1])
        say("%d/%d against '>= %d/%d': %s; binomial sd of the count at the observed rate %.2f; the line sits %+.2f sd from the observation" % (
            k_, n, K, n, "PASS" if k_ >= K else "FAIL", math.sqrt(n * (k_ / n) * (1 - k_ / n)) if 0 < k_ < n else float("nan"),
            (K - k_) / math.sqrt(n * (k_ / n) * (1 - k_ / n)) if 0 < k_ < n else float("nan")))
        say("how often the line passes at a true rate: " + ", ".join("p %.2f -> %.2f" % (p, stats.binom_tail(K, n, p)) for p in (0.5, 0.6, 0.67, 0.8, 0.9)))
        return 0
    if args.cells:
        b, c = args.cells
        p = stats.mcnemar_exact(b, c)
        say("%d cells for v %d against: McNemar exact p %.4f: %s" % (b, c, p, "decided" if p <= args.alpha else "NOT decided (a coin)"))
        return 0
    if args.class_table:
        return from_class_table(args.class_table, args.task, args.guard if args.guard is not None else 5.0, args.k, args.alpha, args.power)
    if args.base and args.arm:
        from_rows(args.base, args.arm, args.case, args.metric, args.stat, args)
        return 0
    if args.probe:
        from_table(args.probe, args.metric, args.effect_share, args.n, args.alpha, args.power, args.k, args.table)
        return 0
    if args.sd is not None:
        from_sd(args.sd, args.effect, args.n, args.alpha, args.power, args.k)
        return 0
    parser.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())

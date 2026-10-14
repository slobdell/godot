#!/usr/bin/env python3
"""Sequential (early-stop) judging of a paired series (sizing S4): after every run, each pre-registered line prints
CONTINUE / PASS / FAIL with its boundary, and the series stops the moment it is decided.

  sequential.py --base B.jsonl --arm A.jsonl --case terminus/head \\
                --lines xfast:gain:0.25 arrived:guard:0.02 allin:guard:0.20 [--sd-from table|rows] [--min-runs 6]
  sequential.py ... --simulate 4000           error rates of the rule on THIS series' own rows (sign-flipped nulls,
                                              shifted effects, resampled observations), no new runs
  sequential.py --approach A.jsonl --lines onside35:rate:0.67:0.05 alive:guard:0.1 ...
  sequential.py --terminus m4_judged.txt --squad rigs --lines arrived:guard:0.10 contacts:gain:0.25

A line is METRIC:KIND:EFFECT[:P0]. KIND `gain`: the bar wants the metric DOWN by EFFECT (a share of the base per run, or
`abs=…` a per-run amount); `guard`: the metric must not get WORSE by EFFECT (worse = up, or down for arrived-type
metrics); `rate`: a per-run yes/no (on side) at rate EFFECT against the control's P0.

The test is Wald's SPRT on the per-run paired differences d_i = arm_i - base_i, in the runner's order (seed-major, start
tick minor, mk/traffic.mk), with the probe's per-run sd taken from the pre-registered table (references/round30/sizing/
table.csv) by default:
  gain   H0 delta = 0 v H1 delta = -effect: PASS when the log-likelihood ratio reaches A = ln((1-beta)/alpha),
         FAIL when it falls to B = ln(beta/(1-alpha))       (alpha: a null passes; beta: the named effect fails)
  guard  H0 no harm v H1 harm = +effect: FAIL at A, PASS at B  (alpha: a harmless change fails; beta: a real harm passes)
  rate   Bernoulli SPRT p1 = EFFECT v p0 = P0 on the arm's yes/no, PASS at A, FAIL at B
Truncated at the grid's end: the sign of the ratio decides. The series FAILS at the first line that fails (no partial
gain), PASSES when every line has passed, and never stops before --min-runs (one full seed of ticks by default), so a
stop is never read off a single start tick.

THE ONE RULE FOR A STREAM: you may stop a judged series early only on the row where this script prints `SERIES PASS` or
`SERIES FAIL` for EVERY case of the bar with the table's sd (not the rows' own), and you record that row in the bar's
block ("stopped at run 11 of 18: xfast PASS llr 3.1 > 2.77 …"). A CONTINUE on any line means the series runs on. A probe
with no table row (its noise unmeasured) runs its full grid: it owes its A/A first.
"""
import argparse
import csv
import math
import os
import random
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rows  # noqa: E402
import stats  # noqa: E402

TABLE_CSV = os.path.join(os.path.dirname(os.path.dirname(HERE)), "_agents/streams/references/round30/sizing/table.csv")
# metrics where WORSE is DOWN (a guard's harm is a fall)
DOWN_IS_WORSE = {"arrived", "alive", "kills", "hit_on_side_share", "on_target_s"}
# yes/no per-run metrics for `rate` lines
RATE_METRICS = {"onside35": lambda r: 0 <= r.get("hit_off_median_deg", -1) <= 35.0}


class Line:
    def __init__(self, text, sd, base_run):
        parts = text.split(":")
        self.metric, self.kind = parts[0], parts[1]
        eff = parts[2]
        self.effect_share = None
        if self.kind == "rate":
            self.p1, self.p0 = float(eff), float(parts[3]) if len(parts) > 3 else 0.05
            self.p0 = min(max(self.p0, 0.01), 0.99)
            self.effect = None
        else:
            if eff.startswith("abs="):
                self.effect = float(eff[4:])
            else:
                self.effect_share = float(eff)
                self.effect = float(eff) * abs(base_run)
            self.harm_sign = -1.0 if self.metric in DOWN_IS_WORSE else 1.0  # the direction that is worse
        self.sd = sd
        self.base_run = base_run
        self.name = text

    def increments(self, diffs):
        """Per-run log-likelihood-ratio increments of H1 against H0."""
        if self.kind == "rate":
            return [math.log(self.p1 / self.p0) if d else math.log((1 - self.p1) / (1 - self.p0)) for d in diffs]
        if self.sd <= 0:
            return [0.0 for _ in diffs]
        if self.kind == "gain":
            delta = -self.harm_sign * self.effect  # the better direction by the effect
        else:
            delta = self.harm_sign * self.effect  # the worse direction by the effect
        return [(delta * d - delta * delta / 2.0) / (self.sd * self.sd) for d in diffs]

    def fixed_decision(self, diffs):
        n = len(diffs)
        z = stats.norm_ppf(1.0 - ALPHA)
        if self.kind == "rate":
            k = sum(1 for d in diffs if d)
            return "PASS" if stats.binom_tail(k, n, self.p0) <= ALPHA else "FAIL"
        if self.sd <= 0:
            return "FAIL" if self.kind == "gain" else "PASS"
        mean = statistics.mean(diffs)
        se = self.sd / math.sqrt(n)
        if self.kind == "gain":  # pass only when the gain is distinguishable from nothing
            return "PASS" if -self.harm_sign * mean >= z * se else "FAIL"
        return "FAIL" if self.harm_sign * mean >= z * se else "PASS"  # fail only when harm is shown

    def judge(self, diffs, a, b, min_runs):
        """Walk the runs; return (decision, stop_index (1-based) or None, llr path)."""
        llr, path, decision, stop = 0.0, [], None, None
        for i, inc in enumerate(self.increments(diffs), 1):
            llr += inc
            path.append(llr)
            if decision is None and i >= min_runs:
                if self.kind in ("gain", "rate"):
                    if llr >= a:
                        decision, stop = "PASS", i
                    elif llr <= b:
                        decision, stop = "FAIL", i
                else:
                    if llr >= a:
                        decision, stop = "FAIL", i
                    elif llr <= b:
                        decision, stop = "PASS", i
        if decision is None:  # truncated at the grid's end: the fixed one-sided test at alpha decides (not the LLR's
            # sign, which under a null is a coin and would double both error rates)
            decision = self.fixed_decision(diffs)
            stop = len(diffs)
            truncated = True
        else:
            truncated = False
        return decision, stop, path, truncated


def table_sd(probe, metric, path=TABLE_CSV):
    try:
        with open(path) as handle:
            for r in csv.DictReader(handle):
                if r["probe"] == probe and r["metric"] == metric and r.get("sd_run"):
                    return float(r["sd_run"]), float(r["base_run"])
    except FileNotFoundError:
        pass
    return None, None


def series_verdict(lines, diffs_by_line, a, b, min_runs):
    """Walk all lines together; the series decision and the row it is reached on."""
    per = {ln.name: ln.judge(diffs_by_line[ln.name], a, b, min_runs) for ln in lines}
    n = max(len(d) for d in diffs_by_line.values())
    for i in range(1, n + 1):
        failed = [ln.name for ln in lines if per[ln.name][0] == "FAIL" and per[ln.name][1] <= i and not per[ln.name][3]]
        if failed:
            return "FAIL", i, per
        if all(per[ln.name][0] == "PASS" and per[ln.name][1] <= i and not per[ln.name][3] for ln in lines):
            return "PASS", i, per
    decision = "FAIL" if any(per[ln.name][0] == "FAIL" for ln in lines) else "PASS"
    return decision, n, per


def untouched_stop(pairs, counter, min_runs):
    """The row at which a case is known to be UNTOUCHED: every row so far byte-identical in arrivals and fast contacts
    AND the arm's own rule counter (lesson 300) zero in every row, after min_runs. None when the rule fired or the arms
    diverged anywhere. A guard on an untouched case is an equality check, and an equality check needs one seed, not three."""
    if not counter:
        return None
    for i, (_k, base_row, arm_row) in enumerate(pairs, 1):
        if arm_row.get(counter, 0) != 0 or abs(rows.all_in_s(arm_row) - rows.all_in_s(base_row)) > 0.05 or arm_row["contacts_fast"] != base_row["contacts_fast"]:
            return None
        if i >= min_runs:
            return i
    return None


def print_walk(keys, lines, diffs_by_line, a, b, min_runs, untouched=None):
    per = {ln.name: ln.judge(diffs_by_line[ln.name], a, b, min_runs) for ln in lines}
    decision, stop, _ = series_verdict(lines, diffs_by_line, a, b, min_runs)
    why = ""
    if untouched is not None and untouched < stop and all(ln.kind == "guard" for ln in lines):
        decision, stop, why = "PASS", untouched, " (UNTOUCHED: arms identical and the rule's counter 0 in every row: an equality check)"
    for i, key in enumerate(keys, 1):
        cells = []
        for ln in lines:
            d, s, path, trunc = per[ln.name]
            state = d if (s is not None and i >= s and not trunc) else "CONTINUE"
            cells.append("%s %s llr %+.2f" % (ln.name, state, path[i - 1]))
        mark = " <- SERIES %s" % decision if i == stop else ""
        seed, tick = (key[0], key[1]) if isinstance(key, tuple) and len(key) > 1 else (key, "-")
        print("SEQ row %2d (seed %s tick %s): %s%s" % (i, seed, tick, " | ".join(cells), mark))
        if i == stop:
            break
    print("SEQ boundaries A %+.2f B %+.2f (alpha %.2f beta %.2f), min runs %d" % (a, b, ALPHA, BETA, min_runs))
    print("SERIES %s at run %d of %d%s%s" % (decision, stop, len(keys), " (the full grid)" if stop == len(keys) else " (early)", why))
    return decision, stop


def simulate(lines, diffs_by_line, a, b, min_runs, reps, seed=30):
    """Error rates of the rule on this series' own rows. Worlds per line: NULL (sign-flipped diffs: no effect, the
    probe's real noise shape), EFFECT (the null shifted by the named effect in its direction), OBSERVED (resampled real
    diffs). For `rate` lines the worlds are Bernoulli at p0, p1 and the observed rate."""
    rng = random.Random(seed)
    out = {}
    for ln in lines:
        d = diffs_by_line[ln.name]
        n = len(d)
        res = {}
        for world in ("NULL", "EFFECT", "OBSERVED"):
            decisions, stops = [], []
            for _ in range(reps):
                if ln.kind == "rate":
                    p = {"NULL": ln.p0, "EFFECT": ln.p1, "OBSERVED": sum(1 for x in d if x) / n}[world]
                    sample = [1 if rng.random() < p else 0 for _ in range(n)]
                elif world == "OBSERVED":
                    sample = [rng.choice(d) for _ in range(n)]
                else:
                    centre = statistics.mean(d)  # the null keeps the pairs' noise shape, not the observed effect
                    sample = [(x - centre) * rng.choice((-1.0, 1.0)) for x in d]
                    if world == "EFFECT":
                        shift = (-ln.harm_sign if ln.kind == "gain" else ln.harm_sign) * ln.effect
                        sample = [x + shift for x in sample]
                dec, stop, _p, _t = ln.judge(sample, a, b, min_runs)
                decisions.append(dec)
                stops.append(stop)
            res[world] = {"pass": decisions.count("PASS") / reps, "fail": decisions.count("FAIL") / reps,
                          "mean_stop": statistics.mean(stops), "stopped_early": sum(1 for s in stops if s < n) / reps}
        out[ln.name] = res
    return out


ALPHA, BETA = 0.05, 0.20


def main(argv=None):
    global ALPHA, BETA
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--base")
    parser.add_argument("--arm")
    parser.add_argument("--case")
    parser.add_argument("--approach")
    parser.add_argument("--terminus")
    parser.add_argument("--squad", default="rigs")
    parser.add_argument("--lines", nargs="+", required=True)
    parser.add_argument("--sd-from", default="table", choices=("table", "rows"))
    parser.add_argument("--table", default=TABLE_CSV)
    parser.add_argument("--probe", help="table probe name; default 'traffic-series <case>'")
    parser.add_argument("--alpha", type=float, default=0.05)
    parser.add_argument("--beta", type=float, default=0.20)
    parser.add_argument("--min-runs", type=int, default=6)
    parser.add_argument("--simulate", type=int, default=0)
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("--counter", help="the arm's own rule counter field (tr_verdicts, tr_cross_verdicts): a case with the counter 0 "
                                          "and identical arms through --min-runs stops as PASS, an equality check")
    args = parser.parse_args(argv)
    ALPHA, BETA = args.alpha, args.beta
    a, b = math.log((1 - args.beta) / args.alpha), math.log(args.beta / (1 - args.alpha))

    if args.approach:
        pairs = rows.approach_pairs(args.approach)
        probe = args.probe or "ApproachStage flank probe (a roster)"
        metric_fn = lambda m: RATE_METRICS.get(m) or (lambda r: r[m])  # noqa: E731
        table_names = {"alive": "alive (of 5)", "first_shot_s": "first shot s", "hit_on_side_share": "hit on side share", "hit_off_median_deg": "median hit bearing deg"}
    elif args.terminus:
        table = rows.terminus_rows(args.terminus)[args.squad]
        pairs = [(s, bb, nn) for s, bb, nn in table]
        probe = args.probe or "Terminus census, %s (a seed)" % args.squad
        metric_fn = lambda m: (lambda r: r[m])  # noqa: E731
        table_names = {"arrived": "arrived (of %d)" % (16 if args.squad == "rigs" else 24), "contacts": "wall contact-ticks"}
    else:
        cases = rows.traffic_pairs(args.base, args.arm)
        pairs = [p for c in args.case.split(",") for p in cases[c]]
        probe = args.probe or "traffic-series " + args.case
        metric_fn = rows.metric_fn
        table_names = {}
    keys = [k for k, _b, _a in pairs]

    lines, diffs_by_line = [], {}
    for text in args.lines:
        metric = text.split(":")[0]
        f = metric_fn(metric)
        if text.split(":")[1] == "rate":
            d = [1 if f(arm_row) else 0 for _k, _b, arm_row in pairs]
            sd, base = 0.0, 0.0
        else:
            d = [f(arm_row) - f(base_row) for _k, base_row, arm_row in pairs]
            base_vals = [f(base_row) for _k, base_row, _a in pairs]
            sd, base = (None, None)
            if args.sd_from == "table":
                sd, base = table_sd(probe, table_names.get(metric, metric), args.table)
                if sd is None:
                    print("SEQ no table row for %s / %s: falling back to the rows' own sd (POST HOC: a stop on it is not pre-registered)" % (probe, metric))
            if sd is None:
                sd, base = stats.paired_sd(d), statistics.mean(base_vals)
            else:
                base = statistics.mean(base_vals)  # the effect is a share of THIS series' base level
        ln = Line(text, sd, base)
        lines.append(ln)
        diffs_by_line[ln.name] = d
        if not args.quiet:
            print("SEQ line %s: sd a run %.3f (%s), base a run %.3f, effect a run %s" % (
                ln.name, ln.sd, args.sd_from, ln.base_run, "%.3f" % ln.effect if ln.effect is not None else "p1 %.2f v p0 %.2f" % (ln.p1, ln.p0)))

    untouched = untouched_stop(pairs, args.counter, args.min_runs) if (args.base and args.counter) else None
    decision, stop = print_walk(keys, lines, diffs_by_line, a, b, args.min_runs, untouched)
    if args.simulate:
        sim = simulate(lines, diffs_by_line, a, b, args.min_runs, args.simulate)
        for name, res in sim.items():
            ln = next(l for l in lines if l.name == name)
            if ln.kind == "guard":
                print("SIM %s: harmless change FAILS %.1f %% (alpha %.0f %%), named harm PASSES %.1f %% (beta %.0f %%); observed rows: PASS %.0f %%, "
                      "mean stop %.1f of %d (early %.0f %%); null mean stop %.1f" % (
                          name, 100 * res["NULL"]["fail"], 100 * args.alpha, 100 * res["EFFECT"]["pass"], 100 * args.beta, 100 * res["OBSERVED"]["pass"],
                          res["OBSERVED"]["mean_stop"], len(diffs_by_line[name]), 100 * res["OBSERVED"]["stopped_early"], res["NULL"]["mean_stop"]))
            else:
                print("SIM %s: null PASSES %.1f %% (alpha %.0f %%), named effect FAILS %.1f %% (beta %.0f %%); observed rows: PASS %.0f %%, "
                      "mean stop %.1f of %d (early %.0f %%); null mean stop %.1f" % (
                          name, 100 * res["NULL"]["pass"], 100 * args.alpha, 100 * res["EFFECT"]["fail"], 100 * args.beta, 100 * res["OBSERVED"]["pass"],
                          res["OBSERVED"]["mean_stop"], len(diffs_by_line[name]), 100 * res["OBSERVED"]["stopped_early"], res["NULL"]["mean_stop"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())

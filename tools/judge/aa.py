#!/usr/bin/env python3
"""Read an A/A pair's noise from two base files of the SAME arm (sizing S5): the swing a line must clear when nothing changed.

  aa.py A.jsonl B.jsonl [--case terminus/head] [--metrics fast,xfast,arrived,allin,fstuck]

Two kinds of A/A exist in this project and the script tells them apart by the seed grids:
  same seeds, different commits   the sim is deterministic per (commit, seed, tick, flags), so any difference is code
                                  divergence: the per-run PAIRED sd is the probe's noise under a change that was not
                                  meant to change anything (the hull-rest clicked pair is this kind)
  different seed sets             the totals' swing between sets is the between-seed-set noise of a case total at this n
                                  (what a "within 2 se" line read across seed sets must clear); the per-run sd of each
                                  set is reported, and the se of a total at n is sd * sqrt(n)
A pair with identical rows is a replay, not an A/A, and is refused. Exit 0 whenever it read something.
"""
import argparse
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rows  # noqa: E402
import stats  # noqa: E402

DEFAULT_METRICS = ("fast", "xfast", "arrived", "allin", "fstuck")


def load(path):
    out = {}
    for r in rows.read_jsonl(path):
        if r.get("which", "both") != "both" or r.get("missing"):
            continue
        out[(r["arena"] + "/" + r["kind"], r["seed"], r["start_tick"])] = r
    return out


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("a")
    parser.add_argument("b")
    parser.add_argument("--case")
    parser.add_argument("--metrics", default=",".join(DEFAULT_METRICS))
    args = parser.parse_args(argv)
    A, B = load(args.a), load(args.b)
    cases = sorted({k[0] for k in A} & {k[0] for k in B}) if not args.case else [args.case]
    metrics = args.metrics.split(",")
    for case in cases:
        ka = sorted(k for k in A if k[0] == case)
        kb = sorted(k for k in B if k[0] == case)
        same = set(ka) == set(kb)
        if same:
            pairs = [((k[1], k[2]), A[k], B[k]) for k in ka]
            if all(rows.diffs(pairs, m) == [0] * len(pairs) for m in metrics):
                print("AA %s: REFUSED, the two files are the same run on %d rows (a replay is not an A/A)" % (case, len(pairs)))
                continue
            print("AA %s: SAME SEEDS (%d runs), different code: the paired differences are divergence noise" % (case, len(pairs)))
            for m in metrics:
                d = rows.diffs(pairs, m)
                f = rows.metric_fn(m)
                ta, tb = sum(f(A[k]) for k in ka), sum(f(B[k]) for k in kb)
                print("AA   %-8s totals %s v %s  paired sd %.2f a run (runs differing %d)  se of the sum at n = %d: %.1f  -> a guard here is base +- %.1f (1.645 se)" % (
                    m, fmt(ta), fmt(tb), stats.paired_sd(d), len(stats.acted(d)), len(d), stats.paired_se_total(d), 1.645 * stats.paired_se_total(d)))
        else:
            print("AA %s: DIFFERENT SEED SETS (%d and %d runs): the swing of the case total is between-seed-set noise at this n" % (case, len(ka), len(kb)))
            for m in metrics:
                f = rows.metric_fn(m)
                va, vb = [f(A[k]) for k in ka], [f(B[k]) for k in kb]
                if m == "allin":
                    sa, sb = statistics.median(va), statistics.median(vb)
                    label = "medians"
                else:
                    sa, sb = sum(va), sum(vb)
                    label = "totals"
                swing = abs(sa - sb) / statistics.mean((sa, sb)) if (sa + sb) else 0.0
                print("AA   %-8s %s %s v %s  swing %.0f %% of the mean  per-run sd %.2f / %.2f  (independent se of a total at n = %d: %.1f)" % (
                    m, label, fmt(sa), fmt(sb), 100 * swing, statistics.pstdev(va), statistics.pstdev(vb), len(ka),
                    (statistics.pstdev(va) ** 2 * len(ka) + statistics.pstdev(vb) ** 2 * len(kb)) ** 0.5))
    return 0


def fmt(v):
    return ("%.1f" % v) if isinstance(v, float) and v != int(v) else str(int(v))


if __name__ == "__main__":
    sys.exit(main())

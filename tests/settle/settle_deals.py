#!/usr/bin/env python3
"""Round 40 (settle; orders' G1 v6 trace, terminus 5 route s8206): the dry deal read from DEPLOY_TRACE lines' `deals`.

    python3 tests/settle/settle_deals.py LOG_DIR [BUNCHED_M]

Per deploy: cause, the crews' spread, and [worst, total] m of the drives to the grounded seats under main's seating, the
least-total deal on the ordered heading, and that deal laid on the street's axis. Summed: every deploy, the cap deploys,
and the bunched cap deploys (spread <= BUNCHED_M, default 10). Dev read only.
"""
import glob
import gzip
import json
import os
import statistics as st
import sys


def opened(path):
    return gzip.open(path, "rt", errors="replace") if path.endswith(".gz") else open(path, errors="replace")


def rows(folder):
    for path in sorted(glob.glob(os.path.join(folder, "**", "*.log*"), recursive=True)):
        with opened(path) as f:
            for line in f:
                if line.startswith("DEPLOY_TRACE "):
                    d = json.loads(line.split(" ", 1)[1])
                    if d.get("deals"):
                        yield os.path.basename(path), d


def summary(name, picked):
    if not picked:
        print("%-14s n 0" % name)
        return
    out = ["%-14s n %3d" % (name, len(picked))]
    for arm in ("main", "ordered", "street"):
        got = [d["deals"][arm] for _, d in picked if d["deals"].get(arm)]
        if got:
            out.append("%s worst median %.1f max %.1f, >= 25 m %d, total mean %.1f (n %d)" % (
                arm, st.median(g[0] for g in got), max(g[0] for g in got), sum(1 for g in got if g[0] >= 25),
                st.mean(g[1] for g in got), len(got)))
    print(" | ".join(out))


def main(folder, bunched_m=10.0):
    every = list(rows(folder))
    for log, d in every:
        if d.get("cause") == "cap":
            print("%-44s %-16s spread %5.1f  main %s  ordered %s  street %s" % (
                log, d["leader"], d["deals"]["spread_m"], d["deals"]["main"], d["deals"]["ordered"], d["deals"]["street"]))
    summary("every", every)
    summary("cap", [r for r in every if r[1].get("cause") == "cap"])
    summary("cap bunched", [r for r in every if r[1].get("cause") == "cap" and r[1]["deals"]["spread_m"] <= bunched_m])


if __name__ == "__main__":
    main(sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else 10.0)

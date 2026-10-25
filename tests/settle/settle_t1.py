#!/usr/bin/env python3
"""Round 40 (settle T1): the deploy trigger's lab read from orders-probe logs (ORDERS_PROBE_SQUAD / ORDERS_PROBE lines).

    python3 tests/settle/settle_t1.py LOG_DIR          the lab read
    python3 tests/settle/settle_t1.py LOG_DIR caps     the cap deploys' ARRIVE_TRACE lines, classified

Per arm (the log name's `-<arm>.log` or `-<arm>-s<seed>.log`): runs, the worst twitch a run (median, max), squads with twitch
>= 15 m, runs never all in, the all-in time (median over runs in), and the per-seed worst twitch. Dev read only.
"""
import glob
import gzip
import json
import os
import re
import statistics as st
import sys
from collections import defaultdict


def logs(folder):
    return glob.glob(os.path.join(folder, "**", "*.log"), recursive=True) + glob.glob(os.path.join(folder, "**", "*.log.gz"), recursive=True)


def opened(path):
    return gzip.open(path, "rt", errors="replace") if path.endswith(".gz") else open(path, errors="replace")


def arm_seed(name):
    m = re.search(r"-s(\d+)-([A-Za-z0-9_]+)\.log$", name) or re.search(r"-([A-Za-z0-9_]+)-s(\d+)\.log$", name)
    if not m:
        return None, None
    a, b = m.groups()
    return (b, int(a)) if a.isdigit() else (a, int(b))


def main(folder):
    runs = defaultdict(dict)
    for path in sorted(logs(folder)):
        arm, seed = arm_seed(os.path.basename(path).replace(".gz", ""))
        if arm is None:
            continue
        squads = []
        with opened(path) as f:
            for line in f:
                if line.startswith("ORDERS_PROBE_SQUAD "):
                    squads.append(json.loads(line.split(" ", 1)[1]))
        if squads:
            runs[arm][(os.path.basename(path).split("-s")[0], seed)] = squads
    for arm in sorted(runs):
        worst, long_, never, allin, per = [], 0, 0, [], []
        causes = defaultdict(int)
        waits = []
        for key, squads in sorted(runs[arm].items()):
            for s in squads:
                causes[s.get("deploy_cause", "")] += 1
                if float(s.get("deploy_s", -1)) >= 0 and float(s.get("arrived_s", -1)) >= 0:
                    waits.append(float(s["deploy_s"]) - float(s["arrived_s"]))
            tw = max(float(s.get("twitch_m", -1)) for s in squads)
            worst.append(tw)
            long_ += sum(1 for s in squads if float(s.get("twitch_m", -1)) >= 15)
            arrived = [float(s.get("arrived_s", -1)) for s in squads]
            if min(arrived) < 0:
                never += 1
            else:
                allin.append(max(arrived))
            per.append("s%d %.1f" % (key[1], tw))
        print("%-8s runs %2d | worst twitch median %.1f max %.1f | squads >= 15 m %d | never-in runs %d | all-in median %.1f s" % (
            arm, len(worst), st.median(worst), max(worst), long_, never, st.median(allin) if allin else -1))
        print("         deploys %s | arrival to deploy median %.1f mean %.1f s (n %d)" % (dict(sorted(causes.items())),
              st.median(waits) if waits else -1, st.mean(waits) if waits else -1, len(waits)))
        print("         " + ", ".join(per))


if __name__ == "__main__" and len(sys.argv) == 2:
    main(sys.argv[1])


def caps(folder):
    """Every ARRIVE_TRACE line (a cap deploy) classified by the crews keeping the squad out (off > 3.5 m):
    near-holding (<= 5 m, holding), reached-then-off (was in, now off), held-far (holding, never in), driving (never in)."""
    from collections import Counter
    kinds, squads = Counter(), 0
    examples = defaultdict(list)
    for path in sorted(logs(folder)):
        with opened(path) as f:
            for line in f:
                if not line.startswith("ARRIVE_TRACE "):
                    continue
                d = json.loads(line.split(" ", 1)[1])
                squads += 1
                out = {n: c for n, c in d["crews"].items() if c[0] > 3.5}
                kind = "+".join(sorted({("reached-off" if c[3] else ("near-hold" if c[0] <= 5 and c[1] else
                                        ("held-far" if c[1] else "driving"))) for c in out.values()})) or "none-out"
                kinds[kind] += 1
                examples[kind].append("%s %s %s" % (os.path.basename(path), d["leader"],
                                                    {n: c for n, c in out.items()}))
    print("cap deploys %d" % squads)
    for k, v in kinds.most_common():
        print("  %-30s %d   e.g. %s" % (k, v, examples[k][0][:220]))
    return kinds


if __name__ == "__main__" and len(sys.argv) > 2 and sys.argv[2] == "caps":
    caps(sys.argv[1])

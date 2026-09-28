#!/usr/bin/env python3
"""Round 14 (nav N4): the stall share and the queues behind hulls giving way, both arms, per map x tempo x seed.

Usage: queue_table.py ARM=DIR[,DIR...] ARM=DIR[,DIR...]   (each DIR holds nav-fight-maps logs, <map>-busy<N>.log)

Per arm: the `blocked_*` share of ordered unit-ticks (round 13's stall clause), `blocked_friend`, `yielding`, per run;
how many runs the second arm's blocked share is above the first's; and the queue census (`queues` in NAV_FIGHT):
unit-seconds queued behind a yielder by the yielder's spot kind, the longest queue, and per kind the give-way
episodes, their unit-seconds, and how many had anyone queued behind them.
"""
import glob
import json
import os
import sys
from collections import Counter, defaultdict

TICK = 30.0  # SimClock.TICK_RATE


def load(dirs):
    runs = {}
    for d in dirs:
        seed = os.path.basename(d.rstrip("/")).rsplit("-", 1)[-1]
        for path in sorted(glob.glob(os.path.join(d, "*.log"))):
            final = None
            for line in open(path, errors="replace"):
                if line.startswith("NAV_FIGHT "):
                    final = json.loads(line[len("NAV_FIGHT "):])
            if final is None:
                print("NO NAV_FIGHT in %s" % path)
                continue
            runs[(seed, os.path.basename(path).removesuffix(".log"))] = final
    return runs


def blocked(share):
    return sum(v for k, v in share.items() if k.startswith("blocked_"))


def main(args):
    arms = []
    for arg in args:
        name, dirs = arg.split("=", 1)
        arms.append((name, load(dirs.split(","))))
    keys = sorted(set(arms[0][1]) & set(arms[1][1]), key=lambda k: (int(k[0]), k[1]))
    print("| seed | map/tempo | " + " | ".join("%s blocked_*, friend, yielding, lost G/R" % name for name, _ in arms) + " |")
    print("|---|---|" + "---|" * len(arms))
    up = 0
    for key in keys:
        cells = []
        for name, runs in arms:
            r = runs[key]
            sh = r["share"]
            cells.append("%.1f %%, %.1f %%, %.1f %%, %d/%d" % (100 * blocked(sh), 100 * sh.get("blocked_friend", 0),
                                                         100 * sh.get("yielding", 0), r["green_lost"], r["rust_lost"]))
        if blocked(arms[1][1][key]["share"]) > blocked(arms[0][1][key]["share"]):
            up += 1
        print("| %s | %s | %s |" % (key[0], key[1], " | ".join(cells)))
    print("\n%s's blocked_* share above %s's on %d of %d runs" % (arms[1][0], arms[0][0], up, len(keys)))
    for name, runs in arms:
        queued, yielding, kinds = Counter(), Counter(), defaultdict(Counter)
        longest = 0
        for key in keys:
            q = runs[key].get("queues", {})
            queued.update(q.get("queued_unit_ticks", {}))
            yielding.update(q.get("yield_unit_ticks", {}))
            longest = max(longest, int(q.get("longest_queue", 0)))
            for kind, row in q.get("episodes_by_kind", {}).items():
                kinds[kind].update(row)
        print("\n%s: queued behind a yielder (unit-s) by its kind %s; yielding (unit-s) %s; longest queue %d" % (
            name, {k: round(v / TICK, 1) for k, v in queued.most_common()},
            {k: round(v / TICK, 1) for k, v in yielding.most_common()}, longest))
        for kind, row in sorted(kinds.items()):
            eps = row["episodes"]
            print("  %-6s episodes %4d, %6.1f unit-s yielding, %3d with a queue (%.0f %%), %6.1f queued unit-s, "
                  "%.2f queued s per yielding s" % (kind, eps, row["ticks"] / TICK, row["with_queue"],
                                                    100.0 * row["with_queue"] / max(eps, 1), row["queued_ticks"] / TICK,
                                                    row["queued_ticks"] / max(row["ticks"], 1)))


if __name__ == "__main__":
    main(sys.argv[1:])

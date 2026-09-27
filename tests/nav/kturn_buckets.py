#!/usr/bin/env python3
"""Round 12 (nav N1): bucket every `kturn_none` the Terminus drive logged (NAV_KTURN_NONE lines, `--kturn-log`).

Usage: kturn_buckets.py build/nav-drive/*.log

One bucket per refusal, first match wins, in the order the brief asks the question:
  near_point   the steering point is within NEAR_M of the centre: settling onto a spot, not a turn into a street
  pressed      the hull's outline already started deeper than the clear reach (a nose on a face): a recovery case
  no_room      the single back-up was blocked within its first metre: nothing behind to use
  cap          the back-up ran its whole 8 m without clearing the forward arc (a longer one might)
  short_room   the back-up was blocked between 1 m and 8 m, never clear: the street is too narrow for ONE back-up
and, across every bucket, what else would have cleared it: a longer single back-up, a straight one, or the
back-and-fill (`_plan_fill`, reverse-first or forward-first) and how many legs it needed. A friend in the swept box is
reported beside the bucket, never as one: the search reads the navmesh only, so a friend cannot cause a refusal.
"""
import json

## A steering point closer than this (the War Rig's half length) is a hull settling onto its spot, not one turning into
## a street: no manoeuvre of any family is the answer, the arrival rule is.
NEAR_M = 7.0
import sys
from collections import Counter, defaultdict


def dist(row):
    return ((row["at"][0] - row["to"][0]) ** 2 + (row["at"][1] - row["to"][1]) ** 2) ** 0.5


def bucket(row):
    if dist(row) < NEAR_M:
        return "near_point"
    if row["pressed_points"] > 0:
        return "pressed"
    blocked = row["blocked_at_m"]
    if blocked < 0:
        return "cap"
    if blocked <= 1.0:
        return "no_room"
    return "short_room"


def legs(plan):
    return len(plan) if plan else 0


def main(paths):
    rows = []
    for path in paths:
        run = path.rsplit("/", 1)[-1].removesuffix(".log")
        for line in open(path, errors="replace"):
            if line.startswith("NAV_KTURN_NONE "):
                row = json.loads(line[len("NAV_KTURN_NONE "):])
                row["run"] = run
                rows.append(row)

    if not rows:
        print("NAV_KTURN_BUCKETS none logged (was the drive run with --kturn-log?)")
        return
    by_bucket = defaultdict(list)
    for row in rows:
        by_bucket[bucket(row)].append(row)
    print("NAV_KTURN_BUCKETS total=%d runs=%d units=%d" % (len(rows), len({r["run"] for r in rows}),
                                                          len({(r["run"], r["unit"]) for r in rows})))
    header = "%-11s %5s %6s %6s %8s %9s %9s %9s %s" % ("bucket", "n", "longer", "straight", "fill<=3", "fill<=5",
                                                         "friend_bh", "width", "fill legs (rev-first | fwd-first)")
    print(header)
    for name in ["near_point", "pressed", "no_room", "cap", "short_room"]:
        group = by_bucket.get(name, [])
        if not group:
            print("%-11s %5d" % (name, 0))
            continue
        longer = sum(1 for r in group if r["longer_m"] > 0)
        straight = sum(1 for r in group if r["straight_m"] > 0)
        best = [min([legs(r["fill_rev"]), legs(r["fill_fwd"])], key=lambda n: n if n else 99) for r in group]
        fill3 = sum(1 for n in best if 0 < n <= 3)
        fill5 = sum(1 for n in best if 0 < n <= 5)
        friend = sum(1 for r in group if r["friend_behind"])
        spans = sorted(min(r["spans_m"]) + 2 * r["bake_radius_m"] for r in group)
        median = spans[len(spans) // 2]
        by_legs = Counter(best)
        print("%-11s %5d %6d %8d %8d %9d %9d %8.1fm %s" % (name, len(group), longer, straight, fill3, fill5, friend,
                                                         median, dict(sorted(by_legs.items()))))
    many = []
    for r in rows:
        options = [m for m in (r.get("many_rev", [0, 0]), r.get("many_fwd", [0, 0])) if m[0] > 0]
        many.append(min(options) if options else None)
    found = [m for m in many if m]
    print("NAV_KTURN_MANY found %d of %d; legs %s; metres %s" % (len(found), len(rows),
          dict(sorted(Counter(m[0] for m in found).items())), sorted(round(m[1]) for m in found)))
    print("NAV_KTURN_BY_LEG %s" % json.dumps(dict(sorted(Counter(r.get("leg", -1) for r in rows).items()))))
    print("NAV_KTURN_INTO_LEG_S %s" % json.dumps(dict(sorted(Counter(min(int(r.get("into_leg_s", -1) // 5 * 5), 60)
                                                               for r in rows).items()))))
    blocked_by = Counter(r.get("blocked_by", "-") for r in rows)
    print("NAV_KTURN_BLOCKED_BY %s" % json.dumps(dict(blocked_by.most_common())))
    errors = Counter(int(abs(r["error_deg"]) // 30 * 30) for r in rows)
    dists = Counter(min(int(dist(r) // 5 * 5), 40) for r in rows)
    print("NAV_KTURN_POINT_M %s" % json.dumps(dict(sorted(dists.items()))))
    print("NAV_KTURN_ERROR_DEG %s" % json.dumps(dict(sorted(errors.items()))))
    # The same hull refusing again a second later is one episode seen twice: count distinct (run, unit, place).
    episodes = {(r["run"], r["unit"], round(r["at"][0] / 4), round(r["at"][1] / 4)) for r in rows}
    print("NAV_KTURN_EPISODES %d (distinct run/unit/4 m cell)" % len(episodes))


if __name__ == "__main__":
    main(sys.argv[1:])

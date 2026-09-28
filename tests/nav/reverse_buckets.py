#!/usr/bin/env python3
"""Round 14 (nav N1): the other 53 % -- route-driven reverses and k-turn legs, bucketed.

Usage: reverse_buckets.py LOG [LOG ...]   (logs of `make nav-terminus-drive NAV_FLAGS=--reverse-log`, <squad>-<seed>.log)

Per squad:
  (1) reverse-gear wall-contact ticks by the layer that drove them (`by_driver_gear`), and the route ones by which rule
      reversed (`by_reverse_why`: circle / station / order / other);
  (2) circle episodes (`NAV_CIRCLE`): Steering's circle rule backing a wheeled hull on a forward route order, bucketed by
      whether the point is the route's end or a mid-route steering point, and whether the reverse the rule commits to
      fits the outline sweep (`fits`) or which part leaves the clear reach first (`blocked_by`); contacts, reverse
      contacts, metres needed vs clear;
  (3) k-turn legs (`NAV_KTURN_LEG`): bucketed by plan kind, gear and how the leg ended; planned vs driven metres, the
      drift from the planner's pose at the same distance, the predicted vs the actual clearance margin, contacts.
"""
import json
import os
import statistics
import sys
from collections import Counter, defaultdict


def read(paths):
    squads = defaultdict(lambda: {"runs": 0, "driver_gear": Counter(), "why": Counter(), "circles": [], "legs": []})
    for path in paths:
        name = os.path.basename(path).removesuffix(".log")
        squad, seed = name.rsplit("-", 1)
        final = None
        circles, legs = [], []
        for line in open(path, errors="replace"):
            if line.startswith("NAV_DRIVE "):
                final = json.loads(line[len("NAV_DRIVE "):])
            elif line.startswith("NAV_CIRCLE "):
                circles.append(json.loads(line[len("NAV_CIRCLE "):]))
            elif line.startswith("NAV_KTURN_LEG "):
                legs.append(json.loads(line[len("NAV_KTURN_LEG "):]))
        if final is None:
            print("REFUSED %s: no NAV_DRIVE line (the run did not finish)" % path)
            continue
        entry = squads[squad]
        entry["runs"] += 1
        entry["driver_gear"].update(final["wall_contacts"].get("by_driver_gear", {}))
        entry["why"].update(final["wall_contacts"].get("by_reverse_why", {}))
        for row in circles + legs:
            row["seed"] = seed
        entry["circles"].extend(circles)
        entry["legs"].extend(legs)
    return squads


def med(values):
    values = [v for v in values if v is not None]
    return round(statistics.median(values), 2) if values else "-"


def moving(rows):
    out = Counter()
    for row in rows:
        out.update(row.get("moving", {}))
    return out


def circle_bucket(row):
    where = "goal" if row.get("point_is_goal") else "mid"
    sweep = "fits" if row.get("fits") else ("blocked:" + row.get("blocked_by", "?") if "blocked_by" in row else "never_lets_go")
    return (where, sweep)


def leg_bucket(row):
    return (row.get("kind", "?"), "rev" if row.get("gear", -1) < 0 else "fwd", row.get("end", "open"))


def table(title, head, rows):
    print("\n" + title)
    print("| " + " | ".join(head) + " |")
    print("|" + "---|" * len(head))
    for r in rows:
        print("| " + " | ".join(str(c) for c in r) + " |")


def main(paths):
    squads = read(paths)
    for squad, entry in sorted(squads.items()):
        dg = entry["driver_gear"]
        rev = {k.split("/")[0]: v for k, v in dg.items() if k.endswith("/reverse")}
        print("\n## %s: %d runs; reverse-gear contact ticks %d by driver %s" % (
            squad, entry["runs"], sum(rev.values()), dict(sorted(rev.items(), key=lambda kv: -kv[1]))))
        print("route/reverse by rule: %s (sum %d; route/reverse %d)" % (
            dict(entry["why"].most_common()), sum(entry["why"].values()), rev.get("route", 0)))

        circles = entry["circles"]
        groups = defaultdict(list)
        for row in circles:
            groups[circle_bucket(row)].append(row)
        rows = []
        for key, members in sorted(groups.items(), key=lambda kv: -sum(r["reverse_contacts"] for r in kv[1])):
            rows.append([key[0], key[1], len(members), sum(r["contacts"] for r in members),
                         sum(r["reverse_contacts"] for r in members), med([r.get("needed_m") for r in members]),
                         med([r.get("clear_m") for r in members]), med([r.get("driven_m") for r in members]),
                         med([r.get("remaining_m") for r in members]), med([r.get("fwd_same_m") for r in members]),
                         med([r.get("fwd_other_m") for r in members]),
                         dict(Counter(r.get("end", "open") for r in members).most_common(3))])
        table("circle episodes (%d; contacts %d, reverse %d)" % (len(circles), sum(r["contacts"] for r in circles),
                                                                 sum(r["reverse_contacts"] for r in circles)),
              ["point", "sweep", "episodes", "contacts", "rev contacts", "needed m", "clear m", "driven m",
               "remaining m", "fwd same m", "fwd other m", "ended"], rows)
        ends, hits = Counter(), Counter()
        for row in circles:
            for k, v in row.get("ends", {}).items():
                ends[k] += v
            for k, v in row.get("hit", {}).items():
                hits[k] += v
        print("circle contacts by end: %s; hit: %s" % (dict(ends.most_common()), dict(hits.most_common(6))))
        print("circle contacts by gear/end/actual roll: %s; median v0 of episodes with contacts %s, without %s" % (
            dict(moving(circles).most_common(8)), med([r.get("v0") for r in circles if r["contacts"]]),
            med([r.get("v0") for r in circles if not r["contacts"]])))

        legs = entry["legs"]
        groups = defaultdict(list)
        for row in legs:
            groups[leg_bucket(row)].append(row)
        rows = []
        for key, members in sorted(groups.items(), key=lambda kv: -sum(r["reverse_contacts"] for r in kv[1])):
            rows.append([key[0], key[1], key[2], len(members), sum(r["contacts"] for r in members),
                         sum(r["reverse_contacts"] for r in members), med([r.get("planned_m") for r in members]),
                         med([r.get("driven_m") for r in members]), med([r.get("drift_m") for r in members]),
                         med([r.get("drift_deg") for r in members]), med([r.get("pred_margin_m") for r in members]),
                         med([r.get("end_margin_m") for r in members]), med([r.get("start_margin_m") for r in members])])
        table("k-turn legs (%d; contacts %d, reverse %d)" % (len(legs), sum(r["contacts"] for r in legs),
                                                            sum(r["reverse_contacts"] for r in legs)),
              ["kind", "gear", "ended", "legs", "contacts", "rev contacts", "planned m", "driven m", "drift m",
               "drift deg", "pred margin", "end margin", "start margin"], rows)
        ends, hits, parts = Counter(), Counter(), Counter()
        for row in legs:
            for k, v in row.get("ends", {}).items():
                ends[k] += v
            for k, v in row.get("hit", {}).items():
                hits[k] += v
            if row.get("contacts", 0) > 0:
                parts[row.get("end_part", "?")] += row["contacts"]
        print("leg contacts by end: %s; hit: %s; outline part out at the leg's end (contact-weighted): %s" % (
            dict(ends.most_common()), dict(hits.most_common(6)), dict(parts.most_common())))
        print("leg contacts by gear/end/actual roll: %s; legs with contacts: median v0 %s, wrong-way %s m; without: %s, %s m" % (
            dict(moving(legs).most_common(8)), med([r.get("v0") for r in legs if r["contacts"]]),
            med([r.get("wrong_way_m") for r in legs if r["contacts"]]), med([r.get("v0") for r in legs if not r["contacts"]]),
            med([r.get("wrong_way_m") for r in legs if not r["contacts"]])))
        # Round 14 (N3): planned in time? The roll-out (v^2/2b against the leg's gear) vs the arc's hit distance.
        firsts = [r for r in legs if r.get("leg_no") == 1 and r.get("kind") in ("single", "fill")]
        late = [r for r in firsts if (r.get("roll_margin_m") is not None and r["roll_margin_m"] < 0)]
        print("first legs %d: roll-out NOT clear %d (their contacts %d, reverse %d; median stop %s m, hit %s m); "
              "roll-out clear or none %d (contacts %d, reverse %d)" % (
                  len(firsts), len(late), sum(r["contacts"] for r in late), sum(r["reverse_contacts"] for r in late),
                  med([r.get("stop_m") for r in late]), med([r.get("hit_m") for r in late]), len(firsts) - len(late),
                  sum(r["contacts"] for r in firsts if r not in late), sum(r["reverse_contacts"] for r in firsts if r not in late)))
        # Planned vs driven, contact legs only: is the leg short of its plan (cut) or on plan and still in a wall?
        with_contact = [r for r in legs if r.get("contacts", 0) > 0]
        planned_ok = [r for r in with_contact if (r.get("pred_margin_m") or 0) >= 0]
        print("legs with contacts %d: predicted clear along the whole leg %d (their contacts %d, reverse %d); "
              "median drift %s m / %s deg (all legs: %s m / %s deg)" % (
                  len(with_contact), len(planned_ok), sum(r["contacts"] for r in planned_ok),
                  sum(r["reverse_contacts"] for r in planned_ok), med([r.get("drift_m") for r in with_contact]),
                  med([abs(r.get("drift_deg") or 0) for r in with_contact]), med([r.get("drift_m") for r in legs]),
                  med([abs(r.get("drift_deg") or 0) for r in legs])))


if __name__ == "__main__":
    main(sys.argv[1:])

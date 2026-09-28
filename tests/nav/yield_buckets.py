#!/usr/bin/env python3
"""Round 13 (nav R1): where the rig backs into walls when it gives way.

Usage: yield_buckets.py LOG [LOG ...]    (logs of `make nav-terminus-drive NAV_FLAGS=--yield-log`, <squad>-<seed>.log)

Per squad: (1) the reverse-gear wall-contact ticks by the layer that drove them (`WallContact.by_driver_gear`), so the
yield share is read, not assumed; (2) every give-way (`NAV_YIELD`), bucketed by the gear it drove to its spot, the kind
of spot (round 6's `spot(along,across)` table or the straight `back(m)` last resort), and whether the straight run to
the spot keeps the whole outline inside the clear reach (the planned reverse's sweep): `clear`, or the first part
that leaves it. Each bucket: give-ways, contact ticks, reverse-gear contact ticks, reached, the room behind the tail.
Then what the reverse contacts hit, with which end, and through which route the give-way began (asked / behind / self).
"""
import json
import os
import sys
from collections import Counter, defaultdict


def read(paths):
    squads = defaultdict(lambda: {"runs": 0, "driver_gear": Counter(), "gear": Counter(), "yields": []})
    for path in paths:
        name = os.path.basename(path).removesuffix(".log")
        squad = name.rsplit("-", 1)[0]
        final = None
        yields = []
        for line in open(path, errors="replace"):
            if line.startswith("NAV_DRIVE "):
                final = json.loads(line[len("NAV_DRIVE "):])
            elif line.startswith("NAV_YIELD "):
                yields.append(json.loads(line[len("NAV_YIELD "):]))
        if final is None:
            print("REFUSED %s: no NAV_DRIVE line (the run did not finish)" % path)
            continue
        entry = squads[squad]
        entry["runs"] += 1
        entry["driver_gear"].update(final["wall_contacts"].get("by_driver_gear", {}))
        entry["gear"].update(final["wall_contacts"].get("by_gear", {}))
        for row in yields:
            row["seed"] = name.rsplit("-", 1)[1]
        entry["yields"].extend(yields)
    return squads


def spot_kind(row):
    return "back" if row["spot"].startswith("back") else "spot"


def main(paths):
    squads = read(paths)
    for squad, entry in sorted(squads.items()):
        reverse_total = entry["gear"].get("reverse", 0)
        print("\n== %s: %d runs; reverse-gear contact ticks %d (of %d)" % (
            squad, entry["runs"], reverse_total, sum(entry["gear"].values())))
        by_driver = Counter()
        for key, n in entry["driver_gear"].items():
            driver, gear = key.rsplit("/", 1)
            if gear == "reverse":
                by_driver[driver] += n
        print("  reverse-gear contacts by driver: " + ", ".join("%s %d (%.0f%%)" % (d, n, 100.0 * n / max(reverse_total, 1))
                                                           for d, n in by_driver.most_common()))
        yields = entry["yields"]
        if not yields:
            print("  no NAV_YIELD rows (was --yield-log passed?)")
            continue
        logged_reverse = sum(int(r["reverse_contacts"]) for r in yields)
        print("  give-ways %d; their contact ticks %d, reverse-gear %d (driver 'yield' reverse in the totals: %d)" % (
            len(yields), sum(int(r["contacts"]) for r in yields), logged_reverse, by_driver.get("yield", 0)))
        buckets = defaultdict(list)
        for row in yields:
            buckets[(row["gear"], spot_kind(row), row.get("sweep", "?"))].append(row)
        print("  %-8s %-5s %-12s %6s %8s %8s %8s %13s" % ("gear", "spot", "sweep", "yields", "contacts", "reverse",
                                                          "reached", "room_behind"))
        for key in sorted(buckets, key=lambda k: -sum(int(r["reverse_contacts"]) for r in buckets[k])):
            rows = buckets[key]
            behind = sorted(float(r.get("room_behind_m", -1)) for r in rows)
            print("  %-8s %-5s %-12s %6d %8d %8d %8d %13s" % (
                key[0], key[1], key[2], len(rows), sum(int(r["contacts"]) for r in rows),
                sum(int(r["reverse_contacts"]) for r in rows), sum(1 for r in rows if r.get("reached")),
                "med %.1f" % behind[len(behind) // 2]))
        by_len = defaultdict(lambda: [0, 0, 0])
        for row in yields:
            key = "%s (%.0f m) for %s (%.0f m)" % (row["unit_id"], row["length_m"], row["asker_id"], row["asker_length_m"])
            by_len[key][0] += 1
            by_len[key][1] += int(row["contacts"])
            by_len[key][2] += int(row["reverse_contacts"])
        print("  who gave way for whom: " + "; ".join("%s: %d, %d contacts, %d reverse" % (k, *v)
                                                    for k, v in sorted(by_len.items(), key=lambda kv: -kv[1][2])))
        spots = Counter()
        spot_rev = Counter()
        via = Counter()
        via_rev = Counter()
        hit = Counter()
        ends = Counter()
        for row in yields:
            spots[row["spot"]] += 1
            spot_rev[row["spot"]] += int(row["reverse_contacts"])
            via[row["via"]] += 1
            via_rev[row["via"]] += int(row["reverse_contacts"])
            for what, n in row["hit"].items():
                hit[what] += n
            for end, n in row["ends"].items():
                ends[end] += n
        print("  spots (yields / reverse contacts): " + ", ".join("%s %d/%d" % (s, spots[s], spot_rev[s])
                                                                  for s, _ in spot_rev.most_common()))
        print("  begun via: " + ", ".join("%s %d/%d" % (v, via[v], via_rev[v]) for v in via))
        print("  contact ends (gear/end): " + ", ".join("%s %d" % kv for kv in ends.most_common()))
        print("  what they hit: " + ", ".join("%s %d" % kv for kv in hit.most_common(8)))
        worst = sorted(yields, key=lambda r: -int(r["reverse_contacts"]))[:6]
        print("  worst give-ways:")
        for row in worst:
            print("    seed %s leg %s +%ss %s %s %s gear=%s ahead=%.1f right=%.1f behind=%.1f sweep=%s@%s reached=%s rev=%d hit=%s" % (
                row["seed"], row.get("leg"), row.get("into_leg_s"), row["unit"], row["via"], row["spot"], row["gear"],
                row["ahead_m"], row["right_m"], float(row.get("room_behind_m", -1)), row.get("sweep"),
                row.get("sweep_at_m", "-"), row.get("reached"), int(row["reverse_contacts"]), row["hit"]))


if __name__ == "__main__":
    main(sys.argv[1:])

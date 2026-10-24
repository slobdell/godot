#!/usr/bin/env python3
"""Round 39 (manoeuvre M1's census): chained give-ways from `make traffic-jam-census` logs (jam_census.gd's `giveway_chain`
totals in JAM_CENSUS and its GIVEWAY_CHAIN rows).

    python3 tests/traffic/chain_table.py DIR [DIR2]

Per folder: give-ways by a crew with a seat, split parked / travelling; parked ones by how far off the seat they began (off-seat
bin) and by chain index (give-ways in a row since the crew was last back by its seat); per row n, push_m (farthest from the seat
during the give-way minus where it began, summed), out_m (positive end - begin, summed: the drift a give-way left), and the means.
`parked:chained` = parked give-ways begun more than CHAIN_ROW_M (4 m) off the seat. With DIR2, the same rows side by side.
Also the rule's own counters (route_arms chain_*) and parked_refusals, and the fights' kills / deaths per team.
"""
import glob
import json
import os
import sys


def load(folder):
    totals, arms, teams, fights = {}, {}, {}, 0
    for path in sorted(glob.glob(os.path.join(folder, "*.log"))):
        with open(path, errors="replace") as f:
            for line in f:
                if not line.startswith("JAM_CENSUS "):
                    continue
                c = json.loads(line[11:])
                fights += 1
                for key, row in c.get("giveway_chain", {}).items():
                    t = totals.setdefault(key, {"n": 0, "push_m": 0.0, "end_m": 0.0, "out_m": 0.0})
                    for k in t:
                        t[k] += row.get(k, 0)
                ra = c.get("route_arms", {})
                for k in ("chain_in_play", "chain_spots_skipped", "chain_refusals", "parked_refusals", "yields_started"):
                    arms[k] = arms.get(k, 0) + int(ra.get(k, 0))
                for team, row in c.get("teams", {}).items():
                    t = teams.setdefault(team, {"kills": 0, "deaths": 0})
                    t["kills"] += int(row.get("kills", 0))
                    t["deaths"] += int(row.get("deaths", 0))
    return {"fights": fights, "totals": totals, "arms": arms, "teams": teams}


def order(key):
    rank = {"all": 0, "travelling": 1, "parked": 2, "parked:chained": 3}
    if key in rank:
        return (rank[key], 0.0, key)
    tail = key.split(":")[-1]
    num = float(tail.split("-")[0].rstrip("+")) if tail[0].isdigit() else 0.0
    return (4 if ":off:" in key else 5, num, key)


def cells(row):
    n = row["n"] if row else 0
    if not n:
        return "%5d %8s %8s %6s" % (0, "-", "-", "-")
    return "%5d %8.1f %8.1f %6.2f" % (n, row["push_m"], row["out_m"], row["out_m"] / n)


def main(argv):
    folders = argv[1:]
    data = [load(f) for f in folders]
    print("fights: " + " | ".join("%s %d" % (os.path.basename(f.rstrip("/")), d["fights"]) for f, d in zip(folders, data)))
    keys = sorted(set().union(*[d["totals"].keys() for d in data]), key=order)
    head = "%-24s" % "give-ways" + "".join(" | %5s %8s %8s %6s" % ("n", "push_m", "out_m", "out/n") for _ in data)
    print(head)
    for key in keys:
        print("%-24s" % key + "".join(" | " + cells(d["totals"].get(key)) for d in data))
    for d, f in zip(data, folders):
        print("%s: %s; teams %s" % (os.path.basename(f.rstrip("/")), json.dumps(d["arms"], sort_keys=True), json.dumps(d["teams"], sort_keys=True)))


if __name__ == "__main__":
    main(sys.argv)

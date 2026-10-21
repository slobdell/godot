#!/usr/bin/env python3
"""Round 36 (manoeuvre S4): orders' LOOP squads, the metres each crew drove AWAY from its order goal, by what was driving.

usage: s4_away.py DIR   (one orders-probe-trace log per case, `<map>-<n>-<route>-<seed>-sq<squad>.log`, run with the lab probe
                         `S4_AWAY f <frame> <crew> {driver: metres}` (lab/s4-trace, movement.gd `_s4_away`, measurement only))

Drivers: hold (Traffic.holding: traffic's street hold), yield (phase yielding: a give-way), kturn1 / kturn-1 (a planned k-turn
leg, forward / reverse), escape (H1 / unstick), side (S2a), route_rev (the route law in reverse), route (the route law forward:
the wheels' own turn-around, the case S4 was filed for), planner. A crew's row is cumulative; the last one counts.
Measurement only.
"""
import collections
import json
import os
import re
import sys

SQUADS = {1: "Alpha", 2: "Bravo", 3: "Charlie", 4: "Delta", 5: "Echo"}
ROW = re.compile(r"^S4_AWAY f (\d+) (.+?) (\{.*\})$")
## probe v2: one row every 15 frames while a FRESH route episode drives away (no other driver in the 5 s before it):
## its start frame, the goal's distance and angle off the nose then, and the metres away so far (the last row a little short).
## probe v3: every give-way begun (the yielder's distance to its OWN seat, the spot, T7's pass lane for the asker: 0 none).
YIELD = re.compile(r"^S4_YIELD f (\d+) (.+?) unit (\S+) order (\S*) seat_m (-?[\d.]+) spot (.*?) spot_m ([\d.]+) "
                   r"spot_seat_m (-?[\d.]+) asker (.+?) lane (-?\d+)$")
EP = re.compile(r"^S4_EP (.+?) start (\d+) d ([\d.]+) off_nose (\d+) v (-?[\d.]+) unit (\S+) m ([\d.]+)$")


def read(log):
    last = {}
    read.eps = {}
    read.yields = []
    for line in open(log, errors="replace"):
        y = YIELD.match(line)
        if y:
            read.yields.append((int(y.group(1)), y.group(2), y.group(3), y.group(4), float(y.group(5)), y.group(6),
                                float(y.group(7)), float(y.group(8)), y.group(9), int(y.group(10))))
            continue
        e = EP.match(line)
        if e:
            read.eps[(e.group(1), int(e.group(2)))] = (float(e.group(3)), int(e.group(4)), float(e.group(5)), e.group(6),
                                                       float(e.group(7)))
            continue
        m = ROW.match(line)
        if m:
            last[m.group(2)] = json.loads(m.group(3))
        elif line.startswith("ORDERS_PROBE_SQUAD "):
            r = json.loads(line.split(" ", 1)[1])
            read.squads[r["squad"]] = r
    return last


def main():
    root = sys.argv[1]
    total = collections.Counter()
    dominant = collections.Counter()
    episodes = []
    yields = []
    print("case                         crew              away_m(orders)  driven away, m by driver")
    for name in sorted(os.listdir(root)):
        if not name.endswith(".log") or "-sq" not in name:
            continue
        read.squads = {}
        last = read(os.path.join(root, name))
        squad = int(name.rsplit("-sq", 1)[1].split(".")[0])
        prefix = "Green_%s_" % SQUADS[squad]
        crews = {k: v for k, v in last.items() if k.startswith(prefix)}
        if not crews:
            print("%-28s no S4_AWAY rows for %s" % (name, prefix))
            continue
        worst = max(crews, key=lambda k: sum(crews[k].values()))
        row = crews[worst]
        top = max(row, key=row.get)
        dominant[top] += 1
        for k, v in row.items():
            total[k] += v
        episodes += [(name[:-4], crew, start) + ep for (crew, start), ep in read.eps.items() if crew.startswith(prefix)]
        yields += [(name[:-4],) + y for y in read.yields if y[1].startswith(prefix)]
        away = read.squads.get(squad, {}).get("away_m", -1)
        print("%-28s %-17s %6.1f          %s" % (name[:-4], worst, away,
              ", ".join("%s %.1f" % (k, v) for k, v in sorted(row.items(), key=lambda kv: -kv[1]))))
    print("worst crew's largest driver, cases: %s" % dict(dominant.most_common()))
    big = sorted((e for e in episodes if e[-1] >= 5.0), key=lambda e: -e[-1])
    print("fresh route episodes >= 5 m away, the looping squads' crews (%d; goal distance and angle off the nose at the start):" % len(big))
    for case, crew, start, d, off, v, unit, m in big:
        print("  %-28s %-16s %-10s f %5d  goal %5.1f m, %3d deg off the nose, v %5.2f  -> %.1f m away" % (case, crew, unit, start, d, off, v, m))
    if yields:
        print("give-ways begun by the looping squads' crews (%d): seat_m = the yielder's distance to its own seat at the ask;"
              " spot_seat_m = the spot's; lane = T7's pass lane for the asker (0 none, +-1 a side)" % len(yields))
        for case, f, crew, unit, order, seat, spot, spot_m, spot_seat, asker, lane in yields:
            print("  %-28s f %5d %-16s %-10s %-8s seat %5.1f -> spot %-14s %5.1f m away, %5.1f m from seat; asker %s lane %+d" % (
                case, f, crew, unit, order, seat, spot, spot_m, spot_seat, asker, lane))
        near = [y for y in yields if 0 <= y[5] <= 10.0]
        print("  at or near their seat (<= 10 m) when asked: %d of %d; of those sent >= 10 m from the seat: %d; with a lane for the"
              " asker: %d" % (len(near), len(yields), sum(1 for y in near if y[8] >= 10.0), sum(1 for y in near if y[10] != 0)))
    print("metres away summed over the worst crews: %s" % {k: round(v, 1) for k, v in total.most_common()})


if __name__ == "__main__":
    main()

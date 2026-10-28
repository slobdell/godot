#!/usr/bin/env python3
"""Round 43 (manoeuvre S1): the per-crew table of a start_trace.gd log (make manoeuvre-start-trace).
    python3 tests/manoeuvre/start_table.py build/manoeuvre/start_trace.log [--every=15] [--crew=Guns_3]
Per traced crew: its squad's click, its first seat and how far that is from the click, how many times the seat moved (and
the biggest move), the first tick it read arrived, the nearest it came to the click, seconds yielding / blocked and to whom,
and the k-turn / wedged seconds. --crew prints that crew's timeline (a row every --every ticks and at every phase change).
"""
import json, math, re, sys


def parse(path):
    rows, seats, orders, yields, gaps = {}, [], [], [], []
    for line in open(path):
        if line.startswith("START_ROW "):
            d = dict(kv.split("=", 1) for kv in line.split()[1:] if "=" in kv)
            rows.setdefault(d["n"], []).append(d)
        elif line.startswith("START_SEAT "):
            seats.append(line.rstrip("\n"))
        elif line.startswith("START_ORDER "):
            orders.append(json.loads(line.split(" ", 1)[1]))
        elif line.startswith("START_YIELD "):
            t, body = line.split(" ", 2)[1:]
            yields.append((int(t[2:]), json.loads(body)))
        elif line.startswith("START_GAP "):
            gaps.append(line.rstrip("\n"))
    return rows, seats, orders, yields, gaps


def point(s):
    m = re.match(r"\((-?[\d.]+),(-?[\d.]+)\)", s or "")
    return (float(m.group(1)), float(m.group(2))) if m else None


def clicks(seats):
    """element -> its task's 'to' from the first START_SEAT naming it."""
    out = {}
    for line in seats:
        el = re.search(r" el=(\S+)", line).group(1)
        m = re.search(r'"to":\[(-?[\d.]+),(-?[\d.]+)\]', line)
        if el not in out and m:
            out[el] = (float(m.group(1)), float(m.group(2)))
    return out


def table(rows, seats, yields):
    by_el = clicks(seats)
    print("%-10s %-16s %6s %5s %6s %7s %6s %6s %6s %6s  %s" % ("crew", "first seat", "d_clk", "moves", "maxmv", "arrived", "nearest", "yield", "block", "kturn", "yields to (via spot) / wedged s"))
    for n in sorted(rows, key=lambda k: (k.rsplit("_", 1)[0], int(k.rsplit("_", 1)[1]) if k.rsplit("_", 1)[1].isdigit() else 0)):
        r = rows[n]
        el = n.rsplit("_", 1)[0]
        click = by_el.get(el)
        first = next((d["seat"] for d in r if point(d["seat"])), "-")
        d_click = math.dist(point(first), click) if point(first) and click else float("nan")
        last, moves, maxmv = None, 0, 0.0
        for d in r:
            p = point(d["seat"])
            if p is None:
                continue
            if last is not None and math.dist(p, last) > 1.0:
                moves += 1
                maxmv = max(maxmv, math.dist(p, last))
            last = p
        t0 = int(r[0]["t"])
        # The first "arrived" AFTER the crew has driven (the idle mover reads arrived before its order's first drive).
        driven = False
        arrived = None
        for d in r:
            driven = driven or d["ph"] == "driving"
            try:
                near_seat = float(d["dseat"]) <= 12.0
            except ValueError:
                near_seat = True
            if driven and d["ph"] == "arrived" and near_seat:
                arrived = int(d["t"])
                break
        nearest = min(math.dist((float(d["x"]), float(d["z"])), click) for d in r) if click else float("nan")
        yielding = sum(1 for d in r if d["ph"] == "yielding") / 30.0
        blocked = sum(1 for d in r if d["ph"] == "blocked") / 30.0
        kturn = sum(1 for d in r if d["kt"] == "1") / 30.0
        wedged = sum(1 for d in r if d["wed"] == "1") / 30.0
        partners = []
        for t, y in yields:
            if y.get("unit", "").endswith("_" + n) or y.get("unit", "") == "Green_" + n:
                partners.append("t%d %s (%s %s)" % (t, y.get("asker", "").replace("Green_", ""), y.get("via", ""), y.get("spot", "")))
        print("%-10s %-16s %6.1f %5d %6.1f %7s %6.1f %6.1f %6.1f %6.1f  %s%s" % (n, first, d_click, moves, maxmv,
                ("%.1fs" % (arrived / 30.0)) if arrived else "never", nearest, yielding, blocked, kturn, "; ".join(partners),
                (" / wedged %.1f s" % wedged) if wedged > 0 else ""))
    print()
    print("seatings (%d changes):" % len(seats))
    for line in seats:
        head = line.split(" | ")[0]
        print("  " + head[len("START_SEAT "):][:200])


def timeline(rows, crew, every):
    last = None
    for d in rows.get(crew, []):
        t = int(d["t"])
        key = (d["ph"], d["bb"], d["y"], d["rev"], d["kt"], d["seat"], d["ord"])
        if t % every == 0 or key != last:
            print(" t%4d (%6s,%6s) hdg%4s spd%5s ph=%-8s bb=%-10s y=%-16s g=%-14s dg=%-5s st=%-14s pace=%s stall=%s rev=%s kt=%s wed=%s defl=%s path=%s ord=%s seat=%s dseat=%s" % (
                    t, d["x"], d["z"], d["hdg"], d["spd"], d["ph"], d["bb"], d["y"], d["g"], d["dg"], d["st"], d["pace"], d["stall"],
                    d["rev"], d["kt"], d["wed"], d["defl"], d["path"], d["ord"], d["seat"], d["dseat"]))
            last = key


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    every = next((int(a.split("=", 1)[1]) for a in sys.argv[1:] if a.startswith("--every=")), 15)
    crew = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--crew=")), "")
    rows, seats, orders, yields, gaps = parse(args[0])
    if crew:
        timeline(rows, crew, every)
        return
    table(rows, seats, yields)
    if gaps:
        print()
        print("fidelity (gap from his census, m): first %s | last %s" % (gaps[0][len("START_GAP "):][:160], gaps[-1][len("START_GAP "):][:160]))


if __name__ == "__main__":
    main()

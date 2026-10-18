#!/usr/bin/env python3
"""Round 30 (brains B5c-v4): make gate-series' paired table. Rows pair on (cell, seed, start_tick); `never` (a run whose
crews were not all in) sorts last and counts as never in the median. Usage: gate_table.py build/gate-series.jsonl"""
import json
import statistics
import sys

NEVER = float("inf")


def last_in(row):
    """Yard / Terminus (TrafficStage): the last crew's arrival, or NEVER unless every crew arrived."""
    if row.get("missing"):
        return NEVER
    times = list((row.get("arrive_s") or {}).values())
    if int(row.get("arrived", 0)) < int(row.get("crews", 0)) or not times or min(times) < 0:
        return NEVER
    return max(times)


def within8(row):
    """Sumps (settle_probe): every crew within 8 m of its slot (all_in8_s), or NEVER."""
    value = row.get("all_in8_s", -1)
    return NEVER if row.get("missing") or value is None or value < 0 else float(value)


def fired(row):
    keys = ("gates_given_up", "gates_reached_latched", "gates_shortened", "gates_turned", "gates_latched_away", "gates_near", "gates_side")
    return sum(int(row.get(k, 0) or 0) for k in keys)


def fmt(value):
    return "never" if value == NEVER else "%.1f" % value


def median(values):
    return statistics.median(values) if values else NEVER


def main(path):
    rows = [json.loads(line) for line in open(path) if line.strip()]
    pairs = {}
    for row in rows:
        key = (row.get("cell"), int(row.get("seed", -1)), int(row.get("start_tick", -1)))
        pairs.setdefault(key, {})[row.get("arm")] = row
    for cell, read, label in (("yard", last_in, "last crew in (s)"), ("sumps", within8, "all within 8 m (s)"),
                              ("terminus", last_in, "last crew in (s)")):
        keys = sorted(k for k in pairs if k[0] == cell and {"on", "off"} <= set(pairs[k]))
        if not keys:
            continue
        on = [read(pairs[k]["on"]) for k in keys]
        off = [read(pairs[k]["off"]) for k in keys]
        print("\n== %s (n = %d pairs): %s" % (cell, len(keys), label))
        for k, a, b in zip(keys, on, off):
            p_on, p_off = pairs[k]["on"], pairs[k]["off"]
            extra = ""
            if cell != "sumps":
                extra = " crews %s/%s v %s/%s" % (p_on.get("arrived"), p_on.get("crews"), p_off.get("arrived"), p_off.get("crews"))
            else:
                extra = " arc %s v %s" % (p_on.get("guns_on_arc"), p_off.get("guns_on_arc"))
            print("  s%-3d t%-3d on %7s  off %7s%s  fired on %d off %d  (turned %s latched_away %s near %s side %s)" % (
                k[1], k[2], fmt(a), fmt(b), extra, fired(p_on), fired(p_off), p_on.get("gates_turned"),
                p_on.get("gates_latched_away"), p_on.get("gates_near"), p_on.get("gates_side")))
        print("  median on %s v off %s; on never %d, off never %d" % (fmt(median(on)), fmt(median(off)),
              on.count(NEVER), off.count(NEVER)))
        if cell == "sumps":
            later = [k for k, a, b in zip(keys, on, off) if a > b + 5.0]
            arcs_on = [float(pairs[k]["on"].get("guns_on_arc", -1)) for k in keys]
            arcs_off = [float(pairs[k]["off"].get("guns_on_arc", -1)) for k in keys]
            print("  runs > 5 s later on: %d %s; guns_on_arc mean on %.3f v off %.3f" % (len(later), later,
                  statistics.mean(arcs_on), statistics.mean(arcs_off)))
        else:
            fewer = [k for k in keys if int(pairs[k]["on"].get("arrived", 0)) < int(pairs[k]["off"].get("arrived", 0))]
            print("  runs with fewer crews in on: %d %s" % (len(fewer), fewer))
        print("  counter: on-arm runs with 0 fired %d; off-arm runs with > 0 fired %d" % (
            sum(1 for k in keys if fired(pairs[k]["on"]) == 0), sum(1 for k in keys if fired(pairs[k]["off"]) > 0)))
    missing = [r for r in rows if r.get("missing")]
    if missing:
        print("\nMISSING rows: %d %s" % (len(missing), [(r.get("cell"), r.get("arm"), r.get("seed"), r.get("start_tick")) for r in missing]))


if __name__ == "__main__":
    main(sys.argv[1])

#!/usr/bin/env python3
"""Round 17 (sim F2): the first tick at which two witness dumps (SIM_HASH_DETAIL lines) differ, and WHAT differs there,
by kind: a unit's state / velocity / command / intent, a team's intel contact, a shell, the clock line, the census.
Usage: witness_first_field.py runA.txt runB.txt [ticks_to_show=3] [--common: only keys both runs dumped]
"""
import sys


def load(path):
    by_tick = {}
    for line in open(path, errors="replace"):
        if not line.startswith("SIM_HASH_DETAIL "):
            continue
        parts = line.split()
        tick = int(parts[1].split("=")[1])
        kind = parts[2]
        if kind.startswith("intel") or kind in ("shell", "census"):
            key = (kind, parts[3])
            fields = {"value": " ".join(parts[4:])}
        elif kind == "clock":
            key = ("clock", "")
            fields = {p.split("=")[0]: p for p in parts[3:]}
        else:
            key = ("unit", kind)
            fields = {"state": parts[3], "vel": parts[4], "cmd": parts[5], "intent": " ".join(parts[6:])}
        by_tick.setdefault(tick, {})[key] = fields
    return by_tick


def main():
    a, b = load(sys.argv[1]), load(sys.argv[2])
    show = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 3
    shown = 0
    for tick in sorted(set(a) & set(b)):
        da, db = a[tick], b[tick]
        diffs = []
        for key in sorted(set(da) | set(db)):
            fa, fb = da.get(key), db.get(key)
            if fa == fb:
                continue
            if fa is None or fb is None:
                if "--common" in sys.argv:
                    continue
                diffs.append((key, "only in run %s" % ("A" if fb is None else "B")))
                continue
            diffs.append((key, ",".join(k for k in fa if fa.get(k) != fb.get(k))))
        if not diffs:
            continue
        kinds = {}
        for (kind, name), what in diffs:
            kinds.setdefault(kind if not kind.startswith("intel") else kind, []).append("%s[%s]" % (name, what))
        print("tick %d: %d difference(s)" % (tick, len(diffs)))
        for kind in sorted(kinds):
            print("  %-7s %d: %s" % (kind, len(kinds[kind]), " ".join(kinds[kind][:40])))
        shown += 1
        if shown >= show:
            break
    if shown == 0:
        print("no detail difference")


if __name__ == "__main__":
    main()

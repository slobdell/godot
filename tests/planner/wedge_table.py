#!/usr/bin/env python3
"""planner P0: read a Terminus rigs drive log (DRIVE_TRACE on every rig) and list every PIN: a run of ticks where a rig
asked for throttle, reported a speed, and moved under PIN_MOVE_M a tick. Prints one line per pin (unit, first tick,
ticks, reported speed, metres moved over the pin) and the census rows' cause tally."""
import json
import re
import sys

PIN_MOVE_M = 0.01
PIN_MIN_TICKS = 30
# DRIVE_TRACE Green_S0_3  dt=0.03333 wanted=(x, z) -> would move (dx, dz) | moved=(dx, dz) ...
LINE = re.compile(r"^DRIVE_TRACE (\S+)\s+dt=\S+ wanted=\(([-\d.]+), ([-\d.]+)\) -> would move \(([-\d.]+), ([-\d.]+)\) \| moved=\(([-\d.]+), ([-\d.]+)\)(.*)$")


def main(path):
    pins = {}
    open_pin = {}
    tick_of = {}
    causes = {}
    kinds = {}
    with open(path, errors="replace") as f:
        for line in f:
            if line.startswith("MANOEUVRE_TURN "):
                row = json.loads(line[len("MANOEUVRE_TURN "):])
                causes[row.get("cause")] = causes.get(row.get("cause"), 0) + 1
                kinds[row.get("kind")] = kinds.get(row.get("kind"), 0) + 1
                continue
            m = LINE.match(line)
            if not m:
                continue
            unit = m.group(1)
            wanted = (float(m.group(2)) ** 2 + float(m.group(3)) ** 2) ** 0.5
            would = (float(m.group(4)) ** 2 + float(m.group(5)) ** 2) ** 0.5
            moved = (float(m.group(6)) ** 2 + float(m.group(7)) ** 2) ** 0.5
            tick_of[unit] = tick_of.get(unit, 0) + 1
            tick = tick_of[unit]
            pinned = wanted > 1.0 and moved < PIN_MOVE_M
            if pinned:
                pin = open_pin.get(unit)
                if pin is None:
                    pin = {"unit": unit, "first_tick": tick, "ticks": 0, "wanted": wanted, "moved": 0.0, "would": would}
                    open_pin[unit] = pin
                pin["ticks"] += 1
                pin["moved"] += moved
                pin["wanted"] = max(pin["wanted"], wanted)
            elif unit in open_pin:
                pin = open_pin.pop(unit)
                if pin["ticks"] >= PIN_MIN_TICKS:
                    pins.setdefault(unit, []).append(pin)
    for unit, pin in open_pin.items():
        if pin["ticks"] >= PIN_MIN_TICKS:
            pins.setdefault(unit, []).append(pin)
    total = 0
    print("PLANNER_WEDGE pins of >= %d ticks (wanted speed > 1 m/s, moved < %.2f m a tick):" % (PIN_MIN_TICKS, PIN_MOVE_M))
    for unit in sorted(pins):
        for pin in pins[unit]:
            total += pin["ticks"]
            print("PLANNER_WEDGE_PIN %s from tick %d: %d ticks (%.1f s), wanted up to %.1f m/s, moved %.3f m in all" % (
                unit, pin["first_tick"], pin["ticks"], pin["ticks"] / 30.0, pin["wanted"], pin["moved"]))
    print("PLANNER_WEDGE_TOTAL pinned unit-ticks %d (%.1f s); census causes %s kinds %s" % (
        total, total / 30.0, json.dumps(causes, sort_keys=True), json.dumps(kinds, sort_keys=True)))


if __name__ == "__main__":
    main(sys.argv[1])

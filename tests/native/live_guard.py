#!/usr/bin/env python3
"""Round 28 (N7 guard): every native switch in force took its native path under the tick profile.

Reads the NATIVE_TICK_PROFILE line of a `--native-tick-profile` run: `native_on` (the switches the run had on) and
`native_taken` (the native paths taken, counted under the instrument from its install until the window opened).
A switch with no count of its own is checked through the path that carries it (INSIDE). Exit 1 names every switch
that stepped aside -- the class of bug where a seam steps aside for a measurement mode and a price compares GDScript
with GDScript (found 2026-10-13: pathing and perception under profile_detail).
"""
import json
import sys

# Switches carried by another native path (read live by the C++ each call, no gate of their own): the native drive
# (drive_native.cpp) runs the ported callbacks (native_cb), the beaten-zone check (native_fire), Avoidance.solve's
# native branch (native_avoid: `switches->get("native_avoid")` each drive) and Movement._next_waypoint's route tail
# (native_path: its own port inside the drive; the switch gates only the GDScript drive's seam, NativeRoute).
INSIDE = {"native_cb": "drive", "native_fire": "drive", "native_avoid": "drive", "native_path": "drive"}
# Switches whose path the tick profile's match never runs, each held live by its own test instead (named, printed, never
# silently skipped): the black box records only skirmishes (MatchRecorder.start), not the profile's headless match.
ELSEWHERE = {"native_recorder": "tests/test_native_recorder.gd (the tick profile does not record)",
             # Round 31 (C31.5): the planner plans only behind --nav-off=planner (CP-P1), never in the profile's match.
             "native_planner": "tests/test_native_planner.gd (the planner's twin test; nothing in the profile plans)"}


def main(path: str) -> int:
    report = None
    for line in open(path, errors="replace"):
        if line.startswith("NATIVE_TICK_PROFILE "):
            report = json.loads(line[len("NATIVE_TICK_PROFILE "):])
    if report is None:
        print("native-live-guard: no NATIVE_TICK_PROFILE in %s" % path)
        return 1
    on = report.get("native_on", [])
    taken = report.get("native_taken", {})
    if not on:
        print("native-live-guard: no native switch in force (the library absent?) -- nothing guarded, FAIL")
        return 1
    missing = []
    elsewhere = 0
    for switch in on:
        if switch in ELSEWHERE:
            print("  %-20s held elsewhere: %s" % (switch, ELSEWHERE[switch]))
            elsewhere += 1
            continue
        name = INSIDE.get(switch, switch[len("native_"):])
        count = int(taken.get(name, 0))
        print("  %-20s %-12s %8d %s" % (switch, name, count, "ok" if count > 0 else "STEPPED ASIDE"))
        if count <= 0:
            missing.append(switch)
    if missing:
        print("native-live-guard: FAIL -- on but not taken under the tick profile: %s" % ", ".join(missing))
        return 1
    print("native-live-guard: every native switch in force (%d) took its path under the tick profile%s" % (
        len(on) - elsewhere, (", %d held elsewhere by its own test" % elsewhere) if elsewhere else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))

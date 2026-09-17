#!/usr/bin/env python3
"""CP1 (round 5): print a SIM_PROFILE line as a table (`make sim-profile`). Usage: sim_profile_report.py LOG [OUT.json]"""
import json
import sys


def main():
    profile = result = None
    for line in open(sys.argv[1], errors="replace"):
        if line.startswith("SIM_PROFILE "):
            profile = json.loads(line[len("SIM_PROFILE "):])
        elif line.startswith("MATCH_RESULT "):
            result = json.loads(line[len("MATCH_RESULT "):])
    if profile is None or result is None:
        print("no SIM_PROFILE / MATCH_RESULT in", sys.argv[1], file=sys.stderr)
        return 1
    tanks = result["tanks"]
    print(f"SIM PROFILE {profile['ticks']} ticks, {tanks['green']}+{tanks['rust']} vehicles at the start, "
          f"{result['units_left']['green']}+{result['units_left']['rust']} at the end, speedup {result['speedup']}x")
    print(f"  whole tick (all _physics_process)   {profile['tick_ms']:7.3f} ms   (M1 budget: 5 ms at 60 vehicles, laptop)")
    for name, section in profile["sections"].items():
        indent = "    " if "/" in name else "  "
        print(f"{indent}{name:<36}{section['ms_per_tick']:7.3f} ms   {section['calls_per_tick']:7.2f} calls/tick")
    print(f"  unattributed (priority 0: brains)   {profile['unattributed_ms']:7.3f} ms")
    if len(sys.argv) > 2:
        with open(sys.argv[2], "w") as handle:
            json.dump({"profile": profile, "result": result}, handle, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())

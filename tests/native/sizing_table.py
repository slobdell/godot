#!/usr/bin/env python3
"""The controller band sized for the lead's decision (round 23, native; the orchestrator's ask): over n headless 50 v 50
matches with leaders, what share of the brains' per-vehicle work is the EXECUTE step (compute_command every tick: move +
avoid + weapon + unstick), what share is THINK (situation + decide + act, every 3-9 ticks), and how much of each is
engine calls that stay engine calls in any port (NavigationServer, physics rays). Reads `make native-sizing`'s logs:
BRAINS_PARTS lines (shares; the instrumentation inflates the absolutes) and SIM_PROFILE lines (the uninflated band).

    sizing_table.py build/native-sizing/*.log
"""
import json
import statistics
import sys

ENGINE = {"nav.closest": "execute", "nav.path": "execute", "nav.chord": None, "los.ray": "think", "los.ray_repeat": "think"}
EXECUTE_TOP = ["move", "weapon", "move.avoid", "avoid.solve", "avoid.refresh", "nav.chord", "nav.closest", "nav.path",
               "move.path", "move.guard", "steer.drive", "steer.station", "t.poll", "c.wall_contact", "c.reflexes"]
THINK_TOP = ["situation", "decide", "act", "s.cover_fire", "s.contacts", "s.tactics", "s.squad", "s.select", "s.allies",
             "s.cover_spots", "s.incoming", "los.cover", "los.cover_computed", "los.ray", "weapon.scan", "weapon.lanes"]


def main(paths):
    parts_runs, profile_runs = [], []
    for path in paths:
        parts = profile = result = None
        for line in open(path, errors="replace"):
            if line.startswith("BRAINS_PARTS "):
                head, body = line.split(": ", 1)
                parts = (int(head.split()[1]), json.loads(body))
            elif line.startswith("SIM_PROFILE "):
                profile = json.loads(line[len("SIM_PROFILE "):])
            elif line.startswith("MATCH_RESULT "):
                result = json.loads(line[len("MATCH_RESULT "):])
        if parts and "-parts" in path:
            parts_runs.append((path, parts, result))
        if profile and "-profile" in path:
            profile_runs.append((path, profile, result))
    if profile_runs:
        print("THE BAND, uninflated (SIM_PROFILE; ms a tick, whole match):")
        rows = []
        for path, profile, result in profile_runs:
            sections = profile["sections"]
            band = sections.get("segment:controllers", {}).get("ms_per_tick", float("nan"))
            elements = sections.get("segment:elements", {}).get("ms_per_tick", float("nan"))
            left = result["units_left"] if result else {"green": "?", "rust": "?"}
            rows.append((profile["tick_ms"], band, elements))
            print(f"  {path.split('/')[-1]:<14} tick {profile['tick_ms']:6.1f}  controllers {band:6.1f}  elements {elements:5.2f}  "
                  f"{profile['ticks']} ticks, {left['green']}+{left['rust']} left")
        for i, name in enumerate(["tick", "controllers", "elements"]):
            vals = [r[i] for r in rows]
            print(f"  {name:<12} mean {statistics.mean(vals):6.2f} ms  min {min(vals):6.2f}  max {max(vals):6.2f}  n = {len(vals)}")
    if parts_runs:
        print("\nTHE SHARES (BRAINS_PARTS; instrumented, so read shares and calls, not ms):")
        keys = sorted({k for _, (_, table), _ in parts_runs for k in table})
        means = {}
        for k in keys:
            us = [table.get(k, [0, 0])[0] * 1000.0 for _, (_, table), _ in parts_runs]
            calls = [table.get(k, [0, 0])[1] for _, (_, table), _ in parts_runs]
            means[k] = (statistics.mean(us), min(us), max(us), statistics.mean(calls))
        execute = means.get("execute", (0, 0, 0, 0))[0]
        think = means.get("think", (0, 0, 0, 0))[0]
        total = max(execute + think, 1e-9)
        engine_exec = sum(means.get(k, (0,))[0] for k in ("nav.closest", "nav.path"))
        engine_think = sum(means.get(k, (0,))[0] for k in ("los.ray",))
        print(f"  execute (compute_command every tick)  {execute:9.0f} us/tick  {100 * execute / total:5.1f} %  of which engine (nav.closest + nav.path) {engine_exec:7.0f} us = {100 * engine_exec / max(execute, 1):4.1f} % of execute")
        print(f"  think (situation + decide + act)      {think:9.0f} us/tick  {100 * think / total:5.1f} %  of which engine (los.ray)               {engine_think:7.0f} us = {100 * engine_think / max(think, 1):4.1f} % of think")
        print(f"  (n = {len(parts_runs)} runs; execute+think = {total:.0f} us/tick instrumented)")
        for label, names in (("execute parts", EXECUTE_TOP), ("think parts", THINK_TOP)):
            print(f"  {label}:")
            for k in names:
                if k in means:
                    m = means[k]
                    print(f"    {k:<22} {m[0]:9.0f} us/tick  (min {m[1]:7.0f} max {m[2]:7.0f})  {m[3]:7.2f} calls/tick  {m[0] / max(m[3], 1e-9):8.1f} us/call")
    if not parts_runs and not profile_runs:
        print("no BRAINS_PARTS or SIM_PROFILE lines in", paths, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

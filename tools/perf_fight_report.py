#!/usr/bin/env python3
"""`make perf-fight`'s table (round 22): one row per run (fight, arena, arm, seed), the run's frames pooled
(PerfScene `summary.run`: mean, p95, p99, the share over the locked-30 line, the sim's tick per tick and ticks per frame)
beside the `all` phases' mean UI and FX process time and GPU, the census start -> end; then each run's timeline by phase;
then, when the fights are P1's sizes (25, 50), the bar of C22.3: p95 at 50 <= p95 at 25 x 1.25, per arena.

    python3 tools/perf_fight_report.py build perf-fight

Names are <prefix>-<fight>-<arena>-<arm>-<seed>.json. Prints one PERF_FIGHT {json} line. Every number names its machine
(the summary's GPU) and commit (TANK_SQUAD_COMMIT on builder0, else git)."""
import glob
import json
import os
import re
import subprocess
import sys

BAR = 1.25


def commit():
    sha = os.environ.get("TANK_SQUAD_COMMIT", "")
    if not sha:
        try:
            sha = subprocess.run(["git", "rev-parse", "--short=8", "HEAD"], capture_output=True, text=True).stdout.strip()
        except OSError:
            sha = ""
    dirty = "+dirty" if os.environ.get("TANK_SQUAD_DIRTY") == "1" else ""
    return (sha or "unknown") + dirty


def parse_name(prefix, path):
    """(fight, arena, arm, seed) from a run file name, or None. Pure."""
    match = re.fullmatch(re.escape(prefix) + r"-(.+)-([a-z]+)-([a-z0-9_]+)-(\d+)\.json", os.path.basename(path))
    return match.groups() if match else None


def mean(values):
    values = [v for v in values if v is not None]
    return sum(values) / len(values) if values else 0.0


def run_row(summary, phases):
    """The numbers one run contributes. Pure."""
    run = summary.get("run") or {}
    alls = [p for p in phases if p.get("phase") == "all"]
    curve = summary.get("vehicles_curve") or [[0, 0]]
    return {
        "avg_ms": run.get("avg_ms"), "p95_ms": run.get("p95_ms"), "p99_ms": run.get("p99_ms"),
        "over34": run.get("over_cap_share"), "tick_ms": run.get("tick_script_ms"), "ticks_per_frame": run.get("ticks_per_frame"),
        "ui_ms": round(mean([p.get("process_game_ui_ms") for p in alls]), 2),
        "fx_ms": round(mean([p.get("process_fx_ms") for p in alls]), 2),
        "gpu_ms": round(mean([p.get("gpu_ms") for p in alls]), 2),
        "speed": round(mean([p.get("game_speed") for p in alls]), 2),
        "veh_start": curve[0][1], "veh_end": curve[-1][1], "frames": run.get("frames"),
        "seconds": round(sum(p.get("frames", 0) * p.get("avg_ms", 0.0) for p in alls) / 1000.0, 1),
    }


def bar_verdicts(rows):
    """{arena: {"p95_25", "p95_50", "ratio", "holds"}} from rows keyed (fight, arena, arm, seed) over the main arm. Pure."""
    result = {}
    for arena in sorted({key[1] for key in rows}):
        pooled = {}
        for size in ("25", "50"):
            values = [row["p95_ms"] for key, row in rows.items() if key[0] == size and key[1] == arena and key[2] == "main"]
            if values:
                pooled[size] = mean(values)
        if len(pooled) == 2 and pooled["25"] > 0:
            ratio = pooled["50"] / pooled["25"]
            result[arena] = {"p95_25": round(pooled["25"], 2), "p95_50": round(pooled["50"], 2), "ratio": round(ratio, 3),
                             "holds": ratio <= BAR}
    return result


def main(args):
    if len(args) != 2:
        print(__doc__)
        return 2
    build, prefix = args
    rows, timelines, machines, layer_costs = {}, {}, set(), {}
    for path in sorted(glob.glob(os.path.join(build, prefix + "-*.json"))):
        key = parse_name(prefix, path)
        if key is None:
            continue
        try:
            data = json.load(open(path))
        except (OSError, ValueError):
            continue
        summary, phases = data["summary"], data.get("phases", [])
        machines.add("%s %s" % (summary.get("gpu", "?"), summary.get("window", "")))
        rows[key] = run_row(summary, phases)
        rows[key]["preset"] = summary.get("flags", {}).get("render-preset", "")
        layer_costs[key] = {"ui": summary.get("layer_cost_ui_ms") or {}, "frame": summary.get("layer_cost_ms") or {},
                            "tick": summary.get("layer_cost_tick_ms") or {}}
        timelines[key] = [(p.get("t"), p.get("phase"), p.get("vehicles"), p.get("avg_ms"), p.get("p95_ms"),
                           p.get("tick_script_ms"), p.get("ticks_per_frame"), p.get("process_game_ui_ms"), p.get("gpu_ms"))
                          for p in phases]
    if not rows:
        print("perf_fight_report: no run files %s/%s-*.json" % (build, prefix))
        return 1
    sha = commit()
    print("commit %s | machine %s" % (sha, "; ".join(sorted(machines))))
    print("frame ms pooled over every `all` frame of the run; tick = the sim's script time per tick (C22.4: brains');")
    print("ui/fx = _process time a frame (ui: everything at default priority, the HUD and controls; fx: FxWorld)")
    print()
    cols = ["avg_ms", "p95_ms", "p99_ms", "over34", "tick_ms", "ticks_per_frame", "ui_ms", "fx_ms", "gpu_ms", "speed"]
    heads = ["avg", "p95", "p99", "over34", "tick", "t/f", "ui", "fx", "gpu", "speed"]
    print("%-10s %-8s %-18s %6s  %s  %9s %5s" % ("fight", "arena", "arm", "seed", " ".join("%7s" % h for h in heads), "vehicles", "s"))
    for key in sorted(rows):
        row = rows[key]
        cells = []
        for col in cols:
            value = row.get(col)
            cells.append("%7s" % ("—" if value is None else ("%.0f%%" % (value * 100) if col == "over34" else "%.2f" % value)))
        print("%-10s %-8s %-18s %6s  %s  %4d->%-4d %5.0f" % (key[0], key[1], key[2], key[3], " ".join(cells),
                                                       row["veh_start"], row["veh_end"], row["seconds"]))
    print()
    print("timeline per run (t phase vehicles avg p95 tick t/f ui gpu):")
    for key in sorted(timelines):
        print("  %s" % "-".join(key))
        for entry in timelines[key]:
            print("    %6s %-8s %3s %8s %8s %6s %5s %6s %6s" % tuple("—" if v is None else v for v in entry))
    for key in sorted(rows):
        costs = layer_costs.get(key) or {}
        if any(name.startswith("phys:") for name in costs.get("tick", {})):
            print()
            print("tick removal within %s (ms a tick; largest first):" % "-".join(key))
            phys = {n: v for n, v in costs["tick"].items() if n.startswith("phys:")}
            for layer in sorted(phys, key=lambda name: -phys[name])[:25]:
                print("  %-48s tick %+7.2f  frame %+7.2f" % (layer, phys[layer], costs["frame"].get(layer, 0.0)))
        if costs.get("ui"):
            print()
            print("removal within %s (the `all` phases either side minus the layer, ms a frame; largest ui first):" % "-".join(key))
            for layer in sorted(costs["ui"], key=lambda name: -costs["ui"][name])[:25]:
                print("  %-48s ui %+7.2f  frame %+7.2f  tick %+6.2f" % (layer, costs["ui"][layer],
                                                                        costs["frame"].get(layer, 0.0), costs["tick"].get(layer, 0.0)))
    verdicts = bar_verdicts(rows)
    if verdicts:
        print()
        print("C22.3 bar (p95 at 50 <= p95 at 25 x %.2f, the main arm, seeds pooled):" % BAR)
        for arena, verdict in verdicts.items():
            print("  %-8s p95 25: %.2f  p95 50: %.2f  ratio %.3f  %s" % (arena, verdict["p95_25"], verdict["p95_50"],
                                                                         verdict["ratio"], "HOLDS" if verdict["holds"] else "OVER"))
    print("PERF_FIGHT " + json.dumps({"commit": sha, "machines": sorted(machines),
                                      "runs": {"-".join(k): v for k, v in rows.items()}, "bar": verdicts},
                                     separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

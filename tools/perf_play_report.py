#!/usr/bin/env python3
"""`make perf-play`'s table (round 16, play P1): one row per run file, the frame split and the choppy share, then each
run's layer costs (removal within the run: perf_scene.gd `layer_costs`), then one `PERF_PLAY {json}` line.

    python3 tools/perf_play_report.py build/perf-play-92721.json build/perf-play-92721-capped.json ...

Missing files are skipped (an arm not run). Reads perf-scene's shape too (`summary.all` is absent there: it falls back to
the summary's own `all_*` fields)."""
import json
import os
import sys

COLUMNS = [("avg_ms", "avg"), ("p95_ms", "p95"), ("p99_ms", "p99"), ("over_cap_share", "over34"), ("game_speed", "speed"),
           ("tick_script_ms", "tick"), ("ticks_per_frame", "t/f"), ("gpu_ms", "gpu"), ("process_game_ui_ms", "ui"),
           ("process_fx_ms", "fx"), ("cpu_render_ms", "cpu_r"), ("draw_calls", "draws"), ("vehicles", "veh")]
LAYER_KEYS = [("layer_cost_ms", "frame"), ("layer_cost_tick_ms", "tick"), ("layer_cost_ui_ms", "ui"),
              ("layer_cost_gpu_ms", "gpu"), ("layer_cost_over_cap_share", "over34")]


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def row(name, summary):
    means = summary.get("all") or {"avg_ms": summary.get("all_avg_ms"), "p95_ms": summary.get("all_p95_ms"),
                                   "gpu_ms": summary.get("all_gpu_ms")}
    cells = []
    for key, _ in COLUMNS:
        value = means.get(key)
        cells.append("—" if value is None else ("%.0f%%" % (value * 100) if key == "over_cap_share" else
                                                "%.0f" % value if key in ("draw_calls", "vehicles") else "%.2f" % value))
    return name, cells, means


def main(paths):
    runs = []
    for path in paths:
        data = load(path)
        if data is None:
            continue
        runs.append((os.path.basename(path).removesuffix(".json"), data["summary"]))
    if not runs:
        print("perf_play_report: no run files")
        return 1
    width = max(len(name) for name, _ in runs)
    print("NOTE: a windowed match is NOT repeatable past ~tick 150 (round 16, render): two RUNS are two different fights.")
    print("      Within a run the layer costs are sound (each layer against the `all` phases either side); across runs,")
    print("      read the alive curves below, or use the `frozen` arm (--tune=match.no_damage=1) for a comparable census.")
    print()
    print("%-*s  %s" % (width, "run (all phases)", "  ".join("%7s" % label for _, label in COLUMNS)))
    record = {}
    for name, summary in runs:
        name, cells, means = row(name, summary)
        print("%-*s  %s" % (width, name, "  ".join("%7s" % c for c in cells)))
        record[name] = {"capped": summary.get("capped"), "frame_target": summary.get("frame_target"),
                        "window": summary.get("window"), "gpu": summary.get("gpu"), "all": means,
                        "holds_30fps_at_vehicles": summary.get("holds_30fps_at_vehicles"),
                        "layers": {label: summary.get(key, {}) for key, label in LAYER_KEYS}}
    print()
    print("layer costs (the `all` phases either side minus the layer, ms; over34 in share points):")
    for name, summary in runs:
        layers = sorted(set().union(*[summary.get(key, {}).keys() for key, _ in LAYER_KEYS]))
        for layer in layers:
            parts = []
            for key, label in LAYER_KEYS:
                value = summary.get(key, {}).get(layer)
                if value is not None:
                    parts.append("%s %+.2f" % (label, value * 100 if label == "over34" else value))
            print("  %-*s  %-12s %s" % (width, name, layer, "  ".join(parts)))
    print()
    print("vehicles alive by run time (s:count) and the run's recording:")
    for name, summary in runs:
        curve = " ".join("%.0f:%d" % (t, v) for t, v in summary.get("vehicles_curve", []))
        print("  %-*s  %s%s" % (width, name, curve or "(no curve: an older file)", "  [frozen]" if summary.get("no_damage") else ""))
        if summary.get("recording"):
            print("  %-*s  %s" % (width, "", summary["recording"]))
        record[name]["recording"] = summary.get("recording", "")
    print("PERF_PLAY " + json.dumps(record, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

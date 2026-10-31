#!/usr/bin/env python3
"""Round 47 (camera K1/K5): how far the camera looks from his selection.

Reads either a replay log of tests/camera/replay_camera.gd (CAMK lines, every 5 ticks) or one of his match recordings
(`cam` rows once a second, his `sel` rows, the `census` row nearest each cam row for where his units stood), and prints
one line:

  K1_GAP {"source", "n", "median_gap", "over30_pct", "median_dist", "far_selects", "frame_s_median", "frame_s_max",
          "never", "frame_s"}

  gap        metres from the camera's look point (the shown ground point) to his selection's centre
  over30_pct share of samples with the gap > 30 m
  far_selects selection changes whose new selection was > 20 m from the look point at the change
  frame_s    per far select, seconds until the gap first falls under 20 m ("never" if the next selection or the end came
             first; counted as never, not as a time)

    python3 tests/camera/k1_gap.py <replay.log | recording.jsonl> [--label=NAME] [--from-tick=T]
"""
import bisect
import json
import statistics
import sys

FAR_M = 20.0
OFF_M = 30.0
RATE = 30.0


def samples_from_log(path):
    rows = []
    for line in open(path):
        if line.startswith("CAMK "):
            rows.append(json.loads(line[5:]))
    return [(r["tick"], tuple(r["sel"]), r["gap"], r["dist"], r.get("mode", "")) for r in rows]


def samples_from_recording(path):
    rows = [json.loads(line) for line in open(path) if line.strip()]
    cams = [r for r in rows if r["t"] == "cam"]
    census = [r for r in rows if r["t"] == "census"]
    sels = [r for r in rows if r["t"] == "sel"]
    ticks = [c["tick"] for c in census]
    out = []
    for cam in cams:
        sel = None
        for s in sels:
            if s["tick"] <= cam["tick"]:
                sel = s
        if sel is None:
            continue
        row = census[max(0, bisect.bisect_right(ticks, cam["tick"]) - 1)]
        pts = [u["pos"] for u in row["units"] if u["n"] in sel["units"] and u.get("hp", 1) > 0]
        if not pts:
            continue
        cx = sum(p[0] for p in pts) / len(pts)
        cz = sum(p[1] for p in pts) / len(pts)
        gap = ((cam["target"][0] - cx) ** 2 + (cam["target"][1] - cz) ** 2) ** 0.5
        out.append((cam["tick"], tuple(sel["units"]), gap, cam["dist"], cam.get("mode", "")))
    return out


def measure(samples, label):
    gaps = [s[2] for s in samples]
    dists = [s[3] for s in samples]
    frames = []
    for i, s in enumerate(samples):
        if i > 0 and s[1] == samples[i - 1][1]:
            continue
        if s[2] <= FAR_M:
            continue
        took = None
        for later in samples[i:]:
            if later[1] != s[1]:
                break
            if later[2] < FAR_M:
                took = (later[0] - s[0]) / RATE
                break
        frames.append(took)
    timed = [f for f in frames if f is not None]
    return {
        "source": label,
        "n": len(samples),
        "median_gap": round(statistics.median(gaps), 1) if gaps else None,
        "over30_pct": round(100.0 * sum(g > OFF_M for g in gaps) / len(gaps), 1) if gaps else None,
        "median_dist": round(statistics.median(dists), 1) if dists else None,
        "far_selects": len(frames),
        "frame_s_median": round(statistics.median(timed), 2) if timed else None,
        "frame_s_max": round(max(timed), 2) if timed else None,
        "never": sum(f is None for f in frames),
        "frame_s": [round(f, 2) if f is not None else "never" for f in frames],
    }


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    label = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--label=")), args[0])
    until = next((int(a.split("=", 1)[1]) for a in sys.argv[1:] if a.startswith("--to-tick=")), None)
    path = args[0]
    samples = samples_from_recording(path) if path.endswith(".jsonl") else samples_from_log(path)
    if until is not None:
        samples = [s for s in samples if s[0] <= until]
    print("K1_GAP " + json.dumps(measure(samples, label)))


if __name__ == "__main__":
    main()

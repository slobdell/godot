"""perf P5 (round 26): R (the frame's work outside the simulation, ms a frame) paired by arena x seed between arms of a native-tick-profile session. Usage: r_paired.py DIR BASE ARM..."""
import json, glob, os, re, statistics, sys
d, base = sys.argv[1], sys.argv[2]
def load(arm):
    out = {}
    for p in glob.glob(os.path.join(d, f"tp-{arm}-*.log")):
        m = re.search(rf"tp-{arm}-\d+-(\w+)-main-(\d+)\.log", os.path.basename(p))
        for l in open(p, errors="replace"):
            if l.startswith("NATIVE_TICK_PROFILE "):
                r = json.loads(l[20:])
                tpf = r["ticks_per_frame"]; R = r["frame_wall_ms"] - tpf * (r["sim"]["tick_ms"] + r["engine_physics_step_ms"])
                out[(m.group(1), m.group(2))] = (R, r["frame_wall_ms"], tpf)
    return out
b = load(base)
for arm in sys.argv[3:]:
    a = load(arm); keys = sorted(set(a) & set(b))
    diffs = [a[k][0] - b[k][0] for k in keys]
    rel = [100 * (a[k][0] - b[k][0]) / b[k][0] for k in keys]
    se = statistics.stdev(diffs) / len(diffs) ** 0.5 if len(diffs) > 1 else float("nan")
    ser = statistics.stdev(rel) / len(rel) ** 0.5
    print("%-8s v %-8s R %.2f v %.2f ms a frame: %+.2f ms (se %.2f), %+.1f %% (se %.1f), n %d, outside 2 se: %s" % (arm, base,
        statistics.mean(a[k][0] for k in keys), statistics.mean(b[k][0] for k in keys), statistics.mean(diffs), se,
        statistics.mean(rel), ser, len(keys), abs(statistics.mean(diffs)) > 2 * se))

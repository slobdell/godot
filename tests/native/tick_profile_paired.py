"""Round 24 (native, N4): the in-contact price of one arm against a base arm, PAIRED by arena and seed (the rule in
_agents/native.md *The rules for a seam*): mean change of tick scripts (and controllers), its se, and game speed in the
window (C24.7: ticks a frame x 33.3 ms / frame ms). Usage: tick_profile_paired.py BUILD_DIR BASE ARM [ARM...]"""
import glob, json, math, re, statistics, sys

TICK_MS = 1000.0 / 30.0


def rows(build, arm):
    out = {}
    for path in glob.glob(f"{build}/tp-{arm}-*.log"):
        key = re.search(rf"tp-{arm}-(.*)\.log$", path).group(1)
        for line in open(path, errors="replace"):
            if line.startswith("NATIVE_TICK_PROFILE "):
                r = json.loads(line[len("NATIVE_TICK_PROFILE "):])
                s = r["sim"]["sections"]
                out[key] = {"tick": r["sim"]["tick_ms"], "ctrl": s["segment:controllers"]["ms_per_tick"],
                        "speed": r["ticks_per_frame"] * TICK_MS / r["frame_wall_ms"], "frame": r["frame_wall_ms"]}
    return out


build, base_arm, arms = sys.argv[1], sys.argv[2], sys.argv[3:]
base = rows(build, base_arm)
for arm in arms:
    other = rows(build, arm)
    keys = sorted(set(base) & set(other))
    for field in ("tick", "ctrl"):
        d = [100.0 * (other[k][field] - base[k][field]) / base[k][field] for k in keys]
        se = statistics.stdev(d) / math.sqrt(len(d)) if len(d) > 1 else float("nan")
        print(f"{arm} v {base_arm} {field}: {statistics.mean(d):+.2f} % (se {se:.2f}, n {len(d)}; outside 2 se: {abs(statistics.mean(d)) > 2 * se})")
    print(f"{arm}: game speed in the window {statistics.mean(other[k]['speed'] for k in keys):.3f} (base {statistics.mean(base[k]['speed'] for k in keys):.3f}), "
          f"tick scripts {statistics.mean(other[k]['tick'] for k in keys):.2f} v {statistics.mean(base[k]['tick'] for k in keys):.2f} ms")

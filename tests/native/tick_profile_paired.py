"""Round 24 (native, N4): the in-contact price of one arm against a base arm, PAIRED by arena and seed (the rule in
_agents/native.md *The rules for a seam*): mean change of tick scripts (and controllers), its se, and game speed in the
window (C24.7: ticks a frame x 33.3 ms / frame ms). Usage: tick_profile_paired.py BUILD_DIR BASE ARM [ARM...]

Round 25 (native, N5a): also the elements segment and priority 0's tank + match sections in ms (paired difference and
se: the void rule, lesson 282 -- a segment the arm cannot touch must not move with it), hulls alive at the window's
two ends (the window must hold the fight: on a water map contact can come later than on foundry), and the tick split
by arena (the water workload is two maps; a ruling reads the pooled line, the per-arena lines say where it came from).
Arms may differ in size (`NATIVE_TP_ARMS="s25@25= s20@20="`): runs pair by arena and seed, and game speed is also
printed as a paired difference with its se."""
import glob, json, math, re, statistics, sys

TICK_MS = 1000.0 / 30.0


def rows(build, arm):
    out = {}
    for path in glob.glob(f"{build}/tp-{arm}-*.log"):
        key = re.sub(r"^\d+-", "", re.search(rf"tp-{arm}-(.*)\.log$", path).group(1))  # <arena>-main-<seed>: size-free
        for line in open(path, errors="replace"):
            if line.startswith("NATIVE_TICK_PROFILE "):
                r = json.loads(line[len("NATIVE_TICK_PROFILE "):])
                s = r["sim"]["sections"]
                ms = lambda name: s.get(name, {}).get("ms_per_tick", 0.0)
                out[key] = {"tick": r["sim"]["tick_ms"], "ctrl": ms("segment:controllers"),
                        "elements": ms("segment:elements"), "prio0": ms("tank") + ms("match"),
                        "alive": r.get("alive", [0, 0]),
                        "speed": r["ticks_per_frame"] * TICK_MS / r["frame_wall_ms"], "frame": r["frame_wall_ms"]}
    return out


def arena_of(key):
    # keys look like <arena>-main-<seed>
    parts = key.split("-")
    return parts[0] if len(parts) >= 3 else "?"


def mean_se(d):
    se = statistics.stdev(d) / math.sqrt(len(d)) if len(d) > 1 else float("nan")
    return statistics.mean(d), se


build, base_arm, arms = sys.argv[1], sys.argv[2], sys.argv[3:]
base = rows(build, base_arm)
alive = sorted((k, v["alive"]) for k, v in base.items())
print(f"{base_arm}: hulls alive at the window's ends: " + ", ".join(f"{k} {a[0]}->{a[1]}" for k, a in alive))
for arm in arms:
    other = rows(build, arm)
    keys = sorted(set(base) & set(other))
    for field in ("tick", "ctrl"):
        d = [100.0 * (other[k][field] - base[k][field]) / base[k][field] for k in keys]
        m, se = mean_se(d)
        print(f"{arm} v {base_arm} {field}: {m:+.2f} % (se {se:.2f}, n {len(d)}; outside 2 se: {abs(m) > 2 * se})")
    d = [other[k]["speed"] - base[k]["speed"] for k in keys]
    m, se = mean_se(d)
    print(f"{arm} v {base_arm} game speed: {m:+.3f} (se {se:.3f}, n {len(d)})")
    for field in ("elements", "prio0"):
        d = [other[k][field] - base[k][field] for k in keys]
        m, se = mean_se(d)
        b = statistics.mean(base[k][field] for k in keys)
        print(f"{arm} v {base_arm} {field}: {m:+.3f} ms (se {se:.3f}, n {len(d)}), base {b:.2f} ms")
    for arena in sorted({arena_of(k) for k in keys}):
        ks = [k for k in keys if arena_of(k) == arena]
        d = [100.0 * (other[k]["tick"] - base[k]["tick"]) / base[k]["tick"] for k in ks]
        m, se = mean_se(d)
        print(f"   {arena}: tick {m:+.2f} % (se {se:.2f}, n {len(d)}), {statistics.mean(other[k]['tick'] for k in ks):.2f} v "
              f"{statistics.mean(base[k]['tick'] for k in ks):.2f} ms, speed {statistics.mean(other[k]['speed'] for k in ks):.3f} v "
              f"{statistics.mean(base[k]['speed'] for k in ks):.3f}")
    print(f"{arm}: game speed in the window {statistics.mean(other[k]['speed'] for k in keys):.3f} (base {statistics.mean(base[k]['speed'] for k in keys):.3f}), "
          f"tick scripts {statistics.mean(other[k]['tick'] for k in keys):.2f} v {statistics.mean(base[k]['tick'] for k in keys):.2f} ms")

#!/usr/bin/env python3
"""Round 30 (manoeuvre M4b, bar line b5): a rig's speed while it touches a wall, two arms paired by run.

Usage: brush_table.py BASE_DIR NEW_DIR  (each holds <squad>-<seed>.log from `make nav-terminus-drive` run with
--turn-log --turn-states: MANOEUVRE_STATE lines, one per crew per second).
Per run: the mean of the plant's speed `v` (|velocity.xz|, the reading round 29's (A) zeroed on every brush) over
every state line with `touch true`, and the count of such lines; the real speed (`real`, Tank.real_velocity) beside
it when the log has it. Paired difference of the per-run means, se, within 2 se. Report only (a first measurement).
"""
import pathlib
import re
import statistics
import sys

STATE = re.compile(r"MANOEUVRE_STATE f (\d+) (.+?) (\S+) order (\S*) from (\S*) v ([-\d.]+) moved ([-\d.]+) "
                   r"cmd ([-\d.]+)/([-\d.]+) .* touch (\S+) .* goal ([-\d.]+)(?: real ([-\d.]+))?")


def run_brush(log):
    speeds, reals = [], []
    for line in log.read_text(errors="replace").splitlines():
        m = STATE.search(line)
        if m and m.group(10) == "true":
            speeds.append(float(m.group(6)))
            if m.group(12) is not None:
                reals.append(float(m.group(12)))
    return {"n": len(speeds), "v": statistics.mean(speeds) if speeds else float("nan"),
            "real": statistics.mean(reals) if reals else float("nan")}


def load(root):
    return {p.stem: run_brush(p) for p in sorted(pathlib.Path(root).glob("*.log"))}


def main(base_dir, new_dir):
    base, new = load(base_dir), load(new_dir)
    keys = sorted(k for k in set(base) & set(new) if base[k]["n"] > 0 and new[k]["n"] > 0)
    print(f"BRUSH runs paired {len(keys)} (base {len(base)}, new {len(new)}; runs with no touching line dropped)")
    for k in keys:
        print(f"BRUSH {k}: base v {base[k]['v']:.2f} over {base[k]['n']} s, real {base[k]['real']:.2f} | new v {new[k]['v']:.2f} over {new[k]['n']} s, real {new[k]['real']:.2f}")
    if len(keys) > 1:
        d = [new[k]["v"] - base[k]["v"] for k in keys]
        mean, se = statistics.mean(d), statistics.stdev(d) / len(d) ** 0.5
        verdict = "within 2 se" if abs(mean) <= 2 * se else ("DOWN beyond 2 se" if mean < 0 else "UP beyond 2 se")
        print(f"BRUSH speed while touching, paired mean diff {mean:+.2f} m/s se {se:.2f} (n {len(d)}): {verdict}; "
              f"base mean {statistics.mean(base[k]['v'] for k in keys):.2f}, new {statistics.mean(new[k]['v'] for k in keys):.2f}")
        t = sum(base[k]["n"] for k in keys), sum(new[k]["n"] for k in keys)
        print(f"BRUSH touching crew-seconds: base {t[0]} new {t[1]}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

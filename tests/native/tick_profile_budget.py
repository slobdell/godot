"""Round 25 (native, stretch b): what is left between an arm's game speed in the window and C24.7's 0.97, by component.
Usage: tick_profile_budget.py BUILD_DIR ARM [TARGET]   (reads build/tp-<ARM>-*.log, NATIVE_TICK_PROFILE lines)

The model (sim_clock.gd: 30 Hz, max_physics_steps_per_frame = 3). A frame costs R + k * S wall ms: S = one tick's
simulation (the tick's scripts + the engine's physics step between two ticks), R = the frame's work outside the
simulation (render, _process, the HUD, audio), k = ticks run that frame (<= 3). Saturated (k at the cap, the slow
motion he sees) game speed = 3 * 33.33 / (R + 3 * S), so speed >= TARGET needs R + 3 S <= 100 / TARGET ms. R is read
as frame_wall - ticks_per_frame * S. The gap is printed two ways: all of it from S (ms a tick, and % of the tick's
scripts), or all of it from R (ms a frame); and S's sections with their share of the gap, largest first, so "port X"
or "think less" reads as a fraction of what is missing. Means over the arm's runs (arena x seed), with the spread.
The model holds only AT the cap: below it (round 25, 20 a side: 2.43 ticks a frame) slow frames still hit the cap and
lose time, and the model overstates (0.934 v 0.896 measured). Trust the measured speed there."""
import glob, json, statistics, sys

TICK_MS = 1000.0 / 30.0
CAP = 3

build, arm = sys.argv[1], sys.argv[2]
target = float(sys.argv[3]) if len(sys.argv) > 3 else 0.97
runs = []
for path in sorted(glob.glob(f"{build}/tp-{arm}-*.log")):
    for line in open(path, errors="replace"):
        if line.startswith("NATIVE_TICK_PROFILE "):
            runs.append(json.loads(line[len("NATIVE_TICK_PROFILE "):]))
if not runs:
    sys.exit(f"no NATIVE_TICK_PROFILE lines in {build}/tp-{arm}-*.log")


def mean(f):
    return statistics.mean(f(r) for r in runs)


def sd(f):
    return statistics.stdev(f(r) for r in runs) if len(runs) > 1 else 0.0


scripts = mean(lambda r: r["sim"]["tick_ms"])
step = mean(lambda r: r["engine_physics_step_ms"])
S = scripts + step
frame = mean(lambda r: r["frame_wall_ms"])
tpf = mean(lambda r: r["ticks_per_frame"])
R = frame - tpf * S
speed = mean(lambda r: r["ticks_per_frame"] * TICK_MS / r["frame_wall_ms"])
budget = CAP * TICK_MS / target
model = CAP * TICK_MS / (R + CAP * S)
gap_s = max(0.0, (R + CAP * S - budget) / CAP)
print(f"{arm}: {len(runs)} runs; game speed in the window {speed:.3f} (sd {sd(lambda r: r['ticks_per_frame'] * TICK_MS / r['frame_wall_ms']):.3f}); "
      f"saturated model {model:.3f}")
print(f"  a tick S = {S:.2f} ms (scripts {scripts:.2f}, sd {sd(lambda r: r['sim']['tick_ms']):.2f}; engine step {step:.2f}); "
      f"outside the sim R = {R:.1f} ms a frame; {tpf:.2f} ticks a frame, frame {frame:.1f} ms")
print(f"  {target}: R + 3 S <= {budget:.1f} ms; now {R + CAP * S:.1f}. Gap: {gap_s:.2f} ms a tick ({100 * gap_s / scripts:.1f} % of the "
      f"scripts), or {CAP * gap_s:.1f} ms a frame from R alone")
sections = {}
for r in runs:
    for name, v in r["sim"]["sections"].items():
        sections.setdefault(name, []).append(v["ms_per_tick"])
top = ["segment:controllers", "segment:elements", "tank", "match", "visfield", "shell", "segment:order_executor+commanders"]
print("  the tick by segment (ms, share of the scripts, share of the gap if it went to zero):")
for name in top:
    if name in sections:
        m = statistics.mean(sections[name])
        print(f"    {name:36s} {m:6.2f}  {100 * m / scripts:5.1f} %  {100 * m / gap_s if gap_s else 0:6.0f} % of the gap")
print("  brains' largest parts (brain/*, nested: think > situation > s.contacts ...):")
for name, vals in sorted(((n, v) for n, v in sections.items() if n.startswith("brain/")), key=lambda kv: -statistics.mean(kv[1]))[:14]:
    m = statistics.mean(vals)
    print(f"    {name:36s} {m:6.2f}  {100 * m / scripts:5.1f} %")

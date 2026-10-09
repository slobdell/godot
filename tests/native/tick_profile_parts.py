"""Round 24 (native, N4): every SimProfile section of NATIVE_TICK_PROFILE lines, mean ms a tick over the logs given,
sorted, so a port is chosen by where the tick actually goes. Usage: tick_profile_parts.py LOG... [--top N]"""
import json, statistics, sys

args = [a for a in sys.argv[1:] if not a.startswith("--top")]
top = int(next((a.split("=")[1] for a in sys.argv[1:] if a.startswith("--top=")), "60"))
rows = []
for path in args:
    for line in open(path, errors="replace"):
        if line.startswith("NATIVE_TICK_PROFILE "):
            rows.append(json.loads(line[len("NATIVE_TICK_PROFILE "):]))
if not rows:
    sys.exit("tick_profile_parts: no NATIVE_TICK_PROFILE line in " + " ".join(args))
keys = sorted({k for r in rows for k in r["sim"]["sections"]})
mean = {k: statistics.mean(r["sim"]["sections"].get(k, {}).get("ms_per_tick", 0.0) for r in rows) for k in keys}
print("n=%d, tick scripts %.2f ms, alive %s" % (len(rows), statistics.mean(r["sim"]["tick_ms"] for r in rows),
        [statistics.mean(r["alive"][i] for r in rows) for i in (0, 1)]))
for k in sorted(keys, key=lambda k: -mean[k])[:top]:
    print("%-40s %7.3f" % (k, mean[k]))

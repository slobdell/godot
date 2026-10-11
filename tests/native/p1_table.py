"""perf P1 (round 26): the in-contact tick in buckets (share of tick scripts) from native-tp-headless logs. Usage: p1_table.py DIR... (one DIR per arena x size, holding tph-*.log)"""
import json, statistics, sys, glob, os
B = [  # (label, sections summed)
 ("tick scripts", None),
 ("controllers", ["segment:controllers"]),
 (" think", ["brain/think"]),
 ("  gate: t.poll", ["brain/t.poll"]),
 ("  gate: t.rate_progress", ["brain/t.rate_progress"]),
 ("  gate: t.incoming", ["brain/t.incoming"]),
 ("  situation", ["brain/situation"]),
 ("   s.contacts (native)", ["brain/s.contacts"]),
 ("   s.tactics", ["brain/s.tactics"]),
 ("   s.squad", ["brain/s.squad"]),
 ("   s.cover_spots", ["brain/s.cover_spots"]),
 ("   s.cover_fire", ["brain/s.cover_fire"]),
 ("   s.incoming", ["brain/s.incoming"]),
 ("  decide (native)", ["brain/decide"]),
 ("  act", ["brain/act"]),
 ("   act.prelude", ["brain/act.prelude"]),
 (" execute", ["brain/execute"]),
 ("  move", ["brain/move"]),
 ("   m.native_drive", ["brain/m.native_drive"]),
 ("  weapon", ["brain/weapon"]),
 ("   weapon.scan", ["brain/weapon.scan"]),
 ("   weapon.aim", ["brain/weapon.aim"]),
 ("   weapon.lanes", ["brain/weapon.lanes"]),
 (" c.wall_contact", ["brain/c.wall_contact"]),
 ("engine-call laps: los.ray+nav.path+nav.is_ready", ["brain/los.ray", "brain/nav.path", "brain/nav.is_ready"]),
 ("elements", ["segment:elements"]),
 ("tank", ["tank"]),
 ("match", ["match"]),
 ("engine physics step", "engine_physics_step_ms"),
]
cols = []
for d in sys.argv[1:]:
    rows = []
    for p in glob.glob(os.path.join(d, "tph-*.log")):
        for line in open(p, errors="replace"):
            if line.startswith("NATIVE_TICK_PROFILE "):
                rows.append(json.loads(line[len("NATIVE_TICK_PROFILE "):]))
    if not rows:
        continue
    vals = {}
    for label, secs in B:
        if secs is None:
            v = [r["sim"]["tick_ms"] for r in rows]
        elif isinstance(secs, str):
            v = [r.get(secs, 0.0) for r in rows]
        else:
            v = [sum(r["sim"]["sections"].get(s, {}).get("ms_per_tick", 0.0) for s in secs) for r in rows]
        vals[label] = statistics.mean(v)
    alive = [statistics.mean(r["alive"][i] for r in rows) for i in (0, 1)]
    cols.append((os.path.basename(d.rstrip("/")), len(rows), alive, vals))
print("%-48s" % "ms a tick (share of tick scripts)" + "".join("%20s" % c[0] for c in cols))
print("%-48s" % "n, alive at window end" + "".join("%20s" % ("n=%d %.0f/%.0f" % (c[1], c[2][0], c[2][1])) for c in cols))
for label, _ in B:
    print("%-48s" % label + "".join("%12.2f (%4.1f%%)" % (c[3][label], 100 * c[3][label] / c[3]["tick scripts"]) for c in cols))

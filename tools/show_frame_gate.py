#!/usr/bin/env python3
"""S6: a frame of the arena that contains no fight cannot answer the questions we shoot frames for.

Every frame the show tools produce is shot for one of two reasons -- *how does the venue look* and *does the venue
out-read the fight* -- and both of them need the fight to be in the picture. On 2026-09-20 it was not: the frame
tools never passed `--budget`, so the runs fielded 950 points (FIVE units a side) instead of the ~30 the lead
plays, and a 3-second warmup left those five still on their spawn line ~86 m from the camera. Every frame this
stream shot before midday framed an empty control ring, and the readability gate's "fight ring" window was
measuring bare asphalt.

**And the first version of `vehicles_in_frame` was itself wrong**: it counted positions inside the camera frustum,
and reported 19 for a frame containing no hull at all. The frustum is a cone 1200 m deep, so a vehicle 90 m away
on the far side of the map counted the same as one filling a third of the picture. It now projects each tank's
DRAWN meshes and requires a minimum on-screen height -- a frustum count is a statement about geometry, and the
question is about pixels.

This also checks `SHOW_LOOK_CONTACT`: the armies must actually have met. A wall-clock warm-up does not achieve
that on a machine that presents a vsync'd window at ~1/10 real time (remote_builds.md:126) -- 20 s of timer bought
about 2 s of match, and both sides were still on their spawn lines.
"""
import glob
import json
import os
import sys

out_dir = sys.argv[1] if len(sys.argv) > 1 else "build/show"
rows = []
for log in sorted(glob.glob(os.path.join(out_dir, "**", "*.log"), recursive=True)):
    if os.sep + "clips" + os.sep in log:
        continue
    for line in open(log, errors="ignore"):
        if line.startswith("SHOW_LOOK {"):
            rows.append(json.loads(line.split(" ", 1)[1]))

if not rows:
    print("show-frames: no SHOW_LOOK rows under %s" % out_dir)
    sys.exit(1)

contact = []
for log in sorted(glob.glob(os.path.join(out_dir, "**", "*.log"), recursive=True)):
    for line in open(log, errors="ignore"):
        if line.startswith("SHOW_LOOK_CONTACT "):
            contact.append(json.loads(line.split(" ", 1)[1]))
for c in contact:
    print("show-frames: waited %.1f s wall for contact; closest opposing pair %.1f m (bar %.0f m) -> %s"
          % (c["waited_wall_s"], c["closest_gap_m"], c["bar_m"], "ENGAGED" if c["engaged"] else "NOT ENGAGED"))
never = [c for c in contact if not c["engaged"]]

missing = [r for r in rows if not r.get("vehicles_in_frame")]
counts = sorted(r.get("vehicles_in_frame", 0) for r in rows)
print("show-frames: %d frames, vehicles in frame: min %d, median %d, max %d"
      % (len(rows), counts[0], counts[len(counts) // 2], counts[-1]))
if never:
    print("show-frames: FAILED -- %d run(s) hit the wall-clock cap without the armies meeting." % len(never))
    print("             The frames show two sides walking towards each other, not a fight.")
    sys.exit(1)
if missing:
    print("show-frames: FAILED -- %d of %d frames contain NO vehicles:" % (len(missing), len(rows)))
    for r in missing[:8]:
        print("             %s" % r.get("file", "?"))
    print("             A frame with no fight in it cannot show how the venue looks against the fight, and the")
    print("             readability gate's ring window is measuring bare ground. Check --budget and the warmup.")
    sys.exit(1)

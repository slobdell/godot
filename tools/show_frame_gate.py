#!/usr/bin/env python3
"""S6: a frame of the arena that contains no fight cannot answer the questions we shoot frames for.

Every frame the show tools produce is shot for one of two reasons -- *how does the venue look* and *does the venue
out-read the fight* -- and both of them need the fight to be in the picture. On 2026-09-20 it was not: the frame
tools never passed `--budget`, so the runs fielded 950 points (FIVE units a side) instead of the ~30 the lead
plays, and a 3-second warmup left those five still on their spawn line ~86 m from the camera. Every frame this
stream shot before midday framed an empty control ring, and the readability gate's "fight ring" window was
measuring bare asphalt.

`vehicles_in_frame` is now printed with every capture, and this refuses a set where the frames are empty.
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

missing = [r for r in rows if not r.get("vehicles_in_frame")]
counts = sorted(r.get("vehicles_in_frame", 0) for r in rows)
print("show-frames: %d frames, vehicles in frame: min %d, median %d, max %d"
      % (len(rows), counts[0], counts[len(counts) // 2], counts[-1]))
if missing:
    print("show-frames: FAILED -- %d of %d frames contain NO vehicles:" % (len(missing), len(rows)))
    for r in missing[:8]:
        print("             %s" % r.get("file", "?"))
    print("             A frame with no fight in it cannot show how the venue looks against the fight, and the")
    print("             readability gate's ring window is measuring bare ground. Check --budget and the warmup.")
    sys.exit(1)

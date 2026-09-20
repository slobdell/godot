#!/usr/bin/env python3
"""S6: the arena light show must not make the fight harder to read than it already was.

`art_direction.md:72` requires the arena be "lit well enough to read the fight". feel's review of the first strip
(2026-09-20) found the hierarchy inverted -- the brightest pixels were the building edges and the darkest were the
arena floor and the vehicles -- so this became a gate rather than a note.

**It is a DELTA gate, and the BEFORE arm is why.** The first version compared the fight ring's mean luminance to
the block band's and failed when the band won. Run against three arms of the same arena, seed and pose, it failed
22 of 30 frames IN THE BEFORE ARM -- the branch point, with no show in it at all. At the lead's 21 degree pose over
dark asphalt, the top of the frame is simply brighter than the middle, and an absolute gate measures the venue
rather than the light show. So the bar is: **the show must not make the ring/band ratio meaningfully worse than the
same frame with the show off.**

**And the two halves are shot in ONE process, on the SAME paused scene**, by toggling `Show.driving`. They were
two separate runs first, and that was wrong for the same reason the paired perf runs were wrong: these frames ride
a LIVE skirmish, so across two processes the vehicles are somewhere else and the ring's luminance moves several
percent for reasons that have nothing to do with the light show. Measured that way the same frames swung by up to
5 points between two runs of one commit. Toggling on a frozen scene makes the pair differ in the show and in
nothing else.

`<dir>/outline` is the variant: a look to compare rather than a control, and not gated.
"""
import collections
import glob
import json
import os
import sys

# Frame-to-frame render noise in the measured ratio is about +-1.5%; 3% is comfortably outside it and still
# catches anything a person would see.
TOLERANCE_PCT = 3.0

out_dir = sys.argv[1] if len(sys.argv) > 1 else "build/show"
rows = []
for log in sorted(glob.glob(os.path.join(out_dir, "*.log"))):
    for line in open(log, errors="ignore"):
        if line.startswith("SHOW_LOOK {"):
            rows.append(json.loads(line.split(" ", 1)[1]))

if not rows:
    print("show-luma: no SHOW_LOOK rows under %s" % out_dir)
    sys.exit(1)


failed, compared, before_loses = [], 0, 0
print("%-38s %9s %9s   %s" % ("frame", "show off", "show on", "on vs off, same frozen frame"))
for r in sorted(rows, key=lambda r: (r["arena"], r["pose"], r["label"])):
    if not r.get("luma_band_before"):
        continue  # the outline variant's own process: a look to compare, not a control
    compared += 1
    before_loses += 0 if r["luma_ring_before"] >= r["luma_band_before"] else 1
    b = r["luma_ring_before"] / max(r["luma_band_before"], 1e-6)
    d = r["luma_ring"] / max(r["luma_band"], 1e-6)
    delta = (d - b) / b * 100.0
    key = (r["arena"], r["pose"], r["label"])
    if delta < -TOLERANCE_PCT:
        failed.append((key, delta))
    print("%-38s %9.3f %9.3f   %+6.1f%%%s"
          % ("/".join(key), b, d, delta, "  <-- WORSE" if delta < -TOLERANCE_PCT else ""))

print()
print("show-luma: %d frames compared. The BEFORE arm -- no show at all -- already loses ring<band in %d of them,"
      % (compared, before_loses))
print("           which is why this gate is a delta and not an absolute: that is the venue, not the show.")
if failed:
    print("show-luma: FAILED -- the show makes the fight harder to read in %d frames (worse than %.0f%%):"
          % (len(failed), TOLERANCE_PCT))
    for key, delta in failed:
        print("           %-38s %+6.1f%%" % ("/".join(key), delta))
    print("           Lower show_edge_energy, or the channel's ceiling in the arena's patch.")
    sys.exit(1)
print("show-luma: ok -- no frame is more than %.0f%% worse than the branch point." % TOLERANCE_PCT)

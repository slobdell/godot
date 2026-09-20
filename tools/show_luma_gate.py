#!/usr/bin/env python3
"""S6: the arena light show must never out-read the fight.

`art_direction.md:72` requires the arena be "lit well enough to read the fight"; feel's review of the first strip
(2026-09-20) found the hierarchy inverted -- the brightest pixels in the frame were the building edges and the
darkest were the arena floor and the vehicles. That is a play problem, not a taste one, so it is a gate.

Reads the SHOW_LOOK lines `make show-frames` wrote and fails if the block band beats the fight ring in any frame of
the DEFAULT style. The `outline` variant is exempt and reported: it exists to be compared, not to ship.
"""
import glob
import json
import os
import sys

out_dir = sys.argv[1] if len(sys.argv) > 1 else "build/show"
rows = []
for log in sorted(glob.glob(os.path.join(out_dir, "*.log"))):
    with open(log, errors="ignore") as handle:
        for line in handle:
            if line.startswith("SHOW_LOOK {"):
                rows.append(json.loads(line.split(" ", 1)[1]))

if not rows:
    print("show-luma: no SHOW_LOOK rows in %s" % out_dir)
    sys.exit(1)

failed = [r for r in rows if not r["ring_wins"] and r.get("style", "") in ("", "parapet")]
exempt = [r for r in rows if not r["ring_wins"] and r.get("style", "") == "outline"]

for r in sorted(rows, key=lambda r: (r["arena"], r["pose"], r["label"])):
    mark = "ok " if r["ring_wins"] else "BAND"
    print("show-luma %s %-42s ring %.4f  band %.4f  %s" % (mark, r["file"], r["luma_ring"], r["luma_band"], r.get("style", "")))

print("show-luma: %d frames, %d failed, %d exempt (outline variant)" % (len(rows), len(failed), len(exempt)))
if failed:
    print("show-luma: FAILED -- the block band out-reads the fight ring in %d default-style frames." % len(failed))
    print("           The venue is competing with the game. Lower show_edge_energy or the channel's ceiling.")
    sys.exit(1)

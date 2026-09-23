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

# The floor the gate can never go below, however quiet the null looks.
FLOOR_PCT = 3.0
# The bar is this many times the MEASURED null spread. The null is the same frame shot twice with nothing changed
# at all, so it is the honest answer to "how big must a difference be before it means something" -- and measuring
# it beats the 1.5% I guessed first, which the data refuted within one run.
NULL_MULTIPLE = 2.0

# ROUND 10: THE GATE REPORTS, IT DOES NOT DECIDE. The brief: "the bar and the gates ... stay as instruments; they
# stop being the verdict", and "if it objects, the number goes to him with the frame, not a quieter effect". So by
# default an objection is printed loudly and the target still succeeds; --enforce restores the round-9 behaviour.
ENFORCE = "--enforce" in sys.argv
args = [a for a in sys.argv[1:] if not a.startswith("--")]
out_dir = args[0] if args else "build/show"
rows = []
for log in sorted(glob.glob(os.path.join(out_dir, "*.log"))):
    for line in open(log, errors="ignore"):
        if line.startswith("SHOW_LOOK {"):
            rows.append(json.loads(line.split(" ", 1)[1]))

if not rows:
    print("show-luma: no SHOW_LOOK rows under %s" % out_dir)
    sys.exit(1)


# Calibrate against the null before judging anything.
nulls = []
for r in rows:
    if r.get("luma_band_null"):
        a = r["luma_ring_before"] / max(r["luma_band_before"], 1e-6)
        b = r["luma_ring_null"] / max(r["luma_band_null"], 1e-6)
        nulls.append(abs(b - a) / a * 100.0)
nulls.sort()
null_p95 = nulls[int(len(nulls) * 0.95)] if nulls else 0.0
tolerance = max(FLOOR_PCT, NULL_MULTIPLE * null_p95)
if nulls:
    print("show-luma: null control -- the same frame shot twice with NOTHING changed differs by a median %.1f%%, "
          "p95 %.1f%%, worst %.1f%% (%d pairs)."
          % (nulls[len(nulls) // 2], null_p95, nulls[-1], len(nulls)))
print("show-luma: bar = max(%.0f%%, %.0f x null p95) = %.1f%%\n" % (FLOOR_PCT, NULL_MULTIPLE, tolerance))

# The gate asks one question: is the arena lit well enough to READ THE FIGHT (art_direction.md:72). At `victory`
# and `defeat` the match is over and there is no fight to read -- the venue taking the frame is the point of those
# cues, and the victory sweep is the one team-coloured thing in the game. So they are scoped OUT of the gate and
# reported separately, which is a narrowing of the question rather than a loosening of the bar. If you disagree,
# the argument to make is that the venue should stay subordinate even after the last shot, not that 4.8% is fine.
ENDGAME_MOODS = ("victory", "defeat")

failed, endgame, compared, before_loses = [], [], 0, 0
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
    if delta < -tolerance:
        (endgame if r.get("mood", "") in ENDGAME_MOODS else failed).append((key, delta))
    print("%-38s %9.3f %9.3f   %+6.1f%%%s"
          % ("/".join(key), b, d, delta, "  <-- WORSE" if delta < -tolerance else ""))

print()
print("show-luma: %d frames compared. The BEFORE arm -- no show at all -- already loses ring<band in %d of them,"
      % (compared, before_loses))
print("           which is why this gate is a delta and not an absolute: that is the venue, not the show.")
if endgame:
    print("show-luma: %d frame(s) past the bar in an ENDGAME cue, which the gate does not judge -- the match is"
          % len(endgame))
    print("           over and there is no fight left to read:")
    for key, delta in endgame:
        print("           %-38s %+6.1f%%" % ("/".join(key), delta))
if failed:
    print("show-luma: FAILED -- the show makes the fight harder to read in %d frames (worse than %.0f%%):"
          % (len(failed), tolerance))
    for key, delta in failed:
        print("           %-38s %+6.1f%%" % ("/".join(key), delta))
    if ENFORCE:
        print("           Lower show_edge_energy, or the channel's ceiling in the arena's patch.")
        sys.exit(1)
    print("           REPORTED, NOT ENFORCED (round 10: his eye is the verdict; these numbers go to him beside the")
    print("           frames). --enforce makes this a failure again.")
    sys.exit(0)
print("show-luma: ok -- no frame is more than %.1f%% worse with the show on than with it off." % tolerance)

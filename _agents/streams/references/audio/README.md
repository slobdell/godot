# Audio measurements: what they were taken on

## Every `make remote T=audio-pass` before `3d38ab26` recorded a slow-motion match

Found by feel, round 6 (2026-09-18). On builder0 the game window sits on an idle desktop, and a vsync'd window there
presents at a crawl: the simulation ran at about **1/10 of wall time** while the recording ran in real time.

| Run (builder0, 30 a side, yard, seed 3) | Match time per wall time |
|---|---|
| default (vsync on), unmuted, 90 s | 8.2 s of match in 90 s |
| default (vsync on), `--mute`, 30 s | 3.1 s in 30 s (so not the audio) |
| `--disable-vsync`, `--mute`, 30 s | 25.6 s in 30 s |

`audio-pass` now passes `--disable-vsync` by default (`PASS_GODOT_FLAGS`, `mk/audio.mk`); FrameTarget's frame cap
still paces the game.

**What still holds from earlier passes** (round 5's X6 in `../../archive/round5/audio.md`, round 6's first X3
readings): loudness, true peak and clipping describe exactly what was recorded. **What does not:** anything about
how *dense* the battle was — how often impacts land, how the impact ducking overlaps itself, how often music layers
change. Round 5 noted "game time runs ~10x slower than wall time" and left the cause open; this is the cause.
The laptop was never affected: it has a live display.

## Generating announcer clips from a worktree (feel, round 8) — two traps, one of which cost 18 masters

`assets/announcer/masters/` is git-ignored, so **a worktree has none**. Two consequences, both found the hard way:

1. **A dry run from a worktree reports every request unrecorded.** `make announcer-generate ONLY=<ids>` printed
   "144 requests, ~17,018 credits" where the real job was 18 requests and ~2,125: it could not see the seven arenas
   already recorded. An approved run from there would have re-bought them all, 8x over. **Read the REQUEST COUNT, not
   the credit estimate** ("Already recorded (skipped on a real run): N requests"), and copy the masters in first:
   `cp -r --update=none ~/projects/godot/assets/announcer/masters assets/announcer/`.
2. **Copy the NEW masters back before deleting the copy.** The generator writes each new master beside the old ones.
   Deleting `assets/announcer/masters` after a run (194 MB the remote sync would carry every time) deleted the 18
   Terminus masters with it. The clips shipped and are verified, so nothing is broken today, but those 18 cannot be
   re-cut if the cutting or normalisation changes: that would need re-recording (~1,630 credits). The order is
   **copy in → generate → `cp -r --update=none assets/announcer/masters ~/projects/godot/assets/announcer/` → delete**.

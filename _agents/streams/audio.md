# Stream: audio, round 13 (the garage, smoke-tested like a player, then given music)

> Read [`game_design.md`](../game_design.md) *Round 13 direction* (his answer 6, verbatim), the archived round-12 brief
> `archive/round12/audio.md` and its Status (the director's per-state draw, the manifest, the `garage` state that
> nothing plays), and `assets/music/PROMPTS.md`. **You own** round 12's audio paths (`game/audio/`, `assets/music/`,
> `tools/audio/`, `mk/audio.mk`, `tests/audio/`, the announcer paths) **plus a carve-out this round:** `game/garage/**`,
> `game/modes/garage_mode.gd` and the garage targets in `mk/garage.mk` — for the smoke test and the music hook ONLY. The
> garage stream is paused; a garage feature or fix bigger than an hour is written up as a round-14 item, not built.

## The lead's direction (2026-09-27)

> *"6. Yes let's add garage music, but I've never even smoke tested the garage."*

And answer 5: *"29 MB of music is fine"* (the web pack question is closed; add what the garage needs).

## Where things stand (verify)

- `MusicDirector.STATES` includes `garage`; the manifest has a `garage`/`victory` pool of 4 (round 12); **nothing in
  `game/` asks the director for the `garage` state** (round 12's finding: the same shape as `pre_match` before it was
  fixed). `game/modes/garage_mode.gd` is the mode; `make garage`, `garage-smoke` (headless: open, FIGHT, the skirmish
  starts with the saved army, no errors), `garage-shots`, `garage-e2e`, `garage-web-smoke` exist and are in `check`'s
  garage smoke — **headless**. He has never played it: the title → GARAGE → build → FIGHT path with a display, at his
  aspect, is the gap.

## Backlog (in order)

**G1. The garage as a player sees it.** From the title, on the default path, with a display (builder0's, `make remote`):
GARAGE → build an army (tap/drag, the budget, a preset, an army code) → FIGHT → the match → results → REMATCH/ARMY.
Frames at desktop 1920×1080 and the 20:9 phone aspect (`garage-shots` is the start; extend it to the whole loop).
**Look at every frame** and list what is wrong in Status, in his words' register (what a player would say), with the
frame beside each: broken layout, a button that does nothing, text that overflows, a stale unit (the catalogue stub
`catalog_stub.gd` hardcodes pre-CP2 boxes — does the garage show the right vehicles at all?). Fix what is an hour's work
inside the carve-out; the rest is the round-14 garage list.

**G2. Garage music.** The garage mode asks the director for `garage` on enter and hands back on leaving (to `pre_match`
via the title, or straight to the match: which state the FIGHT hand-off lands in must be stated and tested); the pool
rotates like every other state (least recently heard first; the test from round 12's M1 extended to `garage`).
`music-smoke` and `audio-launch-smoke` extended to cover entering the garage. `make music-check` on anything imported;
`assets/music/PROMPTS.md` updated. If the four-track pool shares with `victory`, decide whether the garage wants its own
mood (his tracks: `Factory Silence`, `Neon Outrun` are candidates by title) and say why.

**G3 (stretch).** The two placements made by title (`defeat_hunt`, `defeat_ragnarok`): listen if you can; otherwise
leave the note for him.

## How to verify

`make remote T=check` (the garage smokes are in it); `make remote T=garage-shots` and your loop frames; `music-smoke`
and `announcer-record-smoke` matching their no-audio controls; the sim baseline `6313a38d7ecd99bb` pre-registered
UNMOVED (the garage is outside the match).

## Don't touch

`game/tactics/**`, `game/ai/**`, `game/theme/**`, `game/control/**`, `game/match/**`.

## Waiting on the lead

Nothing. The frames and the round-14 garage list go into Status for him.

## Status

_(the worker keeps this current)_

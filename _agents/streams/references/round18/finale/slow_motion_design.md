# Slow motion is half a simulation: two fixes, designed, not built (finale stretch a, round 18)

`roadmap.md` *Round 18 candidates* item 5. Written 2026-10-04 at `258d1f78`; nothing here is built (both fixes move
hashes or the kill cam's length, which is his call). Read with `determinism.md` (the kill cam's rule) and
`game/theme/fx/kill_cam.gd`'s header.

## The defect, precisely

Godot runs physics ticks at `physics_ticks_per_second` per REAL second and hands each tick
`physics_step × Engine.time_scale` as its delta. So under `time_scale = 0.2`:

- anything integrated from `delta` (motion, Jolt, `sim_seconds`, timers in seconds) runs at 0.2×;
- anything counted in TICKS (reload ticks, the brains' think cadence, intel every N ticks, the kill cam's own
  HOLD_TICKS) runs at full rate.

The two halves of the simulation disagree on how fast time passes. After a decided match (the kill cam) it is harmless
and deterministic since round 17 (the schedule counts ticks). In a LIVE match under tactics' `--slow-motion=<f>`
(`game/tactics/tactics_flags.gd:62`) it is a different game: a gun reloads five times faster relative to the motion,
brains think five times as often per metre driven. `Match` already warns on a live tick at `time_scale ≠ 1`
(`match.gd:400`).

## Fix A (recommended): slow motion slows the TICK RATE, every tick stays a full tick

Set, together, `Engine.physics_ticks_per_second = 30 × f` and `Engine.time_scale = f`. Godot then runs `30 f` ticks a
real second, each handed `(1 / (30 f)) × f = 1/30` s. **Every tick is the same tick it is at full speed**; there are
just fewer of them per real second, and physics interpolation draws between them. Both halves agree because the
simulation no longer sees the scale at all.

- **What it buys:** slow motion becomes pure presentation. The hash at tick N is the hash at tick N whatever the scale,
  so the kill cam's schedule could go back to wall time with no fork risk (the round-17 Sumps fork was the schedule
  changing which ticks ran scaled; under A no tick is ever scaled), and `--slow-motion=` becomes a faithful viewer.
- **What it touches:**
  - `game/theme/fx/kill_cam.gd` (finale): `_apply` sets both values; `_restore` puts `physics_ticks_per_second` back to
    `SimClock.TICK_RATE`. The schedule must be re-expressed: 42 ticks at 6 ticks/s is 7 s, so HOLD_TICKS would count
    real frames or wall time (safe under A) — **the length is his call**; keep 1.4 s + 0.6 s as the default.
  - `game/tactics/tactics_flags.gd` (brains): the same pair for `--slow-motion=`.
  - Readers of `Engine.physics_ticks_per_second` that mean "the simulation's rate" must read `SimClock.TICK_RATE`
    instead, or they report slowed numbers during slow motion: `game/announcer/match_event_adapter.gd` `seconds()`
    (the booth's clock: its comment says it follows the ACTUAL rate on purpose, for tests that change it — that test
    must move to SimClock), `game/control/orders.gd:100` (an order's response ticks), `game/theme/audio/crowd_voice.gd:131`
    (a meter line), `game/main.gd:52` (the headless fps cap: read before any slow motion, harmless).
  - The float risk, MEASURED (2026-10-04, IEEE doubles, the same arithmetic as Godot's `1.0 / tps * time_scale`):
    `physics_ticks_per_second` is an INTEGER, so the factor must be `k / 30`; `(1.0 / k) * (k / 30.0) == 1.0 / 30.0`
    holds for every k in 1..30 **except k = 21** (f = 0.7). The kill cam's SLOW = 0.2 is k = 6: exact. So a ramp in
    whole ticks per second (6, 7, … 30, skipping 21) keeps every tick bit-identical; a smooth ramp between them cannot
    be used. Still to do before building: Godot's own step arithmetic (C++, `Main::iteration`) read to confirm it is
    exactly that product, and a windowed pair with the kill cam at f = 0.2 hashing identical to a run without it past
    the end.
  - Physics interpolation: fewer ticks a real second at the same game motion means larger visual steps between ticks;
    interpolation already handles it (it is designed for 30 Hz under 60+ fps), but the slow-motion frames should be
    looked at (the round-17 old-clock arm showed "two stills" when ticks starved).
- **Hashes:** after a decided match, the kill cam's windowed runs move (they would match HEADLESS past the end for the
  first time). `--slow-motion=` runs move. The default headless baseline and `make determinism` are unmoved (no slow
  motion there). Declared per C18.1's rule as a planned move.

## Fix B: tick-counted rules become time-counted

Every rule counted in ticks reads scaled seconds instead (reload in seconds of `sim_seconds`, think cadence by
accumulated scaled delta, intel by accumulated scaled delta).

- **What it touches:** every tick-counted rule across `game/combat/**` (reloads), `game/ai/**` (think cadence,
  perception, the far-and-idle rate), `game/tactics/**`, `game/match/**` (intel, visibility field cadence), plus their
  tests and scenarios; brains' and nobody's paths.
- **Why not:** (1) a cadence by accumulated float seconds is a new source of float drift in decisions (lesson: the
  sim's determinism rests on integer tick counts, `determinism.md`); (2) at time scale 1 it must reproduce today's
  ticks exactly or the baseline moves for every map; (3) it touches far more code than A for the same result.

## Recommendation

A, with the factor quantised to whole ticks per second (k / 30, never 21), behind the windowed hash pair above. It is ~4 files and turns slow motion
into presentation for good; B is a cross-stream rewrite of the rules for the same result with a new drift risk. Both
leave the length of the kill cam's slow motion to him.

# Stream: feedback (the new rules show on screen; the phone map frees its top)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` (*Summary of his answers*, *His call on R1-R3*, his
> note "free the top of the screen", his end-of-match pick), `_agents/art_direction.md`, `_agents/workstreams.md` **Round 39** (C39.5)
> and *Rulings (round 38)*: R38.28, R38.55. Your round-38 brief: `streams/archive/round38/feedback.md` (*Open, not started*). **You
> own:** `game/ui/**`, `game/theme/**`, `game/audio/**`, `game/announcer/**`, `tests/feedback/**`, `tests/test_feedback*.gd`,
> `mk/feedback.mk`. **Model:** Opus. **Machine:** builder0 light lane; screenshots on the laptop (real GPU). **Seeds:** 6501-6512.

## The lead's direction

His answers on the slug-fest rules (2026-10-21): "never hide an enemy inside a range the player was shown"; suppression slows but never
stops, **shown**; flank hits made visible. He rejects new UI buttons ("UX overload") and anything that looks like the game cheating.
2026-10-22: "the most important part of the view is the top of the screen since that corresponds to units in the distance".

## Where things stand

- **ON:** the flank/rear ring segment, pinned chevrons, the Tanker's repair beam and repairs under fire (F3), end card A (+ portrait),
  the top of the screen free on desktop (F5).
- **R1-R3 are ON by default now (R38.55).** Nobody has checked what he can SEE of them: does any shown range (selection ring, sight
  ring, the tactical map) still show a stopped crew's range while it drives? Does a moving tank's wider spread show anywhere? Is the
  pin slow visible beyond the chevrons?
- `--touch-map` (round 2's phone grammar, `game/ui/tactical_map.gd` `_layout_panels`) keeps its squad bar top centre and camera
  buttons top right: freeing the top there is a phone-layout redesign.

## Backlog (in order)

1. **F1 the rules he can see (audit, then fix).** With R1-R3 ON, film a moving and a stopped crew under fire (desktop + phone) and list
   every place a range or effect is shown. Fix any shown range that lies (his "never hide an enemy inside a range the player was
   shown"): that is a correctness fix, ships with its own test. Any NEW look (a moving tank's spread, etc.) goes on a directions page
   (2-3 options + "none") for his pick; nothing new shows by default until he picks (C39.5).
2. **F2 the phone map's top (`--touch-map`).** A directions page FIRST: 2-3 layouts that move the squad bar and camera buttons off the
   top where thumbs reach, filmed at phone sizes. Build his pick.
3. **F3 build his picks** from F1/F2 as they come back (the orchestrator relays).
4. **Stretch:** announcer lines for the new rules in REAL matches (a moving crew missing, a pinned crew slowed), within the announcer
   rules (subtle satire, authentic UFC hype), behind a switch until he hears them.

## How to verify

Screenshots at 4 sizes x 2 touch boosts (`make remote T=end-shots` pattern, FB_FLAGS='--ui-touch'), LOOK at them; sim-baseline must not
move (presentation only); `make quick-remote`; one full check per named hash. Directions pages go to the orchestrator as artifacts with a
`db` for his picks.

## Don't touch

`game/control/**` (orders), brains, movement, `game/match/**`, `game/tank/**`, `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

F1's and F2's directions pages, once filed.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**2026-10-23 ~22:00: started.** Plan (in order; each a test first):
1. **F1a the fog lies (correctness, ships with its test):** FOUND. The fog of war is the range he is shown; the field
   (game/match/visibility_field.gd) takes one crew's look a tick and publishes once a cycle (15 ticks, or one tick per crew
   past 15 crews), so lit ground trails a crew that drives off, and R1 shrinks its sight 110 % -> 85 % within a second on top.
   Measured (tests/test_feedback_sight_shown.gd, laptop glibc 2.39, 906557c06 + test, enemy just outside the driving sight,
   a drive-off from every point of the refresh cycle, 2 s each): army 1: R1 ON 8 lie-ticks / 5 drive-offs (worst 5.8 m past
   real sight), OFF 38 (3.7 m); army 25: **ON 303 ticks / 9 drive-offs (worst 24.5 m)**, OFF 331 (13.0 m). Fix in my paths
   (game/match is nobody's): the fog sheet's shader and the radar's fog layer clip lit ground to each living crew's sight
   circle as it is NOW (FogViewers, uniforms every frame); the field still decides walls. After: 0 lie-ticks in all four.
2. **F1b audit list** (every shown range or rule effect, below) -> a directions page for the NEW looks (2-3 + none each).
3. **F2** touch-map layouts: a shots target, 2-3 layouts behind `--touch-layout=`, filmed at phone sizes -> directions page.
4. F3 build his picks; stretch: announcer lines for the rules behind a switch.

**F1 audit (R1-R3 ON, 906557c06):**
- Fog of war, 3D sheet (cyberpunk + default themes): LIED (above), fixed.
- Radar fog (same field texture, ~1.2 m a pixel): same lie, fixed (its own layer + clip shader).
- Enemy tanks, selection rings, radar blips: drawn from Match.is_visible_to (intel, every 3 ticks): honest.
- Squad chip contact pip, the vision camera's frame (VisionRegion): read sight_radius live: honest.
- Garage "Sight": a relative bar, no metres: honest. Unit hover card "Range N m" (orders' rts_controls): weapon range, not
  a sight claim; unchanged.
- R2 moving spread: nothing shows it except the shells themselves (tracers land wide). A new look is a page item.
- R3 pin slow: chevrons start at suppression 0.3 (FeedbackReader.PIN_SHOW); the slow starts at 0 (up to 12 % slower with
  no chevron). Nothing shows the slow itself. Page items.

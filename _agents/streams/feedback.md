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

**REPORT 2026-10-24 ~10:10: F3 + stretch built (4ce6759b8, 7567d3753); full check owed after main's batch-1 check is green
and merged in (the orchestrator's order).** builder0 `make quick` exited 0, 261 passed / 0 failed (7567d3753's tree, every
test the diff since 906557c06 touches + lint). d8f88b3ab (the fog fix) is in main's batch-1.
- **His picks** (db `picks/round39`, 2026-10-24 06:58Z; the orchestrator confirmed, R39.4): sight none, fire none, slowed amber,
  touch dock, all six caller lines, no words. **ON by default now:** `slowed` (FeedbackLook slot; `--feedback-look=slowed:off`):
  the pinned chevrons show from the first 5 % of R3's slow and warm yellow -> orange; the phone map's `dock` layout
  (`--touch-layout=top` keeps round 2's). **Deleted:** sight edge/ring, fire wedge, slowed brake, split, `--rules-look`,
  FeedbackFx's moving-shot record, the fog shader's settled glow.
- **Caller lines (stretch), behind `--announcer-rules=on`:** MatchEventAdapter counts shells fired on the move (15 %+ of top
  speed) that hit no enemy and crews R3 holds 20 %+ slow for 2 s while rolling; momentum carries them as an optional `rules`
  field (K5 and its Python twin unchanged, as round 37's `face`). AnnouncerMemory: 3+ misses, no hit -> `moving_miss`; a crawling
  crew -> `pinned_slow` (`unit_<unit>`); beats.json cooldown 45 s each. Voiced caller.moving_miss.01-03 + caller.pinned_slow.01-03:
  ElevenLabs 433 characters, STT flagged 0, credits read 121124 -> 121124 (settles later, as round 37's), ledgered.
- **Looked at (builder0, laptop preset, 7567d3753; kept ~/projects/godot-feedback-keep/r39/f3/):** `feedback-shots
  FB_SLOTS=slowed`: the 50 % crew's chevron is orange with amber, yellow without; the 15 % crew gains a chevron (behind the message
  log in this framing). `touch-shots TOUCH_LAYOUTS=dock` at 2400x1080 / 1800x810 / 810x1800: top of the screen clear, nothing on
  the bug or radar.
- **Dock framing (the orchestrator's ask, dc9cd45d0; builder0 quick 262/0):** test_tactical_map's input test found his
  crews under dock's chips. Cause: TacticalMap's own overview (orthographic, the map without an RTS rig) draws his end of the
  arena at the bottom of the screen, where dock sits. Fix: the overview zooms out by the bars' share and lifts
  (`overview_fit`, Camera3D.v_offset) so the whole arena sits above the bars, nothing cut at the top. The follow view is not
  lifted (that would push the far ground off the top, the part he said matters most); the followed crew is framed at the centre,
  clear. Test: every crew above the bars in the overview, the followed crew clear in the follow view, at 1280x720, 2400x1080 and
  810x1800. test_tactical_map.gd is unchanged from main (no pin). Looked at: touch-shots dock (builder0): his squad above the
  bars at 2400x1080 and 810x1800.
- **Known issues:** NOT verified: the RTS rig's own overview button in a real skirmish (perspective, 77 degrees, game/camera/
  rts_camera.gd, not mine) likely draws his end under dock's bars the same way; a capture flag couldn't hold it open (the rig's
  tracking took the view back). If it does, the fix is the rig's overview framing taking a bottom screen inset (TacticalMap can
  hand it `touch_rects["text_floor"]`). In portrait, the order-preview line floats mid-screen. Caller lines off until he hears them.
- **Merge notes:** outside my paths, the announcer data: assets/announcer/{lines.json, beats.json, README.md, ledger.md, clips/manifest.json, 6 clips} (round 37 did the same).
  R39.3 noted: laptop Godot runs under `flock /tmp/tank-squad-laptop-godot.lock`, none below 1500 MiB available.
- **What to playtest:** `.tools/godot-*/Godot_* --path . -- --skirmish --enemy=cpu --announcer-rules=on` (the chevrons under fire;
  listen for the two new calls when crews fire on the move or crawl under fire); `-- --skirmish --touch-map --ui-touch` (dock).

**2026-10-24 ~01:30 (superseded): green hash d8f88b3ab** (`make check` builder0 exited 0, 3144 passed / 0 failed, 25 passed +
2 NOT JUDGED: perf-judge refused at 2.3-2.5x busy, scenario_perf unpinned; sim-baseline unmoved on every map). The fog fix (F1a)
ON; picks and caller lines then at the lead gate.

**2026-10-24 ~00:10: F1 + F2 directions page filed; waiting on his picks (lead gate). Full check queued on 6f793958f.**
- **Page:** https://claude.ai/artifact/7zsrhB5GG4hV4ckcCWaxGD (db `picks/round39`: sight / fire / slowed / touch / words; empty
  at filing). Rule looks filmed with `make remote T=feedback-shots FB_SLOTS=sight,fire,slowed` (191185d7a; fire at 0fc88183a
  + staging) on builder0, laptop preset; phone map with `make remote T=touch-shots TOUCH_LAYOUTS='top dock split'` (7db78b1b6).
  Clips and stills kept in ~/projects/godot-feedback-keep/r39/ (final-ss, fire4, touch3).
- **My recommendations:** sight none; fire none; slowed amber; phone map dock. The sight `edge` look is built (and tested) but
  left off the page: it can't be seen in a staged shot (the army lights the whole site; the boundary falls behind buildings).
- quick-remote builder0: 201 passed / 0 failed (7db78b1b6, all the diff's tests + lint). Orchestrator messaged.
- Staging lesson (feedback-shots on builder0): the window renders a few frames a second, so physics jumps most of a sim second
  between drawn frames; a timed look (the wedge, 0.9 s) must be staged right before each capture, not on the sim clock.

- **The clip's cost on his GPU** (`make perf-play PERF_PLAY_LAYERS=no_fogvis,no_fogclip PERF_PLAY_PRESET=laptop`, laptop UHD 620,
  1854x1011, seed 92721, 3 cycles x 2.5 s, 45abbb3d3; the laptop was loaded by other worktrees, frames ~136 ms): no_fogclip
  gpu +0.19 ms of 11.4 (noise: no_fogvis read frame +4.15). No cost I can measure; perf-judge (builder0) owns the judged line.
- Page v2 adds question 5: six caller lines (moving misses, slowed to a crawl) as TEXT for his approval (lead gate 2:
  `announcer-generate APPROVED=1` only after). Wiring (adapter events + memory moments, `--announcer-rules=on`) follows his ticks.

**Questions for the lead** (on the page): the four picks and which caller lines to voice.

**What to playtest:** `make skirmish` (the fog fix is ON: drive a crew away from an enemy and watch the lit ground follow it);
the looks: `make rules-skirmish` won't pass them; use `.tools/godot-*/Godot_* --path . -- --skirmish --enemy=cpu
--rules-look=slowed:amber,fire:wedge,sight:ring` and `-- --skirmish --touch-map --ui-touch --touch-layout=dock`
(C39.6's `make skirmish SKIRMISH_FLAGS=` once native's grant lands).

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

**2026-10-23 ~23:00: 38a865e97 committed** (F1a fix + candidate looks + F2 layouts, everything new OFF). quick-remote on the
fix alone: builder0 `make quick` exited 0, 81 passed / 0 failed. Candidate looks (`--rules-look=`, FeedbackLook.RULE_LOOKS,
default none): sight `edge` (fog boundary brighter round a settled crew) / `ring` (live dashed sight ring under selected crews);
fire `wedge` (a shot fired on the move leaves a fading wedge of its spread, the stopped spread inside); slowed `amber`
(chevrons from 5 % slow, warming to orange) / `brake` (brake lights on a slowed rolling hull). Touch layouts
(`--touch-layout=`, TouchLayout, default top): `dock` (orders + chips centred between bug and radar, camera buttons over the
radar), `split` (chips centred, orders over the score bug, camera buttons over the radar); portrait both = orders column
left, chips column right, camera buttons between. Found on today's phone map (touch-shots 906557c06 builder0): its order bar
runs into the score bug's kills line in landscape and covers the bug in portrait.

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

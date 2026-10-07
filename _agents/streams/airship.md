# Stream: airship (he played whole matches on the built-up maps and never saw it)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *The Syndicate airship* (why it
> exists: *"sometimes visible in the field of view"*), *Round 11 direction* (*The camera and the airship: push up, not
> away*), *Round 14 direction, first item* (steer clear of his view) and *Round 15: the airship's "what gives way",
> decided on the page* (his pick C), `_agents/workstreams.md` *Round 21* (C21.3), and the archived briefs
> `streams/archive/round14/airship.md` and `streams/archive/round15/airship.md` with their Status (the instruments
> `airship-view`, `airship-report`, `airship-look`, `airship-shot`; the arms; the noise declaration; B2's finding that
> no altitude lever reached the in-frame bar; B3's finding that pointing the camera near the hull makes it LEAVE the
> shot). Evidence: `streams/references/round14/airship/`, `references/round15/airship/`. **You own**
> `game/theme/arena_kit/airship/**`, `tests/test_theme_ad_airship.gd`, `tests/test_theme_airship.gd`,
> `game/theme/fx/bench/airship_shot.gd`, `game/theme/fx/bench/rig_vanish.gd`, `tools/airship_view_pool.py`, the airship
> targets in `mk/fx.mk`, the `_build_airship` carve-out in `game/theme/cyberpunk/arena_dressing.gd`. **Read-only:**
> `game/camera/**` (one additive accessor allowed, listed in merge notes; a fix on the camera's side is a REQUEST),
> `arenas/**`, `game/arena/**` (the map layouts; `Arena.ROTATION` is the live list you read).

## The lead's direction

2026-09-19, why it exists: *"a Bladerunner-like Airship that hovered over the arena, sometimes visible in the field of
view, that also had a big TV screen"*. 2026-09-23: *"we push the camera up above the airship (that way there's more
likelihood of seeing the cool airship for an in-game effect)"*. 2026-09-27: *"frequently when we're playing the
airship flies right in front of the camera and disrupting the game… make the airship smarter and try to avoid blocking
the player's field of view"*. 2026-09-28, shown the climb's cost (seen half as often): *"ah ok that's a great idea,
turn that on by default"*. 2026-10-03, his tap: **C** (climb against where the camera rests; the camera stops lifting
over the hull). **Nothing new from him in words this round:** the finding is the orchestrator's from his afternoon play
on 2026-10-06 (he played the garage's fights on foundry and never saw it), measured below. Standing: opaque, visible,
in the venue, 1.5×, never faded or cut away; the fight is never hidden behind it.

## Where things stand — REWRITTEN by the worker on the orchestrator's instruction (2026-10-06 night)

- **Why he never saw it: there was no airship in the garage's fights.** Foundry (`Arena.DEFAULT_LAYOUT`, every
  `make garage` fight) never built one (the dressing's size check; fixed at `3f2ea88d` on `stream/airship-foundry`, the
  fix alone for a first merge; also in `684f976b` on this branch). Foundry has no kit: once built, the report reads it
  cruising 100 % and in frame 32 % at 49 m.
- **"His frame": the live camera (`make airship-view`) is taken as the truth, the report as the close-camera bound.**
  Reason: `airship-view` drives the real vision camera in a real skirmish, and its traces put that camera ~88 m back,
  ~35 m up on every map (builder0, seeds 41–44, main's flight at `0c243e8a`+V0); the report assumes his round-6 49 m
  pose, the close end of the auto camera (floor 45 m, cap 100 m). On the live camera main's hull is in frame 50–84 %
  on the built-up six (terminus 68, cut 67, locks 73, crossing 50, docks 81, sumps 77) against 77–81 % on the open
  maps (yard 81, parade 77): the built-up maps already read like the open ones, except the Crossing. The report now
  prints both cameras (`seen49`, `seen95`).
- **The column V2 is judged on (agreed with the orchestrator, 2026-10-07): BODY %** in `make airship-view` = the share
  of ticks the hull's mid-height line (seven points along the keel and on the flanks, where the screens are) is inside
  his lens with a clear ray from the lens through the arena's colliders. Frame % (the hull BOX touching the frustum)
  overstates the built-up maps: there it is mostly the belly's edge in the top strip. One-seed smoke (builder0,
  post-merge `be4516bb`, seed 41, 20–60 s): body % Terminus 0.0, Docks 6–7, foundry 32, yard 11–33. His bar "same as
  other maps" = the open maps' body % on the same seeds; hides the fight bounded by main's (C21.3).
- The original reading follows, kept as written.

### As written at the launch (read at `0a9ce446`, main, the orchestrator's laptop)

- **`make airship-report`** (headless, his pose, `SEEN_YAWS` averaged, `LEG_S` default), share of the flight in his
  frame: **terminus 0 %, cut 0 %, locks 1 %, crossing 1 %, docks 3 %**, sumps 10 %, pit 16 %, the open maps
  (parade, yard, gorge, archipelago) 24–31 %. Inside something drawn: 0 % everywhere (round 11's rule holds).
- **Why (hypothesis, labelled; verify first):** on the built-up maps the pilot climbs over tall kit (`_clear_spot`, the
  solid rule) and the view-climb (`view_climb`, `view_rest`, `view_low`) keeps the belly above
  `SyndicateAdAirship.visible_ceiling_at(distance)`; the frame's top edge is 3.5° BELOW the horizon at his pitch, so
  anything above the ceiling at its range is out of frame. On the open maps there is less to climb over and the
  carrot's orbit brings the hull low into frame between the squads' views. Round 15's B2 found no altitude lever
  reached the brief's in-frame bar on the four maps it tested; the built-up rotation maps were never in the list.
- **The instrument's default list is stale (lesson 265):** `airship_report.gd` `MAPS` is the round-11 nine; the
  rotation is twelve (`Arena.ROTATION`: yard, pit, terminus, crossing, sumps, locks, parade, gorge, archipelago, cut,
  docks, yard_open). Six rotation maps were never measured until 2026-10-06.
- The airship is built on every map; his laptop preset does not remove it (FX tier HIGH on desktop). It costs no
  credits and nothing in the sim (dressing; the baselines never see it).
- `make airship-view` is not tick-repeatable; quote pooled series only (round 15's known issue). `VIEW_DISPLAY=1` on
  builder0 is ~1 fps. `make airship-look` needs a display (builder0's is unlocked and on).

## Backlog (in order)

**V0. The instrument reads the live rotation.** `airship_report.gd` defaults to `Arena.ROTATION` (plus `MAPS=` to
override); a test fails when a rotation map is missing from the report; the report prints a per-map line and a
pooled line. Run it on main's flight on builder0 as the BEFORE table (commit, machine, LEG_S, seeds) in Status.

**V1. Name the mechanism per map.** For each built-up map (terminus, cut, locks, crossing, docks, sumps) attribute the
missing share by REMOVING one thing at a time (lesson: a cost is attributed by removal, not by ratio): the view-climb
(`AIRSHIP_OFF=viewclimb`), the rest-climb (`viewrest`), the solid-clearance climb over kit, the carrot's altitude/orbit
radius. A table: map × lever removed → in-frame %, hides-the-fight % (`airship-view`, pooled seeds). The lever that
returns the share without raising hides-the-fight is the design; if none does, say so with the numbers.

**V2. Seen on every map (the behaviour).** Build the lever(s) V1 names so that on every rotation map the hull is in
his frame for a real share of the flight without hiding the fight more than main does (C21.3). Candidate designs to
decide among with V1's table, not before: (a) a lower cruise over kit where the sight lines allow it (clear the kit
by a margin, not by the ceiling); (b) the climb sinks back faster and lower once the camera has moved on
(`view_sink`, measured OFF in round 15 on four maps; re-measure on the built-up six); (c) "appearances": the pilot
plans a pass that crosses the top third of his frame on purpose every N seconds, far side of the fight, then climbs
out, so he SEES it and it never stands between him and his vehicles; (d) a bigger orbit over the quiet half of the
map at an altitude under the ceiling at that range. **The bar, his (2026-10-06 evening, *"same as other maps"*): in frame as often as on the open maps today
(24–31 % of the flight at `0a9ce446`), never over the ground he looks at.** Every switch defaults OFF until its acceptance passes; then ON in one commit with the
before/after tables.

**V3. Looked at.** `make airship-look` and `airship-shot` frames on terminus, cut, locks, docks at his pose: the hull
in frame, over the city, not over the fight; desktop and phone aspect; the three worst frames per map from
`airship-view VIEW_DISPLAY=1` if it runs; put them under `streams/references/round21/airship/` and say what you see.

**V4. Docs.** The airship section of `game_design.md` is his words (do not edit); write yours in the file headers and in
`_agents/show_dials.md` or `lighting.md` if a dial moved; a one-line entry in `roadmap.md` is the orchestrator's.

**Stretch (a).** The deck panel is seen at ~89° (`deck_grazing_deg`): a dark slab in play. If V2's lower cruise brings
it under 80°, say so; if a tilt of the deck panel toward his pose is cheap and looks right in the frames, do it.
**Stretch (b).** A hardware-preset switch for the laptop (`FX tier`) that keeps the airship but drops its screen's
feed to a static poster, if the frames show the feed costs him anything (measure first with `make perf-play`).

## How to verify

- `make remote T=check` green on every commit (builder0; read `>> remote: make check exited <N>` and `N passed, M
  failed`, never a pipe). 23 targets ALL JUDGED; thirteen lines + determinism UNMOVED (the airship is dressing; say so
  in each commit).
- `make airship-report` on the live rotation, before and after (builder0, same LEG_S); `make airship-view` pooled
  seeds on at least the six built-up maps for hides-the-fight; `make airship-look` frames looked at.
- Play it: `make skirmish ARENA=terminus` and `ARENA=cut` for a few minutes at his pose; does the airship come into
  the top of the frame now and then, and does it ever stand between you and your squad? Record what you saw.
- Every number: commit, machine, workload, seeds (C16.3). Builder0 is ~2.75× faster than the laptop.

## Don't touch

`game/camera/**` (read-only; a request) · `game/control/**`, `game/ui/**` (orders') · `game/tactics/**`, `game/ai/**`
(brains') · `arenas/**`, `game/arena/**` (nobody; you READ `Arena.ROTATION`) · the rest of `game/theme/**` outside your
files · `mk/core.mk`, `tests/baselines/**`.

## Waiting on the lead

- Nothing. **His answer (2026-10-06 evening): *"I want the airship same as other maps."*** V2's bar is the open maps'
  share at `0a9ce446` (24–31 % of the flight in his frame) on every rotation map, the fight never hidden more than
  main's (C21.3).

## Status

_(newest first within each section)_

### REPORT (2026-10-07 morning) — read this first
- **DONE for round 21.** `1f091e84` merged to main as `32285ab8` (the foundry fix earlier, alone, as `bbb6be80`).
  Worktree clean; nothing under `build/` to keep (every number and frame quoted here is filed in
  `references/round21/airship/`).
- **Merged already:** the foundry fix ALONE (`3f2ea88d` → main `bbb6be80`): the garage's fights had no airship at all.
  **Green on this branch:** see the last line of this report for the hash the check ran on.
- **Why he never saw it:** in the garage's fights (foundry, `Arena.DEFAULT_LAYOUT`) the airship was never built
  (the dressing's size check). Fixed. Foundry now: in frame 88 %, **body 39 %** (the open maps 29–39 %), hides the fight
  6.67 % (per seed 4.8–8.1; the open maps' per-seed 1.3–10.8): same as the open maps both ways (orchestrator accepted).
- **The brief's 0–3 % was the wrong camera** (the report's fixed 49 m pose; his auto camera sits ~95 m back, ~35 m
  up). On his real camera the built-up maps' problem is sharper and narrower: the airship's BELLY shows over the roofs,
  its BODY and screens almost never — body % main (seeds 51–56 / 61–66): Terminus 0.1, Cut 2.6 / 4.5, Locks 3.0,
  Crossing 2.7, Docks 10.0 / 14.5, Sumps 14.5 / 11.0, against the open maps' 29–39.
- **Mechanism, by removal (V1):** the climb over 24 m kit, on all six (Crossing: no kit → body 31.1 from 2.7; no
  view-climb 5.4; nominal orbit 2.1). No altitude lever exists: the lowest legal centre over a 24 m roof (~37 m) is
  above his ~35 m lens, and his frame's ceiling FALLS with distance (top edge 3.5° below the horizon), so no far pass
  shows it either.
- **V2, the lever (stations: hover in open squares near the fight), built, measured, OFF everywhere.** It does reach
  the open maps' body % on the Cut, Docks and Sumps (37–52 %), but under the bounds ruled with the orchestrator (the
  open maps' band on the same seeds: hides and longest intrusion) no map passes on both seed sets: Cut passed
  51–56 (5.89 %, 4.9 s) and failed 61–66 (7.24 % > 6.09); Sumps failed 51–56 on longest (7.7 s > 6.0) and passed 61–66;
  Docks failed hides both times (8.50, 7.65). Terminus, Locks and Crossing: **no lever reaches them** — too few open
  squares in range (body 1–14 % with stations); under the roofs his frame cannot hold the body. Said plainly.
- **The trade, for him (the orchestrator puts it at the close):** *on the Cut, the Docks and the Sumps the airship can
  be seen about as often as on the open maps (it comes down into an open square near the fight and hovers there,
  broadcasting), at the cost of it sitting over your fight roughly twice as often (Cut 3.3 → 7.2 %, Docks 4.4 → 7.7 %, Sumps 3.0 → 5.3 %, seeds 61–66) and for up to 5–8 s at a time;
  today it is almost never seen there.* Ready behind a flag: `AIRSHIP_ON=stationsescape
  AIRSHIP_STATIONS_MAPS=cut,docks,sumps make skirmish ARENA=sumps` (or `--airship-on=stationsescape
  --airship-stations-maps=...`). To ship it on his yes: `AirshipFlight.stations := true`, `station_escape := true`,
  `station_maps := ["cut", "docks", "sumps"]` (one commit, airship paths only).
- **Instruments (all mine):** `make airship-report` reads `Arena.ROTATION` + foundry and prints seen49 / seen95;
  `make airship-view` adds **body %** (the column V2 was judged on; verified with a probe ray onto Terminus' Block_0 at
  24.0 m), belly %, an `AIRSHIP_VIEW_LOS` blocker listing, and the arms `nokit`, `nochoice`, `stations`,
  `liveboom`, `stationslive`, `stationsfarlive`, `stationsescape`. Evidence: `references/round21/airship/`
  (every pooled table, the climb map, the open-squares map, the V3 sheets).
- **V3 (looked at):** `airship-shot`, 49 m and 105 m, foundry / Terminus / Cut / Locks / Docks
  (`references/round21/airship/v3_*.jpg`). Foundry: the white hull and its screen read clearly beyond the fight in the
  wide frames; its belly crosses the top strip at 49 m. Terminus/Locks/Docks: blocks fill the frames, at most a sliver
  of hull at the top; Cut: once over a block with its screen up. The bench aims at the hull, so the frames show WHAT
  it looks like, not how often.
- **V4 docs:** file headers carry the reasons (`airship_flight.gd` stations section, `airship_view.gd` header,
  `airship_report.gd` header, `syndicate_ad_airship.gd` LIVE_BOOM_M); no show dial moved.
- **Stretch (a):** the deck panel at the live camera is ~83° off straight-on (rise 34 − 22.8 m over 88.7 m run),
  not under 80°; stations do not change the deck's height. A tilt toward "his pose" has no single direction (his
  camera turns with his squads); not done. **Stretch (b):** not measured — it wants `make perf-play` on HIS laptop GPU
  (builder0's numbers say nothing about the UHD 620); the command for him or the orchestrator: `make perf-play
  ARENA=foundry` with and without `--fx-quality=medium`.
- **Questions for the lead:** the trade above (stations on the Cut/Docks/Sumps), put by the orchestrator.
- **Requests to other streams:** none. **Known issues:** `airship-view` is not tick-repeatable (pooled seeds only;
  per-seed hides range 0–11 %); `VIEW_DISPLAY=1` is ~1 fps on builder0. The report's two cameras are camera-blind
  upper bounds; quote `airship-view` body % for what he sees.
- **Playtest:** `make garage` → FIGHT (foundry): the airship is now in the sky. `make skirmish ARENA=cut` (today) vs
  `AIRSHIP_ON=stationsescape AIRSHIP_STATIONS_MAPS=cut make skirmish ARENA=cut` (the trade).
- **GREEN, merge here: `1f091e84`** (builder0 `>> remote: make check exited 0`, 2194 passed / 0 failed, 23 targets ALL
  JUDGED, thirteen sim-baseline lines unmoved, determinism `762a0576f944f5b7`). Everything above it is this Status.
- **Merge notes:** `game/theme/cyberpunk/arena_dressing.gd` setup(): one `_build_airship()` call (already on main).
  `mk/fx.mk`: airship targets only. Everything else airship-owned. Every new switch defaults OFF; main's flight is
  unchanged by this branch.

### Plan (2026-10-06 evening, in order)
1. **V0** — the report reads `Arena.ROTATION`, pooled line, test; BEFORE table on builder0. Then **V1** attribution by
   removal: report arms (`solidclimb` off = no kit, a measurement upper bound; `orbitchoice` off; `viewsink` on) and
   `airship-view` arms on the six built-up maps (main `climb` vs `off` = no view-climb, pooled seeds). Then **V2** the
   lever V1 names, behind a switch, ON only when the bar passes; **V3** frames; **V4** docs; stretch.
   Reason for the order: the report measures the flight with NO camera (the view-climb never runs in it), so the
   report's 0–3 % cannot come from the view-climb at all; the kit is the first suspect and removal says how much.

### THE FINDING: in the garage's fights there was NO airship (fixed, `684f976b`, check pending)
- He played the garage's fights, which land on **foundry** (`Arena.DEFAULT_LAYOUT`; `make garage` passes no
  `--arena`). Foundry is in neither the rotation nor the round-11 nine, so no airship instrument ever measured it.
  `make airship-view` on foundry: **`AIRSHIP_VIEW_FAILED ... airship=false`**. Mechanism: `ArenaDressing._ready` builds
  the venue before any map is active (so no airship: `flies_on({})` is false), and `setup(layout)` rebuilt the venue
  only when the map's size differs from the default venue (121 m). Foundry is 120 m (+1) = no rebuild = no airship,
  every garage match. Same for the cut 120 m maps (boulevard, boneyard, maze, barriers); every rotation map is 140 m and
  was fine. **The brief's hypothesis (the climb over kit) is real on the built-up rotation maps but is NOT why he never
  saw it**: foundry has no kit at all (report: cruise 100 %, in frame 32.1 %).
- Fix: `_build_airship()` in `setup`'s no-rebuild branch (one line; the call site of the carve-out). Test first
  (`test_theme_airship::test_every_map_gets_its_broadcast_airship_even_one_the_size_of_the_default_venue`, builds the
  dressing in the game's order on foundry and the Terminus): failed on foundry before, passes after (builder0).
- `AirshipReport.default_maps()` = `Arena.ROTATION` + `Arena.DEFAULT_LAYOUT` (the maps he plays, lesson 265 again).

### The two instruments disagree, and why (read before quoting any in-frame number)
- `make airship-report` puts his camera at his round-6 pose: 49 m boom, 21°, 35° lens (17.6 m up). The auto camera's
  floor is 45 m, its cap 100 m. `make airship-view` drives the real vision camera, and it sits at **~88 m ground
  range, ~35 m up** on every map (builder0, traces, seeds 41–44, foundry/yard/parade/terminus at `0c243e8a`+V0):
  framing a squad, it runs to its 100 m cap. From there a hull over a 24 m roof is IN frame. Main's flight in frame
  (airship-view, pooled seeds 41–44): terminus 68 %, cut 67 %, locks 73 %, crossing 50 %, docks 81 %, sumps 77 %,
  yard 81 %, parade 77 %. So the report's 0–3 % is the close end of his camera's range, the live number the far end;
  which he plays at is his (`make skirmish` prints `CAMERA_POSE` with the readout on). Both are reported below.

### V2 confirmation pre-registration (written 2026-10-07 before any run of seeds 61–66; not edited after)
- Build `c64ac015`, builder0, `make airship-view`, seeds 61–66, 240 s. Arms: main (`climb`) and `stationsescape` on
  cut, sumps, docks; main on yard, parade, gorge, archipelago (the band, same seeds).
- **A map's stations ship ON (per-map switch) only if, on BOTH the design seeds 51–56 and these, `stationsescape`:**
  hides the fight ≤ the open maps' highest pooled hides on the same seeds, longest intrusion ≤ the open maps' highest
  longest on the same seeds, and body % ≥ the open maps' lowest pooled body % on the same seeds. On 51–56 only the Cut
  passed (5.89 % ≤ 6.05; 4.9 s ≤ 6.0; body 37.2 ≥ 29.5).
- Expectation, so it can be wrong: the Cut's 5.89 against 6.05 is inside one batch's noise (per-seed hides range
  1–11 %); a coin flip.

### What "in frame" hides: the BODY is missing on the built-up maps, not the hull (`airship-view` body % / belly %)
- The rendered frames (V3, `references/round21/airship/v3_*`) showed Terminus, Locks and Docks with little or no hull
  where frame % said 68–81 %. Frame % counts the hull BOX touching the frustum, which on the built-up maps is mostly its
  bottom edge in the top strip. New columns (`2eb0a7f7`): **body %** = seven points on the hull's mid-height line (where
  the flank screens are) inside his lens with a clear ray through the arena's colliders; **belly %** the same at its
  underside. Checked before quoting: the first version read Terminus 0.0 % because `Camera3D.is_position_in_frustum`
  refuses everything headless (fixed: the instrument's own lens); a probe confirms the rays hit the floor and Terminus'
  `Block_0` at 24.0 m.
- Smoke (builder0, post-merge `be4516bb`, seed 41, 20–60 s, one seed: indicative only): body % Terminus **0.0**, Docks
  6–7, foundry 32, yard 11–33; belly % Terminus 46–50, Docks 44–68, foundry 73, yard 75–85. No ray was ever stopped by
  a block: from his ~35 m camera the roofs do not hide the hull; its middle is simply ABOVE his frame when it flies
  over 24 m roofs (centre ~37 m against a 35 m lens looking 3.5° below the horizon at the frame's top).
- So the brief's complaint survives the camera correction in a sharper form: on the built-up maps he sees the
  airship's belly over the roofs, almost never its body and screens. V2 is re-opened on **body %** (fresh seeds 51–56,
  post-merge, main vs stations, with hides the fight), running.

### The report's second camera (orchestrator's item 3) — and foundry BEFORE/AFTER
`make airship-report` now prints **seen49** (his round-6 pose, the auto camera's close end) and **seen95** (where the
auto camera sits in play, from the airship-view traces). Builder0, the flight of `684f976b` (= main's flight; stations
OFF), 4 × 60 s legs, deterministic:

| map | cruise % | seen49 % | seen95 % |
|---|---|---|---|
| terminus | 0.0 | 0.0 | 21.0 |
| cut | 0.0 | 0.2 | 28.6 |
| locks | 2.5 | 0.7 | 21.6 |
| crossing | 5.1 | 1.2 | 26.6 |
| docks | 9.1 | 3.3 | 29.2 |
| sumps | 19.2 | 10.2 | 54.0 |
| pit | 43.0 | 16.1 | 49.0 |
| yard / yard_open | 77.1 | 25.5 | 56.9 |
| parade | 69.5 | 27.9 | 62.8 |
| gorge | 66.1 | 24.3 | 54.8 |
| archipelago | 87.0 | 31.4 | 62.9 |
| **foundry** | 100.0 | 32.1 | 63.3 |
| POOLED (13) | 42.7 | 15.3 | 45.2 |

**Foundry, the corrected number for the close:** BEFORE (main `0a9ce446`/`0c243e8a`, in his game): **no airship at
all** (`airship-view`: `AIRSHIP_VIEW_FAILED airship=false`). The report could not see that (it builds the airship
itself, not the dressing) and read 32.1 % at 49 m. AFTER (`3f2ea88d` = main `bbb6be80`): built; the report 32.1 % at
49 m / 63.3 % at 95 m; the live camera 75.4 % in frame, hides the fight 4.45 % (seeds 41–44). Both report cameras are
camera-blind upper bounds (no occlusion, no view-climb, four fixed yaws); the live instrument is the one to quote for
what he sees.

### V2 — DECIDED: the build fix is the behaviour; stations measured and shipped OFF (lesson 266)
**Live camera** (`make airship-view`, builder0, `684f976b` + the `stations` arm, seeds 41–44, 240 s, pooled; frame %
/ hides the fight % / longest intrusion s):

| map | main | stations (`--airship-on=stations`) |
|---|---|---|
| foundry (fixed) | 75.4 / 4.45 / 5.0 | not built up: identical |
| terminus | 68.3 / 1.99 / 3.2 | 64.6 / 3.76 / 3.2 |
| cut | 67.0 / 2.73 / 5.1 | 72.1 / 6.12 / 5.3 |
| locks | 72.7 / 3.01 / 5.0 | 77.4 / 6.15 / 7.9 |
| crossing | 49.9 / 2.11 / 2.6 | 31.4 / 2.36 / 6.1 |
| docks | 81.3 / 4.51 / 7.8 | 86.5 / 10.99 / 6.6 |
| sumps | 76.7 / 3.25 / 6.5 | 86.1 / 5.61 / 7.7 |
| open maps for the bar | yard 81.1 / 3.34, parade 76.7 / 8.56 (seeds 41–44, same build) | — |

- **Stations FAIL C21.3** (hides the fight up on all six, roughly doubled on cut, locks, docks) and buy little frame
  on the camera he plays with (−18 to +9 points). On the 49 m report they did help (pooled 13.9 → 21.3 %, docks 3.3 →
  32.4, terminus 0 → 7.5), but that camera is not where his auto camera sits. **OFF**, kept switchable
  (`--airship-on=stations`, `AIRSHIP_ON=stations make skirmish ARENA=docks` to see it hover).
- **On the live camera the built-up maps already read like the open ones** (64–81 % vs 77–81 %, hides 2–4.5 % vs
  3.3–8.6 %), **except the Crossing** (50 %). And foundry, his garage map, goes from no airship to 75 % in frame,
  hides 4.45 % (main at `0a9ce446` had 0 % hides there only because there was no hull to hide anything: the cost of
  having it at all, in line with the open maps).

### V1 — DONE: the mechanism per map, by removal
**Report (no camera; builder0, `684f976b`'s flight = main's; 4 × 60 s legs, deterministic):**

| map | main | no kit (`solidclimb` off; inside %) | nominal orbit only | sink 1.5× (`viewsink`) |
|---|---|---|---|---|
| terminus | 0.0 | 31.4 (96 % inside) | 0.0 | 0.0 |
| cut | 0.2 | 31.4 (66 %) | 3.6 | — |
| locks | 0.7 | 31.4 (78 %) | 0.6 | — |
| crossing | 1.2 | 31.4 (77 %) | 1.0 | — |
| docks | 3.3 | 31.4 (50 %) | 6.1 | 3.9 |
| sumps | 10.2 | 31.4 (53 %) | 5.0 | — |
| POOLED (12) | 13.9 | 31.4 (39 %) | 14.3 | 14.2 |

- **The climb over kit is the whole deficit** on the report: with no kit every map reads 31.4 % (the open maps'
  ceiling), but through the buildings. Neither the orbit's radius choice nor a faster sink returns it. The view-climb
  cannot be in it at all (the report has no camera). No altitude lever exists: a belly over a 24 m roof (25 m) is above
  his 17.6 m camera, out of frame at any range, and the hull's 22 m beam does not fit the 18–22 m streets.
- **Live camera, the view-climb removed** (`airship-view`, builder0, seeds 41–44, 240 s, main `climb` → `off`):
  frame % terminus 68.3 → 73.0, cut 67.0 → 69.5, locks 72.7 → 76.0, crossing 49.9 → 53.8, docks 81.3 → 83.7, sumps
  76.7 → 78.4; hides the fight 2.0 → 7.9, 2.7 → 9.7, 3.0 → 9.7, 2.1 → 5.5, 4.5 → 14.3, 3.3 → 7.3 %. The view-climb
  costs 2–5 points of frame and saves 3–10 points of hiding: it stays.
- **So the lever is WHERE it flies, not how high:** (d) as built in V2 — open squares to hover in.

### V0 — DONE (`6c80d10c`)
- `AirshipReport.default_maps()` = `Arena.ROTATION` read at run time; `--maps=` overrides; per-map lines then a POOLED
  line (plain mean, every map one vote, and the least-seen map). Tests: `test_the_report_measures_every_map_he_is_dealt`,
  `test_the_report_pools_its_maps_into_one_line`; the airship tests' map list now covers the rotation too.
  `AIRSHIP_FLAGS=` passes switches to the report.
- **BEFORE** (builder0, main's flight at `0c243e8a` + the V0 report, `make airship-report`, LEG_S 60 (default), four
  legs, SEEN_YAWS; deterministic, no seeds):

| map | inside % | cruise % | in his frame % |
|---|---|---|---|
| yard | 0.0 | 77.1 | 25.5 |
| pit | 0.0 | 43.0 | 16.1 |
| terminus | 0.0 | 0.0 | **0.0** |
| crossing | 0.0 | 5.1 | **1.2** |
| sumps | 0.0 | 19.2 | 10.2 |
| locks | 0.0 | 2.5 | **0.7** |
| parade | 0.0 | 69.5 | 27.9 |
| gorge | 0.0 | 66.1 | 24.3 |
| archipelago | 0.0 | 87.0 | 31.4 |
| cut | 0.0 | 0.0 | **0.2** |
| docks | 0.0 | 9.1 | **3.3** |
| yard_open | 0.0 | 77.1 | 25.5 |
| **POOLED** | 0.0 | 38.0 | 13.9 (least: terminus 0.0) |

- **Where the hull must climb** (diagnostic, builder0: share of the play disc where the cruising hull's footprint, at
  heading 0 or 90°, overlaps kit it must climb over): terminus **96 %**, cut 76 %, crossing 75 %, locks 75 %, sumps
  67 %, docks 60 %, pit 48 %; the open maps 19–22 %. In-frame tracks cruise (seen ≈ 0.35 × cruise on every map): the
  frame's top edge is 3.5° below the horizon at his pose, so a belly over a 24 m roof (25 m) is ABOVE his 17.6 m
  camera and out of frame at any range.

### Baseline
`0c243e8a` (branch start) builder0 `>> remote: make check exited 0`, 2166 passed / 0 failed, 21 passed + 2 NOT
JUDGED (perf-judge refused: box busy, 1.83×; `scenario_perf` unpinned), thirteen sim-baseline lines unmoved,
determinism `762a0576f944f5b7`.

# Stream: mapkit (blast doors the announcer calls; then sight screens, overpass, tank traps)

> Read `_agents/orchestration.md` (the worker contract; *Lead gates*), `_agents/workstreams.md` **Round 47** (C47.1-C47.11; C47.7, C47.8
> and C47.10 are yours), `_agents/arenas.md` (*The cheap-piece map kit backlog*, *Streets are lanes*, *How we test that a map
> delivers*), `_agents/streams/references/fx_tricks.md`, `_agents/art_direction.md`, `game_design.md` *His ask on cheap map pieces* and its announcer
> sections (grep `announcer`). **This is a new stream.** **You own:** `arenas/**`, `game/arena/**`, new prop
> files under `game/theme/` and `assets/props/**`, a NEW `game/match/blast_doors.gd` (+ its test), blast-door line SLOTS in
> `game/announcer/` (text and event wiring only), `tests/arena/**`, `tests/test_arena*.gd`, `tests/mapkit/**`, `mk/mapkit.mk` (new; one
> include line in the Makefile, listed in merge notes); GRANT perception's eye ray for the `sight` class (C47.7, one function behind a
> kit flag). **Model:** Opus. **Machine:** builder3; the laptop only for the lock-held fps read. **Seeds:** 12901-12948 (map series),
> 12949-12996 (reserve). Dev 7001-7012.

## The lead's direction (2026-10-30 ~16:05, verbatim)

"We started something great by using cheap inexpensive buildings with lights on them to further creating these cyberpunk gladiator
arena effect without bloating our assets. Do you have other ideas for reproducible polygons that could be added to our maps that are
cheap in terms of rendering but fit with the theme and enable more interestin maps?"

"ok can we capture all of these ideas as backlog items to see about adding to our maps? If we don't like them we can just remove them,
but presuambly this is a way to add details to our game that won't result in asset creep. I also do like your blast doors idea coupled
with announcer feedback and what not. This is something that can make the game generally more interest"

Memory: concept choices on the tap-to-approve page (2-3 directions per piece) before any 3D; announcer satire subtle and believable,
caller = authentic UFC hype; the laptop is the test bed (UHD 620); approved content ships ON.

## Where things stand (main fccfaadea; code e306ce27f GREEN builder3 3518/0, 28 ALL JUDGED)

- The kit: `game/arena/arena_kit.gd` PROPS (cover classes `hard` / `low`); a kit type lands in the SAME commit as its `prop.<type>` slot
  and scene. The lit city blocks are the recipe: boxes on one trim-sheet material, emission glow, MultiMesh, little translucency.
- Nine pieces in `arenas.md`; **blast doors WANTED**; sight screens, overpass, tank traps recommended first; raised ground needs his go
  (not this round).
- Doors touch the route (C47.8): route's planner reads `BlastDoors.is_open(id, tick)`; until route's side lands, doors ship on a dev
  arena only.

## Backlog (in order)

1. **P1 the looks page (lead gate):** for blast doors, sight screens, overpass, tank traps: 2-3 directions each, rendered from the kit's
   own primitives in Godot (no paid generation needed; if a direction needs Meshy, say so on the page first), at the in-game camera
   distance, desktop aspect; plus the **announcer's door lines as text** (a door opening, closing, a crew caught by one: 3-4 variants
   each, his caller's voice). Publish as an Artifact with the `db` capability for his picks; message the orchestrator the URL.
2. **P2 blast doors, rules first (independent of the look):** `blast_doors.gd`: a door is a collider + a nav link, open/shut on a
   schedule deterministic from the match seed (replays reproduce it); events for the announcer and the feed; both sides read the same
   schedule (C47.9). Tests first: open/shut by tick, a replay equal, a crew never crushed or trapped inside a closing door (it waits or
   is pushed clear). A dev arena with two doors.
3. **P3 the `sight` cover class (C47.7):** blocks the eye ray and the cover map's sight term, not hulls or shells; engage is told the hour
   it lands. Tests: a screened line of sight is blind, a shell passes.
4. **P4 the approved pieces into maps** (after his picks): tank traps and the overpass first (pure kit), sight screens after P3, doors
   after route's R5. `make arena-report` before/after; the paired series against the map's twin without the pieces; the laptop fps
   (C47.10, under the lock); lanes still pass `tests/test_arena_lanes.gd`.
5. **P5 announcer lines for doors:** wired to slots with placeholder text-to-screen; audio only after he approves the text (paid gate).
6. **Stretch:** pipe racks, gantry cranes (backlog items 4-5) onto the looks page.

## Don't touch

movement / traffic (manoeuvre), `pathing.gd` / planner (route: doors go through C47.8), gunnery / the rest of perception (engage),
`game/control/**`, `native/**`, `game/camera/**`, `game/ui/**`, `game/audio/**`, the rest of `game/match/**`, `tests/baselines/**`.

## How to verify

`make remote T=check` on builder3 (read `>> remote: make check exited <N>` and `N passed, M failed`, never an exit code through a
pipe); `make quick-remote` to iterate (`QUICK_BASE=<your last green>`); `make replay-match RECORDING=...` and `make playtest-report
RECORDING=...` on his four recordings; screenshots at desktop and phone aspect, looked at. Every number with its commit, machine,
workload and n. **No local Godot runs** except a lock-held laptop budget read (C47.1: seven sessions on a 7 GB laptop).

## Waiting on the lead

Nothing at launch. If a bar fails, write in player terms what he would see ON v OFF and message the orchestrator the same hour.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**REPORT (2026-10-30 ~21:00; newest first).**

**Green hashes:** 6282f0fbf (P2 v1; builder3 3532/0, ALL JUDGED); **39c7dba53** (P2 contract + P3 + P5 + P4 traps/monorail/door
look; builder3 `make check exited 0`, 3548/0, 28 targets ALL JUDGED, 20:23; MERGED to main by the orchestrator). 2bf534df2 was red
(test_render_multimesh_interpolation: the strip curtain bypassed FxMultiMesh; fixed in 39c7dba53). **c2ff150a2** (470301cc7 + a .uid):
steam screens, pipes B, crane A, the monorail deck split, P1b's trim sheet, mapkit-gpu -- quick 310/0 builder3; full check queued
on builder3 since ~20:55 -> **RED** (3551/0 but the engine-log gate: "ObjectDB instance was leaked at exit" x3 shards; the
sight screen's member initializer made a strip node the steam branch never used). **04adca907** = the fix + **the trim sheet ON**
on traps/monorail/pipes/crane (his P1b pick, R47.38; `--kit-look=plain` escapes) + the train concepts; quick 116/0 builder3; full
check queued on builder3 (name it here). f10081d90 (gallery only) on top.

**His picks so far:** looks (P1, db `picks/*`): door A, screen C, overpass C, traps A, pipes B, crane A; 21 lines kept.
Trim trial (P1b, db `trim/*`): TRIM on all four. Train (R47.38): page https://claude.ai/artifact/9PNjR9rWKNXQXBWQ9sNsLC,
db `train/pick`, waiting. **Bar P** (the twin series) filed by the orchestrator; runs after manoeuvre's W/H and orders' O2.
**Render copy:** builder3 `~/tank_squad/mapkit-render` (a copy of this stream's folder for gallery renders while a check is queued in
`godot-mapkit`; delete it at the round's close).

**Done, by backlog item:**
- P1 looks page (his picks: door A, screen C, overpass C, traps A, pipes B, crane A; 21 lines kept). P1b trim-sheet page
  https://claude.ai/artifact/Ko8xyeccqTwz9AcYKoNNVA (waiting on his picks: `trim/<piece>` db).
- P2 blast doors: rules + colliders + route's contract (C47.8 as built), hold/overstay, doors_dev. On doors_dev ONLY until native
  passes RouteDoors' mask in C++ route queries (C47.6) -- blocked on native, request sent.
- P3 sight class: done (C47.7); engage/native told (merge notes on 39c7dba53).
- P4: all six picks exist as kit types with their looks (tank_trap, monorail + monorail_deck, sight_screen steam/strips, pipeline,
  gantry_leg, prop.blast_door). Twins (CANDIDATES): parade_traps, parade_rail. Static reads (laptop, arena_report): traps change no
  view (mean 83.6 -> 82.8 m); the rail cuts views a little (centre sees 0.82 -> 0.78, mean 81.6 m); every lane and corner passes.
  NOT done: the paired series v parade (C47.1: a bar first), screens/pipes/crane placed on a map, doors on a dealt map (native).
- P5: the booth calls the doors with his 21 lines, 133 clips voiced (ledger below).

**Laptop (C47.10), `make mapkit-gpu`, 470301cc7, Intel UHD 620 (WHL GT2), laptop preset, his pose 1920x1080, 120 frames, n=1 per row:**
empty floor 9.47 / 9.50 / 8.80 ms GPU (the noise: about +-0.7 ms). Plain: traps 8.45/8.37, monorail 9.12/9.16, pipes 9.33/9.21,
crane 8.90/8.31, door 7.78/8.50. Screen steam 8.84 v strips 9.34. Trim: traps 8.38, monorail **10.62** (+1.4 over plain, re-measure
before it ships), pipes 9.40, crane 8.71. No piece reads above the floor's own spread except that one. (The gallery scene: render
levers may not all apply outside a match; the read is each piece's cost relative to the same floor.)

**What to playtest:** `make skirmish ARENA=parade_traps` (hedgehog breakwaters in front of each base), `make skirmish
ARENA=parade_rail` (a monorail over the parade ground), `make skirmish ARENA=doors_dev` (two blast doors on a timer, the booth
calling them; crews route round by the flank gaps until native passes the door mask). `--kit-sight=off` turns screens back into
scenery. Steam shows on the high FX tier outside the laptop preset.

**Next steps:** paired series parade v parade_traps / parade_rail (file a bar first); a screened twin (Crossing: gangs v syndicate's
79 m median is the case screens were for); pipes on Sumps/Locks twins; doors on a dealt map once native passes the mask; the trim
monorail GPU repeat; his trim picks -> MapkitYard.look default per piece.
- **P1b Material Maker trial (R47.28), in progress 19:35:** Material Maker pinned at 7d6daae3c (2026-10-24, shallow clone) in
  builder3's `~/tools/material-maker`, outside every repo. Export path read first (parse_args.gd): a local `.ptex` only; nothing is
  fetched unless a `website:` argument is given. **Gotcha:** Godot 4 takes `--export` itself (the Godot 3 flag); use
  `--export-material`. It renders on builder3's NVIDIA under Xorg :1 (Steam/SPIR-V errors on stdout are harmless: its optional
  integrations). Recipe `assets/props/trim/trim_sheet.ptex` = ONE inline GLSL shader node -> Material (+ MM's normal_map node): a
  1024 px sheet in four bands (plate 0-0.40, hazard 0.40-0.55, grime 0.55-0.85, glowing joints 0.85-1). `make mapkit-trim` renders
  it (MM_COMMIT checked), `make mapkit-trim-adopt` copies the PNGs in. The kit's MapkitYard meshes carry UVs into those bands;
  `MapkitYard.look = "trim"` (gallery `--kit-look=trim`) dresses them; "plain" is what ships.
- **P4 in progress (uncommitted at 18:15, waiting on builder3's queue: 6 full checks deep):** his picks built as kit:
  `tank_trap` (hedgehogs, `low`, box 0.9 m under the muzzles, hog drawn 1.2 m), `monorail` (overpass C: 1.4 x 9 m pillar, `hard`,
  carrying 10 m of beam at 9 m; `car` look key), the door look `prop.blast_door` (vault slabs A, leaves glide 1.2 s, red/green
  header, beacons through the warning; a held door shows its warning). One MultiMesh per kind (`MapkitYard`). Twin
  `parade_traps` (candidate) + static read: views unchanged, lanes pass. Tests: test_tank_traps, test_monorail.
- **His picks (read by the orchestrator from the page db, main b8ec444aa):** door A vault slabs, sight screen C vent steam, overpass
  C monorail, tank traps A hedgehogs, extras pipes B and crane A; all 21 door lines KEPT -> voice approved.
- **P2 first version GREEN: 6282f0fbf** (builder3, `make check exited 0`, 3532 passed / 0 failed, 28 targets ALL JUDGED; waited
  1781 s for the full-check lock). Contract version (route's R47.12 shape) + P3 + P5 follow in the next commit; its check is named
  below when it lands.
- **C47.8 as built with route:** static `BlastDoors.is_open(id: StringName, tick)` reads `BlastDoors.active` (the arena built last;
  unknown door or no arena = open); the doorway is CARVED (bake-only slabs in Obstacles during the bake, freed after); one
  NavigationLink3D per door on exactly `RouteDoors.register(&id, middle)`'s bit (UNUSED_LAYER, bit 32, while RouteDoors is not in
  the project: no route uses a door). Hold: errs OPEN only; `overstay` event after HOLD_EVICT_S = 6 s held (the door never seals on
  a hull; manoeuvre's yield can consume it -- request below). Replay-equal hold test.
- **P3 sight class (C47.7):** ArenaKit `sight` cover + `sight_screen` type (14 x 6 x 0.6 m), body on physics layer 5
  (SIGHT_LAYER 16), never in `obstacles`; `Perception.eye_mask()` = WORLD_MASK | SIGHT_LAYER while `ArenaKit.sight_on`
  (`--kit-sight=off`); CoverTables marks screens; placeholder look = strip curtain until his pick (C, steam) is built in P4 (a
  translucent look -> high tier, the strips the low/medium fallback, C47.10). No shipped map has a screen: byte-identical.
- **P5 voice: 133 clips recorded** (132 + 1 re-record), ledger rows in `assets/announcer/ledger.md` and below. Door events reach the
  booth as K5 `door` {door, gate, kind[, unit, team]}; moments door_open / door_shut / door_closing (PA warning) / door_held /
  door_caught (nearest crew within 25 m driving at a door as it shuts). `{gate}` = 4 recorded compass names for every map (layout
  door key `call`).

**Paid ledger (mapkit):**
| when | what | requests | characters | credits before -> after |
|---|---|---|---|---|
| 2026-10-30 ~18:05 | the 21 door lines x gate/unit/faction variants (lead kept all 21; orchestrator relayed approval) | 132 | 9,445 | 120,679 -> 112,354 |
| 2026-10-30 ~18:15 | caller.door.open.04@south re-recorded once (speech-to-text heard a stray "But") | 1 | 68 | 112,354 -> 112,354 (unsettled read) |
Speech-to-text still flags caller.door.open.04@north and @west for contractions only ("Somebody's gonna"): check by ear.

**Requests to other streams:** (1) native: pass the route mask (RouteDoors) in C++ route queries, and EYE mask: native_perception
configures C++ LOS with `Perception.WORLD_MASK`; screens need `Perception.eye_mask()` there (until then, a native crew sees through a
sight screen). (2) manoeuvre (via orchestrator): an `overstay` door event names a crew parked in a closing doorway for 6 s; a yield
that drives it clear. (3) engage / whoever owns `match.gd` `_clear_view` and `visibility_field.gd`: they ray with WORLD_MASK, so
intel/visibility ignore screens; switch to `Perception.eye_mask()` (one word each).

**2026-10-30 ~16:55 (start).** Base = main c789b55a6 (code e306ce27f GREEN builder3 3518/0, inherited; no launch check run).

**Plan (in order; smallest foundation first):**
1. **P1 looks page (his gate):** `tests/mapkit/looks_gallery.gd` (+ `make mapkit-looks`, `mk/mapkit.mk`) builds 2-3 directions per
   piece from CyberMaterials primitives at his pose (21 deg, FOV 35, 49 m) beside a dozer; doors drawn shut AND open; stretch pieces
   (pipes, crane) on the same page now, since the scene costs nothing extra. Page = Artifact with `db` for his picks + the door lines.
   *Decision:* the renders live in `tests/mapkit/` (concept only); the picked direction is rebuilt as a `prop.<type>` MultiMesh scene
   with its ArenaKit type in one commit (P4).
2. **P2 `game/match/blast_doors.gd` rules** (independent of the look): schedule from the match seed, `is_open(id, tick)`, events,
   crew-safe closing (a door waits while a hull is in its swept box), dev arena with two doors. Tests first.
3. **P3 the `sight` cover class** (C47.7) behind a kit flag; perception's eye ray in one function; tell engage the hour.
4. **P4** approved pieces into maps after his picks (traps + overpass first).
5. **P5** door lines in announcer slots as text; audio only after his approval.

**Found on the way:** builder3 runs Xorg on `:1`, not Xwayland, so `tools/remote.sh` exports no DISPLAY there and every rendering
target fails or draws nowhere on builder3. Workaround: `make remote T="<target> DISPLAY=:1 XAUTHORITY=/run/user/1000/gdm/Xauthority"`.

**Requests to other streams:** native (owns `tools/remote.sh`): teach the DISPLAY probe builder3's Xorg (`ps -C Xorg -o args=` for
`-auth`, display from `/tmp/.X11-unix/X*`).

**P1 DONE, waiting on his picks (lead gate):** the looks page https://claude.ai/artifact/WSBf2Wmmar3BSocBqqrRpm (published 17:02;
picks in its db: `picks/<door|screen|overpass|traps|pipes|crane>` = {choice a|b|c|none, note}; `lines/<id>` = {verdict keep|cut}).
Renders: `make mapkit-looks` on builder3 (DISPLAY :1), 18 shots at his pose (21 deg, FOV 35, 49 m), 1920x1080. Concept frames draw
53-147 draw calls each in the gallery scene (builder3, the scene's own MAPKIT_LOOKS lines; the hedgehog field is the 147: ~5 boxes a
hog unbatched; the built prop is one MultiMesh). **Found while looking:** the overpass deck hides the street under it from his camera
(first render, deck running away from the camera, covered both dozers) -- any overpass needs a deck cutaway like the blocks' (camera's
`BlockCutaway`); said on the page. Holo screen A needed an opaque scrim (the additive holo alone let the enemy dozer show through).
Door lines on the page: caller 15 (open 4, close 4, caught 4, held 3), PA 4, Veteran 2 -- text only, audio is his gate.

**Questions for the lead:** (on the looks page) his picks per piece; keep/cut per door line.

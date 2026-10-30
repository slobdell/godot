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

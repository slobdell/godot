# Roadmap

Each step leaves a playable, tested game. Details of *what the game is* live in [game_design.md](game_design.md);
this file is *order and status*. Rewritten 2026-09-15 (the milestone-by-milestone history is in git and in the
archived stream briefs).

## Done

| When | What | Where to read |
|---|---|---|
| 2026-09-12 | **M0–M3.5:** scaffold and bootstrap; one tank with direct control; server-authoritative WebSocket multiplayer; combat (projectiles, armor facing, line of sight, teams, bots); the agent bridge (Claude commands a tank) | architecture.md, agent_bridge.md |
| 2026-09-13 | **M4:** faster-than-real-time match runner and fairness controls; navmesh pathing; tank brains (utility AI) with directives and doctrines; shared team vision; tactical map with commanders, formations, drills; elimination skirmish; the parallel-work refactor (modes, visual slots, sim baseline) | tank_brain.md, tactical_map.md, squad_ai_design.md, workstreams.md |
| 2026-09-14/15 | **Round 1: five parallel streams overnight**, merged 2026-09-15 | streams/archive/round1/ |
| | gameplay: touch input, fog of war + radar, responsive orders, RTS camera, turrets that fight on the move, shields, ammo/heat/lasers, unit catalog, budgets, CPU armies, control point | archive/round1/gameplay.md, balance.md |
| | look & feel: FX lab and tier budgets, cyberpunk theme, pooled effects, HUD widgets, quality tiers, sound, title screen | archive/round1/look_and_feel.md, references/fx_tricks.md |
| | assets: GLB pipeline, Meshy/Tripo clients, the **prison dozer** (now the default tank) | archive/round1/assets.md, slot_contracts.md, art_direction.md |
| | netcode: relay broker, player-hosted matches, lobby, reconnect, replays; lockstep feasibility spike | archive/round1/netcode.md, references/netcode_designs.md |
| | garage: touch army builder, saving, army codes, presets | archive/round1/garage.md |

| 2026-09-15 | **Round 2: rules, ai, command, art, army**, merged 2026-09-15 | streams/archive/round2/ |
| | rules: fixed unit catalog v2, counters from mechanics, friendly fire, 25 units a side, arenas as data, matchup matrix, Burner and fire pits | archive/round2/rules.md, balance.md |
| | ai: cover map, peek and shoot, fire lanes, matchup groundwork, squad tactics, AI ladder | archive/round2/ai.md, unit_ai.md |
| | command: tap grammar, squad bar, formation and drill icons, camera follows orders, HUD messages | archive/round2/command.md |
| | art: roster and arena kit from reviewed Meshy concepts, textured floor, crowds, the review page | archive/round2/art.md |
| | army: army builder v2, progression and unlocks, match loop with results, challenges | archive/round2/army.md |
| 2026-09-15 | **Remote builds on builder0** (`make remote T=check`: 6 min 40 s vs 14–22 min) | remote_builds.md |

| 2026-09-15 | **Round 3: control, combat, ai, feel, assets, announcer**, merged 2026-09-15 | streams/archive/round3/ |
| | control: StarCraft-style desktop control (select, box, groups, right-click, attack-move, queues, follow), the K1 Orders API, 1-tick response, automatic formations, regrouping, selection panel | archive/round3/control.md |
| | combat: tank shells (320 dmg / 5 s, 75 m/s), 25 mm bursts, MG streams, weak spots, arcade driving with turning circles, artillery deploy, K2 events, K3 locomotion, matchup matrix | archive/round3/combat.md, balance.md |
| | ai: orders always win, circle-strafing and attack runs, dodging shells, weak-spot hunting, cover work, a CPU commander that maneuvers, champion x4 | archive/round3/ai.md, unit_ai.md |
| | feel: tank-shell muzzle/flight/impact/kill effects, burst and stream tracers, weak-spot hits, wrecks, order and selection feedback, motion dust and drift, sound | archive/round3/feel.md, references/fx_tricks.md |
| | assets: stackable ISO containers, giant ad screens, neon signs, artillery outriggers, 33 faction concepts reviewed by the lead, **15 faction vehicles in 3D** plus a wreck husk | archive/round3/assets.md, art_direction.md |
| | announcer: match-event contract and fixtures, the banter director, 429 lines, transcripts and the booth page (no audio generated yet) | archive/round3/announcer.md |

| 2026-09-16 | **Round 4: control, doctrine, combat, ai, audio**, merged 2026-09-16 | streams/archive/round4/ |
| | control: the vision-framed camera (zoom capped by ground your force can see), element focus with edge chips and alerts, the radar as the map, tasks not geometry, 30-a-side command measured, faction pick, a cinematic camera | archive/round4/control.md |
| | doctrine: elements with leaders, formations and movement techniques from Army literature, battle drills, faction tables, parity by construction, the doctrine page | archive/round4/doctrine.md, doctrine.md |
| | combat: suppression and effective fire, heavies shielding the fragile, three factions playable (15 vehicles, 11 weapons, hover, field repair), the simulation 30–58% cheaper, a faction matrix | archive/round4/combat.md, balance.md |
| | ai: brains executing doctrine, deliberate suppression (fire at ground), beaten-zone avoidance, champion x4t9 | archive/round4/ai.md, unit_ai.md |
| | audio: the announcer voiced for real (589 lines, 2,372 recordings, whole sentences after stitching was rejected), variance gated, the booth live, a cinematic sound mix, MatchMood, the music pipeline | archive/round4/audio.md |

## Round 10 (2026-09-22, closed 09-23): what it did, in one list

- The right-click always answers (five mechanisms; 7 of 7 states on main); Form squad on the card; objective rings
  where the match scores; every player goal grounded on the navmesh with the hull's clearance.
- The Terminus streets are lanes (16–22 m drivable, junctions certified for the rig; kerb paint and a pool at every
  corner); nav's wall-contact instrument and drive test; the pressed-wall escape on by default (caveat: n = 1).
- The bigger bus, the turret mounts, the blimp on the avenue; the light show on the walls per window; 518 announcer
  lines; two water-and-bridge maps (the Crossing, the Sumps) whose bridges are used.
- The pitch from the turning envelope; a 20 m move settles in 4–9 s; the friendly-fire line-of-fire site reads the
  hull's box (yard gangs 36 % vs 23 %, p 0.039, the whole effect at that one site).
- The yaw freeze's mechanism (a ratchet against a squadmate); the world-only constraint passes four bars and stays
  OFF on a fifth (a two-sided pinch the driver must creep out of).
- Three research briefs and replies curated (`research_catalog.md`, rows B1–B14 and C1–C12).

## Round 11 (2026-09-24, closed the same day): what it did, in one list

His eleven playtest items, four streams, one day. **Three of the four streams were finishing work that already
existed and did not reach him** — the shape to look for first next time. Full record in `HANDOFF.md` *ROUND 11*.

- **The rotation was the bug, not the content.** `Arena.ROTATION` held three names while `arenas/` held fifteen;
  round 10's Crossing and Sumps had never been reachable. Now six maps, including the new **Locks** (canal, a watched
  lock and two covered swing bridges, its name recorded and his yes on the page), and the Pit finally dug. A map
  built and neither dealt, cut, nor a fixture now fails the suite.
- **The Terminus spotlights were solid-looking and not solid:** 21 m venue towers with no collision, ~8 m inside the
  wall. Outside it now, and the prop-parity test covers the venue dressing where they hid.
- **A reverse decided before the bumper** (nav): press/unstick-driven wall contacts 88 → 1 on the mixed squad,
  total contacts −64 %, arrivals up; plus the formation slot that stopped landing inside buildings, on by default.
- **The vehicles:** seven turrets were spinning inside their hulls; the "detached barrel" was a 14-triangle sliver;
  the only two non-uniformly stretched meshes in the game are gone; the Law at his approved 1.25×; and the first
  test that asserts a model faces −Z.
- **The airship** was inside something 31 % of a Terminus flight and is now 0 % on nine maps; the camera lifts up and
  over it.
- **Six lessons** (`orchestration.md` 214-219), two of them the orchestrator's own errors.

## Round 12 (2026-09-26 → 27, closed): what it did, in one list

Six streams, one night. Full record in `HANDOFF.md` *ROUND 12*; briefs in `streams/archive/round12/`.

- **The fire engine he approved on the 24th, built:** the Condemned burner draws its own turntable-ladder truck
  (box 2.99 × 3.30 × 7.54, the flame from the drawn nozzle). The bus stays the dozer by his word ("there was nothing
  wrong with the tank"); the War Rig's muzzle gap measured at 16–29 px and left alone.
- **The booth and the music:** the opening had never played the pre-match bed (nothing asked for the state); every
  state now rotates 3–6 tracks; 67 + 39 new voiced lines (the trade pool 3 → 20; the PA where she actually speaks),
  all through his veto pages; the booth's faction unit ids fixed (413 of 427 events had been unmatchable).
- **The camera asks the drawing:** out of the floodlight's lamp head; the cutaway stays buildings-only by his verdict.
- **The formation he sees is the one formed:** the AUTO icon and card read the leader's pick; a G-chosen shape survives
  the halt; the fall-in rule measured worse and ships OFF; a partial selection scatters by his round-10 design.
- **The rig's refused back-ups 130 → 56**, arrivals 104 → 115/128, a five-leg turn on the clip with 0 contacts (vs 67);
  an arrived scout stays arrived (mixed stop time 18.9 → 12.1 s); sim baseline → `6313a38d7ecd99bb`.
- **Water reads wet** at his pose (near-black pixels 0.98 → 0.55 on the Locks' far quay), ~1 ms GPU, 0 draw calls.
- **Lessons 220–222**, and the builder0 incident (a runaway rsync from outside a checkout; the wrapper now refuses).

## Round 13 (2026-09-27, one afternoon, closing): what it did, in one list

Three streams, every item built, no sim-baseline move (two streams pre-registered one; neither happened). Full record
in `HANDOFF.md` *ROUND 13*; briefs in `streams/archive/round13/`; evidence in `streams/references/round13/`.

- **The wedge is the default plain-move shape in every terrain** (his *"Default wedge"*): the yard re-measured on the
  same seeds, column first in 5 of 16 paired runs and tidier in 0 of 4 cells against a pre-registered bar of 9 and 2.
- **S6 ON (his call, 2026-09-27 evening; the toggle documented at the code site):** a wheeled fixed-gun hull with nothing in sight is not told to face; mixed-squad stop
  ~20 → ~13 s, faster in 32 of 32 pairs; the scouts sit up to 2.7 m off their slot and no longer angle out along their
  sector (frames in `references/round13/squad/`). **OFF is one line if he prefers tidy.**
- **A give-way the hull fits:** the WHOLE of round 12's +57 % rig reverse-contact rise was right-of-way (spots checked
  at the centre; the 6 m last resort aimed inside the rig's own footprint). Rigs' reverse contacts 3602 → 1756 and all
  contacts halved over 16 seeds; four pre-registered clauses failed on the design seeds and reversed on fresh ones; the
  fight-maps stall share rose on 7 of 12 (a hull that yields in place holds) — shipped ON on his tidier-traversal trade.
- **The garage, smoke-tested like a player, then given music:** the title had no way into the garage; a windowed FIGHT
  opened the faction menu at 0 v 0. Both fixed; `make garage-tour` shoots the loop at both aspects; the garage bed
  plays and hands FIGHT to `pre_match`; the garage and victory pools split.
- Lessons 223–224.

## Round 14 (2026-09-27 evening → 09-28 morning, closed): what it did, in one list

Four streams, one night; the sim baseline unmoved all round (nav's one declared move was withdrawn on a measurement).
Full record in `HANDOFF.md` *ROUND 14*; briefs in `streams/archive/round14/`; evidence in `streams/references/round14/`.

- **His invisible War Rigs were deployed INSIDE a city block** on the Locks and pushed 6.24 m under the floor (read
  from his recording, found by replay after two wrong guesses): deploy keeps every hull clear of obstacles and inside
  the arena; the silent placement check now counts what it could not check; a hull off the floor is logged.
- **The airship against the live camera:** it hides the fight 1.5–7.5 % of ticks, mostly when the camera travels to
  it; a climb over his view halves that on fresh seeds but halves how often he sees it — **shipped OFF, his call**
  (`AIRSHIP_ON=viewclimb`).
- **The garage's first-visit list, all six:** room to build, the turntable at match proportions, **a time-out is
  judged on points destroyed (equal = draw)**, a clean HUD at 20:9, the loader shows the army, the dead stub deleted.
- **Nav's other 53 %:** momentum is the mechanism (reverse commanded while still rolling forward); two fixes measured,
  both OPT-IN — the k-turn brake helps the rigs (contacts −19 %, leg time −13 % on fresh seeds) but breaks the scout's
  engine-deck orbit; the stall share is a coin flip; a holding rig queues +13 %.
- **Squad's two red instruments:** the gang-pack drills were stale since the day they were written (corrected, three
  mutation runs, in `check` now, 15 s); `scenario_perf` REFUSES under load (NOT JUDGED on the verdict line) and fired
  for real three times the same night.
- Lessons 225–228.

## Round 15 (2026-10-01 evening → 10-02, closed): what it did, in one list

Five streams overnight, three decision pages, all three tapped by morning; one baseline move (fleet's IFV boxes),
recorded. Full record in `HANDOFF.md` *ROUND 15*; briefs in `streams/archive/round15/`; evidence in
`streams/references/round15/`.

- **His two approved IFVs are in the game:** the Condemned crash-tender wedge and Law's tracked police APC (his taps
  on fleet's page; 75 credits in all). Tank/IFV silhouette overlap at his pose Condemned 0.89 → 0.69, Law 0.87 → 0.79;
  amber class lamps on both; a standing lineup test holds every pair under 0.80. Baseline moved by the boxes alone.
- **The gangs' table stays as shipped (his tap):** over 16 paired fights per opponent neither flip helps; round 14's
  one-seed flips were noise. Two drill DEFECTS fixed on the way: the far-ambush flanker that circled (enemy-left vs
  chasers 0.63 → 0.42) and the bait runner that never came home.
- **The War Rig's k-turns brake for real, scouts keep their taps** (nav V1, ON for hulls ≥ 10 m: contacts −30 % on
  fresh seeds, +2.4 s a leg); the earlier-looking planner falsified and opt-in; holds are 20 % of queued time.
- **The airship against the live camera, the rest of it:** 54 of 60 intrusions are the camera's lift and the hull's
  climb chasing each other; a fix behind `viewrest`, and the camera-lift question on his page (C recommended).
- **The garage's second list:** the centre scores, said at the first fight; 'N.N m long' on every card; the loader
  readable on a phone; the status box fits at 20:9; a loss on the point repeats the tip.
- **`scenario_perf` fights one battle alone and in-suite; the ladder prints its winner rule; `tactics-pytest` in check.**
- Lessons 229–233.

## Round 16 (2026-10-02 evening → 10-03, closed): what it did, in one list

Six streams, one night, a performance round from his words (*"the game is getting extremely choppy … before sacrificing
any of the existing graphics or gameplay let's find … where we can just get better performance"*). Full record in
`HANDOFF.md` *ROUND 16*; briefs in `streams/archive/round16/`; evidence in `streams/references/round16/` and
`streams/references/perf/r16-*`; lessons 235–241.

- **The game he plays is now measured as he plays it** (`make perf-play`: a human-side skirmish, his flags and window,
  capped and uncapped, layers by removal within one run, wall-clock frame times with `game_speed`; a `.perf` trace
  beside every recording; the script profiler on his path ranking every module's script time).
- **The simulation tick, without changing one decision** (every decision byte-identical to the launch commit, the sim
  baseline unmoved by every performance commit): the fog-of-war field 1.85 → 0.36 ms a tick on the main thread; the
  intel loop's allocation hoisted; the match accessors cached on the tick and kept across ticks; `Units.stat` without a
  String per call; the recorder's census tick 3.0 → 1.2 ms; the brains' memos (nav sweeps, readiness, chords, slots)
  9.4 % of the whole tick's scripts. **The honest line: equal-answer work is spent; the 4 ms brain budget needs
  decision changes, priced for his page in round 17.**
- **The HUD** redraws on change: HUD script 5.6 → 2.9 ms a frame at 68 vehicles on his laptop (−48 %), draw calls 154
  → 121, the tooltip's planner rerun gone; not at 1.5 ms — the three remaining per-unit lines are round 17's native
  candidates with their µs.
- **The picture, proven unchanged** (`make look-parity`, 40/40 within 0.03 %): ~2 ms of GPU at his window pixel-equal;
  the six transparent effects' draw order defined once (round 15's undefined tie); **his five taps on the levers page
  as the `laptop` render preset** (scale 0.75, two lights, no fog, no haze, medium crowd), `desktop` keeping scale 1.0
  (his words), chosen by the adapter, LOOK FULL / LOOK LIGHT in the HUD.
- **His three items:** the opponent randomised (never a mirror); the title's music through the loader AND through
  every planning pause (it had been silent there); the announcers' thin pools measured (four caller pools one match
  uses up), the free fix (a recent specific line falls through), and his 62 approved lines voiced (repeats 7 → 1 a match).
- **Law's APC behaves as tracked** (his words; the round's one declared behaviour change; baseline unmoved).
- **Found on the way:** the skirmish's shot spread was never seeded (every skirmish a fresh roll); the browser build
  had been dead since 2026-09-22 (two export breaks; `web-smoke` now in every check); two HUD defects (bars at a fixed
  height; a duplicate bar); a portrait regression caught by the tour; the laptop's wedged inodes (a reboot).

## Round 17 (2026-10-03 → 10-04, closed): what it did, in one list

Five streams from two things he said after playing round 16 (*"they are completely aligned and completely orthogonal,
and it looks completely synthetic"*; *"the sound effects for all the gunfire and possibly explosions are lacking"*)
and round 16's three candidates. Full record in `HANDOFF.md` *ROUND 17*; briefs in `streams/archive/round17/`; evidence
in `streams/references/round17/` and `streams/references/perf/r17-*`; lessons 243–253. His verdict after playing it:
*"It's getting quite good."*

- **Containers placed by people** (yard): every dealt map turned for real at his strength B (±4.0° / ±6.4°, upper
  levels to 45 cm), the collider with the picture; walls guarded against opened sight rays, narrowed lanes and
  junctions; contact counting (`make container-contacts`) showed no rise in planned-turn contacts and, for the first
  time, how much long hulls scrape on every layout.
- **Sound** (guns): the mix first (a gun is the loudest thing), the gun families in layers, impacts by surface, the
  audit's first silent events filled, the bus layout file, the 5.1 finding; seventeen picks and thirteen keeps by his
  ear; 2,879 ElevenLabs credits.
- **The Sumps' windowed fork** (sim): the kill cam's wall-clock schedule was the cause; it counts ticks now, bounded to
  ~3 s real; a windowed regression pair in `check`.
- **The browser build and the check** (ship): the voice, required sound, the faction pack after the title; perf-judge
  pinned and alone with a named verdict; the engine-message gate; `check-all` reporting every target; the light lane.
  `check` is 23 targets.
- **The brains' decision levers** (brains): six levers and two bundles built behind switches, priced by paired split
  A/B, and **none worth turning on**: no saving on his laptop at equal vehicle counts; the builder0 saving was time
  after the match was decided; the bundle changes outcomes. Every lever OFF. The instruments stay (`--brains-census`,
  `BRAINS_ARM`, `ai-lever-perfplay`, `unit_ai.md` *pricing a decision lever*).

## Round 25 notes (collected during round 24; the orchestrator)

- **The laptop's pricing workload has no water map** (foundry + parade). His last playtest was the Locks. Add a water
  map (locks) to `make native-tick-profile`'s arenas; re-price `native_el` (C24.8, OFF at −0.37 % on foundry/parade;
  −0.94 ms headless on the Sumps, mostly the water rules) on it.
- **The give-way** (brains' stretch b, round 24): ~+0.5 s of B1's +0.54 s on a plain move sits in Movement's give-way
  (freeze set); a give-way arm on the same series confirms it. The bridge-mouth queue (crews finishing on the narrow
  quay) points at the same code.
- **`ElementPlan.build`** (~1 ms a tick spread over ~40 functions): not ported in round 24 (native's estimate: days of
  Dictionary-shaped output for ≤ 1 ms).
- **The 0.97 bar** (C24.7): round 24's levers reach ~0.92 on the laptop; the rest is execute (weapon, move) and the
  engaged crews.

## Round 24 candidates (collected at round 23's close, 2026-10-08) — LAUNCHED 2026-10-08 night as brains (1b) + native (1) (`workstreams.md` *Round 24*)

Each has a line **for him**, written as what he would notice (lesson 254), and the technical line beside it.

1. **DECIDED BY HIM (2026-10-08): the whole per-vehicle tick rewritten in C++** (*"ok yes let's plan on re-writing the
   whole per-tick loop in C++"*; Rust asked and answered, C++ kept: `game_design.md` *Round 23, the afternoon*). **For
   him:** big fights stop going into slow motion on the laptop, and the army goes back to ten squads / 50 vehicles when
   the laptop table says so. **Technical:** `native.md` *The plan from here*, N3: the per-tank data reshaped into a
   native record the C++ owns across ticks, a per-team contacts table filled once a tick, the EXECUTE step
   (`Movement.drive` → steering → command; 56.6 % of the brains' work at 50 v 50) as ONE native call per tank per tick,
   then THINK (`decide`, 43.4 %). Where we stand (round 23, builder0, n = 3, every port on, hashes equal): the brains'
   cost −20 % his Sumps / −22 % at 25 v 25 / −22 % at 50 v 50; on the laptop 25 a side in contact ~40 ms a tick before
   (`references/round23/perf/laptop/`), ~30 ms by proportion after; the bar 25 ms (C23.3). Size it as ONE stream
   (native) for the round, possibly two rounds: the state machine has ~140 `ctl.tank.*` touch points and ~9,300 lines
   of GDScript sit in `game/ai/{movement,tank_brain,avoidance,steering,combat_motion,gunnery}.gd`. **The proof will
   not stay bit-exact end to end** (Dictionary-ordered tie-breaks): plan each step as equal-answer where it can be,
   and the rest as DECLARED changes (C22.2) with the paired series, his to accept. Brains must not edit
   `movement.gd` / `tank_brain.gd` behaviour while the port runs (a freeze contract, or brains rests). The round's
   first measurement: the laptop table on round 23's close main with native ON (`make perf-fight PERF_FIGHT=size
   PERF_FIGHT_SIZES="25 30"`), so the bar is read against today, not last night.
1b. **HIS, from playing the close (2026-10-08): units sent across the Locks' bridge drive into the river and stick;
   and one squad of a big group takes another route and leaves the army.** (`game_design.md` *Round 24 direction*;
   recording `references/round24/his/2026-10-08T20-17-24-locks.jsonl.gz`.) The bridge is a BUG and comes FIRST:
   brains (or a nav stream) reproduces his order from the recording, finds which layer leaves the bridge (navmesh,
   route, anchor/leg, slot grounding), fixes it with a scenario on the Locks and a check across every map with a
   bridge or a ford; then the group route (a cost on a squad's route splitting from the body's; one shared corridor
   for squads ordered together), declared, symmetric. **Contract with item 1:** both live in `movement.gd` /
   `pathing.gd` / the element transit, which native's rewrite freezes. Recommended order: the bridge fix lands
   FIRST (days, not a round), then native's freeze starts on the fixed code; the group-route design can run in
   brains' tactics paths (`game/tactics/**`) beside the rewrite.
2. **For him: the army stays five squads / 25 vehicles until 1 lands** (`Units.MAX_SQUADS` 5; army's A4 recipe flips
   it, the orchestrator at a close).
3. **For him: a crew under three long-range guns still dies where it stands; it decides a second sooner now, but its
   cover is behind it and turning eats the time.** Brains' B3 (OFF, `--duck-urgent=on`): the lever is a reverse leg
   to cover (a declared change of its own).
4. **For him: nothing he would notice; an ordinary move costs ~0.75 s more since the squad paces itself** (brains'
   B1 candidate b; where it comes from is unpriced: the creep of crews ahead of their seat, or the give-way's dips).
5. **For him: nothing; small fixes.** `hud_skin.gd` pins its banner to `ALERT_Y`, not the strip's real line (24 px
   at his window; perf's file); `control_scale` timing still unjudged (needs an idle builder0); the in-line seat swap
   is fixed on the shipped path but halves (4 → 2) on the untangle-off arm (not shipped, unmeasured).
6. **Held, each as he was told it:** round 23's 7 (the Syndicate range gap: stays) and 8 (the airship trade answered;
   the mirror-match caller line; rank raises credits; the netcode guard; the camera's sixth-frame hitch; the exported
   build's two resources at quit; the missing sounds and the subwoofer; the browser, which keeps the GDScript path).

## Round 23 launch record (2026-10-07 ~23:30 PDT; three streams, `workstreams.md` *Round 23*) — CLOSED 2026-10-08, kept as the record

**His first item after playing round 22's close** (`game_design.md` *Round 23 direction, first item*: the line abreast
only formed at the end; some vehicles should slow so the squad forms on the way) became **brains** (candidate 0: the
element's transit paces its anchor to the slowest-to-seat crew; plus candidate 5's first half, the grace under three
guns). Candidate 1 (the per-vehicle tick, round 19's held item 2) became **native** (C++ through godot-cpp: the vehicle
brain's hot loop ported, the sim hash and the full suite the proof, priced by in-run A/B; the laptop baseline at 25 and
30 a side is the orchestrator's first measurement, run the launch night). Candidates 3, 4 and 6 became **orders** (28 m
between two columns, decided by him; AUTO at ten squads stands on the click; the chip under the alert strip; the
per-vehicle hold readout, candidate 5's second half). Candidate 2 goes away when native lands and the cap returns to
50 by one constant (the orchestrator, at the close). **His two answers at the launch:** 28 m, yes; the range gap
(candidate 7) stays. Held: 8, as they were.

## Round 23 candidates (collected at round 22's close, 2026-10-07 evening) — LAUNCHED 2026-10-07 night, kept as the record

Each has a line **for him**, written as what he would notice (lesson 254), and the technical line beside it.

0. **For him (his words, 2026-10-08, playing): tanks in line abreast only formed up at the very end, because the lead
   vehicle was already closest to the target and the others never caught up until it stopped; some vehicles should
   slow down so the squad forms on the way.** Brains: the element's transit paces its anchor to the slowest-to-seat
   crew (a crew ahead of its seat slows; `GroupFormation.pace` is the model); scenario from his case; the arrive series
   as the guard; the pursuit keeps road speed. `game_design.md` *Round 23 direction, first item*.

1. **For him: big fights go into slow motion on your laptop; 25 a side already does once everyone is in contact, and
   the 50-a-side army you asked for cannot ship until this is fixed.** The simulation costs ~0.6–0.8 ms per vehicle
   per tick on builder0 (~2 ms on the laptop), four fifths of it the vehicle brains (`tank_brain.gd`), the profile flat
   (no function over 14 %); equal-answer cuts bought ≤ 2 % and one was not equal; the think-rate lever bought 15–25 %.
   The candidate is NATIVE code for the controllers (round 19's held item 2, now where the frame goes): a GDExtension
   port of the brain's hot loop with the sim hash as the proof, priced by in-run A/B. Brief: `references/round22/brains/b3/`
   and perf's tables (`references/round22/perf/`). The laptop baseline (`make perf-fight PERF_FIGHT=size
   PERF_FIGHT_SIZES="25 30"`, a quiet window, ~1 h) is the round's first measurement. When it lands, the cap goes back to
   ten squads / 50 by one constant (army's A4 recipe in `streams/archive/round22/army.md`).
2. **For him: a scout army of 25 leaves about 500 credits unspent** (the cap at 25 with 2000 CR; the line says so).
   Goes away with candidate 1.
3. **For him: two squads in column driving side by side are 14 m apart and brush each other; 28 m is the proposal.**
   Orders' question 1 (his eye; one constant).
4. **For him: ten squads on auto formation ordered close to your base stand 30 m past your click** (orders' fallback
   (a): AUTO has no shape to nest; pick any one shape and they stand on the click). Only with the cap at 50.
5. **For him: a vehicle under fire from three or more long-range guns at once still dies where it stands** (B1's grace;
   brains); and under your per-vehicle hold the readout says nothing (only squad-level holds report).
6. **For him: a squad chip on the bottom edge can hide behind the contact alert** (perf's known issue, small).
7. **For him: four Syndicate vehicles beat ten Rat Rods for no damage (1320 v 700 points); one spotter beats five Rat
   Rods 12 of 16.** Measured (B4), unchanged; his balance call.
8. **Held, each as he was told it:** the airship trade (answered: no); the mirror-match caller line; rank raises
   credits; `control_scale` timing; the netcode guard; the camera's sixth-frame hitch; the exported build's two
   resources at quit; the missing sounds and the subwoofer; the browser.

## Round 22 launch record (2026-10-07 afternoon; four streams, `workstreams.md` *Round 22*) — CLOSED 2026-10-08, kept as the record

**His two items after playing round 21** (`game_design.md` *Round 22 direction*: *"the armies I can create with tanks
are too small"* → *"yeah double it sounds good"*; a Syndicate vehicle *"just sat there and took it until it died"*)
became **army** (ten squads, 50 vehicles, 2000 credits; the cap a measured number), **brains** (the sitting duck; the
commander at ten; the tick at 50 a side; candidate 2 measured for him), **orders** (groups 1–9 and 0; ten squads shown;
the body at ten; 50 a side on the map) and **perf** (his frame on the laptop at 50 a side, then equal-output cuts and a
hardware preset). Candidates 3 and 5 are brains', 4 is orders' stretch, 6 held. **Questions to him:** candidate 1 (the
airship trade; recommended: try the flag in one game) and 2 (the range gap; recommended: leave it).

## Round 22 candidates (collected at round 21's close, 2026-10-07) — LAUNCHED 2026-10-07, kept as the record

Each has a line **for him**, written as what he would notice (lesson 254), and the technical line beside it.

1. **For him: on the Cut, the Docks and the Sumps you could see the airship about as often as on the open maps, at
   the cost of it sitting over your fight roughly twice as often (3–4 % → 5–8 % of the match) and for up to 5–8 s at
   a time; today it is almost never seen there.** His call (art direction). Ready behind a flag: `AIRSHIP_ON=stationsescape
   AIRSHIP_STATIONS_MAPS=cut,docks,sumps make skirmish ARENA=sumps`; shipping it is three defaults in
   `airship_flight.gd` (airship's final Status, `streams/archive/round21/airship.md`). On Terminus, the Locks and the
   Crossing no flight reaches its body under the 24 m roofs at his pitch: not offered.
2. **For him: a full Syndicate squad of four out-ranges ten Rat Rods (all ten dead in 13 s for no damage), and a lone
   Syndicate spotter kites five Rat Rods at 20–30 m.** Balance (C12.6, his): brains recorded it on yard_open seed 3
   (laptop) and changed nothing. Whether a 40 CR scout should ever beat a 120 CR platform is a design question for him
   before any number moves.
3. **For him: nothing he would notice; the computer's squad leaders now cost 3–5 ms a tick on his laptop in every
   game.** Brains' stretch (b): an equal-answer cut in slot grounding (56 of 192 uncached `closest_point` calls a tick;
   transit stations move every update so the memo misses), priced by in-run A/B (`make ai-ab-match`), then the
   orchestrator's quiet-window number on his laptop.
4. **For him: two gang squads on auto formation ordered side by side can interleave their wings** (orders' known issue 1:
   AUTO is priced as a line; the gangs' table picks `swarm`, ≈137 m wide). Pricing AUTO as the widest shape the table
   can pick would stand five AUTO gang squads one per rank. Orders, if he sees it.
5. **For him: a squad chasing a vehicle that turns while out of sight keeps going straight for up to 10 s, then one
   crew turns round when it sees it again.** Brains' P2 limit (reported, not asserted); a turn memory or a wider
   search cone, only if he notices.
6. **Held, each as he was told it:** round 20's 6 (the garage caption "the 1 CR left buys no vehicle"; M1's yard IFV);
   the mirror-match caller line (his audio gate); rank raises the credits you bring (nothing built); the `control_scale`
   timing (needs an idle builder0); round 19's held items (the netcode guard; native code for the HUD; the camera's
   sixth-frame hitch; the exported build's two resources at quit; the missing sounds and the subwoofer; the browser).

## Round 21 launch record (2026-10-06 evening; three streams, `workstreams.md` *Round 21*) — CLOSED 2026-10-07, kept as the record

**Candidates 1, 2 and 2b launched as three streams:** **airship** (1: in his frame for a real share of every rotation
map, the fight never hidden more than today, the report reading the live rotation), **brains** (2: no bait/encircle
under ANY player order; an attack on a named target that moves is a pursuit; stretch 4 and 5), **orders** (2b: the row
of several squads capped, a second rank behind instead of 400 m abreast; the five-squad probe case; the Parade bay
slot). **Held:** 3 (CPU leaders on by default: asked again, recommended yes), 6 (the garage caption; M1's yard case is
brains' stretch c), 7. **Questions to him:** the leaders' default; how often he wants to see the airship (recommended:
as on the open maps today, never over the fight).

## Round 21 candidates (collected at round 20's close, 2026-10-06 evening) — LAUNCHED 2026-10-06, kept as the record

Each has a line **for him**, written as what he would notice (lesson 254), and the technical line beside it.

1. **For him: you played a whole match and never saw the airship.** `make airship-report` (main `0a9ce446`, laptop):
   share of the flight in his frame terminus 0 %, cut 0 %, locks 1 %, crossing 1 %, docks 3 %, sumps 10 %, pit 16 %,
   the open maps 24–31 %. It is built on every map; the pilot climbs over tall kit and stays above his frame top
   (`visible_ceiling_at`); the report's default `MAPS` is the round-11 nine. A stream owning
   `game/theme/arena_kit/airship/**`: in frame for a real share of every rotation map at his pose, the rotation in the
   report's default list, frames looked at (`make airship-look`).
2. **For him: when you attack a vehicle that runs, your scouts circle instead of chasing it; and an attack-move still
   sends one scout forward and holds the rest.** (`game_design.md` *Round 20, evening*; `build/recordings/2026-10-06T18-38-40.jsonl`.)
   Brains: (a) no bait/encircle under ANY player order (M1b widened); (b) a named-target attack on a moving target is a
   pursuit: stations lead the target, no "arrived" outside weapon range, a lone survivor drives straight at it; the
   scenario in game_design.md. **Round 21's first item with the airship.**
2b. **For him: when five squads attack one vehicle, the outer squads first drive 100 m sideways.** Orders' side-by-side
   spread gives each squad its formation's width (a gang vee ≈ 72 m), five need ≈ 400 m, the clamp pins the outer
   squads at ±116 m (foundry, `build/recordings/2026-10-06T14-59-04.jsonl`). For an attack on a named target, converge
   on it; or cap the spread. `game/control/**`.
3. **For him: the computer sets ambushes on the open maps** (M3 now hides its whole line) **at about 3–5 ms a tick on
   your laptop** — CPU squad leaders on by default is still his decision (`make skirmish ARENA=parade CPU_LEADERS=1`).
4. **For him: when the computer's holding squad is losing the trade it stays and dies.** Brains' stretch (a): the hold
   falls back one bound when losing (round 19's −1.4 ± 1.2 vehicles in the 8-v-4 stage); a new behaviour, scenario +
   paired series, DECLARED.
5. **For him: nothing you'd notice; the squad leaders' next price cut** must be measured by an in-run A/B
   (`make ai-ab-match`), not the profiler, which overstated round 19's grounding cut (brains' stretch b).
6. **For him: a suggested army opens saying "the 1 CR left buys no vehicle"** (true, odd on first sight; garage); and
   on the yard a wedge ordered 100 m forward from the spawn row has one IFV back round once (brains M1's one worse
   case, away 1.4 → 3.2 m).
7. **Held from round 20's list, each as he was told it:** the mirror-match caller line (5, his audio gate); rank
   raises the credits you bring (8, nothing built); the two instruments (7); round 19's held items (9).

## Round 20 launch record (2026-10-06 morning; two streams, `workstreams.md` *Round 20*)

**His two garage items after playing round 19** (`game_design.md` *Round 20 direction*: the vehicles seen; 25 scouts
= 1000 credits) became **garage**; **brains** takes candidates **2** (form up on the move) and the opening half of
**1** (the computer's opening lets it be ahead; the ambush hides the line as stretch). Held: 3 (the cap, his open
question), 4–9. **Question to him:** more than 25 vehicles for an all-scout army (recommended: no).

## Round 20 candidates (collected at round 19's close, 2026-10-06) — LAUNCHED 2026-10-06, kept as the record

Each has a line **for him**, written as what he would notice (lesson 254), and the technical line beside it.

1. **For him: the computer sets ambushes on the open maps, at about 3–5 ms a tick on your laptop; try it first with
   `make skirmish ARENA=parade CPU_LEADERS=1`.** Brains' posture (B2) is built and proven in CPU-v-CPU (the hold moves
   the hash on 9 of 13 maps); the price in his frame +5.1 ms a tick mean, +3.4 median, sd 4.5 over 23 bins
   (`references/round19/brains/`). Four limits written up: the ambush spot hides one point, not the line; no ambush
   unless the CPU scored first (its attack-first opening puts its line in contact before it is ahead); the hold costs
   vehicles in the 8-v-4 stage (−1.4 ± 1.2 alive per pair); the form-up stray below. Default ON is his decision.
2. **For him: a squad shuffles into its shape before it sets off, and one straggler can drive 17 m away from your
   click to its seat first.** The transit forms the wedge around the travelling anchor at the spawn and then moves
   (round 12's design); orders measured 12–20 m off a straight line in the first 5 s, and a Sumps straggler 17.7 m
   AWAY from the click. The fix is a transit design change: form up on the move, stations that start where the crews
   stand and converge over the first leg (brains' analysis; orders' three requests in its final report).
3. **For him: the Road Gangs can't spend all their 1000 credits (25 vehicles is the field limit).** Decided for him
   at 25; bigger squads are a brains contract first (`Formations.MAX_MEMBERS`), then `ArmyCatalog.MAX_SQUAD_SIZE`.
4. **For him: on a phone, a squad of five long names wraps and the five squads scroll** (garage); and the HUD's status
   block briefly says "Skirmish vs <flag>" before the garage overwrites it (`game/modes`, nobody's).
5. **For him: in a mirror match the caller says "The Condemned win it!" over your DEFEAT.** He never gets a mirror
   on his path (round 16's rule), but the harness does; a HOME / AWAY line for the caller needs new audio (his gate).
6. **For him: the results screen could show the per-ring stat sheet** (`final_score.sides[t].zones` exists; garage).
7. **For him: nothing he would notice; two instruments.** The `control_scale` click-to-order timing is unjudged on a
   loaded builder0 (needs `control-timing` on an idle box); the probe's windowed run needs a 720 s timeout; a slot
   grounded against the Parade bay's containers (orders' known issue) wants a look.
8. **For him: a rank earned by playing raises the credits you bring to a game** (his *"as players advance they get
   more credits"*): sketched in `game_design.md` *Progression* (garage stretch c), nothing built, questions listed.
9. **Held from round 19's list, each as he was told it:** the netcode guard (1); native code for the HUD (2); the
   camera's sixth-frame hitch (3); the exported build's two resources at quit (6); the missing sounds and the subwoofer
   in 5.1 (7); the browser (parked on his word); the open maps' frame cost is now measured in passing (parade is the
   cheap case; round 19's series files).

## Round 19 launch record (2026-10-05 evening; four streams, `workstreams.md` *Round 19*)

**His four items after two games on the twelve maps** (`game_design.md` *Round 19 direction*) became **orders** (1: a
formation per squad; 2: two squads, one click), **garage** (3: 1000 credits a game, every vehicle priced, squads
however he likes, one simple screen, the theme as a kit) and **board** (4: the scoreboard, in the register of a
televised sport). **brains** runs on his standing rule (smart on both sides) with candidates **10** (the CPU defends
and lies in wait, the price cut and measured so he can be asked), **4** (the Cut's stop-short) and **5** (a decision
change's own series). **Held:** 1 (the netcode guard), 2 (native code for the HUD), 3 (the camera's sixth-frame
hitch), 6 (the exported build's two resources at quit), 7 (the sounds; the subwoofer; the browser), 8 (the open
maps' frame cost: measured when brains' B3 asks for its quiet window), 9 (landed in round 18 as D1).

**Questions to him this round, each with our recommendation** (asked in the launch message; answers recorded in
`game_design.md` and the briefs): how big an army 1000 credits buys (the army he plays now); every vehicle open from
the first game (yes); kills counting toward the win (not this round: shown, not scored); one central floor or the
maps' two side zones (the maps', named); the computer's squad leaders on in his skirmish, at the measured price
(after brains' B3, with the number); the two-second slow motion after the final kill (keep).

## Round 19 candidates (collected live during round 18; started 2026-10-05 00:55 PDT) — LAUNCHED 2026-10-05, kept as the record

Each has a line **for him**, written as what he would notice (lesson 254), and the technical line beside it.

1. **For him: nothing he would notice today; a guard for when multiplayer is next worked on.** The server sends
   state to a peer in the tick it leaves (Godot refuses the send: `ready_state != STATE_OPEN`, `wsl_peer.cpp:788`;
   harmless today). Seen in 1 of about 22 checks on builder0 and 1 of 30 net-smoke runs on the laptop, always beside a
   departure (ship, 2026-10-05; excused in the two smokes' server logs only). Guard it when netcode is next opened.
2. **For him: would the game run faster if parts were rewritten in a faster language? For the unit markers and
   panels alone, about 3 %: not worth it by itself.** After round 18's two equal-output cuts the HUD's per-unit work
   is about 2.8 ms of a 40–50 ms frame on his laptop at ~64 vehicles a side; a GDExtension port of its four hottest
   loops might save half (picker, `c750f942`, laptop, headless `make hud-profile`, N=3). It becomes worth a native
   toolchain only alongside the simulation's per-unit work (brains, pathing), where the frame goes. His call.
3. **For him: a small hitch every sixth frame as the camera works out how far it may zoom.** About 1.2 refs of
   `cam.vision` is `RtsCamera`'s own vision update (`game/camera`, nobody's), including a sixth-frame zoom-cap search
   (12 binary steps of `shows_all`). Spreading it across frames removes the spike but lands a cap update up to five
   frames later: a look-and-feel change, priced not shipped (picker).
4. **For him: on one new map (the Cut) a squad on an attack-move can stop short beside one wall.** The Cut, seed 3,
   at (−4.1, 44.9): open ground 6 m from a city block's face; the re-seat fires its 3 allowed times and the squad
   stops 105 m short with one crew 18.5 m off its slot (brains; a limit of round 18's "his squads on a task arrive").
5. **For him: an AI change can pass the regression check unseen on his most-played map.** The per-map baseline
   sees layout and movement changes; a decision change (round 18's peeking rule) moved three of seven lines because
   the 40 s baseline matches on the Terminus, the Crossing, the Sumps and the Locks hold no bait at all. No cheap
   extra line saw it on all six dealt maps (ship's `make sim-variants`). A decision change needs its own series.
6. **For him: the game holds two things in memory when he quits mid-match in the exported build** (`desktop-smoke`
   red in `check-all`: "2 resources still in use at exit"; unseen since round 17's gate; maps is naming them).
7. **Held from round 18, each as he was told it:** turrets turning, tanks colliding and about ten other events make
   no sound (9); on a 5.1 system every sound also goes to the subwoofer, so play in stereo (10); the browser version
   is too slow at his army size, a host often fails to open a room, and it sometimes crashes (7, 11, 12: parked on
   his word that the native game never bends for the browser).
8. **For him: how the new open maps run on his laptop is not measured.** `make perf-play PERF_PLAY_ARENA=parade`
   against `sumps`, interleaved, needs a few quiet minutes of his laptop with windows opening on his desktop; not run
   in round 18.
10. **For him: the computer never sets an ambush, on any map; teaching it to costs frame time on his laptop and
   needs it to DEFEND sometimes, which it never does today.** Measured in round 18 (brains): in his skirmish the
   CPU runs no squad leaders (elements off), and its commander never issued an ambush order. Built on `stream/brains`
   (unmerged at the round's close unless stated in HANDOFF): `AmbushSite` + the commander choosing ambush (a line
   element out of contact lies hidden on the flank of open ground the enemy must cross, within its shortest
   effective range; drops it after 30 s unsprung; one ambusher at a time). It fires CPU-v-CPU with elements. On his
   path it NEVER fires in time on parade: the bays sit at mid-depth, both sides race for the centre, a CPU leaving
   its base needs about 100 m at 7–8 m/s to reach a bay and his line about 77 m at 9 m/s to reach the kill zone
   (his squad across parade v the CPU commander, 8 seeds: 0 ambushes taken with the in-time rule; before it, taken
   7 of 8, sprung 5, from a bay never). **A bay ambush is possible only when the CPU is already there: a posture
   "hold the depot, ambush the crossing"** (when its depot is threatened or it is ahead on points) is the design
   to make. **The price of CPU elements on his laptop** (the orchestrator's quiet-window run, 2026-10-05, his path,
   parade and the Sumps × 2 seeds, at equal vehicle counts): +6.5 ms a tick on average (+20 %), median +4.6, up to
   +14, strongly seed-dependent; frame avg 69 → 94, 97 → 119, 97 → 124, 118 → 151 ms. The cost is the element
   machinery itself (navmesh grounding of slots, the tactics layer, the order feeds), not the ambush search. Whether
   the CPU runs squad leaders in his skirmish is HIS decision; not put to him in round 18 because it would have
   cost him that and shown him no ambush.
9. **For him: in open ground a moving wedge or column does not watch its flanks; a computer-ordered line bunches
   up and stops a few metres off its places** (brains' D1–D3, measured on a bare plate; the fix is doctrine for both
   sides; may land in round 18 if time allows).

## Round 18: what it delivered (CLOSED 2026-10-05; `HANDOFF.md` *ROUND 18 IS CLOSED*)

- **The formation picker** (picker): a panel of every formation as its shape, opened by resting on Formation; an
  animated preview and a "fits here / squeezed here" line from the real seating; G still cycles. Three equal-output
  HUD cuts and `make hud-digest`.
- **Six candidate maps** (maps), **all six DEALT after the close on his word (2026-10-05, `da0bdef3`; the rotation is twelve):** `parade` (v3: an open floor between two bays), `gorge`, `archipelago`,
  `cut`, `docks`, `yard_open`; the CANDIDATE class; `make arena-room` (room for a line of four, chokepoints,
  flank-ambush ground); his page with KEEP / CUT (unanswered at the close).
- **The champion `x18m`** (brains, CP1): no unit shows itself to a gun it knows is laid on it; three baseline lines
  adopted; the round-15 red scenario green. **His squads on a task arrive** (D4, D5, D5b) and watch their sectors on
  the move (D1). `make element-digest`, `make ai-element-perfplay`.
- **No mid-match shader freezes** (finale): `ShaderWarmup` behind a loading screen that holds for it by contract;
  glow on the feed; the banner below the kill; the exit leak fixed in the quit paths; `make end-frame-measure`,
  `make quit-leak-arms`.
- **The check** (ship): a baseline line per dealt map; shards that exit clean and fail on a crash; every recipe
  reading exit codes; the copy-back fixed; an intermittent known-red marking; the scenario count recorded and
  checked by one definition.
- **Not delivered:** the computer ambushing him (candidate 10 below; the code is on branch `stream/brains`).

## Round 18 launch record (2026-10-04; five streams, `workstreams.md` *Round 18*)

His two items after playing round 17 became **picker** (A) and **maps** (B). From the numbered list below he took
**6** (*"Yes make the CPU smarter, this would apply to all units"*) and set the browser aside (*"I don't want to
sacrifice anything on our game to accomodate browser play"*: 7, 11 and 12 held). **brains** takes 6 and the CPU's
doctrine in open ground (the note under B); **ship** takes 1 (the baseline sees every dealt map) and 13 (the test
shards' leaks); **finale** takes 8 (the freeze at the final kill), on the orchestrator's recommendation; maps takes 4
(the turning pocket). Riding as stretch: 3 (brains), 5 as a written design only (finale). **Held for a later round:**
2 (the HUD's per-unit work), 9 and 10 (the missing sounds; the subwoofer in 5.1), 7, 11, 12 (the browser). His words
and the two standing rules they carry (smart on both sides; the native game never bends for the browser):
`game_design.md` *His pick*.

**For him, each held item in one line** (lesson 254): 2 the unit markers and panels cost frame time on the laptop;
3 long vehicles scrape along containers, worst on the Sumps; 9 turrets turning, tanks colliding and about ten other
events make no sound; 10 on a 5.1 system every sound also goes to the subwoofer, so play in stereo; 7 / 11 / 12 the
browser version is too slow at his army size, a host often fails to open a room, and it sometimes crashes.

## Round 18 candidates (collected live during round 17) — LAUNCHED 2026-10-04, kept as the record

**The lead's two items after playing round 17 (2026-10-04, his words in `game_design.md` *Round 18 direction*). These
come first; the numbered list below is ours.**

A. **The formation button becomes a picker** (control/HUD). Today G and the button step through five formations blind
   (`RtsControls.cycle_formation`, `FORMATION_CYCLE`); he wants a panel that opens on mouseover showing every formation
   as its shape, one click to pick, and the "sleek visualization" on hovering each one. The parts exist: the tactical
   map's picker cards (`tactical_map.gd` `PICKER_FORMATIONS`, `CommandIcons.FORMATION_INFO`) and the task buttons'
   animated preview (`TaskPreview`). Small: one stream's first item, his eye is the check.
B. **New maps, by experiment** (a map stream told to be creative): *"room for vehicles to maneuver, perhaps some
   chokepoints … opportunities to really use formations like screens and ambushes"*, and first of all **a large open
   centre with cover placed so a line abreast crossing it can be ambushed from the flank**. Measured: no lane on any
   dealt map fits a line of four at its 12 m spacing (lanes are 12–30 m; a line of four needs about 36 m). Several rough
   candidates, he plays each, nothing is dealt except on his word. Depends on candidate 1 (the baseline sees one map)
   and wants brains beside it: the CPU's doctrine has never been measured in open ground.
   **Where the brains assume corridors (brains, 2026-10-04, from reading, not measured):** (i) the far-unit levers key
   on `LOD_RADIUS` = 130 m and weapon reach, so in open ground more units see each other and far-idle saves less; (ii)
   movement's planned-reverse / k-turn, chord and guard logic and avoidance's 14 m neighbour radius were tuned in
   12–30 m streets (`navigation.md` rounds 7–15) and mostly go idle in the open; (iii) `TacticsFormation.DEFAULT_SPACING`
   is 12 m and a slot's leash is the element's pitch (14 m for tanks), so a line of four needs ~36–48 m, which has
   never been played: the CPU's line-abreast seating and `SlotGround.standable_for` have only run squeezed into
   lanes; (iv) doctrine's drills fire on contact geometry, and nobody has checked whether any assumes a wall on one
   side: read `game/tactics/drills.gd` first.

1. **The sim baseline covers one map** (yard's finding, 2026-10-03): `sim-baseline` and `determinism` run on `foundry`,
   which has no containers, so a change to any dealt map's layout, cover or lanes is invisible to both. A per-map
   baseline (one short seeded match per dealt layout) priced in check minutes; ship owns the check's composition.
2. **The HUD's per-unit work at its GDScript floor** (held from round 17's candidates: item 2 below).
3. **A planned back-and-fill has no margin beside a container** (yard's witness, 2026-10-03, the Terminus avenue): the
   same manoeuvre is clean or plants a 14 m rig into a 40 ft box for 9 ticks depending on centimetres; suspect
   `_outline_ok`'s start tolerance and its 10 samples (`game/ai/movement.gd`). Two avenue kerb boxes are held square in
   `make_arenas.py` until it is fixed. Brains is judging it this round; a fix is a declared behaviour change.
   **Decided round 18 (2026-10-03):** yard's count over 8 seeds × 4 maps showed no rise in planned-leg contacts from
   turning the containers (the holds were removed; flush kerb boxes keep their block's angle instead). What the count
   did show: long hulls plant 16–58 times and scrape 300–500 times a minute on EVERY layout — the standing state of
   rigs in streets, measured for the first time (`make container-contacts`). The Yard read higher turned (32.7 → 45.7
   plant × kturn a minute, 4 of 8 seeds): take 16 seeds when the fix is tested.
   **At strength B (CP2, his choice):** planned-leg contacts stay within the seeds' spread of square; **route
   scraping on the Sumps is higher on 7 of 8 seeds (449 → 583 a minute)**, lower on the Pit and the Terminus, flat on
   the Yard. Not gated; the routing class, on his most-played map. Where on the Sumps is in yard's round-17 Status.
   **Attributed (yard):** of +1,548 steer ticks at B over 8 seeds only +150 are containers; the rest is terrain rims,
   the perimeter, wrecks, floodlights: the turned map sends the fights along different routes. So the item is the
   Sumps' ROUTES for long hulls, not its boxes.
6. **The champion brain baits into a loaded gun** (brains' diagnosis, 2026-10-03, laptop, `ec31e419`):
   `scenario_cover::test_peeking_while_the_enemy_reloads_takes_fewer_hits` has been red since round 15 because the
   BEHAVIOUR is wrong. The reload-window brain shows itself while the enemy gun is loaded; the gun fires ~35 ticks
   later, the brain ducks on that tick, and the shell lands 14 ticks later while it is still in sight (it breaks line
   of sight ~60 ticks after the shot): 4 hits / 4 shots, the same as the brain without the feature, and it never
   shoots inside the window it baited for. Fix = a decision change in the champion (`x5p` carries `reload_windows`):
   peek only while the enemy gun reloads (AiTickCache estimates it), or bait only when shell flight exceeds the time to
   break sight. Moves parity and almost certainly the foundry baseline; wants its own ladder run.
   **Why it broke (brains):** round 15's N5 made gunners lay before firing, so the bait was changed to stay out until
   the round is on its way; at duel range the shell lands ~14 ticks later and breaking sight takes ~60. **It is in his
   skirmish, on both sides:** the bait applies to any visible contact and the champion carries `reload_windows`, so
   CPU units hand his units free hits and his own units do the same from cover. Try first: no bait, peek only while
   the enemy gun reloads (`contact.gun_ready_in`) or after it fired at someone else; the scenario becomes "no more hits
   than x3, every peek starts inside a window" plus a two-target stage. **Fixing it makes the CPU harder: the
   difficulty side is his call.** Brains' Status (round 17) has the trace and both rules.
7. **The browser build's frame rate** (ship's sweep, 2026-10-03): his fight at his army size runs at 3.4–4.9 fps in
   headless Chrome on the laptop's GPU (8–11 under guns' conditions); the native build on the same laptop holds ~20–25.
   Every browser decision of round 17 (voice, faction art, the mix) sits on a build that is not playable at that size
   on that machine. What limits it (the tick in a single-threaded wasm, or the GPU path) is not yet measured; the real
   window on builder0 is. Candidates: a threaded web export, a smaller default army in the browser, the brains' levers.
8. **A multi-second frame stall at the final kill** (sim, 2026-10-03, the laptop under load, his window): the two
   frames around the last kill took 1.7 s and 3.4 s, on the old and the fixed kill cam alike — likely a first-use FX or
   shader compile at the kill burst / the DEFEAT banner. It is the last thing he sees in every match. Measure it on a
   quiet laptop first; a warm-up of those effects at load is the usual fix. And his call: the tick-counted kill cam now
   lasts as long as 60 ticks take (~5 s on a loaded laptop, 2 s where the game keeps up) — `KillCam.HOLD_TICKS`.
9. **The sounds still missing, ranked by how often he would hear them** (guns' audit, 2026-10-03; laptop, a headless
   probe in an archive copy of `3d7891ab`, his Sumps match, 146 s to the control win, two identical runs, map-wide
   events a minute): turret traverse 474 starts (~35 % of alive time), silent; hits doing under 5 damage 46, playing a
   damaging hit's clank; tank-to-tank collisions 44, silent; pinned 39, silent; a tank into a wall or prop 26, silent;
   rocket-truck deploy / pack 13 / 10, silent; onto a bridge deck 6.2, silent; friendly fire 2.0, a generic hit;
   non-primary objective captures 1.2, silent; repair 1.6; resupply / ammo empty 0.8 / 0.4. Water, orders and the kill
   cam read 0 on that match (no water on the Sumps, CPU sides issue no orders, it ended by control): count them on a
   match that has them. The turret and the weak hit sit in `weapon_fx.gd` and the tank code (lines to lend); friendly
   fire and objective captures touch the booth. Full table in guns' round-17 Status.
10. **In 5.1 the subwoofer gets everything** (guns' stretch, 2026-10-03; laptop, a 6-channel null sink): Godot opens
   real 5.1 and keeps the booth and music on the fronts, but every 3D sound also goes full-range into the LFE at a
   constant −11.2 dBFS whatever its bearing (a 1 kHz tone at eight bearings); on his match the LFE below 120 Hz reads
   −20.1 dBFS against the fronts' −29.1. With a receiver's +10 dB LFE gain the sub booms. Engine panning: not
   reachable by a bus effect. Until fixed he plays in stereo / 2.1. A real LFE design (the sub layer of the guns
   routed on purpose) is the round-18 form of his "feel the action". Arena acoustics as a runtime system (slaps off
   the stands and container walls keyed to the shot's position) is the other undone audio stretch.
11. **A browser HOST often fails to open a room** (ship, 2026-10-04, `f5b2226c`, laptop and builder0, headless Chrome
   with software GL): its first frames take ~4 s each, the relay socket is still CONNECTING at 6.0 and 10.7 s, the
   broker's 10 s `handshakeTimeoutMs` passes with no `host` op, the socket closes 1006 at ~14.5 s, and
   `game/network/relay_peer.gd` ends the unseated session as `connection_failed` and never retries. A real host on a
   slow machine can hit it. Fix on the netcode / broker side: retry an unseated host, or do not start the deadline
   before the client can send. (`relay_peer.gd` also has no handshake timeout of its own: sim.)
12. **A wasm trap in the browser build: 'uncaught exception: function signature mismatch'** (ship, same runs): after the
   room opened and the client passed; 1 in 3 with the faction pack on, once with packs off, so not the pack mount.
   Owner unknown (engine-level; maybe an indirect call through a freed object). The web smokes now print the stack.
13. **The test shards leak at exit** (ship's engine-log gate, 2026-10-04): shards 0, 1 and 3 print, after their own
   `0 failed` line, `414 ObjectDB instances leaked at exit`, `14 CanvasItem RIDs leaked`, `10 resources still in use at
   exit`, and RID allocations (DummyTexture 41, ShapedText 121, Font 3). Allowed for the `test` target only, visibly
   (the gate prints the count each run). Run one shard with `--verbose` to name the objects; free them; drop the
   allow-list lines. No smoke and no player path prints a leak line.
5. **Slow motion is half a simulation** (sim's design notes, 2026-10-03; his call, presentation): while
   `Engine.time_scale` is below 1, motion and `sim_seconds` run slowed but every tick-counted rule (reload ticks, the
   brains' think cadence, intel every N ticks) runs at full rate. Harmless after a decided match (the kill cam, now
   tick-counted); wrong in a LIVE match under tactics' `--slow-motion=`. Either slow motion scales the tick rate, or
   tick-counted rules become time-counted. And: windowed and headless runs differ after a decided elimination by
   design (headless has no kill cam) — fine, as long as nothing measured runs past the end.
4. **The lane validators cannot see a turning pocket** (same finding): a 14 cm intrusion into a 17.56 m avenue passed a
   12.14 m bar.

## Round 17 launch record (2026-10-03; five streams, `workstreams.md` *Round 17*)

His two items after playing round 16 (containers square to the grid; gunfire without power — then widened in chat to
impacts by surface and an audit of silent events, with the ElevenLabs spend authorised) became **yard** and **guns**;
candidates 1, 3 and 4 below became **brains**, **sim** and **ship** (ship also takes the check's `scenario_perf` hole,
the garage tour and a desktop boot). His words: *"I want all 5, go"*. Candidate 2 (the HUD's native move) is held for
its own round. Still his, unscheduled: the two defeat music placements and the garage's two blues (his ear), the
airship's edge-pan caveat (his pit playtest), whether Law's lamps stay, the next PA batch when he asks.

## Round 17 candidates (collected live during round 16) — LAUNCHED 2026-10-03, kept as the record

**IN, from the lead (2026-10-03, his words and the measured state in `game_design.md` *Round 17 direction*):**

- **A. Containers that look placed by people** (a `yard` stream: `tools/make_arenas.py`, `arenas/*.json`,
  `game/theme/arena_kit/containers/**`): 93 % of 668 containers sit at exactly 0° or 90°, and a stack's levels move
  ±0.6° / ±4 cm, which nobody can see. Ground level turned for real by a few seeded degrees (mirrored halves turned as
  mirrors), upper levels visibly offset; the sim baseline moves once, on purpose; lanes, cover tables, nav and fairness
  re-proved; before/after frames of every map at his pose on a page for his eye.
- **B. Guns you feel on a living-room system** (a `guns` stream: `game/theme/audio/**`, `tools/audio/**`,
  `assets/audio/**`): Abrams for the tanks, Bradley / Apache chain gun for the IFVs, heavy machine guns for the scouts,
  explosions too. Separate source, mix and format before spending: today's shots are mono, the tank is 77–91 % below
  200 Hz with under 1 % above 2 kHz (no crack), the machine gun sits at −13 dB. An audition page (two or three
  directions per weapon, in the real mix) for his ear before any batch; ElevenLabs is lead gate 1.

**His pick (2026-10-03): all of the recommended set** — 1 the think-rate lever (brains), 3 the Sumps fork (sim), 4 the
browser's voice with the check order (ship); 2 the HUD's native move held for its own round:

1. **A sub-idle think rate for far, idle, off-camera CPU units** (brains, from the lead's question *"lowering the
   frequency of thinking combined with sharding"*, 2026-10-02): cadence and sharding already exist (10 / 5 / 3.3 thinks a
   second by LOD, staggered; on an average tick 7.7 of 50 brains think); thinking is 4.8 ms a tick against 6.7 for
   per-tick execution at 50 vehicles (builder0), so halving the think rate buys at most ~2.4 ms. A PRICED lever, OFF
   behind a variant for his call: wakes on the existing triggers, never applies to his own units; its behaviour cost
   measured with the ai ladder, the drills and scenario counts, K1 latency, and first-contact/first-shot over 16 seeds.
2. **The HUD's per-unit work at its GDScript floor** (hud, laptop idle load, `3cf5e729`, 30 s, ~31 a side): the three
   biggest remaining per-frame lines, each a candidate for a native (GDExtension) or MultiMesh move — `SelectionMarkers.refresh`
   311 µs a frame ≈ 4.9 µs per vehicle (a native MultiMesh buffer write); `ElementAwareness`'s contact search 282 µs ≈
   0.29 µs per friendly × enemy pair over ~960 pairs (a C++ nearest-neighbour); `vision_state` + the horizon search 307 µs ≈
   3.2 µs per own unit plus a sixth-frame spike (`VisionRegion.contains` / `seen_fraction` in C++). Then radar blips 238,
   callouts 184, UnitBars 146 µs. The 1.5 ms game+UI budget needs these; GDScript cannot reach it at tick = frame.
3. **The Sumps' windowed-only fork at ticks 601–630** (sim, round 16): after the fire-RNG fix the headless Sumps is
   identical to tick 900 and the windowed Terminus to 870, but windowed Sumps pairs fork in the same 30-tick window in
   2 of 3 pairs, and the pair that hashed every tick from 560 (changing the frame pacing) did not — a timing-dependent
   input on the windowed path, not an RNG; nothing in ai, tactics, control, match, tank, combat, units or arena reads
   frame time, the camera or the wall clock for a decision. **The bridges/water suspect is KILLED (sim, read-only): the Sumps' bridges are static
   decks built once by `ArenaTerrain` as floor boxes; the physics census finds only `StaticBody3D` boxes on every map; the
   theme side creates no collider or nav region and its only `_process` is the light show.** The timing-dependent input is
   elsewhere on the windowed path — a bisect of the windowed-only layers is the next step. Witness: `make windowed-repeat ARENA=sumps
   REPEAT_EVERY=5 REPEAT_UNTIL=640 REPEAT_FLAGS=--hash-detail-from=600`, or bisect the windowed-only layers (the
   airship, the cutaway, the bridges' theme side). Until found, a windowed Sumps A/B across runs is two fights.
4. **Does the browser build have a voiced announcer?** The Web preset's `exclude_filter` excludes
   `assets/announcer/clips/*` (booth's round-16 merge note). A fact to establish, then his call on the web pack size.

## Round 16 launch record (2026-10-02 evening; six streams from his words, `game_design.md` *Round 16 direction*)

**A performance round:** *"the game is getting extremely choppy … before sacrificing any of the existing graphics or
gameplay let's find (or profile our code) where we can just get better performance"* — plus three items of his: the
opponent randomised in `make skirmish`, the title music through the loader, the announcers' thin pools. Measured at
launch on his laptop at his window: 30 vehicles → 36.9 ms a frame (tick 24.0, GPU 19.8); a locked 30 holds at 10.
Streams and contracts in `workstreams.md` *Round 16*: **brains** (the AI's share of the tick, no decision changed),
**sim** (the visibility field, intel's O(n²), the cached accessors, `Units.stat`; then Law's APC on tracks = candidate 1
below, CP2), **render** (the GPU's 20 ms, the picture proven unchanged), **hud** (redraw on change), **play** (`make
perf-play` = CP1, the trace, his two items), **booth** (the pools, his veto page). Candidates 3–6 below are carried.

## Round 16 candidates (from round 15's Status reports; his call on the order)

1. **Law's new APC behaves as tracked** (his words, 2026-10-02: *"if it is now a tracked vehicle it should behave as
   one"*): `law_ifv` locomotion wheels → tracks in `units.gd` (fleet's carve-out), whatever the tracked turning model
   implies for a 6.26 m hull, frames at his pose; a sim change — pre-register by the path, attribute both arms, a CP
   if the baseline moves. And whether the lamps stay now that the shapes differ (his call, unasked).
2. ~~**The airship page's answer**~~ tapped C and SHIPPED (2026-10-03; `view_rest` + `view_low` ON, `camera_lift` OFF).
   Still open: airship's edge-pan caveat (two rendered worst frames after big camera moves) — his pit playtest, or a
   measured run with the instrument's edge-pan on. **Next-closest pairs** for the lineup: Gangs' Gun Truck/Rat Rod 0.73, Syndicate's
   Limousine/Skimmer 0.72.
3. **Nav: an approach speed for the route's next corner** (nav's next step after V2 fell): the ease-off before a
   full-lock arc hits, keyed like V1; and the circle rule's reverses (`route/reverse`) still unconsulted.
4. **The garage's third list** (garage's Status): whatever the round-15 tour found next.
5. **Audio, carried:** the two defeat placements for his ear; the garage's two blues; the next PA batch when he asks.
6. **Housekeeping:** `scenario_perf` refused in every full check of the night under five streams — a lower-load
   check order (perf first, alone) or a dedicated quiet slot on builder0.

## Round 15 candidates as they stood at round 14's close (LAUNCHED 2026-10-01 evening as nav, airship, squad, garage, fleet — `workstreams.md` *Round 15*; items 1–5 went into the briefs; 6 is his ear)

1. ~~**The airship's view-climb ON or OFF**~~ decided 2026-09-28: ON by default (`game_design.md` *Round 14: the
   view-climb decided*). Still open: the 39–49 s intrusion cluster airship saw on every map, unchased.
2. **N3 keyed by hull class or plan purpose** (nav's write-up): a War Rig wants a planned leg to really stop and
   reverse; an orbiting scout wants a brake tap; `nav-scenario-arms` is the gate that must stay green. Plus N5: a
   planner that looks earlier from a moving hull (first legs planned inside the stopping distance).
3. **The gang doctrine's encircle/bait verdicts have flipped since 09-16** (squad, ONE seed: encircle on → enemy
   survival 0.66 → 0.002; bait now costs the pack 0.258 → 0.196 alive). Re-measure on seeds before believing it; C12.6
   means it is his call to change the tables.
4. **The tactics ladder across the time-limit rule:** ELO from `winner` is not comparable across `5f562dd0` for
   matches that hit TIME=240 (squad's note); re-baseline the ladder before the next ablation.
5. **Garage G7's next list** (garage's Status): whatever the second tour found.
6. **Two music placements for his ear** (carried from round 13); the next PA batch when he asks.

## Round 14 candidates as they stood at round 13's close (LAUNCHED 2026-09-27 evening as airship, garage, nav, squad — `workstreams.md` *Round 14*; items 1, 3, 4, 6, 7 went into the briefs; 5 is his ear; 8 waits on him)

1. **The airship steers clear of the player's view** (his words, verbatim, in `game_design.md` *Round 14 direction,
   first item*): *"frequently when we're playing the airship flies right in front of the camera and disrupting the
   game … make the airship smarter and try to avoid blocking the player's field of view"*. Where things stand: the
   pilot (`game/theme/arena_kit/airship/airship_pilot.gd`) chases a carrot circling the fight and the camera lifts
   itself out of the hull (`RtsCamera.clear_pose`); he wants the dependency reversed — the carrot avoids the camera's
   frustum, the airship stays visible and opaque (transparency refused, his round-10 words), the venue keeps it. The
   shape of the item: the carrot's goal gets a "not in the player's view" term (the frustum from the live camera pose
   is known every tick; the fight's centre is what the player is looking at, so "circle the fight" and "stay out of
   the view" pull against each other and the measure is the share of a match the hull occupies the frustum, at his
   pose, before and after); the climb-over rule and the PID stay. Measure first: how often and for how long the hull
   is in the frustum on the Terminus over 240 s today (the airship stream's `airship_report.gd` is the instrument to
   extend). Stream: airship (paths as round 10's airship stream, plus read-only `RtsCamera` pose).
2. ~~**S6 ON or OFF**~~ decided 2026-09-27 evening: ON, the toggle documented at the code site (`game_design.md` *Round 13: S6 decided*).
3. **The garage list** (audio's Status, in the order a player hits them): the starter army leaves no room to add a unit;
   the turntable shows a short turreted tank while the match fields the dozer-bus (the hull-box fit is not applied on
   the turntable — theme-side); a stalemate time-out reads DEFEAT (or VICTORY) by chance; the camera readout sits over
   the HUD at 20:9 (or should be off for players); the loader shows a command-card tip on a garage load; delete
   `catalog_stub.gd` (dead since catalog v2).
4. **Nav R4 — the other 53 %:** after the give-way fix, route legs (38 %) and k-turns (15 %) are the rigs' remaining
   reverse-gear contacts; R1's buckets name them (`references/round13/nav/r1_yield_buckets.txt`). And the fight-maps
   stall share that rose on 7 of 12: does a rig that holds instead of yielding block the street behind it?
5. **Two music placements by title, for his ear** (`defeat_hunt`, `defeat_ragnarok`): `make garage` → FIGHT → lose, or
   `make remote T="audio-pass PASS_SECONDS=90"`. And whether the garage's two blues are right.
6. **`make tactics-drills` fails 2 gang-pack assertions on main already** (not in `check`; same with S6 off and on).
7. **`scenario_perf` under builder0 load** (round 12's housekeeping item): make it refuse rather than judge when the box
   is loaded — audio's first check went red on it again this round.
8. The next PA batch when he asks (his *"ok"*); the web release's 29 MB pack (closed: fine).

## Round 13 launch record (launched 2026-09-27; three streams from his answers below, `game_design.md` *Round 13 direction*)

His answers to the list: 1 clarification owed (started on the orchestrator's recommendation, his veto stands) → **nav**;
2 *"Default wedge"* → **squad**; 3 measured → **squad**; 4 *"leave"* → closed; 5 *"29 MB of music is fine"* → closed;
6 garage music, and the garage has never been smoke-tested → **audio**; 7 *"ok"* → next PA batch when he asks; 8
*"don't worry about this"* → closed.

## Round 13 candidates as they stood at round 12's close (kept as the record)

1. **Right-of-way sized for long hulls** (nav): the back-and-fill's declared cost is rigs' reverse-gear contacts +57 %
   (giving way back into walls with round 6's small-hull yield spots); on the rotation, stalled share fell on 10 of 12
   runs and wall contacts rose on 9 of 12. The honest next step; the multi-leg planner's N5 write-up says when a
   kinematic planner would earn its keep.
2. **Column or wedge for a Condemned/Law plain move** (squad's S5): wedge faster in 23 of 32 paired runs; column wins
   only the yard's chokepoint. Recommended: wedge in lanes and open ground, column in dense. **His call, frames in
   `streams/references/round12/squad/`.**
3. **Squad's S6 candidate** (dropping the idle `face` on a no-pivot hull with nothing in sight): pre-registered with its
   signature; measured AFTER nav's bound, which is now on main.
4. **The partial or mixed selection** (squad's S4): scatters by his round-10 design; recommended leave. His call.
5. **The web music pack** (13 → 29 MB, all in the web build): decide at the next web release.
6. **The garage has no music** (nothing plays the `garage` state); the two placements by title, not by ear
   (`defeat_hunt`, `defeat_ragnarok`).
7. **The Locks' open canal**, on arena's water page, after he has driven it.
8. **The next PA batch** carries the boundary read from his ten vetoes (the joke lands on the venue, not on the crews'
   or fans' bodies and homes) as a thing to test.

## Round 12 launch record (2026-09-26 evening; six streams; kept as written)

The list below went to the lead on 2026-09-26; he approved it with two corrections (`game_design.md` *Round 12 becomes
a round*) and asked for workspaces. Where each item went:

| item | stream | note |
|---|---|---|
| 1–2 camera asks the collider; the cutaway misses the ad screen | **camera** | |
| 3 the War Rig's muzzle | **fleet** (stretch) | measured before moved |
| 4 water reads black | **arena** | plus the Locks question on its page |
| 5 the bus mesh | **fleet** | `bus_r11_i` and `q_r11_bus_fit` were APPROVED on the page 2026-09-24 17:27 UTC and never recorded |
| 6 the War Rig's `kturn_none` | **nav** | |
| 7 the burner as a fire engine | **fleet** | **`burner_r11_b` APPROVED 2026-09-24 17:27 UTC, never read back, never built** — his "I haven't seen that materialize" |
| 8 the AUTO icon lies | **squad** | carve-out into `command_icons.gd` |
| 9 a G-chosen formation is overridden at `_halt` | **squad** | |
| 10 ~~the direct path still scatters~~ | **squad** (answered, round 12 S4) | measured on the default path: a whole squad takes the task path and travels as one column; a PARTIAL (3 of 5) or MIXED (2+2) selection goes direct and each crew takes its own route (and leaves its squad). Left as the lead ruled on 2026-09-20 (FORM SQUAD / Ctrl+N makes it a squad); the question whether a partial selection should travel as a formation too is his (squad brief Status) |
| 11 the announcer's filler and the music rotation | **audio** | the `trade` pool is 5 lines; `pre_match` has ONE bed and 23 Suno tracks were never imported |
| the fall-in rule (from the anchor's write-up) | **squad** | |
| the Locks' open canal, re-asked after he has driven it | **arena** | on its page, with the 45 % exposure number |

## Now: round 12's candidates as they stood on 2026-09-26 before launch (kept as the record of the order)

**1-2. The drawing and the simulation disagree about where things are** (airship + fleet, `verification.md`) — take them together:

1. **The camera asks the collider when it means the silhouette.** `RtsCamera.roof_over` / `clear_pose` /
   `sight_blocked` read `Arena.active["obstacles"]`, which are collision boxes. A floodlight's collider is 3 m and its
   drawn mast is **16.05 m**, so the camera can sit inside the lamp head — its tilt range reaches it at about 18°, and
   the lead's default pose is 21°. `sight_blocked` never sees a 20.7 m LED wall whose collider is 1.4 m. **The fix is
   to feed a drawn-extent table into those reads (`AirshipFlight.DRAWN` already exists and is tested against the
   meshes) and never to grow the colliders**, which would move gameplay and the sim baseline.
2. **`BlockCutaway` never cuts away an ad screen.** `_gather` keeps obstacle shapes ≥ 6 m tall; a 20.7 m ad screen
   with a 1.4 m collider fails that test, so it is never hidden when it stands between the camera and the fight. This
   is the same class as the complaint that produced the round-9 cutaway ("the camera ends up inside a building and we
   can't see what's going on"), on an object the rule cannot see. Blocks are unaffected — theirs is the one collider
   that matches what is drawn.

Both are read from the code, not seen in play. Neither was taken in round 11 because the camera is a design change and
round 11 was a defect round.

3. **The War Rig's muzzle** (fleet): the SIMULATED pivot stays in the tractor frame, so the drawn gun is ~0.45 m
   sideways of where rounds leave at a 35° bend and ~0.7 m at the 65° jackknife limit. Same family as 1-2; deferred
   from round 11 because it is a simulation change the lead did not report and it needs its own "can a player feel
   it" measurement.
4. **Water reads black** (`arenas.md`), his choice of next round over tonight, on three maps now.
5. **The bus mesh**: image-to-image keeps the reference's proportions (lesson 215), so the approved concept came back
   a van at 1.85:1 against a 3.34:1 box. The way through is a reference carrying the PROPORTION alongside one
   carrying the LOOK; one test concept was authorised.
6. **The War Rig's `kturn_none`** (nav): 130 against 64 kturns — a 14 m hull with a 12 m radius in an 18-22 m street
   often has no valid 8 m back-up. The one measured sign that a longer search or a kinematic planner would earn its
   keep, and the honest answer to "is the planned reverse enough".
7. **The burner needs its own unit type** (his words: it "looks identical to the tank"); fire-engine concepts are the
   brief.

**From the lead's fine-tuning session (2026-09-26, `doctrine.md` *A plain move travels AS a formation*), three
follow-ups the travelling anchor deliberately did not take:**

8. **The AUTO formation icon lies** (control): `command_icons.gd` shows a wedge for AUTO whatever the doctrine picks,
   and on the maps he plays (dense terrain) the pick is a column. Show the leader's actual pick on the card and icon.
   Then decide whether "dense → column" is the right row for a plain move on the yard-type maps.
9. **A G-chosen formation is overridden at the end of a drills-on move** (squad): `ElementPlan._halt` takes the table's
   halt shape (coil, herringbone) and ignores `task.formation`, so a chosen wedge dissolves into a coil on arrival.
10. **The direct path still scatters** (control): a box-selection that is not a numbered squad goes through
    `Orders._resolve_group`, one route per vehicle to its slot. Either give it the anchor or route every multi-unit move
    through a squad.
11. **The announcer's filler and the music rotation** (audio, his words in `game_design.md` *Round 12 direction*):
    *"they are trading in the middle of the floor"* repeats; whether the fight beds rotate between matches.

**Carried forward, not scheduled this round** (from round 10's archived Status lists, the previous candidate order):

## Next round (12): the first art/terrain item is already decided

- **Water reads black: make it wetter** (the lead, 2026-09-24, on arena's round-11 page; he chose next round, not
  round 11). The diagnosis, the maps, his pose, the frames and arena's suggestions are in
  [`arenas.md`](arenas.md) *Water reads black*. Owner: whoever owns `game/theme/arena_kit/terrain/`.
- **Ask him about the Locks' open canal again** once he has driven it (the orchestrator ruled "leave it open" on
  2026-09-24); put the exposure number beside the question (centre sees 45%).

## Round 11 candidates as of round 10's close (each archived brief's Status has its own list)

1. The driver creeps out of a two-sided pinch before pivoting (nav/squad), then the yaw constraint flips ON
   (combat: the four bars plus drive-to-slots on one build).
2. The checkerboard-staggered deploy (squad/arena) so packed spawns stop clipping on the first dressing turn.
3. The drive test over paired seeds with a seed knob that moves spawn order (nav); the press escape judged on it.
4. Squad's incoming-fire disc site cell, and the two remaining disc sites (combat's series).
5. The blimp on every shipping map (feel); the Pit's west-gate readability (arena); yard's lanes (arena, report only).
6. The lead's taps: the bus and the fire engine 3D (feel); show's four questions; the rim light; announcer vetoes.
7. Cover-peeking re-measured on paired seeds (squad); the seam's next step (the funnel, nav + squad).
8. The hinge bench and show's perf re-measure in a quiet window if round 10's window does not land them.

## Round 5 (historical header kept for the links below)

Round 4 is merged and green (843 tests). The next round starts from the lead's playtest and the open items in
HANDOFF.md: the renderer's per-instance uniform limit at 30 a side (nobody owns `game/theme/**`), the road gangs' 23%
win rate, ElevenLabs sound effects, music stems, and the offline tactics-discovery harness.

## Next (after round 5, order to be decided)

- **Play online for real,** within the lead's cost strategy (servers only match players and route packets;
  server_management.md §5): the new rules replicated in player-hosted matches, deploy the broker on one cheap box and
  the web build on free static hosting; then lockstep on the integer core for ranked. Progression stays on the device.
- **Cross-build determinism follow-up** ([determinism.md](determinism.md) D1–D4), required before ranked lockstep:
  measure native vs web vs phone divergence on the real simulation, decide the port boundary, port system by system
  behind seams, then play lockstep matches. Round 2 keeps the debt small by following its guidelines.
- **Android paid app:** export, touch polish on real devices, store listing. The integer-core lockstep for ranked play, if the lead wants ranked.
- **Content:** more units (one at a time, each with a counter), more arenas, arena hazards.
- **The arena kit** ([game_design.md](game_design.md) *The arena kit*): stackable 20 and 40 ft shipping containers
  and giant dystopian ad screens with live match content, so new arenas are layout data over shared props.
- **Factions** (decided 2026-09-15, not scheduled; [game_design.md](game_design.md#factions-lead-2026-09-15)): the
  Condemned (today's roster), road gangs, the Law, the Syndicate. Same five roles, wildly different trade-offs, one
  shared mechanics vocabulary, balanced over time by headless simulation. First step: a `faction` field in the unit
  catalog, then the road gangs as the second faction (the most different from the Condemned).
- **Unit-count bench** (asked 2026-09-15: how many vehicles can we render, which decides how cheap and expendable
  units can be): a seeded match at 25 / 50 / 100 / 200 vehicles measuring frame time, draw calls, triangles, and
  simulation time per tick, native and in the browser, then on a phone. Then instancing (MultiMesh per unit type) and
  LODs as needed, and set squad-size and army-size limits from the numbers.
- **The AI Commander** (decided 2026-09-15; plan and rules in [vision.md](vision.md#the-ai-commander-an-optional-llm-opponent-decided-2026-09-15)):
  an optional LLM opponent issuing SquadCommands. Order: the commander-backend interface with a scripted fake →
  bring-your-own Gemini key on web → measured on the AI ladder against the heuristic commander → **on-device
  Gemini Nano in the Android app** (the goal; ML Kit GenAI Prompt API through a Godot Android plugin) → Chrome's
  built-in Nano on capable desktops. Claude through the agent bridge (agent_bridge.md) is already a prototype of the loop.
- **Desktop build, possibly on Steam** (under discussion 2026-09-15): native export with the Forward+ renderer as a
  "desktop high" tier (more lights, volumetric fog, better glow and shadows); the web build stays the design
  constraint. Needs controller or Steam Deck input if it ships there.

## Idea backlog (not scheduled; pick deliberately)

- **Replays, kill-cams, shareable replays** (recording already works over the relay).
- **Challenge missions:** fixed armies against scripted opponents that teach one counter each; a daily seeded challenge.
- **Arena hazards and spectacle:** crushing gates, fire pits, mines, a crowd "hype" meter.
- **The arena announcer** (stretch, [game_design.md](game_design.md) *The arena announcer*): two original ElevenLabs
  voices; a big tagged clip library stitched at runtime by a banter graph so commentary differs every match; text
  transcripts reviewed by the lead before audio is generated. **A round-3 stream candidate that can run in isolation**
  against fixture match events: [streams/archive/round3/announcer.md](streams/archive/round3/announcer.md).
- **Ranked with fixed budgets and full rosters,** so progression never affects competitive fairness.
- **Spectate AI vs AI** as a mode (great for learning counters, and for the lead's son).
- **Terrain height** for hull-down positions once the cover AI is solid.
- **Colorblind-safe team accents** and a readability pass for small phone screens.

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

## Round 12 is RUNNING (launched 2026-09-26 evening; six streams, briefs in `_agents/streams/`)

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

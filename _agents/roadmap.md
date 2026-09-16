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

## Now: Round 4 (planned 2026-09-16)

Goal: **doctrine, vision, and scale.** The lead played round 3 ("this is for sure much better") and asked for a camera
that shows only what the force can see, elements that run real battle drills chosen by a leader, suppression that makes
those drills bite, ~30 units a side with faction-sized rosters, and audio that stops sounding like an Atari.
Streams and briefs: [workstreams.md](workstreams.md).

| Stream | Outcome |
|---|---|
| **control** | Vision-framed camera, element focus, off-screen markers and alerts, command at 30+ a side |
| **doctrine** | Element leaders, formations and movement techniques from real doctrine, battle drills, faction doctrines |
| **combat** | Suppression and effective fire, protecting fragile units, faction rosters, scale |
| **ai** | Doctrine execution, ≤ 4 ms per tick at 60 units, suppression-aware behavior, the tactics ladder |
| **audio** | The real announcer run, cinematic sound effects, match mood, the dynamic music pipeline |

Paused: netcode, army and progression, new Meshy art.

## Next (after round 4, order to be decided)

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

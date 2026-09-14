# Architecture

Read before adding any new kind of "thing that decides what a tank does", or
anything that touches networking.

## The seam: `TankCommand`

`game/tank/tank_command.gd` is the most important file in the repo, even though
it's tiny. It's one tick's worth of intent: `throttle`, `turn`, `aim_point`, `fire`.

- **`Tank` consumes it** and knows nothing about where it came from.
- **Controllers produce it.** Today there are two: `PlayerController` (keyboard and mouse) and `ScriptedController` (demo and tests).

Every roadmap item adds a producer or moves where the consumer runs; none of
them change the contract:

| Milestone | New producer / change | Runs on |
|---|---|---|
| M1 ✅ | `PlayerController`, `ScriptedController` | local |
| M2 ✅ | Owning client's controller writes `tank.command`; `NetworkInput` sends it by RPC; the server-side `NetworkInput` validates it and applies it | client → server |
| M3 ✅ | `OrderController` (standing orders → command) and `BotController` (a tiny policy choosing orders) | server (bots) |
| M3 ✅ | `AgentBridge` drives an `OrderController` from an external process: Claude ([agent_bridge.md](agent_bridge.md)) | client or offline |
| M4 ✅ | `TankBrain extends OrderController`: senses team intel, scores options with directives, commits, emits orders ([tank_brain.md](tank_brain.md)) | server / match runner |
| M4 ✅ | `Squad` (commander, formation, drill) feeds each brain a slot + drill-weighted directives; the **TacticalMap** emits SquadCommands ([tactical_map.md](tactical_map.md)) | simulating peer |
| Round 2 | Fixed unit types (catalog v2) drive `Tank`; smarter brains (cover, peeking, fire discipline) stay controllers | simulating peer |
| Later | A commander (Claude, or an LLM) issues the same SquadCommands as the player | client or server |

If you find yourself making `Tank` check `if is_ai:` or `if multiplayer.is_server():`
for *decision-making*, stop: that logic belongs in a controller.

## Layers (target state)

```
 PLAYER / COMMANDER (client)         army builder ─▶ army JSON (units in ≤ 5 squads)
                                     taps on map/radar ─▶ SquadCommand (a later LLM commander uses the same)
──────────────────────────────────────────────────────────────── (validated by the simulating peer)
 SQUADS + BRAINS (per tick)          squad orders + formations + utility AI ─▶ orders ─▶ TankCommand
 CONTROLLERS                         Player / Scripted / NetworkInput / Skill ─▶ TankCommand
 SIMULATION (server-authoritative)   Tank, projectiles, damage, perception, navigation
──────────────────────────────────────────────────────────────── (state snapshots)
 PRESENTATION (client)               interpolation, camera, effects, UI
```

Rules that fall out of this:
1. **Simulation code doesn't depend on presentation.** A tank must work with no camera, no meshes, and no display. The headless server and `tests/` prove it continuously.
2. **Pure math lives in pure classes** (`TankMotion`), so tests and future AI planners can use it without a scene tree.
3. **The LLM is never in the tick loop** (reasons in [vision.md](vision.md#where-the-llm-fits-and-where-it-must-not)).
4. **Anything the client sends is untrusted.** A client sends *intent* (commands now, doctrine later); the server clamps and validates (`TankCommand.sanitized()` is the first instance of this).

## Seams for parallel work (2026-09-13)

- **Modes:** `main.gd` only parses flags and hands off to one `GameMode` (`game/modes/`).
- **Visuals:** gameplay scenes hold `VisualSlot`s; `GameTheme` maps slot ids to art scenes. Changing art never edits gameplay files, and `make sim-baseline` proves the simulation didn't change.
- **Replication:** `Replication.attach_tank_sync()` builds the synchronizer in code (netcode owns what syncs); `tank.tscn` has no networking nodes.
- **HUD:** `hud.tscn` (layout) + `hud.gd` (text).
- **Makefile:** `mk/<area>.mk`.
- Ownership and contracts: [workstreams.md](workstreams.md).

## One codebase, three builds

| Build | How | Includes |
|---|---|---|
| Desktop dev | `make run` | everything |
| Web client | `make export-web` → `build/web/` | everything; WebGL 2 |
| Dedicated server | `make export-server` → `build/server/*.x86_64` | `dedicated_server=true` strips visual resources; feature tag `server` |

**One origin in the browser:** the web client connects to `/ws` on the page's own
host (`wss://` under https). Locally `tools/serve_web.py` proxies `/ws` to the game
server; in production the reverse proxy (Caddy) will do the same. Nobody types a
second port.

The same `main.tscn` boots in all three. Mode selection happens in `game/main.gd`
from flags (`--demo`, later `--server`/`--connect=`) or URL query params on the
web. Code can also check `OS.has_feature("server")` / `OS.has_feature("web")`.

## Networking (M2)

Every process is exactly one **role**, chosen in `game/main.gd`:

| Role | Started by | Has a local controller? | Tanks `simulate`? | Has `NetworkInput`? |
|---|---|---|---|---|
| OFFLINE | no flags | yes | yes | no |
| SERVER | `--server[=port]`, or an exported server binary | no | **yes, the only simulator** | yes (applies commands) |
| CLIENT | `--connect[=url]` / `?connect`, or `--join=CODE` / `?join=CODE` (relay), or `--replay=PATH` | yes | **no, display only** | yes (sends own commands) |
| HOST | `--host` / `?host` (a player hosts through the broker's relay), or via `--lobby` / `?lobby` | yes (unless `--no-player`) | **yes, the only simulator** | yes, except on the host's own tank |
| LOBBY | `--lobby` / `?lobby` | becomes HOST or CLIENT in place | n/a | n/a |
| DET_SPIKE | `--det-spike` / `?det-spike` | no | runs `game/network/detcore/` only (N2 experiment) | no |

One tick of networked play:

```
CLIENT (owner)                                    SERVER
LocalController  (priority -10) → tank.command
NetworkInput     (priority  -5) → submit_command.rpc_id(1, …)  ──unreliable_ordered──▶
                                                   NetworkInput.submit_command: sender == owner?
                                                     finite? rate OK? → sanitized → _latest
                                                   NetworkInput (priority -10) → tank.command
                                                   Tank (priority 0) simulates, writes sync_*
            ◀──── MultiplayerSynchronizer "StateSync" every 33 ms: sync_position/yaw/turret_yaw
Tank._process smooths the visual toward sync_*
```

How the pieces fit:
- **Spawning.** `MultiplayerSpawner` (`Main/TankSpawner`) uses a *spawn function* (`main.gd::_spawn_tank`), not a scene list. The server calls `spawner.spawn(data)`; the same function runs on every peer with the same `data`, so every peer builds an identical node (`Tanks/Tank_<peer_id>` plus its `NetworkInput` child). Identical node paths are what make RPCs and synchronizers work. The spawn function must be assigned **before** connecting.
- **Authority.** All tanks keep the default multiplayer authority (peer 1, the server). Clients own nothing; they only send intent.
- **Offline mode reuses the spawner.** The offline peer is its own server, but gets no `NetworkInput` (it would override the local controller with "stale input: stop").
- **Security baseline.** `SceneMultiplayer.server_relay = false` on the server; sender check, finite check, clamp, 120 msg/s limit, 500 ms stale-stop in `NetworkInput.accept()`/`current_command()`. All of it is unit-tested without sockets.

### Player-hosted matches through the relay (netcode N1, 2026-09-14)

```
 host player (HostMode)            broker (server/broker, Node)             players (ClientMode)
 RelayPeer ──WebSocket──▶  room K7QX2: star relay, seq numbers,  ◀──WebSocket── RelayPeer
 (peer 1, simulates)       heartbeats, 30 s grace + resume,                    (display + commands)
                           rate/size limits; never simulates
```

`RelayPeer` is a `MultiplayerPeerExtension`, so the spawner/synchronizer/RPC code above runs
unchanged: the host is peer 1 like a server. A dropped socket stays invisible to Godot (the peer
reconnects and resumes; reliable frames are retransmitted); a seat lost for good is rejoined with a
player key and the host restores that tank. Wire protocol and measurements:
`_agents/streams/archive/round1/netcode.md`; designs (lockstep, host loss, backgrounding, costs):
`_agents/streams/references/netcode_designs.md`.

## Combat and rules (M3)

```
Main (main.gd: roles, flags, HUD)
├─ Arena                  static world, collision layer 1 (point-symmetric layout: fair for both teams)
└─ Match (match.gd: THE RULES)
   ├─ TankSpawner / ShellSpawner   spawn functions run on every peer (listed BEFORE the containers; see trip-ups)
   ├─ Tanks/Tank_<peer>, Bot_<n>   collision layer 2
   ├─ Shells/Shell_<id>
   ├─ Effects                      client-only impact visuals (show_impact RPC)
   ├─ Brains/Brain_Bot_<n>         server-only BotControllers (not replicated)
   └─ ScoreSync                    score_green / score_rust, on change
```

- **Tanks report, Match decides.** `Tank` emits `fired(muzzle, direction)` and `died`; it never spawns shells or respawns itself. `Match` (simulating peer only) spawns the shell, resolves hits, scores, and schedules respawn. This keeps the Tank reusable and the rules in one place.
- **Shells are projectiles** (70 m/s, 110 m range) that sweep a ray each tick (world + tanks masks, shooter excluded). The first sweep starts at the turret center so a wall touching the barrel still blocks. Clients fly the same straight line visually; the server's despawn removes them.
- **Damage = weapon damage × armor multiplier**, where `Armor.facing()` compares the hull's forward to the shell's travel direction: front (within 45° of head-on), side, rear, per weapon profile; shields absorb first. Friendly fire is off today (teammates stop shells); **round 2 turns it on** (game_design.md).
- **Firing is a held trigger** sampled each tick (`TankCommand.fire`), gated by a 2 s reload. A dropped unreliable packet costs at most one tick of a held trigger. This replaced the earlier plan of a reliable fire event: simpler, and good enough for a slow-firing gun.
- **Teams:** a new tank joins the smaller team (ties go to Green). Green's base is south (z = +42) facing north; Rust's is north. Slots spread along x.
- **Navigation (M4):** `Arena` bakes a navmesh from collision shapes at startup on every peer (the server export has no meshes). It bakes the south half and mirrors it for fairness (see squad_ai_design.md "Fairness"). `OrderController.move_to` follows `Pathing.find_path` waypoints, repaths every second or when the goal moves, and slows only for the path's end. `"reverse": true` backs along the path.
- **Reflexes (M4):** conditional standing orders checked every tick before orders execute (`retreat_below_hp`, `halt_on_contact`); each fires once and re-arms when its condition clears. They're the seed of doctrine *phases*.
- **Match runner (M4):** role MATCH (`--match`): bots only, ends at a score/time limit, prints `MATCH_RESULT {json}` with shot/hit/face/kill stats. Run under Godot's `--fixed-fps 60` with no `max_fps` cap, so it simulates ~8–70× real time. `tools/match_series.py` runs seeded series in parallel. `--swap-bases`, `--rust-first`, and `--no-navigation` exist as experiment controls.
- **Tank brains (M4 AI v1):** see [tank_brain.md](tank_brain.md). `Match.intel[team]` is shared team vision with memory (refreshed every 6 ticks, each tank's own `sight_radius` (75 m for a tank, 110 m for a scout), 12 s memory), so brains are not omniscient (BotController still is). `Match.load_doctrine()` builds squads of `TankBrain`s from `doctrines/*.json`; directives resolve defaults → squad → tank. Brains think every 6 ticks, staggered, and `decide()` is pure.
- **Weapons are data** (`Weapons.PROFILES`): the cannon (projectile), laser and machine gun (hitscan BEAM), mortar (indirect ARC rounds kept as data in `Match`), and flamethrower (CONE) fire through `Tank.fired` / `Tank.sprayed`; every hit goes through `Match._land_hit` → `Tank.take_hit` (shield first, then armor facing). Unit stats come from `Units.PROFILES` via `Tank.apply_loadout` (directive set 2); numbers in [balance.md](balance.md).
- **Pure helpers** shared by bots, the bridge, and future AI: `Armor`, `Ballistics` (intercept lead, aim error), `Steering` (goal → throttle/turn), `Perception` (line of sight on the world layer at 1.3 m, enemy queries).

## Physics tick ordering

Godot runs `_physics_process` for all nodes each tick (60 Hz by default), in
order of `process_physics_priority` (lower first), then tree order. Controllers
use `-10` so the command is ready before the tank reads it. When networking
arrives, the server's tick becomes *the* simulation clock, and this ordering
matters for fairness.

## Decisions log

| Date | Decision | Why |
|---|---|---|
| 2026-09-12 | Godot 4.7.2, GDScript, Compatibility renderer | Web export needs WebGL 2 + GDScript; matches what a beginner (the lead's son) uses |
| 2026-09-12 | `TankCommand` seam before anything else | Human, network, and AI control become interchangeable; avoids a rewrite at M2/M4 |
| 2026-09-12 | Web export without threads | Any static host works; no COOP/COEP; enough for this game |
| 2026-09-12 | Headless server exported from the same project | One codebase; the server *is* the game minus rendering |
| 2026-09-12 | Tank is `CharacterBody3D` with kinematic movement, not `VehicleBody3D` | Predictable, easy to network and to drive from AI; realism isn't a goal |
| 2026-09-12 | Input up by explicit RPC; state down by `MultiplayerSynchronizer` | RPC makes the server's validation visible and testable; the synchronizer is Godot's idiomatic replication. Both are worth learning |
| 2026-09-12 | Replicate `sync_*` properties, not `position` directly | Clients can smooth toward them without fighting the replication writes |
| 2026-09-12 | No client-side prediction | Tanks are slow and squads won't be directly controlled; see server_management.md §2 |
| 2026-09-12 | Rules live in `Match`; `Tank` only emits `fired`/`died` | One place for rules; Tank stays reusable by tests, bots, AI |
| 2026-09-12 | Projectile shells with swept raycasts, not hitscan | Travel time makes leading, dodging, and range matter; sweeping avoids tunneling |
| 2026-09-12 | Fire = held trigger in the unreliable command stream (not a reliable event) | Loss costs ≤ 1 tick while held; avoids a second channel |
| 2026-09-12 | Bots and the agent share `OrderController` | The action layer is built once and exercised by both a dumb policy and a thinking commander |
| 2026-09-13 | Player commands squads via a tactical map; formations are relative to an elected commander; drills tilt brain weights instead of scripting tanks | The lead's brief: lots of hidden power, few inputs; brains stay autonomous |
| 2026-09-13 | Tank AI = utility scoring over a fixed option set, driven by directive data; pure `decide()` | The lead's "weights in a tree" + "deterministic CPU middle layer"; golden-testable without physics |
| 2026-09-13 | Shared team vision (intel) instead of per-tank perception | Makes scouting and spotting teamwork mechanics; cheap (≤ 25 rays per team per 0.1 s) |
| 2026-09-13 | Doctrine coordinates are team-relative (right, forward) | One doctrine plays identically for either side, keeping experiments fair |
| 2026-09-13 | Browser client connects to same-origin `/ws` (proxied) | The lead's first try opened the WebSocket port in a browser; one URL now, same shape as production |
| 2026-09-14 | Casual multiplayer = a player hosts through a WebSocket relay broker (N1); the broker never simulates | Zero game compute on our servers; browsers/phones can't accept connections; cheating accepted for casual play (assumed pending the lead) |
| 2026-09-14 | Relay frames carry sequence numbers; reliable frames are retained until acked | A dropped phone socket must not lose a spawn/despawn, or Godot's replicated tree silently diverges |
| 2026-09-14 | Lockstep would need an integer simulation core | N2: a Q16.16 core is bit-identical native vs wasm; basic float ops agree too, but libm trig (used by Godot physics/navigation) does not |
| 2026-09-13 | Navmesh baked from colliders, south half + 180° mirror | Server export has no meshes; a plain bake was measurably unfair (64% south wins) |
| 2026-09-13 | Match runner uses `--fixed-fps` in-process, not `Engine.time_scale` | Exact 1/60 s steps regardless of speed; physics stays identical to real-time play |
| 2026-09-13 | Retreats back away (reverse) by default | Playtest #2: turning to run exposes rear armor |
| 2026-09-15 | A new squad order re-thinks brains on the next tick and outranks commitment | G3: the lead found RTS commands unresponsive |
| 2026-09-15 | Directional recharging shields over hull; hull mends only at base | G6 (Halo); directional so flanking still pays |
| 2026-09-15 | `VisibilityField` is presentation-only; brains use intel from the same rays | Fog for UI can't change the simulation or the sim baseline |
| 2026-09-15 | Direct fire needs the shooter's line of sight AND the target seen by the team | Closed a fog hole; makes spotting a teamwork mechanic |
| 2026-09-15 | Indirect rounds are data in `Match` (land by tick), drawn on clients by RPC | Deterministic, no spawner changes |
| 2026-09-15 | ~~Chassis + loadout~~ **superseded the same day** by the lead: fixed unit types (StarCraft-style counters), no loadouts | Loadouts were too complicated; depth should come from matchups and command (game_design.md) |
| 2026-09-15 | Friendly fire will be on; brains must reason about lines of fire | The lead; makes positioning and fire discipline matter |
| 2026-09-15 | Tanks render the Meshy prison dozer through a cyberpunk wrapper (`dozer_part.gd`) | Generated art in the default theme while keeping team accents, underglow, and shields |
| 2026-09-15 | Navigation map/region iterations synchronous | Async readiness varied with machine load and broke determinism (orientation trip-up 57) |
| 2026-09-15 | The RTS camera is a controller node over the existing main camera | No shared-scene edits; the map works in perspective via ground raycasts |
| 2026-09-12 | Squad AI direction: utility AI with player-tuned directives and phases (accepted by the lead) | Matches the lead's "weighted tree" intuition; weights are a natural LLM output. Validate with experiments E1–E4 in squad_ai_design.md |

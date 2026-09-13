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
| M4 | `UtilityController`: scores actions with directive weights and emits commands ([squad_ai_design.md](squad_ai_design.md)) | server |
| M5 | Skills are chosen and configured by **doctrine data** | server |
| M7–8 | Doctrine is *authored* by an LLM from natural language | client (authoring time only) |

If you find yourself making `Tank` check `if is_ai:` or `if multiplayer.is_server():`
for *decision-making*, stop: that logic belongs in a controller.

## Layers (target state)

```
 AUTHORING (client, occasional)      natural language ─▶ LLM ─▶ doctrine JSON
                                     or form-based editor ─────▶ doctrine JSON
──────────────────────────────────────────────────────────────── (validated by server)
 DOCTRINE (data)                     loadouts, roles, skills + params, triggers
 SKILLS (server, per tick)           behaviors + squad blackboard ─▶ TankCommand
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

## One codebase, three builds

| Build | How | Includes |
|---|---|---|
| Desktop dev | `make run` | everything |
| Web client | `make export-web` → `build/web/` | everything; WebGL 2 |
| Dedicated server | `make export-server` → `build/server/*.x86_64` | `dedicated_server=true` strips visual resources; feature tag `server` |

The same `main.tscn` boots in all three. Mode selection happens in `game/main.gd`
from flags (`--demo`, later `--server`/`--connect=`) or URL query params on the
web. Code can also check `OS.has_feature("server")` / `OS.has_feature("web")`.

## Networking (M2)

Every process is exactly one **role**, chosen in `game/main.gd`:

| Role | Started by | Has a local controller? | Tanks `simulate`? | Has `NetworkInput`? |
|---|---|---|---|---|
| OFFLINE | no flags | yes | yes | no |
| SERVER | `--server[=port]`, or an exported server binary | no | **yes, the only simulator** | yes (applies commands) |
| CLIENT | `--connect[=url]` / `?connect` | yes | **no, display only** | yes (sends own commands) |

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
| 2026-09-12 | Squad AI direction: utility AI with player-tuned directives and phases (exploration) | Matches the lead's "weighted tree" intuition; weights are a natural LLM output. Validate with experiments E1–E4 in squad_ai_design.md |

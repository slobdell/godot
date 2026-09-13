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
| M2 | Client sends `TankCommand` over the network. A server-side `NetworkInputController` applies the latest one received for that peer. | client → server |
| M4 | `SkillController`: runs a skill (`hold_sector`, `bait`, …) that emits commands | server |
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

# HANDOFF

> **Read [`_agents/orientation.md`](_agents/orientation.md) first.** It has the
> mental model, the context-handoff workflow, and the trip-ups (now 20 of them).
> Then come back here.

_Last updated: 2026-09-12, M3 + M3.5 committed; M4 infrastructure next._

## Current state

**M0–M3 and M3.5 are done, verified, and committed.** `make check-all` passes
from a clean build (tests 40/40, net-smoke, combat-smoke, desktop screenshot,
web-smoke, web-net-smoke, exported server shuts down cleanly with bots). The
screenshots were inspected.

What you can do right now:
- `make run`: play offline vs a bot (click/space fires). `make run BOTS=3` for a brawl.
- `make server BOTS=1` + `make serve-web` → `http://localhost:8060/?connect`: multiplayer with bots in the browser.
- `make server BOTS=1` + `make agent-client` → Claude plays via `tools/agent.py` ([agent_bridge.md](_agents/agent_bridge.md)).

## What happened in the M3 session

1. **Combat** ([architecture.md § Combat](_agents/architecture.md#combat-and-rules-m3)): projectile shells, armor facing (front ×0.5 / side ×1 / rear ×1.5), health/death/respawn, teams, score, symmetric arena, HUD, impacts. `Match` holds the rules; `Tank` only emits `fired`/`died`.
2. **Action layer:** `OrderController` (standing orders → `TankCommand`) with pure helpers `Steering`, `Ballistics`, `Perception`. `BotController` is a tiny policy on top.
3. **Agent bridge (the lead's idea):** localhost HTTP → `OrderController`; Claude played a bot and **lost 4–2**. Findings are in [agent_bridge.md play report #1](_agents/agent_bridge.md#play-report-1-2026-09-12-claude-vs-one-botcontroller-1v1-2-minutes) and logged in [squad_ai_design.md](_agents/squad_ai_design.md): conditional orders are needed, bots deadlock on walls without a navmesh, 1v1 has little positional skill, and first shot wins even duels.
4. **Verification got stricter:** the test runner fails tests on any engine error (a crashing test used to PASS); `make check` / `make check-all` bundles; `FILTER=`.
5. **Real bugs caught by looking, not asserting:** shells flew over every tank (collision box too short, and two tests passed vacuously); a release-only shutdown error from spawner ordering; missing HUD glyphs; the camera couldn't see enemies at engagement range; Rust players' camera faced their own wall.

## Next task: M4 infrastructure (still BEFORE squad AI)

The lead asked to pause for a personal smoke test before squad AI begins. The
M4 items below are infrastructure the playtest showed we need; `UtilityController`
(the first real AI) should wait for that smoke test.

1. **Navmesh pathing** for `move_to` (`NavigationRegion3D` baked from the arena; `NavigationAgent3D` or `NavigationServer3D.map_get_path`). Acceptance: the bot no longer pins itself against `CoverNorth` chasing a target behind it (reproduce with the agent bridge: park behind the wall).
2. **Conditional standing orders** (e.g. `retreat_below_hp`, `hold_until_visible`) in `OrderController` + the bridge + `agent.py`. A second playtest should show Claude surviving its think gaps.
3. **Headless match runner:** `--match` mode that runs bots-vs-bots to a score/time limit **faster than real time** (`--fixed-fps`, and skip the headless `max_fps` cap, trip-up #11) and prints JSON. `make match`.

## Open decisions for the project lead

1. **Smoke test M3 yourself** (`make run`, and the browser multiplayer). Does combat feel right: reload, damage, speed, camera?
2. **Play against Claude?** Start `make server BOTS=0` + browser, and ask Claude to join with `make agent-client`.
3. Still open: your son's Godot version and OS; the working title.

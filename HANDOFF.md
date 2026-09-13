# HANDOFF

> **Read [`_agents/orientation.md`](_agents/orientation.md) first.** It has the
> mental model, the context-handoff workflow, and the trip-ups. Then come back here.

_Last updated: 2026-09-12, end of the M0 + M1 session._

## Current state

**M0 (scaffold) and M1 (one tank, direct control) are done and verified.**

- `make bootstrap` installs Godot **4.7.2** + trimmed export templates into `.tools/` (≈300 MB, checksum-verified).
- `make run`: drive a placeholder tank (WASD/arrows) with the turret following the mouse, in an arena with crates.
- `make test`: **11/11 passing** (motion math, command sanitizing, real-physics drive/turn/turret).
- `make screenshot`: desktop render verified by eye.
- `make web-smoke`: WebAssembly build boots in headless Chrome over WebGL 2, logs `TANK_SQUAD_READY`, no console errors, renders correctly.
- `make export-server`: headless Linux server binary boots and runs `main.gd`.
- Git repo initialized on `main`; **nothing committed yet** (the lead hasn't asked for a commit).

## What happened this session

1. Studied the lead's `plane_maker` project and adopted its `_agents/` + `HANDOFF.md` conventions.
2. Wrote the Makefile-driven bootstrap (pinned version, self-contained mode, template trimming because the disk is 92% full).
3. Built M1 around the `TankCommand` seam ([architecture.md](_agents/architecture.md)), chosen so that network control (M2) and squad AI skills (M4) plug in as controllers.
4. The lead described the long-term vision: a squad of 5 tanks, players author strategy rather than drive, compiled by on-device Gemini Nano on Android. Captured in [vision.md](_agents/vision.md), with the key constraint: **the LLM compiles doctrine data at authoring time and is never in the game loop.**
5. The lead said they don't know how game servers are canonically managed → wrote [server_management.md](_agents/server_management.md) (primer + staged plan S0–S4).
6. Trip-up found and fixed: release server builds swallowed `print()` output (`flush_stdout_on_print`), now orientation trip-up #4.

## Next task: M2, networked direct control

**Pre-read:** [`_agents/server_management.md`](_agents/server_management.md) §1, 2, 5 and the M2 section of [`_agents/roadmap.md`](_agents/roadmap.md).

Sketch:
1. `NetworkManager` autoload: `--server[=port]` hosts a `WebSocketMultiplayerPeer`; `--connect=ws://…` (or `?connect=` in the browser) joins.
2. Server spawns a tank per peer via `MultiplayerSpawner`. Tank authority stays on the server.
3. Client-side `PlayerController` sends its `TankCommand` to the server (unreliable RPC each tick). A server-side `NetworkInputController` applies the latest one, sanitized.
4. `MultiplayerSynchronizer` replicates transform + turret yaw; clients interpolate.
5. `make server` target; a headless bot-client integration test; update verification.md.

## Open decisions for the project lead

1. **Which Godot version does your son use?** We pinned 4.7.2 (latest stable). If he's on another 4.x, consider matching.
2. **Commit?** Everything is untracked. Say the word and it's committed as the initial scaffold.
3. **M2 (networking) before M4 (squad AI)?** Current recommendation: yes (see roadmap "Open ordering decisions").
4. **Working title** "Tank Squad" is a placeholder.

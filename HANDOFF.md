# HANDOFF

> **Read [`_agents/orientation.md`](_agents/orientation.md) first.** It has the
> mental model, the context-handoff workflow, and the trip-ups (now 14 of them).
> Then come back here.

_Last updated: 2026-09-12, end of the M2 session._

## Current state

**M0, M1, and M2 (networked direct control) are done and verified.** The M0/M1
baseline is committed (`fad14f4`). **M2 is not committed yet**; the lead hasn't
been asked.

- `make server` + browser tabs at `localhost:8060/?connect` = real-time multiplayer. The server simulates every tank; clients send `TankCommand`s by RPC and display replicated state.
- `make test`: **18/18** (added 6 server-side validation tests + a NaN-sanitizing test).
- `make net-smoke`: headless server + 2 bot clients over real WebSockets, PASS. Also verified that it **fails** when expectations aren't met (`NET_SMOKE_EXPECT=3`).
- `make web-net-smoke`: a browser client connects, and a remote tank renders rust-colored at its replicated position (screenshot inspected).
- `make web-smoke` (offline), `make screenshot`: still pass and look right.
- Exported release server binary: starts in SERVER role with no flags; a bot client connected and drove through it.

## What happened this session

1. Built M2 as designed in [architecture.md § Networking](_agents/architecture.md#networking-m2): roles in `main.gd`, `MultiplayerSpawner` with a spawn function, a `StateSync` synchronizer in `tank.tscn`, and `game/network/network_input.gd` (the relay plus server-side gate).
2. New trip-ups recorded (#9–14): node paths must match across peers, `server_relay` defaults on, headless spins a CPU core, the offline peer is a server, shared materials, and pipefail in Makefile pipelines.
3. The lead asked two design questions: can each tank run its own control loop over a weighted tree of tunable directives, and where does player skill come from if the AI opponent has identical capabilities? Answered in **[`_agents/squad_ai_design.md`](_agents/squad_ai_design.md)**: utility AI with directives + phases, five sources of skill, and experiments **E1–E4** to validate before committing. The lead is new to game dev and explicitly unsure how squad AI would work, so treat that doc as a hypothesis to test, not a spec.
4. The roadmap was restructured around those experiments: M3 combat must include LOS, armor facing, and cover; the **headless match runner moved up to M4**; M4 acceptance = E1, M5 acceptance = E3.

## Next task: M3, combat (built to be read by AI later)

**Pre-read:** [`_agents/squad_ai_design.md`](_agents/squad_ai_design.md) ("Consequences for the roadmap") and the M3 section of [`_agents/roadmap.md`](_agents/roadmap.md).

Sketch:
1. Firing: client sets `fire` → server spawns a shell (spawner or synchronized projectile) with reload time. Make firing a **reliable** one-shot event, not just a flag in the unreliable per-tick stream, so a dropped packet can't eat a shot.
2. Damage model with armor facing: the angle between the shell's travel direction and the hull's forward decides front/side/rear multipliers. Pure math → `TankMotion`-style pure class + unit tests.
3. Line-of-sight helper (physics ray query) + a few taller walls to hide behind.
4. Health, death, respawn after a delay; two teams with colors (replace the "rust = other player" placeholder).
5. HUD: health + reload. Extend `net-smoke` (e.g. a bot that aims and fires at the other) to prove damage over the network.

## Open decisions for the project lead

1. **Commit M2?** Say the word.
2. **Which Godot version does your son use?** Still pinned to 4.7.2.
3. **Your son's OS:** the Makefile assumes Linux (see bootstrap.md "Platform scope").
4. **Squad AI experiments:** do E1–E4 in [squad_ai_design.md](_agents/squad_ai_design.md) match what you'd want proven before investing in the LLM/Android layers?
5. **Working title** "Tank Squad" is still a placeholder.

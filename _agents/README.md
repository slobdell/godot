# Agent Notes Index

Notes for AI agents **and humans** working on Tank Squad. Start here.

This project has two audiences at once. It's a real game, and it's also the
project lead's way to learn Godot ahead of their son, who is learning game
programming with Claude. So these docs explain *why* as well as *what*. Keep it
that way: a note that only says "do X" teaches nothing.

## Files

**Start here**
- **[orientation.md](orientation.md)**: **Read this first.** A 3-minute warmup: the mental model, how context is handed between sessions, the repo layout, common tasks, and the trip-ups that have already cost someone time.
- **[game_design.md](game_design.md)**: **What the game is:** fixed unit types that counter each other, StarCraft-style control (desktop first), arcade-tactical combat, factions, the gladiator arena and announcer. The design source of truth; round 3's direction is at the top.
- **[vision.md](vision.md)**: Why and for whom: a die-hard game with no pay-to-win; free on the web, paid on Android; over-the-top converted vehicles; how the vision moved.
- **[art_direction.md](art_direction.md)**: The look: the Death Race prison dozer north star, rules for every piece of art, the roster and arena concepts.
- **[orchestration.md](orchestration.md)**: **How we work.** The reusable orchestrator/worker pattern: roles, the round lifecycle, the worker contract, integration and closing checklists, the kickoff prompt, and lessons.
- **[workstreams.md](workstreams.md)**: **The current round.** Streams, lead gates, path ownership, contracts, checkpoints, invariants, and worktree mechanics. Briefs are in `streams/`; rounds 1–2 are archived in `streams/archive/`.
- **[remote_builds.md](remote_builds.md)**: Run heavy make targets on builder0 (`make remote T=check`).
- **[roadmap.md](roadmap.md)**: What's done, the current round, what's next, and the idea backlog.

**How the systems work**
- **[architecture.md](architecture.md)**: The layers, the `TankCommand` seam, modes, networking (server, relay, host), combat and rules, and the decisions log.
- **[tank_brain.md](tank_brain.md)**: The deterministic utility AI (brains, directives, doctrines, team intel) and experiments T0–T3.
- **[squad_ai_design.md](squad_ai_design.md)**: Where player skill comes from; experiments E1–E4; fairness measurement.
- **[tactical_map.md](tactical_map.md)**: How the player commands squads: commanders, formations, drills, SquadCommand, the map and radar.
- **[determinism.md](determinism.md)**: Same-build vs cross-build determinism, where the simulation depends on engine math, portability guidelines for new simulation code, and the follow-up toward lockstep.
- **[balance.md](balance.md)**: Tuning values, measured results, and how to run balance experiments.
- **[slot_contracts.md](slot_contracts.md)**: The visual slot contract between gameplay and art (ids, sizes, optional methods, budgets).
- **[agent_bridge.md](agent_bridge.md)**: Claude commands a tank over a localhost HTTP bridge (smoke test and commander prototype).
- **[server_management.md](server_management.md)**: A primer on how online games run servers, and the staged plan (our servers only match players and route packets).
- **`streams/references/`**: deep references from round 1: FX tricks and tier budgets, asset services, the asset budget, prompts, netcode designs, and HUD widget specs.

**Working here**
- **[verification.md](verification.md)**: How an agent that can't see the screen proves its change works. **Read before calling any task done.**
- **[bootstrap.md](bootstrap.md)**: What `make bootstrap` installs and why; upgrading Godot.
- **[godot_for_programmers.md](godot_for_programmers.md)**: Godot concepts mapped to things an experienced programmer already knows.
- **[teaching_notes.md](teaching_notes.md)**: Concepts that clicked, written for the lead to reuse with their son. Append when something "clicks".

## Conventions (same as the lead's other projects)

- **One high-level task at a time.** When a task ends, the running agent updates `HANDOFF.md` (project root) *before* context is cleared. `HANDOFF.md` must always tell the reader to read `_agents/orientation.md` first.
- **Docs evolve with the code.** If your change makes a note stale, fix the note in the same change. If you learned something the hard way, add it to the trip-ups in `orientation.md`.
- **The Makefile is the source of truth for setup and workflows.** If you ran a command twice, it probably belongs in the Makefile, with a `## help` comment.

# Agent Notes Index

Notes for AI agents **and humans** working on Tank Squad. Start here.

This project has two audiences at once. It's a real game, and it's also the
project lead's way to learn Godot ahead of their son, who is learning game
programming with Claude. So these docs explain *why* as well as *what*. Keep it
that way: a note that only says "do X" teaches nothing.

## Files

- **[orientation.md](orientation.md)**: **Read this first.** A 3-minute warmup: the mental model, how context is handed between sessions, the repo layout, and the trip-ups that have already cost someone time.
- **[vision.md](vision.md)**: Where the game is going. Players don't drive tanks; they write *strategy* for a 5-tank squad, compiled by an on-device LLM (Gemini Nano on Android) into data the simulation runs. Read before making any design decision that would be hard to undo.
- **[squad_ai_design.md](squad_ai_design.md)**: Exploration of *how* tanks think (utility AI: directives and phases over a per-tank sense→think→act loop) and *where player skill comes from* when both sides have identical tanks. Includes the experiments (E1–E4) that validate it. Read before any AI, doctrine, or game-balance work.
- **[architecture.md](architecture.md)**: The layers (simulation → controllers → skills → doctrine → authoring), the one seam everything hangs on (`TankCommand`), and **how networking works**: roles, the per-tick message flow, spawning, authority, and the security baseline. Read before adding a new kind of "thing that decides what a tank does".
- **[roadmap.md](roadmap.md)**: Milestones with acceptance criteria, what's done, and the open ordering decisions.
- **[server_management.md](server_management.md)**: A primer on how online games actually run servers (authoritative servers, tick/snapshot loops, matchmaker → allocator → game-server process, persistence) and the staged plan for this project. Read before any networking or deployment work.
- **[godot_for_programmers.md](godot_for_programmers.md)**: Godot concepts mapped to things an experienced programmer already knows (scenes ≈ composable prefabs, signals ≈ observer pattern, autoloads ≈ singletons…), plus the coordinate-system and scene-file facts this repo relies on.
- **[verification.md](verification.md)**: How an agent that can't see the screen proves its change works: unit tests, integration tests stepped through real physics, desktop screenshots, the headless-Chrome web smoke test, and the server-binary check. **Read before calling any task done.**
- **[bootstrap.md](bootstrap.md)**: What `make bootstrap` installs, where it goes, and why (pinned version, self-contained mode, trimmed export templates, disk budget). How to upgrade Godot. What Android will add.
- **[teaching_notes.md](teaching_notes.md)**: A running log of concepts that were confusing or satisfying the first time, written for the project lead to reuse when helping their son. Append to it when something "clicks".

## Conventions (same as the lead's other projects)

- **One high-level task at a time.** When a task ends, the running agent updates `HANDOFF.md` (project root) *before* context is cleared. `HANDOFF.md` must always tell the reader to read `_agents/orientation.md` first.
- **Docs evolve with the code.** If your change makes a note stale, fix the note in the same change. If you learned something the hard way, add it to the trip-ups in `orientation.md`.
- **The Makefile is the source of truth for setup and workflows.** If you ran a command twice, it probably belongs in the Makefile, with a `## help` comment.

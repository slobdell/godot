# HANDOFF

> **Read [`_agents/orientation.md`](_agents/orientation.md) first.** Then [`_agents/orchestration.md`](_agents/orchestration.md)
> (how we work: the orchestrator/worker pattern), [`_agents/game_design.md`](_agents/game_design.md) (what the game is), and if
> you're a workstream agent, [`_agents/workstreams.md`](_agents/workstreams.md) and your brief in `_agents/streams/`.

_Last updated: 2026-09-16. **Round 3 is merged, verified and closed; round 4 is planned and its worktrees are fresh
from `main`.**_

## Current state (main)

- **Verified:** `make remote T=check` green on builder0 (656 tests, every smoke test, the announcer's Python tests).
  Sim baseline `glibc-2.43 10e95d54f5dd3efe` (moved by combat's suppression, then ai's think LOD and decisions) (builder0 is canonical; record with `make remote T=sim-baseline-record`).
- **Play it:** `make skirmish` is the round-3 game: StarCraft-style control (click, box, ctrl+1–9 groups, right-click
  orders, attack-move, shift-queued waypoints, follow, stop, hold), slow devastating tank shells, 25 mm bursts, machine-gun
  streams, weak spots, wheeled vehicles with turning circles, brains that strafe, dodge, flank and use cover, a CPU
  commander that maneuvers, and impact effects with sound. The control point is on by default (`--no-control` turns it off).
  Also: `make garage`, `make vehicle-gallery FACTION=gangs|law|syndicate`, `make arena-kit-gallery`, `make fx-shots`,
  `make ai-shots`, `make announcer-demo`, `make duel GREEN_UNITS=… RUST_UNITS=…`.
- **Builds run on builder0:** `make remote T=check` (about 7 minutes, versus 14–22 on the laptop);
  [remote_builds.md](_agents/remote_builds.md). One remote run per worktree at a time.
- **What round 3 delivered, per stream:** `_agents/streams/archive/round3/` (each brief's Status is its report, with
  measurements, decisions, known issues, and what to playtest).

## Round 4: five streams (planned 2026-09-16)

Goal: **doctrine, vision, and scale** ([game_design.md](_agents/game_design.md) *Round 4 direction*).

| Stream | Brief | Outcome |
|---|---|---|
| control | [streams/control.md](_agents/streams/control.md) | The vision-framed camera (as close as your force's sight allows), element focus, off-screen markers and alerts, command at 30+ a side, faction pick |
| doctrine | [streams/doctrine.md](_agents/streams/doctrine.md) | Elements with leaders, formations and movement techniques from real doctrine, battle drills on contact, faction doctrines (**L1 = CP1**) |
| combat | [streams/combat.md](_agents/streams/combat.md) | Suppression and effective fire, heavies shielding the fragile, faction rosters, scale to ~30 a side (**L2 + L3 = CP2**) |
| ai | [streams/ai.md](_agents/streams/ai.md) | Brains that execute doctrine, ≤ 4 ms per tick at 60 units, suppression-aware behavior, the tactics ladder, groundwork for offline discovery |
| audio | [streams/audio.md](_agents/streams/audio.md) | Announcer variance then the real ElevenLabs run and live wiring, cinematic sound effects, the match-mood signal, the dynamic music pipeline |

Paused: netcode, army and progression, new Meshy art (88 credits). Ownership, contracts (L1–L5, K1–K5, C1–C8),
checkpoints and gates: [`_agents/workstreams.md`](_agents/workstreams.md).

**Start each agent** in its worktree (`cd ~/projects/godot-<stream> && claude --dangerously-skip-permissions`), the
same text for all five:

> /goal You are a Tank Squad workstream agent in the orchestrator/worker pattern. Your stream is determined by your working directory: the folder is `godot-<stream>` and the git branch is `stream/<stream>`. Run `pwd` and `git branch --show-current` to confirm them, and stop if they disagree. The lead is mostly away: never wait for an answer except at lead gates; record questions in your brief's Status, message the orchestrator session when something needs another stream, and keep working. Read CLAUDE.md, HANDOFF.md, `_agents/orchestration.md` (the worker contract), `_agents/orientation.md`, `_agents/game_design.md`, `_agents/workstreams.md`, then `_agents/streams/<stream>.md`. Work through its backlog in order, then its stretch items: test first, build, verify with `make remote T=check` (builds run on builder0), smoke test like a player and look at your screenshots, commit every green step, and keep the brief's Status current. Done when every backlog item is complete, waiting on a lead gate, or written up as blocked; `make check` passes on your last commit; and the Status holds your report.

**Orchestrator duties:** merge CP1 (doctrine's elements) and CP2 (combat's suppression and rosters) as soon as they're
announced and tell everyone to `git merge main`; relay anything waiting on the lead the same day; final integration
order combat → doctrine → ai → control → audio, with `make remote T=check` after each.

## Waiting on the lead

1. ~~Announcer text review~~ **approved 2026-09-16** (*"we can have an agent go ahead and run the full ElevenLabs
   pipeline"*), with one note: the PA repeated her opening across matches, so the audio stream fixes variance before
   generating. All three voices exist (`JR1`, `corporate2`, `veteran`).
2. **Meshy credits: 88 left.** Round 3 spent 600 (concepts 360, models 240). Any new art next round needs a top-up.
3. **Ad art and copy** for the arena screens (placeholders ship today): the humor direction applies (believable,
   slightly off).
4. **Carried over:** rotate the Meshy API key (it was pasted in chat once); Git LFS for generated art; the round-2
   questions in `streams/archive/round2/` (army unlock pacing, tier names, challenges as a tutorial).

## Open questions and follow-ups (not scheduled)

- **Factions as gameplay.** The art exists (15 vehicles in `game/theme/factions/`, gallery-only, excluded from the web
  export). Playable factions need catalog entries, per-faction mechanics, and balance. The lead's picks settled the
  specials (game_design.md *Factions*); the Lancer now sits in both the Condemned and Syndicate rosters, which is a
  design question.
- **A scout's counter** (ai asked, ruled in game_design.md): scouts are spotters first; `good_vs` claims must be real
  in the mechanics. Combat still owes the `scout > lancer` claim a mechanic or its removal.
- **Unit-count bench:** frame time, draw calls, triangles, and simulation time at 25/50/100/200 vehicles.
- **Cross-build determinism** ([determinism.md](_agents/determinism.md) D1–D4), including glibc differences.
- **AI Commander** (bring-your-own Gemini key → Gemini Nano on Android), the Steam build, arena announcer audio, the
  paused netcode and army/progression streams.
- **Disk:** the laptop is at 95% (about 6 GB free). `assets/incoming/` alone is 968 MB of raw generated art.

## Starting the next round

The pattern, the kickoff prompt, and the checklists are in [`_agents/orchestration.md`](_agents/orchestration.md).
Round 4's streams get written into [`_agents/workstreams.md`](_agents/workstreams.md) and `_agents/streams/` when the
lead's playtest feedback lands.

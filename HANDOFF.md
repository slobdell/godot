# HANDOFF

> **Read [`_agents/orientation.md`](_agents/orientation.md) first.** Then [`_agents/orchestration.md`](_agents/orchestration.md)
> (how we work: the orchestrator/worker pattern), [`_agents/game_design.md`](_agents/game_design.md) (what the game is), and if
> you're a workstream agent, [`_agents/workstreams.md`](_agents/workstreams.md) and your brief in `_agents/streams/`.

_Last updated: 2026-09-15. **Round 3 is merged into `main`, verified, and closed. Round 4 isn't planned yet: it starts
from the lead's playtest.**_

## Current state (main)

- **Verified:** `make remote T=check` green on builder0 (656 tests, every smoke test, the announcer's Python tests).
  Sim baseline `glibc-2.43 d7967d8b36d4417b` (builder0 is canonical; record with `make remote T=sim-baseline-record`).
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

## Waiting on the lead

1. **Announcer text review (lead gate 2).** The booth page: https://claude.ai/artifact/FCkbZb1uyg4fjcBfEpRttw;
   transcripts in `assets/announcer/transcripts/`; the line library is `assets/announcer/lines.json` (429 lines).
   Its questions: is the PA subtle enough, is the caller's hype authentic, are the faction lines right, and approve the
   spend (about 28,500 characters for 701 clips; a ~250-character pilot first is recommended). **No ElevenLabs call has
   been made.** All three voices now exist (`JR1`, `corporate2`, `veteran`).
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

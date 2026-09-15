# HANDOFF

> **Read [`_agents/orientation.md`](_agents/orientation.md) first.** Then [`_agents/orchestration.md`](_agents/orchestration.md)
> (how we work: the orchestrator/worker pattern), [`_agents/game_design.md`](_agents/game_design.md) (what the game is), and if
> you're a workstream agent, [`_agents/workstreams.md`](_agents/workstreams.md) and your brief in `_agents/streams/`.

_Last updated: 2026-09-15. **Round 2 is merged into `main` and verified; round 3 is planned and its worktrees are
fresh from `main`.**_

## Current state (main)

- **Round 2 merged** (rules, ai, command, art, army) with integration fixes: unit icons skip unprojectable positions,
  command tests follow mixed-unit squads, loss messages use "an IFV", a float threshold made a messages test flaky,
  player words for the AI's new behaviors. Reports: `_agents/streams/archive/round2/`.
- **Verified:** `make check` green (414 tests, every smoke test) locally and on builder0.
- **Sim baseline:** per glibc version in `tests/baselines/sim_state_hash.txt`: builder0 `glibc-2.43 c9cfbb1a221f5c94`
  (canonical), laptop `glibc-2.39 772dfb5198e15909` ([determinism.md](_agents/determinism.md)).
- **Remote builds:** `make remote T=check` runs on builder0 in 6 min 40 s (14–22 min on the laptop):
  [remote_builds.md](_agents/remote_builds.md).
- **Play it:** `make skirmish` (the round-2 game: fixed units, friendly fire, cover-seeking brains, the roster and arena
  art, tap-style commanding), `make garage` (army builder, progression, challenges), `make vehicle-gallery`.
- **The lead's verdict on it (2026-09-15):** boring, burdensome to command, units unresponsive, combat lifeless,
  weapons wrong. Round 3 exists to fix that ([game_design.md](_agents/game_design.md) *Round 3 direction*).

## The lead's round-3 decisions (2026-09-15)

- **Desktop first; Steam is the primary target for now.** Android with Gemini Nano follows once the game is fun.
- **StarCraft-style control:** select, box, control groups, right-click orders, attack-move, queues, follow;
  **automatic formations**; orders always win; units regroup.
- **Arcade-tactical feel** (Twisted Metal 3 energy): move while shooting, dodge, flank for weak spots, cover pops.
- **Weapons:** tank = slow, devastating, costly misses; IFV = 25 mm bursts; scout = forward machine-gun stream.
- **Assets:** stackable 20/40 ft containers and giant ad screens; **concepts for all three new factions** (review page
  before any 3D).
- **Announcer:** build the script engine and pipeline, **no ElevenLabs calls** until the lead reviews transcripts;
  humor must be subtle (believable, slightly off), JR is authentic UFC-style hype.
- **Remote builds on builder0** (done by the orchestrator before launch).
- **Reuse the orchestrator/worker pattern** without re-explaining it: [orchestration.md](_agents/orchestration.md).
- Answered from round 2: control point on by default; finite ammo only for artillery; scouts are spotters first.

## Round 3: six streams

| Stream | Brief | Outcome |
|---|---|---|
| control | [streams/control.md](_agents/streams/control.md) | StarCraft-style selection and orders, instant response, regrouping, automatic formations, selection panel (K1 Orders API = CP1) |
| combat | [streams/combat.md](_agents/streams/combat.md) | Weapons rebuilt, weak spots, arcade driving with turning circles, artillery deploy, matchup matrix (K2 weapon events + K3 locomotion = CP2) |
| ai | [streams/ai.md](_agents/streams/ai.md) | Circle-strafing, dodging, weak-spot flanking, cover pops, a CPU that maneuvers and uses formations; orders always win |
| feel | [streams/feel.md](_agents/streams/feel.md) | Weapon and hit effects, weak-spot hits, wrecks, sound, order and selection feedback |
| assets | [streams/assets.md](_agents/streams/assets.md) | Containers, ad screens, faction concepts → approved 3D, artillery outriggers |
| announcer | [streams/announcer.md](_agents/streams/announcer.md) | Event fixtures, the banter director, transcripts for review; pipeline tested with a mock (no API calls) |

Paused: netcode, army/progression, faction gameplay. Ownership, contracts K1–K5 (+ standing C1–C8), checkpoints, and
lead gates: [`_agents/workstreams.md`](_agents/workstreams.md).

**Start each agent** in its worktree (`cd ~/projects/godot-<stream> && claude --dangerously-skip-permissions`), the
same text for all six (also in [orchestration.md](_agents/orchestration.md)):

> /goal You are a Tank Squad workstream agent in the orchestrator/worker pattern. Your stream is determined by your working directory: the folder is `godot-<stream>` and the git branch is `stream/<stream>`. Run `pwd` and `git branch --show-current` to confirm them, and stop if they disagree. The lead is mostly away: never wait for an answer except at lead gates; record questions in your brief's Status and keep working. Read CLAUDE.md, HANDOFF.md, `_agents/orchestration.md` (the worker contract), `_agents/orientation.md`, `_agents/game_design.md`, `_agents/workstreams.md`, then `_agents/streams/<stream>.md`. Work through its backlog in order, then its stretch items: test first, build, verify with `make remote T=check` (builds run on builder0), smoke test like a player and look at your screenshots, commit every green step, and keep the brief's Status current. Done when every backlog item is complete, waiting on a lead gate, or written up as blocked; `make check` passes on your last commit; and the Status holds your report.

**Orchestrator duties this round** ([orchestration.md](_agents/orchestration.md) §6–8):
1. **CP1:** when control announces the K1 Orders API, merge `stream/control` to `main`; tell ai, combat, and feel to
   `git merge main`.
2. **CP2:** when combat announces K2 + K3, merge `stream/combat`; tell ai, feel, and control to `git merge main`.
3. Relay the assets review pages (one per faction) and the announcer's transcripts to the lead; record answers.
4. **Final integration order:** combat → control → ai → feel → assets → announcer, `make remote T=check` after each.

## Open questions for the lead

1. From round 2 (answer any time): army's unlock pacing (~3.7 h to unlock everything), tier names, challenge missions
   as a tutorial path; command's radar tap and commander election (likely moot with the new controls); art's web
   `.pck` size (20.3 MB) and listening to the synthesized engine and crowd sounds; ai's question whether autonomous
   squad tactics should be weaker so player coordination matters more.
2. **Carried over:** rotate the Meshy API key (it was pasted in chat once); move `MESHY_API_KEY` and
   `ELEVENLABS_KEY_ID` above the interactive guard in `~/.bashrc` (line 6) so agent shells see them (the assets
   stream needs Meshy; announcer makes no calls this round); Git LFS for generated art; create the Veteran voice.

## Follow-ups to track (not in round 3)

- **Cross-build determinism** ([determinism.md](_agents/determinism.md) D1–D4), now including glibc differences.
- **Unit-count bench** (roadmap *Next*): frame time, draw calls, triangles, and simulation time at 25/50/100/200
  vehicles; decides squad sizes. The roster gallery draws ~331k primitives for 10 vehicles.
- **Factions as gameplay** (after the core is fun): a `faction` field, then the road gangs first.
- **AI Commander** (bring-your-own Gemini key → Gemini Nano on Android), Steam build details, arena announcer audio.

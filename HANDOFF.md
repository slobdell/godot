# HANDOFF

> **Read [`_agents/orientation.md`](_agents/orientation.md) first.** Then [`_agents/orchestration.md`](_agents/orchestration.md)
> (how we work: the orchestrator/worker pattern), [`_agents/game_design.md`](_agents/game_design.md) (what the game is), and if
> you're a workstream agent, [`_agents/workstreams.md`](_agents/workstreams.md) and your brief in `_agents/streams/`.

_Last updated: 2026-09-18. **Round 5 is closed and merged; round 6 is planned and launching.**_

## Current state (main)

- **Round 5 is fully merged** (render, arena, control, combat, ai, audio). Briefs and their reports are archived in
  [`_agents/streams/archive/round5/`](_agents/streams/archive/round5/); the measurements behind their numbers are in
  [`_agents/streams/references/`](_agents/streams/references/), each with its commit, machine and caveat.
- **The frame rate fight is won.** The lead's round-6 playtest does not mention it once. The simulation runs at
  **30 Hz** with physics interpolation, physics is **Jolt**, and the target the lead chose is **a locked 30 fps at
  1080p with 30 a side, plus a 720p 60 fps option** (his round-5 sign-off). Baseline for scale: 60 fps used to hold at
  13 vehicles at 720p and never at 1080p.
- **The game today:** StarCraft-style control with a camera that only shows what your force can see; elements that
  pick formations and run battle drills from real doctrine, the same library for you and the CPU; suppression that
  makes base-of-fire-and-maneuver real; four playable factions with their own rosters and doctrine; tank shells you
  can watch fly; a voiced announcer trio; layered sound and a music director; seven arenas.
- **Builds run on builder0:** `make remote T=check`. **Budget 30–50 minutes during an active round, not the 7 minutes
  the docs used to claim** — measured ~50 min for 1010 tests on `main` at `5c68a03e` with six streams live, because
  builder0 runs two slots and four concurrent checks both queue *and* slow each other
  ([remote_builds.md](_agents/remote_builds.md)). So: **iterate with a local `make check`, spend a remote slot only on
  a merge candidate**, and ask the orchestrator to clear a window for a big measurement series. **Read the result from
  the wrapper's own `>> remote: make check exited <N>` line and the runner's `N passed, M failed` — never a shell exit
  code through a pipe, and never the `waiting for a heavy-run slot` line, which is printed on enqueue and never
  retracted.**

## Round 6: six streams (planned 2026-09-18)

Goal: **movement you can trust, and a squad that forms up.** The lead played round 5 and stopped at vehicles that get
stuck behind each other, formations that never form, buttons he can't name, a long dead pause after FIGHT, a camera
too far above the fight, empty stands, and weapons that open fire the moment anyone is visible
([game_design.md](_agents/game_design.md) *Round 6 direction*, his words in full).

| Stream | Brief | Outcome |
|---|---|---|
| nav | [streams/nav.md](_agents/streams/nav.md) | A horde gets where it is sent: real path planning, local avoidance with peer-to-peer right-of-way, nothing stuck, one regulated control law (PID). Proven on a maze (**N1 = CP1**) |
| squad | [streams/squad.md](_agents/streams/squad.md) | A squad order is a *formation* order: one formation system, a slot per unit, a form-up ETA, and every named task doing what it says (**N2 = CP3**) |
| control | [streams/control.md](_agents/streams/control.md) | The squad UX earns every button: military task symbology, nothing the mouse already does, a camera between StarCraft 2 and Twisted Metal, loading that shows itself |
| arena | [streams/arena.md](_agents/streams/arena.md) | Terrain that makes ambush and flanking possible, objectives off the centre line, and the maze nav is measured against (**N3 = CP2**) |
| combat | [streams/combat.md](_agents/streams/combat.md) | Seeing an enemy is not the same as opening fire: acquisition, a real effective band, fire discipline (**N5 = CP4**) |
| feel | [streams/feel.md](_agents/streams/feel.md) | The arena is inhabited: a crowd in the stands that can be seen and heard, and a place that reads from a low camera |

Ownership, contracts (N1–N6, M1–M3, L1–L5, K1–K5, C1–C8), checkpoints and invariants:
[`_agents/workstreams.md`](_agents/workstreams.md).

### What the survey found, and every stream's brief is built on

- **There *is* pathfinding** (Godot `NavigationServer3D` over a navmesh, i.e. A* over polygons). What is missing is
  everything about *other units*: no RVO/ORCA, no separation, no reservation, no negotiation. One mechanism exists —
  `_around_friends`, which sidesteps the **single nearest ally** by 5 m without checking the sidestep against the
  navmesh, ignores enemies entirely, and is a no-op outside a `TankBrain`.
- **A stuck unit then lies about it.** `TankBrain.ORDER_STALL_ARRIVE = 12.0`: after 3 s of no progress, a unit within
  **twelve metres** of its goal declares the order complete. That is why a jammed horde looks like it *decided* to
  stop.
- **The formation abstraction the lead described exists three times** — `game/control/group_formation.gd` (used by a
  plain player move), `game/ai/formations.gd` + `squad.gd` (≤ 5 members), `game/tactics/tactics_formation.gd` (any
  size, sectors, the best of the three) — with three shape tables, three assignment rules, three pacing rules, and no
  single owner. And **a plain `move` deliberately bypasses the element layer and dissolves the element**
  (`rts_controls.gd:42-46`), so his commonest order is the one that turns a squad back into loose vehicles.
- **Formation slots are never validated against geometry** — clamped to the arena rectangle only, so a wedge beside a
  container stack puts vehicles inside it.
- **Steering is a pure P controller** with one gain for the whole game (`turn = clamp(-error/30°, ±1)`), which is
  exactly the gap the lead's PID instinct points at.
- **Firing needs no acquisition.** `_shootable()` admits any target inside weapon range with a clear physics line of
  sight; the comment records that the `seen` test was found unused and **removed**. And `effective_range == range` for
  every core weapon, so there is no band where a shot is legal but bad. That is the mechanism behind *"units see each
  other and then everyone just starts firing"*.
- **Pitch is welded to zoom** in `rts_camera.gd:179-185` (`lerp(25°, 82°)` over the same slider as `lerp(16 m, 260 m)`).
  A player commanding 30 vehicles zooms out; there is no way to zoom out without tilting to near top-down. The lead
  never chose a bird's eye view — he chose to see his army, and the camera charged him a top-down for it.
- **Nothing about loading is threaded** — no `Thread`, no `WorkerThreadPool`, no `ResourceLoader.load_threaded_*`
  anywhere in `game/`. FIGHT synchronously loads the scene, builds the venue, **bakes the navmesh**, and instantiates
  ~44 vehicles a side in one frame, with no progress UI of any kind.
- **The crowd already exists** and shipped 2026-09-14 — MultiMesh, 900–4000 figures, seats from the stands' rows,
  reacting to `FxWorld.spectacle`, plus a `crowd_voice.gd` murmur and roar bed. So the lead seeing none of it is a
  *diagnosis* job, not a build job: find out what hides it before adding anything.

**Start each agent** in its worktree (`cd ~/projects/godot-<stream> && claude --dangerously-skip-permissions`), the
same text for all six:

> /goal You are a Tank Squad workstream agent in the orchestrator/worker pattern. Your stream is determined by your working directory: the folder is `godot-<stream>` and the git branch is `stream/<stream>`. Run `pwd` and `git branch --show-current` to confirm them, and stop if they disagree. The lead is mostly away: never wait for an answer except at lead gates; record questions in your brief's Status, message the orchestrator session when something needs another stream, and keep working. Read CLAUDE.md, HANDOFF.md, `_agents/orchestration.md` (the worker contract), `_agents/orientation.md`, `_agents/game_design.md`, `_agents/workstreams.md`, then `_agents/streams/<stream>.md`. Work through its backlog in order, then its stretch items: test first, build, verify with `make remote T=check` (builds run on builder0), smoke test like a player and look at your screenshots, commit every green step, and keep the brief's Status current. Done when every backlog item is complete, waiting on a lead gate, or written up as blocked; `make check` passes on your last commit; and the Status holds your report.

**Open orchestrator obligations (round 6):**

1. **Ping arena the moment CP4 merges.** arena is holding X3 (objectives off the centre line) until then, because it
   is a tactical claim that would straddle the range change. At the same ping it re-derives X2's exposure numbers at
   the new effective range — one cheap Python re-run, not machine time. arena found that its static
   exposure/sightline numbers are *mostly* CP4-proof (eye-level rays against box footprints, no weapons involved),
   with one exception it flagged rather than buried: `exposure()` hard-codes a **110 m watcher range**, which is a
   weapon-range assumption wearing a sightline's clothes.
2. **The sim baseline WILL move with CP4, and combat owns the move.** It is not a perturbation: N5 changes when the
   trigger is pulled, so a different battle happens from first contact onward. The order combat set, which the
   orchestrator endorsed: **series → final bands → record the baseline twice on builder0 → one commit.** Until that
   commit exists, **no stream re-runs a determinism-sensitive measurement**, or it will be comparing against a hash
   that is about to be replaced.
3. **Merge CP2 at the commit whose check went green** — arena's maze is on `stream/arena` at `38c15f77` with its own
   five tests passing on the laptop; its `make remote T=check` is queued behind the other worktrees and arena will
   send the hash.
4. **An ElevenLabs request is coming from feel (X3, crowd beds), and it must not be approved until the mix is
   eliminated as the cause.** feel measured the existing crowd murmur as procedural filtered noise at **~43 dB below
   full scale on a Bed bus that is ducked under impacts** — inaudible in a firefight whatever the source material is.
   Recording a better bed and playing it 43 dB down buys an inaudible better bed. The order the orchestrator set:
   solo the crowd, record a real match, fix the mix (bed level, duck depth and release, a ceiling on how far impacts
   may duck the bed), re-listen — *then* ask for credits if it is still thin. Paid generation is irreversible in a way
   a gain change is not (lesson 18), and the standing gate is text → cheap pilot → listen → batch (lesson 19).
5. **nav was not started with the other five streams** (2026-09-18). Its brief now carries arena's full CP2 baseline
   so it starts with the target number rather than rediscovering it; squad has been told to take its two independent
   items first and explicitly *not* to build its own avoidance to fill the gap.

**Orchestrator duties this round:** merge CP1 (nav's Movement API) and CP2 (arena's maze) as soon as they're announced
and tell everyone to `git merge main`; **CP4 (combat's engagement envelope) lands once and early, and every stream
re-runs its measurements after it — nobody publishes a number that straddles it**; get control's camera page in front
of the lead the day it exists; relay findings between streams; rescue git-ignored payload from worktrees before
removing them ([backups.md](_agents/backups.md)). Final integration order: nav → combat → squad → arena → control →
feel.

## Waiting on the lead

1. **The camera look** (round 6's main gate): control produces `make camera-looks`, a page of the same fight at a grid
   of pitch × distance × FOV. "Between StarCraft 2 and Twisted Metal" needs a picture he points at.
2. **Which arena is fun** — unanswered since round 5; he has still never played them.
3. **The Lancer sits in two factions** (Condemned `lancer`, Syndicate `syn_lancer`): the role is shared, the vehicle
   isn't. One of them may want to lose it.
4. **Meshy credits: 88 left.** Any new 3D art needs a top-up. ElevenLabs has ~123k.
5. **Git LFS, eventually.** `.git` is 353 MB and grows with every regeneration. The rule to adopt when it hurts:
   generated binaries that *ship* go in LFS; generated *sources* stay out of git and live in backups.
6. **Faction art is excluded from the web export** (47 MB): the three new rosters *play* as themselves but *look* like
   the Condemned in the browser. Desktop ships the real art.
7. **Carried over:** rotate the Meshy API key; the round-2 questions in `streams/archive/round2/`.

## Open questions and follow-ups (not scheduled)

- **Backups are automatic** ([backups.md](_agents/backups.md)): a systemd user timer rsyncs the git-ignored generated
  assets to `builder0:~/tank_squad_backup/` every 30 minutes, never deleting. `make backup`, `make backup-status`.
  **A worktree's ignored payload is still only in one place until it's copied into the main checkout** — round 5's
  close rescued 195 MB of announcer and ElevenLabs masters out of the audio worktree.
- **The element layer does not yet earn its place at 30 a side.** With the control point on, brains-only beat faction
  doctrine 34-14; with it off, 27-21; cutting `break_contact` reaches parity (24-24), not better. The army-level layer
  proposed in `doctrine.md` is a **bet** on the missing layer being *above* the elements, not a fix for the drills.
  Evidence: `archive/round5/ai.md` and `references/round5_ai_ladders.json`.
- **The control point funnels the whole fight** — found independently by three streams. arena owns the fix attempt
  this round (objectives off the centre line), measured with a control that cancels the cause, not more seeds.
- **The road gangs win 23%** (Condemned 70%, Law 63%, Syndicate 47%, 5 seeds) — pre-Jolt, pre-30 Hz. Re-measure after
  combat's CP4 before tuning anything.
- **Determinism:** `NavigationServer3D` is on the risk list ([determinism.md](_agents/determinism.md)); the grid-A*
  replacement is unwritten. Navigation map iterations are pinned **synchronous** in `project.godot` (trip-up 57) —
  do not switch them to async to make a loading bar look nicer.
- **Cross-build determinism** (D1–D4), the **AI Commander** (bring-your-own Gemini key → Gemini Nano on Android), the
  Steam build, arena announcer audio, and the paused netcode, garage and progression streams.
- **Disk:** the laptop is at 95%. `assets/incoming/` alone is 968 MB of raw generated art.

## Starting the next round

The pattern, the kickoff prompt, and the checklists are in [`_agents/orchestration.md`](_agents/orchestration.md).
When the lead's next playtest feedback lands, it goes into [`game_design.md`](_agents/game_design.md) verbatim, the
streams into [`workstreams.md`](_agents/workstreams.md), and the briefs into `_agents/streams/`.

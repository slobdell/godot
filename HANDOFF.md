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

### Where round 6 actually stands (2026-09-18, end of the lead's first away window)

**Merged and verified on `main`:** squad's **CP3** (`df736a8e` — one formation system, support-by-fire that forms a
firing line, slots validated against geometry), arena's **CP2** (`5590c465` — the maze, `make nav-maze`, the objective
schema, the stale-navmesh fixture), feel (`e817194a` — the 130× vehicle-spawn load fix and a crowd that reads), and
combat's two make-namespace fixes cherry-picked (`9f798368`, `fd5ac1af`). Plus the `slot.sh` FIFO rewrite.

**Green and waiting on one word:** control's `758a45a8` (the lead's camera, the wall cutaway, the task palette with
Support by Fire and Screen *earned*, the loading screen, X7's "why did my element do that"). X4 is deliberately
**reverted** out of it — see the bar below.

**The round's one dependency chain, and squad is the bottleneck:**
`squad's two precedence fixes` → `combat's CP4` → `nav's gunnery.gd split`. combat's branch is **red by construction**
and has refused to chase greenness by weakening a test that is telling the truth. If squad stalls, the round stalls;
re-cut priorities rather than letting nav or combat idle.

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
3. **CP4 does not merge alone: it merges paired with squad's brain-range fix.** combat's evidence, which the
   orchestrator accepted: `TankBrain._combat_move()` decides where to stand from `weapon["range"]` (full reach) while
   N5 decides firing from the *effective* band, so the outranging and short-halt branches park a unit exactly where it
   may not shoot — measured at **61 m for 45 s, 0 shots, 0 metres, never arrives**. Landing CP4 alone would trade the
   lead's *"everyone just starts firing"* for *"everyone stands still"*, which is a worse game and breaks product
   constraint #1. combat has committed a two-token proposal **in squad's file** (`5478fa61` on `stream/combat`,
   explicitly to take, replace or revert) which makes the scenario finish in **14.9 s — faster than the 20.8 s it
   measured before N5 existed**. squad owns the judgement and the remaining cases; **`scenario_motion::test_brains_dont_dither`
   at 17.7 and 15.6 option switches per minute against a bar of 12 is the blocking one**, because "no element
   flip-flopping" is the round's legibility bar.
4. **DONE — CP2 merged** at arena's green `5590c465` (1018 passed, exited 0). Note for the record: arena first
   reported `38c15f77` ready on a *filtered* run showing 5/5; the full check found 2 failures, and `38c15f77` and
   `13add85d` are both **red**. Merging the commit whose own full check went green (lesson 29) is the only reason that
   never reached `main` — and lesson 45 is the filtered-run half of it.
5. **TWO merges re-time other streams' measurements this round, not one.** CP4 is the known one. The second, found by
   control: **`perf_scene.gd` calls `RtsCamera.pose_for(focus, 0, zoom)`**, so when control's pitch decoupling merges,
   `make perf-scene`'s camera drops from the welded pose to the lead's **12°/FOV 60** — a far lower, wider camera that sees the whole venue to the far stands,
   so feel's **M1** frame numbers move at that merge through no change of feel's own. Relayed to feel; the rule is the
   same as CP4's: **re-baseline after the merge, and never publish a frame number measured across it.** This is the
   generalisable shape — a shared harness that derives its own configuration from another stream's code silently
   inherits that stream's changes.
6. **RESOLVED, and now with the lead: the mix was the cause, and the crowd question costs nothing to answer.** Two
   recordings were sent to him 2026-09-18 while he was away — `build/crowd-listen/full_mix_real_pace.mp3` (the match as
   a player hears it) and `crowd_only_real_pace.mp3`, builder0 vsync-off at tree `1badf779`, Yard, Gangs vs Law, same
   seed. **The one question: is the crowd audible, and does it sound like people or like hiss?** The murmur is still
   round 3's procedural filtered noise. **If hiss**, the ElevenLabs text is drafted in feel's brief under *Waiting on
   the lead*: 5 sources (bed, tense lull, roar, near-miss "oooh", last-stand stomping), **pilot first** —
   `crowd_bed` + `crowd_roar`, ~25 s ≈ **250 credits**, full set ~900 (lesson 19). **If fine, nothing is spent.**
   The mix itself was settled by measurement: at +13 dB the crowd was the loudest bed in the game (~4 dB under the whole
   mix); at **+8 dB** it sits a median **7.5 dB** under (min 5.6), impacts dipping it 2:1 on top; −17.5 LUFS, true peak
   −3.6 dBFS, 0 clipped.
   *The rule that produced this, kept for next time:* an ElevenLabs request must never be approved while the mix could
   be the cause — feel measured the existing crowd murmur as procedural filtered noise at **~43 dB below
   full scale on a Bed bus that is ducked under impacts** — inaudible in a firefight whatever the source material is.
   Recording a better bed and playing it 43 dB down buys an inaudible better bed. The order the orchestrator set:
   solo the crowd, record a real match, fix the mix (bed level, duck depth and release, a ceiling on how far impacts
   may duck the bed), re-listen — *then* ask for credits if it is still thin. Paid generation is irreversible in a way
   a gain change is not (lesson 18), and the standing gate is text → cheap pilot → listen → batch (lesson 19).
7. **Tell nav the hour CP4 merges.** It is doing `movement.gd` first (combat's four edits are all in the gunnery half)
   and the `gunnery.gd` split *after* CP4, so combat's edits move across once instead of conflicting. Its plan, endorsed.
8. **nav must NOT delete `ORDER_STALL_ARRIVE` (the 12 m lie) yet, and knows it.** It is one line in squad's
   `tank_brain.gd` — the file squad has two gating fixes in flight in — and removing it makes arrival numbers look
   **worse** before avoidance makes them better. With three streams measuring, we would lose the attribution on all
   three. It lands later as its own commit with a before/after from arena's harness attached. Its entire value is the
   measurement that comes with it.
9. **X4 is held, not lost, and the bar for re-adding it is written into `rts_controls.gd`:** *0 idle commands on five
   squads in the lead's own sequence.* control measured 31 idle commands and `never_arrived` 0 → 3 of 21 with it on
   (round 5's healthy value was 0) — and "units never arrive" is the lead's *headline* complaint, so it must not ship
   on a hope. **squad owes the answer: designed station-keeping, or thrash?** When it re-lands, the A/B must be re-run
   **on the merged tree** — CP3 changed the formation system underneath the exact path X4 exercises, so 31-against-0
   was measured against a world that no longer exists.
10. **Which arenas are fun is still unanswered** (`fun: []` on both pages, 2026-09-18). arena is spending the round on
   map shape without it. Nothing is blocked; ask again on whatever page he sees next.
11. **nav was not started with the other five streams** (2026-09-18). Its brief now carries arena's full CP2 baseline
   so it starts with the target number rather than rediscovering it; squad has been told to take its two independent
   items first and explicitly *not* to build its own avoidance to fill the gap.

**Orchestrator duties this round:** merge CP1 (nav's Movement API) and CP2 (arena's maze) as soon as they're announced
and tell everyone to `git merge main`; **CP4 (combat's engagement envelope) lands once and early, and every stream
re-runs its measurements after it — nobody publishes a number that straddles it**; get control's camera page in front
of the lead the day it exists; relay findings between streams; rescue git-ignored payload from worktrees before
removing them ([backups.md](_agents/backups.md)). Final integration order: nav → combat → squad → arena → control →
feel.

## Waiting on the lead

1. **The camera look AND which arena is fun — both are on one page, live since 2026-09-18:**
   **https://claude.ai/artifact/6LEzbnaQc1T6oyVo2jmxaL** (private to the lead's account). One frozen 30-a-side fight
   (Condemned vs Syndicate, Container Yard, seed 3, ~6 s after the first shot): row 1 is round 5's four welded poses
   (zoom 0.20/0.36/0.55/0.75 = 34°/45°/56°/68°, the last being the "bird's eye" he disliked); then a grid of
   pitch 25/35/45/60° × distance 28/50/90 m × FOV 45/60°; then an arena tour, all seven arenas at three poses each
   with a **Fun** checkbox. He taps a frame to pick it (optional note) and ticks the fun arenas.
   **His answers are saved in the page's own database at `picks/lead`** — read them back with the Artifact tool's
   `read_db` on that URL, then tell control, which sets the defaults from his pick.
   Provenance: rendered on the **laptop** at 1920×1080 from `stream/control`'s working tree at `a975e262`
   (uncommitted at the time). Frames are camera poses only, so machine and commit do not change what they show.
   **The diagnosis is confirmed by row 1:** the start pose was fine; zooming out is what tilted him to top-down.
3. **The Lancer sits in two factions** (Condemned `lancer`, Syndicate `syn_lancer`): the role is shared, the vehicle
   isn't. One of them may want to lose it.
4. **Meshy credits: 88 left.** Any new 3D art needs a top-up. ElevenLabs has ~123k.
5. **Git LFS, eventually.** `.git` is 353 MB and grows with every regeneration. The rule to adopt when it hurts:
   generated binaries that *ship* go in LFS; generated *sources* stay out of git and live in backups.
6. **Faction art is excluded from the web export** (47 MB): the three new rosters *play* as themselves but *look* like
   the Condemned in the browser. Desktop ships the real art.
7. **Carried over:** rotate the Meshy API key; the round-2 questions in `streams/archive/round2/`.

## Open questions and follow-ups (not scheduled)

- **FIGHT → playable is 7.6 s → 1.4 s** (laptop, `make shell-playtest` gangs vs law on Boulevard: 7,563 ms at
  `a975e262` against 1,398/1,406 ms on two runs of `8d9c59af`'s tree). feel's strong-reference fix did the shortening —
  `make spawn-cost` went from ~63 ms per vehicle to **0.8 ms** after the first of each type — and control's loading
  screen makes the remaining beat legible rather than shorter. **What is left is the arena build + navmesh bake, ~690 ms
  of the 1.4 s**, which is synchronous on purpose for determinism (trip-up 57: async navigation iterations made the same
  seed simulate differently). Not scheduled: it belongs to arena or nav, it is a ~0.7 s win, and it must not be bought
  by making navigation async.
- **Round-3 `matchup-search` numbers in `balance.md` may be unreliable and cannot be re-derived.** A make-namespace
  collision (`UNITS ?= 60` in `mk/ai.mk` reaching `mk/match.mk`) meant **every `matchup-search` run silently passed
  `--units 60` whatever the caller asked for**, and the tool never recorded the value it used
  ([orchestration.md](_agents/orchestration.md) lesson 44). Fixed as `SEARCH_UNITS`. Any conclusion that assumed a
  non-default unit count is suspect; combat flagged this rather than assuming the old numbers were fine. **The general
  fix, worth doing everywhere: print every resolved knob into the output**, so a wrong value shows up in the artefact.
  Related and also open: **nothing checks that a "reproduce with" line in a reference README still runs** — `make
  engagement PAIRS=… SEEDS=3 TIME=240`, documented as the way to reproduce a saved baseline, had been broken since the
  `VARIANTS` default landed. A smoke test that runs every documented reproduce line is a round-7 candidate.

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

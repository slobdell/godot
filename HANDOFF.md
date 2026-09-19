# HANDOFF

> **Read [`_agents/orientation.md`](_agents/orientation.md) first.** Then [`_agents/orchestration.md`](_agents/orchestration.md)
> (how we work: the orchestrator/worker pattern), [`_agents/game_design.md`](_agents/game_design.md) (what the game is), and if
> you're a workstream agent, [`_agents/workstreams.md`](_agents/workstreams.md) and your brief in `_agents/streams/`.

_Last updated: 2026-09-18. **Round 5 is closed and merged; round 6 is planned and launching.**_

## ⚠ READ THIS FIRST: the round stopped on a quota limit, 2026-09-18

**The weekly quota ran out. It resets ~2026-09-22. Every stream session's context is gone; nothing on disk is lost.**
All six stream branches are merged into `main`, every worktree is clean, and each brief's **Status is written for a
stranger** — that was the last thing every stream did before stopping. Read your stream's Status before anything else;
it holds what the session knew that the code does not say.

### The five-minute version of where this stands

**Round 6 is complete and merged.** `main` was last green at **1130 passed, 0 failed** on builder0; the sim baseline is
`glibc-2.43 b0df248dc0140639`, recorded once at the end by the orchestrator (invariant 2). Two merges landed after that
green run (`control`'s camera work and trailing docs), so **re-run `make remote T=check` before trusting `main`** — budget
30–50 minutes.

**What round 6 did:** movement you can trust (100% arrival on every configuration, up from 33/60 on a shipping map),
one formation system instead of three, the player's units holding until ordered *by a rule rather than a coincidence*, a
plain move keeping a squad a squad, loading 7.6 s → 1.4 s, 3,011 spectators visible where 0 of 2,040 had been, a city
skyline, engagement ranges that decide fights at 40 m instead of 54 with flanking up from 26% to 45%, and the maze the
movement work is measured against.

**THE GAME IS STILL NOT PLAYABLE, and the lead said so after the round closed.** Two reasons, in his words: the camera,
and *"getting adequate command of our units (I couldn't tell what direction they were facing)"*. **Round 7's whole
subject is legibility, not capability** — see *Round 7 direction* in [game_design.md](_agents/game_design.md), which holds
his feedback verbatim and is the most important document to read after this banner.

### What was in flight when it stopped, and where to pick it up

| Item | State | Owner |
|---|---|---|
| **The lead's settled camera pose** — `pitch=21 distance_m=49 fov=35`, auto-frame on | committed by control; **`fov=35` is the floor of the range and two agents argued the wrong way about it** | control |
| **Announcer voices cut each other off** | diagnosed only; his rule is *interrupt is fine, the incumbent yields **after** being interrupted, never truncated* | feel |
| **Machine gun: no tracer, and missing sounds** | not started; **ElevenLabs approved broadly** — plenty of credits, a monthly budget that is wasted unspent | feel |
| **Unit scale not honouring `hull_size`** (a gang tank renders smaller than a scout) | not started | feel |
| **The gangs' IFV drives backwards** | not started; **check whether the SIM is reversed too, not just the visual** — if so it has been taking front-armour hits on its rear | feel |
| **Arena verdict: KEEP Pit + Yard, CUT the other four** | recorded, **nothing deleted** — the four are *do-not-invest*; Foundry is `DEFAULT_LAYOUT`, so cutting it is an infrastructure change | orchestrator |

### The three things a fresh orchestrator should not have to rediscover

1. **No agent on this project can play the game** (lesson 72). Everything we call playtesting is scripted input plus
   screenshots. Feel-questions — camera, order legibility, audio presence — can only be answered by the lead. **The
   pattern that finally worked was giving him live in-game controls and one key that prints a pasteable line** (the
   camera took four attempts from still images and one from live controls). Build the instrument, hand it over, let the
   design come out of him using it.
2. **This round found more broken instruments than broken game code.** Lessons 32–75 in
   [orchestration.md](_agents/orchestration.md) are all round 6, and most are measurement failures: three load-bearing
   coincidences, four constants calibrated against a camera that had changed, six tick-rate leftovers of which three
   lied to a *reader* rather than failing a test, a build queue that starved rather than being slow, an audio harness
   recording at 1/10 speed, and a series whose control was not a real "before".
3. **`centre_sees_share` predicts the lead's map taste.** He cut the four most open arenas and kept the two least open,
   with the numbers in front of him but no way to sort by them. That makes it a **design target for new maps**, and it
   is the most transferable thing the arena work produced.

---

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

### Where round 6 actually stands (2026-09-18 evening, the lead away)

**Four streams have finished: feel, control, combat, squad.** arena has delivered its review page and holds one item;
nav is the only stream with work in flight.

**Merged and green on `main`** (every merge at the commit whose own full check went green):
one formation system instead of three · support-by-fire that forms a real firing line · the player's units holding
until ordered, *enforced by a rule rather than by a coincidence* · a plain move keeping a squad a squad without order
thrash · form-up paced by a real navigation ETA · loading **7.6 s → 1.4 s** · **3,011 spectators in the default frame**
(round 5's default showed 0 of 2,040) · stands on all four sides, a city skyline, crowd audible through a proper mix ·
the lead's **12°** camera with the wall cutaway · the task palette with APP-6 symbology, `move`/`follow` off the card,
Support by Fire / Screen / Ambush earned · a loading screen and "why did my element do that" · the maze and
`make nav-maze` · terrain authoring rules · the **N1 Movement API** · engagement ranges: **fights decided at 40 m
instead of 54, off-axis kills 26% → 45%**.

**Held deliberately, and it is the lead's call:** nav's ORCA avoidance + right-of-way + PID reaches **100% arrival in
every configuration** (maze-60 head-on went **0 → 60/60**; `yard`-60 34 → 60/60) but costs a tick of order-response
latency — **4 ticks where K1 guarantees 3 (100 ms)**. Arrival bought with responsiveness is a trade he has not
approved, and *"the units aren't very responsive to my input"* is his own round-5 complaint. **Do not merge it, and do
not let anyone weaken the K1 test, without him.**

**What the round actually taught, and it is not what anyone expected:** it found **more broken instruments than broken
game code**. Three load-bearing coincidences (lesson 50), four constants calibrated against a camera that had changed
(lesson 59), six tick-rate leftovers of which three lied to a reader rather than failing a test (lesson 30), a build
queue that starved rather than being slow (lesson 48), an audio harness recording at 1/10 speed (lesson 46), a
measurement whose outliers were a spawn bug (lesson 57), and a series whose control was not a real "before" and so
hid which half of the change did the work (lesson 62). Lessons 32–62 are all round 6.

**Open orchestrator obligations (round 6):****Open orchestrator obligations (round 6):**

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

- **Dynamic obstacles: deliberately none, and now with a reason rather than a default** (arena ruled, nav verified,
  2026-09-18). **Nothing blocks drivable space mid-match, now or planned**, so a `NavigationObstacle3D` has no consumer.
  The strong argument against building one is **fairness, not cost**: the navmesh is baked as the southern half plus its
  180° rotation *as a second region*, because a normal bake is not point-symmetric — mirrored trips differed by up to
  4.4 m and the south base won 64% of 140 matches (trip-up 21). **Any mid-match re-bake must reproduce that
  construction or silently reintroduce the base bias**, with units standing on the mesh while it happens. And the lead's
  approved destructible-cover design (*a stack collapses to a lower stack, never changing drivable space*) was chosen to
  avoid exactly this, so X6 will not create a consumer either.
  **If round 7 ever revisits the startup-only mesh, it must revisit `agent_max_climb` in the same breath** — both are
  consequences of the same construction, and both need the swap-bases control re-run.

- **The unifying shape of round 7's best candidates, named by arena:** *the correct behaviour depends on what the
  element is currently trying to do.* Round 6 made each layer correct **in general** — avoidance that keeps a column a
  column, an objective at the centre, a formation that holds its geometry — and the residue in every case is that the
  *right* answer changes with the element's current intent. Three items below are the same statement at different
  scales: not overtaking is right for a column and wrong for a charge; a central objective is right for a brawl and
  wrong for a game about flanking; a fixed slot is right for holding and wrong for forming up. **A round that made
  behaviour context-dependent would be the natural successor to one that made it correct.**
- **Should a battle drill override formation discipline?** Round 6's ORCA deliberately does **not** treat a friend
  moving the same way as a collision, so a column stays a column — which is right for formations and is why round 5's
  overtaking sidestep was removed (it also steered into walls unchecked). Attributed cost, measured by bisect: an
  assault-through an ambush now takes **18.5 s against 17.7 s**, because the quick units no longer pass the slow ones.
  **0.8 s is not worth re-adding overtaking for** — it would risk nav's 33/60 → 60/60 arrival result. But *a charge is
  the one case where you might want the fast units through rather than the column preserved*, and the lead would notice
  it as *"my fast units got stuck behind the slow ones during a charge"*. Round-7 question: do drills get to suspend
  formation discipline, and which ones?
- **The lead's PID request is half-delivered, and the missing half is the visible half.** nav's N6 regulates any
  `move_to` whose goal *slides* — a squad follower's leader-anchored slot is such a goal, so **squad station-keeping is
  PID-controlled and measured (0.35 m mean gap against 4.58 m for the old proportional law)**. squad deliberately added
  **no second regulator**, which is right. But **element slots are fixed per leg or per click**, so the PID never
  engages for elements: an element still *snaps* to its formation geometry rather than **flowing** into it. The lead's
  own words were *"no matter where they might be currently, there's a formula to form up"* and *"a PID loop would
  conceptually be useful for a unit trying to get back in his formation"* — the second is delivered for squads and not
  for elements. **Making elements flow into formation is the next build on top of N6**, and it is the piece most likely
  to make the formations *look* as good as they now measure. A round-7 candidate, and cheap now that the regulator
  exists.
- **Per-faction PID gains** (nav's X8, not started): the lead asked for it by name — *"we might even be able to
  differentiate units of different factions by PID values"* — the Syndicate crisp, the gangs loose. `control_gains.gd`
  exists and the defaults are stable, so this is now a data exercise. It must be **measured** rather than shipped as
  flavour: if identical armies with different gains win equally often and look the same on screen, say so.

- **A texture leak on `main` that `make check` cannot see** (found by control on the merged tree at `2fa58c01`,
  laptop, windowed): `make shell-playtest` fails its clean-console gate with two `ERROR: Texture with GL ID of
  142/143: leaked 5460 bytes` lines, absent in all seven pre-merge runs. Likely feel's `night_sky`/skyline shaders or
  `arena_environment` crossing the **title → skirmish scene switch** — control's inference, not a proof; routed to
  feel. **Why it matters beyond two console lines:** `shell-playtest` is **not in `make check`**, so `main` goes green
  with it; a leaked resource is an **ERROR**, and the relay and net smokes fail their clients on any ERROR
  (trip-up 75), so this may be one scene switch from breaking a gated smoke; and it happens on the transition every
  player crosses. **Round-7 candidate regardless of this fix: `shell-playtest`'s console gate belongs in `check`, or
  its expected state belongs in a committed baseline** (lesson 42 — do not simply add a red suite to the gate).
- **The void below the near wall.** The ground plane ends at the stands, so any camera outside the venue looks down
  into black — the bottom 15–40% of a far frame, **seen every match at the lead's 12°**. feel's to fill (a dark plaza,
  car park or road out toward the new skyline).

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

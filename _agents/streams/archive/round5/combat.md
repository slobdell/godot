# Stream: combat (make the fight a fight, not two masses)

> **Archived 2026-09-18:** round 5 is merged into `main`. This brief and its Status are the record of what the
> stream did; the current round is in [../../../workstreams.md](../../../workstreams.md).

> Read [../orchestration.md](../../../orchestration.md) (the worker contract), [../game_design.md](../../../game_design.md)
> (*Round 5 direction*, *Units*, *Factions*), [../workstreams.md](../../../workstreams.md) (you consume arena's M2 and render's
> M1), [../balance.md](../../../balance.md), [../doctrine.md](../../../doctrine.md) and your round-4 report
> [archive/round4/combat.md](../round4/combat.md). You own `game/units/`, `game/combat/`, `game/match/`,
> `game/tank/`, `tools/{match_series,matchup_matrix,combat_duel,matchup_search}.py`, `mk/match.mk`,
> `game/modes/match_runner_mode.gd`, `_agents/balance.md`.

> **Picking combat up fresh? Three files, in this order.** (1) [../balance.md](../../../balance.md) **START HERE** — why no
> balance series may run until the baseline is re-taken, and how to run a fair one; (2)
> [../sim_tick_rate.md](../../../sim_tick_rate.md) — the 30 Hz tick: what it bought, what it cannot buy, and how tick counts
> are written now; (3) this brief's **Status** for what round 5 actually did. The tools:
> `make sim-profile` (where a tick goes), `make engagement` (the shape of a fight), `make team-fairness` (army, team
> and base controls), `make duel`, `make faction-matrix`, `make matchups`, `make scale-bench` — all in `make help`.

## The lead's direction (2026-09-17)

> *"right now, I can't tell if perhaps the vehicles have too much range, but when I play the game now it's just these 2
> masses shooting at each other."*

That's the whole brief in one sentence: **if both armies can hurt each other from where they start, there is no
maneuver, no flanking, no reason for cover, and doctrine has nothing to decide.** Everything else here is secondary.

## Where things stand (updated at the close of round 5)

- **The fight's shape is measured but untuned**, and it must be re-measured before it is tuned: see the Status and
  balance.md's START HERE. The engagement numbers below are pre-round-5 and were taken on collisions, not battles.
- **The simulation runs at 30 Hz** (interpolation on, catch-up capped at 3). Brains are ~85% of a tick and are the
  frame-rate lever now; the tick rate cannot reduce their thinking half.
- **Jolt is the physics engine**; hulls move in floating mode; `Lethality` answers "can I kill this quickly".
- Round 4 landed suppression, three playable factions, heavies shielding the fragile, and a 30–58% cheaper simulation.
- **Ranges were never re-tuned for 30 a side on a 240 m map.** A tank's shell reaches 70 m, a Lancer 90 m, artillery
  160 m; with 30 vehicles a side the front is wide and everything is in range of everything at contact.
- **The road gangs win 23%** (Condemned 70%, Law 63%, Syndicate 47%). Two real defects were fixed without moving it.
- The Lancer role sits in both the Condemned and the Syndicate; the lead may want one of them to lose it.
- ai reports two behaviour gates that are partly yours: SUPPRESS is unreachable in a duel because the "killing this is
  slow going" test reads a matchup table the champion runs without, and a pinned enemy doesn't pull units out of cover.

## Backlog (in order)

**X1. Make range and sight produce maneuver.** Measure first: in a 30-a-side match, how far apart do the armies stop,
how much of the match is spent in one static exchange, and what fraction of shots are taken from inside cover? Then
tune the levers — weapon ranges, sight radii, accuracy at range versus moving, time-to-kill, and (with arena) the
distances their maps create — until the fight has phases: approach, contact, maneuver, decision. **Target to state in
balance.md:** a majority of kills come from the flank or rear, and the armies' centre of mass moves during the fight.

**X2. Cover has to be worth using.** With arena's new layouts (M2), check that hard cover blocks shots, that a unit
behind it is meaningfully safer, and that crossing open ground is a decision. If suppression plus cover doesn't change
where units die, say so with numbers and fix the mechanic.

**X3. The gangs at 23%.** Re-run `make faction-matrix SEEDS=5 TIME=150` on today's `main` (suppression, drills and
avoidance all landed after those numbers), then fix what the data shows. Swarms should trade numbers for reach: cheap,
fast, lethal up close, punished at range. If the counter to a swarm is "stand still and shoot", the swarm has no game.

**X4. The duplicated Lancer.** Decide with evidence whether the Condemned or the Syndicate keeps it (or what replaces
it), and write the reasoning in balance.md.

**X5. Behaviour gates that are really rules** (with ai): give brains a matchup-free way to know "I can't kill this
quickly" (penetration against armour) so SUPPRESS is reachable, and make being pinned actually worth exploiting.

**X6. Re-measure and write it down.** The matchup matrix, a faction-versus-faction series and the engagement-range
numbers from X1, after arena's maps land. balance.md gets the story, not just tables.

- **Stretch:** wrecks as cover (the prop exists); a ram or boost if the driving wants it (propose first).

## How to verify

`make remote T=check` with the sim baseline updated on purpose; `make duel` timelines; seeded series and the matrix on
builder0; and **watch a 30-a-side match** (`make skirmish` or `make cinematic`) and describe its phases in Status.

## Don't touch

Arena layouts (arena; request shapes you need), vehicle art and effects (render), brains (ai; request changes), UI and
camera (control), audio (audio).

## Status

- 2026-09-17: brief written for round 5. Nothing started.
- 2026-09-17: **started.** Baseline `make remote T=check` green on builder0 (`stream/combat` at `faaaac2`).

- 2026-09-17: **re-prioritised by the orchestrator after CP1:** the simulation tick is the frame-rate blocker, so its
  cost comes before X1's engagement ranges (M1: the whole tick <= 5 ms at 60 vehicles on the laptop, shared with ai).

### CP1: simulation cost (in progress)

**Measured.** `make sim-profile` (new: `SimProfile` marker nodes split a tick by process-priority band, plus sections
inside Match / Tank / Shell; `PROFILE_FLAGS=--no-brains`) on the laptop, Condemned 31 v 27, 60 s: **11.6 ms a tick,
9.3 ms of it the priority -10 band = ai's OrderController + TankBrain**; combat's own share ~2.2 ms (Tank 1.67, of
which driving 1.05; Match 0.47; shells 0.02). builder0 runs about 2x faster than the laptop: halve laptop budgets
when reading builder0 numbers. Merged to `main` early for ai (cc9a01e).

**What worked** (same-load A/B on builder0: two copies side by side, twice; tank section per vehicle):

| Change | Effect | Sim baseline |
|---|---|---|
| Floating motion mode, `max_slides` 2 (flat arenas) | tank cost **-16%** | moves (the only change that does) |
| Parked hulls skip the motion step; basis only when turning; no per-tick `TankCommand` allocation | tank cost -8% | parked skip is exact |
| `ThreatField.decay` over active cells only | suppression pass ~-30% | bit-identical |
| `Tank._process`: nameplate and visual setters only on change | per-frame, not per tick | none |

**What didn't:** skipping `move_and_slide` for hulls with nothing in reach (`MotionClearance`, a static grid from the
arena's collision boxes plus a per-tick hull bucket hash). It skipped half the slides and cut drive cost 27%, but
building the grid in GDScript cost 0.17-0.24 ms a tick, so it was net zero. Removed, not shipped.

**Proposed, for the orchestrator and the lead:**
- **Jolt physics** (`project.godot`, shared): with floating mode, tank cost **-28%** and the whole tick **-17%**
  including ai's band (cheaper raycasts). A full `make check` on a Jolt scratch copy reports what breaks.
- **A 30 Hz simulation tick with physics interpolation** halves everything per tick, ai included:
  [../sim_tick_rate.md](../../../sim_tick_rate.md) (inventory of every 60-per-second assumption, what interpolation breaks,
  a three-step plan). A cross-stream refactor, so a proposal, not started.

**Landed:** Jolt (b52e8b9, orchestrator-approved; merged to `main` as 8d975fa, baseline `83f1272ade466282`).

### Fairness: the "Green wins 25%" lean was army luck (2026-09-17)

Arena measured Green winning 25–28% of seeded mirrors on every map. `make team-fairness` (new: `--swap-armies`,
`--same-army` on the match runner) says: the winner follows the **army draw** (swapping armies flips 15 of 16 seeds;
seeds 1–16 gave Rust Armor/Balanced and Green Swarm/Recon); **team identity** (processing order) and **base position**
are neutral (fresh seeds 17–64: north base 24/48 and 25/48). The RNG has no parity bias. Rule written into
balance.md: counterbalance armies in every series.

### X1: measured, tuning on hold

`make engagement` (Jolt, brains only, 15 matches): contact 4 s in at 108 m, fighting at ~71 m, kills at a median 52 m;
hull-level numbers look lively (2% standing still, 61% side+rear hull hits) but the army view is the lead's "two
masses": only 13% held line, **73% of kills straight across the line between the armies, 4% from behind it**, and
the pushing army gains 26 m. A range-falloff mechanic is in (`effective_range` per direct-fire weapon, inert at
= range) with variants ready (`tools/matchup_variants/x1_range_falloff.json`). **On hold:** ai found the match runner
never runs doctrine (elements, drills), and doctrine beats brains-only 52–28, so tuning waits for `TacticsFlags` on
`main` and a deliberate doctrine-on re-baseline of the balance series (orchestrator's call, 2026-09-17).

### X5: rules for brains (in progress)

- `Lethality.seconds_to_kill(shooter_unit, target_unit, face, health, shield)` and `is_slow_kill` (> 20 s): the
  matchup-free "I can't kill this quickly" for ai's SUPPRESS gate. Relayed to ai.
- Pinned is worth exploiting: suppression shrinks a crew's sight (up to 40%) and its hull turn rate (up to 50%), so a
  flanker gets closer unseen and the hull can't swing its front armor round in time. Tests include a flanker at 80%
  of sight that a calm crew sees and a pinned one doesn't (mutation-checked).

### 30 Hz simulation tick (the lead's call, 2026-09-17; combat owns it)

Plan, inventory and the render/control interpolation checklist: [../sim_tick_rate.md](../../../sim_tick_rate.md).
Steps 1–2 are on the branch and green at 60 Hz with the **baseline unchanged**, which is the proof the conversion is
exact: `SimClock.TICK_RATE` (game/match/sim_clock.gd) drives every tick count in match, tank, combat, ai, tactics,
control's three constants, the announcer and NetworkInput; `SIM_HZ` in the Makefile drives every `--fixed-fps` and the
Python tools; ~36 test files count seconds through SimClock. Step 3 (the flip) is measured on a scratch copy of the
branch on builder0 before it lands.

**Two real defects the 30 Hz run exposed, both fixed at 60 Hz first (each moves the baseline on purpose):**
1. **Guns fired a tick late.** Controllers run before the tank in a tick and read the reload the tank published
   *last* tick, so `ready_to_fire()` was always one tick stale: a 0.1 s machine gun fired 8.6 times a second at
   60 Hz and 7.5 at 30 Hz instead of 10. Every beaten zone in the game was thinner than its data said. Fixed in
   `Tank.ready_to_fire` (the simulating peer counts a reload that ends this tick as ready), mutation-checked.
2. **A unit going round a beaten zone thrashed at 30 Hz.** A beaten zone pulses, so a momentary reading below the
   threshold looked like the fire lifting: the unit dropped its step and picked the other side on the next check,
   staying in the lane (19 ticks in it against a control's 16). `OrderController.FIRE_LEG_MIN_TICKS` keeps a step for
   0.25 s. At 30 Hz the avoider now spends **0 ticks** in the beaten zone against the control's 16.

**Landed (ae58286c):** the simulation runs at 30 Hz with physics interpolation, `max_physics_steps_per_frame` 3, and
the sim baseline `glibc-2.43 16dc0de84f1c29b6` (recorded twice). `make remote T=check` green at 30 Hz: 935 passed,
every smoke. What it bought, and what it did not: [../sim_tick_rate.md](../../../sim_tick_rate.md) *What it bought*.
Short version, settled with render: **simulation script cost per simulated second fell a quarter to a third**
(513 → 377 ms and, repeated on the tip, 490 → 329 ms on the laptop; only per-tick work halves, and thinking is on a
wall-clock cadence). At 1080p a locked
30 fps holds **~29 vehicles on a quiet laptop** and **12–15 while agents are working on it** (render's measurement of
the same build); before the round it was 60 fps at 13 vehicles at 720p and never at 1080p. At the lead's 60 vehicles
it is ~100 ms a frame, so **the target is not met by the tick change alone**, and ~85% of what is left is the brains.

## Report (2026-09-17)

**Done:** CP1's simulation-cost work (profiler, cuts, Jolt), the 30 Hz tick with everything it exposed, X1's
measurement half, X5 in full, and the fairness answer. **Not done: the tuning half of X1, X2, X3, X4, X6** — every one
of them is a balance series, and three separate findings landed today saying the series would have measured the wrong
game (below). Nothing is blocked on the lead.

| Item | State |
|---|---|
| CP1 sim cost | Done: `make sim-profile`, floating hulls, parked hulls, active-cell threat decay, per-frame caching, Jolt (merged), and the 30 Hz tick |
| X1 ranges and maneuver | **Measured, not tuned.** `make engagement` + `stats.engagement`; `effective_range` falloff is in and inert (`--tune`-able), variants ready in `tools/matchup_variants/x1_range_falloff.json` |
| X2 cover | **Mechanics half done and measured** (balance.md *Round 5 X2*): a wall stops direct fire completely (0 damage against 113 in the open) and fire on the far side still suppresses (0.27 of a 0.60 pin). The battle half — does cover change where units die — needs the re-taken baseline |
| X3 the gangs | Not started, and the ground moved: see *Do not tune the gangs yet* below |
| X4 the Lancer | Recommendation written, evidence not taken: the Syndicate keeps the Lancer (the lead's pick for their special) and the Condemned's special becomes the Burner they already field, which gives every faction exactly five roles. Needs a counterbalanced matrix run first |
| X5 rules for brains | Done: `Lethality.seconds_to_kill` / `is_slow_kill`, and pinning worth exploiting (sight −40%, hull turn −50% at full suppression) |
| X6 re-measure | Not started (same reason as X3) |

### Do not tune the gangs yet (three findings from today, in order of size)

1. **Guns fired a tick late, which hit fast weapons hardest** (balance.md, Round 5): a fixed tick lost per shot is 14%
   of a machine gun's rate and under 0.5% of a tank cannon's. Every rapid-fire weapon has been running at ~85-90% of
   its data sheet. The swarm is the archetype built out of fast cheap guns, so the gangs' 23% and `Armor beat Swarm
   16-0` were measured under a handicap that hit one side of each comparison hardest.
2. **Both armies charged from second one in every match a player plays** (ai, merged): the player's faction army was
   built by the CPU generator and never held. Engagement ranges, the 39-43 m median hit range, `static_share` and
   centroid travel were all measured in collisions, not battles with an approach.
3. **Army draw, not team identity, explains the "Green wins 25%" lean** (`make team-fairness`): counterbalance armies
   in every series from now on.

So the first series of round 6 is a **re-taken baseline**, not a tuning run: `make engagement` and
`make faction-matrix` with army counterbalancing, on a build that has all three fixes. Then gangs-versus-law first, to
see how much of the gap closes for free.

### Watch out: on an overloaded machine the match runs in slow motion

`max_physics_steps_per_frame = 3` (round 5) chooses slow motion over a death spiral: game time advances at most 3
ticks per rendered frame, so a machine rendering at 1 fps runs the match at a tenth of real time (audio measured
exactly that on builder0 with a window at 30 a side: 48.8 s of music against a 5.0 s match clock). **Any metric
measured per second of wall time on such a run is wrong by up to 10×**; per-tick and frame-time metrics are fine. Use
`sim_seconds` from `MATCH_RESULT` or count ticks. The arithmetic and the round-6 question (3 vs 1 vs 8) are in
[../sim_tick_rate.md](../../../sim_tick_rate.md).

### Questions for the lead (nothing is blocked)

1. **30 Hz did not reach your target.** A locked 30 fps at 1080p holds ~30 vehicles, not 60 (98 ms a frame at 60).
   ~85% of what is left is the brains. Do you want the next round to spend itself on brain cost (thinking less often
   is the obvious lever and it changes how units behave), or to cap the battle size and keep the current behaviour?
2. **The Lancer** (X4): the recommendation above is mine to take with evidence, unless you would rather rule on it.

### Requests to other streams

- **ai (round 6):** `Lethality.seconds_to_kill(shooter, target, face, health, shield)` is the matchup-free gate you
  asked for. Brain cost per second is now the frame-rate blocker, and it did **not** halve with the tick: thinking is
  on a real-time cadence by design. `make sim-profile` splits a tick by band; `perf-scene` is a live battle and
  diverges, so it cannot A/B a brain change.
- **render:** `build/perf-30hz-{720,1080}.json` are mine at 30 Hz on the lead's laptop; p99 and worst frame are in
  them, and interpolation is on, so a pass looking for effects drifting from their vehicles is worth it.

### What to playtest (exact commands)

```bash
make skirmish                                   # 30 Hz, interpolation on: motion should be as smooth as before
make skirmish-factions FACTION=gangs ENEMY_FACTION=law
make perf-scene PERF_RES=1920x1080              # a window for ~2 min; frame, p95, ticks per frame by vehicle count
make remote T="sim-profile TIME=60"             # where a tick goes, by band
make remote T="engagement PAIRS=condemned:condemned SEEDS=3"   # the shape of a fight
make team-fairness N=16                         # army / team / base controls
make duel GREEN_UNITS=scout RUST_UNITS=tank     # a machine gun at its real rate of fire
```

### Merge notes (shared files and other streams' paths)

- `project.godot`: `[physics]` — Jolt, 30 Hz, interpolation on, jitter fix off, `max_physics_steps_per_frame` 3.
- `Makefile`: `SIM_HZ` (exported); every `--fixed-fps` in `mk/*.mk` and the Python tools reads it.
- Other streams' files, all part of the tick refactor the orchestrator assigned to combat: `game/ai/*` (tick
  constants; plus `OrderController.FIRE_LEG_MIN_TICKS`, a behaviour fix), `game/tactics/*`, `game/announcer/*`,
  `game/network/network_input.gd`, `game/camera/cinematic_camera.gd`, `game/ui/squad_chip.gd`,
  `game/control/element_awareness.gd`, `tools/announcer/events.py`, and ~40 test files.
- Four tests changed because they measured in frame counts rather than seconds, one because a second alert at 30 Hz
  was a different *kind* (under fire, not contact), one because a clock that sums frame deltas can land a hair short.
- **The sim baseline moved four times on purpose**, each in its own commit with its reason: Jolt
  `83f1272ade466282`, pinned-crew effects `fc4e4247b7158e01`, the two latent defects `0c64debc427725c6`, the tick rate
  `16dc0de84f1c29b6`. Each recorded twice on builder0.

### Plan (worker contract step 2)

1. **X1a, measure first.** `EngagementStats` (`game/match/engagement_stats.gd`) fills `stats.engagement` in every
   `MATCH_RESULT`: contact distance, engaged distance (median nearest-enemy distance while shots fly), kill distance,
   `static_share` (seconds of fire where both armies stand still), centroid travel after contact, kills by face
   (front / side / rear / indirect), and cover use (time, shots, kills, deaths within 5 m of an obstacle).
   `make engagement PAIRS=… SEEDS=…` averages it over counterbalanced faction battles. Read-only: no sim change.
2. **X1b, tune the levers** against those numbers (weapon range, accuracy falloff with range, sight vs range, time to
   kill), with the target written in balance.md: a majority of direct-fire kills from the flank or rear, and armies
   that move after contact.
3. **X2 cover**, once arena's M2 layouts land (CP2); before then, on today's `scrapyard`.
4. **X3 the gangs**: re-run the faction matrix on today's code first, then fix what it shows.
5. **X4 the Lancer**: decide with the matrix and write it down.
6. **X5 rules for brains**: a matchup-free "can I kill this quickly" query; pinned worth exploiting.
7. **X6 re-measure** after arena's maps, and the balance.md story.

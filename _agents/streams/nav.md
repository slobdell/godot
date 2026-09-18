# Stream: nav (movement you can trust: paths, avoidance, right-of-way, one control law)

> Read [../orchestration.md](../orchestration.md) (the worker contract), [../game_design.md](../game_design.md)
> (*Round 6 direction*), [../workstreams.md](../workstreams.md) (you own **N1**, **N6**; you consume arena's **N3**),
> [../squad_ai_design.md](../squad_ai_design.md) (the movement layers), [../determinism.md](../determinism.md)
> (navigation is on its risk list), and round 5's reports in [archive/round5/](archive/round5/).
>
> **You own** `game/ai/{pathing,steering,combat_motion,order_controller,order_feed}.gd`, the new
> `game/ai/{movement,avoidance,pid,control_gains}.gd`, `game/tank/tank_motion.gd`, `mk/nav.mk` (new), and
> `_agents/navigation.md` (new: write the architecture down as you build it).
>
> **You are the bottom of the stack.** squad decides *where a unit should be*; you get it there. Everything the lead
> called unplayable this round lands on you first.

## The lead's direction (2026-09-18, verbatim)

> *"The main thing that makes the game unplayable right now is that the vehicles aren't smart enough yet to really
> navigate around like they should. If we have a hoarde of units, and I tell different squads to move in different
> directions a bunch of cars just get stuck or blocked by other cars. I would assume this should be solved by both
> making the computer units smarter but also like a real-world situation with units that presumably knew about each
> other or saw each other, I'd imagine an in-game command could be sent peer to peer between units to move out of the
> way or whatever the case is."*

> *"we're dealing with a discrete control system, where there should probably be things like PID loops all throughout
> the system somehow (we might even be able to differentiate units of different factions by PID values somehow) and so
> my point is that intuitively a PID loop would conceptually be useful for a unit trying to get back in his formation.
> I know video games using pathing algorithms like A* and stuff like that. Are we using that? We might even want a map
> that's a quasi maze just for test purposes to ensure units can get through it."*

> *"A good standard is Starcraft 2, where the units definitely seem smart (but we want our stuff to be even smarter)."*

**The answer to his question, which he is owed in the Status:** yes, there is pathfinding — Godot's
`NavigationServer3D` over a navmesh baked from the arena's collision at startup (`Pathing.find_path`,
`game/ai/pathing.gd:12`), which is A* over navigation polygons. What there is *not* is any real handling of other
units, and that is what he is seeing.

## Where things stand (surveyed 2026-09-18, on `main` at `5c68a03e`)

The honest summary: **the path planner is fine and everything around it is thin.**

- **Path planning.** `Pathing.find_path()` (`game/ai/pathing.gd:12-15`) wraps
  `NavigationServer3D.map_get_path(..., optimize=true)`. `Pathing.enabled` is an experiment kill switch
  (`--no-navigation`). The navmesh is baked once at startup in `Arena._bake()` (`game/arena/arena.gd:84-97`),
  southern half plus a 180° mirror because an asymmetric bake gave the south base a 64% win rate (trip-up 21).
  `cell_size 0.5`, `agent_radius 2.0`, `agent_height 1.75`, mask 1.
- **Path following.** `OrderController._next_waypoint()` (`order_controller.gd:608-623`) repaths every
  `REPATH_SECONDS = 1.0` or when the goal moves > 1 m, and advances within `WAYPOINT_RADIUS = 2.5` m. Waypoints are
  **raw navmesh corners** — no smoothing, no respect for a minimum turning radius (an unbuilt item since round 2).
- **Steering.** `Steering.drive_toward()` (`steering.gd:18-32`) is a **pure P controller**:
  `turn = clamp(-error / 30°, -1, 1)`, `throttle = cos(error) × clamp(remaining / 8, 0.35, 1)`, and it *stops and
  pivots* past 70° of heading error. No I, no D, one gain for every vehicle in the game. Wheels
  (`_wheels()`, `steering.gd:87-111`) use pure pursuit with a three-point turn. `CombatMotion` adds 16-direction
  context steering while fighting.
- **The plant.** `game/tank/tank_motion.gd` integrates tracks/wheels/hover with acceleration, braking and
  `lateral_grip`; `Tank._drive()` (`tank.gd:387-430`) runs it and calls `move_and_slide()`. Hulls are on layer 2 /
  mask 3, so **vehicles physically block each other**.
- **Inter-unit avoidance: essentially absent.** There is no RVO, no ORCA, no separation force, no velocity obstacle,
  no space reservation, no messaging. The one mechanism is `OrderController._around_friends()`
  (`order_controller.gd:537-578`): it finds the **single nearest** *ally* within 10 m ahead and 3.2 m of the path
  line, and overrides the waypoint with a point 5 m to one side. It never checks that sidestep against the navmesh or
  an obstacle, it is a no-op unless the controller is a `TankBrain`, and **enemies are never avoided at all**.
- **Unsticking is blind.** `_apply_unstick()` (`order_controller.gd:639-651`): >50% throttle but under
  `STUCK_SPEED = 0.8` m/s for 1 s → 0.9 s of full reverse with `turn = 1.0` — always reverse, always right, with no
  idea what it is stuck against.
- **And then it lies.** `TankBrain.ORDER_STALL_ARRIVE = 12.0` (`tank_brain.gd:128`): after 3 s of no progress a unit
  within **12 metres** of its goal declares the order complete. That is why a jammed horde looks like it "decided" to
  stop — units are reporting success from twelve metres away.
- **No dynamic obstacles.** No `NavigationObstacle3D` anywhere; the bake never updates. Wrecks were deliberately moved
  to layer 4 so they never block driving, precisely to dodge this.
- `game/control/squad_orders_playtest.gd:13` already names *"moved, but piled up"* as an expected failure mode. It was
  known; nobody owned it.

**The existing regression harness you inherit:** `tests/test_navigation.gd`, `test_tank_drive.gd`,
`test_tank_motion.gd`, and the player-order measurement in the check (`MEASURE player_orders worst gap …`).

## CP2 has already landed, and it came with your baseline (arena, 2026-09-18)

arena delivered the maze on day one and **measured the problem before you got here**. Relayed verbatim, because the
numbers are the point:

> `arenas/maze.json` — four container bands (z = 74, 52, 30, 10) plus their mirrors, so a gap at +x mirrors to -x and
> crossing is a serpentine: 424 m of navmesh route against a 204 m crow flight. Tight gate is 7 m physical =
> **3 m of drivable corridor** after the 2 m nav agent radius, narrower than two hulls, and it sits on the shorter of
> the two routes so a horde picks it. One dead end. Not in `Arena.ROTATION`; `--arena=maze` only.
>
> `make nav-maze` (`NAV_UNITS=30 ARENA=maze NAV_TIME=180 SEED=1 NAV_BOTH=1`) → `build/nav-maze.json`: arrivals,
> t50/t90/t100, unit-seconds under 0.5 m/s, stuck events, units left off the navmesh, and the five that got least far.
> It measures only positions over time, so nav can rewrite path planning/avoidance/the control law and the numbers
> keep meaning the same thing.
>
> `NAV_BOTH=1` splits the force between both bases so the two streams meet head-on in the shared corridor — the
> peer-to-peer right-of-way case the lead described. One-way traffic never exercises it.

**The baseline. Laptop, `38c15f77`, one-way, 180 s, seed 1, hold-fire (driving only):**

| run | arrived | t50 | t90 | units that ever stalled 3 s | route actually travelled |
|---|---|---|---|---|---|
| maze, 30 units | 15/30 | 60 s | never | 30 of 30 | 47% |
| maze, 60 units | 36/60 | 56 s | never | 60 of 60 | 49% |
| **yard, 60 units (control)** | 33/60 | 31 s | never | 27 of 60 | 91% |

arena's own reading, and the orchestrator agrees it is the important line: **this is not a maze-specific cruelty.**
On a *shipping* arena, with no enemy and nothing to do but drive, **45% of a 60-vehicle force never reaches its
destination in three minutes and 27 of them stall outright.** That is the lead's *"a bunch of cars just get stuck or
blocked by other cars"*, reproduced headlessly without a shot fired. The maze sharpens it; `yard` already shows it.

**arena's caveats, which travel with the number:** single seed, laptop (~2.75× slower than builder0, though nothing
here is frame-rate sensitive — it is `--fixed-fps 30`), one-way traffic, all tanks, hold-fire. **It is a floor to
improve on, not a balance claim.**

**The head-on pair (`NAV_BOTH=1`), same conditions — this is the one your X4 has to answer:**

| run | arrived | t50 | units that ever stalled 3 s | route travelled |
|---|---|---|---|---|
| maze, 60, head-on | 23/60 (38%) | **never** | 60 of 60 | 39% |
| yard, 60, head-on (control) | 35/60 (58%) | 37 s | 30 of 60 | 93% |

Against the one-way runs: head-on traffic **barely moves `yard`** (55% → 58%, inside noise on one seed) and
**collapses the maze** (60% → 38%, and t50 stops being reached at all). arena's reading, which the orchestrator
endorses: narrow corridors are where two streams meeting actually costs something. That is the case for the maze's two
gates sharing one corridor rather than running as separate pipes, and it is precisely the situation your peer-to-peer
right-of-way (X4) exists to resolve. A yard-only measurement would have told you avoidance barely matters; it does,
but only where there is no room to be sloppy.

**arena's caveat on the last column, which you must not misread:** *do not* read "39% vs 93% of route travelled" as
maze-vs-yard difficulty. The maze route is ~409 m per unit against yard's ~223 m, so that column is about jamming, not
speed. **The columns that compare cleanly are arrivals, whether t90 is ever reached, and how many units stall at all.**

All five runs are saved with provenance in `_agents/streams/references/arena/` — the README carries one row per file
with its conditions, and both of arena's wrong-number stories (lesson 34).

This changes your X2: **arena has already built most of your instrument.** Do not build a second one. Read
`make nav-maze`, add what it lacks (your own `make nav-jam` gap case if it is genuinely different), and spend the time
you saved on X3 and X4 instead.

## Backlog (in order)

**X1 — the N1 Movement seam, and a truthful stuck report (CP1; land this first, before any cleverness).**
Create `game/ai/movement.gd` as the single entry point between "be here" and "drive there":
`Movement.request(unit, to, opts)`, `Movement.state(unit)`, `Movement.eta(unit, to)`, `Movement.cancel(unit)`, with
`state().phase` in `pathing | driving | yielding | blocked | arrived` and `blocked_by` naming the cause. **Split `order_controller.gd` while you are in there**, because today it is one file doing two crafts and two streams
need it: path-following, avoidance and unsticking move into `movement.gd` (**yours**); the firing decision moves into a
new `game/ai/gunnery.gd` that becomes **combat's file** — they own the rule about when a gun may speak (N5), you own
where the vehicle is. `order_controller.gd` stays yours as the thin composer that calls both.

**Read this before you open the file: combat has already edited it, and has specified the seam for you.** nav had no
session when CP4 became the round's early checkpoint and two other streams were holding for it, so the orchestrator
accepted four surgical edits into `order_controller.gd` rather than park the round behind a stream that did not exist
(recorded as an exception below). Every *rule* lives in `game/combat/engagement.gd` (combat's); the controller only
carries state and calls it. The four edits: an `engagement_lay` member beside `spotter`; an `Engagement.is_seen(...)`
early-out at the top of `_shootable()` *before* the line-of-sight raycast (a dict lookup, so a rejected contact now
saves a ray); an `envelope` term in `_apply_weapon()`'s trigger line; and a `_seconds_step()` helper with
`engagement_lay.lose(...)`/`.forget()` on the no-target and death branches. **None of them reads a path, a waypoint or
a throttle**, so they move across the seam untouched.

**The seam combat asked for, so you build it rather than guess it.** `gunnery.gd` takes `_apply_weapon`,
`_apply_suppress`, `_apply_indirect`, `_shootable`, `_scanned_shootable`, `_nearest_shootable`, `_named_tank`,
`_cover`, `_clear_to_fire`, `_enemies`, and the state `engaged_target`, `watch_point`, `spotter`, `engagement_lay`,
`_scan_pick`, `_scan_left`, `_lane_hold_left`, `lane_blocked_ticks`, `ticks_since_fire`. The composer calls
`gunnery.apply(cmd, seconds)` **after** the movement half. Gunnery needs exactly four things from your side: `tank`,
`tanks_root`, `weapon_order`, and `move_order["type"]` (only so a fixed-mount hull can swing onto its target when
halted). **Pass it seconds, not a tick count** — lesson 30: the acquisition timer is booked in seconds and must stay
that way at any tick rate. Two rules that are
the point of the item:
- **A unit never silently stands still.** If it cannot make progress it reports `blocked` with a reason, and something
  above it can act.
- **Delete the 12 m lie.** `ORDER_STALL_ARRIVE` stops being a way to complete an order. An order completes when the
  unit arrives, or fails loudly. Expect this to *look* worse before it looks better; that is the honest baseline.
Write the API into `_agents/navigation.md` and **message the orchestrator the moment the interface is on the branch**,
because squad is coding against it.

**X2 — measure the jam.** Before fixing anything, build the instrument. `make nav-jam`: N units (10, 30, 60) ordered
across an arena and through a gap, reporting arrivals, median and p95 time-to-arrive, total unit-seconds spent under
0.5 m/s, number of stuck events, and the worst single unit. Run it on `yard` and on `foundry` and record the numbers
with commit and machine. Every later item is judged against this, and the lead's complaint is exactly p95 and
"stuck events", not the mean.

**X3 — local avoidance that actually resolves.** Replace `_around_friends` with a real reciprocal scheme. The
recommendation, in order of what to try: **reciprocal velocity obstacles (RVO/ORCA) over the k nearest neighbours**,
including **enemies** and, at reduced weight, static geometry. It must be:
- *reciprocal* — both units yield half, which is what stops the two-units-mirroring-each-other deadlock;
- *deterministic* — fixed neighbour count, neighbours ordered by unit name, no wall clock, `dt` = the fixed tick
  (invariant 7; the sim baseline will move, which is yours to move on purpose);
- *cheap* — the AI band is the frame budget (round 5: 9.3 ms of an 11.6 ms tick was brains). Budget it, measure it
  with `make ai-perf`, and use the tick cache's neighbour columns rather than a fresh scan.
Do **not** turn hulls into ghosts that pass through each other: vehicles are vehicles. Soft nudging at low relative
speed is acceptable; teleporting through a friend is not.

**X4 — right-of-way: the lead's peer-to-peer "move out of the way".** Avoidance alone still deadlocks at a gap where
there is only room for one. Add an explicit negotiation, and make it legible:
- a unit that cannot proceed asks the unit blocking it to yield, addressing it by name;
- the tie is broken by a **deterministic priority** — recommendation: the unit with the shorter remaining path yields
  to the one with the longer one (it has less to lose), and ties break on unit name so it is reproducible;
- a yielding unit steps to a *validated* free point (navmesh-checked, unlike today's sidestep), holds for a bounded
  time, then resumes; it must never yield into another unit's way and never yield twice in a row to the same asker;
- the whole exchange is visible in `Movement.state()` (`phase: "yielding"`, `blocked_by`) so the HUD, the AI overlay
  and your tests can see who asked whom.
This is the item the lead described in his own words; it should read, on screen, as units noticing each other.

**X5 — the maze.** arena delivers `arenas/maze.json` on day one (N3). `make nav-maze` sends 30 and 60 units from the
start zone to the far objective and reports: how many arrived, the time to 50%/90%/100%, unit-seconds stalled, stuck
events, and whether any unit ever ended up outside the navmesh. **The gate: 100% arrive, no unit permanently stuck, at
both sizes, on five seeds.** Wire it into `make check` only once it is fast and stable; until then it is a target you
run deliberately.

**X6 — the PID layer (N6).** `game/ai/pid.gd`: a small deterministic regulator — gains, integral clamp (anti-windup),
derivative **on measurement** not on error (no kick when the setpoint jumps to a new slot), `reset()`, `dt` = the fixed
tick. Then apply it where there is a continuous error worth regulating:
- **slot station-keeping** (the lead's own example: a unit getting back into its formation) — this is the one that
  matters, and it is where a P-only follower visibly oscillates today;
- **speed matching** to a leader or a paced group;
- **turret lay**, if it improves on what combat has.
Keep it *out* of discrete choices (which path, which drill, whether to fire). Gains live in `control_gains.gd` as
**data**, defaults first and stable, then per-faction as a stretch (X8).

**X7 — path quality.** Smooth the raw navmesh corners (string-pulling / funnel, or a spline the hull can actually
follow), respect `min_turn_radius_m` for wheels, and stop repathing from scratch every second when nothing changed.
Round 2 listed "paths that respect the minimum turning radius" as unbuilt; it is still unbuilt, and it is why wheeled
units saw off corners.

**X8 (stretch) — factions differ by their gains.** The lead's idea, and it is a good one: the Syndicate crisp and
twitchy (higher P, real D, tight integral), the road gangs loose and overshooting (lower P, sloppy D), the Law
damped and deliberate. Only after the defaults are stable, only as data, and **measure that it changes outcomes** —
if identical armies with different gains win equally often and look the same on screen, say so rather than shipping
flavour text.

**X9 (stretch) — dynamic obstacles.** `NavigationObstacle3D` for wrecks and destructible cover, so the navmesh stops
being a startup-only snapshot. Coordinate with arena before changing what blocks driving: wrecks are on layer 4 *on
purpose*.

## How to verify

- `make remote T=check` green on your last commit — name the hash when you report.
- `make nav-jam` and `make nav-maze` (yours to build), with numbers at a commit and a machine, on five seeds.
- **Watch it.** `make skirmish`, order three squads in three directions from a standing start, and look at the
  screenshots — this is the exact thing the lead did. Also `make control-playtest`, `make command-playtest-shots`.
- `make ai-perf` / `make perf-scene`: the tick budget is 30 Hz and the frame budget is a locked 30 fps at 1080p.
  Avoidance is per-unit-per-tick work; if it costs more than ~1 ms at 60 units, say so with the number.
- `make determinism` and the sim baseline: yours to move, on purpose, with the reason in the commit.
- Re-run the swap-bases fairness control after anything that touches navigation (invariant 4).

## Don't touch

`game/tactics/**` and the deciding half of `game/ai/` (squad's), `game/control/` and `game/camera/` (control's),
`game/units/` `game/combat/` `game/match/` (combat's), `arenas/` and `game/arena/` (arena's), `game/theme/**` (feel's).
Need something from them? Stub it in your paths and write the request in your Status.

## Waiting on the lead

Nothing blocking. His question *"are we using A\*?"* is answered above — put that answer in your Status so it reaches
him.

## Status

_nav worker, started 2026-09-18 (the last stream to start; branch fast-forwarded to `main` a0206d45 first)._

**For the lead — "are we using A\*?"** Yes. Units plan routes with Godot's `NavigationServer3D`, which runs A* over the
navigation mesh baked from the arena's walls and containers when the match starts (`Pathing.find_path`). What was
missing was everything about *other units*: no avoidance beyond sidestepping the single nearest friend, no negotiation,
and a stuck unit that reported success from 12 m away. That is what this stream builds.

### Where it stands (updated as I go)

| Item | State |
|---|---|
| **X1 / CP1** Movement seam | **Merged to main** (`30e3250d` → `f03a795c`). **Gunnery split done** after CP4 (`game/ai/gunnery.gd`, combat's file, combat's seam); cutting its envelope call turns exactly combat's three wiring tests red (22 rule tests stay green). `ORDER_STALL_ARRIVE` deletion waits for squad's precedence fixes, as its own measured commit (orchestrator's ruling). |
| **X2** measure the jam | `make nav-suite` (arena's probe × configs, parallel on builder0) + `make nav-where` (who didn't arrive, where, and what their Movement says). Baseline saved: `references/nav/nav_suite_30e3250d_baseline.json`. |
| **X3** ORCA | Done: `game/ai/avoidance.gd`. |
| **X4** right-of-way | Done: ask / give way in `movement.gd`, visible as `phase: yielding`. |
| **X5** maze gate | **Met on one seed at 180 s except head-on maze** (see numbers); five seeds are identical by construction (below). Not wired into `make check`: a suite run is ~10 min. |
| **X6** PID | Done for station-keeping (`pid.gd`, `control_gains.gd`): 0.35 m mean gap vs 4.58 m for the P law. Speed matching is the same loop; turret lay not attempted (combat's turret already has a rate limit, which is the dominant dynamics). |
| **X7** path quality | Done: carrot along the route, cars look until they can drive onto the point, re-plan on change. |
| X8, X9 | Not started. |

### Numbers (builder0, `make nav-suite`, hold-fire, 180 s; arrived of N)

| config | round 5 (`30e3250d`) | X3+X4+X6 (`e291a35a`) |
|---|---|---|
| maze-30 | 15 | **30** |
| maze-60 | 35 | **60** (t90 129 s) |
| maze-60 head-on | **0** | **60** (t90 145 s) |
| yard-60 | 34 | **60** (t90 47 s) |
| yard-60 head-on | 33 | **60** (t90 37 s) |
| foundry-60 | 40 | **60** (t90 38 s) |

At `1923059c` (after the K1 and wheels fixes): the same 60/60 and 30/30 everywhere; t90 maze-60 120 s, head-on 144 s,
yard 55 s / 42 s, foundry 40 s. **Cost** (`make ai-perf`, 60 brains): the `move` part 1119 → 1688 usec per tick
(+0.57 ms), inside the brief's ~1 ms.

Caveats: one seed (the probe has no randomness, so five seeds are five copies; defaulting to 1 is the honest
setting), all `tank` units, hold-fire, no brains (the probe drives plain `OrderController`s).

### Findings worth relaying

- **60 units on 52 spawn points stacks 8 pairs exactly on top of each other, and in round 5 those pairs never moved.**
  Part of arena's baseline was coincident hulls, not congestion. Coincident hulls now part by name (deterministic).
- **Five seeds of the probe are one sample.** Check that the thing you vary actually varies before running a series.
- **Blind unsticking rams friends.** The round-5 routine reversed whatever was behind; in a column that makes two stuck
  units out of one. It now backs off only with room, and tracks pivot instead.
- **Cars and short lookaheads don't mix.** Any steering point inside a car's turning circle is a three-point turn; the
  carrot, the avoiding point and the give-way spot all have to be forward-reachable.

### Plan (in order)

1. **X1 / CP1** — `game/ai/movement.gd`, the N1 API; path-following moved out of `order_controller.gd`; honest
   `blocked` reporting. *Interface on the branch at `30e3250d`.* Gunnery split after CP4 is on main (orchestrator
   agreed); `ORDER_STALL_ARRIVE` deleted in its own measured commit after squad's precedence fixes (orchestrator's call).
2. **X2** — no second harness (arena built it): `make nav-suite` runs arena's maze probe over maze/yard/foundry × sizes ×
   traffic × 5 seeds in parallel on builder0 and writes `build/nav/summary.md` with commit and machine.
3. **X3** — ORCA over the 6 nearest hulls, friend and enemy, reciprocal (½ each; a parked unit takes none), on the
   navmesh or not at all. `game/ai/avoidance.gd`. Always on (N1); `--no-avoidance` is the measuring switch.
4. **X4** — right-of-way: stalled 1 s → ask the friend ahead to give way; still units always give way to movers, between
   movers the shorter remaining route gives way, name breaks ties; a validated spot off the asker's line; never twice
   in a row to the same asker. Visible as `phase: yielding`, `blocked_by: <asker>`.
5. **X5** maze gate, **X6** PID, **X7** path quality, then stretch X8/X9.

### Decisions

- `Movement.state(unit)` takes the Tank node (control's `MovementReadout` already calls it that way). `blocked_by` is a
  unit name, `"no_path"` or `"terrain"`; it also names the asker while `yielding`. Extra keys: `goal`, `stalled_s`,
  `yield_to`.
- A unit is `blocked` after 2 s without getting 0.5 m closer along its route (the probe's own stall clock is 3 s).
- ORCA rather than a sampling RVO: the half-plane LP is the cheapest thing that is actually reciprocal, and GDScript
  can't afford per-sample collision tests at 60 units.

### Requests to other streams

- **arena**: `tests/arena/maze_probe.gd` drives plain `OrderController`s, so round 5's brains-only `_around_friends`
  never ran in your baseline. Not a problem now (N1 avoidance is on for every controller) — just a note for reading
  the old numbers.

### Merge notes

- New files: `game/ai/{movement,avoidance}.gd`, `tests/test_{movement,avoidance}.gd`, `mk/nav.mk`,
  `tools/nav_suite.py`, `_agents/navigation.md`.

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
  **Correction (arena, verified by nav 2026-09-18): the layer-4 claim is false.** Only `tank.tscn` sets a collision
  layer; the `wreck` kit prop is a plain layer-1 `StaticBody3D`, baked into the navmesh and blocking like a container,
  and a destroyed vehicle leaves no body at all (`game/theme/fx/fire_sites.gd`: visual only).
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

### Nav's next work: a long hull's clearance (raised by combat, 2026-09-19)

Two gaps, both mine, found while explaining the War Rig's shuffle:
1. **Clearance ignores length.** `_chord_slack()` = max(0.3, 2.0 − width/2 − 0.2) uses the hull's WIDTH, and the navmesh
   is baked with `agent_radius` 2.0 for every unit whatever its size. A 14 m hull's rear sweeps well outside the line
   its centre follows, so a gap the routing calls passable is one the rig's tail catches. The sweeping dimension is
   half-LENGTH at a corner, not half-width.
2. **A `face` order has no recovery.** `Movement`'s unstick only runs for a MOVE. Under a face order a wheeled hull
   creeps until the order changes, however little ground it is covering.

Combat's evidence that this costs more than looks: the 14 m rig took `gangs vs law` from 9/20 to 0/20 (p ≈ 2e-6), with
the highest suppression figures in their table. A hull that covers 0.5 m in 4 s is a stationary target whatever its
speedometer says. They are testing `static_share` against hull length, pre-registered at `b16b8d78`.

### BLOCKED (2026-09-19, evening): builder0 is unreachable

The facing-arc measurement below is queued and cannot run: builder0 answers `No route to host` (100% packet loss to
10.115.229.237 over the ZeroTier interface `ztktis7se4`, which is up on this machine at 10.115.229.242). It stayed down
for an hour of polling. `zerotier-cli` needs a password here, so diagnosing the tunnel is the lead's, not mine.

Both arms are pinned to commits and the run is reproducible as soon as it is back:
`make remote T="nav-fight-maps FIGHT_BUSY_LEVELS=0"` on `2038a40a` (no facing populated) and on `777574e5`
(`stream/nav` + squad's `ea55c624`), reading `travelled`, `gates` and the `move`/`attack_move` buckets.

Also seen in the failed rsync, worth someone's attention: **builder0's root filesystem is at 91%** (102G of 119G, 11G
free).

### PRE-REGISTERED before the run: what squad's `facing` does once the arc actually fires

squad populated `facing` (`ea55c624`) on MOVE and KEEP_SLOT orders, so the arrive-on-heading gate now fires in real
fights instead of only in my tests. The two halves were checked separately and never together, and the combination
changes wheeled ROUTING (a car aims at a gate 2.5 turning radii short of its goal), so it is measured before the lead
sees it.

- **Arms, both on builder0, same seed, same maps:** `stream/nav` tip (the arc present, `facing` never set, so the gate
  never fires) against `measure/facing-arc` (`stream/nav` + `ea55c624`). The only difference is squad's commit.
- **Runs:** `nav-fight-maps`, the 4 maps, busy 0, seed 3, 120 s.
- **Primary:** per-wheeled-type `net_over_path` and `oscillating_share` from `travelled`. The arc is supposed to raise
  the first and lower the second: a car that arrives on heading does not creep round afterwards.
- **Secondary:** the `move` verb's `progressing` share, and `blocked_*` — a gate placed badly would show as a detour or
  a refusal, not as a crash.
- **Guard:** `attack_move` `progressing` must not fall by more than 10% on 2 or more maps. Routing to a gate costs
  distance; if it costs fighting, it is not worth it.
- **Reading it:** better or flat on the primaries and inside the guard → say so and leave it on. Primaries flat and the
  guard tripped → tell squad to stop populating `facing` on KEEP_SLOT (the packed-slot case, where the gate is refused
  most anyway) and keep it on player moves. Primaries WORSE → the gate is wrong in traffic and I take it back to tests.

### Next experiment, PRE-REGISTERED before it runs: how sticky should a combat plan be?

The churn the lead complains about is a direction that keeps changing. Commitment exists for that
(`CombatMotion.COMMIT_BONUS` = 0.35) and round 8 showed it is weaker than it looks: a HOLD returns index −1 and never
consults it, and turning it off changed scout wobble by −14% to +19%. The remaining nav-side lever is its size.

- **Change:** `COMMIT_BONUS` 0.35 → 0.7, nothing else. Off arm is `--nav-off=commit` as today; the on arm is the new
  value. Arms verified from `NAV_FIGHT_ARM`.
- **Run:** builder0, terminus, 45 a side, `STALL_VERB=attack_move`, busy 0, 120 s, seeds 3, 5 and 7, paired by seed.
- **Primary metric:** `oscillating_share` among attack-moving units (0.060, 0.037, 0.040 on those seeds today).
- **Win:** ≥ 20% lower on at least 2 of the 3 seeds, and not higher on any.
- **Guard, with power this time:** shots fired, both sides (about 2600 and 2900 a run). The guard FAILS if shots fall
  more than 15% on any seed — a unit that commits to a direction it should have left is a unit not shooting. Units lost
  are reported but not used: 2–5 a run has no power, which is the mistake the hold A/B's guard made.
- **If it misses:** the value goes back to 0.35 and the finding is recorded, because the churn is then not in the
  argmax's stickiness and the next suspect is the re-plan rate itself (`TankBrain.MOTION_REPLAN_TICKS` and the incoming
  count in its key — squad's file, so a request rather than a change).

### Round 9's catalogue rows, and the order I recommended (nav, 2026-09-19)

Four ADOPT rows are nav's: A1 (event-triggered replanning), A4 (clothoid primitives with priced cusps), A7 (null-space
priority projection), A11 (dynamic-window arcs replacing the context-steering ring). A1, A7 and A11 touch the same code
path, so Invariant 0c sequences them. My recommendation to the orchestrator, from what round 8 measured:

**A7 → A11 → A1 → A4.**
- **A7 first, alone.** Round 8's clearest finding is a cancellation failure: a standoff HOLD returns index −1 and never
  consults the commitment bonus, so we shipped a term that was never in the code path and measured it twice for nothing.
  That IS "opposing goals cancel to zero", and priority projection makes it structurally impossible. Its falsifier is
  already measurable here (`travelled`, arena's stall counters).
- **A11 second:** it replaces the ring A7 has just re-plumbed. The other order means fitting priority projection to a
  scoring structure we are about to delete. Round 8's gear flips (9–19 per unit-minute) are the independent evidence.
- **A1 third:** cadence is worth the most on paper (70% of churn) and is the likeliest to look like a win while hiding a
  regression — the hold-hysteresis A/B is the cautionary case, churn down 6–22% and still a fail. Its latency falsifier
  needs a stable decision layer underneath.
- **A4 last:** clothoids are a primitive and the arc chooser consumes them. The round-8 arrival arc is their natural
  first consumer (it drives a straight approach today; a clothoid is the honest version).
- **Caution against my own recommendation:** A7 replaces additive blending, which is CombatMotion's entire weight table
  — standoff, commitment, armour toward threats, all lead-approved behaviour. Its brief must name which become
  priorities and which become null-space tasks BEFORE any code, or round 7 gets re-litigated by accident.

**This layer's declaration for Invariant 0c.** nav owns the desired-velocity layer (`movement.gd`, `combat_motion.gd`,
`steering.gd`, `tank_motion.gd`). It assumes ABOVE: squad hands down goals and, since round 8, a `facing`. It assumes
BELOW: the plant honours (throttle, turn) with a bounded yaw rate. Replaces: A7 → the additive blend; A11 → the
16-direction ring; A1 → the fixed repath and re-aim cadence; A4 → the straight approach inside the arrival arc. None of
the four adds alongside.

**Reeds–Shepp stays parked, and Part 1 §5 gives a better reason than mine:** it is curvature-discontinuous, so the plant
expresses every join as the visible correction the lead complains about. My reason was only that its evidence was an
angle-wrap bug in my own reporter.

### Round 8 wrap-up (nav, 2026-09-19 evening) — hand-over facts

**GREEN HASH: `5367c395`.** Read from the wrapper: `>> remote: make check exited 0 (build/ copied back)` with
`1261 passed, 0 failed` and `sim-baseline passed: 0cb238bf366e141f (glibc-2.43)` in the same log.

> **What that baseline line does NOT mean (combat, 2026-09-19).** The OLD `sim-baseline` match is blind to 5 of 6
> mutations combat tried: wheeled turn rate, fixed-mount fire arc, hover speed, the rig's hull box and turret traverse
> all left the hash unchanged; only the tracked case registered. Wheeled turn rate is close to exactly what the
> arrive-on-heading arc touches. So `sim-baseline passed` says the hash did not move, NOT that the arc leaves the sim
> alone — **the instrument could not have seen it.** The 1261 tests are the real evidence, and the arc's own five are
> direct. combat's widened match is `db837581` (unmerged; it moves the baseline by construction). **Do not carry "the
> facing pair is inert" forward as established** — the orchestrator drew that against the blind match and is amending
> it (`6a8aaa8c`). The rule is the one we already had for guards: **a green from an instrument that cannot detect the
> treatment is indistinguishable from a green that means the treatment is harmless.** Prove it can go red. The rsync for that run
started between `5367c395` (17:27:29) and `c1dd3d75` (17:28:47), so the checked tree is exactly `5367c395`.

**Verified at the green hash:** everything up to and including `5367c395` — the yaw ramp, the hold-hysteresis switch,
the flow-field revert, the `--nav-off` unknown-name refusal, the rotation-capture unwrap, control's split facing test,
the workstreams contract entry, and the arrive-on-heading arc with its five tests.

**Landed AFTER the green hash (10 commits, `c1dd3d75`..`b4f04126`), not covered by it:**
- Docs only: `c1dd3d75`, `7eae19b4`, `e66d56f7`, `f6f42127`, `47836038`, `0edd5550`, `ecdade39`, `b4f04126`.
- Probe only: `bf72d8f0` (`--empty` in the rotation capture), `c4faf1e2` (`travelled` in nav-fight).
- **Touches `game/ai/movement.gd`: `2038a40a`** — two static counters (`gates_aimed`, `gates_refused`) and no
  behaviour change. Parse-checked and `make test FILTER=wheeled_arrival` 5/5 locally, but **not** remote-checked.
- `make remote T=lint` was green ("lint: all scripts parse", exit 0) at `47836038`, so `ecdade39`, `2038a40a` and
  `b4f04126` postdate even the lint.

**The facing-arc A/B DID run (builder0 returned at 21:0x) and it is a POSITIVE-CONTROL FAILURE, not a null.**
Arms `a35cf487` (no facing populated) and `777574e5` (+ squad's `ea55c624`), 4 maps, seed 3, both `exited 0`. Every
figure is identical between arms to three decimals — and the counter added for exactly this says why: **`gates aimed 0`
and `gates refused 0` in BOTH arms.** The arc never ran, so nothing was compared.
Cause, read from the code rather than guessed: squad's `_arrive_facing` only attaches a facing when
`intended_facing()` is non-null, which needs the K1 order to carry one or `Orders.station` to hold a heading. `nav-fight`
issues `UnitCommand.make(names, "move", {"to": …})` with no facing, and a CPU fight never sets one. **So the pair is
genuinely inert in a CPU fight — for a narrow reason, not a general one — and remains UNTESTED where it does fire: a
player's drag-order with a facing, and a squad told to hold one (the lead's ambush case).**
Round 9's version of this measurement needs the probe to issue orders WITH a facing; otherwise it re-measures nothing.

**Still blocked / queued behind the merge chain:**
1. The facing-arc measurement re-done with facings in the issued orders, against combat's widened baseline.
2. Re-checking the three post-green commits that are not docs.
3. ~~The commitment-strength A/B (`COMMIT_BONUS` 0.35 → 0.7)~~ **probably moot**: catalogue A2 replaces the flat bonus
   with a state-dependent cost, so the A/B would locate a constant we intend to delete. Do not spend a slot without
   asking the orchestrator first.
4. The terminus maze half of any future checkpoint, which needs arena's `f7bff357` and a 60-unit both-ways baseline.

### Round 8 report (nav, 2026-09-19) — the short version

What the round answered, in the order the orchestrator set it:
1. **The yaw ramp shipped** (`9f8c21e2`): tracked and hover hulls reach their turn rate over 0.25 s. The tank pivot went
   from 90% of peak in 1 tick to 7. It moves the sim baseline.
2. **The semi does NOT yaw in place**, isolated or in a fight: 0.11–0.74 events per semi-minute against 3.4–3.7 for the
   gang scout. What the lead saw doing it is the small gang cars around the trucks.
3. **The lead's back-and-forth IS real**, measured on main (`aa984edd`): attack-move oscillation 5.3–7.2% on all four of
   his maps, 25–28 units per map, not a few stuck ones. That is the headline of the round.
4. **Commitment could not have cured it**, because a standoff HOLD returns index −1 and never consults the commitment
   bonus. About 40% of the wheeled events happen while holding.
5. **Hold hysteresis:** built, measured, missed its bar (scouts ≥20% lower on 1 of 4 maps), now opt-in
   (`--nav-off=holdband` turns it ON).
6. **Gear flips are three things, not one** (a reverse ORDER, a `face` order's creep K-turn, plain `move_to`), so a
   single gear-change cost would tax all three to treat one. Built, measured as mis-aimed, reverted before shipping.
7. **Flow fields: a measured null**, reverted with their switch.
8. **Reeds–Shepp is parked**: the 20.7° "overshoot" that justified it was the measurement wrapping a 201° turn.

Instruments this round gained (they outlast the features): archetype pinning and `FIGHT_REQUIRE` refusal in nav-fight,
in-place-yaw counters with provenance, gear-flip counters, unwrapped rotation headings, and `--nav-off` refusing an
unknown mechanism name.

Owed next, in order: the wheeled arrive-on-heading arc (contract agreed with squad: a move order may carry `facing`),
then the terminus oscillation at 45 a side (0.060 — the first number the size of the lead's complaint).

### The War Rig's pivot is length-driven (builder0, `81f87186`, `nav-rotation-numbers ROT_CASES=truck`)

Only `hull_size` changed between these, restored after each run:

| hull_size | in-place turn (within 1.5 m of its start) | farthest wander |
|---|---|---|
| 3.0, 4.4, 5.6 (the size the lead complained about) | 7° | 5.5 m |
| 2.84, 4.49, 12.0 | 23° | 3.9 m |
| 3.32, 5.24, 14.0 (shipped) | 26° | 3.5 m |

The 5.6 m control re-run on today's tree still reads 7°, so the change is combat's size change and nothing else this
round. Going back to 12 m recovers 3° of a 19° move, so it does not undo the lead's complaint.

**The mechanism is terrain contact, not the motion model** (combat caught my first explanation, which was wrong:
`hull_size` never reaches `TankMotion`, so at a fixed radius the centre's path per degree cannot depend on length).
`--empty` re-runs the same case with every prop removed. Laptop, `81f87186`, one machine for all six cells:

| hull_size | on yard | on bare ground |
|---|---|---|
| 3.0, 4.4, 5.6 | 7°, wander 5.5 m | 7°, wander 6.7 m |
| 2.84, 4.49, 12.0 | 23°, 3.9 m | 7°, 6.7 m |
| 3.32, 5.24, 14.0 | 26°, 3.5 m | 7°, 6.7 m |

On bare ground every length is identical. So a long rig does not pivot, and it is not jammed either — a tick-by-tick
dump settles what it actually does:

    t=0.5 heading  -3.9  model_speed  3.50  moved 0.31
    t=1.0 heading  -7.9  model_speed -0.47  moved 0.40
    t=1.5 heading -11.0  model_speed  3.10  moved 0.40
    t=2.0 heading -14.3  model_speed -0.80  moved 0.46

The hull IS rolling — the model's speed and the real speed agree, so nothing is stuck — and it is the creep K-turn's
legs alternating forward and reverse. **On yard the legs cancel: 25° of heading for 0.5 m of net displacement. On bare
ground the same legs drift the hull 6.7 m away, so the detector never counts it.** The longer the hull, the sooner a leg
meets scenery, which is why the yard column rises with length while the bare column does not move at all.

So the honest statement: a long rig shuffles round on the spot when there is something to bump against, by a mechanism
that is legitimate physics for a car and looks exactly like the pivot the lead says is impossible. The laptop reproduced
builder0's yard numbers exactly.

What it means for the fix: neither length nor `min_turn_radius_m` is the lever. A big hull needs either to stop
commanding yaw while it is against something, or not to be asked to turn on the spot at all (squad's change, and the
arrive-on-heading arc).

### The 14 m War Rig, measured (builder0, `81f87186`, `make nav-rotation-numbers`)

- In place: **26°** of turn while within 1.5 m of its start, farthest wander 3.5 m (at the old size: 7° and 5.5 m). A
  longer hull on the same 12 m circle translates less per degree, so it reads MORE like a pivot. Still under the
  pre-registered 30° bar, but no longer far from it.
- Throughput: 62° of a 90° face in 12 s, peak yaw 17°/s. Slow, not snappy; its ROBOTIC(b) is the capture ending mid-turn.
- `min_turn_radius_m` 12 is right for a 14 m hull (bicycle geometry: ~8.4 m of wheelbase, 30° of lock → 14.6 m, 40° → 10).
  My earlier "12–15" was a guess and is withdrawn.
- `settle_radius` = min(0.6 × R, 6) = 6 m, which is 0.43 hull lengths. Right: it stops a rig circling a point it cannot
  stop on.

### Round 8 (nav, 2026-09-19) — read this first when resuming round 8

The lead's verdict on round 7 was "it still sucks". The orchestrator set the order: (1) angular acceleration at the plant, plus
the semi trucks "yawing in place"; then reproduce the lead's stall in a probe; then (3) flow fields as their own
checkpoint, judged on a pre-registered metric that is not attack-move progress. (2) Reeds–Shepp for wheeled hulls comes in
wherever it fits.

**Done**
- **Yaw ramp, `9f8c21e2`.** Tracks and hover reach their turn rate over `YAW_RAMP_SECONDS` = 0.25 s, or over
  `hull_turn_accel_deg_s2` when a unit's catalog entry has one (`TankMotion._ramped_yaw`).
  - `make nav-rotation-numbers` on builder0: the tank pivot now reaches 90% of its peak rate in 7 ticks (it was 1), so it
    is smooth.
  - ~~The scout's K-turn still overshoots by 20.7°~~ **Retracted: that was a bug in the instrument.** The car turns
    201° in one smooth arc and its heading never reverses; `_report` wrapped 201° to −159° and called the difference an
    overshoot. Fixed with an unwrapped heading sum. Laptop, `nav-rotation-numbers` after the fix: pivot, car and wheel
    are all smooth with 0.0° overshoot. The truck turns 62° of its 90° face in 12 s and is still turning when the case
    ends (the "last tick 37%" is the cut-off, not a snap). **With no overshoot there is no measured defect for
    Reeds–Shepp to fix, so (2) is parked.**
- **Semi in isolation (`truck` case).** Told to face 90°, `gang_tank` turned 7° while it was within 1.5 m of its start,
  and travelled 5.5 m. It does not yaw in place.
- **Stall repro, `nav-fight-maps`, attack_move, arena's counters.** Oscillation was 5.3–6.6% on yard, boulevard, pit
  and boneyard, with commitment on. That meets the pre-registered bar for "the back-and-forth is real" (≥ 5% on any
  map), and it is churn, not terrain: `blocked_terrain` is about 0, and under plain move units progress about 90% of the
  time. The lead has ruled (main `f5526594`): manoeuvring is smart, churn is not.
- **In-place yaw in fights, gangs vs gangs (tree `9f8c21e2`, builder0, 120 s, seed 3).** This run is INVALID for semis:
  the seed fielded `gang_hail` on both sides, so no `gang_tank` was on the field. On the units it did field, scouts
  produced 185–262 events per map, 3–5× every other type. Laptop smoke on `2649d448`: most scout events are `wobble`.
  - Fixes: `FIGHT_GREEN_ARMY`/`FIGHT_RUST_ARMY` pin the archetype (`2649d448`).
  - `--require=`/`FIGHT_REQUIRE` refuses a run without the unit under test, and nav-fight-maps fails when any run
    refuses (`485c2788`).
  - The diagnostic split `turned` / `wobble` / `crept` is not part of the pre-registered count.

**The headline, re-measured on main.** Tree `aa984edd` (main `f5526594` merged, no nav changes on top), builder0,
attack_move, Condemned vs Condemned, seed 3, 120 s. Arm read live: commit=true, standoff.

| map | oscillating | units that ever oscillated |
|---|---|---|
| yard | 7.2% | 28 |
| boneyard | 6.6% | 27 |
| pit | 5.8% | 25 |
| boulevard | 5.3% | 28 |

The pre-registered answer is **YES, the churn is real**, on all 4 maps, and it touches nearly every unit rather than a
few stuck ones.

**Local diagnosis (laptop, `3018e993`, 20 s, gang_ram vs gang_pack).** All 11 scout in-place events happened while
`driving`, none while creeping, and 7 of 11 had both forward and reverse gear above 0.5 m/s in the window. That looks
like context steering alternating between forward and reverse directions.

**Pre-registered, written BEFORE the run: does commitment change scout wobble?** This asks whether the heading wobble is
the same churn as the attack-move oscillation.
- Run: gang_ram vs gang_pack, `FIGHT_REQUIRE=gang_tank`, the 4 maps, busy 0, seed 3, 120 s, builder0. One arm with
  commit on, one with `NAV_FLAGS=--nav-off=commit`. Each arm is verified from its `NAV_FIGHT_ARM` line.
- Metric: scout `wobble` events per scout alive-minute, per map, paired by map.
- Rule:
  - Commit on is ≥ 30% lower than commit off on ≥ 3 of the 4 maps: **same phenomenon.** Fix it with the churn.
  - Within ±10% on all 4 maps: **not commitment-related.** Look at steering jitter in the wheeled controller.
  - Anything else: inconclusive.
- Semi verdict from the commit-on arm (the game as shipped): ≥ 1 pre-registered event per semi alive-minute on any map
  means the lead's report reproduces; 0 on all maps means it does not reproduce in fights either.

**Results of the commit/wobble A/B (builder0, `3018e993`).** The FIGHT_REQUIRE control passed: 23 semis and 26 scouts
fielded on every map.
- **Semi: does NOT reproduce.** 0.11–0.74 in-place events per semi-minute (yard 0.74, 15 of its 30 events in phase
  `blocked`). That is 5–30× below scouts (3.4–3.7), IFVs (2.8–3.6) and supports (1.3–2.1).
- **Scout wobble, commit on vs off:** boneyard +19%, boulevard −14%, pit −4%, yard −6%. By the pre-registered rule
  that is **inconclusive**.
- Reading the code explains it. A standoff HOLD returns index −1, so the hold **never consults commitment**
  ("commitment did not help" and "commitment was not consulted" look identical from outside). `standoff_holds` had no
  hysteresis, and about 40% of scout events happen while holding (`arrived`).
- squad reports that player semis spend 85% of ticks under a face order. That counts the ORDER; this counts the
  ROTATION. Semis are told to pivot and mostly can't.

**Hold hysteresis (round 8), pre-registered BEFORE its run.**
- `CombatMotion.standoff_holds`: a gun already holding keeps holding up to `HOLD_SLACK_M` = 3 m past either edge of its
  band, and only a round that would hit it breaks the hold. `--nav-off=holdband` switches it off. Tests are in
  `test_ai_combat_motion`.
- Runs: builder0, one tree, seed 3, 120 s, busy 0, the 4 maps, holdband on vs `--nav-off=holdband`, each arm verified
  from `NAV_FIGHT_ARM holdband=`:
  - (G) gang_ram vs gang_pack with FIGHT_REQUIRE=gang_tank;
  - (C) Condemned, STALL_VERB=attack_move.
- Primary: scout in-place events per scout alive-minute (the pre-registered count), from (G), paired by map.
- Secondary: attack_move `oscillating_share`, from (C).
- **Win:** scout events ≥ 20% lower with holdband on, on ≥ 3 of 4 maps, AND (C) oscillation not higher with it on, on
  ≥ 3 of 4 maps.
- **Kills guard** (a unit that holds when it should move dies; churn down with kills down is not a win): units lost,
  both sides, per run. The guard FAILS if the holdband arm is > 20% lower than off in ≥ 2 of the 8 paired runs, or
  > 20% higher in ≥ 2 of them. Either way the fight changed character and needs a look before shipping.
- Anything else is inconclusive. It then ships only with the lead's say-so.

**Hold hysteresis A/B: result (builder0; runs rsynced from 7c4ec608 to 7f14241b, identical fight and sim code).**

Arms read live, holdband=true vs false. Figures are on vs off.

| map | (G) scout events/min | (G) units lost | (C) oscillation |
|---|---|---|---|
| boneyard | 2.84 vs 3.62, **−22%** | 3 vs 4 | 6.6% vs 6.6% |
| boulevard | 2.72 vs 3.38, −19.5% | 2 vs 5 | 5.3% vs 5.3% |
| pit | 3.17 vs 3.43, −8% | 2 vs 3 | 5.8% vs 5.8% |
| yard | 3.44 vs 3.67, −6% | 2 vs 5 | 8.3% vs 7.2% |

- Primary: 1 of 4 maps reached ≥ 20% lower. Secondary: oscillation was not higher on 3 of 4.
- The **kills guard tripped**: 4 of 8 runs had > 20% fewer lost. The counts are 2–5 units out of 90 in 120 s, so the guard
  has almost no power here. But the rule was fixed in advance.
- **Verdict: not a win.** Hysteresis is now **opt-in** (`--nav-off=holdband` turns it ON, like `r5sidestep`), so the
  default game is round 7's hold. The direction is consistently downward (scout −6% to −22% on all four maps), so it is
  worth the lead's eye, not dropping.
- Also noticed: (C) Condemned oscillation came out identical to the third decimal on 3 of 4 maps between arms.
  Condemned fights rarely hit a standoff hold. The churn in the headline is not in the hold path.

### Flow fields (round 8, item 3) — PRE-REGISTERED before a line of it is written

**What it is.** One cost-to-goal field per shared goal, built by a Dijkstra sweep over the navmesh polygons and read as
a gradient, instead of every unit owning an A* route to the same place. Per-unit A* stays for singletons and for every
reachability answer. `--nav-off=flow` switches it off, and it stays **OFF by default until it clears the bar below**.

**Instruments, never pooled** (arena's ruling, and its ceiling argument):
- `terminus` (arena `8fda01a8`, quoted with that commit: the lead has not ruled on the map): the realistic one.
  `no_progress` 0.091, 30/30 arriving, a 51.5 s crossing against a 120 s limit, so there is headroom to move.
- The barriers fixture (`make nav-maze`): the sensitivity detector, built ground, `no_progress` 0.192.

**Metrics, both under a PLAIN MOVE, never attack-move progress** (it cannot move more than about 3 points from better
pathing, so it would read a working change as a failure):
- Primary: `stuck_share` = the share of ordered unit-seconds in `blocked_*` + `slow` + `yielding`, from
  `nav-fight`'s `by_verb["move"]` buckets.
- Secondary: arena's `no_progress_share`, and arrivals (`arrived` of N) which must not fall.
- Power: both are unit-second shares over ~1400 under-way seconds a run, not 2–5 deaths. The kills guard is not used
  here; its A/B last time tripped on noise.

**Ship it only if, on terminus:** `stuck_share` ≥ 20% lower (relative), AND `no_progress_share` ≥ 20% lower, AND
arrivals unchanged at 30/30, AND `make check` green — plus the barriers fixture moving the same way (≥ 20% lower
`no_progress`). Both instruments are reported separately, with commit and machine.

**REVERT it (and record the round as a null) if ANY of these:**
1. terminus `no_progress_share` improves by less than 10% relative, or `stuck_share` by less than 10%;
2. arrivals fall anywhere (terminus, barriers, `nav-suite`, the head-on maze);
3. the two instruments disagree in SIGN (one better, one worse): that means the change is map-shaped, not a fix;
4. any Movement contract answer changes: `reachable` for an unreachable goal, `blocked_by` attribution, or
   `route_end_gap_m`/`goal_gap_m` (the N1 tests own this and must stay green);
5. planning cost per tick on builder0 rises more than 25% against the same commit with `--nav-off=flow`;
6. `make determinism` or the nav-suite arrivals move at all.

7. **The look.** A five-squad move on terminus, captured at the lead's pose (pitch 21, 49 m, FOV 35) with the switch
   on and off, and LOOKED at. Revert if the group reads as a crowd rather than as squads. Flow fields make units share
   a congestion gradient, which is the point and is also how a formation turns into a herd; the lead has just paid 4
   seconds of arrival time for a tidier march, so `stuck_share` would score that trade as a win while undoing what he
   bought. No threshold is pre-registered for this, only that a human looks and writes down what they see. (Every
   instrument defect this round was found by somebody looking at output, not by a test going red; conditions 1–6 are
   all numbers.)

Reverting means the switch is deleted along with the code, not left in: a mechanism nobody reaches is how round 7's
commitment ended up being measured twice for nothing.

**Flow fields: first runs, and an instrument failure (builder0, tree `279f8a98`).**
- `nav-maze` does not pass `NAV_FLAGS` to its probe (`mk/arena.mk:53`), so BOTH maze arms ran the same treatment and came
  back byte-identical (terminus no_progress 0.030 twice; barriers 0.541 twice). Those numbers are a positive-control
  failure, not a null. arena has been asked to add the flag and an ARM header to the probe.
- The fight half did have distinct arms (`off=[]` vs `off=["flow"]`, read live). Terminus, 45 a side, seed 3, 120 s:

| | flow off | flow on |
|---|---|---|
| move: progressing | 0.545 | 0.579 |
| move: stuck (blocked+slow+yielding) | 0.415 | 0.373 |
| of which blocked_no_path | 0.160 | **0.219** |
| attack_move oscillating | 0.060 | 0.045 |

  One map, one seed, so it decides nothing. The `blocked_no_path` rise is the thing to explain before anything else:
  the field should fall back to A* whenever it cannot answer, so it should not be able to report MORE goals as
  unreachable than A* does.
- **Baseline settled with arena:** `NAV_BOTH=1 NAV_UNITS=60 NAV_TIME=180` on terminus (`8fda01a8`), on builder0. Arena's
  0.091 was one-way/30 on the laptop; my 0.030 was both-ways/30. Density dominates: both-ways at 60 gives 0.153.
- **Arena's spare finding, taken:** one-way at 60 units is the only maze configuration whose `oscillating` (0.012) is
  above noise (0.001–0.002). Crowding one direction is where the lead's complaint lives.

**Flow fields, the verdict: REVERTED, a null (builder0, tree `654b1c5d`, terminus, 45 a side, 120 s, three seeds,
arms read live from `NAV_FIGHT_ARM`).**

| seed | stuck_share off → on | oscillating off → on | no_progress off → on | field answered / fell back |
|---|---|---|---|---|
| 3 | 0.415 → 0.373 (−10%) | 0.060 → 0.045 | 0.451 → 0.470 | 2948 / 919 |
| 5 | 0.365 → 0.362 (−1%) | 0.037 → 0.037 | 0.403 → 0.374 | 4019 / 1149 |
| 7 | 0.372 → 0.405 (**+9%**) | 0.040 → 0.039 | 0.428 → 0.447 | 3228 / 1417 |

Mean stuck_share ≈ −1%, and no_progress is flat to slightly worse. Pre-registered condition 1 — "revert if terminus
`no_progress` improves by less than 10% relative, or `stuck_share` by less than 10%" — fires. The one seed that looked
good (seed 3, −10%) is the seed I ran first, which is exactly why the rule was written for three.

Also worth keeping: the field answered about 70-75% of route plans and fell back to A* for the rest, so this is not a
mechanism that failed to run — it ran, and it did not help. A grid of 2 m cells over a street map gives routes A* was
already giving; what a flow field buys is CPU when an army shares one goal, and a fight's goals are per-unit.

**Condition 7 (the look) could NOT be evaluated, and that is an instrument defect of mine, not a pass.** `nav-flow-look`
filmed both arms on terminus at the lead's pose (pitch 21, 122 m) and the frames are unusable: at that pitch a city map
of 40 m blocks hides almost every vehicle behind a building, and the unit nameplates cover what is left. Whoever films a
march on terminus next needs a steeper pitch (45-55 degrees), the nameplates off, and the camera framed on the army
rather than parked at a distance. The decision above rests on condition 1 alone, which is enough on its own; if the
numbers had been a pass I would have had to re-shoot before shipping.

Deleted with the code, per the pre-registration: `game/ai/flow_field.gd`, `Movement._plan`'s flow branch, the `flow`
entry in `OFF_NAMES`, `tests/test_flow_field.gd`, the `flow` block in the fight probe, and `make nav-flow-look`.
**Kept:** the `--nav-off` unknown-name refusal (`Movement.OFF_NAMES`), which this work produced and which is worth more
than the field was.

### Round 7 report (nav, 2026-09-19) — read this first when resuming round 7

**Green, merge here: `d963d9ad`** (builder0: `test` 1191/1 — the 1 is control's `test_radar`, a static leaked by
sibling tests in its own file, fixed on `main` by the orchestrator and not yet merged into this branch; every other
`check` target run as one remote make exited 0; sim hash `253ecfdeed84bc4d` = `main`'s line, so these merges do not
move the baseline). Merged to `main` before it: `1dd28265` (standoff + unsticking), `36627372` (commitment,
reachability).

The lead: *"a lot of them just keep getting stuck in places"*, *"scouts are just running directly into their targets"*,
*"I couldn't tell what direction they were facing"*. What nav did about each, measured (all builder0):

| complaint | cause found | fix | before → after |
|---|---|---|---|
| stuck in a fight | round 6 only ever measured driving with no enemy. `make nav-fight` attributes every stalled ordered unit-tick: pinned on the END of a barricade/container (a carrot or car look-ahead whose chord clipped it), cars nose to nose with no legal move | chords checked on the navmesh with a per-hull slack from the bake's 2 m erosion; a final guard falls back to the next corner; cars give way by reversing | plain move in a fight, seed 7: progressing 74% → 83%, blocked by friend 6.7% → 0.6%, by terrain 5.9% → 0 |
| scouts ram | CombatMotion's round-3 "run" style: close to 9 m whatever the band, drive away gun-backwards to 22 m | "standoff" (shoot-and-scoot) — squad's 2 hooks land it | closest 3.0 → 27.7 m, nose on target 17% → 79%, shots 29 → 211 |
| facing | the ORDER carried facing; the BRAIN never executed it | squad's intended_facing (their file); nav's settle radius for the hold tail | within 15° at +10 s: move 2/30 → 27/30; hold 1/29 → 21/30 → 27/30 with the settle patch |
| attack-move "disobeys" | ~70% of target jumps are CombatMotion re-planning inside one decision (squad's split) | commitment (hysteresis) + timer jinks only against projectile weapons; pre-registered A/B: ships | motion churn 21.4 → 15.6/unit-min, losses no worse; cost: attack-move progress −2.9 pts (paired, 5/5 seeds), time moved to fighting from a halt |

**Also:** reachability is `Pathing.query` (route ends at the goal's nearest mesh point; `goal_on_mesh`; gaps reported,
not compared) and Movement says `blocked`/`no_path` at the end of an unreachable route. The gangs' backwards IFV is
art-only (the sim reads only the hull body's basis). The maze regression my own fixes caused (60 → 27/60) was found by
nav-suite, isolated by switches, fixed at the cause; maze is 60/60 again.

**Handed to squad, waiting on their file:** `references/nav/round7_scout_standoff_brain.patch` (landed on their side),
`round7_commitment_brain.patch`, `round7_hold_settle_brain.patch` (needs `d963d9ad` on main first).

**Process findings (in `verification.md` and the orchestrator's lessons):** a switch initialised in a static var from
another class's static silently did nothing (the first A/B's arms were byte-identical) — switches are read at call
time and `nav-fight-ab` refuses identical arms; seeded A/Bs are PAIRED (the progress cost was invisible unpaired);
pre-register a guard metric, not only a success metric.

**Looked at like a player** (`make remote T=control-scale-shots`, builder0, `b6a5b7ca`, 34 a side, foundry, the lead's
camera: pitch 21°, FOV 35°, 61-62 m): an attack-moving squad rounds a barricade as a spaced column with nobody pressed
on its end (the round-6 carrot pinned hulls exactly there); a moving squad threads out of the parked army without
shoving it. **Limit:** stills can't show how a hull ROTATES (pivots, three-point turns), which is what the telephoto
makes visible; judging that needs motion (a short capture), not done.

**Rotation at the lead's pose** (`make remote T=nav-rotation`, builder0, tree of `d12dd70a` + the capture tool; pitch
21, 49 m, FOV 35). "Robotic" was pre-registered in `tests/nav/rotation_capture.gd`'s header before the first run:
(a) 0 → ≥90% of peak angular rate, or back, within one tick; (b) overshoot, or a last tick > 30% of peak; (c) rotating
about a point it isn't driving around (frames).

| shape | (a) start / stop | (b) overshoot, last tick | (c) frames | verdict |
|---|---|---|---|---|
| tank pivot on `face` (118°) | **instant start** (90% of peak in 1 tick); stop decays over 31 ticks | 0.0°, 4% | pivots about its own centre (right for tracks) | **robotic (a)** |
| scout K-turn to a point behind it (159°) | 21 ticks up, 25 down | ~~overshoots 20.7°~~ 0.0° (round 8: the 20.7° was the measurement wrapping 201° to −159°) | drives a real arc | smooth |
| squad of 4 wheeling onto a facing (89°) | 4 ticks up, 28 down | 0.0°, 4% | in place, together | smooth |

What each would take, NOT started (orchestrator: the capture decides, the lead's next playtest decides whether):
(a) is the plant — `TankMotion.step_in_place` sets yaw rate = turn × max rate with no angular acceleration, so every
pivot starts at full rate; the textbook fix is an angular-acceleration limit in the plant (a rate PID on heading in
`face` would only mask it from one caller). (b) is the car's arrival — it reaches its point still turning at speed;
Reeds-Shepp (plan the K-turn to end on the heading) or an arrival that brakes the yaw. Raw series and verdict lines:
`references/nav/round7_rotation_capture.txt`.

**Not done / owed:** flow fields (the root fix for crowding; an architecture change, explicitly not this round);
Reeds-Shepp paths for cars; faction-gain screenshots at the lead's 21° pose; the idle ADVANCE+stop facing miss (squad).

### Round 7 A/B, pre-registered (written 2026-09-19 BEFORE the run)

**Commitment in CombatMotion** (a bonus for last plan's direction; timer jinks only against projectile weapons) vs
without (`--nav-off=commit`). `make nav-fight-ab AB_OFF=commit`: yard, CPU armies at 6500, seeds 1 3 5 7 9, 120 s,
both arms from the same tree. **Churn** = motion jumps per unit-minute (drive target > 8 m, same option). **Survivability**
= green units lost AND rust units lost (both sides: the exchange, not only our losses).
**Rule:** if commitment cuts motion churn and green losses do not rise by more than the seed-to-seed spread of the
"off" arm, and the exchange (rust lost / green lost) is not worse by more than that spread, it ships: the churn was not
the price of not dying. If green losses rise beyond the spread, evasion is load-bearing, commitment does not ship, and
the answer is legibility (control's), reported with the numbers.

**Result (builder0, 2026-09-19; `references/nav/round7_commit_ab.json`).** The first run's arms were byte-identical: the
switch never applied (a static initialiser read `Movement._off` before it was populated). Nothing was reported from
it; switches are now read at call time and `nav-fight-ab` refuses identical arms. The re-run's arms differ (live
`NAV_FIGHT_ARM commit=true/false`):

| | commitment on | off (spread) |
|---|---|---|
| motion jumps / unit-minute | **15.6** (lower on 5/5 seeds) | 21.4 (±4.8) |
| decision jumps / unit-minute | 6.8 | 6.8 |
| green lost (of 34-52) | 1.4 | 1.6 (±0.8) |
| rust lost | 1.2 | 0.8 |
| attack-move progressing | 41% | 44% |

**By the rule: it ships.** Churn down 27%, green losses not higher, exchange not worse. **Caveats I did not pre-register
and report anyway:** survivability had little power (1-3 deaths a side in 120 s), and attack-move progress dipped 3
points. The brain half (passing the previous direction back; timer jinks only against projectile weapons) is squad's
file: `references/nav/round7_commitment_brain.patch`.

### Resuming this stream after round 8 (written 2026-09-19)

**State:** round 8's backlog is done (the yaw ramp, the semi question, the stall repro, hold hysteresis, the gear-flip
diagnosis, flow fields reverted as a null, Reeds-Shepp parked with its evidence retracted). Green at `81f87186` on
builder0 (1256/0, `>> remote: make check exited 0`), with the sim baseline patched-and-restored locally — the orchestrator
records `glibc-2.43 668b7d49 -> 0cb238bf`, not me.

**The arc is green too:** `5367c395` on builder0, `>> remote: make check exited 0`, 1261/0, `sim-baseline passed:
0cb238bf366e141f`. Commits after it are probes and docs, and the tip passes `make remote T=lint`. Nothing is in flight.

**Next, in the order I would take them:**
1. A long hull's clearance and the missing recovery under a `face` order (the section above; combat's evidence).
2. The commitment-strength A/B, pre-registered above (`COMMIT_BONUS` 0.35 -> 0.7).
3. Tighten control's wheeled facing bound back to the tracked one once squad populates `facing` (they own that half).

**The habit that paid this round:** write the decision rule, the guard and the revert condition down BEFORE the run, and
run three seeds. The first seed of the flow-field A/B said -10% and the round would have shipped a null on it.

### Resuming this stream (written 2026-09-18 before a 4-day pause; read this first)

**State:** backlog complete (X1–X8 done, X9 closed). Everything is merged or mergeable: code green at `34293b3b`
(builder0, 1127/0), tip `4bbb957c`+ docs only. Worktree clean. Nothing is in flight. **Do not** restart anything below
without re-measuring first — every number here is tied to a commit.

**Where the knowledge lives:** architecture and every constant's reason in `_agents/navigation.md` (read its
*Measuring* section: the switches table and the two traps). Saved measurements in `_agents/streams/references/nav/`
(`nav_suite_30e3250d_baseline.json` = round-5 movement; `nav_suite_1923059c.json` = after X3/X4/X7 + K1 fix).

**The K1 start window — three decisions, each measured** (`movement.gd` `_avoid`):
1. For `AVOID_GRACE_TICKS` = 10 ticks after a *new destination* (goal jump > 3 m; a sliding slot doesn't count) the
   hull steers along its route and avoidance only sets throttle. Why: with avoidance steering from tick 0, control's
   `test_units_respond_within_three_ticks…` took 4 ticks (133 ms) against K1's 100 ms = 3 ticks.
2. Inside that window, a crowded-but-not-reversed way is driven at ≥ 15% (`AVOID_MIN_PACE`), so an order always
   *visibly* starts (the test also accepts "driving at it", which needs throttle > 0).
3. The 15% floor applies **only** in the window: left on permanently it cost 20 s at the tail of head-on maze-60
   (`nav-where`, 300 s: 182.5 → 162.8 s last arrival; builder0, tree of `1923059c`'s parent).
And for wheels, any steering point must be forward-reachable (outside both turning circles): found by control's
right-click test (an IFV three-point-turned for a second on a 40° bend with a 1.2-radius carrot).

**Every headline number, with provenance (all builder0):**
- Arrivals, `make nav-suite` (hold-fire, 180 s, 1 seed, all `tank`): round 5 at `30e3250d` 15/30, 35, 0 (head-on),
  34, 33, 40 of 60 → X3+X4+X6 at `e291a35a` and again at `1923059c`: 30/30 and 60/60 on every config.
- PID: `test_station_keeping`, slot at 5 m/s re-issued every 4 ticks: mean gap 0.35 m PID vs 4.58 m P-law at
  `e291a35a` (0.13 m after later fixes); X8 faction table at the commit "nav X8" (`test_station_keeping` MEASURE lines).
- 12 m lie: `make nav-orders` before `c3e4102e` / after `c8c7a79d` (table below).
- Cost: `make ai-perf` 60 brains, `move` part 1119 µs (`30e3250d`) → 1688 µs (`1923059c`).
- Near-ambush attribution: `near_ambush(30 s)` through_tick 531 at `00c99bf4`, 555 at `7cce78af`; 531 again on nav's
  tree with `--nav-off=r5sidestep`.

**Suspected, not proved** (don't treat as findings):
- Head-on single-lane traffic resolves one unit at a time; a *column-level* yield (the whole queue backs as one) would
  probably cut head-on maze t90 (~144 s) toward one-way (~120 s). Untested.
- The K1 window likely costs a little flow in open ground (yard one-way t90 47 s at `e291a35a` → 55 s at `1923059c`),
  but that pair also differs by X7 changes; not isolated.
- ORCA's 2 s horizon and hull radius (mean half-extent + 0.25 m) were never tuned; they were the first reasonable
  values and the suite went 100% on them. Tuning could buy flow; it could also break head-on.
- Wheeled units in crowds were only checked through control's tests and the IFV debug trace; nav-suite uses tanks
  (tracks) only. A wheels-only suite run has never been done.
- X8 almost certainly does not change win rates; never measured.

### Where it stands (updated as I go)

| Item | State |
|---|---|
| **X1 / CP1** Movement seam | **Merged to main** (`30e3250d` → `f03a795c`). **The 12 m lie is deleted** (`c8c7a79d`, measured below). **Gunnery split done** after CP4 (`game/ai/gunnery.gd`, combat's file, combat's seam); cutting its envelope call turns exactly combat's three wiring tests red (22 rule tests stay green). `ORDER_STALL_ARRIVE` deletion waits for squad's precedence fixes, as its own measured commit (orchestrator's ruling). |
| **X2** measure the jam | `make nav-suite` (arena's probe × configs, parallel on builder0) + `make nav-where` (who didn't arrive, where, and what their Movement says). Baseline saved: `references/nav/nav_suite_30e3250d_baseline.json`. |
| **X3** ORCA | Done: `game/ai/avoidance.gd`. |
| **X4** right-of-way | Done: ask / give way in `movement.gd`, visible as `phase: yielding`. |
| **X5** maze gate | **Met on one seed at 180 s except head-on maze** (see numbers); five seeds are identical by construction (below). Not wired into `make check`: a suite run is ~10 min. |
| **X6** PID | Done for station-keeping (`pid.gd`, `control_gains.gd`): 0.35 m mean gap vs 4.58 m for the P law. Speed matching is the same loop; turret lay not attempted (combat's turret already has a rate limit, which is the dominant dynamics). |
| **X7** path quality | Done: carrot along the route, cars look until they can drive onto the point, re-plan on change. |
| **X8** factions by gains | Done as data (`ControlGains.FACTIONS`), measured on movement; win rates not measured (below). Found and fixed a stopped-slot overshoot first. |
| X9 dynamic obstacles | **Closed: no consumer, and arena would refuse one.** Wreck props are static, baked and blocking; destroyed vehicles leave no body; the approved destructible cover collapses to a lower stack without changing drivable space. A mid-match re-bake would also have to reproduce the south-half-plus-mirror construction or reintroduce the 64% base bias (trip-up 21). `NavigationObstacle3D` would duplicate ORCA. |

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

### The 12 m lie, measured (`make nav-orders`: 5 player squads × 6 with brains, ordered across one another; builder0)

| | yard | foundry | maze |
|---|---|---|---|
| before (`c3e4102e`) | 30/30, t100 27.3 s, 0 far | 30/30, 21.4 s, 0 far | 29/30 in 90 s: 1 completed 8.1 m short, 1 never (blocked 90 m out) |
| after (`c8c7a79d`) | same | same | **30/30, t100 73.2 s, 0 far** |

The unit that "completed" 8 m short was parked in a corridor, and it was what the never-arriving unit was stuck
behind. The lie wasn't only a false report; it made jams.

### X8: factions by their gains (builder0, `test_station_keeping`, the same tank hull, a slot at 5 m/s that stops)

| crew | tracking gap | overshoot when the slot stops | settle |
|---|---|---|---|
| default (Condemned) | 0.20 m | 1.89 m | 3.2 s |
| Syndicate — crisp | **0.09 m** | 1.68 m | 3.1 s |
| gangs — loose | 0.81 m | **2.55 m** | 3.2 s |
| Law — damped | 1.00 m | **1.55 m** | 3.1 s |

Before these, every gain set overshot a stopping slot by ~3.2 m: the slot's speed estimate stayed stale for a second
and feed-forward pushed the crew past. Fixed (a goal re-issued unchanged means it stopped). **Honest limit:** this
changes how a formation moves and halts; nothing here shows it changes who wins, and I would not expect it to.

### Findings worth relaying

- **60 units on 52 spawn points stacks 8 pairs exactly on top of each other, and in round 5 those pairs never moved.**
  Part of arena's baseline was coincident hulls, not congestion. Coincident hulls now part by name (deterministic).
- **Five seeds of the probe are one sample.** Check that the thing you vary actually varies before running a series.
- **Blind unsticking rams friends.** The round-5 routine reversed whatever was behind; in a column that makes two stuck
  units out of one. It now backs off only with room, and tracks pivot instead.
- **Removing a mechanism can be the regression.** Squad's near-ambush assault got 0.8 s slower on nav's merge with
  every added mechanism switched off; the cause was the *removed* round-5 sidestep, which overtook a friend in the
  same lane. ORCA doesn't overtake (a friend moving your way isn't a collision). squad restored its own 22 s window.
- **Cars and short lookaheads don't mix.** Any steering point inside a car's turning circle is a three-point turn; the
  carrot, the avoiding point and the give-way spot all have to be forward-reachable.

### Report (nav, 2026-09-18)

**Green, merge here: `34293b3b`** (builder0 `make check`: 1127 passed, 0 failed, all smokes; `5b8e0df7` and this Status on
top are docs only). **The sim baseline moves and is deliberately not recorded here** (orchestrator's ruling); on this
tree it was `glibc-2.43 b0df248dc0140639`. Earlier merges to main: CP1 at `30e3250d`, X3–X7 at `1923059c`.

Looked at like a player: `make remote T=control-scale-shots` (34 a side, foundry, 1920×1080, builder0, 18:36): squad 1
moves out as a spaced column, squad 2 threads out of the parked line without disturbing it, no piling. The lead's own
scenario, headless and with brains, is `make nav-orders` (numbers above).

### What to playtest (the lead)

- `make skirmish`: box-select squads and send them in different directions at once, through each other, and through
  a gap. What to look for: nobody sits jammed behind a friend; a friend in the way pulls aside (it reads as *giving
  way*, not as avoiding); a new order still starts moving instantly; squads keep their places on the move and stop
  in them without sailing past.
- `make skirmish ARENA=maze` if you want the torture test (it isn't a shipping map).
- Headless, no window: `make remote T=nav-suite`, `make remote T=nav-orders`, `make remote T="nav-where ARENA=maze NAV_BOTH=1"`.

### Questions for the lead

- **Faction feel by control law (X8)** is in as data: Syndicate crisp, gangs loose and overshooting, Law damped.
  It changes how formations move and halt, not who wins. Keep, exaggerate, or drop?

### Known issues

- Head-on traffic in the maze's single 3 m corridor resolves (60/60) but slowly: t90 ~144 s against 120 s one-way.
  Right-of-way decides one unit at a time; a platoon-level "whole column waits" would be faster.
- Hulls can still touch: ORCA picks a velocity, the tank's turn rate and acceleration only approximately follow it.
  `move_and_slide` keeps them solid, and that's by design (vehicles are vehicles).
- `yard` one-way t90 55 s against 47 s at `e291a35a`. The K1 start window trades a little flow for the 3-tick
  response. Not chased further.

### Next steps

- **If round 7 revisits the startup-only navmesh, revisit `agent_max_climb` with it** (arena): both follow from "a
  snapshot baked in two mirrored halves"; that constant caps authored slopes at ~20° (`make slope-probe`), and raising
  it needs the same swap-bases fairness control a dynamic mesh would.
- A column-level right-of-way (a whole queue yields as one) for single-lane head-on traffic.
- Wire `nav-suite`'s maze-60 head-on into a nightly target rather than `make check` (~10 min on builder0).

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

- **arena** (X9): answered. Nothing stops blocking mid-match, now or planned; X9 is closed (see the table).
- **arena**: `tests/arena/maze_probe.gd` drives plain `OrderController`s, so round 5's brains-only `_around_friends`
  never ran in your baseline. Not a problem now (N1 avoidance is on for every controller) — just a note for reading
  the old numbers.

### Merge notes

- New files: `game/ai/{movement,avoidance,pid,control_gains,gunnery}.gd` (**gunnery.gd is combat's**),
  `tests/test_{movement,avoidance,pid,station_keeping}.gd`, `tests/nav/{nav_probe,order_probe}.gd`, `mk/nav.mk`,
  `tools/nav_suite.py`, `_agents/navigation.md`, `_agents/streams/references/nav/`.
- Edits outside nav's paths: `game/ai/tank_brain.gd` — only `ORDER_STALL_ARRIVE` and its one use (agreed with the
  orchestrator). `tests/baselines/sim_state_hash.txt` is untouched (recorded by the orchestrator at the close).

# Stream: nav (units still drive into walls: the Terminus drive test, and every clearance number names its motion)

> Read `HANDOFF.md`, [orchestration.md](../orchestration.md) (*The worker contract*), [game_design.md](../game_design.md)
> (*Round 10 direction*), [workstreams.md](../workstreams.md) (*Round 10: the eight streams*, contracts **R3**, **R4**,
> checkpoint **CP2**, **CP4**; *What reads `hull_size`*), [navigation.md](../navigation.md), and your round-9 brief
> [archive/round9/nav.md](archive/round9/nav.md) — its "Next steps, in order" and the pre-registered wheeled-facing row
> are folded in below.
>
> **You own** the desired-velocity layer: `game/ai/{pathing,steering,combat_motion,movement,avoidance,pid,
> control_gains,order_controller,order_feed}.gd`, `game/tank/tank_motion.gd`, `mk/nav.mk`, `tests/nav/`, `tests/test_*`
> for those files, `_agents/navigation.md`. Not yours: `game/ai/gunnery.gd` (combat), `tank_brain.gd` (squad),
> `game/tank/tank.gd` and the plant constraint (combat), `hull_size` values (feel's carve-out for two units, combat
> otherwise), the bake radius in `arena.tscn` (arena's; you read it live).

## The lead's direction (2026-09-20, evening; verbatim in game_design.md *Round 10 direction*)

> Units are still driving into walls.

> I want to gauge how smart units are by trying to navigate them through the city.

And his afternoon acceptance: *"I'll know that they units are doing what I want when I can navigate them through the
Terminus streets."* The round's bar for you is that sentence, measured.

## Where things stand

- **The map was against you.** Containers sit in the Terminus lanes (arena's brief, item 1; CP2 clears them and asserts
  every lane's drivable width ≥ 6.64 m). Until CP2 merges, measure on the ring road and the clear halves of the
  avenue, and say so beside every number; after it, the whole grid.
- **"Driving into walls" has no counter.** Nothing on the tree counts a hull-wall contact per tick, per unit, per
  cause. `Tank`'s plant (combat's) knows when `move_and_slide` collided; `Movement` knows the route and the corridor;
  neither publishes "this hull touched a wall at this tick while doing X". The first thing this round is that
  instrument, published in `Movement.state(unit)` and on `--nav-off` telemetry, so "still driving into walls" becomes
  a number with a cause split (routing: the path ran through the wall; steering: the desired velocity pointed at it;
  avoidance: ORCA deflected into it; the plant: the hull could not follow; the arena: the box was not in the bake).
- **What you already know:** the `wedged` regime detector (round 9, fires 8× in the defile run; all three
  pre-registered hypotheses dead; 61 % ORCA deflection with no arrival); `Arena._obstacle_shapes()` tiles big boxes
  because the baker ignores them (arena's; a hull "pinned against an obstacle its path insists is not there" is the
  failure it prevents); `clearance_shortfall()` and the routing refusal behind `--nav-off=clearance` (off on
  measurement: progress −35 %, 90.9 % of consultations refused, and your own correction that `radius_of` is a
  ROTATIONAL envelope compared against a LATERAL clearance); `Movement.hull_box()` as the one accessor; the clothoids
  (A4) off; the arrival arc's `off_mesh` refusals split 474/361.
- **The plant is combat's and its constraint is OFF** (`Tank.yaw_fit_enabled`, `game/tank/tank.gd:683-710`): with it
  on, four of five squads froze at spawn (the refusal never resets); combat's round-10 first item is the predicate.
  Your round-9 endorsement of a world-only mask stands as an ARM, not a default, and only with `test_move` in both
  arms and "the corridor must not move" as the arm proof. **Relay rule:** when your drive test shows a hull rotating
  through a wall, that is combat's row; when it shows a hull DRIVEN into a wall by its desired velocity, it is yours.
- **Every clearance constant must say which motion it licenses** (your lesson 197): `HULL_CLEAR_M` (squad's: its pitch
  is being derived from the turning envelope this round), the bake radius (arena's, 2.0 m, driving), `Avoidance.
  radius_of` `(w + l)/4 + margin` (yours: the seventh disc site, 4.58 m for the rig against a 1.66 m half-width, too
  wide abeam, too narrow end-on, with its own falsifier).
- **The held wheeled hull's facing** (pre-registered in round 9): crews end at tank 1.4°/16.2°, ifv 41.4°/28.5° after a
  hold with a drawn heading; a wheeled hull cannot neutral-steer. Falsifier: all four crews within 10° within 5 s on the
  default arena; `face_giveups` stays zero; time-on-station and shots not reduced; a bounded, visible three-point turn.
- **The seam** (round 9's structural finding, yours and squad's): `CombatMotion` decides under a tenth of a hull's
  ticks and `Movement` drives the rest knowing no leash; every one of your five rows trips on it. Not a first item;
  the first candidate once the drive test says where the wall contacts come from.

## Backlog (in order)

1. **The wall-contact instrument.** Per unit per tick: contact yes/no (from the plant's collision report; ask combat
   for one getter if `Tank` does not expose it, stub by reading `get_slide_collision_count()` through the unit),
   the cause class (route / steer / avoid / plant / bake), the corridor and the lane name if arena's `lanes` cover
   the point. Published in `Movement.state()` and summed in the `--nav-off` arm report. A test that drives one hull
   at a wall and reads the counter is the mutation check.
2. **The Terminus drive test** (the round's bar). A scripted default-path run (`make skirmish`-equivalent flags:
   none) on Terminus: a mixed squad ordered street to street (spawn → ring road → west street → plaza → the far ring
   road), then a squad of War Rigs the same way. Pass: every unit arrives, zero wall contacts for the mixed squad,
   the rigs' contacts named by cause. Run it on the pre-CP2 map on the clear streets first, then on CP2's map; both
   numbers in Status with the commit and machine. This is the test the orchestrator reads before merging anything of
   yours.
3. **Fix what the instrument names, one cause at a time, each as an arm.** Expect: routing corners cut through a
   kerb container (the chord slack against the hull's WIDTH plus the bake, not `radius_of`); ORCA deflecting into a
   wall in a corridor (the navmesh refusal's fallback); the wedged regime (something must notice it; today nothing
   does). Every fix has a before/after on item 2 and the sim baseline pre-registered UNMOVED unless the fix is a
   default-path behaviour change, in which case it is pre-registered MOVED with one cause and merged alone.
4. **`Avoidance.radius_of` (the seventh disc site).** An oriented capsule or box abeam vs end-on, behind a knob, with
   its falsifier (the defile dispersion and the yard oscillation share must not worsen; the rig's abeam clearance
   falls from 4.58 to ~2 m + margin). Off until the numbers say.
5. **The held wheeled hull's facing** (the pre-registered row above), after items 1–3.
6. **The seam.** Measure first: what fraction of Terminus drive ticks is `CombatMotion` deciding, and does a leash
   or corridor exist in `Movement` for those ticks? Then the smallest change that lets `Movement`'s goal selection
   see the formation leash (A7's level-0 region), as an arm with A12's four metrics from `make metrics`.
7. **Stretch:** A6's falsifier once squad's field emits `corridor`; N4's 361 unreachable gates against the clothoid
   arm; `facing_arc` in `Movement.state()` for metrics (owed from round 9, cheap: publish it).

## How to verify

- `make check` green (`make remote T=check`); `make nav-fight-maps`, `make metrics LOGS=…` for A12; the drive test
  as its own make target (`make nav-terminus-drive` or the name you choose, in `mk/nav.mk`), run on builder0.
- `make skirmish ARENA=terminus` and drive them yourself; look at frames at his pose.
- Every number: commit, machine, sample size, the arm proven applied (round 9: five green zero-reading arms).

## Don't touch

`game/tank/tank.gd` and the plant (combat's: send combat the contact log and a failing test), `game/tactics/**`,
`tank_brain.gd` (squad's), `arenas/`, `game/arena/`, `arena.tscn`'s bake radius (arena's; a change there is a
request with your falsifier), `game/theme/**`.

## Waiting on the lead

Nothing blocks. "Heavies in alleys" (should hulls above the bake radius not route through alleys narrower than their
clearance) is DECIDED for this round: after CP2 there are no lanes narrower than the rig; alleys off the lanes are
priced by your instrument and reported, not refused.

## Status

_(the worker keeps this current)_

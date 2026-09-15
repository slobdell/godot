# Stream: combat (weapons, weak spots, arcade driving, rules)

> Read [../orchestration.md](../orchestration.md), [../game_design.md](../game_design.md) (*Round 3 direction*, pillar
> 7, *Weapons feel*, *Locomotion*, *Match rules*), [../workstreams.md](../workstreams.md) (K2 and K3 are yours; CP2 is
> your first item), [../balance.md](../balance.md), and [../determinism.md](../determinism.md). You own
> `game/units/`, `game/combat/` except `impact.gd`, `game/match/`, `game/tank/`, `game/arena/` + `arenas/`,
> `game/ai/doctrine.gd`, `doctrines/`, `tools/{match_series,matchup_matrix,make_arenas}.py`, `mk/match.mk`,
> `game/modes/match_runner_mode.gd`, and `_agents/balance.md`.

## The lead's direction (2026-09-15)

> *"Tanks should shoot at very low frequency and be able to land devastating hit, but a miss is also quite costly. The
> IFV's were supposed to have something like a 25mm cannon like a Bradley fighting vehicle where it's basically a low
> frequency machine gun (but much higher frequency than a tank). The scouts currently are not shooting machine guns
> (note that I would think machine guns in and of themselves with their wall of bullets would even be valuable in
> circumstances, even though they can only shoot directly forward)."* Also: *"the tanks right now just shoot these
> boring blasts at somewhat high frequency"*, *"another game I'm drawing inspiration from is Twisted Metal 3"*, and on
> wheels: *"they won't be able to turn like a tank, they will have a turning radius and will need to drive like cars."*
> Decided with the lead: **arcade-tactical**.

## Where things stand (round 2, measured 2026-09-15)

- `Weapons.PROFILES`: cannon reload 2.5 s, 34 damage (a tank has 300 hull + 150 shield: ~13 hits to kill); autocannon
  0.35 s, 9 damage; machine gun 0.2 s, 4 damage, 45 m; mortar 4.5 s, 90 damage, 9 m splash; laser; flamethrower.
- Every unit steers like a tank (rotates in place at `hull_turn_rate_deg`; `game/tank/tank.gd`, `game/ai/steering.gd`).
- Friendly fire, armor thickness per face, fixed-mount arcs (`Tank.can_bear_on`), arenas as data with hazards, the
  matchup matrix (`make matchups`), and a Burner unit exist. The lead answered: control point on by default; finite
  ammo only for artillery; scouts are spotters first.
- The round-2 brief with all measurements: [archive/round2/rules.md](archive/round2/rules.md).

## Backlog (in order)

**X1. K2 and K3 skeleton (checkpoint CP2).** Add the weapon profile v3 fields and emit `Match.weapon_fired` and
`Match.projectile_impact` with the K2 fields (weak-spot flag included) using today's weapons; add
`Match.incoming_projectiles`; add the K3 locomotion fields with today's values (`tracks` for all) and a pure
`TankMotion.predict`. Also add the `Match.orders` field for control (K1). Tests for every field and signal. **Announce
CP2 in your Status as soon as it's green.**

**X2. The weapons, rebuilt for feel** (numbers are yours to tune; these are targets to measure against):
- **Tank cannon:** reload ~4–6 s; a visible shell (~60–90 m/s, so leading and dodging matter); a hit to a tank's side
  or rear takes most of its health, a frontal hit a big chunk; a miss wastes the whole reload. 2–4 hits kill a tank.
- **IFV 25 mm:** bursts of 3–5 rounds, ~1.5–2 s between bursts, fast rounds, low penetration: shreds scouts and light
  units, chips tanks, hurts a tank's rear.
- **Scout machine gun:** a continuous stream while the trigger is held (~8–12 rounds/s), spread, tracers; only fires
  where the hull points; weak per round, lethal to exposed rears and light units, suppressing up close.
- Artillery: finite ammo only here; the Lancer and Burner re-tuned to fit the new time-to-kill.
Hitscan versus projectile is your call per weapon (record why); projectiles must be deterministic and portable.

**X3. Weak spots that read.** Side and rear multipliers clearly punishing, plus a weak-spot hit (e.g. a rear or
engine-deck hit) flagged in `projectile_impact` for feel and the announcer. Tests with hand-placed shots.

**X4. Arcade driving (K3 for real).** Momentum: acceleration, braking, drift on wheels (`lateral_grip`); **wheels
have a turning circle** (no rotation at standstill, yaw rate from speed and radius, inverted steering in reverse);
tracks pivot. Proposed: scout, IFV, artillery, Lancer on wheels; tank on tracks. Units should feel quick and weighty,
Twisted Metal–like, while staying portable (curvature math, no trig where dot/cross works). Pure `TankMotion` tests.

**X5. Artillery deploys.** A `deployed` state with deploy and pack-up time; can't move or fire while changing; a slot
method `set_deployed(ratio)` for assets' outrigger animation (game_design.md *Artillery deploys before firing*).

**X6. Time-to-kill and the matchup matrix.** Re-run `make matchups` (via builder0) with the new weapons and driving,
using ai's champion brain; tune so counters hold (counter wins ≥ 65% cost-equal) and fights resolve in seconds, not
minutes. Update balance.md with the new tables and the tuning story.

**X7. Match defaults.** Control point on by default in skirmish (coordinate with control, who owns skirmish mode:
Status request); a skirmish length and first-contact time that feel good (measure `first_shot_seconds`, match
duration).

- **Stretch:** a boost or ram mechanic if the driving wants it (propose in Status first: pillar-level); wreck husks that
  stay as cover (a `unit_destroyed` event with the transform for feel and assets).

## How to verify

`make remote T=check` with the sim baseline updated on purpose (say why); unit tests per mechanic; the matchup matrix
and a match series on builder0; `make remote T=skirmish-shots` screenshots showing shells in flight, bursts, and
streams; describe in Status how a 1-v-1 tank duel and a scout run on a tank play out, tick by tick.

## Don't touch

Brains (ai), selection and orders UI (control; you only add `Match.orders`), effects and sound (feel: they read your
K2 events), models (assets).

## Status

- 2026-09-15: brief written for round 3.
- 2026-09-15 (worker): **backlog complete** (X1-X7, stretch `unit_destroyed`); X6 time-boxed at 8 of 12 counters; X7's default flip is a request to control. Report at the end of this section.

### Plan (worker, 2026-09-15)

1. **X1 (CP2)** skeleton with **no gameplay change** (sim baseline must hold): profile v3 fields with today's values,
   `weapon_fired` / `projectile_impact` from every weapon path, `incoming_projectiles`, K3 catalog fields, pure
   `TankMotion.predict` (heading as a unit vector: `√` only, no per-tick trig), `Match.orders`. Tests first.
2. **X3 before X2's tuning pass** is not worth it: X2 weapons (bursts, streams, per-weapon shell speed, integer tick
   timers) then X3 weak spots, then X4 driving (the tank starts using `TankMotion.step`), X5 deploy, X6 matrix, X7.
3. Minimal compatibility edits outside my paths get listed under *Merge notes*.

### CP2 announcement: K2 and K3 skeleton are green (X1, 2026-09-15)

**Orchestrator: `stream/combat` is ready to merge for CP2** at the commit "Combat X1: K2 weapon events and K3
locomotion skeleton". `make remote T=check` passed with the sim baseline unchanged (`c9cfbb1a221f5c94`): no gameplay
changed. What landed (tests: `tests/test_combat_events.gd`, `tests/test_combat_locomotion.gd`):
- **K2 profile v3** on every `Weapons.PROFILES` row (`Weapons.FIRE_MODELS`). `kind` stays the mechanical resolver.
  The flamethrower has `damage: 0` (it deals `damage_per_second`); the mortar's `spread_deg` is 0 (it scatters on landing).
- **`Match.weapon_fired(event)`** from shells, beams, arcs, and (every `CONE_EVENT_TICKS` = 6 ticks) flames. Additive
  fields beyond K2: `speed_mps`, `range` (so effects can fly a round without a node).
- **`Match.projectile_impact(event)`** for shells and beams (wall hits too: no `target`, damage 0) and one per arc
  burst. Additive: bursts carry `victims: [{target, face, damage, killed}]`, `target` = the most-hurt victim. Rounds that
  burn out in the air report nothing. Flames report no impacts (kills still come through `tank_destroyed`).
  `weak_spot` is a direct-fire rear hit for now (X3 refines it).
- **`Match.incoming_projectiles(unit)`**: `{position, velocity, eta_ticks, damage_estimate}` plus `projectile_id`,
  `weapon`; soonest first; anyone's rounds but the unit's own; walls ignored (pure geometry).
- **K3 catalog fields** (`Units.LOCOMOTIONS`; all `tracks`, accel = braking = 14, grip 1 for now; X4 changes values) and
  **`TankMotion.predict(state, throttle, turn, ticks)`** with `TankMotion.state_for(unit_id, position, forward, speed)`,
  `state_of(tank)`, `step(...)`, `turn_heading(...)`. Poses: `{position, forward (unit Vector3), speed, velocity}`;
  headings are vectors, not yaw angles. Matches a real tank within 0.3 m over a second on open ground.
- **`Match.orders`** (`var orders: Object = null`): control assigns its `Orders`; tighten the type when it lands.

### X2 done: the weapons rebuilt (2026-09-15)

| Weapon | Round 2 | Round 3 | Why |
|---|---|---|---|
| Tank cannon (shell) | 34 dmg / 2.5 s, 70 m/s | **320 dmg / 5 s, 75 m/s** | Side hit = 63% of a full tank's shield + hull, front 39%, rear 95%; kills in 2 (side, rear) to 4 (front) shells. Measured in `test_combat_weapons.gd` |
| IFV 25 mm (burst) | 9 dmg / 0.35 s | **4 x 15 dmg, 0.12 s apart, every 1.8 s, 180 m/s** | ~33 dps; a started burst is committed |
| Scout MG (stream) | 4 dmg / 0.2 s, spread 1.5° | **3.5 dmg / 0.1 s, spread 2°, hitscan** | 10 rounds/s; hitscan because a node per bullet costs 10 spawns/s per scout and dodging single bullets isn't the counterplay |
| Laser (first pass) | 12 dmg, 16 heat | 28 dmg, 20 heat | keeps the Lancer's job against tanks that now die fast; X6 tunes |
| Flamethrower (first pass) | 20 dps | 55 dps | same ratio to the cannon's new dps; X6 tunes |
| Mortar (first pass) | 90 | 140 | X6 tunes |

Mechanics: weapon timing is in whole ticks (`Tank._reload_ticks`, `_burst_rounds_left`), deterministic; shells fly at
their weapon's `projectile_speed_mps`. Sim baseline re-recorded on purpose (twice on builder0, repeatable):
`glibc-2.43 f63aa6d6ea9545f9`. Tools: `make duel GREEN_UNITS=tank RUST_UNITS=scout,scout` (text timeline from the new
match runner flag `--combat-log`).

**A 1-v-1 tank duel, tick by tick** (`make duel`, seed 3, both advancing on (30, 0)): first shots at 6.9 s from 76 m
(both fire the same tick: today's brains shoot the moment they're loaded and aimed); Green's shell lands 0.8 s later
on Rust's front (176 = shield + 26 hull), Rust's misses. They stop at 38 m and trade every 5.0 s: 11.9 s both hit
fronts; 16.9 s Green's shell catches Rust's side as it turns and kills it (17.4 s). Three volleys, 5 s of dread each,
and the one angled hit decides it. Nobody dodges or circles yet: that's ai X2/X3 reading `incoming_projectiles`.

**Two scouts on a tank** (seed 2): the scouts see the tank at ~80 m and back off to their spotting standoff (ai's
brain); the tank chases at 9 m/s, fires at 10.8 s and 15.8 s at reversing scouts and misses both (leading a
7 m/s target at 50 m), then kills a scout pinned against the north wall with a 220 front hit at 21.4 s. The scouts
never fire: their brain treats them as spotters. Worth a look by ai: a scout reversing into a wall.

Tests adjusted to derive from data (merge notes): `test_combat.gd`, `test_shields.gd`, `test_weapons_and_intel.gd`,
`test_turrets.gd` (expected shots from the reload).

### X3 done: weak spots that read (2026-09-15)

- **Flanks punish through armor** (tested for every direct weapon against tanks and IFVs: front < side < rear). Cannon
  into a tank: ×0.5 / ×1.0 / ×1.5; 25 mm: ×0.05 / ×0.13 / ×0.84; MG: ×0.05 / ×0.13 / ×0.63.
- **The engine deck** (`Armor.is_weak_spot`: a shell or beam arriving within `WEAK_SPOT_ARC_DEG` = 25° of dead astern) is
  armored like half the rear (`Match.weak_spot_multiplier`). Light guns get through there: a scout's stream on a tank's
  engine does ×1.13 per round instead of ×0.63 (measured 1.4×+ the hull damage of the same stream from 37° off the
  quarter). Heavy rounds are already at the cap from behind, so a tank shell on the deck leaves a full tank at 21 hull
  (still two shells). Flagged `weak_spot: true` in `projectile_impact`; `stats.weak_spot_hits` per team.
- Why not a flat damage bonus: at ×1.3 a tank shell into the deck one-shots a full tank, which breaks "2-4 hits" and
  makes a single lucky angle end a duel; thinner armor keeps it mechanical (no damage table) and makes a scout's
  flanking run on a tank's engine a real threat. Tests: `tests/test_combat_weak_spots.gd`.

### X4 done: arcade driving (2026-09-15)

- **One driving model for the sim and the planners:** `Tank` steps its own K3 state through
  `TankMotion.step_in_place` every tick (so `predict` matches a real tank within 0.3 m and a real scout carving a
  turn within 0.5 m over a second), `Basis.looking_at` sets the hull, `move_and_slide` still owns collisions, and the
  slid velocity feeds the next tick (walls eat a car's momentum).
- **Tracks** (the tank): pivot in place at `hull_turn_rate_deg`, accel 10, braking 12 m/s².
- **Wheels** (scout, IFV, artillery, Lancer, Burner): yaw rate = |speed| / turning radius (full lock =
  `min_turn_radius_m`), capped at `hull_turn_rate_deg`; no rotation standing still; momentum split along the new
  heading with `lateral_grip` killing that fraction of sideways slide per tick (scout 0.45 drifts ~1.3 m/s sideways
  through a flat-out full-lock turn; artillery 0.85 carves). Radii: scout 5, IFV 7, Burner 7, Lancer 7.5, artillery 9 m.
- **Decision: `TankCommand.turn` is the direction the hull should yaw, in either gear.** In reverse the wheels steer
  the opposite way to get it (a driver's inverted steering, done for the brain). Why: every brain's
  `Steering.reverse_toward` already swings a reversing hull's back like its front; true inverted input sent scouts
  backing away from a tank into a dithering stall at 65 m (inside cannon range). A player-facing direct drive mode can
  invert for feel later.
- **Decision: a turn command with almost no throttle creeps wheels** (`WHEEL_CREEP_THROTTLE` 0.5 × |turn|, in the
  current direction of travel) along the turning circle instead of stalling, so tank-style "turn in place" steering
  from today's brains becomes a tight arc. ai can plan real multi-point turns with `predict`.
- Tests: `tests/test_combat_locomotion.gd` (yaw = speed/radius, the circle's diameter, no pivot at a standstill, yaw
  intent in reverse, creep, drift vs grip, coasting and braking, predict vs the real scout). Adjusted:
  `test_turrets.gd` (the IFV spins at full throttle: speed buys yaw). Sim baseline re-recorded on purpose:
  `glibc-2.43 67a9f2750b4a7f52`. determinism.md inventory updated.

### X5 done: artillery deploys (2026-09-15)

- `deploy_seconds` 2.5 / `pack_seconds` 2.0 on artillery (optional C1 keys; no other unit has them). A battery whose
  command has no throttle or turn for `Tank.DEPLOY_SETTLE_TICKS` (15) while nearly stopped lowers its legs; it fires
  only at `deploy_ratio` 1 (`Tank.is_deployed()`, also folded into `ready_to_fire()`); any drive command packs it up
  first, and it can't move or fire until packed. Stop-and-go never deploys. The turret still turns while deployed.
- **Why automatic, not an order verb:** today's brains already stop to shell; deploying on a held stop needs no new
  AI or control work, and a player's move order naturally packs it. ai may add explicit "relocate now" logic.
- Slot: `set_deployed(ratio)` every frame on the hull, turret, and weapon visuals of units that deploy
  (slot_contracts.md). Tests: `tests/test_combat_deploy.gd`; the K2 mortar tests now wait for the legs.
- Also found: `tools/remote.sh` picked a stale Xwayland cookie on builder0, so native rendering targets hung. Main's
  7dc7bdc fixes it properly (merged into this branch).

### X6 done (time-boxed): time-to-kill and matrix #5 (2026-09-15)

Full story and tables: balance.md *Round 3: weapons rebuilt and matrix #5*. Short version:
- **Fights resolve in 22-60 s** (matrix #2: 50-130 s); scouts, who spot instead of fighting, still stall.
- **8 of 12 designed counters hold at ≥ 65%** (tank > IFV, IFV > scout, IFV > Lancer 75%, scout > artillery 79%, Burner >
  IFV 67%, Burner > artillery, tank > Burner, Lancer > Burner). **Lancer > tank is 50%**; scout > tank and scout > Lancer
  are 0% (scouts hold a spotting standoff); artillery > tank 0%. Artillery wins nothing alone.
- **Tuned:** laser 22 dmg / 18 heat / 90 m (Lancer sight 90), 25 mm penetration 5, IFV front armor 7, Lancer armor
  3/2/1.5, Burner front 6, tank sight 62, mortar back to 140 (a cliff at 200+ wipes bunched scouts).
- **New tools:** `make matchup-search VARIANTS=tools/matchup_variants/<file>.json [UNITS= SEEDS= ESCORT=]` scores tune
  variants against every unit's good_vs/weak_vs; `make matchups FOCUS= ESCORT=`. Variant files for every round are kept.
- **Deploy revised for today's brains:** a fire command digs a battery in at once (it brakes first), and a drive command
  must persist `PACK_SETTLE_TICKS` (0.5 s) to pack it; `ready_to_fire()` no longer includes deployment (a brain asks a
  packed battery to fire). Before this, ai's BOMBARD kept nudging its range and artillery never fired.
- Stopped at the 90-minute time-box: outcomes swing ±15% between neighbouring numbers because brains react to them
  (more tank shield and a slower tank both *lowered* Lancer > tank). The next lever is behavior (ai X2/X3).
- Sim baseline re-recorded on purpose: `glibc-2.43 79fd0387fc497327`.

### Stretch done: `Match.unit_destroyed(event)` for wrecks (2026-09-15)

`{tick, unit, unit_id, team, killer, cause ("enemy" | "friendly_fire" | "hazard"), position, forward, hull_size}`, emitted
right after `tank_destroyed` for every destruction (one `_announce_destroyed` path). For feel (explosions, wreck
effects), assets (wreck art sized to `hull_size`), and the announcer. **Wreck husks as cover are not built**: a husk that
blocks shells but not the navmesh strands units, and one that blocks both needs runtime navmesh carving; proposal below.

### X7 done (measured; the default flip is control's): match defaults (2026-09-15)

`make pace [CONTROL=1]` (new): seeded CPU vs CPU armies at the skirmish budget (1000), elimination, 10 matches each on
builder0.

| Rules | First shot (median) | First kill (median) | Length: median (p25-p75) | Ends by |
|---|---|---|---|---|
| Elimination only | 5.7 s | 11.6 s | 54 s (42-83) | elimination 10 |
| + control point | 5.5 s | 11.8 s | **92 s (54-113)** | elimination 7, control 3 |

**Recommendation:** control point on by default (the lead already agreed). With the new time-to-kill, elimination alone
ends most fights in under a minute; the point keeps a match to ~1.5 minutes, gives a losing side a path back, and makes
3 of 10 matches about holding ground instead of the last kill. First contact within ~6 s of the battle starting (after
the skirmish's planning pause) feels right for arcade-tactical; no change to `CONTROL_POINTS_TO_WIN` (90) yet.
**Request to control (owner of `game/modes/skirmish_mode.gd`):** make `game_match.control_point` default to true
(`--no-control` to turn it off). One line; I haven't touched the file.

## Report (combat stream, round 3, 2026-09-15)

**Done:** X1 (CP2), X2, X3, X4, X5, X6 (time-boxed at 8/12 counters), X7 (measured; the flag flip is a request to
control), stretch `unit_destroyed`. Every step green on `make remote T=check`; last sim baseline
`glibc-2.43 79fd0387fc497327`.

### Decisions (with reasons, in the sections above)
- Hitscan MG and beams; projectile shells and 25 mm rounds (spawn cost, dodging counterplay).
- Weapon timing in whole ticks; a started burst is committed.
- Weak spot = engine deck through half the rear armor, not a flat damage bonus (keeps tank shells a 2-hit kill).
- `TankCommand.turn` = the hull's yaw direction in either gear; wheels creep along the circle on a bare turn command.
- Artillery deploys automatically: a fire command digs in; a drive command held 0.5 s packs up.
- Laser range/strength sits on a knife edge between IFV > Lancer and Lancer > tank; IFV front armor and tank sight
  were the levers that move one edge only.

### Questions for the lead
1. **Scouts as fighters:** matrix #5 has scouts beating only artillery (they hold a spotting standoff, per your
   "spotters more than fighters"). `Units.PROFILES.scout.good_vs` still lists the Lancer. Keep scouts as pure
   spotters (and drop Lancer from good_vs), or should ai give them attack runs on light units and exposed rears?
2. **Artillery's role:** it's a support unit that wins nothing alone or spotted (a stronger mortar wipes scouts, its
   one counter). Is that acceptable for now, or should it get a mechanic (e.g. a bigger minimum range but a slow
   shell that ignores cover) in a later round?
3. **Boost / ram (stretch, pillar-level, not built):** proposed a short nitro boost on wheels (1.5 s at +40% speed and
   half grip, 8 s cooldown) and ram damage scaled by mass × closing speed (tanks and Burners best). It would give
   scouts and IFVs a way to break a tank's firing solution and to finish attack runs. Build it next round?
4. **Wreck husks as cover (stretch, not built):** husks that block shells and sight need runtime navmesh carving or
   units strand on them. Want them (a later round, with ai), or keep wrecks visual only (the `unit_destroyed` event)?

### Requests to other streams
- **ai:** (a) read `Match.incoming_projectiles` to dodge tank shells (a 5 s reload makes every dodge count; the duel
  timeline shows tanks trading from a standstill). (b) Use `Armor.is_weak_spot` / `Match.weak_spot_multiplier` to seek
  engine-deck angles (a scout's stream there does ×1.13 instead of ×0.05 on the front). (c) Wheeled units: plan with
  `TankMotion.predict`; `Steering` still assumes pivots (the creep assist hides it). (d) Artillery BOMBARD: stop and fire
  rather than nudging range every tick (a fire command now deploys it). (e) `matchups.gd` mirrors the penetration
  curve: add the engine deck, and note burst weapons (`burst_count` × `damage` per `reload_s`). (f) A lone unit with no
  objective drives straight at the enemy base through the center crate's shadow on point-symmetric arenas: two lone
  tanks passed each other at 9 m unseen (`make duel` works around it with objectives). (g) Minimal edits I made in
  your paths: `order_controller.gd` and `fire_lanes.gd` lead with the weapon's `projectile_speed_mps`;
  `tests/ai_scenarios/scenario_cover.gd` gives the hurt tank a hull that survives one volley.
- **control:** skirmish `control_point` default on (X7). `Match.orders` exists (`Object`, assign your `Orders`).
  (The `army-loop-smoke` triangulation flake I patched is fixed properly on main, 8dbe23e; merged, my guard dropped.)
- **feel:** K2 events carry `speed_mps` and `range` (fly rounds without nodes); arc bursts carry `victims`; flames emit
  `weapon_fired` every 6 ticks and no impacts; `unit_destroyed` has the wreck transform; artillery visuals get
  `set_deployed(ratio)`; wheeled units drift (`lateral_grip`, velocity vs heading) for tire marks.
- **assets:** `set_deployed(ratio 0..1)` on artillery hull, turret, and weapon (slot_contracts.md); wreck art can size
  to `unit_destroyed.hull_size`.
- **orchestrator:** fold K2 additive fields (`speed_mps`, `range`, `victims`, `unit_destroyed`) and K3's "turn = yaw
  direction in either gear" into workstreams.md; `tools/remote.sh`'s Xwayland fix: superseded by main's 7dc7bdc (merged; the running
  Xwayland's auth file), so no merge note remains for it.

### Known issues
- **Blocking `make check` since merging main's 8dbe23e (not combat code):** main's new
  `test_command_icons::test_unit_icons_skip_positions_a_camera_could_not_project` fails deterministically on builder0
  ("a collinear triangle is not drawn"); `game/ui/` and that test are identical to main. Reported to the orchestrator.
  The last green combat commit is d921ffb/26f2476 (full check), and 887e18e (merge of 7dc7bdc) was green too.
- Lancer > tank is a coin flip (50%); scouts win only vs artillery; artillery wins nothing (see questions).
- `make skirmish-shots` at 35 s wall clock on builder0 rarely catches a shell in flight at that zoom; the timelines
  (`make duel`) are the reliable evidence for shells, bursts, and streams.
- Balance samples are 12 per pair (±14 points); brains react to numbers, so neighbouring values swing ±15%.

### What to playtest (exact commands)
- `make skirmish` then fight: tanks should feel slow and heavy-hitting (5 s between shells, a flank shot guts a tank),
  IFVs rattle 4-round bursts, scouts stream tracers only where the hood points, wheeled units swing wide and slide.
- `make watch-match GREEN_DOCTRINE=anvil_hammer RUST_DOCTRINE=flame_rush` to watch driving and deploying artillery.
- Text: `make remote T="duel GREEN_UNITS=tank RUST_UNITS=tank"`, `… GREEN_UNITS=scout,scout RUST_UNITS=tank`.

### Next steps
- Behavior before stats: once ai dodges and flanks, re-run `make matchups` and `make matchup-search` (variant files in
  `tools/matchup_variants/`). Then the lead's answers on scouts, artillery, boost/ram, and husks.

### Merge notes (edits outside combat's paths)
- `game/ai/order_controller.gd`, `game/ai/fire_lanes.gd` (lead speed), `tests/ai_scenarios/scenario_cover.gd` (ai).
- `_agents/slot_contracts.md` (shared, additive): `set_deployed`. `_agents/determinism.md` inventory rows.
  `_agents/verification.md` row 6i.
- Round-2 tests now derive from data: `tests/test_combat.gd`, `test_shields.gd`, `test_weapons_and_intel.gd`,
  `test_turrets.gd`.

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

- 2026-09-15: brief written for round 3. Nothing started.

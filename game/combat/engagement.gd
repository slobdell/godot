class_name Engagement
extends RefCounted
## N5 (round 6, CP4): THE ENGAGEMENT ENVELOPE. Seeing an enemy is not the same as opening fire.
##
## The lead, twice (round 5 and round 6): *"The long range of the weapons is also I think making the game unplayable
## (units see each other and then everyone just starts firing)."* The mechanism behind that sentence was one line:
## `OrderController._shootable()` admitted any enemy inside the weapon's range with a clear physics line, and
## `effective_range == range` for every weapon, so there was no distance at which a shot was legal but bad. First
## contact was the whole fight.
##
## Three gates now stand between "there is an enemy over there" and "the gun speaks":
##
##   1. SIGHT        the contact must be SEEN — by this crew (its own `sight_radius`) or handed to it by the team's
##                   shared intel (`spotter`, which is `Match.is_visible_to`). A gun may not reach past the eyes that
##                   aim it. This is the `seen` test that round 5 found computed-and-discarded, put back deliberately.
##   2. ACQUISITION  the crew must hold the contact for `acquire_seconds` before the first round leaves the barrel.
##                   Switching target restarts it, so swinging onto a new contact COSTS TIME; distance costs more,
##                   and so does being under fire. Losing the contact bleeds the lay away rather than wiping it, so
##                   a target that ducks behind a crate for a moment does not have to be found from scratch.
##   3. DISCIPLINE   a round fired beyond the weapon's EFFECTIVE range is legal but bad (`Match.range_spread_multiplier`
##                   widens it toward `RANGE_SPREAD_FACTOR` at maximum range), so a unit HOLDS FIRE until it is inside
##                   the band. Two exceptions, both deliberate: a commander who designates a target by name has
##                   overridden the crew's judgement, and a crew already being shot at may answer at any range it can
##                   reach. Nothing else buys a long shot.
##
## Gate 3 is the one the player feels: it turns "closing" from something the AI happens to do into the thing that
## starts the fight. Gates 1 and 2 are what stop a horde opening up the instant the first hull clears a corner.
##
## Deliberate non-coverage: ARC weapons (mortar, catapult, gas rockets, guided missiles) go through
## `OrderController._apply_indirect`, which ALREADY requires a spotter and a [min_range, range] window — indirect fire
## is spotted fire by construction, and its reach is its job. `suppress` orders (L2: fire at a piece of ground) are
## also untouched: putting rounds on a lane nobody is standing in is a deliberate order, not a target of opportunity.


## Acquisition time (seconds of continuous lay) at zero range and at the edge of the crew's own sight. A contact at
## arm's length is on the reticle almost at once; one at the limit of vision takes a beat to resolve into a target.
const ACQUIRE_NEAR_SECONDS := 0.3
const ACQUIRE_FAR_SECONDS := 1.6
## A suppressed crew acquires more slowly: at full suppression it takes this much longer. Heads down, nobody is
## calling the range. (L2 already costs them accuracy and sight; this is the third bite.)
const SUPPRESSION_ACQUIRE_PENALTY := 1.0
## Scouts are spotters first (the lead, round 4): finding things is their job, so they resolve a contact in this
## fraction of the time anyone else needs. This is also one of the two mechanics behind `scout > lancer` (X6).
const SCOUT_ACQUIRE_SCALE := 0.55
## X6: a contact CROSSING the gunner's field is harder to lay on than one coming straight at him. At
## CROSSING_REFERENCE_RATE of angular movement acquisition takes (1 + CROSSING_ACQUIRE_PENALTY) times as long, scaling
## linearly and capped at CROSSING_ACQUIRE_MAX so a contact hugging the hull is not unlayable.
##
## This is the mechanic `scout > lancer` never had. The roster has claimed `lancer.weak_vs = ["scout"]` since round 2
## with nothing behind it: a Lancer's laser reaches 90 m, a scout's machine gun 45, so on paper the scout dies on the
## way in. Angular rate is what actually decides that duel, and it is pure geometry — a 14 m/s scout at 86 m crosses
## at 9.3 deg/s and takes a Lancer about 2.25 s to acquire instead of 1.54 s, which is 31 m of closing bought by
## moving across rather than at him.
##
## The part that makes it a good rule rather than a patch: it pays for the RIGHT behaviour. A scout that charges
## straight down the sight line has almost no crossing rate and gets no protection at all; a scout that circles is
## hard to hit. That is the attack run the unit is supposed to make, rewarded by the mechanic instead of by a number
## in a table. It applies to every gun equally — a tank crossing an IFV's front is just as hard to lay on.
const CROSSING_ACQUIRE_PENALTY := 1.0
const CROSSING_REFERENCE_RATE := 0.349  # rad/s (20 deg/s)
const CROSSING_ACQUIRE_MAX := 2.0
## When the contact is lost, the lay bleeds off at this fraction of the rate it built up, so ducking behind cover for
## a moment does not send the gunner back to the start.
const LOST_LAY_DECAY := 0.5
## Once a unit IS firing at a target, it keeps firing out to this multiple of its effective range: a target drifting a
## metre past the band must not make the gun stutter on and off.
const RELEASE_FACTOR := 1.12
## Crew suppression at or above which a unit is "being shot at" and may answer at any range it can reach.
## `Match.SUPPRESSION_FULL_DENSITY` worth of fire is a pin; a quarter of it is unmistakably incoming.
const RETURN_FIRE_SUPPRESSION := 0.25

## Measurement switch (`--no-acquisition`, match runner only): disables gates 1 and 2 so a series can isolate what
## DISCIPLINE alone is worth. Never set in normal play; gate 3 is switched off instead by tuning a weapon's
## `effective_range` up to its `range`, which is exactly the world before this contract.
static var acquisition_enabled := true

## Measurement switch (`--no-crossing`, match runner only): drops X6's crossing penalty while leaving the rest of
## acquisition alone. `--no-acquisition` would switch off gates 1 and 2 *and* X6 together, which cannot tell "a
## contact takes time to resolve" from "a contact that is moving across takes longer" — and those two are worth
## separating, because stacking N5's discipline on X6's crossing penalty is the one combination that could make
## fights too QUIET rather than too loud. Never set in normal play.
static var crossing_enabled := true

## Measurement only: how many ticks a gun with a target in front of it was held by each gate. Never read by decisions.
static var held_by_acquisition := 0
static var held_by_discipline := 0


static func reset_counters() -> void:
	held_by_acquisition = 0
	held_by_discipline = 0


## Gate 1. Does this crew know the contact is there? The team's shared intel when it has a spotter (which is every
## unit under a brain or a player order: `Match.is_visible_to`), else its own eyes.
## Note the ordering at the call site: this is a dictionary lookup and belongs BEFORE the line-of-sight raycast.
static func is_seen(tank: Tank, enemy: Tank, spotter: Callable) -> bool:
	if not acquisition_enabled:
		return true
	if spotter.is_valid():
		return bool(spotter.call(enemy))
	return tank.global_position.distance_to(enemy.global_position) <= tank.sight_radius


## X6: how fast `target` crosses `tank`'s field, in radians per second — the component of its velocity perpendicular
## to the line of sight, over the range. Pure geometry: the same speed is a hard track up close and a slow drift far
## away. The shooter's own motion is deliberately ignored; the target's crossing is the dominant term and a rule a
## player has to predict should be simple.
static func crossing_rate(tank: Tank, target: Tank, distance: float) -> float:
	if distance <= 0.5:
		return 0.0
	var sight_line := target.global_position - tank.global_position
	sight_line.y = 0.0
	if sight_line.length_squared() <= 0.0:
		return 0.0
	sight_line = sight_line.normalized()
	var velocity := target.estimated_velocity
	velocity.y = 0.0
	return (velocity - sight_line * velocity.dot(sight_line)).length() / distance


## Gate 2's cost: how long this crew must hold THIS contact at THIS range before it may shoot at it.
static func acquire_seconds(tank: Tank, target: Tank, distance: float) -> float:
	var sight := maxf(tank.sight_radius, 1.0)
	var reach := clampf(distance / sight, 0.0, 1.0)
	var seconds := lerpf(ACQUIRE_NEAR_SECONDS, ACQUIRE_FAR_SECONDS, reach)
	seconds *= 1.0 + SUPPRESSION_ACQUIRE_PENALTY * clampf(tank.suppression, 0.0, 1.0)
	if target != null and crossing_enabled:
		var crossing := crossing_rate(tank, target, distance) / CROSSING_REFERENCE_RATE
		seconds *= 1.0 + CROSSING_ACQUIRE_PENALTY * clampf(crossing, 0.0, CROSSING_ACQUIRE_MAX)
	if Units.role_of(tank.unit_id) == "scout":
		seconds *= SCOUT_ACQUIRE_SCALE
	return seconds


## Gate 3's threshold: the range inside which this weapon's fire is worth the round. Weapons without an
## `effective_range` (cones, arcs) are disciplined by their own short reach or their spotter instead.
static func effective_range(weapon: Dictionary) -> float:
	var reach := float(weapon.get("range", 0.0))
	return float(weapon.get("effective_range", reach))


## The band an ORDINARY defender covers: the number any "can this approach be covered" metric should use instead of a
## hard-coded watcher range. (arena's `exposure()` used 110 m, which was a weapon-range assumption wearing a
## sightline's clothes.) It is the MEDIAN over every unit in every roster of `min(effective_range, sight_radius)` — a
## defender has to both SEE the target and be worth fearing at that distance, and the smaller of the two is what it
## actually covers.
##
## Median, not mean, and deliberately so: the two long-range archetypes (the Lancer's laser at 86 m, the Syndicate's
## railgun at 104 m) exist precisely to out-reach a tank, and averaging them into the line units they are designed to
## beat would invent a defender nobody fields. If you need "deniable by a long-range archetype", ask for those
## weapons' bands separately rather than moving this number.
##
## Derived from the data on purpose, so it cannot go stale the next time a band moves. Callers should call it rather
## than copy today's answer into a constant.
##
## One caveat that must travel with any number built on this: an order carrying `long_shot` reaches the weapon's FULL
## range, so an approach outside this radius is safe from units using their own judgement, not safe absolutely. That
## is the intended design — an ambush should be beatable by a commander who spends the order.
static func covering_range() -> float:
	var covered: Array[float] = []
	for unit_id: String in Units.PROFILES:
		var weapon := Weapons.profile(String(Units.PROFILES[unit_id].get("weapon", "")))
		if not weapon.has("effective_range"):
			continue
		covered.append(minf(effective_range(weapon), float(Units.stat(unit_id, "sight_radius", 0.0))))
	if covered.is_empty():
		return 0.0
	covered.sort()  # sorted, so the answer never depends on the catalog's declaration order
	var mid := covered.size() / 2
	return covered[mid] if covered.size() % 2 == 1 else (covered[mid - 1] + covered[mid]) / 2.0


## The tracked lay of ONE gun on ONE contact. The order controller keeps one of these per unit; it is two floats and a
## name, and it is updated from the target the weapon scan already picked, so it costs no extra raycast.
class Lay extends RefCounted:
	## The contact being laid on ("" = none).
	var target := ""
	## Seconds of continuous lay on `target`.
	var progress := 0.0
	## True while this gun is already engaging `target` (gate 3's hysteresis).
	var firing := false

	func forget() -> void:
		target = ""
		progress = 0.0
		firing = false

	## Called on a tick where there is nothing to shoot at: the lay bleeds off but the contact is remembered, so a
	## target that breaks line of sight for a moment is re-acquired from where the gunner left it.
	func lose(seconds: float) -> void:
		firing = false
		progress = maxf(0.0, progress - seconds * Engagement.LOST_LAY_DECAY)

	## Gates 2 and 3, on the target the weapon scan picked (which has already passed gate 1 and the line of sight).
	## `ordered` = a commander named this target, which overrides the crew's judgement about range.
	## Returns whether the trigger may be pulled this tick.
	func engage(tank: Tank, contact: Tank, distance: float, seconds: float, ordered: bool) -> bool:
		var target_name := String(contact.name) if contact != null else ""
		if target_name != target:
			target = target_name
			progress = 0.0
			firing = false
		if not Engagement.acquisition_enabled:
			progress = INF
		else:
			var needed := Engagement.acquire_seconds(tank, contact, distance)
			progress = minf(progress + seconds, needed)
			if progress < needed:
				firing = false
				Engagement.held_by_acquisition += 1
				return false
		var limit := Engagement.effective_range(tank.weapon)
		if ordered or tank.suppression >= Engagement.RETURN_FIRE_SUPPRESSION:
			limit = float(tank.weapon.get("range", limit))
		elif firing:
			limit *= Engagement.RELEASE_FACTOR
		firing = distance <= limit
		if not firing:
			Engagement.held_by_discipline += 1
		return firing

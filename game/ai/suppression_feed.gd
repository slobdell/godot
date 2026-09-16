class_name SuppressionFeed
extends RefCounted
## How brains read suppression and effective fire: contract L2 in _agents/workstreams.md, shipped by combat at CP2 —
## `Tank.suppression` / `Tank.is_pinned()`, `Match.is_beaten_zone(team, from, to)`, `Match.threat_along(team, from, to)`,
## `Match.threat_field(team)` and `Weapons.suppression(weapon)`. Round-4 ai X3, _agents/unit_ai.md "Suppression".
##
## The lead: *"vehicles make decisions to avoid walking into a wall of bullets that will kill them, and opposing forces
## could concentrate their fire power to create those suppressive fire effects or cut off an avenue."* So a brain uses
## this for three things: don't drive through a beaten zone, break contact when it is pinned, and put rounds on an
## enemy to hold it down even when it can't kill it.
##
## Duck-typed like OrderFeed and ElementFeed, and every reader has a defined answer when the match doesn't answer L2
## (an old save, a hand-built test situation, a scenario with a stub): no suppression, no beaten zones, and then a
## brain behaves exactly as it did before suppression existed.

## Suppression this high is worth breaking contact for even before `is_pinned()`, if the hull is worn too.
const HEAVY := 0.4
## Threat density (ThreatField units) that makes a route worth going round rather than through. Match's own
## BEATEN_ZONE_DENSITY is the "a machine gun is working this ground" line; this is the softer "prefer not to".
const AVOID_DENSITY := 0.5
## A weapon that puts at least this much suppression on the ground per round is worth firing to pin rather than kill.
const SUPPRESSING_WEAPON := 0.05


## The object that answers L2: the match, or an object attached with attach() (tests). null when nothing answers.
static func source(game_match: Object) -> Object:
	if game_match == null:
		return null
	if game_match.has_meta("suppression"):
		var attached: Variant = game_match.get_meta("suppression")
		if attached is Object and is_instance_valid(attached):
			return attached
	if game_match.has_method("is_beaten_zone") or game_match.has_method("threat_field"):
		return game_match
	return null


## Answer L2 for this match's brains from `fields` instead (tests and hand-built situations).
static func attach(game_match: Object, fields: Object) -> void:
	game_match.set_meta("suppression", fields)


## How suppressed a unit's crew is, 0..1 (0 when the unit doesn't carry it).
static func of(unit: Object) -> float:
	if unit == null or not ("suppression" in unit):
		return 0.0
	return clampf(float(unit.get("suppression")), 0.0, 1.0)


## Is this unit pinned — its own fire ineffective, so the right answer is to get out rather than trade?
static func is_pinned(unit: Object) -> bool:
	if unit == null:
		return false
	if unit.has_method("is_pinned"):
		return bool(unit.call("is_pinned"))
	return of(unit) >= Tank.PINNED_SUPPRESSION


## Would going from `from` to `to` take a unit of `team` through a wall of bullets? False when nothing answers L2.
static func beaten(fields: Object, team: int, from: Vector3, to: Vector3) -> bool:
	if fields == null or not fields.has_method("is_beaten_zone"):
		return false
	return bool(fields.call("is_beaten_zone", team, from, to))


## How exposed a route is for `team` on average, 0 = clear: for scoring one route against another.
static func along(fields: Object, team: int, from: Vector3, to: Vector3) -> float:
	if fields == null or not fields.has_method("threat_along"):
		return 0.0
	return maxf(float(fields.call("threat_along", team, from, to)), 0.0)


## Incoming-fire density at one point for `team`, 0 when there is no field.
static func density(fields: Object, team: int, point: Vector3) -> float:
	var field := field_for(fields, team)
	if field == null:
		return 0.0
	if field is Object and (field as Object).has_method("at"):
		return maxf(float((field as Object).call("at", point)), 0.0)
	if field is Callable:
		return maxf(float((field as Callable).call(point)), 0.0)
	return 0.0


static func field_for(fields: Object, team: int) -> Variant:
	if fields == null or not fields.has_method("threat_field"):
		return null
	var field: Variant = fields.call("threat_field", team)
	if field is Object and not is_instance_valid(field as Object):
		return null
	return field


## How much suppression this weapon lays on the ground per round. What makes fire *suppressive* is volume and noise,
## not damage: a machine gun's stream holds a crew's head down, a cannon's shell every 5 s does not.
static func weapon_suppression(weapon: Dictionary) -> float:
	if weapon.has("suppression"):
		return maxf(float(weapon["suppression"]), 0.0)
	# Before CP2 the profiles had no such field: rounds per reload stands in for volume.
	var reload := maxf(float(weapon.get("reload", 1.0)), 0.05)
	return maxf(float(weapon.get("burst_count", 1)), 1.0) / reload * 0.01


## Is this a weapon worth firing to pin an enemy it probably can't kill?
static func suppresses(weapon: Dictionary) -> bool:
	return weapon_suppression(weapon) >= SUPPRESSING_WEAPON

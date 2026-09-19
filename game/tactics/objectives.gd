class_name Objectives
extends RefCounted
## Where the fight's objective is, for squad's deciders: ONE seam over the match's control point. Today Match knows a
## single central zone (Match.CONTROL_CENTER, a static in_control_zone); combat's N7 makes objectives arena data, read
## per match (in_any_objective / objective_presence). Until N7 is on main, every decider in squad's paths asks here and
## this answers from the central zone — and REFUSES, loudly, when the arena declares an objective that is not that zone
## (a position off the centre, or more than one): a CPU competing for the wrong ground looks completely functional, so a
## silent wrong answer is the failure to prevent (lesson 77: prefer a loud break when you deprecate).
## When N7 lands: re-implement center()/contains()/owner() on the instance API; the call sites do not change.
##
## Callers: CpuCommander (muster objective, holding the zone), ElementCommander._objective, TankBrain's situation
## ("control"), DiscoveryBridge's state.


## Whether this match has an objective at all.
static func active(game_match: Match) -> bool:
	return game_match != null and game_match.control_point


## The objective's centre.
static func center(game_match: Match) -> Vector3:
	_guard()
	return Match.CONTROL_CENTER


static func radius(game_match: Match) -> float:
	_guard()
	return float(Arena.active.get("control_point", {}).get("radius", Match.CONTROL_RADIUS)) \
			if Arena.active.get("control_point") is Dictionary else Match.CONTROL_RADIUS


static func contains(game_match: Match, point: Vector3) -> bool:
	_guard()
	return Match.in_control_zone(point)


## Which team holds it (Match.control_owner).
static func owner(game_match: Match) -> int:
	return game_match.control_owner


## The guard: this seam only knows the single central zone. A layout that places its objective anywhere else, or has
## several, gets an error instead of a plausible wrong answer.
static func _guard() -> void:
	if not describes_central_zone(Arena.active):
		push_error("Objectives: the arena declares an objective other than the single central zone; squad's deciders " \
				+ "still read Match.CONTROL_CENTER. Move game/tactics/objectives.gd onto N7's instance API.")


## Whether a layout's objective is (at most) one zone at the arena's centre.
static func describes_central_zone(layout: Dictionary) -> bool:
	if layout.has("objectives") and (layout["objectives"] as Array).size() > 1:
		return false
	var declared: Variant = layout.get("objectives", [layout.get("control_point")])[0] if layout.has("objectives") \
			else layout.get("control_point")
	if not declared is Dictionary:
		return true
	var at: Variant = (declared as Dictionary).get("position")
	if at == null:
		return true
	return Vector2(float(at[0]) - Match.CONTROL_CENTER.x, float(at[1]) - Match.CONTROL_CENTER.z).length() < 0.5

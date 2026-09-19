class_name Objectives
extends RefCounted
## Where the fight's objectives are, for squad's deciders: ONE seam over the match's objectives (combat's N7:
## `Match.objectives`, read per match from the layout, `[{name, position, radius, owner, progress}]`). A layout may
## declare several (off-centre ones come in mirrored pairs), so a decider never asks "where is THE objective": it asks
## which one to go for from where it stands (`goal`), whether a point is on one (`contains`, `held_at`), and whether its
## team holds them all (`all_held`).
##
## Round 7: this file answered from the single central zone (the Match constant) until N7 reached main, behind a guard
## that push_errored on any other layout. arena's first above-zero maps (yard, pit) tripped it 35,336 times in one match
## that still COMPLETED with a winner — the deciders competed for the wrong ground the whole time (lesson 122: degraded
## is worse than fatal). Nothing here reads the central-zone constant any more.
##
## Callers: CpuCommander (muster objective, holding the zone), ElementCommander._objective, TankBrain's situation
## ("control"), DiscoveryBridge's state.


## Whether this match has objectives at all (the --control match flag; N7 then always has at least one).
static func active(game_match: Match) -> bool:
	return game_match != null and game_match.control_point and not game_match.objectives.is_empty()


## Every objective, live (Match's own dictionaries: read them, never write them).
static func all(game_match: Match) -> Array:
	return game_match.objectives if active(game_match) else []


## The objective `team` should go for from `from`: the nearest one it does not hold; if it holds them all, the nearest
## (to stay on). Ties go to the earlier-listed one, so the answer is deterministic. {} when there are none.
static func goal(game_match: Match, team: int, from: Vector3) -> Dictionary:
	var best := {}
	var best_d := INF
	var best_held := true
	for objective: Dictionary in all(game_match):
		var held := int(objective["owner"]) == team
		var d := _flat_distance(from, objective["position"])
		if (best_held and not held) or (held == best_held and d < best_d - 0.001):
			best = objective
			best_d = d
			best_held = held
	return best


## Whether `point` is inside any objective.
static func contains(game_match: Match, point: Vector3) -> bool:
	return not _containing(game_match, point).is_empty()


## Whether `point` is inside an objective `team` holds (a place worth holding rather than leaving).
static func held_at(game_match: Match, team: int, point: Vector3) -> bool:
	var objective := _containing(game_match, point)
	return not objective.is_empty() and int(objective["owner"]) == team


## Whether `team` holds every objective (nothing left to take).
static func all_held(game_match: Match, team: int) -> bool:
	for objective: Dictionary in all(game_match):
		if int(objective["owner"]) != team:
			return false
	return active(game_match)


## The (first) objective whose zone holds `point`, or {}.
static func _containing(game_match: Match, point: Vector3) -> Dictionary:
	for objective: Dictionary in all(game_match):
		if _flat_distance(point, objective["position"]) <= float(objective["radius"]):
			return objective
	return {}


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

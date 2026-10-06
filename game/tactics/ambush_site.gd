class_name AmbushSite
extends RefCounted
## Round 18 (brains B4/B5): where an element can lie in ambush on the enemy's way in. Pure over a CoverMap and positions,
## so the commander's choice has a unit test. The lead's map item: a centre where *"a line abreast formation could get
## ambushed by another formation that was orthogonal"*; the CPU never set one (ElementCommander gave no ambush task).
##
##   AmbushSite.find(cover, element_center, enemy_center, objective, reach_m) -> {"spot", "zone", "lateral", "along"} or {}
##
## The enemy is taken to come straight from where it is now to our objective (its APPROACH). A SPOT is one of the
## CoverMap's tactical points (beside a feature) that is:
##   - within REACH_M of the element (150 m: from the CPU's spawn the bays are ~110 m away; the commander's in-time rule
##     decides whether it can get there first),
##   - on the approach's flank: ALONG_MIN..ALONG_MAX of the way from the enemy to the objective, LATERAL_MIN_M..
##     `reach_m` (the element's guns' range) to one side of it: fire from the side, not head-on,
##   - hidden from the enemy where it is now, with a clear line to its KILL ZONE (the approach point level with it),
##   - beside OPEN ground: no tactical point within OPEN_M of the kill zone (nothing there for the enemy to hide behind).
## The nearest such spot to the element wins (ties by position, so the answer never depends on iteration order).

const REACH_M := 150.0
const ALONG_MIN := 0.25
const ALONG_MAX := 1.0
const LATERAL_MIN_M := 25.0
const OPEN_M := 12.0
const MIN_APPROACH_M := 60.0


static func find(cover: CoverMap, element_center: Vector3, enemy_center: Vector3, objective: Vector3,
		reach_m: float) -> Dictionary:
	if cover == null:
		return {}
	var enemy := Vector2(enemy_center.x, enemy_center.z)
	var goal := Vector2(objective.x, objective.z)
	var length := enemy.distance_to(goal)
	if length < MIN_APPROACH_M:
		return {}
	var along_dir := (goal - enemy) / length
	var best := {}
	var best_key := []
	# Round 19 (B3): unsorted and early-exit queries (the best spot is chosen by a full key below, so the order the
	# candidates come in never changes the answer; test_tactics_ambush_site proves it against the sorted search).
	for index: int in cover.points_within(Vector2(element_center.x, element_center.z), REACH_M):
		var point: Vector2 = cover.points[index]
		var rel := point - enemy
		var along := rel.dot(along_dir)
		var t := along / length
		if t < ALONG_MIN or t > ALONG_MAX:
			continue
		var lateral := (rel - along_dir * along).length()
		if lateral < LATERAL_MIN_M or lateral > reach_m:
			continue
		var zone := enemy + along_dir * along
		var spot3 := Vector3(point.x, 0.0, point.y)
		var zone3 := Vector3(zone.x, 0.0, zone.y)
		if cover.any_point_within(zone, OPEN_M):
			continue
		if cover.clear_line(enemy_center, spot3) or not cover.clear_line(spot3, zone3):
			continue
		var key := [snappedf(Vector2(element_center.x, element_center.z).distance_to(point), 0.01), point.x, point.y]
		if best.is_empty() or key < best_key:
			best_key = key
			best = {"spot": spot3, "zone": zone3, "lateral": lateral, "along": t}
	return best

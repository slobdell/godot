class_name Perception
extends RefCounted
## What a tank can know about other tanks. Today every peer holds every tank's
## position, so these are pure queries. Fog of war will later restrict what
## clients receive; AI and the agent bridge must only ever use these helpers.

## Physics layer 1 = static world (ground, walls, crates). Tanks are layer 2.
const WORLD_MASK := 1
## Sight lines run at roughly turret height, so crates block them but the ground doesn't.
const EYE_HEIGHT := 1.3


## True if no static world geometry blocks the line between the two tanks.
## Must be called during physics processing (or when physics isn't stepping).
## Round 16 (A2): with the detailed profile on (ai-perf DETAIL=1, or --sim-profile) every call is the part "los.ray"
## (calls per tick = rays per tick, the brains' and the match's together: the match's intel calls this too).
static func has_line_of_sight(viewer: Node3D, target: Node3D) -> bool:
	var started := Time.get_ticks_usec() if OrderController.profile_detail else 0
	var space := viewer.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
			viewer.global_position + Vector3.UP * EYE_HEIGHT,
			target.global_position + Vector3.UP * EYE_HEIGHT, WORLD_MASK)
	var clear := space.intersect_ray(query).is_empty()
	if OrderController.profile_detail:
		OrderController.add_part("los.ray", Time.get_ticks_usec() - started)
		_count_repeat(query.from, query.to)
	return clear


## Measurement only (round 16, A3's question before its answer): how many rays in a physics frame ask a line that was
## already asked in the same frame, at bit-identical ends ("los.ray_repeat"). That is the most an exact memo could save.
static var _seen_frame := -1
static var _seen := {}


static func _count_repeat(from: Vector3, to: Vector3) -> void:
	var frame := Engine.get_physics_frames()
	if frame != _seen_frame:
		_seen_frame = frame
		_seen.clear()
	var key := [from, to] if from.x < to.x or (from.x == to.x and from.z <= to.z) else [to, from]
	if _seen.has(key):
		OrderController.add_part("los.ray_repeat", 0)
	else:
		_seen[key] = true


## Living tanks on a different team than `tank`.
static func enemies_of(tank: Tank, tanks_root: Node) -> Array[Tank]:
	var enemies: Array[Tank] = []
	for node in tanks_root.get_children():
		var other := node as Tank
		if other != null and other != tank and other.is_alive() and other.team != tank.team:
			enemies.append(other)
	return enemies


## The closest enemy, optionally only among those in sight and within range.
static func nearest_enemy(tank: Tank, tanks_root: Node, require_visible: bool,
		max_range: float = INF) -> Tank:
	var best: Tank = null
	var best_distance := max_range
	for enemy in enemies_of(tank, tanks_root):
		var distance := tank.global_position.distance_to(enemy.global_position)
		if distance > best_distance:
			continue
		if require_visible and not has_line_of_sight(tank, enemy):
			continue
		best = enemy
		best_distance = distance
	return best

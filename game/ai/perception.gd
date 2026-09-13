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
static func has_line_of_sight(viewer: Node3D, target: Node3D) -> bool:
	var space := viewer.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
			viewer.global_position + Vector3.UP * EYE_HEIGHT,
			target.global_position + Vector3.UP * EYE_HEIGHT, WORLD_MASK)
	return space.intersect_ray(query).is_empty()


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

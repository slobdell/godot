extends TestCase
## Round 10 (arena; the orchestrator's ruling, 2026-09-22): an army deploys INSIDE its layout's spawn zone. The zone
## cannot move forward on the maps the lead plays -- the free ground ahead of its front edge (z = 86) is 4-5 m on
## yard, pit and the Terminus (arenas.md *The deploy zone*) -- so a large army must stand inside it and never step
## forward into the blocks and containers in front of it. This round `ArmyLayout` deploys at the round-9 width floor
## (the orchestrator's revised ruling, 2026-09-22) and passes; a checkerboard-staggered deploy at the turning
## envelope is round 11's (arenas.md), and this test is what it must keep green.
##
## Asserted on real layouts with the army that forces the question: five squads of five of the bare-spawn bus
## (`Units.DEFAULT`), the case squad measured laying two ranks with the front one ~11 m AHEAD of the zone at the
## diagonal pitch. Two things per deployed vehicle: its centre is not ahead of the zone's front edge, and its hull
## box (live transform) overlaps no collider.

const MATCH := preload("res://game/match/match.tscn")
const ARENAS := ["yard", "pit", "terminus"]


static func _army() -> Dictionary:
	var squads: Array = []
	for s in 5:
		var units: Array = []
		for i in 5:
			units.append({"unit": Units.DEFAULT})
		squads.append({"name": "S%d" % s, "units": units})
	return {"name": "Bus army", "squads": squads}


## Oriented-box overlap in the ground plane (separating axes): true when the hull and the obstacle intersect by more
## than `slack` metres.
static func overlaps(centre_a: Vector2, half_a: Vector2, yaw_a: float, centre_b: Vector2, half_b: Vector2,
		yaw_b: float, slack := 0.05) -> bool:
	var axes := [Vector2.from_angle(yaw_a), Vector2.from_angle(yaw_a + PI / 2.0),
			Vector2.from_angle(yaw_b), Vector2.from_angle(yaw_b + PI / 2.0)]
	var d := centre_b - centre_a
	for axis: Vector2 in axes:
		var ra := half_a.x * absf(axis.dot(Vector2.from_angle(yaw_a))) + half_a.y * absf(axis.dot(Vector2.from_angle(yaw_a + PI / 2.0)))
		var rb := half_b.x * absf(axis.dot(Vector2.from_angle(yaw_b))) + half_b.y * absf(axis.dot(Vector2.from_angle(yaw_b + PI / 2.0)))
		if absf(d.dot(axis)) >= ra + rb - slack:
			return false
	return true


## Every problem with where `tanks` stand on `layout`: ahead of the zone, or inside a collider.
static func problems(tanks: Array, layout: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var zone := Arena.spawn_zone_of(layout, true)
	var front: float = (zone["center"] as Vector3).z - (zone["size"] as Vector2).y / 2.0
	for tank: Tank in tanks:
		var p := tank.global_position
		if p.z < front - 0.05:
			out.append("%s stands %.1f m AHEAD of the zone's front edge (z %.1f < %.1f)" % [tank.name, front - p.z, p.z, front])
		var hull: Array = Units.stat(tank.unit_id, "hull_size")
		var forward := -tank.global_basis.z
		# Box local x (width) in the ground plane; Vector2 here is (x, z).
		var yaw := atan2(forward.x, -forward.z)  # 0 when facing -Z
		var half := Vector2(float(hull[0]) / 2.0, float(hull[2]) / 2.0)
		for obstacle: Dictionary in layout.get("obstacles", []):
			var size := Arena.obstacle_size(obstacle)
			# ArenaKit's footprint frame: rotation_deg about +Y, local x -> world (cos, -sin) in (x, z).
			var o_yaw := -deg_to_rad(float(obstacle.get("rotation_deg", 0.0)))
			var hull_axis := Vector2(cos(yaw), sin(yaw))
			if overlaps(Vector2(p.x, p.z), half, hull_axis.angle(), Vector2(obstacle["position"][0], obstacle["position"][1]),
					Vector2(size.x / 2.0, size.z / 2.0), o_yaw):
				out.append("%s at (%.1f, %.1f) stands inside %s at %s" % [tank.name, p.x, p.z, obstacle["type"], obstacle["position"]])
				break
	return out


func _deploy(layout_name: String) -> Array:
	var arena: Arena = await ArenaFixture.build(self, layout_name)
	var game_match: Match = add_to_tree(MATCH.instantiate())
	await wait_physics_frames(1)
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _army()), "", "setup: the bus army loads on %s" % layout_name)
	return [game_match, game_match.sorted_team_tanks(Match.Team.GREEN), arena]


## Free one map's match and arena before the next is built (the next build drains the navigation regions).
func _clear(deployed: Array) -> void:
	(deployed[0] as Node).queue_free()
	(deployed[2] as Node).queue_free()
	await wait_physics_frames(2)


func test_a_full_bus_army_deploys_inside_its_zone_on_the_maps_he_plays() -> void:
	var failures := PackedStringArray()
	for layout_name: String in ARENAS:
		var deployed: Array = await _deploy(layout_name)
		var tanks: Array = deployed[1]
		assert_eq(tanks.size(), 25, "setup: 25 buses on %s" % layout_name)
		var found := problems(tanks, Arena.active)
		print("MEASURE deploy_zone %s %s" % [layout_name, JSON.stringify({"vehicles": tanks.size(), "problems": found.size(),
				"front_z": tanks.map(func(t: Tank) -> float: return t.global_position.z).min()})])
		for line in found.slice(0, 4):
			failures.append("%s: %s" % [layout_name, line])
		await _clear(deployed)
	assert_true(failures.is_empty(), "every vehicle deploys inside its zone and clear of every collider: %s" % "; ".join(failures))


## Positive control (B12): the checker must see a vehicle standing on the Terminus's block row and one ahead of the zone.
func test_the_checker_sees_a_bus_on_a_block_and_one_ahead_of_the_zone() -> void:
	var deployed: Array = await _deploy("terminus")
	var tanks: Array = deployed[1]
	var tank: Tank = tanks[0]
	tank.global_position = Vector3(30.0, 0.0, 78.0)  # inside block (30, 62), whose footprint runs z 42..82
	var found := problems([tank], Arena.active)
	assert_true(found.size() >= 1 and found[0].contains("AHEAD"), "a bus at z 78 is ahead of the zone: %s" % [found])
	assert_true(Array(found).any(func(l: String) -> bool: return l.contains("inside block")),
			"and inside the block: %s" % [found])
	await _clear(deployed)

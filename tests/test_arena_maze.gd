extends TestCase
## The Maze (arena X1, round 6, contract N3 / checkpoint CP2): nav's acceptance fixture, not a shipping map.
##
## Everything here is a property `make nav-maze` depends on. The fixture's whole value is that it is HARD in a
## specific, known way: if a band gap silently widens, or the dead end acquires a back door, a nav run across it
## stops meaning anything and nobody finds out. So each claim the brief makes about the maze is asserted against
## the REAL baked navmesh, not against tools/arena_report.py's grid model (which is a 1 m approximation of it).

const ARENA := preload("res://game/arena/arena.tscn")
## The band gaps, as authored in tools/make_arenas.py: [x of the gap's centre, z of the band].
const GATE_TIGHT := Vector2(11.5, 74.0)
const GATE_WEST := Vector2(-55.5, 74.0)
## Inside the dead-end pocket behind the z = 52 band's westmost gap.
const DEAD_END := Vector2(-99.0, 41.0)
func _maze() -> Arena:
	return await ArenaFixture.build(self, "maze")


func _length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


func test_the_maze_is_a_fixture_and_never_ships() -> void:
	var loaded := Arena.load_layout("maze")
	assert_true(loaded.has("layout"), "maze validates: %s" % loaded.get("error", ""))
	assert_true(not Arena.ROTATION.has("maze"), "--arena=random never picks the maze (%s)" % [Arena.ROTATION])
	assert_true(String(loaded["layout"]["note"]).contains("NOT A SHIPPING MAP"), "and the file says so out loud")
	# In a flag as well as in prose, because consumers need to ASK. The maze broke the announcer's "every arena the
	# booth can name" test on the day it landed; the answer is not to record a name for a map nobody plays.
	assert_true(Arena.is_fixture(loaded["layout"]), "and in a field a tool can read")
	var shipping := Arena.shipping_layout_names()
	assert_true(not shipping.has("maze"), "shipping_layout_names() leaves it out (%s)" % [shipping])
	assert_true(shipping.has("yard") and shipping.has("foundry"), "but keeps the real arenas (%s)" % [shipping])
	for layout_name in shipping:
		assert_true(not Arena.is_fixture(Arena.load_layout(layout_name)["layout"]),
				"%s is a real arena" % layout_name)


func test_a_horde_can_get_from_one_base_to_the_other() -> void:
	var arena: Arena = await _maze()
	var green: Vector3 = Arena.spawn_spot(true, 0)
	var rust: Vector3 = Arena.spawn_spot(false, 0)
	var there := Pathing.find_path(arena, green, rust)
	assert_true(there.size() >= 2 and there[there.size() - 1].distance_to(rust) < 4.0,
			"the navmesh connects green's base to rust's (%d waypoints, ends %.1f m away)"
			% [there.size(), there[there.size() - 1].distance_to(rust) if there.size() > 0 else -1.0])
	# The point of the fixture: the route is a serpentine, not a straight run.
	var detour := _length(there) / green.distance_to(rust)
	assert_true(detour > 1.6, "and it is a detour, not a straight line (%.2fx the crow flight)" % detour)
	# Fairness still holds here, mirrored bake and all (invariant 4): the mirror trip is the same length.
	var back := Pathing.find_path(arena, -green, -rust)
	assert_near(_length(there), _length(back), 0.05, "the 180 deg mirror trip is exactly as long")


func test_every_band_gap_is_open_and_the_tight_one_is_still_tight() -> void:
	var arena: Arena = await _maze()
	var green: Vector3 = Arena.spawn_spot(true, 0)
	for gate: Vector2 in [GATE_TIGHT, GATE_WEST]:
		var mouth := Vector3(gate.x, 0.0, gate.y)
		var route := Pathing.find_path(arena, green, mouth)
		assert_true(route.size() >= 2 and route[route.size() - 1].distance_to(mouth) < 4.0,
				"the band-1 gate at x = %.1f is drivable" % gate.x)
	# The tight gate is a single-file gap: probe across it at hull height and find wall within 5 m either side.
	var space := arena.get_world_3d().direct_space_state
	var wall_at := func(from: Vector3, to: Vector3) -> bool:
		return not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Perception.WORLD_MASK)).is_empty()
	var centre := Vector3(GATE_TIGHT.x, 1.3, GATE_TIGHT.y)
	assert_true(wall_at.call(centre, centre + Vector3(5.0, 0, 0)), "a container stands within 5 m east of the tight gate")
	assert_true(wall_at.call(centre, centre + Vector3(-5.0, 0, 0)), "and within 5 m west of it")
	assert_true(not wall_at.call(centre + Vector3(0, 0, 4.0), centre + Vector3(0, 0, -4.0)),
			"but the gate itself is open through the band")


func test_the_dead_end_has_no_back_door() -> void:
	var arena: Arena = await _maze()
	var pocket := Vector3(DEAD_END.x, 0.0, DEAD_END.y)
	var rust: Vector3 = Arena.spawn_spot(false, 0)
	var out := Pathing.find_path(arena, pocket, rust)
	assert_true(out.size() >= 2, "the pocket is not sealed off entirely: a unit that drives in can drive out")
	# The only way out is back north through the z = 52 band it came in by.
	var highest := -1000.0
	for point in out:
		highest = maxf(highest, point.z)
	assert_true(highest > 52.0,
			"leaving the pocket means backtracking north of the z = 52 band (highest z on the way out: %.1f)" % highest)


func test_the_two_serpentines_are_different_lengths() -> void:
	var arena: Arena = await _maze()
	var green: Vector3 = Arena.spawn_spot(true, 0)
	var rust: Vector3 = Arena.spawn_spot(false, 0)
	# Measure each alternative as a WHOLE route -- spawn to the gate, then gate to the far base. The two gates feed
	# one shared corridor and their tails converge, so comparing only the tails reads 350 m against 359 m and says
	# "one route with two mouths", which is false: what a unit pays for choosing a gate is mostly the leg to it.
	# (The shared corridor is deliberate. Two squads sent through different gates meet head-on in it, which is the
	# peer-to-peer right-of-way case nav owes us -- a maze of separate pipes would never exercise it.)
	var via := func(gate: Vector2) -> float:
		var mouth := Vector3(gate.x, 0.0, gate.y)
		return _length(Pathing.find_path(arena, green, mouth)) + _length(Pathing.find_path(arena, mouth, rust))
	var via_tight: float = via.call(GATE_TIGHT)
	var via_west: float = via.call(GATE_WEST)
	assert_true(via_tight > 0.0 and via_west > 0.0, "both gates lead somewhere (%.0f m, %.0f m)" % [via_tight, via_west])
	assert_true(absf(via_tight - via_west) > 20.0,
			"and they are genuinely different routes, not two mouths of one (%.0f m vs %.0f m)" % [via_tight, via_west])


## X3 (round 6): objectives are data, and an off-centre one must come in a mirrored pair.
##
## `Match` does not read these yet -- it hard-codes CONTROL_CENTER / CONTROL_RADIUS, and a layout's `control_point`
## reaches only the dressing. These tests pin the shape of the data and, above all, the fallback: a layout with no
## `objectives` list must report exactly the single central zone Match already hard-codes, so combat's change is a
## read-through that cannot move any existing arena.
func test_a_layout_without_objectives_reports_the_one_match_already_hard_codes() -> void:
	for layout_name in Arena.layout_names():
		var layout: Dictionary = Arena.load_layout(layout_name)["layout"]
		if layout.has("objectives"):
			continue
		var objectives := Arena.objectives_of(layout)
		assert_eq(objectives.size(), 1, "%s reports exactly one objective" % layout_name)
		assert_eq(objectives[0]["position"], Match.CONTROL_CENTER, "%s: at the centre Match already uses" % layout_name)
		assert_true(objectives[0]["radius"] > 0.0, "%s: with a positive radius" % layout_name)


func test_an_off_centre_objective_needs_its_mirror() -> void:
	var layout: Dictionary = Arena.load_layout("yard")["layout"].duplicate(true)
	layout["objectives"] = [{"name": "west gate", "position": [-40.0, 20.0], "radius": 14.0}]
	assert_true(String(Arena.validate(layout)).contains("mirror"),
			"a lone off-centre objective is refused: %s" % Arena.validate(layout))
	layout["objectives"].append({"name": "east gate", "position": [40.0, -20.0], "radius": 14.0})
	assert_eq(Arena.validate(layout), "", "its mirrored pair validates")
	var read := Arena.objectives_of(layout)
	assert_eq(read.size(), 2, "and both are read back")
	assert_eq(read[0]["position"], Vector3(-40.0, 0.0, 20.0), "as world positions")
	# The fairness invariant this pairing exists to protect: the pair is the same distance from both bases.
	# Read the spawn from the LAYOUT, not Arena.spawn_spot: this test builds no arena, so the static Arena.active is
	# whatever the previous test left behind (or nothing at all, which is how this first failed).
	var green_spawn: Array = layout["spawns"]["green"][0]
	var green := Vector3(green_spawn[0], 0.0, green_spawn[1])
	var to_green := [green.distance_to(read[0]["position"]), green.distance_to(read[1]["position"])]
	to_green.sort()
	var to_rust := [(-green).distance_to(read[0]["position"]), (-green).distance_to(read[1]["position"])]
	to_rust.sort()
	assert_near(to_green[0], to_rust[0], 0.01, "the nearer objective is equally near to each base")
	assert_near(to_green[1], to_rust[1], 0.01, "and so is the farther one")


func test_a_bad_objective_is_refused() -> void:
	var layout: Dictionary = Arena.load_layout("yard")["layout"].duplicate(true)
	layout["objectives"] = [{"name": "nowhere", "position": [0.0, 0.0]}]
	assert_true(String(Arena.validate(layout)).contains("radius"), "an objective needs a radius")
	layout["objectives"] = [{"name": "offmap", "position": [400.0, 0.0], "radius": 10.0},
			{"name": "offmap mirror", "position": [-400.0, 0.0], "radius": 10.0}]
	assert_true(String(Arena.validate(layout)).contains("outside the arena"), "and must be inside the arena")

extends TestCase
## C5: readability at play distance. The starting camera shows vehicles big enough to read as vehicles on
## a phone, nameplates stay out of the play view, and the map switches from models to icons when far out.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup(screen: Vector2i) -> Array:
	tree.root.size = screen
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, Doctrine.load_file("res://doctrines/player_default.json")["doctrine"]), "",
			"setup: player doctrine")
	var camera := Camera3D.new()
	add_to_tree(camera)
	camera.make_current()
	var rig := RtsCamera.new()
	rig.camera = camera
	rig.edge_pan = false
	add_to_tree(rig)
	var map := TacticalMap.new()
	map.game_match = game_match
	map.camera = camera
	map.rig = rig
	add_to_tree(map)
	await wait_physics_frames(2)
	return [game_match, map, rig]


func test_the_starting_view_shows_the_army_at_a_readable_size_on_a_phone() -> void:
	var setup: Array = await _setup(Vector2i(1200, 540))
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	# What SkirmishMode does: frame the army and the ground ahead, no higher than needed.
	var army: Array = map.squad_points("Alpha") + map.squad_points("Bravo")
	rig.frame(army + [Vector3(0, 0, army[0].z - SkirmishMode.START_AHEAD)], true, SkirmishMode.START_ZOOM)
	await tree.process_frame
	assert_true(map.all_on_screen(army), "every vehicle is on screen at the start")
	var tank := game_match.tanks.get_node("Green_Alpha_1") as Tank
	var hull: Array = Units.stat(tank.unit_id, "hull_size")
	var front := rig.camera.unproject_position(tank.global_position + Vector3(0, 0, -float(hull[2]) / 2.0))
	var back := rig.camera.unproject_position(tank.global_position + Vector3(0, 0, float(hull[2]) / 2.0))
	var side := rig.camera.unproject_position(tank.global_position + Vector3(float(hull[0]) / 2.0, 0, 0))
	var across := rig.camera.unproject_position(tank.global_position - Vector3(float(hull[0]) / 2.0, 0, 0))
	var pixels := maxf(front.distance_to(back), side.distance_to(across))
	assert_true(pixels >= 24.0, "a vehicle is at least 24 px on a 1200x540 phone screen (%.0f px)" % pixels)
	assert_true(map.is_close_up(), "and the start is close enough to show models, not icons (zoom %.2f)" % rig.zoom)


func test_nameplates_stay_out_of_the_play_view() -> void:
	var setup: Array = await _setup(Vector2i(1280, 720))
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	var tank := game_match.tanks.get_node("Green_Alpha_1") as Tank
	rig.zoom = SkirmishMode.START_ZOOM
	map._apply_fog_of_war()
	assert_true(not tank.nameplate.visible, "no nameplate at play distance (the chips and rings carry that)")
	rig.zoom = 0.05
	map._apply_fog_of_war()
	assert_true(tank.nameplate.visible, "zoomed right in, the nameplate shows")


func test_far_out_markers_are_readable_icons() -> void:
	var setup: Array = await _setup(Vector2i(1200, 540))
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	rig.zoom = 0.75
	assert_true(not map.is_close_up(), "far out, the map draws markers")
	assert_true(map.marker_size() >= 16.0, "icons are at least 16 px (%.0f)" % map.marker_size())
	rig.toggle_overview(Match.Team.GREEN)
	assert_true(not map.is_close_up(), "the overview always uses icons")


func teardown() -> void:
	tree.root.size = Vector2i(1280, 720)
	super.teardown()

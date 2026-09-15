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
	rig.toggle_overview(Match.Team.GREEN)
	rig.zoom = RtsCamera.TRACK_MAX_ZOOM
	assert_true(map.is_close_up(), "a camera following an order stays in the model view")


func test_friend_and_foe_differ_by_shape_not_only_color() -> void:
	var setup: Array = await _setup(Vector2i(1280, 720))
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var markers := SelectionMarkers.new()
	markers.game_match = game_match
	markers.map = map
	add_to_tree(markers)
	var enemy := game_match.spawn_tank("Rust_Near_1", 0, Match.Team.RUST)
	enemy.global_position = (game_match.tanks.get_node("Green_Alpha_1") as Tank).global_position + Vector3(0, 0, -25)
	await wait_physics_frames(Match.INTEL_EVERY_TICKS + 1)
	markers.refresh()
	var enemy_ring := markers.get_node("Ring_Rust_Near_1") as MeshInstance3D
	var friend_ring := markers.get_node("Ring_Green_Bravo_1") as MeshInstance3D
	assert_true(enemy_ring.visible, "setup: the enemy in sight has a ring")
	var enemy_triangles := (enemy_ring.mesh as ArrayMesh).surface_get_array_len(0)
	var friend_triangles := (friend_ring.mesh as ArrayMesh).surface_get_array_len(0)
	assert_true(enemy_triangles < friend_triangles * 0.75, "the enemy ring is dashed (gaps), the friendly ring solid (%d vs %d vertices)" % [enemy_triangles, friend_triangles])


func test_ui_scale_makes_everything_bigger_and_still_fits_a_phone() -> void:
	var setup: Array = await _setup(Vector2i(1200, 540))
	var map: TacticalMap = setup[1]
	var normal := map.button_height()
	map.ui_scale = 1.25
	map._layout_panels()
	await tree.process_frame
	await tree.process_frame
	assert_near(map.button_height(), normal * 1.25, 0.5, "a 1.25 UI scale makes tap targets 25% bigger")
	var screen := Rect2(Vector2.ZERO, Vector2(1200, 540))
	for panel in [map._squad_bar, map._command_bar, map._top_row]:
		assert_true(screen.encloses((panel as Control).get_global_rect()), "%s still fits a phone (%s)" % [panel.name, (panel as Control).get_global_rect()])
	assert_true(not map._squad_bar.get_global_rect().intersects(map._top_row.get_global_rect()), "without overlapping")


func teardown() -> void:
	tree.root.size = Vector2i(1280, 720)
	super.teardown()

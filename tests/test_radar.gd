extends TestCase
## G2: the radar shows only what the team knows, and taps/drags on it aim the camera and order squads.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup() -> Array:
	if tree.root.size.x < 640:
		tree.root.size = Vector2i(1280, 720)
	var arena := ARENA.instantiate()
	add_to_tree(arena)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, Doctrine.load_file("res://doctrines/player_default.json")["doctrine"]), "",
			"setup: player doctrine")
	var camera := Camera3D.new()
	add_to_tree(camera)
	camera.make_current()
	var rig := RtsCamera.new()
	RtsCamera.fov = 55.0  # round 5's lens: these tests are about screen geometry, written for it (the default is the lead's 35° telephoto)
	rig.camera = camera
	rig.edge_pan = false
	add_to_tree(rig)
	var map := TacticalMap.new()
	map.game_match = game_match
	map.camera = camera
	map.rig = rig
	add_to_tree(map)
	var radar := Radar.new()
	radar.game_match = game_match
	radar.map = map
	map.add_child(radar)
	radar.read_arena(arena)
	await wait_physics_frames(2)
	return [game_match, map, rig, radar]


func test_radar_and_world_coordinates_agree() -> void:
	var setup: Array = await _setup()
	var radar: Radar = setup[3]
	assert_true(radar.size.x >= Radar.MIN_SIZE and radar.size.x == radar.size.y, "a square radar of a sensible size (%s)" % radar.size)
	for spot in [Vector3(-100, 0, 80), Vector3(30, 0, -45)]:
		assert_true(radar.radar_to_world(radar.world_to_radar(spot)).distance_to(spot) < 0.01, "round trip %s" % spot)
	assert_true(radar.world_to_radar(Vector3(0, 0, -100)).y < radar.size.y / 2.0, "the enemy base (north for Green) is at the top")
	assert_true(radar.obstacles.size() >= 15, "it read the arena's obstacles (%d)" % radar.obstacles.size())


func _kinds(radar: Radar, kind: String) -> int:
	return radar.blips().filter(func(b: Dictionary) -> bool: return b["kind"] == kind).size()


func test_enemies_appear_only_through_team_intel() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var radar: Radar = setup[3]
	assert_eq(_kinds(radar, "friendly") + _kinds(radar, "commander"), 5, "all five of our tanks")
	assert_eq(_kinds(radar, "commander"), 2, "each squad's commander is marked")
	var hidden := game_match.spawn_tank("Rust_Far_1", 0, Match.Team.RUST)
	hidden.global_position = Vector3(100, 0, -100)  # far from every Green tank
	await wait_physics_frames(Match.INTEL_EVERY_TICKS + 1)
	assert_eq(_kinds(radar, "enemy") + _kinds(radar, "contact"), 0, "an enemy nobody has seen is not on the radar")
	hidden.global_position = Vector3(0, 0, 40)  # in front of the base, in plain sight
	await wait_physics_frames(Match.INTEL_EVERY_TICKS + 1)
	assert_eq(_kinds(radar, "enemy"), 1, "once seen, it shows")
	hidden.global_position = Vector3(100, 0, -100)
	await wait_physics_frames(Match.INTEL_EVERY_TICKS + 1)
	assert_eq(_kinds(radar, "contact"), 1, "out of sight again: a last-known contact")
	assert_eq(_kinds(radar, "enemy"), 0, "not a live blip")


func test_tap_orders_the_selected_squad_and_drag_looks() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var rig: RtsCamera = setup[2]
	var radar: Radar = setup[3]
	var focus_before := rig.focus
	var goal := Vector3(-60, 0, -30)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = radar.world_to_radar(goal)
	radar._gui_input(press)
	var release := press.duplicate()
	release.pressed = false
	radar._gui_input(release)
	var squad: Squad = game_match.squads["0/Alpha"]
	assert_eq(squad.verb, "move", "a tap on the radar sends the selected squad (C1)")
	assert_true((squad.destination as Vector3).distance_to(goal) < 3.0, "to the tapped spot (%s)" % [squad.destination])
	var bravo: Squad = game_match.squads["0/Bravo"]
	var look_at := Vector3(40, 0, 10)
	press.position = radar.world_to_radar(Vector3(0, 0, 60))
	radar._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = radar.world_to_radar(look_at)
	radar._gui_input(motion)
	assert_true(rig.focus.distance_to(look_at) < 3.0, "a drag scrubs the camera across the radar while the finger is down (%s)" % rig.focus)
	release.position = motion.position
	radar._gui_input(release)
	assert_true((squad.destination as Vector3).distance_to(goal) < 3.0, "and a drag orders nothing")
	assert_eq(bravo.verb, "hold", "nobody else moved either")
	assert_true(rig.focus.distance_to(focus_before) > 10.0, "the view stays where the drag left it")
	# A press that rests (a hesitant finger) looks instead of ordering.
	press.position = radar.world_to_radar(Vector3(-20, 0, 80))
	radar._gui_input(press)
	radar._process(TacticalMap.LONG_PRESS_SECONDS + 0.05)
	release.position = press.position
	radar._gui_input(release)
	assert_true((squad.destination as Vector3).distance_to(goal) < 3.0, "a long press on the radar orders nothing")
	assert_true(rig.focus.distance_to(Vector3(-20, 0, 80)) < 3.0, "it looks there (%s)" % rig.focus)

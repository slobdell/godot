extends TestCase
## Round 37 (feedback stretch): the radar rings a pinned enemy the team can see, and the unit card names what the rules
## are doing to a vehicle ("PINNED", "REPAIRING +5/s"), both behind the `marks` look, off until his pick.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func teardown() -> void:
	FeedbackLook.reset()


func _radar() -> Array:
	if tree.root.size.x < 640:
		tree.root.size = Vector2i(1280, 720)
	var arena := ARENA.instantiate()
	add_to_tree(arena)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.load_doctrine(Match.Team.GREEN, Doctrine.load_file("res://doctrines/player_default.json")["doctrine"])
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
	var radar := Radar.new()
	radar.game_match = game_match
	radar.map = map
	map.add_child(radar)
	radar.read_arena(arena)
	await wait_physics_frames(2)
	return [game_match, radar]


func _pinned_enemies(radar: Radar) -> int:
	return radar.blips().filter(func(b: Dictionary) -> bool: return b["kind"] == "enemy" and bool(b.get("pinned", false))).size()


func test_a_pinned_enemy_in_sight_is_ringed_on_the_radar() -> void:
	var setup: Array = await _radar()
	var game_match: Match = setup[0]
	var radar: Radar = setup[1]
	var enemy := game_match.spawn_tank("Rust_Seen_1", 0, Match.Team.RUST)
	enemy.global_position = Vector3(0, 0, 40)  # in front of the base, in plain sight
	await wait_physics_frames(Match.INTEL_EVERY_TICKS + 1)
	assert_eq(_pinned_enemies(radar), 0, "seen, not pinned: a plain diamond")
	enemy.suppression = 1.0
	FeedbackLook.use("")
	assert_eq(_pinned_enemies(radar), 0, "off by default: nothing he has not picked shows")
	FeedbackLook.use("marks:a")
	assert_eq(_pinned_enemies(radar), 1, "pinned: ringed")
	var rings: Array = radar._marks_from_blips(radar.blips())["by_shape"]["ring"]
	assert_true(rings.any(func(r: Array) -> bool: return r[2] == Radar.PINNED_COLOR), "in the pinned colour")


func test_the_pinned_and_repairing_words() -> void:
	var game_match: Match = add_to_tree(MATCH.instantiate())
	game_match.elimination = true
	var tanker := game_match.spawn_tank("Tanker", 0, Match.Team.GREEN, "gang_support")
	var patient := game_match.spawn_tank("Patient", 1, Match.Team.GREEN, "gang_scout")
	tanker.global_position = Vector3(60, 0, 0)
	patient.global_position = Vector3(68, 0, 0)
	var panel := SelectionPanel.new()
	var controls := RtsControls.new()
	controls.game_match = game_match
	panel.controls = controls
	FeedbackLook.use("marks:a")
	assert_eq(panel._state_words(patient), "", "nothing happening: no words")
	patient.health = patient.max_health / 2
	patient.ticks_since_hit = 1_000_000
	patient.suppression = 0.9
	FeedbackLook.use("")
	assert_eq(panel._state_words(patient), "", "off by default: no words until he picks them")
	FeedbackLook.use("marks:a")
	assert_eq(panel._state_words(patient), "PINNED  REPAIRING +5/s", "both, in his words")
	panel.free()
	controls.free()

extends TestCase
## C2: the squad bar (one chip per squad: name, unit icons, health and shield, order state) and the
## world selection marks (3D ground rings that never cover the models).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


## A doctrine with `squads` squads of `per_squad` tanks, in whichever army JSON the catalog speaks
## (v1 "tanks" with weapons now; v2 "units" once rules' catalog v2 lands).
static func army(squads: int, per_squad: int) -> Dictionary:
	var names := ["Alpha", "Bravo", "Charlie", "Delta", "Echo"]
	var v2 := (Units.PROFILES["tank"] as Dictionary).has("role")
	var result := {"name": "Test", "squads": []}
	for i in squads:
		var members := []
		for j in per_squad:
			members.append({"unit": "tank"} if v2 else {"weapon": "cannon"})
		(result["squads"] as Array).append({"name": names[i], "formation": "wedge", "verb": "hold",
				"units" if v2 else "tanks": members})
	return result


func _setup(doctrine: Dictionary = {}, screen := Vector2i(1280, 720)) -> Array:
	tree.root.size = screen
	var arena := ARENA.instantiate()
	add_to_tree(arena)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	if doctrine.is_empty():
		doctrine = Doctrine.load_file("res://doctrines/player_default.json")["doctrine"]
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, doctrine), "", "setup: player doctrine loads")
	var camera := Camera3D.new()
	add_to_tree(camera)
	camera.make_current()
	var rig := RtsCamera.new()
	rig.camera = camera
	rig.edge_pan = false
	rig.focus = Vector3(0, 0, 70)
	rig.zoom = 0.3
	add_to_tree(rig)
	var map := TacticalMap.new()
	map.game_match = game_match
	map.camera = camera
	map.rig = rig
	add_to_tree(map)
	var markers := SelectionMarkers.new()
	markers.game_match = game_match
	markers.map = map
	add_to_tree(markers)
	await wait_physics_frames(2)
	return [game_match, map, rig, markers]


func test_one_chip_per_squad_and_tapping_selects_then_follows() -> void:
	var setup: Array = await _setup()
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	assert_eq(map._squad_chips.keys(), ["Alpha", "Bravo"], "a chip for each squad, in order")
	var selections: Array = []
	map.squad_selected.connect(func(key: String) -> void: selections.append(key))
	(map._squad_chips["Bravo"] as SquadChip).pressed.emit()
	assert_eq(map.selected_squad, "Bravo", "tapping a chip selects the squad")
	assert_eq(selections, ["0/Bravo"], "and announces it (C7 squad_selected)")
	var focus_before := rig.focus
	assert_eq(rig.focus, focus_before, "the first tap doesn't move the camera")
	(map._squad_chips["Bravo"] as SquadChip).pressed.emit()
	var center := Vector3.ZERO
	for p in map.squad_points("Bravo"):
		center += p / 2.0
	assert_true(rig.focus.distance_to(Vector3(center.x, 0, center.z)) < 2.0,
			"a second tap on the selected chip centers the camera on the squad (%s vs %s)" % [rig.focus, center])
	assert_eq(selections.size(), 1, "re-tapping the same squad is not a new selection")


func test_chip_summary_tracks_units_health_and_orders() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var chip := map._squad_chips["Alpha"] as SquadChip
	var info := chip.summary()
	assert_eq((info["roles"] as Array).size(), 3, "one icon per vehicle in Alpha")
	assert_eq(info["roles"][0], "tank", "a cannon tank shows the tank icon")
	assert_near(float(info["health"]), 1.0, 0.001, "full health")
	assert_eq(info["state"], "Holding", "the doctrine starts Alpha holding")
	map.order_drag(Vector3(-20, 0, 40), Vector3(-20, 0, 40))
	assert_eq(chip.summary()["state"], "Moving", "after an order the chip says Moving")
	var victim := game_match.tanks.get_node("Green_Alpha_2") as Tank
	victim.apply_damage(victim.health)
	info = chip.summary()
	assert_eq(info["alive"], [true, false, true], "a lost vehicle shows as lost")
	assert_near(float(info["health"]), 2.0 / 3.0, 0.01, "squad health counts the loss (%.2f)" % info["health"])
	for member in ["Green_Alpha_1", "Green_Alpha_3"]:
		var tank := game_match.tanks.get_node(member) as Tank
		tank.apply_damage(tank.health)
	info = chip.summary()
	assert_true(info["lost"], "every vehicle gone: the squad is lost")
	assert_eq(info["state"], "Destroyed", "and the chip says so")


func test_contact_pip_when_an_enemy_is_in_sight() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var chip := map._squad_chips["Alpha"] as SquadChip
	assert_true(not chip.summary()["contact"], "no contact at the start")
	var enemy := game_match.spawn_tank("Rust_Probe_1", 0, Match.Team.RUST)
	var lead := game_match.tanks.get_node("Green_Alpha_1") as Tank
	enemy.global_position = lead.global_position + Vector3(0, 0, -30)
	await wait_physics_frames(Match.INTEL_EVERY_TICKS + 1)
	assert_true(chip.summary()["contact"], "an enemy in sight of Alpha lights the contact pip")


func test_five_squads_fit_a_phone_without_overlapping_the_tools() -> void:
	var setup: Array = await _setup(army(5, 1), Vector2i(1200, 540))
	var map: TacticalMap = setup[1]
	await tree.process_frame
	await tree.process_frame
	assert_eq(map._squad_chips.size(), 5, "five squads, five chips")
	var screen := Rect2(Vector2.ZERO, Vector2(1200, 540))
	var bar := map._squad_bar.get_global_rect()
	var tools := map._top_row.get_global_rect()
	assert_true(screen.encloses(bar), "the squad bar fits a 1200x540 phone (%s)" % bar)
	assert_true(screen.encloses(tools), "the camera/time buttons fit (%s)" % tools)
	assert_true(not bar.intersects(tools), "and they don't overlap (%s vs %s)" % [bar, tools])
	for chip_name in map._squad_chips:
		var chip := map._squad_chips[chip_name] as SquadChip
		assert_true(chip.size.y >= 48.0, "%s's chip is a thumb-sized target (%.0f px)" % [chip_name, chip.size.y])
	assert_eq((map._squad_chips["Echo"] as SquadChip).hotkey, "" if TacticalMap._touch_first() else "5", "desktop hotkey hint")


func test_ground_rings_mark_the_selected_squad_and_respect_fog() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var markers: SelectionMarkers = setup[3]
	var hidden := game_match.spawn_tank("Rust_Far_1", 0, Match.Team.RUST)
	hidden.global_position = Vector3(100, 0, -100)
	await wait_physics_frames(Match.INTEL_EVERY_TICKS + 1)
	markers.refresh()
	var rings := markers.state()
	assert_eq(rings["Green_Alpha_1"]["kind"], "commander", "Alpha's commander gets the commander ring")
	assert_eq(rings["Green_Alpha_2"]["kind"], "selected", "Alpha's wingmen get the selection ring")
	assert_eq(rings["Green_Bravo_1"]["kind"], "friendly", "other squads only get a faint team mark")
	assert_true(not rings["Rust_Far_1"]["visible"], "an enemy in the fog gets no ring (no information leak)")
	map.select_squad("Bravo")
	markers.refresh()
	rings = markers.state()
	assert_eq(rings["Green_Alpha_2"]["kind"], "friendly", "selecting Bravo moves the rings")
	assert_eq(rings["Green_Bravo_2"]["kind"], "selected", "to Bravo")
	var ring := markers.get_node("Ring_Green_Bravo_2") as MeshInstance3D
	var material := ring.material_override as StandardMaterial3D
	assert_true(not material.no_depth_test, "rings are depth-tested, so a vehicle covers its own ring")
	assert_true(ring.global_position.y < 0.5, "the ring lies on the ground")


func test_close_up_the_map_leaves_vehicles_to_their_models() -> void:
	var setup: Array = await _setup()
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	rig.zoom = 0.3
	assert_true(map.is_close_up(), "zoomed in, the 2D markers step aside for the 3D rings")
	rig.zoom = 0.8
	assert_true(not map.is_close_up(), "zoomed out, the map draws markers again")


func teardown() -> void:
	tree.root.size = Vector2i(1280, 720)
	super.teardown()

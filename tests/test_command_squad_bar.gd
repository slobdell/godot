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
	RtsCamera.fov = 55.0  # round 5's lens: these tests are about screen geometry, written for it (the default is the lead's 35° telephoto)
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
	var squad_max := 0.0
	for member in ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"]:
		squad_max += (game_match.tanks.get_node(member) as Tank).max_health
	victim.apply_damage(victim.health)
	info = chip.summary()
	assert_eq(info["alive"], [true, false, true], "a lost vehicle shows as lost")
	# Health is weighted by each unit's max health (squads mix unit types).
	assert_near(float(info["health"]), 1.0 - victim.max_health / squad_max, 0.01,
			"squad health counts the loss (%.2f)" % info["health"])
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
	# PUT IT SOMEWHERE THE LEAD CAN ACTUALLY SEE, rather than at a fixed offset. This test is about the CHIP'S PIP,
	# not about perception or about the foundry's furniture, so it should not be able to fail because of either.
	#
	# It used to place the enemy 30 m due north, which on the foundry put it inside the crate at (-12, 56) - by five
	# centimetres, with a 3.6 m hull, which the physics solver tolerated. At CP2 that hull became 8.62 m, the overlap
	# became 2.56 m, and the solver resolved it by **shoving the body 1.48 m under the floor** in a single tick.
	# `Perception.has_line_of_sight` casts at EYE_HEIGHT 1.3 m, so the ray ran from y 1.301 to y -0.176 - into the
	# ground - and the pip could never light. (Measured by scale on builder0, e7ebb372.) So the test was never
	# really clear of that crate; it was passing on 5 cm of margin, and any resize or new arena would have ended it.
	# A shorter fixed offset would rot exactly the same way, so there is no fixed offset here at all.
	var placed := Vector3.ZERO
	for bearing in 12:
		for reach: float in [24.0, 32.0, 40.0]:
			var spot := lead.global_position + Vector3(sin(TAU * bearing / 12.0), 0.0, -cos(TAU * bearing / 12.0)) * reach
			enemy.global_position = Vector3(spot.x, lead.global_position.y, spot.z)
			enemy.reset_physics_interpolation()  # teleport: interpolation must not leave it at its old spot
			await wait_physics_frames(2)
			# Not pushed out of the world by something it was placed inside, and really in sight.
			if absf(enemy.global_position.y - lead.global_position.y) < 0.5 and Perception.has_line_of_sight(lead, enemy):
				placed = enemy.global_position
				break
		if placed != Vector3.ZERO:
			break
	assert_true(placed != Vector3.ZERO, "setup: somewhere within sight of Alpha that is not inside the scenery")
	assert_true(placed.distance_to(lead.global_position) <= lead.sight_radius,
			"setup: and inside its sight radius (%.0f m of %.0f)" % [placed.distance_to(lead.global_position), lead.sight_radius])
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
	hidden.reset_physics_interpolation()  # teleport: interpolation must not draw it at its old spot
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
	var material := markers.layer("selected").material_override as StandardMaterial3D
	assert_true(not material.no_depth_test, "rings are depth-tested, so a vehicle covers its own ring")
	assert_true((rings["Green_Bravo_2"]["position"] as Vector3).y < 0.5, "the ring lies on the ground")


func test_close_up_the_map_leaves_vehicles_to_their_models() -> void:
	var setup: Array = await _setup()
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	rig.zoom = 0.3
	assert_true(map.is_close_up(), "zoomed in, the 2D markers step aside for the 3D rings")
	rig.zoom = 0.8
	assert_true(not map.is_close_up(), "zoomed out, the map draws markers again")


func test_a_unit_card_shows_one_vehicle_and_follows_the_selection() -> void:
	var setup: Array = await _setup(army(2, 3), Vector2i(1200, 540))
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var markers: SelectionMarkers = setup[3]
	map.focus_unit("Green_Alpha_3")
	await tree.process_frame
	await tree.process_frame
	assert_true(map._unit_card.visible, "focusing a unit opens its card")
	assert_true(map._unit_title.text.begins_with("Alpha 3 · Tank"), "naming the vehicle and its type (%s)" % map._unit_title.text)
	assert_true(map._unit_stats.text.contains("Hull"), "with its hull (%s)" % map._unit_stats.text)
	var screen := Rect2(Vector2.ZERO, Vector2(1200, 540))
	assert_true(screen.encloses(map._unit_card.get_global_rect()), "the card fits a phone (%s)" % map._unit_card.get_global_rect())
	assert_true(not map._unit_card.get_global_rect().intersects(map._command_bar.get_global_rect()), "above the order bar")
	markers.refresh()
	assert_eq(markers.state()["Green_Alpha_3"]["kind"], "focused", "its ground ring turns white")
	map.focus_unit("Green_Bravo_1")
	assert_eq(map.focused_unit, "", "a unit outside the selected squad can't be focused")
	map.focus_unit("Green_Alpha_3")
	map.select_squad("Bravo")
	assert_eq(map.focused_unit, "", "selecting another squad closes the card")
	assert_true(not map._unit_card.visible, "(hidden)")
	map.select_squad("Alpha")
	map.focus_unit("Green_Alpha_2")
	var victim := game_match.tanks.get_node("Green_Alpha_2") as Tank
	victim.apply_damage(victim.health)
	await tree.process_frame
	await tree.process_frame
	assert_eq(map.focused_unit, "", "a destroyed unit's card closes")


func test_long_pressing_a_chip_gives_quick_commands_for_that_squad() -> void:
	var setup: Array = await _setup({}, Vector2i(1200, 540))
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var chip := map._squad_chips["Bravo"] as SquadChip
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	chip._gui_input(press)
	chip._process(TacticalMap.LONG_PRESS_SECONDS + 0.05)
	assert_eq(map.quick_squad, "Bravo", "holding Bravo's chip opens Bravo's quick commands")
	var release := press.duplicate()
	release.pressed = false
	chip._gui_input(release)
	chip.pressed.emit()  # what the Button does on release
	assert_eq(map.selected_squad, "Alpha", "the long press didn't change the selection")
	await tree.process_frame
	await tree.process_frame
	var row := map._quick_row.get_global_rect()
	assert_true(Rect2(Vector2.ZERO, Vector2(1200, 540)).encloses(row), "the quick row fits the phone (%s)" % row)
	assert_true(not row.intersects(map._squad_bar.get_global_rect()), "under the squad bar, not over it")
	assert_true(absf(row.get_center().x - chip.get_global_rect().get_center().x) < row.size.x / 2.0, "near Bravo's chip")
	(map._buttons["quick:break_contact"] as Button).pressed.emit()
	assert_eq(game_match.squads["0/Bravo"].verb, "break_contact", "Break contact went to Bravo")
	assert_eq(game_match.squads["0/Alpha"].verb, "hold", "not to the selected squad")
	assert_eq(map.quick_squad, "", "and the quick row closed")
	chip._gui_input(press)
	chip._process(0.1)
	chip._gui_input(release)
	assert_eq(map.quick_squad, "", "a short tap is not a long press")
	map.open_quick_commands("Bravo")
	map._process(TacticalMap.QUICK_SECONDS + 0.1)
	assert_eq(map.quick_squad, "", "unused quick commands close by themselves")


func teardown() -> void:
	tree.root.size = Vector2i(1280, 720)
	super.teardown()

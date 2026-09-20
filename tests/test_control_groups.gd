extends TestCase
## Control X4: control groups and the camera. Ctrl+1–9 saves, 1–9 selects, a quick second tap centers the camera,
## shift+N adds, Tab cycles groups; doctrine squads load as groups 1–5; wheel zoom and middle-drag pan reach the
## camera through the controls; the radar's left click looks and right click orders; the group bar shows each group.

const Fixture := preload("res://tests/support/control_fixture.gd")


func _setup() -> Fixture:
	var f := Fixture.new(self)
	await f.build(false)
	return f


func test_ctrl_number_saves_and_number_recalls() -> void:
	var f := await _setup()
	await f.select(["Green_Alpha_1", "Green_Bravo_2"])
	await f.key(KEY_3, false, true)
	assert_eq(f.controls.groups.members(3), ["Green_Alpha_1", "Green_Bravo_2"], "ctrl+3 saves the selection as group 3")
	await f.click(f.screen("Green_Alpha_2"))
	await f.key(KEY_3)
	assert_eq(f.controls.selection.units, ["Green_Alpha_1", "Green_Bravo_2"], "3 selects group 3 again")
	await f.click(f.screen("Green_Alpha_3"))
	await f.key(KEY_3, true)
	assert_eq(f.controls.groups.members(3), ["Green_Alpha_1", "Green_Alpha_3", "Green_Bravo_2"], "shift+3 adds the selection to group 3")
	await f.key(KEY_7)
	assert_eq(f.controls.selection.units, ["Green_Alpha_3"], "an empty group number doesn't clear the selection")


func test_a_quick_second_tap_centers_the_camera_on_the_group() -> void:
	var f := await _setup()
	await f.select(["Green_Bravo_1", "Green_Bravo_2"])
	await f.key(KEY_2, false, true)
	f.rig.focus = Vector3(-80, 0, -60)
	await f.key(KEY_2)
	assert_true(f.rig.focus.distance_to(Vector3(-80, 0, -60)) < 0.1, "one tap selects without moving the camera")
	await f.key(KEY_2)
	assert_true(f.rig.focus.distance_to(Vector3(15, 0, 40)) < 3.0, "a quick second tap centers on the group (focus %s)" % f.rig.focus)


func test_tab_cycles_through_groups() -> void:
	var f := await _setup()
	f.controls.groups.save(1, ["Green_Alpha_1"])
	f.controls.groups.save(4, ["Green_Bravo_1", "Green_Bravo_2"])
	await f.key(KEY_TAB)
	assert_eq(f.controls.selection.units, ["Green_Alpha_1"], "Tab selects the first group")
	await f.key(KEY_TAB)
	assert_eq(f.controls.selection.units, ["Green_Bravo_1", "Green_Bravo_2"], "Tab again skips empty groups to group 4")
	await f.key(KEY_TAB)
	assert_eq(f.controls.selection.units, ["Green_Alpha_1"], "and wraps around")


func test_doctrine_squads_become_groups_one_to_five() -> void:
	var f := await _setup()
	var groups := ControlGroups.from_squads(f.game_match, Match.Team.GREEN)
	assert_eq(groups.members(1), ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"], "squad Alpha is group 1")
	assert_eq(groups.members(2), ["Green_Bravo_1", "Green_Bravo_2"], "squad Bravo is group 2")
	assert_true(groups.is_empty(3), "no third squad, no group 3")
	f.tank("Green_Alpha_2").apply_damage(100000)
	groups.prune(f.game_match)
	assert_eq(groups.members(1), ["Green_Alpha_1", "Green_Alpha_3"], "destroyed units leave their groups")


func test_wheel_zooms_and_middle_drag_pans_through_the_controls() -> void:
	var f := await _setup()
	var zoom := f.rig.zoom
	var center := Vector2(640, 360)
	f.button(center, true, MOUSE_BUTTON_WHEEL_DOWN)
	f.button(center, false, MOUSE_BUTTON_WHEEL_DOWN)
	await tree.process_frame
	assert_true(f.rig.zoom > zoom, "wheel down zooms out (%.2f → %.2f)" % [zoom, f.rig.zoom])
	var focus := f.rig.focus
	f.button(center, true, MOUSE_BUTTON_MIDDLE)
	var drag := InputEventMouseMotion.new()
	drag.position = center + Vector2(120, 0)
	drag.global_position = drag.position
	drag.relative = Vector2(120, 0)
	drag.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	tree.root.push_input(drag)
	f.button(center + Vector2(120, 0), false, MOUSE_BUTTON_MIDDLE)
	await tree.process_frame
	assert_true(f.rig.focus.distance_to(focus) > 3.0, "middle-drag pans the camera")
	assert_eq(f.controls.selection.units, [], "and never selects anything")


func test_radar_left_click_looks_and_right_click_orders_the_selection() -> void:
	var f := await _setup()
	var radar := Radar.new()
	radar.game_match = f.game_match
	radar.controls = f.controls
	f.controls.add_child(radar)
	radar.read_arena(f.arena)
	await f.select(["Green_Alpha_1"])
	var spot := Vector3(-60, 0, -40)
	var at := radar.get_global_rect().position + radar.world_to_radar(spot)
	f.button(at, true)
	f.button(at, false)
	await tree.process_frame
	assert_true(Vector2(f.rig.focus.x, f.rig.focus.z).distance_to(Vector2(spot.x, spot.z)) < 3.0,
			"a left click on the radar moves the camera there (%s)" % f.rig.focus)
	assert_eq(f.orders.ordered_units(), [], "without ordering anyone")
	f.button(at, true, MOUSE_BUTTON_RIGHT)
	f.button(at, false, MOUSE_BUTTON_RIGHT)
	await tree.process_frame
	var order := f.orders.current("Green_Alpha_1")
	assert_eq(order.get("verb", ""), "move", "a right click on the radar moves the selection")
	assert_true(order.has("to") and Vector2(order["to"][0], order["to"][1]).distance_to(Vector2(spot.x, spot.z)) < 3.0,
			"to that spot (%s)" % [order.get("to")])
	await f.key(KEY_A)
	f.button(at, true)
	f.button(at, false)
	await tree.process_frame
	assert_eq(f.orders.current("Green_Alpha_1").get("verb", ""), "attack_move", "A then a radar click attack-moves there")


func test_group_bar_shows_each_group_with_unit_icons_and_health() -> void:
	var f := await _setup()
	f.controls.groups.save(1, ["Green_Alpha_1", "Green_Alpha_3"])
	f.controls.groups.save(3, ["Green_Bravo_2"])
	f.tank("Green_Alpha_1").health = f.tank("Green_Alpha_1").max_health / 2
	var bar := GroupBar.new()
	bar.controls = f.controls
	f.controls.add_child(bar)
	await tree.process_frame
	var shown := bar.summary()
	assert_eq(shown.map(func(g: Dictionary) -> int: return g["number"]), [1, 3], "one chip per group that has units")
	assert_eq(shown[0]["roles"], ["tank", "ifv"], "group 1 shows a tank and an IFV icon")
	assert_near(shown[0]["health"], 0.75, 0.05, "group 1's bar shows its average health")
	assert_eq(shown[1]["roles"], ["scout"], "group 3 shows a scout icon")
	await f.select(["Green_Bravo_2"])
	assert_true(bar.summary()[1]["selected"], "the group whose units are selected is lit")
	bar.chip_pressed(1)
	assert_eq(f.controls.selection.units, ["Green_Alpha_1", "Green_Alpha_3"], "clicking a chip selects its group")


## Round 6 X6: each chip says what its squad is doing, idle squads stand out, and the chip stays lit when the
## selection is the group's living units in another order or with a member dead.
func test_group_chips_say_what_each_squad_is_doing() -> void:
	var f := await _setup()
	f.controls.groups.save(1, ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"])
	f.controls.groups.save(2, ["Green_Bravo_1", "Green_Bravo_2"])
	f.place("Rust_Alpha_1", Vector3(0, 0, -200))  # out of sight: contact would outrank every other state
	var bar := GroupBar.new()
	bar.controls = f.controls
	f.controls.add_child(bar)
	await f.select(["Green_Bravo_1", "Green_Bravo_2"])
	assert_eq(f.controls.order_selection("move", {"to": [15.0, 70.0]}), "", "group 2 is sent somewhere")
	await wait_physics_frames(3)
	await tree.process_frame
	var states := {}
	for chip: Dictionary in bar.summary():
		states[chip["number"]] = chip["state"]
	assert_eq(states.get(2, ""), "moving", "the moving squad says so (%s)" % [states])
	assert_eq(states.get(1, ""), "idle", "the squad with no orders reads idle (%s)" % [states])
	assert_true(GroupBar.STATE_WORDS.has("idle"), "idle has a word on the chip")
	await f.select(["Green_Alpha_3", "Green_Alpha_1", "Green_Alpha_2"])
	assert_true(bar.summary()[0]["selected"], "group 1 is lit whatever order its units were picked in")


## Round 9 (CP2): a radar blip reads the hull it stands for. Every blip used to be the same dot, which was fine when
## the roster ran 2.8-5.0 m and throws away what the resize bought now that it runs 2.93-14.0 m.
func test_a_radar_blip_reads_the_hull_it_stands_for() -> void:
	var lengths := {}
	for unit_id: String in ["gang_scout", "tank", "gang_tank"]:
		var hull: Array = Units.stat(unit_id, "hull_size")
		lengths[unit_id] = float(hull[2])
	var measured := {}
	for unit: String in lengths:
		measured[unit] = [lengths[unit], snappedf(Radar.blip_scale(lengths[unit]), 0.01)]
	print("MEASURE radar_blip_scale ", JSON.stringify(measured))
	# Longer hull, bigger mark, in the order the roster actually has them.
	assert_true(Radar.blip_scale(lengths["gang_scout"]) < Radar.blip_scale(lengths["tank"]),
			"the rat rod's mark is smaller than the tank's")
	assert_true(Radar.blip_scale(lengths["tank"]) < Radar.blip_scale(lengths["gang_tank"]),
			"and the tank's is smaller than the rig's")
	# Readable, not to scale: a radar is not a scale drawing, so the spread is bounded.
	var spread := Radar.blip_scale(lengths["gang_tank"]) / Radar.blip_scale(lengths["gang_scout"])
	assert_true(spread > 1.5 and spread < 2.6, "the extremes differ enough to read and not so much as to swamp (%.2f)" % spread)
	# A vehicle we have no handle on -- a remembered contact -- is the standard dot and invents nothing.
	assert_eq(Radar.blip_scale(0.0), 1.0, "an unknown hull is the plain dot")
	# The length is READ from hull_size through the usual seam, so a resize moves it with no table to update here.
	assert_eq(lengths["tank"], float((Units.stat("tank", "hull_size") as Array)[2]), "the length is the hull's own")

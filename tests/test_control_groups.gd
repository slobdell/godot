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


## Round 21 (orders, stretch c): Shift+N ADDS the selection to group N (StarCraft's meaning, kept in round 19), which is
## how "1, then Shift+2" quietly put two squads in group 2. The first time he does it the controls say what it did, once.
func test_shift_number_says_once_that_it_added() -> void:
	var f := await _setup()
	var told: Array = []
	f.controls.notice.connect(func(text: String, _warning: bool) -> void: told.append(text))
	await f.select(["Green_Alpha_1"])
	await f.key(KEY_3, false, true)
	await f.select(["Green_Bravo_2"])
	await f.key(KEY_3, true)
	assert_eq(told.size(), 1, "one line the first time (%s)" % [told])
	if told.size() == 1:
		assert_true(String(told[0]).contains("group 3") and String(told[0]).contains("Ctrl+3"),
				"it names the group and the key that replaces instead (%s)" % told[0])
	await f.select(["Green_Alpha_3"])
	await f.key(KEY_3, true)
	assert_eq(told.size(), 1, "and never again")
	assert_eq(f.controls.groups.members(3).size(), 3, "the adds still happened")


## Round 22 (orders O1, C22.5): ten squads a side, so ten groups. Keys 1–9 are groups 1–9 and 0 is group 10 (the
## keyboard's order, as in StarCraft); MAX_GROUPS is the constant army's garage reads.
func test_ten_groups_and_zero_is_group_ten() -> void:
	assert_eq(ControlGroups.MAX_GROUPS, 10, "ten groups")
	assert_eq(ControlGroups.number_for_key(KEY_1), 1, "1 is group 1")
	assert_eq(ControlGroups.number_for_key(KEY_9), 9, "9 is group 9")
	assert_eq(ControlGroups.number_for_key(KEY_0), 10, "0 is group 10")
	assert_eq(ControlGroups.number_for_key(KEY_A), 0, "a letter is no group")
	for number in range(1, ControlGroups.MAX_GROUPS + 1):
		assert_eq(ControlGroups.number_for_key(ControlGroups.key_for_number(number)), number, "key round trip %d" % number)
	assert_eq(ControlGroups.key_label(10), "0", "group 10 is labelled with its key")
	assert_eq(ControlGroups.key_label(4), "4", "the rest are their number")
	var groups := ControlGroups.new()
	groups.save(10, ["Green_Juliet_1"])
	assert_eq(groups.members(10), ["Green_Juliet_1"], "group 10 holds units")
	assert_eq(groups.numbers(), [10] as Array[int], "and is listed")
	groups.save(11, ["Green_Kilo_1"])
	assert_true(groups.is_empty(11), "there is no group 11")


func test_zero_key_saves_adds_and_recalls_group_ten() -> void:
	var f := await _setup()
	var told: Array = []
	f.controls.notice.connect(func(text: String, _warning: bool) -> void: told.append(text))
	await f.select(["Green_Alpha_1", "Green_Bravo_2"])
	await f.key(KEY_0, false, true)
	assert_eq(f.controls.groups.members(10), ["Green_Alpha_1", "Green_Bravo_2"], "Ctrl+0 saves the selection as group 10")
	await f.click(f.screen("Green_Alpha_2"))
	await f.key(KEY_0)
	assert_eq(f.controls.selection.units, ["Green_Alpha_1", "Green_Bravo_2"], "0 selects group 10 again")
	await f.click(f.screen("Green_Alpha_3"))
	await f.key(KEY_0, true)
	assert_eq(f.controls.groups.members(10), ["Green_Alpha_1", "Green_Alpha_3", "Green_Bravo_2"], "Shift+0 adds to group 10")
	assert_true(told.size() == 1 and String(told[0]).contains("Shift+0") and String(told[0]).contains("Ctrl+0"),
			"the once-a-session line names the 0 key, not 10 (%s)" % [told])
	f.rig.focus = Vector3(-80, 0, -60)
	await f.key(KEY_0)
	await f.key(KEY_0)
	assert_true(f.rig.focus.distance_to(Vector3(-80, 0, -60)) > 10.0, "a quick double 0 centres the camera on group 10")


## The garage's squads 1–10 (Alpha … Juliet) land in groups 1–10, so Juliet is on 0; an eleventh squad (an army file
## from elsewhere) still lands on a key, and squad names with numbers sort as numbers ("Guns10" after "Guns9").
func test_ten_squads_become_groups_one_to_ten() -> void:
	var f := await _setup()
	var names := ["Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet"]
	var squads: Array = []
	for squad_name: String in names:
		squads.append({"name": squad_name, "units": [{"unit": "scout"}]})
	assert_eq(f.game_match.load_doctrine(Match.Team.GREEN, {"name": "Ten", "squads": squads}), "", "eight more squads")
	var groups := ControlGroups.from_squads(f.game_match, Match.Team.GREEN)
	assert_eq(groups.numbers().size(), 10, "ten groups")
	assert_eq(groups.label(1), "Alpha", "Alpha is 1")
	assert_eq(groups.label(9), "India", "India is 9")
	assert_eq(groups.label(10), "Juliet", "Juliet is 10, on the 0 key")
	assert_eq(groups.members(10), ["Green_Juliet_1"], "with its vehicle")
	assert_true(groups.ungrouped(f.game_match, Match.Team.GREEN).is_empty(), "every vehicle is on a key")
	var numbered: Array = []
	for i in range(1, 12):
		numbered.append({"name": "Guns%d" % i, "roster": ["g%d" % i]})
	numbered.shuffle()
	var plan := ControlGroups.plan(ControlGroups.ordered(numbered))
	assert_eq(plan.size(), 10, "eleven squads fill ten groups")
	assert_eq(String(plan[1]["name"]), "Guns2", "Guns2 is the second, not Guns10")
	assert_eq(String(plan[9]["name"]), "Guns10", "Guns10 is the tenth")
	assert_eq(plan[0]["roster"], ["g1", "g11"], "Guns11 joins its family's group, on a key")


## Round 22 (orders O2): ten chips. They keep their size; one row while it fits between the radar and its mirror,
## else two rows in key order (1–5 over 6–0). Group 10's chip says "0", the key that recalls it.
func test_group_bar_rows() -> void:
	assert_eq(GroupBar.rows_for([], 6.0, 1000.0), [] as Array[int], "no chips, no rows")
	assert_eq(GroupBar.rows_for([180.0, 180.0, 180.0, 180.0, 180.0], 6.0, 1206.0), [5] as Array[int], "five fit one row")
	var ten: Array = []
	for i in 10:
		ten.append(180.0)
	assert_eq(GroupBar.rows_for(ten, 6.0, 1206.0), [5, 5] as Array[int], "ten at his window: two rows of five")
	assert_eq(GroupBar.rows_for(ten, 6.0, 2000.0), [10] as Array[int], "a wide enough screen keeps one row")
	assert_eq(GroupBar.rows_for(ten.slice(0, 7), 6.0, 1000.0), [4, 3] as Array[int], "seven: four over three")
	assert_near(GroupBar.room_for(Vector2(1854, 1011)), 1206.0, 1.0, "his window's room is the panel's")


func test_group_bar_shows_ten_chips_in_two_rows() -> void:
	var f := await _setup()
	var trio := ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"]
	for number in range(1, 6):
		f.controls.groups.save(number, trio)
	var bar := GroupBar.new()
	bar.controls = f.controls
	f.controls.add_child(bar)
	await tree.process_frame
	await tree.process_frame
	var rects := bar.chip_rects()
	assert_eq(rects.size(), 5, "five chips")
	assert_true(rects.values().all(func(r: Rect2) -> bool: return is_equal_approx(r.position.y, 0.0)), "five stand in one row")
	for number in range(6, 11):
		f.controls.groups.save(number, trio)
	await tree.process_frame
	await tree.process_frame
	rects = bar.chip_rects()
	assert_eq(rects.size(), 10, "ten chips")
	var top: Rect2 = rects[1]
	var under: Rect2 = rects[6]
	assert_true(under.position.y > top.end.y, "6 stands under 1 (%s, %s)" % [top, under])
	assert_true(is_equal_approx((rects[5] as Rect2).position.y, top.position.y), "1-5 share the top row")
	assert_true(is_equal_approx((rects[10] as Rect2).position.y, under.position.y), "6-0 share the bottom row")
	var viewport := Rect2(Vector2.ZERO, Vector2(tree.root.size))
	for number in rects:
		var r: Rect2 = rects[number]
		assert_true(viewport.encloses(Rect2(bar.position + r.position, r.size)), "chip %d is on the screen" % number)
		for other in rects:
			if other != number:
				assert_true(not r.intersects(rects[other]), "chips %d and %d do not overlap" % [number, other])
	var shown := bar.summary()
	assert_eq(String(shown[9]["key"]), "0", "group 10's chip says 0")
	f.controls.selection.set_units(["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3", "Green_Bravo_1"])
	await tree.process_frame
	assert_true(bar.summary().all(func(g: Dictionary) -> bool: return g["included"]),
			"a squad wholly inside a bigger selection is lit")
	assert_true(not bar.summary()[0]["selected"], "but it is not THE selected group")
	bar.chip_pressed(10)
	assert_eq(f.controls.selection.units, trio, "the 0 chip selects group 10")


## Round 22 (orders O4): his Ctrl+A over fifty vehicles drew a ring round every dot, one yellow blob. Past
## Radar.RINGS_UP_TO selected, each selected squad gets one square round its dots instead; a few selected keep rings.
func test_radar_draws_squares_round_selected_squads_past_a_few() -> void:
	var f := preload("res://tests/support/control_fixture.gd").new(self)
	await f.build_scale(20)
	var radar := Radar.new()
	radar.game_match = f.game_match
	radar.controls = f.controls
	f.controls.add_child(radar)
	radar.read_arena(f.arena)
	await tree.process_frame
	f.controls.selection.set_units(f.controls.groups.members(1).slice(0, 3))
	var marks: Dictionary = radar._marks()
	assert_eq((marks["by_shape"]["ring"] as Array).size(), 3, "three selected: three rings")
	assert_eq((marks["squad_boxes"] as PackedVector2Array).size(), 0, "and no squares")
	var all: Array[String] = []
	for number in f.controls.groups.numbers():
		all.append_array(f.controls.groups.members(number))
	f.controls.selection.set_units(all)
	marks = radar._marks()
	assert_eq((marks["by_shape"]["ring"] as Array).size(), 0, "twenty selected: no rings")
	assert_eq((marks["squad_boxes"] as PackedVector2Array).size(), 4 * 8, "one square (four segments) per squad")
	assert_eq((marks["by_shape"]["disc"] as Array).size(), 20, "every vehicle still a dot")

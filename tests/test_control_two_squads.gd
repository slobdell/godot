extends TestCase
## Round 19 (orders, O3; C19.1). The lead: *"I selected 2 squads and right clicked a point on the map - the resultant
## indicator dots for all the units was all over the map, and a bunch of vehicles just basically ran off to the middle
## of the map."* Two squads ordered together stay two squads: one order each, the same destination, side by side
## across the approach in the order they stand, each travelling from its own position, never one element of ten.

const Fixture := preload("res://tests/support/control_fixture.gd")
## Squad 1 on the west flank, squad 2 on the east one, both facing north; the click is between them, ahead.
const WEST := Vector3(-68, 0, 50)
const EAST := Vector3(68, 0, 50)
const CLICK := Vector3(0, 0, 0)


func _setup() -> Fixture:
	var f := Fixture.new(self)
	await f.build_scale(10)
	_place(f, f.controls.groups.members(1), WEST)
	_place(f, f.controls.groups.members(2), EAST)
	await wait_physics_frames(2)
	return f


func _place(f: Fixture, names: Array[String], at: Vector3) -> void:
	for i in names.size():
		f.place(names[i], at + Vector3((i - 2) * 6.0, 0, 0))


func _both(f: Fixture) -> Array[String]:
	var names: Array[String] = f.controls.groups.members(1) + f.controls.groups.members(2)
	return names


func _to(element: Element) -> Vector3:
	var to: Array = element.task.get("to", [])
	return Vector3(float(to[0]), 0, float(to[1])) if to.size() == 2 else Vector3.INF


## The shared checks: two elements of five, the west squad west of the east one, abreast across the approach (north),
## each anchor within one squad-width of the click and the two at least their half-widths apart.
func _assert_side_by_side(f: Fixture, label: String) -> void:  # awaits: callers `await` it
	var one := f.controls.groups.members(1)
	var two := f.controls.groups.members(2)
	var west := f.controls.elements.of(one[0])
	var east := f.controls.elements.of(two[0])
	assert_true(west != null and east != null and west != east, "%s: two squads, two elements" % label)
	if west == null or east == null or west == east:
		return
	assert_eq(Array(west.members()), Array(one), "%s: squad 1 is still exactly squad 1" % label)
	assert_eq(Array(east.members()), Array(two), "%s: squad 2 is still exactly squad 2" % label)
	for element: Element in f.controls.elements.of_team(Match.Team.GREEN):
		assert_true(element.members().size() <= Formations.MAX_MEMBERS,
				"%s: no element is bigger than a squad (%s has %d)" % [label, element.element_name, element.members().size()])
	var a := _to(west)
	var b := _to(east)
	assert_true(a.x < CLICK.x and b.x > CLICK.x, "%s: west squad left of the click, east squad right of it (%s, %s)" % [label, a, b])
	assert_near(a.z, CLICK.z, 0.5, "%s: abreast across the approach (west)" % label)
	assert_near(b.z, CLICK.z, 0.5, "%s: abreast across the approach (east)" % label)
	# One squad-width: the widest a squad of five can stand (a line, at the doctrine's open spacing), plus the gap.
	var widest := SelectionSquads.width("line", Formations.MAX_MEMBERS) + SelectionSquads.GAP_M
	assert_true(a.distance_to(CLICK) <= widest and b.distance_to(CLICK) <= widest,
			"%s: each squad's anchor within one squad-width of the click (%.1f, %.1f <= %.1f)" % [label, a.distance_to(CLICK), b.distance_to(CLICK), widest])
	# Where every vehicle will stand, once the leaders have planned: no vehicle of one squad within a hull's
	# clearance of the other's, and every one within one squad-width of the click.
	await wait_physics_frames(Element.UPDATE_TICKS + 2)
	var closest := INF
	for x in one:
		for y in two:
			var p: Variant = f.controls.arrival_slot(x)
			var q: Variant = f.controls.arrival_slot(y)
			if p is Vector3 and q is Vector3:
				closest = minf(closest, (p as Vector3).distance_to(q))
	assert_true(closest >= SelectionSquads.GAP_M * 0.5, "%s: the squads' slots do not mix (closest pair %.1f m)" % [label, closest])
	for unit_name in one + two:
		var slot: Variant = f.controls.arrival_slot(unit_name)
		assert_true(slot is Vector3 and (slot as Vector3).distance_to(CLICK) <= widest,
				"%s: %s stands within one squad-width of the click (%s)" % [label, unit_name, slot])


func test_two_squads_selected_together_are_two_orders_side_by_side() -> void:
	var f: Fixture = await _setup()
	f.controls.selection.set_units(_both(f))
	assert_eq(f.controls.selected_group(), 0, "setup: the selection is no control group (a box round both)")
	assert_eq(f.controls.order_selection("move", {"to": [CLICK.x, CLICK.z]}), "", "the order is taken")
	await _assert_side_by_side(f, "selected")


func test_one_group_over_both_squads_is_still_two_squads() -> void:
	var f: Fixture = await _setup()
	f.controls.selection.set_units(_both(f))
	f.controls.groups.save(3, _both(f))  # Ctrl+3 over both
	f.controls.recall_group(3)
	assert_eq(f.controls.selected_group(), 3, "setup: the selection is group 3, which holds both squads")
	assert_eq(f.controls.order_selection("move", {"to": [CLICK.x, CLICK.z]}), "", "the order is taken")
	await _assert_side_by_side(f, "grouped")


func test_through_a_real_right_click() -> void:
	var f: Fixture = await _setup()
	f.controls.selection.set_units(_both(f))
	await f.right_click(f.ground(CLICK))
	await _assert_side_by_side(f, "right-click")


func test_each_squad_travels_from_its_own_position() -> void:
	var f: Fixture = await _setup()
	f.controls.selection.set_units(_both(f))
	f.controls.order_selection("move", {"to": [CLICK.x, CLICK.z]})
	await wait_physics_frames(Element.UPDATE_TICKS + 2)
	for entry: Array in [[1, WEST], [2, EAST]]:
		var element := f.controls.elements.of(f.controls.groups.members(int(entry[0]))[0])
		assert_true(element != null and element.in_transit(), "squad %d travels as a formation" % entry[0])
		if element == null or element.transit.is_empty():
			continue
		var from: Vector3 = (element.transit["route"] as Array)[0]
		assert_true(from.distance_to(entry[1]) < 6.0,
				"squad %d's route starts at its own centre %s, not the middle of both (%s)" % [entry[0], entry[1], from])
		# Its crews' first stations are on its own side of the click: nobody is sent across to the other flank.
		for unit_name in element.members():
			var goal: Variant = f.orders.goal_position(unit_name)
			if goal is Vector3:
				assert_true(signf((goal as Vector3).x - CLICK.x) == signf((entry[1] as Vector3).x - CLICK.x),
						"%s's first station stays on its own side (x %.1f)" % [unit_name, (goal as Vector3).x])


func test_each_squad_keeps_its_own_formation_in_a_joint_order() -> void:
	var f: Fixture = await _setup()
	f.controls.recall_group(1)
	f.controls.set_formation("line")
	f.controls.recall_group(2)
	f.controls.set_formation("column")
	f.controls.selection.set_units(_both(f))
	assert_eq(f.controls.formation, RtsControls.MIXED_FORMATION, "two squads in two formations read as mixed")
	f.controls.order_selection("move", {"to": [CLICK.x, CLICK.z]})
	var west := f.controls.elements.of(f.controls.groups.members(1)[0])
	var east := f.controls.elements.of(f.controls.groups.members(2)[0])
	assert_eq(String(west.task.get("formation", "")), "line", "squad 1 goes in its Line")
	assert_eq(String(east.task.get("formation", "")), "column", "squad 2 goes in its Column")


func test_a_drawn_heading_lays_them_across_it() -> void:
	var f: Fixture = await _setup()
	f.controls.selection.set_units(_both(f))
	f.controls.order_selection("move", {"to": [CLICK.x, CLICK.z], "facing": [1.0, 0.0]})  # face east
	var a := _to(f.controls.elements.of(f.controls.groups.members(1)[0]))
	var b := _to(f.controls.elements.of(f.controls.groups.members(2)[0]))
	assert_near(a.x, CLICK.x, 0.5, "facing east: the squads stand north-south of each other (squad 1)")
	assert_near(b.x, CLICK.x, 0.5, "facing east: the squads stand north-south of each other (squad 2)")
	assert_true(absf(a.z - b.z) > 20.0, "and apart (%s, %s)" % [a, b])


func test_one_squad_still_goes_exactly_where_he_clicked() -> void:
	var f: Fixture = await _setup()
	f.controls.recall_group(1)
	f.controls.order_selection("move", {"to": [CLICK.x, CLICK.z]})
	var element := f.controls.elements.of(f.controls.groups.members(1)[0])
	assert_eq(_to(element), CLICK, "a single squad's task is the click itself, as before")


func test_squads_and_loose_units_each_get_their_own_place() -> void:
	var f: Fixture = await _setup()
	var one := f.controls.groups.members(1)
	var two := f.controls.groups.members(2)
	f.controls.selection.set_units(one + [two[0], two[1]])
	assert_eq(f.controls.order_selection("move", {"to": [CLICK.x, CLICK.z]}), "", "the order is taken")
	var west := f.controls.elements.of(one[0])
	assert_true(west != null and west.members().size() == one.size(), "squad 1 got a task as squad 1")
	for unit_name in [two[0], two[1]]:
		var order := f.orders.current(unit_name)
		assert_eq(String(order.get("source", "")), "player", "%s (in no squad of the selection) got a direct order" % unit_name)
		assert_true(f.controls.elements.of(unit_name) == null, "%s is in no element" % unit_name)
		var goal: Variant = f.orders.goal_position(unit_name)
		assert_true(goal is Vector3 and (goal as Vector3).x > _to(west).x, "%s stands east of squad 1, the side it came from" % unit_name)


func test_a_whole_group_bigger_than_a_squad_is_dealt_into_squads() -> void:
	var f: Fixture = await _setup()
	var all := _both(f)
	f.controls.groups.save(1, all)  # one group of ten and nothing smaller inside it
	f.controls.groups.save(2, [])
	f.controls.recall_group(1)
	assert_eq(f.controls.order_selection("move", {"to": [CLICK.x, CLICK.z]}), "", "the order is taken")
	var found := {}
	for unit_name in all:
		var element := f.controls.elements.of(unit_name)
		assert_true(element != null, "%s is in a squad" % unit_name)
		if element != null:
			found[element.id] = element.members().size()
	assert_eq(found.size(), 2, "ten vehicles became two squads")
	for size: int in found.values():
		assert_eq(size, 5, "of five each")


func test_elements_refuse_more_than_a_squad_loudly() -> void:
	var f: Fixture = await _setup()
	expect_error("more than one squad")
	var element := f.controls.elements.form(_both(f), "Heap")
	assert_true(element == null, "an element of ten is refused")
	for unit_name in _both(f):
		assert_true(f.controls.elements.of(unit_name) == null, "%s was left where it was" % unit_name)


## O4: the dots tell the truth before the vehicles move. A cross per vehicle where it will stand (not at the station
## a travelling squad hands it) and a square per squad at its anchor, on the radar; the ground draws the same points.
func test_the_radar_shows_each_vehicle_where_it_will_stand_and_each_squad_its_place() -> void:
	var f: Fixture = await _setup()
	var radar := Radar.new()
	radar.game_match = f.game_match
	radar.controls = f.controls
	f.controls.add_child(radar)
	f.controls.selection.set_units(_both(f))
	f.controls.order_selection("move", {"to": [CLICK.x, CLICK.z]})
	await wait_physics_frames(Element.UPDATE_TICKS + 2)
	var pins := f.controls.order_marks()
	assert_eq(pins.size(), 2, "one pin on the ground per squad, not one per vehicle (%d)" % pins.size())
	for pin: Dictionary in pins:
		assert_eq(int(pin["units"]), 5, "each pin counts its squad's five")
	var anchors := f.controls.selected_squad_anchors()
	assert_eq(anchors.size(), 2, "one anchor per squad (%s)" % [anchors])
	var kinds := {}
	for blip: Dictionary in radar.blips():
		kinds[blip["kind"]] = int(kinds.get(blip["kind"], 0)) + 1
		if blip["kind"] == "destination":
			assert_true((blip["position"] as Vector3).distance_to(CLICK) <= SelectionSquads.width("line", 5) + SelectionSquads.GAP_M,
					"every cross is near the click, none at a station back on the flanks (%s)" % blip["position"])
	assert_eq(int(kinds.get("squad_anchor", 0)), 2, "two squares on the radar, one per squad")
	assert_true(int(kinds.get("destination", 0)) >= 8, "a cross per vehicle (%d; two may share a 4 m cell)" % int(kinds.get("destination", 0)))
	for unit_name in _both(f):
		var route := f.controls.shown_route(unit_name)
		assert_true(not route.is_empty() and (route[0]["position"] as Vector3).is_equal_approx(f.controls.arrival_slot(unit_name)),
				"%s's dot on the ground is its arrival slot" % unit_name)


## Round 21 (orders, O1/O2; C21.4): five squads of five, one click 150 m ahead, stand as a body (at most three
## abreast, within SelectionSquads.MAX_FRONTAGE_M, the rest behind), not the 400 m row whose outer squads the wall
## pinned at ±116 m in his round-20 games. Five elements of five; every anchor inside the arena without the clamp
## moving it; no two squads' slots mixed.
func test_five_squads_one_click_go_as_a_body() -> void:
	var f := Fixture.new(self)
	await f.build_scale(25)
	var squads: Array = []
	for number in range(1, 6):
		var names := f.controls.groups.members(number)
		assert_eq(names.size(), 5, "setup: group %d is a squad of five" % number)
		_place(f, names, Vector3((number - 3) * 50.0, 0, 100))
		squads.append(names)
	await wait_physics_frames(2)
	var all: Array[String] = []
	for names: Array[String] in squads:
		all.append_array(names)
	f.controls.selection.set_units(all)
	var click := Vector3(0, 0, -50)
	assert_eq(f.controls.order_selection("attack_move", {"to": [click.x, click.z]}), "", "the order is taken")
	var anchors: Array[Vector3] = []
	var ranks := {}
	for names: Array[String] in squads:
		var element := f.controls.elements.of(names[0])
		assert_true(element != null and Array(element.members()) == Array(names), "squad of %s stays exactly itself" % names[0])
		if element == null:
			return
		var at := _to(element)
		anchors.append(at)
		ranks[snappedf(at.z, 0.5)] = true
		assert_eq(Orders.clamp_to_arena(at), at, "%s's anchor needs no clamp (%s)" % [names[0], at])
		assert_true(at.z >= click.z - 0.5, "%s does not stand past the click (%s)" % [names[0], at])
	assert_true(ranks.size() >= 2, "the five stand in ranks, not one row (%d)" % ranks.size())
	var west := INF
	var east := -INF
	for at in anchors:
		west = minf(west, at.x)
		east = maxf(east, at.x)
	var widest := SelectionSquads.width("line", 5, 14.0)
	assert_true(east - west + widest <= SelectionSquads.MAX_FRONTAGE_M + 0.5,
			"the body is at most %.0f m across (anchors span %.1f m)" % [SelectionSquads.MAX_FRONTAGE_M, east - west])
	await wait_physics_frames(Element.UPDATE_TICKS + 2)
	var closest := INF
	for a in squads.size():
		for b in range(a + 1, squads.size()):
			for x: String in squads[a]:
				for y: String in squads[b]:
					var p: Variant = f.controls.arrival_slot(x)
					var q: Variant = f.controls.arrival_slot(y)
					if p is Vector3 and q is Vector3:
						closest = minf(closest, (p as Vector3).distance_to(q))
	assert_true(closest >= SelectionSquads.GAP_M * 0.5, "no two squads' slots mix (closest pair %.1f m)" % closest)


## Round 23 (orders O1; decided by the lead at the launch): two squads in COLUMN ordered side by side stand
## SelectionSquads.COLUMN_GAP_M (28 m) apart, centre line to centre line, centred on the click. A column has no
## frontage, so until now the gap alone (14 m) stood between two snaking files, and on his Sumps match the two files
## came within 5 m of each other while driving.
func _order_both_in(f: Fixture, one: String, two: String) -> Array[Vector3]:
	f.controls.recall_group(1)
	f.controls.set_formation(one)
	f.controls.recall_group(2)
	f.controls.set_formation(two)
	f.controls.selection.set_units(_both(f))
	assert_eq(f.controls.order_selection("move", {"to": [CLICK.x, CLICK.z]}), "", "the order is taken")
	var west := f.controls.elements.of(f.controls.groups.members(1)[0])
	var east := f.controls.elements.of(f.controls.groups.members(2)[0])
	assert_true(west != null and east != null and west != east, "%s + %s: two squads, two elements" % [one, two])
	if west == null or east == null:
		return []
	return [_to(west), _to(east)]


func test_two_columns_side_by_side_stand_28_m_apart() -> void:
	var f: Fixture = await _setup()
	var to := _order_both_in(f, "column", "column")
	if to.is_empty():
		return
	assert_near(to[0].distance_to(to[1]), SelectionSquads.COLUMN_GAP_M, 0.05,
			"two columns' centre lines stand COLUMN_GAP_M apart (%s, %s)" % [to[0], to[1]])
	assert_near(to[0].z, CLICK.z, 0.5, "abreast across the approach (west column)")
	assert_near(to[1].z, CLICK.z, 0.5, "abreast across the approach (east column)")
	assert_true(to[0].x < CLICK.x and to[1].x > CLICK.x, "one file each side of the click (%s, %s)" % [to[0], to[1]])
	assert_near(((to[0] + to[1]) * 0.5).distance_to(CLICK), 0.0, 0.05, "the pair is centred on the click")


func test_two_lines_side_by_side_stand_where_they_did() -> void:
	await _assert_pair_unchanged("line")


func test_two_vees_side_by_side_stand_where_they_did() -> void:
	await _assert_pair_unchanged("vee")


## Unchanged to the metre by O1: each squad's own frontage plus one GAP_M, at the pitch the squads are laid at.
func _assert_pair_unchanged(shape: String) -> void:
	var f: Fixture = await _setup()
	var to := _order_both_in(f, shape, shape)
	if to.is_empty():
		return
	# The pitch the controls lay a squad at before it has an element (its doctrine's open spacing, floored).
	var pitch: float = (f.controls._squad_pitch({"units": f.controls.groups.members(1), "element": null}) as Vector2).x
	var expected := SelectionSquads.width(shape, Formations.MAX_MEMBERS, pitch) + SelectionSquads.GAP_M
	assert_near(to[0].distance_to(to[1]), expected, 0.05,
			"two %ss stand their frontage plus one gap apart: %.1f m (COLUMN_GAP_M does not reach them)" % [shape, expected])
	assert_true(absf(expected - SelectionSquads.COLUMN_GAP_M) > 1.0, "setup: %s's spacing is not the columns' number" % shape)

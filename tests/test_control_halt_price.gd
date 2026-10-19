extends TestCase
## Round 34 (C34.11, O3): an AUTO squad is priced at the shape it will ARRIVE in, its doctrine's halt on the clicked
## ground (SelectionSquads.halt_shape / halt_footprint), not a line's frontage. Brains' B6 trace: an arriving element
## re-lays into the table's hold pick (coil in the open; herringbone in lanes or dense ground), led FACE_LEAD to its
## sectors. `--halt-price=off` (HALT_PRICE false) is round 33's line.

const Fixture := preload("res://tests/support/control_fixture.gd")


func teardown() -> void:
	SelectionSquads.HALT_PRICE = true
	SelectionSquads.halt_terrain = ""
	super.teardown()


func test_the_halt_is_the_doctrines_hold_pick_by_ground() -> void:
	var tanks := ["tank", "tank", "ifv", "ifv", "scout"]
	assert_eq(SelectionSquads.halt_shape(DoctrineTable.for_faction("law"), "open", tanks), "coil", "law, open: a coil")
	assert_eq(SelectionSquads.halt_shape(DoctrineTable.for_faction("law"), "lanes", tanks), "herringbone", "law, lanes")
	assert_eq(SelectionSquads.halt_shape(DoctrineTable.for_faction("law"), "dense", tanks), "herringbone", "law, dense")
	assert_eq(SelectionSquads.halt_shape(DoctrineTable.for_faction("gangs"), "lanes", tanks), "coil", "the gangs coil anywhere")
	assert_eq(SelectionSquads.halt_shape(DoctrineTable.for_faction("syndicate"), "open", tanks), "line", "the syndicate halts in a line")


func test_a_halt_footprint_is_where_its_seats_stand() -> void:
	var line := SelectionSquads.halt_footprint("line", 5, 14.0)
	var coil := SelectionSquads.halt_footprint("coil", 5, 14.0)
	var herring := SelectionSquads.halt_footprint("herringbone", 5, 14.0)
	print("MEASURE halt_footprint 5 at 14 m: line %.1f x %.1f, coil %.1f x %.1f, herringbone %.1f x %.1f" % [
			line.x, line.y, coil.x, coil.y, herring.x, herring.y])
	assert_near(line.x, 57.2, 0.5, "a line's halt is about as wide as the line")
	assert_true(coil.x < line.x * 0.75 and herring.x < coil.x, "a coil is narrower than a line, a herringbone narrower still")
	assert_true(herring.y > coil.y, "a herringbone is the deepest halt")


func _three_in_the_open(f: Fixture) -> Array:
	var squads: Array = []
	for number in range(1, 4):
		var names := f.controls.groups.members(number)
		for i in names.size():
			f.place(names[i], Vector3((number - 2) * 40.0 + (i - 2) * 6.0, 0, 90))
		squads.append(names)
	return squads


func _anchors(f: Fixture, squads: Array) -> Array[Vector3]:
	var at: Array[Vector3] = []
	for names: Array[String] in squads:
		var element := f.controls.elements.of(names[0])
		var to: Array = element.task.get("to", []) if element != null else []
		at.append(Vector3(float(to[0]), 0, float(to[1])) if to.size() == 2 else Vector3.INF)
	return at


## Three AUTO squads of five, one click: abreast, centre to centre one halt's width plus the gap, not a line's.
func test_three_auto_squads_stand_a_halts_width_apart() -> void:
	var f := Fixture.new(self)
	await f.build_scale(15)
	var squads := _three_in_the_open(f)
	await wait_physics_frames(2)
	var all: Array[String] = []
	for names: Array[String] in squads:
		all.append_array(names)
	f.controls.selection.set_units(all)
	assert_eq(f.controls.order_selection("move", {"to": [0.0, 0.0]}), "", "the order is taken")
	var anchors := _anchors(f, squads)
	var xs := anchors.map(func(p: Vector3) -> float: return p.x)
	var spread := float(xs.max()) - float(xs.min())
	var shape := SelectionSquads.squad_halt_shape(squads[0], null, f.game_match)
	var halt := SelectionSquads.halt_footprint(shape, 5, SelectionSquads.SPACING_M)
	var line := SelectionSquads.width("line", 5, SelectionSquads.SPACING_M)
	print("MEASURE three_auto_squads (%s on '%s'): outer anchors %.1f m apart; halt-priced %.1f, line-priced %.1f" % [
			shape, SelectionSquads.halt_terrain, spread, 2.0 * (halt.x + SelectionSquads.GAP_M), 2.0 * (line + SelectionSquads.GAP_M)])
	assert_true(spread < 2.0 * (line + SelectionSquads.GAP_M) - 10.0, "closer than a line's price (%.1f m)" % spread)
	assert_true(spread >= 2.0 * (halt.x + SelectionSquads.GAP_M) - 1.0, "but never closer than their halts (%.1f m)" % spread)

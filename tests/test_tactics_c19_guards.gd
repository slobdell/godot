extends TestCase
## Round 19 (brains B5, C19.1): two squads are never one element, on the tactics side. His two-squad right-click
## (2026-10-05: "the resultant indicator dots for all the units was all over the map, and a bunch of vehicles just
## basically ran off to the middle of the map") came from ONE element of ~10 vehicles whose transit started at the
## centroid of two squads on opposite flanks. Orders now sends one order per squad and lent us the guard in
## Elements.form; these are the element machinery's own guards.


func _lab(arena := "") -> TacticsLab:
	return TacticsLab.create(self, 3, arena)


## The lent guard (orders' line, C19.1): more than Formations.MAX_MEMBERS living members is refused, loudly, and
## nobody is taken out of the element it was in.
func test_form_refuses_more_than_one_squad_and_moves_nobody() -> void:
	var lab := _lab()
	var first: Array = []
	var second: Array = []
	for i in 3:
		first.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1), Vector3(-30 + i * 8, 0, 60), 0.0).name))
		second.append(String(lab.unit(Match.Team.GREEN, "Green_B_%d" % (i + 1), Vector3(30 + i * 8, 0, 60), 0.0).name))
	await lab.start()
	var alpha := lab.elements.form(first, "Alpha")
	var bravo := lab.elements.form(second, "Bravo")
	expect_error("more than one squad")
	var heap: Variant = lab.elements.form(first + second, "Heap")
	assert_true(heap == null, "six crews (%d > MAX_MEMBERS %d) are refused" % [6, Formations.MAX_MEMBERS])
	assert_eq(alpha.members().size(), 3, "Alpha keeps its crews")
	assert_eq(bravo.members().size(), 3, "Bravo keeps its crews")
	assert_true(lab.elements.of(String(first[0])) == alpha, "a crew still answers to its own element")
	lab.dispose()


## The transit's start: the centroid only when the crews stand within one formation width of each other.
func test_a_compact_element_starts_its_transit_at_its_centre() -> void:
	var members: Array = []
	for i in 4:
		members.append({"name": "U%d" % i, "position": Vector3(-15.0 + i * 10.0, 0, 50)})
	var situation := {"center": Vector3(0, 0, 50), "members": members, "leader": "U0"}
	assert_eq(Element.transit_origin(situation, 14.0), Vector3(0, 0, 50), "a squad abreast at its own spacing")


func test_a_split_element_starts_its_transit_at_its_lead_vehicle() -> void:
	# Two pairs on opposite flanks, 150 m apart: their centroid is the middle of the map.
	var members: Array = [{"name": "U0", "position": Vector3(-80, 0, 60)}, {"name": "U1", "position": Vector3(-72, 0, 60)},
			{"name": "U2", "position": Vector3(72, 0, 60)}, {"name": "U3", "position": Vector3(80, 0, 60)}]
	var situation := {"center": Vector3(0, 0, 60), "members": members, "leader": "U2"}
	assert_eq(Element.transit_origin(situation, 14.0), Vector3(72, 0, 60), "not the empty middle: the lead vehicle")


## ElementPlan.clamp_to_arena reads the arena's shape (the dealt maps are hexagons) by the rule every order uses.
func test_the_element_clamp_keeps_a_point_inside_the_hexagon() -> void:
	var lab := _lab("parade")
	await lab.start()
	var corner := Vector3(150, 0, 150)
	var clamped := ElementPlan.clamp_to_arena(corner)
	var square := Vector3(Match.DRIVABLE_LIMIT, 0, Match.DRIVABLE_LIMIT)
	assert_true(not Arena.contains(square), "positive control: the old square corner (116, 116) is OUTSIDE parade's hexagon")
	assert_true(Arena.contains(clamped), "the clamped corner is inside the arena (%s)" % clamped)
	var by_orders := Orders.clamp_to_arena(corner)
	assert_eq(clamped, Vector3(by_orders.x, 0, by_orders.z), "the same point an order would be sent to")
	assert_eq(ElementPlan.clamp_to_arena(Vector3(10, 0, -20)), Vector3(10, 0, -20), "a point inside is left alone")
	lab.dispose()


## Element.remove tells the brains: Elements emits element_changed (and disbands an element left empty), whoever called.
func test_removing_a_crew_directly_announces_the_change() -> void:
	var lab := _lab()
	var names: Array = []
	for i in 2:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_R_%d" % (i + 1), Vector3(i * 8, 0, 60), 0.0).name))
	await lab.start()
	var element := lab.elements.form(names, "Alpha")
	var heard: Array = []
	lab.elements.element_changed.connect(func(id: int) -> void: heard.append(id))
	element.remove(String(names[0]))
	assert_true(heard.has(element.id), "element_changed for the element a crew left (%s)" % [heard])
	assert_true(lab.elements.of(String(names[0])) == null, "the crew no longer answers to it")
	heard.clear()
	element.remove(String(names[1]))
	assert_true(heard.has(element.id), "and when the last crew leaves (%s)" % [heard])
	assert_true(not lab.elements.by_id.has(element.id), "an element left empty is disbanded")
	lab.dispose()

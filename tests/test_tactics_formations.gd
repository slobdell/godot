extends TestCase
## Doctrine X1/X2: the geometry of movement formations, and the properties that make each one worth using
## (_agents/doctrine.md "Why formations pay off"). Pure math: no scene, no physics.


func test_a_column_is_single_file_and_a_line_is_abreast() -> void:
	var column := TacticsFormation.offsets("column", 4, 10.0)
	for i in 4:
		assert_near(column[i].x, 0.0, 0.01, "a column has nobody out to the side")
		assert_near(column[i].y, i * 10.0, 0.01, "each vehicle follows the one ahead at the spacing")
	var line := TacticsFormation.offsets("line", 4, 10.0)
	for slot in line:
		assert_near(slot.y, 0.0, 0.01, "a line has nobody in front of anybody")
	assert_near(TacticsFormation.frontage("line", 4, 10.0), 30.0, 0.01, "four abreast at 10 m is 30 m wide")
	assert_near(TacticsFormation.depth("line", 4, 10.0), 0.0, 0.01, "and has no depth")


func test_a_wedge_puts_the_leader_in_front_and_the_rest_out_to_both_sides() -> void:
	var wedge := TacticsFormation.offsets("wedge", 5, 12.0)
	assert_eq(wedge[0], Vector2.ZERO, "the leader is the point of the wedge")
	var left := 0
	var right := 0
	for i in range(1, 5):
		assert_true(wedge[i].y > 0.0, "every follower is behind the leader")
		if wedge[i].x < 0.0:
			left += 1
		else:
			right += 1
	assert_eq(left, 2, "two vehicles echelon to the left")
	assert_eq(right, 2, "two vehicles echelon to the right")
	assert_true(TacticsFormation.frontage("wedge", 5, 12.0) > TacticsFormation.frontage("column", 5, 12.0),
			"a wedge is wider than a column: more guns can bear forward")
	assert_true(TacticsFormation.depth("column", 5, 12.0) > TacticsFormation.depth("wedge", 5, 12.0),
			"a column is deeper: it exposes fewer vehicles to fire from the front")


func test_a_vee_leads_with_two_vehicles_and_an_echelon_leans_to_one_side() -> void:
	var vee := TacticsFormation.offsets("vee", 3, 12.0)
	assert_true(vee[1].y < 0.0 and vee[2].y < 0.0, "a V puts two vehicles ahead of the leader")
	assert_true(vee[1].x * vee[2].x < 0.0, "one to each side")
	var right := TacticsFormation.offsets("echelon_right", 3, 12.0)
	for slot in right:
		assert_true(slot.x >= 0.0, "an echelon right steps back and to the right, covering that flank")
	var left := TacticsFormation.offsets("echelon_left", 3, 12.0)
	for slot in left:
		assert_true(slot.x <= 0.0, "an echelon left covers the other one")


func test_a_herringbone_alternates_the_flanks_it_watches() -> void:
	var sectors := TacticsFormation.sectors("herringbone", 4)
	assert_near(sectors[0], 0.0, 0.01, "the lead vehicle still watches ahead")
	assert_true(sectors[1] < -45.0 and sectors[2] > 45.0, "the middle vehicles turn out to opposite flanks")
	assert_near(sectors[3], 180.0, 0.01, "and the last one watches the rear")
	assert_true(TacticsFormation.coverage("herringbone", 4) > 0.95, "so a halted element watches all round")
	var slots := TacticsFormation.offsets("herringbone", 4, 10.0)
	assert_true(slots[0].x * slots[1].x < 0.0, "vehicles pull off the axis to alternate sides")
	assert_true(TacticsFormation.coverage("herringbone", 4) > TacticsFormation.coverage("line", 4),
			"a herringbone at a halt watches far more of the circle than a firing line")


func test_sectors_of_fire_cover_the_element_where_its_shape_is_blind() -> void:
	assert_near(TacticsFormation.sectors("column", 4)[0], 0.0, 0.01, "the lead vehicle of a column watches ahead")
	assert_near(TacticsFormation.sectors("column", 4)[3], 180.0, 0.01, "the last one watches behind")
	var middle := TacticsFormation.sectors("column", 4)
	assert_true(absf(middle[1]) > 45.0 and absf(middle[2]) > 45.0, "the middle of a column watches its flanks")
	assert_true(TacticsFormation.coverage("column", 4) > 0.9, "a column in movement covers nearly all round")
	assert_true(TacticsFormation.coverage("line", 4) < 0.5, "a line sees a narrow front: that is what it trades")
	for name in TacticsFormation.NAMES:
		assert_eq(TacticsFormation.sectors(name, 5).size(), 5, "%s assigns every vehicle a sector" % name)


func test_spreading_out_is_what_saves_an_element_from_one_shell() -> void:
	# Splash and a burst hit what is bunched: doctrine's "dispersion" as a measurable number.
	var tight := TacticsFormation.closest_pair("wedge", 5, 6.0)
	var loose := TacticsFormation.closest_pair("wedge", 5, 14.0)
	assert_true(loose > tight + 5.0, "wider spacing puts more meters between the two closest vehicles")
	assert_true(TacticsFormation.closest_pair("line", 5, 12.0) >= 11.99,
			"nobody in a line is closer to a neighbour than the spacing")


func test_slots_land_where_the_element_is_pointed() -> void:
	var anchor := Vector3(10.0, 0.0, -20.0)
	var heading := Vector3(0.0, 0.0, -1.0)  # north: forward is -Z
	var ahead := TacticsFormation.to_world(anchor, heading, Vector2(0.0, -10.0))
	assert_near(ahead.z, -30.0, 0.01, "a slot 10 m 'forward' is 10 m further north")
	var right := TacticsFormation.to_world(anchor, heading, Vector2(10.0, 0.0))
	assert_near(right.x, 20.0, 0.01, "and a slot to the right is to the east when facing north")
	assert_true(TacticsFormation.facing_of("herringbone", 0, 4, heading).z < -0.5,
			"the lead vehicle of a herringbone still faces the way the element was driving")
	assert_true(TacticsFormation.facing_of("herringbone", 2, 4, heading).x > 0.5,
			"a middle vehicle faces out to the flank it watches")
	assert_near(TacticsFormation.rotate(heading, deg_to_rad(90.0)).x, 1.0, 0.01,
			"rotating a heading 90 degrees right of north points east")


func test_centering_moves_the_shape_onto_the_anchor_without_changing_it() -> void:
	var raw := TacticsFormation.offsets("column", 4, 10.0)
	var centered := TacticsFormation.centered(raw)
	var middle := Vector2.ZERO
	for slot in centered:
		middle += slot
	assert_near(middle.length(), 0.0, 0.01, "a centered shape has its middle on the anchor")
	assert_near(centered[1].distance_to(centered[0]), raw[1].distance_to(raw[0]), 0.01,
			"and the vehicles are still the same distance apart")


func test_the_swarm_is_wider_and_raggeder_than_anything_in_a_manual() -> void:
	# The road gangs' shape (the lead: "noticeably less military disciplined ... spreading out their
	# formations wide for better survivability").
	var swarm := TacticsFormation.offsets("swarm", 6, 12.0)
	assert_true(TacticsFormation.frontage("swarm", 6, 12.0) > TacticsFormation.frontage("line", 6, 12.0) * 1.5,
			"a swarm spreads far wider than a firing line")
	var depths := {}
	for slot in swarm:
		depths[snappedf(slot.y, 0.1)] = true
	assert_true(depths.size() >= 3, "and it has no line to shoot along: vehicles sit at different depths")
	assert_true(TacticsFormation.closest_pair("swarm", 6, 12.0) > TacticsFormation.closest_pair("line", 6, 12.0),
			"spread wide, one shell can only ever reach one of them")


func test_a_ring_surrounds_what_it_is_anchored_on() -> void:
	var ring := TacticsFormation.offsets("ring", 6, 12.0)
	var middle := Vector2.ZERO
	var radius := 0.0
	for slot in ring:
		middle += slot
		radius = maxf(radius, slot.length())
	assert_near((middle / 6.0).length(), 0.0, 0.5, "a ring is centred on its anchor: the enemy, not a heading")
	assert_true(radius > 20.0, "and stands off it (%.1f m)" % radius)
	var behind := 0
	for slot in ring:
		if slot.y > 1.0:
			behind += 1
	assert_true(behind >= 2, "with vehicles on the far side of the target, not just in front of it")


func test_the_exposed_slots_go_to_whatever_can_take_a_hit() -> void:
	# The lead: "heavy armor on the outside of a column, light armor on the inside."
	var members: Array = [
		{"name": "Lead", "unit": "tank", "role": "tank"},
		{"name": "Gun", "unit": "artillery", "role": "artillery"},
		{"name": "Heavy", "unit": "tank", "role": "tank"},
		{"name": "Eyes", "unit": "scout", "role": "scout"}]
	var line := TacticsFormation.centered(TacticsFormation.offsets("line", 4, 12.0))
	var seating := TacticsFormation.seat(members, line, Vector3.ZERO, Vector3.FORWARD,
			{"leader": "Lead", "policy": "exposure"})
	# seats[slot] = member index, as the pre-N2 by_exposure returned it.
	var seats: Array = []
	seats.resize(members.size())
	for i in members.size():
		seats[int(seating[String(members[i]["name"])])] = i
	assert_eq(seats[0], 0, "the leader keeps its place in the shape")
	var outermost := 0
	for i in range(1, line.size()):
		if absf(line[i].x) > absf(line[outermost].x):
			outermost = i
	assert_eq(String(members[seats[outermost]]["name"]), "Heavy",
			"the outside of a line is the armoured vehicle's place")
	var innermost := 1
	for i in range(1, line.size()):
		if TacticsFormation.exposure_of(line[i]) < TacticsFormation.exposure_of(line[innermost]):
			innermost = i
	assert_eq(String(members[seats[innermost]]["name"]), "Gun", "the artillery stands where the least fire goes")
	assert_true(TacticsFormation.toughness_of(members[0]) > TacticsFormation.toughness_of(members[3]),
			"a tank can take more than a scout, which is what decides this")
	assert_true(TacticsFormation.toughness_of(members[3]) > TacticsFormation.toughness_of(members[1]),
			"and artillery goes inboard of even a scout: on paper it has the thicker armour, but it is the "
			+ "thing the element is out there to keep alive")


func test_the_ends_of_a_column_are_the_exposed_places() -> void:
	var column := TacticsFormation.centered(TacticsFormation.offsets("column", 4, 12.0))
	var ends := TacticsFormation.exposure_of(column[3])
	var middle := TacticsFormation.exposure_of(column[1])
	assert_true(ends > middle, "the tail of a column is more exposed than its middle (%.1f vs %.1f)"
			% [ends, middle])

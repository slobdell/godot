extends TestCase
## Round 21 (brains stretch d; orders' R1, measured on builder0, parade seed 3): a slot asked for INSIDE parade's bay
## row of 40 ft containers (x 55-101, z = -23) was grounded to the NEAREST standable point, the row's far (south) face
## (75.4, -26.5) -> (75.4, -28.3); the crew coming from the north drove round the west end and ended blocked 26 m
## short. Grounded from the side its element reaches it from, it lands on the near face instead.


func _parade() -> TacticsLab:
	var lab := TacticsLab.create(self, 3, "parade")
	await lab.start()
	return lab


func test_a_slot_inside_the_container_row_lands_on_the_side_the_element_comes_from() -> void:
	var lab: TacticsLab = await _parade()
	var env := SlotGround.envelope_of("law_tank")
	var asked := Vector3(75.4, 0.0, -26.5)
	var nearest := SlotGround.standable_for(lab.arena, asked, env)
	assert_true(nearest.z < -26.0, "the nearest point is the far (south) face, as orders measured: %s" % nearest)
	var north := Vector3(75.4, 0.0, 10.0)
	var from_north := SlotGround.standable_from(lab.arena, asked, env, north)
	assert_true(from_north.z > -21.0, "from the north: the north face (%s)" % from_north)
	assert_true(SlotGround.reached_directly(lab.arena, north, from_north), "and it is driven to without going round")
	assert_true(not SlotGround.reached_directly(lab.arena, north, nearest), "the old answer was a drive round the end")
	var south := Vector3(75.4, 0.0, -60.0)
	var from_south := SlotGround.standable_from(lab.arena, asked, env, south)
	assert_true(from_south.distance_to(nearest) < 1.0, "from the south the near face IS the nearest: unchanged (%s)" % from_south)
	lab.dispose()


func test_a_slot_that_needs_no_push_and_the_control_arm_are_unchanged() -> void:
	var lab: TacticsLab = await _parade()
	var env := SlotGround.envelope_of("law_tank")
	var open := Vector3(75.4, 0.0, -10.0)
	assert_eq(SlotGround.standable_from(lab.arena, open, env, Vector3(75.4, 0.0, 40.0)),
			SlotGround.standable_for(lab.arena, open, env), "standable already: the same answer")
	var asked := Vector3(75.4, 0.0, -26.5)
	assert_eq(SlotGround.standable_from(lab.arena, asked, env, null), SlotGround.standable_for(lab.arena, asked, env),
			"no element position: the nearest, as before")
	SlotGround.SIDE_ENABLED = false
	var control := SlotGround.standable_from(lab.arena, asked, env, Vector3(75.4, 0.0, 10.0))
	SlotGround.SIDE_ENABLED = true
	assert_eq(control, SlotGround.standable_for(lab.arena, asked, env), "--slot-side=nearest: round 6's nearest point")
	lab.dispose()

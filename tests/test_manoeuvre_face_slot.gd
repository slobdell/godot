extends TestCase
## Round 30, manoeuvre M1b(1): **a face at rest keeps to the slot the crew last drove to** (`OrderController.face_slot`).
##
## Round 28's M1 anchored a face plan to `mover._goal`, but `Movement.idle()` clears that goal every tick a face order
## runs (`_apply_move` calls it before the face branch), so the anchor read INF and never held: a law artillery piece
## ping-ponged face/move for ~32 s at the edge of its arrive radius (hull-rest probe, law seed 21). The slot is now the
## goal of the last `move_to` the controller was given, kept across the face. `--nav-off=faceslot` = no anchor.

const LANE_X := TacticsScenarios.LANE_X


static func _controller_of(lab: TacticsLab, tank: Tank) -> OrderController:
	for child in lab.game_match.brains.get_children():
		if child is OrderController and (child as OrderController).tank == tank:
			return child
	return null


## The root cause, live: after a move_to and then a face, the mover's own goal is INF (idle() cleared it: the thing
## round 28 read) and the controller's face_slot is still the move's goal.
func test_the_slot_survives_the_face_that_follows_the_move() -> void:
	var lab := TacticsLab.create(self, 31)
	var rig := lab.gun(Match.Team.GREEN, "Green_A_1", Vector3(LANE_X, 0, 30), 0.0, "gang_tank")
	await lab.start()
	var ctl := _controller_of(lab, rig)
	var goal := rig.global_position + Vector3(0, 0, -6)
	ctl.set_orders({"type": "move_to", "x": goal.x, "z": goal.z}, {"type": "hold_fire"})
	for tick in 5:
		await lab.step()
	ctl.set_orders({"type": "face", "x": goal.x + 20.0, "z": goal.z}, {"type": "hold_fire"})
	for tick in 5:
		await lab.step()
	print("MEASURE m1b_face_slot after a move then a face: mover goal %s, face_slot %s (the move's goal %s)" % [
			ctl.movement._goal, ctl.face_slot, goal])
	assert_true(ctl.movement._goal == Vector3.INF, "the defect's mechanism: Movement.idle() has cleared the mover's goal under the face")
	assert_true(ctl.face_slot.distance_to(goal) < 0.01, "the controller still knows the slot (%s v %s)" % [ctl.face_slot, goal])
	lab.dispose()


## The planner with the slot: a rig stopped 3 m short of its slot, told to face 60 deg left, plans legs that end no
## further from the slot than it starts (+ FACE_SLOT_SLACK_M); the unanchored plan (`--nav-off=faceslot`) is reported
## beside it. The counters show the anchor acted (lesson 300).
func _plan(anchored: bool) -> Dictionary:
	var was_off := Movement._off
	Movement._off = PackedStringArray([]) if anchored else PackedStringArray(["faceslot"])
	var lab := TacticsLab.create(self, 31)
	var rig := lab.gun(Match.Team.GREEN, "Green_A_1", Vector3(LANE_X, 0, 30), 0.0, "gang_tank")
	await lab.start()
	var ctl := _controller_of(lab, rig)
	ctl.set_physics_process(false)
	var here := rig.global_position
	var forward := Vector3(0, 0, -1)
	var slot := here + forward * 3.0
	ctl.face_slot = slot
	var want := forward.rotated(Vector3.UP, deg_to_rad(60.0))
	var kept_before := Manoeuvre.face_slot_kept
	var refused_before := Manoeuvre.face_slot_refused
	var plan := Manoeuvre.plan_face(ctl.movement, here, forward, want, here)
	var end_off := INF
	if not plan.is_empty():
		var end: Array = ctl.movement._fill_end(here, forward, 1.0 if forward.signed_angle_to(want, Vector3.UP) < 0.0 else -1.0, plan)
		end_off = Vector2((end[0] as Vector3).x - slot.x, (end[0] as Vector3).z - slot.z).length()
	var out := {"legs": plan.size(), "end_off": end_off, "start_off": 3.0, "kept": Manoeuvre.face_slot_kept - kept_before,
			"refused": Manoeuvre.face_slot_refused - refused_before}
	lab.dispose()
	Movement._off = was_off
	return out


func test_a_face_plan_ends_no_further_from_the_slot_than_it_starts() -> void:
	var on := await _plan(true)
	var off := await _plan(false)
	print("MEASURE m1b_face_plan gang_tank 3 m short of its slot, 60 deg to face: anchored %d legs ending %.2f m off the slot (kept %d, refused %d) | unanchored %d legs ending %.2f m off" % [
			on["legs"], on["end_off"], on["kept"], on["refused"], off["legs"], off["end_off"]])
	assert_true(off["legs"] > 0, "setup: a plan fits here without the anchor (%d legs)" % off["legs"])
	assert_true(on["kept"] == 1, "the anchor acted (kept %d)" % on["kept"])
	assert_true(on["legs"] > 0, "a plan fits with the anchor (%d legs)" % on["legs"])
	assert_true(on["end_off"] <= on["start_off"] + Manoeuvre.FACE_SLOT_SLACK_M + 0.01,
			"it ends no further from the slot than it starts (%.2f v %.2f + %.1f)" % [on["end_off"], on["start_off"], Manoeuvre.FACE_SLOT_SLACK_M])
	assert_true(on["end_off"] <= off["end_off"] + 0.01, "and no further than the unanchored plan (%.2f v %.2f)" % [on["end_off"], off["end_off"]])

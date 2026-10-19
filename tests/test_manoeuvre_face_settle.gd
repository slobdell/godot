extends TestCase
## Round 35, manoeuvre W2 (C35.7, CP-F attempt 5, the face side): **a face no plan fits gives up cleanly.**
##
## CP-F attempt 4 (R34.18) turned the hull right where a plan fitted (point tasks 3-4 deg v ~50) but failed on settling:
## a face whose plans kept failing crept at the 0.35 lock to the judge (face_creep at the judge: screen 8 v 0, attack-move
## 4 v 0). Now FACE_SETTLE_FAILS failed plans in a row for the same want (within Movement.FACE_REPLAN_DEG) end the face
## as it is: throttle 0, turn 0, and Movement.face_settled() says so; between the failed tries the hull waits still
## instead of creeping. `--nav-off=facesettle` = round 34's creep.

const LANE_X := TacticsScenarios.LANE_X


static func _controller_of(lab: TacticsLab, tank: Tank) -> OrderController:
	for child in lab.game_match.brains.get_children():
		if child is OrderController and (child as OrderController).tank == tank:
			return child
	return null


## A War Rig boxed in by four parked squadmates (no face plan fits: every pose comes nearer one of them), told to face
## 90 deg right, for 8 s. Returns what it did over the last 3 s.
func _boxed_face(settle: bool, unit_id := "gang_tank") -> Dictionary:
	var was_off := Movement._off
	# The arm list follows the default (on a tree where FACE_SETTLE_DEFAULT is true the empty list is ON).
	Movement._off = PackedStringArray([]) if settle == Manoeuvre.FACE_SETTLE_DEFAULT else PackedStringArray(["facesettle"])
	var lab := TacticsLab.create(self, 31)
	var here := Vector3(LANE_X, 0, 30)
	var box: Array = Movement.hull_box(unit_id)
	var half_l := float(box[2]) * 0.5
	var half_w := float(box[0]) * 0.5
	var rig := lab.gun(Match.Team.GREEN, "Green_A_1", here, 0.0, unit_id)
	lab.gun(Match.Team.GREEN, "Green_A_2", here + Vector3(0, 0, -(half_l * 2.0 + 1.0)), 0.0, unit_id)
	lab.gun(Match.Team.GREEN, "Green_A_3", here + Vector3(0, 0, half_l * 2.0 + 1.0), 0.0, unit_id)
	lab.gun(Match.Team.GREEN, "Green_A_4", here + Vector3(half_w * 2.0 + 1.5, 0, 0), 0.0, unit_id)
	lab.gun(Match.Team.GREEN, "Green_A_5", here + Vector3(-(half_w * 2.0 + 1.5), 0, 0), 0.0, unit_id)
	await lab.start()
	var ctl := _controller_of(lab, rig)
	ctl.set_orders({"type": "face", "x": here.x + 20.0, "z": here.z}, {"type": "hold_fire"})
	var none_before := Manoeuvre.face_none
	var settles_before := Manoeuvre.face_settles
	var ticks := SimClock.TICK_RATE * 8
	var tail_from := ticks - SimClock.TICK_RATE * 3
	var throttle_max := 0.0
	var start := Vector3.ZERO
	for tick in ticks:
		await lab.step()
		if tick == tail_from:
			start = rig.global_position
		if tick >= tail_from:
			throttle_max = maxf(throttle_max, absf(float(ctl.movement.contact.decided.get("throttle", 0.0))))
	var out := {"throttle_max": throttle_max, "moved": Vector2(rig.global_position.x - start.x, rig.global_position.z - start.z).length(),
			"settled": ctl.movement.face_settled(), "none": Manoeuvre.face_none - none_before,
			"settles": Manoeuvre.face_settles - settles_before}
	lab.dispose()
	Movement._off = was_off
	return out


func test_a_boxed_face_stops_still_after_its_plans_fail() -> void:
	var on := await _boxed_face(true)
	var off := await _boxed_face(false)
	print("MEASURE w2_face_settle boxed War Rig, last 3 s of 8: ON %s | OFF %s" % [on, off])
	assert_true(int(on["none"]) >= Manoeuvre.FACE_SETTLE_FAILS, "the stage is the case: no plan fits (%d failed)" % int(on["none"]))
	assert_eq(int(on["settles"]), 1, "the face gave up once")
	assert_true(bool(on["settled"]), "face_settled() reports it")
	assert_true(float(on["throttle_max"]) < 0.01, "no creep after giving up (throttle %.2f)" % float(on["throttle_max"]))
	assert_true(float(on["moved"]) < 0.2, "still (moved %.2f m)" % float(on["moved"]))
	assert_true(float(off["throttle_max"]) >= Steering.WHEELS_MIN_THROTTLE - 0.01, "the switch off keeps round 34's creep (%.2f)" % float(off["throttle_max"]))
	assert_eq(int(off["settles"]), 0, "nothing gives up with the switch off")


## A face that plans fine on open ground is untouched: it turns, ends aligned, and face_settled() says so; no give-up.
func test_an_open_face_turns_and_reads_settled_when_aligned() -> void:
	var was_off := Movement._off
	Movement._off = PackedStringArray([]) if Manoeuvre.FACE_SETTLE_DEFAULT else PackedStringArray(["facesettle"])
	var lab := TacticsLab.create(self, 31)
	var here := Vector3(LANE_X, 0, 30)
	var rig := lab.gun(Match.Team.GREEN, "Green_A_1", here, 0.0, "gang_tank")
	await lab.start()
	var ctl := _controller_of(lab, rig)
	ctl.set_orders({"type": "face", "x": here.x + 20.0, "z": here.z}, {"type": "hold_fire"})
	var settles_before := Manoeuvre.face_settles
	for tick in SimClock.TICK_RATE * 20:
		await lab.step()
	var forward := Vector3(-rig.global_basis.z.x, 0.0, -rig.global_basis.z.z).normalized()
	var error := rad_to_deg(absf(forward.signed_angle_to(Vector3(1, 0, 0), Vector3.UP)))
	print("MEASURE w2_face_settle open ground: error %.1f deg, settled %s, settles %d" % [error, ctl.movement.face_settled(),
			Manoeuvre.face_settles - settles_before])
	assert_true(error <= Manoeuvre.FACE_ALIGNED_DEG + 1.0, "it came round (%.1f deg)" % error)
	assert_true(ctl.movement.face_settled(), "aligned reads settled")
	assert_eq(Manoeuvre.face_settles - settles_before, 0, "no give-up on open ground")
	lab.dispose()
	Movement._off = was_off


## A new want (the spot swung more than FACE_REPLAN_DEG) re-arms a given-up face.
func test_a_new_want_rearms_the_face() -> void:
	var mover_id := 4242
	Manoeuvre.face_settle_forget_id(mover_id)
	var want := Vector3(1, 0, 0)
	for i in Manoeuvre.FACE_SETTLE_FAILS:
		Manoeuvre.face_failed_id(mover_id, want)
	assert_true(Manoeuvre.face_given_up_id(mover_id, want), "given up after FACE_SETTLE_FAILS fails")
	assert_true(Manoeuvre.face_given_up_id(mover_id, want.rotated(Vector3.UP, deg_to_rad(10.0))), "a 10 deg swing is the same want")
	assert_true(not Manoeuvre.face_given_up_id(mover_id, want.rotated(Vector3.UP, deg_to_rad(45.0))), "a 45 deg swing re-arms it")
	assert_true(not Manoeuvre.face_given_up_id(mover_id, want), "and the old want is no longer given up")
	Manoeuvre.face_settle_forget_id(mover_id)


## A hull-fixed scout (its hull is its gun's arc) boxed in the same way keeps trying: no give-up, the creep stands.
func test_a_hull_fixed_scout_does_not_give_up() -> void:
	var scout := await _boxed_face(true, "gang_scout")
	print("MEASURE w2_face_settle boxed gang_scout (hull-fixed), ON: %s" % [scout])
	assert_eq(int(scout["settles"]), 0, "a hull-fixed hull never gives up its face")

extends TestCase
## Round 31, manoeuvre M1b(2) (his round-28 call "TURN THE WHOLE VEHICLE"; `--nav-off=turnhull` flips
## `Manoeuvre.TURN_HULL_DEFAULT`, OPT-IN until its bar passes): a wheeled TURRET hull given a DRAWN facing turns its hull
## (the brain's decline lifted, C31.8), and every pose of a face plan keeps inside the crew's arrive radius (round 29's
## facekeep: a gang catapult's two-leg plan put its cusp 8 m out, past the 5.4 m radius, and the brain re-sent the move
## every second for a minute).

const LANE_X := TacticsScenarios.LANE_X


static func _controller_of(lab: TacticsLab, tank: Tank) -> OrderController:
	for child in lab.game_match.brains.get_children():
		if child is OrderController and (child as OrderController).tank == tank:
			return child
	return null


## A face plan from `short` metres short of the slot, `angle` degrees to turn; the furthest any 0.25 m step of it gets
## from the slot.
func _plan(on: bool, unit_id: String, short: float, angle: float) -> Dictionary:
	var was_off := Movement._off
	Movement._off = PackedStringArray(["turnhull"]) if on != Manoeuvre.TURN_HULL_DEFAULT else PackedStringArray([])
	Movement._off_parsed = true
	var lab := TacticsLab.create(self, 31)
	var hull := lab.gun(Match.Team.GREEN, "Green_A_1", Vector3(LANE_X, 0, 30), 0.0, unit_id)
	await lab.start()
	var ctl := _controller_of(lab, hull)
	ctl.set_physics_process(false)
	var here := hull.global_position
	var forward := Vector3(0, 0, -1)
	var slot := here + forward * short
	ctl.face_slot = slot
	var want := forward.rotated(Vector3.UP, deg_to_rad(angle))
	var refused_before := Manoeuvre.face_keep_refused
	var plan := Manoeuvre.plan_face(ctl.movement, here, forward, want, here)
	var turn := 1.0 if forward.signed_angle_to(want, Vector3.UP) < 0.0 else -1.0
	var radius := ctl.movement.wheel_radius()
	var at := here
	var heading := forward
	var worst := 0.0
	for leg: Vector2 in plan:
		var done := 0.0
		while done < leg.y - 0.001:
			var step := minf(0.25, leg.y - done)
			var next := Movement._fill_step(at, heading, int(leg.x), turn, radius, step)
			at = next[0]
			heading = next[1]
			done += step
			worst = maxf(worst, Vector2(at.x - slot.x, at.z - slot.z).length())
	var keep := maxf(maxf(TankBrain.ORDER_ARRIVE, Movement.settle_radius(unit_id)) - Manoeuvre.FACE_KEEP_MARGIN_M, short)
	var out := {"legs": plan.size(), "worst": worst, "keep": keep, "refused": Manoeuvre.face_keep_refused - refused_before}
	lab.dispose()
	Movement._off = was_off
	return out


func test_every_pose_of_a_face_plan_keeps_inside_the_arrive_radius() -> void:
	var worst_off := 0.0
	var worst_on := 0.0
	var keep := 0.0
	var refused := 0
	var cases := 0
	for unit_id: String in ["gang_ifv", "gang_tank", "law_tank"]:
		for angle: float in [90.0, 150.0, -150.0]:
			var on := await _plan(true, unit_id, 4.0, angle)
			var off := await _plan(false, unit_id, 4.0, angle)
			print("MEASURE m1b2_facekeep %s 4 m short, %.0f deg: on %d legs worst %.2f m (keep %.2f, refused steps %d) | off %d legs worst %.2f m" % [
					unit_id, angle, on["legs"], on["worst"], on["keep"], on["refused"], off["legs"], off["worst"]])
			if on["legs"] > 0:
				assert_true(on["worst"] <= on["keep"] + 0.3, "%s %.0f deg: every pose inside the keep radius (%.2f v %.2f)" % [unit_id, angle, on["worst"], on["keep"]])
			worst_on = maxf(worst_on, on["worst"])
			worst_off = maxf(worst_off, off["worst"])
			refused += int(on["refused"])
			cases += 1
	print("MEASURE m1b2_facekeep over %d cases: worst pose on %.2f m, off %.2f m, steps refused %d" % [cases, worst_on, worst_off, refused])
	assert_true(refused > 0, "the keep acted somewhere (lesson 300: %d steps refused)" % refused)


func test_switched_off_the_brain_still_declines() -> void:
	var was_off := Movement._off
	Movement._off = PackedStringArray(["turnhull"]) if Manoeuvre.TURN_HULL_DEFAULT else PackedStringArray([])
	Movement._off_parsed = true
	assert_true(not Manoeuvre.turn_hull_on(), "the switch reads off")
	Movement._off = was_off


## Round 33 (CP-F, F1): round 8's stage (tests/test_wheeled_face.gd: a held turreted truck, an enemy 30 m north in
## sight) with a facing he DREW, east. The brain's face toward the contact is declined (the turret takes it); under
## turnhull the hull keeps his drawn heading instead of `stop`. Traced at hull-rest gangs s66: a War Rig's planned face
## was cut to `stop` mid-leg whenever the quiet enemy came into sight, and it ended 44-126 deg off.
func _contact_stage(on: bool, element_task := true) -> Dictionary:
	var was_off := Movement._off
	Movement._off = PackedStringArray(["turnhull"]) if on != Manoeuvre.TURN_HULL_DEFAULT else PackedStringArray([])
	Movement._off_parsed = true
	var s := AiScenario.create(self, 4)
	s.game_match.set_meta("player_team", Match.Team.GREEN)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-100, 0, 40), PI + 0.7, {}, "gang_tank")
	AiScenario.make_durable(me)
	var target := s.dummy(Match.Team.RUST, "Rust_A_1", Vector3(-100, 0, 10), 0.0)
	AiScenario.make_durable(target)
	var brain := s.brain_of(me)
	var drawn := Vector3(1, 0, 0)
	var elements := Elements.install(s.game_match, s.orders())
	await s.start()
	var authority_was := Drills.PLAYER_AUTHORITY
	if element_task:
		# The player's right-drag is an element TASK with a facing (the F1 case); its crew settles on it and keeps it for
		# as long as the task stands.
		# Round 45 (engage E2, C45.3; R45.10): a squad of ONE now takes his task as his own direct order (Element._his_lone_order),
		# so this one-crew stage measures the element path only with that rule off; squads of two or more keep it.
		Drills.PLAYER_AUTHORITY = false
		var task := {"verb": "move", "to": [-100.0, 40.0], "facing": [drawn.x, drawn.z], "drills": false}
		assert_eq(ElementTask.validate(task), "", "setup: a move task may name a facing")
		elements.form(["Green_A_1"], "Alpha").assign(task)
	else:
		# His commonest case: a plain K1 move with a drawn facing COMPLETES on arrival (here at once), and only the
		# station it leaves remembers that the heading was his.
		assert_eq(s.orders().issue({"units": ["Green_A_1"], "verb": "move", "to": [-100.0, 40.0],
				"facing": [drawn.x, drawn.z], "source": "player"}), "", "setup: the move is accepted")
	var drawn_faces := 0
	var stops := 0
	var holds_before := Manoeuvre.hull_holds
	for tick in SimClock.TICK_RATE * 20:
		await s.step()
		var order: Dictionary = brain.move_order
		if String(order.get("type", "")) == "face":
			var to := Vector3(float(order["x"]) - me.global_position.x, 0.0, float(order["z"]) - me.global_position.z)
			if to.length() > 1.0 and to.normalized().dot(drawn) > 0.98:
				drawn_faces += 1
		elif String(order.get("type", "")) == "stop":
			stops += 1
	var forward := Vector3(-me.global_basis.z.x, 0.0, -me.global_basis.z.z).normalized()
	var result := {"completed": s.orders().current("Green_A_1").is_empty(),
			"station_drawn": bool((s.orders().station("Green_A_1") as Dictionary).get("drawn", false)), "drawn_faces": drawn_faces, "stops": stops, "declined": brain.faces_declined,
			"holds": Manoeuvre.hull_holds - holds_before, "error_deg": rad_to_deg(forward.angle_to(drawn)),
			"shots": s.shots_by(me)}
	s.dispose()
	Movement._off = was_off
	Drills.PLAYER_AUTHORITY = authority_was
	return result


func test_a_declined_contact_face_keeps_the_hull_on_his_drawn_heading() -> void:
	var on := await _contact_stage(true)
	var off := await _contact_stage(false)
	print("MEASURE cpf_contact_face on %s | off %s" % [on, off])
	assert_true(int(on["declined"]) > 0, "setup: the contact face is declined in both arms (on %d)" % on["declined"])
	assert_true(int(off["declined"]) > 0, "setup: ...off %d" % off["declined"])
	assert_true(int(on["holds"]) > 0 and int(on["drawn_faces"]) > 0,
			"on: the declined face keeps the hull on his drawn heading (%d holds, %d ticks)" % [on["holds"], on["drawn_faces"]])
	assert_eq(int(off["drawn_faces"]), 0, "off: round 8's decline stands (the hull is never sent to his heading)")
	assert_true(float(on["error_deg"]) < 20.0, "on: the hull ends on his drawn heading (%.1f deg off)" % on["error_deg"])
	assert_true(int(on["shots"]) > 0, "on: and the turret still fights the contact (%d shots)" % on["shots"])


func test_after_a_plain_move_with_a_drawn_facing_completes_a_contact_keeps_the_hull_on_it() -> void:
	# The orchestrator's case (round 33): his round-28 call is exactly this -- move, draw the facing, then a contact.
	var on := await _contact_stage(true, false)
	var off := await _contact_stage(false, false)
	print("MEASURE cpf_completed_move_face on %s | off %s" % [on, off])
	assert_true(bool(on["completed"]) and bool(off["completed"]), "setup: the plain move completed in both arms")
	assert_true(bool(on["station_drawn"]) and bool(off["station_drawn"]), "setup: its station remembers the heading was drawn")
	assert_true(int(on["declined"]) > 0 and int(off["declined"]) > 0, "setup: the contact face is declined in both arms")
	assert_true(int(on["holds"]) > 0, "on: the declined face keeps the hull on his drawn heading (%d holds)" % on["holds"])
	assert_true(float(on["error_deg"]) < 20.0, "on: the hull ends on his drawn heading (%.1f deg off)" % on["error_deg"])
	# (OFF's first tick or two face his heading as the ORDER's own told face, before the move completes.)
	assert_eq(int(off["holds"]), 0, "off: round 8's decline stands (stop), never held on his heading")
	assert_true(int(off["stops"]) > 500, "off: the hull stops where it is (%d stop ticks)" % off["stops"])
	assert_true(int(on["shots"]) > 0, "on: and the turret still fights the contact (%d shots)" % on["shots"])


func test_an_elements_own_facing_is_not_a_drawn_station() -> void:
	# The station's `drawn` is the PLAYER's: an element's sector facing on its K1 orders must not turn the hull under it.
	var s := AiScenario.create(self, 4)
	s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-100, 0, 40), 0.0, {}, "gang_tank")
	await s.start()
	assert_eq(s.orders().issue({"units": ["Green_A_1"], "verb": "move", "to": [-100.0, 40.0], "facing": [1.0, 0.0],
			"source": "element"}), "", "setup: the element's move is accepted")
	for tick in 10:
		await s.step()
	var post: Dictionary = s.orders().station("Green_A_1")
	assert_true(not post.is_empty(), "setup: the move completed and left a station")
	assert_true(not bool(post.get("drawn", true)), "an element's facing is not his drawn heading")
	s.dispose()


## Round 33 (CP-F attempt 3, R33.23): a crew further from its held seat than R32.3's ARRIVED_M is still on its way
## there: neither lift applies (the face stays declined, no drawn_face), so the move finishes first. Traced at hull-rest
## gangs SBF s44: the lifted face replaced the dressing move every second and the gang tank crept 7 m off its seat to the
## judge. Inside the radius both apply as before.
func test_a_crew_off_its_seat_is_not_turned_until_it_is_seated() -> void:
	var was_off := Movement._off
	Movement._off = PackedStringArray([]) if Manoeuvre.TURN_HULL_DEFAULT else PackedStringArray(["turnhull"])
	Movement._off_parsed = true
	var s := AiScenario.create(self, 4)
	s.game_match.set_meta("player_team", Match.Team.GREEN)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-100, 0, 40), 0.0, {}, "gang_tank")
	var brain := s.brain_of(me)
	await s.start()
	assert_eq(s.orders().issue({"units": ["Green_A_1"], "verb": "move", "to": [-100.0, 40.0], "facing": [1.0, 0.0],
			"source": "player"}), "", "setup: the move is accepted")
	for tick in 10:
		await s.step()
	assert_true(Manoeuvre.drawn_facing(brain), "setup: his heading is drawn (the completed move's station)")
	var face := {"type": "face", "x": 0.0, "z": 40.0, "from": "order"}
	var radius := maxf(Manoeuvre.SEAT_ARRIVED_M, Movement.settle_radius("gang_tank"))
	brain.face_slot = me.global_position + Vector3(0, 0, radius + 3.0)
	var declines0 := Manoeuvre.off_seat_declines
	assert_true(not Manoeuvre.hull_takes_face(brain, face), "%.1f m off its seat: the face is not lifted" % (radius + 3.0))
	assert_true(Manoeuvre.drawn_face(brain).is_empty(), "...and no drawn_face either")
	assert_eq(Manoeuvre.off_seat_declines - declines0, 2, "both counted")
	brain.face_slot = me.global_position + Vector3(0, 0, 5.0)
	assert_true(Manoeuvre.hull_takes_face(brain, face), "5 m off (arrived by R32.3): lifted as before")
	assert_true(not Manoeuvre.drawn_face(brain).is_empty(), "...and drawn_face as before")
	s.dispose()
	Movement._off = was_off

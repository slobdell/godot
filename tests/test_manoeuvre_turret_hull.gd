extends TestCase
## Round 28, manoeuvre M1 (his call 2, 2026-10-12: "turn the whole vehicle"): a WHEELED hull with a TURRET, given a drawn
## facing, turns its hull that way at rest (front armour where he pointed), with M1b's planned turn. Until round 28 the
## brain turned every untold face into a stop for these hulls (tank_brain `_order_move`, round 8: "the turret carries
## the aim"), and an element's sector watch is never "told", so a gang tank's screen ended where it arrived (orders'
## O3: wheels/turret drawn median 60-91 deg, 168 crews). A CLICKED order keeps that rule: the turret takes the facing.
##
## He drew east; the squad drives up from the south, so its own geometry would have faced north.

const EAST := Vector3(1, 0, 0)
const LANE_X := TacticsScenarios.LANE_X


func _forward(tank: Tank) -> Vector3:
	return TacticsFormation.flat(-tank.global_basis.z)


## The resting crews' mean hull heading's error from east and the worst crew's from its own sector, after `seconds` of `task` for four `unit_id` crews.
func _run(seed_value: int, unit_id: String, task: Dictionary, seconds: int) -> Dictionary:
	var lab := TacticsLab.create(self, seed_value)
	var names: Array = []
	for i in 4:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1),
				Vector3(LANE_X + i * 12.0 - 18.0, 0, 50), 0.0, unit_id).name))
	var alpha := lab.element(names, "Alpha")
	await lab.start()
	assert_eq(alpha.assign(task), "", "setup: %s is a valid task" % task)
	for tick in SimClock.TICK_RATE * seconds:
		await lab.step()
	# Judged on the crews AT REST (the face this item is about). A crew still driving onto its slot is M2's problem
	# (the screen's seed 61: one gang tank shuffles 16 m beside its slot for a minute, base and change alike).
	var mean := Vector3.ZERO
	var worst := 0.0
	var resting := 0
	var declined := 0
	for unit_name: String in names:
		var tank := lab.tank_of(unit_name)
		var brain := lab.game_match.brains.get_node_or_null(NodePath("Brain_" + unit_name)) as TankBrain
		declined += brain.faces_declined
		var forward := _forward(tank)
		print("CREW %s %.1f deg off east, order %s, speed %.2f" % [unit_name, rad_to_deg(forward.angle_to(EAST)),
				brain.move_order.get("type"), tank.speed()])
		if String(brain.move_order.get("type")) == "move_to" or absf(tank.speed()) > 0.3:
			continue
		resting += 1
		mean += forward
		# Its own sector of the drawn facing (a firing line fans its crews up to 30 deg out, doctrine), else east.
		var sector: Variant = brain.element.get("facing")
		var own: Vector3 = TacticsFormation.flat(sector) if sector is Vector3 else EAST
		worst = maxf(worst, rad_to_deg(forward.angle_to(own)))
	var off := rad_to_deg(TacticsFormation.flat(mean).angle_to(EAST)) if resting > 0 else 180.0
	lab.dispose()
	return {"off": off, "worst": worst, "declined": declined, "resting": resting}


func _drawn(seed_value: int, unit_id: String, verb: String, to: Array, seconds := 45) -> void:
	var r := await _run(seed_value, unit_id, {"verb": verb, "to": to, "facing": [1.0, 0.0]}, seconds)
	print("MEASURE m1_turret_hull %s %s drawn: %d at rest, mean hull %.1f deg off east, worst %.1f off its sector" % [unit_id, verb,
			r["resting"], r["off"], r["worst"]])
	assert_true(r["resting"] >= 3, "%s %s: the squad came to rest (%d of 4)" % [unit_id, verb, r["resting"]])
	assert_true(r["off"] <= 20.0, "%s %s: the hulls turn to the facing he drew (mean %.1f deg off)" % [unit_id, verb, r["off"]])
	assert_true(r["worst"] <= 15.0, "%s %s: every hull at rest is nose-on to its sector (worst %.1f deg)" % [unit_id,
			verb, r["worst"]])


func test_gang_tanks_screen_turns_the_hulls_to_the_drawn_facing() -> void:
	# 40 m east of the lane (as support by fire): at LANE_X the screen's 6 m slots make one 10 m truck parallel-park
	# between its squadmates for a minute (a formation question, relayed to brains), which is not what this tests.
	await _drawn(61, "gang_tank", "screen", [LANE_X + 40.0, 0.0])


func test_law_tanks_support_by_fire_turns_the_hulls_to_the_drawn_facing() -> void:
	await _drawn(62, "law_tank", "support_by_fire", [LANE_X + 40.0, 0.0])


func test_gang_ifvs_ambush_turns_the_hulls_to_the_drawn_facing() -> void:
	await _drawn(63, "gang_ifv", "ambush", [LANE_X + 40.0, 0.0])


func test_artillery_attack_move_arrives_hull_on_to_the_drawn_facing() -> void:
	await _drawn(64, "gang_artillery", "move", [LANE_X, 0.0])


## A clicked screen keeps today's rule: the hulls keep the way they came (north) and the turrets take the facing.
func test_a_clicked_screen_still_lets_the_turret_take_it() -> void:
	var r := await _run(65, "gang_tank", {"verb": "screen", "to": [LANE_X, 0.0]}, 45)
	print("MEASURE m1_turret_hull gang_tank screen clicked: mean hull %.1f deg off east, faces declined %d" % [r["off"],
			r["declined"]])
	assert_true(r["declined"] > 0, "a clicked screen's faces are still declined for a turreted wheel")

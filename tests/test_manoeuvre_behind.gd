extends TestCase
## Round 26 (manoeuvre M1, M1b, C26.9). The lead: *"if I have a unit selected and I select a point to move to that's
## immediately behind it, the vehicle will do this N point turn to clumsily rotate in place and then eventually drive
## the very short distance to the point. A smart vehicle would have just reversed onto the point"*.
##
## A player's plain move (control's Orders, source "player") on the open band of yard_open, one hull at a time, timed
## to SETTLED (the order done and the hull at rest, any facing turn after arrival included). Main's numbers
## (b57838ed, builder0, `make manoeuvre-behind`) are the bars: each case must beat them. The paired control (the
## `behind` and `faceturn` switches off on the same tree) reproduces the complaint, so the test cannot pass by accident.
## (Round 32, C32.8: the War Rig face-behind pair moved to test_manoeuvre_face_behind.gd; this file ran 69 s.)

const MATCH := preload("res://game/match/match.tscn")
const START := Vector3(0.0, 0.0, 15.0)


func _run(unit: String, astern_m: float, off_deg: float, facing: bool, off: PackedStringArray) -> Dictionary:
	await ArenaFixture.build(self, "yard_open")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.seed_spawns(1, 0.0)
	game_match.elimination = true
	game_match.set_meta("player_team", Match.Team.GREEN)
	var orders := Orders.new()
	Orders.attach(game_match, orders)
	var saved := Movement._off
	Movement._off = off
	var tank := game_match.add_brain_tank(Match.Team.GREEN, "M", unit, [{}], "Green_M_1")
	tank.place(START, 0.0)
	for i in SimClock.TICK_RATE:
		await tree.physics_frame
	var nose := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z).normalized()
	var to := Vector2(tank.global_position.x, tank.global_position.z) + nose.rotated(deg_to_rad(off_deg)) * astern_m
	var command := {"units": ["Green_M_1"], "verb": "move", "to": [to.x, to.y], "queue": false, "source": "player"}
	if facing:
		command["facing"] = [nose.x, nose.y]
	assert_eq(orders.issue(command), "", "order accepted")
	var done := -1
	var still := 0
	var legs := 0
	var gear := 0
	var turned := 0.0
	var reverse_m := 0.0
	var last_nose := nose
	var last := tank.global_position
	var settled := -1
	for frame in SimClock.TICK_RATE * 60:
		await tree.physics_frame
		var now := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z).normalized()
		turned += absf(last_nose.angle_to(now))
		var step := Vector2(tank.global_position.x - last.x, tank.global_position.z - last.z).length()
		last_nose = now
		last = tank.global_position
		var speed := tank.speed()
		var g := 1 if speed > 0.3 else (-1 if speed < -0.3 else 0)
		if g < 0:
			reverse_m += step
		if g != 0 and g != gear:
			legs += 1
			gear = g
		if done < 0 and orders.is_idle("Green_M_1"):
			done = frame
		still = still + 1 if absf(speed) < 0.1 and rad_to_deg(last_nose.angle_to(now)) < 0.05 else 0
		if done >= 0 and still >= SimClock.TICK_RATE:
			settled = frame - SimClock.TICK_RATE
			break
	Movement._off = saved
	return {"settled_s": float(settled) / SimClock.TICK_RATE if settled >= 0 else -1.0, "legs": legs,
			"turned_deg": rad_to_deg(turned), "reverse_m": reverse_m,
			"end_m": Vector2(tank.global_position.x - to.x, tank.global_position.z - to.y).length(),
			"heading_err": rad_to_deg(absf(nose.angle_to(last_nose)))}


func _settled_by(r: Dictionary, seconds: float) -> bool:
	return float(r["settled_s"]) >= 0.0 and float(r["settled_s"]) <= seconds


func test_control_the_tank_pirouettes_onto_a_point_behind() -> void:
	var r := await _run("tank", 10.0, 180.0, false, PackedStringArray(["behind", "faceturn"]))
	assert_true(float(r["turned_deg"]) > 150.0, "control: the tank turns round to drive 10 m back (%s)" % r)


func test_the_tank_reverses_onto_a_point_10_m_behind() -> void:
	var r := await _run("tank", 10.0, 180.0, false, PackedStringArray())
	assert_true(float(r["reverse_m"]) >= 4.0, "it backs onto the point (%s)" % r)
	assert_true(float(r["turned_deg"]) < 30.0, "keeping its heading: no turn after it, C26.9 (%s)" % r)
	assert_true(int(r["legs"]) <= 2, "in at most two legs (%s)" % r)
	assert_true(_settled_by(r, 3.67 - 0.3), "settled faster than main's 3.67 s (%s)" % r)


func test_the_scout_backs_onto_a_point_5_m_behind_keeping_a_drawn_facing() -> void:
	var r := await _run("scout", 5.0, 180.0, true, PackedStringArray())
	assert_true(float(r["heading_err"]) < 15.0, "it ends facing the way it was told (%s)" % r)
	assert_true(int(r["legs"]) <= 2, "in at most two legs (%s)" % r)
	assert_true(_settled_by(r, 6.07 - 1.0), "settled well under main's 6.07 s (a 57 m loop) (%s)" % r)


func test_the_war_rig_does_not_creep_round_after_a_short_move_behind() -> void:
	var r := await _run("gang_tank", 10.0, 180.0, false, PackedStringArray())
	assert_true(int(r["legs"]) <= 3, "two legs and at most one planned turn, not main's 27 creep legs (%s)" % r)
	assert_true(_settled_by(r, 20.0), "settled long before main's 43 s (%s)" % r)

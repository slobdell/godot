extends TestCase
## Round 26 (manoeuvre M2). The lead: *"when vehicles get stuck, they do an N point turn where N is however many
## iterations it take to go back and forth to clear the obstacle. Generally speaking, a vehicle should be able to do a
## 3 point turn such that they drive forward the max amount to make most room, then back up enough such that their next
## turn will be able to clear whatever obstacle they're facing"*.
##
## Wheeled hulls parked nose-on to a Terminus block face, ordered to a point behind and to the side (round 11's case,
## test_nav_planned_reverse, at several distances off the face). Every turn episode is counted by ManoeuvreCensus
## (legs from the run-in to driving clear). The pass: every episode against the block in at most three legs, and the
## hull arrives. The paired control (`kturnaway` off: the away leg left to the pursuit law) is reported beside it.

const MATCH := preload("res://game/match/match.tscn")
## The (40, 0) block's north face is z = 20.
const FACE_Z := 20.0
const GOAL := Vector3(10.0, 0.0, 31.0)


func _drive(unit: String, gap: float, yaw: float, off: PackedStringArray) -> Dictionary:
	await ArenaFixture.build(self, "terminus")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Mover", 0, Match.Team.GREEN, unit)
	var half := float(Movement.hull_box(unit)[2]) * 0.5
	tank.place(Vector3(40.0, 0.0, FACE_Z + half + gap), yaw)
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	var saved := Movement._off
	var census_was := ManoeuvreCensus.on
	var log_was := ManoeuvreCensus.log_on
	Movement._off = off
	ManoeuvreCensus.on = true
	ManoeuvreCensus.log_on = true
	await wait_physics_frames(2)
	Movement.reset_route_arms()
	orders.set_orders({"type": "move_to", "x": GOAL.x, "z": GOAL.z}, {"type": "hold_fire"})
	var arrived := -1
	var contacts := 0
	for frame in SimClock.TICK_RATE * 40:
		await tree.physics_frame
		var reading := Movement.state(tank)
		if bool(reading.get("wall_contact", false)):
			contacts += 1
		if reading.get("phase") == "arrived":
			arrived = frame
			break
	orders.set_orders({"type": "stop"}, {"type": "hold_fire"})
	await wait_physics_frames(SimClock.TICK_RATE * 4)  # rest: the open episode closes
	var worst := 0
	var episodes := 0
	for row: Dictionary in ManoeuvreCensus.rows:
		if String(row.get("unit", "")) == "Mover":
			episodes += 1
			worst = maxi(worst, int(row["legs"]))
	var arms := Movement.route_arms()
	Movement._off = saved
	ManoeuvreCensus.on = census_was
	ManoeuvreCensus.log_on = log_was
	return {"unit": unit, "gap": gap, "arrived_s": float(arrived) / SimClock.TICK_RATE if arrived >= 0 else -1.0,
			"episodes": episodes, "worst_legs": worst, "contacts": contacts, "kturns": int(arms["kturns"]),
			"multi": int(arms["kturn_multi"]), "away": int(arms.get("kturn_away", 0)), "rows": ManoeuvreCensus.rows.duplicate()}


## One arena per test method: a second build in the same test leaves the first one's navigation regions undrained.
func _check(unit: String, gap: float, yaw: float) -> void:
	var r := await _drive(unit, gap, yaw, PackedStringArray())
	print("MEASURE kturn_three_point %s gap %.1f yaw %.0f: legs %d, arrived %.1f s, contacts %d, away legs %d" % [
			unit, gap, rad_to_deg(yaw), r["worst_legs"], r["arrived_s"], r["contacts"], r["away"]])
	assert_true(float(r["arrived_s"]) >= 0.0, "it gets there (%s)" % r)
	assert_true(int(r["worst_legs"]) <= 3, "every turn in at most three legs (%s)" % r)


## The control (`kturnaway` off: the away leg left to the pursuit law), measured and printed, not asserted.
func test_control_without_the_away_leg() -> void:
	var r := await _drive("gang_tank", 2.0, 0.0, PackedStringArray(["kturnaway"]))
	print("MEASURE kturn_three_point CONTROL gang_tank gap 2.0: legs %d, arrived %.1f s, contacts %d" % [
			r["worst_legs"], r["arrived_s"], r["contacts"]])
	assert_true(true, "measured, printed above")


func test_an_ifv_nose_on_to_a_block_turns_in_three_legs() -> void:
	await _check("ifv", 2.5, 0.0)


func test_an_ifv_close_to_a_block_turns_in_three_legs() -> void:
	await _check("ifv", 1.2, 0.0)


func test_a_scout_angled_at_a_block_turns_in_three_legs() -> void:
	await _check("scout", 1.5, deg_to_rad(-25.0))


## M2 is for long hulls by default (movement.gd `_away_here`): the War Rig nose-on to the block.
func test_a_war_rig_nose_on_to_a_block_turns_in_three_legs() -> void:
	await _check("gang_tank", 2.0, 0.0)

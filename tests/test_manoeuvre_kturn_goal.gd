extends TestCase
## Round 43, manoeuvre S3 (`--traffic-on=kturngoal`, Traffic.DEFAULT_OFF until Bar S): a reverse leg ends when its goal has
## moved to where a forward arc reaches it. His Guns_2 on Locks 56416 "crept north" 3.6 s and the War Rigs on terminus /
## crossing k-turned 11-14 s each: at a move's first tick the goal is the transit's converging station a hull's length away
## at 110 degrees off the nose (inside the 12 m turning circle), the mover plans a circle k-turn and commits to it, and half
## a second later the station is 45 m away toward the click, reachable forward, while the leg backs into the arena's edge.
## Forward is -Z (trip-up 2); yaw 0 faces -z. Open ground (yard_open), one War Rig (gang_tank: 14 m, wheels, 12 m radius). In the
## lab the lattice planner's seam would take the k-turn and it re-plans on a new goal by itself; in the match on terminus the seam
## had no plan and the circle k-turn ran on, so the seam is switched off here and the circle plan's leg is the one exercised.

var _lab: TacticsLab


func teardown() -> void:
	Traffic.set_off("kturngoal", Traffic.DEFAULT_OFF.has("kturngoal"))
	ManoeuvreCensus.trace_unit = ""
	for name in ["behind", PlannerSeam.SWITCH]:
		if not OS.get_cmdline_user_args().has("--nav-off=" + name):
			var i := Movement._off.find(name)
			if i >= 0:
				Movement._off.remove_at(i)
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


## A War Rig at the origin facing -z, ordered to a point a hull's length off its right rear quarter (inside its 12 m turning
## circle, 110 degrees off the nose: the station of the trace), with M1's straight reverse (`behind`) switched off as the deploy
## row's neighbours refused it in the match, so the circle k-turn plans as it did there; then, once the k-turn is under way, to a
## point 45 m ahead-left.
func _stage() -> Tank:
	_lab = TacticsLab.create(self, 7, "yard_open")
	var rig := _lab.gun(Match.Team.GREEN, "Green_Rig", Vector3.ZERO, 0.0, "gang_tank")
	await _lab.start()
	ManoeuvreCensus.trace_unit = "Green_Rig"  # the planner's look / plan lines, while this test is being staged
	Movement.switched_off("kturn")  # parse the switches once, then hold M1's straight reverse off for this staging
	for name in ["behind", PlannerSeam.SWITCH]:
		if not Movement._off.has(name):
			Movement._off.append(name)
	Movement.of(rig).ctl.set_orders({"type": "move_to", "x": 7.0, "z": 2.5}, {"type": "fire_at_will"})
	return rig


func _until_kturn(rig: Tank, ticks: int) -> int:
	var mover := Movement.of(rig)
	for i in ticks:
		await _lab.step()
		if mover.manoeuvring():
			return i + 1
		if i % 10 == 9:
			print("KTURN_GOAL_STAGE t%d ready %s phase %s speed %.2f pos (%.1f, %.1f) goal %s steer %s path %d/%d gate %s rev '%s' why %s" % [i + 1, str(Pathing.is_ready(rig)), mover.phase,
					rig.speed(), rig.global_position.x, rig.global_position.z, str(mover._goal), str(mover.steer_to), mover._path_index, mover._path.size(),
					Movement._gate_answer, mover._reverse_why, str(Manoeuvre.plans.get(String(rig.name), "-"))])
	return -1


func test_off_by_default() -> void:
	assert_true(Traffic.DEFAULT_OFF.has("kturngoal"), "S3 is opt-in until judged")
	assert_true(Traffic.off("kturngoal") or OS.get_cmdline_user_args().has("--traffic-on=kturngoal"), "off unless asked")


func test_a_reverse_leg_ends_when_its_goal_moves_out_of_the_circle() -> void:
	var results := {}
	for arm in ["off", "on"]:
		Traffic.set_off("kturngoal", arm == "off")
		var rig := await _stage()
		var mover := Movement.of(rig)
		Movement.reset_route_arms()
		var planned := await _until_kturn(rig, 120)
		assert_true(planned > 0, "%s: a goal inside the turning circle plans a k-turn within four seconds (tick %d)" % [arm, planned])
		for i in 15:
			await _lab.step()  # the plan's first leg takes hold (the seam's reverse)
		assert_true(mover.in_kturn() and mover._kturn_gear < 0, "%s: ...the circle plan's reverse leg (gear %d)" % [arm, mover._kturn_gear])
		# The station moves on: 45 m ahead-left, outside the circle, within the nose's cone.
		mover.ctl.set_orders({"type": "move_to", "x": -30.0, "z": -40.0}, {"type": "fire_at_will"})
		var ended_at := -1
		var reversed_m := 0.0
		var start := rig.global_position
		for i in 3 * SimClock.TICK_RATE:
			await _lab.step()
			if mover.manoeuvring():
				reversed_m = maxf(reversed_m, Vector2(rig.global_position.x - start.x, rig.global_position.z - start.z).length())
			elif ended_at < 0:
				ended_at = i + 1
		var forward_speed := 0.0
		for i in SimClock.TICK_RATE:
			await _lab.step()
			var nose := -rig.global_basis.z
			forward_speed = maxf(forward_speed, rig.real_velocity.dot(nose))
		results[arm] = {"ended_at": ended_at, "reversed_m": reversed_m, "forward_speed": forward_speed,
				"goal_moved": int(Movement.route_arms().get("kturn_goal_moved", 0)), "pos": rig.global_position}
		_lab.dispose()
		_lab = null
	var off: Dictionary = results["off"]
	var on: Dictionary = results["on"]
	assert_eq(off["goal_moved"], 0, "OFF: no leg is ended for a moved goal")
	assert_true(float(off["reversed_m"]) >= 3.0, "OFF: the leg backs on toward its planned end (backed %.1f m)" % off["reversed_m"])
	assert_true(int(on["goal_moved"]) >= 1, "ON: the leg is ended for the moved goal (counter %d)" % on["goal_moved"])
	assert_true(int(on["ended_at"]) > 0 and int(on["ended_at"]) <= 8, "ON: within a few ticks of the goal moving (tick %d)" % on["ended_at"])
	assert_true(float(on["reversed_m"]) < float(off["reversed_m"]), "ON: it backs less than OFF (%.1f v %.1f m)" % [on["reversed_m"], off["reversed_m"]])
	assert_true(float(on["forward_speed"]) > 2.0, "ON: it is driving forward a second later (%.1f m/s)" % on["forward_speed"])


func test_a_goal_that_stays_inside_the_circle_keeps_its_leg() -> void:
	Traffic.set_off("kturngoal", false)
	var rig := await _stage()
	var mover := Movement.of(rig)
	Movement.reset_route_arms()
	var planned := await _until_kturn(rig, 120)
	assert_true(planned > 0, "the k-turn is planned")
	# The goal moves, but to another point inside the circle (behind-right again): the leg stands.
	mover.ctl.set_orders({"type": "move_to", "x": 9.0, "z": 5.0}, {"type": "fire_at_will"})
	var still := 0
	for i in 20:
		await _lab.step()
		if mover.manoeuvring():
			still += 1
	assert_true(still >= 15, "a goal still behind and inside the circle keeps the reverse leg (%d of 20 ticks)" % still)
	assert_eq(int(Movement.route_arms().get("kturn_goal_moved", 0)), 0, "...and nothing is counted")

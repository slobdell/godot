extends TestCase
## Round 30 (planner P2): the planner's kinematic twin of the plant. A planned leg is an arc of `metres` at lock
## `steer`: the heading turns `steer / R` per metre and the hull moves along the new heading. The plant
## (TankMotion.step_in_place, wheels) integrates speed, yaw rate and slip tick by tick, and turns the heading by the
## speed at the START of a tick while moving by the speed at its end: while accelerating it turns LESS than the arc
## (by Δv·dt / R: a War Rig spinning up to 8.4 m/s lags 1.3 degrees), while braking it turns more, and over a leg
## that starts and ends at rest the two cancel. So the twin is tested the way a leg is DRIVEN (PlannerExecutor's rule:
## throttle until the stopping distance, then the opposite throttle ON THE SAME LOCK until all but stopped, then
## zero): the end pose within 1 % of the leg in position and 1 degree in heading, for the hardest hull (the War Rig:
## R 12), a looser one (the IFV, grip 0.7) and the Rat Rod under its yaw cap. (Zero throttle with the lock on is NOT
## a brake: it is the plant's creep, 0.5 throttle forward — the first version of this test drove 150 m that way.)


## Drive ONE leg through the plant as the executor would: `throttle` in `gear` on lock `turn` until what is left is
## within the stopping distance, then the opposite throttle on the same lock until all but stopped, then zero/zero
## until at rest. The end pose and the metres actually travelled.
func _drive_leg(unit: String, gear: int, throttle: float, turn: float, metres: float) -> Dictionary:
	var state := TankMotion.state_for(unit, Vector3.ZERO, Vector3(0, 0, -1))
	var brake := maxf(float(state["braking_mps2"]), 0.1)
	var accel := maxf(float(state["acceleration_mps2"]), 0.1)
	var top := float(state["max_forward_speed"] if gear > 0 else state["max_reverse_speed"]) * throttle
	var travelled := 0.0
	var ticks := 0
	var braking := false
	while ticks < 3000:
		var speed := float(state["speed"]) * float(gear)
		if braking and speed <= PlannerExecutor.BRAKE_TO_SPEED and absf(float(state["speed"])) < 0.01:
			break
		var v_next := minf(speed + accel * TankMotion.TICK_SECONDS, top)
		var stop_now := speed * speed / (2.0 * brake) - speed * TankMotion.TICK_SECONDS * 0.5
		var stop_next := v_next * v_next / (2.0 * brake) - v_next * TankMotion.TICK_SECONDS * 0.5
		var stopping := stop_now + (v_next * TankMotion.TICK_SECONDS + stop_next - stop_now) * 0.5 if speed >= 0.0 else 0.0
		if not braking and travelled + stopping >= metres:
			braking = true
		var cmd_throttle := throttle * gear
		var cmd_turn := turn
		if braking:
			if speed > PlannerExecutor.BRAKE_TO_SPEED:
				cmd_throttle = -throttle * gear
			else:
				cmd_throttle = 0.0
				cmd_turn = 0.0
		var was: Vector3 = state["position"]
		TankMotion.step_in_place(state, cmd_throttle, cmd_turn, TankMotion.TICK_SECONDS)
		var now: Vector3 = state["position"]
		travelled += Vector2(now.x - was.x, now.z - was.z).length()
		ticks += 1
	var f: Vector3 = state["forward"]
	var p: Vector3 = state["position"]
	return {"x": p.x, "z": p.z, "fx": f.x, "fz": f.z, "metres": travelled, "ticks": ticks}


## The planner's pose after one leg of `metres` at `steer` in `gear` from the origin heading north.
func _plan_leg(unit: String, gear: int, steer: float, metres: float) -> Dictionary:
	var req := PlanRequest.for_unit(unit).at(0.0, 0.0, 0.0, -1.0)
	var out := PackedPlan.new()
	out.legs = [Vector3(float(gear), steer, metres)]
	Planner.trace(req, out)
	return {"x": out.end_x, "z": out.end_z, "fx": out.end_fx, "fz": out.end_fz}


func _compare(unit: String, label: String, gear: int, steer: float, metres: float, bar := 0.01) -> void:
	var req := PlanRequest.for_unit(unit)
	var plant := _drive_leg(unit, gear, req.throttle_fwd if gear > 0 else req.throttle_rev, steer, metres)
	var planned := _plan_leg(unit, gear, steer, metres)
	var off := Vector2(float(plant["x"]) - float(planned["x"]), float(plant["z"]) - float(planned["z"])).length()
	var deg := rad_to_deg(absf(Vector2(float(plant["fx"]), float(plant["fz"])).angle_to(Vector2(float(planned["fx"]), float(planned["fz"])))))
	print("MEASURE planner_twin %s %s: planned %.1f m, driven %.2f m in %d ticks, plant (%.2f, %.2f) v planned (%.2f, %.2f): off %.3f m (%.2f %% of the leg), %.2f deg" % [
			unit, label, metres, float(plant["metres"]), int(plant["ticks"]), float(plant["x"]), float(plant["z"]), float(planned["x"]),
			float(planned["z"]), off, 100.0 * off / metres, deg])
	# The executor cannot end a leg finer than the plant's tick quantum: half a tick's travel at the leg speed.
	var quantum := (req.v_fwd if gear > 0 else req.v_rev) * TankMotion.TICK_SECONDS * 0.5 + 0.02
	assert_true(off <= maxf(bar * metres, quantum), "%s %s: the plant ends within %.0f %% of the planned pose or half a tick's travel (off %.3f m of %.1f, quantum %.2f)" % [unit, label, bar * 100.0, off, metres, quantum])
	var deg_quantum := rad_to_deg(quantum / req.radius)
	assert_true(deg <= maxf(1.0, deg_quantum), "%s %s: the plant's heading is the planned one (%.2f deg off; the tick quantum is %.2f deg)" % [unit, label, deg, deg_quantum])


func test_a_straight_leg_is_the_plants_straight() -> void:
	_compare("gang_tank", "straight 20 m", 1, 0.0, 20.0)
	_compare("ifv", "straight 20 m", 1, 0.0, 20.0)


func test_a_full_lock_arc_is_the_plants_arc() -> void:
	var r := float(Units.stat("gang_tank", "min_turn_radius_m", 12.0))
	_compare("gang_tank", "full lock 90 deg", 1, 1.0, r * PI * 0.5)
	_compare("ifv", "full lock 90 deg", 1, -1.0, float(Units.stat("ifv", "min_turn_radius_m", 7.0)) * PI * 0.5)
	# The Rat Rod: 11.5 m/s on R 4.5 is a 4.9-degree lag; the residual of the constant-lag model over its spin-up and
	# braking is ~4 % of a short arc. Not a tight-space hull; measured, held to 5 %.
	_compare("gang_scout", "full lock 90 deg (under its yaw cap)", 1, 1.0, float(Units.stat("gang_scout", "min_turn_radius_m", 4.5)) * PI * 0.5, 0.05)


func test_a_short_arc_is_the_plants_arc() -> void:
	# A leg shorter than its spin-up plus braking never cruises: the lag model's residual is largest here (a rig's
	# 4 m leg: 2 %), so short legs are held to 3 % — and the planner never emits a leg under a metre.
	_compare("gang_tank", "full lock 4 m", 1, 1.0, 4.0, 0.03)
	_compare("ifv", "full lock 3 m", 1, 1.0, 3.0, 0.03)


func test_a_reverse_arc_is_the_plants_reverse() -> void:
	_compare("gang_tank", "reverse full lock 10 m", -1, 1.0, 10.0)
	_compare("ifv", "reverse full lock 10 m", -1, -1.0, 10.0)


## The plant's yaw is capped at hull_turn_rate_deg: the leg speed the request plans for must keep v / R under the cap
## on full lock, or the arc the plant drives is wider than the plan's. for_unit lowers the leg throttle where it must
## (the Rat Rod: 160 deg/s at 0.7 throttle against a 150 cap); the table is printed for P4.
func test_leg_speeds_stay_under_the_yaw_cap() -> void:
	for unit_id: String in Units.PROFILES:
		if String(Units.stat(unit_id, "locomotion", "tracks")) != "wheels":
			continue
		var req := PlanRequest.for_unit(unit_id)
		var yaw_deg := rad_to_deg(req.v_fwd / req.radius)
		if req.throttle_fwd < 0.7 - 0.001:
			print("MEASURE planner_yaw_cap %s: leg throttle lowered to %.2f (%.1f m/s on R %.1f = %.0f deg/s, cap %.0f)" % [
					unit_id, req.throttle_fwd, req.v_fwd, req.radius, yaw_deg, req.omega_max_deg])
		assert_true(yaw_deg <= req.omega_max_deg + 0.001, "%s at %.1f m/s on R %.1f yaws %.0f deg/s, under its cap %.0f" % [
				unit_id, req.v_fwd, req.radius, yaw_deg, req.omega_max_deg])

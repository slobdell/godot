extends TestCase
## Round 9 (nav, A11 — Fox, Burgard & Thrun 1997, *The Dynamic Window Approach*): score a fixed lattice of
## (speed, yaw-rate) pairs the plant can ACTUALLY REACH this tick, as constant-curvature arcs, instead of a ring of
## 16 directions some of which the hull cannot take. **The ring is why a heavy hull picks a heading and then hunts
## toward it** — it scores a direction, the plant cannot deliver it, and the next plan picks a different one.
##
## The claim these tests hold A11 to is narrow and checkable: **every candidate it offers is one `TankMotion` can
## execute.** That is the whole difference from the ring, and it is verified against the plant itself rather than
## against a restatement of the plant's rules — the two drifting apart is how the chord test got it wrong for wheels.

const HORIZON := CombatMotion.DWA_HORIZON


static func _state(unit_id: String, speed: float, yaw_rate := 0.0) -> Dictionary:
	var state := TankMotion.state_for(unit_id, Vector3.ZERO, Vector3.FORWARD, speed)
	state["velocity"] = Vector3.FORWARD * speed
	state["yaw_rate"] = yaw_rate
	return state


func test_every_offered_arc_is_one_the_plant_can_actually_drive() -> void:
	# The window is over the CONTROL PERIOD (how long a command is actually held before the next plan), not over one
	# tick, so this drives the plant for that long and checks the cell promised what the plant delivered: the pose it
	# reaches, the speed it ends at, and the yaw rate it is turning at when it gets there.
	var ticks := maxi(1, int(CombatMotion.DWA_CONTROL_SECONDS * SimClock.TICK_RATE))
	for unit_id: String in ["tank", "ifv", "scout"]:
		var state := _state(unit_id, 4.0)
		var lattice := CombatMotion.dynamic_window(state)
		assert_true(not lattice.is_empty(), "%s gets a lattice (%d)" % [unit_id, lattice.size()])
		for cell: Dictionary in lattice:
			var driven: Dictionary = state.duplicate()
			for _t in ticks:
				TankMotion.step_in_place(driven, float(cell["throttle"]), float(cell["turn"]), SimClock.TICK_SECONDS)
			assert_near(float(driven["speed"]), float(cell["speed"]), 0.0001,
					"%s: the plant reached the speed the cell promised (cell %s)" % [unit_id, cell])
			assert_near((driven["position"] as Vector3).distance_to(cell["position"] as Vector3), 0.0, 0.0001,
					"%s: and the pose (cell %s)" % [unit_id, cell])
			assert_near((driven["forward"] as Vector3).dot(cell["forward"] as Vector3), 1.0, 0.0001,
					"%s: and the heading (cell %s)" % [unit_id, cell])


func test_a_car_is_never_offered_a_turn_it_cannot_roll_into() -> void:
	# The ring offers a stopped car all 16 directions and the plant answers with a creep K-turn. A car's yaw is
	# `|speed| * turn / radius`, so turning REQUIRES rolling — and over a control period a stopped car may legitimately
	# roll first and then turn, which is why the claim is not "no turning arcs" but "no turning without travelling".
	# The lattice cannot offer a pivot in place to something that has no way of performing one.
	for start_speed: float in [0.0, 6.0]:
		var state := _state("ifv", start_speed)
		for cell: Dictionary in CombatMotion.dynamic_window(state):
			var swung := absf(float(cell["mean_yaw"]))
			if swung <= 0.01:
				continue
			var moved := (cell["position"] as Vector3).distance_to(state["position"] as Vector3)
			assert_true(moved > 0.05,
					"a car that turned %.2f rad/s travelled to do it (%.3f m, from %.1f m/s)" % [swung, moved, start_speed])


func test_a_tracked_hull_reaches_its_full_turn_rate_within_the_control_period() -> void:
	# Round 8 gave tracks an angular-acceleration ramp, and YAW_RAMP_SECONDS is 0.25 — exactly the control period.
	# So a hull starting from rest CAN be offered its full rate by the end of the period, and must be: a one-tick
	# window offered it 21 degrees of heading change over a 2 s arc, every candidate pointed nearly the same way,
	# level 3 had nothing to choose between, and the duel scenario's tank died in 6.3 s of a 20 s fight.
	var state := _state("tank", 3.0, 0.0)
	var max_rate := deg_to_rad(float(state["hull_turn_rate_deg"]))
	var widest := 0.0
	for cell: Dictionary in CombatMotion.dynamic_window(state):
		widest = maxf(widest, absf(float(cell["yaw_rate"])))
	# Within a tenth: the period is a whole number of ticks (7 at 30 Hz = 0.233 s), so the ramp gets 93% of the way
	# rather than exactly all of it. The point of the assertion is "most of its rate", not a fencepost.
	assert_near(widest, max_rate, max_rate * 0.1,
			"a hull given the whole control period reaches its rate (%.3f of %.3f rad/s)" % [widest, max_rate])


func test_the_lattice_is_a_fixed_size_and_the_same_every_time() -> void:
	var a := CombatMotion.dynamic_window(_state("tank", 5.0, 0.2))
	var b := CombatMotion.dynamic_window(_state("tank", 5.0, 0.2))
	assert_eq(a.size(), b.size(), "same size")
	assert_true(a.size() <= CombatMotion.DWA_SPEEDS * CombatMotion.DWA_YAWS,
			"never more than the fixed grid (%d)" % a.size())
	for i in a.size():
		assert_near(float((a[i] as Dictionary)["yaw_rate"]), float((b[i] as Dictionary)["yaw_rate"]), 0.0000001,
				"cell %d identical, row-major and deterministic" % i)


## The arm, provable from outside (lesson 147, and round 8's `gates aimed 0` in both arms). A11 only means anything
## inside A7's chooser, so both switches are pinned here rather than inherited.
func test_the_lattice_replaces_the_ring_and_says_so() -> void:
	var request := {"position": Vector3.ZERO, "forward": Vector3.FORWARD, "speed": 10.0, "reverse_speed": 5.0,
			"style": "strafe", "target": {"position": Vector3(0, 0, -30), "forward": Vector3.BACK, "velocity": Vector3.ZERO},
			"band": [15.0, 40.0], "side": 1.0, "wheels": false, "turn_rate_deg": 90.0, "acceleration": 8.0,
			"velocity": Vector3.FORWARD * 6.0, "limit": 200.0,
			"motion": _state("tank", 6.0, 0.1)}
	var was := Movement._off
	Movement._off = PackedStringArray(["a7"])
	Movement._off_parsed = true
	CombatMotion.reset_arms()
	var ring := CombatMotion.choose(request)
	var ring_arms := CombatMotion.arm_report()
	Movement._off = PackedStringArray(["a7", "a11"])
	CombatMotion.reset_arms()
	var lattice := CombatMotion.choose(request)
	var lattice_arms := CombatMotion.arm_report()
	Movement._off = was
	assert_eq(int(ring_arms["a11_lattices"]), 0, "the ring arm builds no lattice (%s)" % ring_arms)
	assert_true(int(lattice_arms["a11_lattices"]) > 0, "the lattice arm builds one (%s)" % lattice_arms)
	assert_true(int(lattice_arms["dwa_candidates_reachable"]) > 16,
			"and it offers more than a ring's worth of reachable arcs (%s)" % lattice_arms)
	assert_eq(int(lattice_arms["a11_with_live_state"]), 1,
			"built from the hull's LIVE motion state, not a synthesised one (%s)" % lattice_arms)
	assert_true(not ring.is_empty() and not lattice.is_empty(), "both arms chose something")

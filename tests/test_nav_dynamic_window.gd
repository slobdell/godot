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
	for unit_id: String in ["tank", "ifv", "scout"]:
		var state := _state(unit_id, 4.0)
		var lattice := CombatMotion.dynamic_window(state)
		assert_true(not lattice.is_empty(), "%s gets a lattice (%d)" % [unit_id, lattice.size()])
		for cell: Dictionary in lattice:
			# Drive the plant for one tick with this cell's controls and check it produced this cell's motion.
			var driven := TankMotion.step(state, float(cell["throttle"]), float(cell["turn"]), SimClock.TICK_SECONDS)
			var forward: Vector3 = state["forward"]
			var turned: Vector3 = driven["forward"]
			var got_yaw := (forward.x * turned.z - forward.z * turned.x) / SimClock.TICK_SECONDS
			var wanted_yaw := float(cell["yaw_rate"])
			# Tight on purpose. At 0.06 this assertion passed a lattice that promised a STOPPED CAR 36 turning arcs,
			# because one tick of a small promised yaw fits inside a loose tolerance. A tolerance wide enough to
			# accept a wrong model is not a test.
			assert_near(got_yaw, wanted_yaw, 0.0001,
					"%s: the plant yawed what the cell promised (cell %s)" % [unit_id, cell])
			assert_near(float(driven["speed"]), float(cell["speed"]), 0.0001,
					"%s: and reached the speed the cell promised (cell %s)" % [unit_id, cell])


func test_a_car_standing_still_is_offered_no_turning_arcs() -> void:
	# The ring offers a stopped car all 16 directions and the plant answers with a creep K-turn. The lattice cannot
	# offer what `yaw = |speed| * turn / radius` will not produce, so the choice is honest at the point it is made.
	var still := CombatMotion.dynamic_window(_state("ifv", 0.0))
	var turning := still.filter(func(c: Dictionary) -> bool: return absf(float(c["yaw_rate"])) > 0.01)
	assert_eq(turning.size(), 0, "a stopped car is offered no turning arc (%d of %d)" % [turning.size(), still.size()])
	var rolling := CombatMotion.dynamic_window(_state("ifv", 6.0))
	var turns := rolling.filter(func(c: Dictionary) -> bool: return absf(float(c["yaw_rate"])) > 0.01)
	assert_true(turns.size() > 0, "and a rolling one is offered plenty (%d of %d)" % [turns.size(), rolling.size()])


func test_a_tracked_hull_is_offered_only_the_yaw_its_ramp_allows_this_tick() -> void:
	# Round 8 gave tracks an angular-acceleration ramp, so a hull at rest cannot be at full turn rate this tick.
	# A lattice that ignored the ramp would offer exactly the unreachable heading the ring offers.
	var from_rest := CombatMotion.dynamic_window(_state("tank", 3.0, 0.0))
	var widest := 0.0
	for cell: Dictionary in from_rest:
		widest = maxf(widest, absf(float(cell["yaw_rate"])))
	var max_rate := deg_to_rad(float(_state("tank", 3.0)["hull_turn_rate_deg"]))
	assert_true(widest < max_rate,
			"a hull not yet turning cannot be offered its full rate this tick (%.3f of %.3f rad/s)" % [widest, max_rate])
	var already := CombatMotion.dynamic_window(_state("tank", 3.0, max_rate * 0.9))
	var widest_moving := 0.0
	for cell: Dictionary in already:
		widest_moving = maxf(widest_moving, absf(float(cell["yaw_rate"])))
	assert_true(widest_moving > widest, "a hull already turning is offered more (%.3f vs %.3f)" % [widest_moving, widest])


func test_the_lattice_is_a_fixed_size_and_the_same_every_time() -> void:
	var a := CombatMotion.dynamic_window(_state("tank", 5.0, 0.2))
	var b := CombatMotion.dynamic_window(_state("tank", 5.0, 0.2))
	assert_eq(a.size(), b.size(), "same size")
	assert_true(a.size() <= CombatMotion.DWA_SPEEDS * CombatMotion.DWA_YAWS,
			"never more than the fixed grid (%d)" % a.size())
	for i in a.size():
		assert_near(float((a[i] as Dictionary)["yaw_rate"]), float((b[i] as Dictionary)["yaw_rate"]), 0.0000001,
				"cell %d identical, row-major and deterministic" % i)

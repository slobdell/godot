extends TestCase
## Control X5 (round 6): orders you can see landing. nav's N1 `Movement.state(unit)` says whether a unit is yielding,
## blocked or driving with an ETA; the HUD says so over the vehicle and on its card. nav's CP1 is not on `main` yet, so
## these tests feed the readout a fake provider shaped exactly like the N1 contract.

const Fixture := preload("res://tests/support/control_fixture.gd")


func test_a_blocked_or_yielding_unit_says_so_over_the_vehicle_and_on_its_card() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	var states := {
		"Green_Alpha_1": {"phase": "blocked", "blocked_by": "Green_Alpha_2", "eta_s": -1.0},
		"Green_Alpha_3": {"phase": "yielding", "eta_s": 6.0},
		"Green_Bravo_1": {"phase": "driving", "eta_s": 4.2},
	}
	f.controls.movement.provider = func(unit_name: String) -> Dictionary: return states.get(unit_name, {})
	var words := {}
	for callout: Dictionary in f.controls.callouts():
		words[callout["unit"]] = callout["word"]
	assert_eq(words.get("Green_Alpha_1", ""), "BLOCKED", "a blocked unit says so (%s)" % [words])
	assert_eq(words.get("Green_Alpha_3", ""), "YIELDING", "a unit giving way says so")
	assert_true(not words.has("Green_Bravo_1"), "a unit driving to its order needs no words")
	var panel := SelectionPanel.new()
	panel.controls = f.controls
	f.controls.add_child(panel)
	await f.select(["Green_Alpha_1"])
	assert_true(String(panel.summary()["card"]["orders"]).contains("Blocked by Tank"), "its card names what blocks it (%s)" %
			panel.summary()["card"]["orders"])
	await f.select(["Green_Bravo_1"])
	assert_true(String(panel.summary()["card"]["orders"]).contains("Arrives in 4 s"), "a driving unit's card gives its ETA (%s)" %
			panel.summary()["card"]["orders"])


func test_with_no_movement_system_nothing_is_drawn_or_said() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	assert_true(f.controls.callouts().is_empty(), "no provider, no callouts")
	assert_eq(f.controls.movement.card_line("Green_Alpha_1"), "", "and no card line")
	# The real wiring: until nav's Movement class exists this is an invalid Callable, not an error.
	var provider := MovementReadout.from_movement(f.game_match)
	assert_true(provider.is_valid() == ProjectSettings.get_global_class_list().any(
			func(entry: Dictionary) -> bool: return String(entry["class"]) == "Movement"),
			"the provider exists exactly when nav's Movement does")


## nav's N1 as it actually shipped (30e3250d): `blocked_by` may be "no_path" or "terrain", `stalled_s` says how long a
## unit has made no progress, `{}` means a hull nothing drives, and `path_points` is the rest of the route.
func test_the_readout_speaks_nav_as_it_shipped() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	var states := {
		"Green_Alpha_1": {"phase": "blocked", "blocked_by": "no_path"},
		"Green_Alpha_2": {"phase": "driving", "eta_s": 9.0, "stalled_s": 4.4},
		"Green_Alpha_3": {},
		"Green_Bravo_1": {"phase": "driving", "eta_s": 3.0, "stalled_s": 0.0,
				"path_points": PackedVector3Array([Vector3(10, 0, 30), Vector3(10, 0, 10)])},
	}
	var readout := f.controls.movement
	readout.provider = func(unit_name: String) -> Dictionary: return states.get(unit_name, {})
	assert_eq(readout.card_line("Green_Alpha_1"), "No way through", "no path, said plainly")
	assert_eq(readout.callout("Green_Alpha_2"), "STUCK", "a unit making no progress reads as stuck, not idle")
	assert_eq(readout.card_line("Green_Alpha_2"), "Stuck for 4 s", "and its card says for how long")
	assert_eq(readout.callout("Green_Alpha_3"), "", "a hull nothing drives says nothing")
	assert_eq(readout.card_line("Green_Alpha_3"), "", "on the card either")
	assert_eq(readout.route("Green_Bravo_1").size(), 2, "the route nav means to take is there to draw")
	assert_eq(readout.route("Green_Alpha_3").size(), 0, "and absent when there is none")


## With nav's N1 on main (f03a795c), the real provider: an ordered unit reports a driving phase and an ETA through the
## readout, and its card says when it arrives.
func test_the_real_movement_api_reaches_the_card() -> void:
	var f := Fixture.new(self)
	await f.build(true)
	var provider := MovementReadout.from_movement(f.game_match)
	assert_true(provider.is_valid(), "nav's Movement is on main, so the provider is live")
	f.controls.movement.provider = provider
	await f.select(["Green_Bravo_2"])
	assert_eq(f.controls.order_selection("move", {"to": [20.0, -20.0]}), "", "the unit is sent 60 m north")
	await wait_physics_frames(12)
	var reading := f.controls.movement.state("Green_Bravo_2")
	print("MEASURE control_movement_readout real state %s" % [reading])
	assert_true(String(reading.get("phase", "")) in ["pathing", "driving", "blocked", "yielding"], "it reports a phase (%s)" % [reading])
	assert_true(float(reading.get("eta_s", -1.0)) > 0.0, "and an ETA")
	var line := f.controls.movement.card_line("Green_Bravo_2", f.controls._unit_label)
	assert_true(line != "", "its card says something about getting there (%s)" % line)


## S4 / A6 (`_agents/legibility.md` §2 and §6.1, signed 2026-09-20): the ordered corridor, split into the CURRENT LEG
## and the rest. The legibility law is a claim about the current leg and nothing else, so the player has to be able to
## see which leg he is judging - and an INACTIVE law (no path) draws nothing at all rather than a guessed corridor.
func test_the_corridor_names_its_current_leg_and_is_empty_when_the_law_is_inactive() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	var route := PackedVector3Array([Vector3(10, 0, 20), Vector3(30, 0, 0), Vector3(30, 0, -30)])
	var states := {
		"Green_Bravo_1": {"phase": "driving", "eta_s": 6.0, "path_points": route},
		"Green_Alpha_1": {"phase": "blocked", "blocked_by": "no_path"},
		"Green_Alpha_2": {},
	}
	var readout := f.controls.movement
	readout.provider = func(unit_name: String) -> Dictionary: return states.get(unit_name, {})
	var here := f.tank("Green_Bravo_1").global_position
	var lane := readout.corridor("Green_Bravo_1", here)
	assert_true(not lane.is_empty(), "a unit with a path has a corridor")
	var leg: Array = lane["leg"]
	assert_true((leg[0] as Vector3).distance_to(Vector3(here.x, 0.0, here.z)) < 0.01,
			"the current leg starts at the unit, got %s" % [leg[0]])
	assert_true((leg[1] as Vector3).distance_to(Vector3(10, 0, 20)) < 0.01,
			"and ends at its NEXT waypoint, not at the goal, got %s" % [leg[1]])
	assert_eq((lane["rest"] as PackedVector3Array).size(), 2, "the two legs after it are the rest")
	var tangent := readout.corridor_tangent("Green_Bravo_1", here)
	var expected := (Vector3(10, 0, 20) - Vector3(here.x, 0.0, here.z)).normalized()
	assert_true(tangent.distance_to(expected) < 0.01, "the tangent is the current leg's direction, got %s" % [tangent])
	# Inactive: no path (blocked), and a hull nothing drives. Neither invents a corridor.
	assert_true(readout.corridor("Green_Alpha_1", f.tank("Green_Alpha_1").global_position).is_empty(),
			"a blocked unit with no path has no corridor - the law is inactive, and an inactive law draws nothing")
	assert_eq(readout.corridor_tangent("Green_Alpha_1", f.tank("Green_Alpha_1").global_position), Vector3.ZERO,
			"and no tangent")
	assert_true(readout.corridor("Green_Alpha_2", f.tank("Green_Alpha_2").global_position).is_empty(),
			"a hull nav knows nothing about has no corridor")

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


## S4 / A6 C-2 and C-3 (`_agents/legibility.md` §6, signed 2026-09-20), and the test control's brief asks for: the
## readout tells a DELIBERATE off-corridor leg (nav says a level took the nose) from an UNREACHED GOAL (nav says it
## cannot proceed), and says nothing at all about a unit on its corridor.
##
## The shape is nav's N5: `Movement.state(unit)["legibility"] = {"active": bool, "why": StringName}`. nav has stated
## that with A7 off - today's default - `why` can only ever be `override`, because the blend is a weighted sum and no
## term "bound" anything. So the vocabulary is tested BOTH ways: rich when nav can name the level, and correct when
## it cannot.
func test_the_readout_names_the_cause_and_never_invents_one() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	var states := {
		# On its corridor: the law is active, and there is nothing to explain.
		"Green_Alpha_1": {"phase": "driving", "legibility": {"active": true, "why": ""}},
		# Off the corridor, deliberately, and nav names the level that took the nose.
		"Green_Alpha_2": {"phase": "driving", "legibility": {"active": false, "why": "band"}},
		# Off the corridor because it CANNOT PROCEED. That is the callout band's job, not this one.
		"Green_Alpha_3": {"phase": "blocked", "blocked_by": "no_path", "legibility": {"active": false, "why": "blocked"}},
		# A7 off: the honest single word. This is what the default path says until A7 is on by default.
		"Green_Bravo_1": {"phase": "driving", "legibility": {"active": false, "why": "override"}},
		# A unit with no order at all: inactive, and silent.
		"Green_Bravo_2": {"phase": "driving", "legibility": {"active": false, "why": "no_order"}},
	}
	var readout := f.controls.movement
	readout.provider = func(unit_name: String) -> Dictionary: return states.get(unit_name, {})
	assert_eq(readout.legibility_line("Green_Alpha_1"), "", "a unit on its corridor gets no readout at all")
	assert_eq(readout.legibility_line("Green_Alpha_2"), "holding its range", "a deliberate off-corridor leg names its cause")
	assert_eq(readout.legibility_line("Green_Alpha_3"), "",
			"an unreached goal is the callout band's (BLOCKED / STUCK), never this one: A6 is about a unit that IS proceeding")
	assert_eq(readout.callout("Green_Alpha_3"), "BLOCKED", "and that band still says it")
	assert_eq(readout.legibility_line("Green_Bravo_1"), "a higher priority has the wheel",
			"with A7 off nav can only say `override`, and the words must still read correctly")
	assert_eq(readout.legibility_line("Green_Bravo_2"), "", "a unit with no order has nothing to be off the corridor of")
	# The half that matters most: control NEVER INVENTS A CAUSE. A build whose nav publishes no legibility at all -
	# which is every build before nav's N5 - is silent, not "unknown".
	states["Green_Alpha_2"] = {"phase": "driving"}
	assert_eq(readout.legibility_line("Green_Alpha_2"), "",
			"nav publishing nothing means the readout says nothing: a guessed cause is confidently wrong")
	# An unknown `why` from a future nav degrades to the honest single word rather than showing a raw key.
	states["Green_Alpha_2"] = {"phase": "driving", "legibility": {"active": false, "why": "something_new"}}
	assert_eq(readout.legibility_line("Green_Alpha_2"), "a higher priority has the wheel",
			"a cause this build does not know is still a cause, and is never shown as a raw key")


## C-3's channel rule, end to end: the cause reaches "why did my element do that" and NOTHING ELSE. The order pin is
## a refusal's channel and must stay that way, or "it is doing this deliberately" and "it is not doing it" become the
## same claim on screen.
func test_the_cause_reaches_the_element_log_and_not_the_order_pin() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	f.controls.elements = Elements.install(f.game_match, f.orders)
	f.controls.element_log.attach(f.controls.elements, f.game_match)
	f.controls.groups.save(2, ["Green_Bravo_1", "Green_Bravo_2"])
	# `Elements.install` creates the registry, not the elements: an element is formed when the player gives a task
	# (or here, directly). The note path reads `elements.of(unit)`, so that is what this test needs to exist.
	var element := f.controls.elements.form(["Green_Bravo_1", "Green_Bravo_2"], "Bravo")
	assert_true(element != null, "setup: the two are an element")
	await f.select(["Green_Bravo_1", "Green_Bravo_2"])
	var states := {"Green_Bravo_1": {"phase": "driving", "legibility": {"active": false, "why": "survival"}}}
	f.controls.movement.provider = func(unit_name: String) -> Dictionary: return states.get(unit_name, {})
	var notes := f.controls.legibility_notes()
	assert_eq(notes.size(), 1, "one cause, for the one unit that has one (%s)" % [notes])
	assert_eq(String(notes[0]["why"]), "under fire", "in the words already on screen")
	await wait_physics_frames(2)
	var lines := f.controls.element_log.lines(element.id)
	assert_true(lines.any(func(line: String) -> bool: return line.contains("under fire")),
			"the cause is in 'why did my element do that' (%s)" % [lines])
	var before := lines.size()
	await wait_physics_frames(6)
	assert_eq(f.controls.element_log.lines(element.id).size(), before,
			"and a cause that lasts is ONE line, not one per frame")
	# The pin is the REFUSAL's channel (a pin turns red and says NOT COMPLYING), and a deliberate off-corridor leg
	# must never reach it, or "it is doing this on purpose" and "it is not doing it" become the same claim on screen.
	# These units have orders from their brains, so pins exist; what must be true is that none of them is a refusal.
	for mark: Dictionary in f.controls.order_marks():
		assert_eq(int(mark.get("refusing", 0)), 0,
				"the cause never turns a pin red: that is the refusal channel (%s)" % [mark])

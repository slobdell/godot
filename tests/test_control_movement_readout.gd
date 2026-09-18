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

extends TestCase
## Round 8, the lead: "telling a group of units to attack a single unit, but they don't obey and instead they shoot at
## whatever they were already shooting at." He found out by watching turrets. The rule: he never learns an order failed
## by inferring it from behaviour - an order that isn't being carried out says so, and says why.

const Fixture := preload("res://tests/support/control_fixture.gd")


func _wait_s(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await tree.process_frame


func test_a_unit_shooting_something_else_says_so() -> void:
	var f := Fixture.new(self)
	await f.build(true)
	var shooting := {"Green_Alpha_1": "Rust_Other_9"}  # what each gun is actually on (stubbed: the lead's case)
	f.controls.engaged_of = func(unit_name: String) -> String: return String(shooting.get(unit_name, ""))
	await f.select(["Green_Alpha_1"])
	assert_eq(f.controls.order_selection("attack", {"target": "Rust_Alpha_1"}), "", "the attack order is taken")
	var marks := f.controls.order_marks()
	assert_eq(marks.size(), 1, "an attack order has a pin too (%s)" % [marks])
	assert_eq(marks[0]["verb"], "attack", "on its target")
	assert_true((marks[0]["point"] as Vector3).distance_to(f.tank("Rust_Alpha_1").global_position * Vector3(1, 0, 1)) < 1.0,
			"at the target")
	# Not yet: a gun gets a moment to come round before it counts as ignoring the order.
	assert_true(f.controls.order_refusals().is_empty(), "no verdict inside the grace")
	await _wait_s(RtsControls.COMPLY_GRACE_S + 0.5)
	var refusals := f.controls.order_refusals()
	assert_eq(refusals.size(), 1, "then the unit that is shooting something else is called out (%s)" % [refusals])
	assert_true(String(refusals[0]["why"]).begins_with("FIRING ON"), "and it says what it is shooting at (%s)" % refusals[0]["why"])
	assert_true(String(f.controls.order_mark_label(f.controls.order_marks()[0])).contains("0/1 on target"),
			"the pin counts nobody on target (%s)" % f.controls.order_mark_label(f.controls.order_marks()[0]))
	# It comes round: the callout clears and the pin counts it.
	shooting["Green_Alpha_1"] = "Rust_Alpha_1"
	await tree.process_frame
	assert_true(f.controls.order_refusals().is_empty(), "on target: nothing to call out")
	assert_true(String(f.controls.order_mark_label(f.controls.order_marks()[0])).contains("1/1 on target"), "and the pin counts it")


func test_the_executor_reports_what_a_unit_is_really_engaging() -> void:
	var f := Fixture.new(self)
	await f.build(true)
	await f.select(["Green_Alpha_1"])
	f.controls.order_selection("attack", {"target": "Rust_Alpha_1"})
	var engaged := ""
	for i in 240:
		await tree.physics_frame
		engaged = f.executor.engaged_target_of("Green_Alpha_1")
		if engaged != "":
			break
	assert_eq(engaged, "Rust_Alpha_1", "an ordered unit reports its real target through the executor")
	assert_eq(f.executor.engaged_target_of("Green_Bravo_2"), f.executor.engaged_target_of("Green_Bravo_2"),
			"and a unit with no order answers from its brain without error")


## No stub: the fixture wires the real executor (as skirmish_mode does), and an obeyed order reads as obeyed.
func test_an_obeyed_attack_counts_its_gun_on_target() -> void:
	var f := Fixture.new(self)
	await f.build(true)
	await f.select(["Green_Alpha_1"])
	f.controls.order_selection("attack", {"target": "Rust_Alpha_1"})
	for i in 240:
		await tree.physics_frame
		if f.controls.engaged_target("Green_Alpha_1") == "Rust_Alpha_1":
			break
	assert_eq(f.controls.engaged_target("Green_Alpha_1"), f.executor.engaged_target_of("Green_Alpha_1"),
			"controls reads the executor's truth")
	assert_true(String(f.controls.order_mark_label(f.controls.order_marks()[0])).contains("1/1 on target"),
			"the pin counts the gun on target (%s)" % f.controls.order_mark_label(f.controls.order_marks()[0]))
	await _wait_s(RtsControls.COMPLY_GRACE_S + 0.3)
	assert_true(f.controls.order_refusals().is_empty(), "and nothing is called out (%s)" % [f.controls.order_refusals()])


## The lead's own gesture: a whole squad selected (its number key), right-click an enemy. That is an attack TASK - its
## leader decides who shoots - so no unit carries an attack order of its own. The pin and the callouts still hold every
## member to the target the player chose.
func test_a_squad_told_to_attack_is_held_to_it() -> void:
	var f := Fixture.new(self)
	await f.build(true)
	f.controls.elements = Elements.install(f.game_match, f.orders)
	f.controls.groups.save(1, ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"])
	var shooting := {"Green_Alpha_1": "Rust_Alpha_1", "Green_Alpha_2": "Rust_Other_9", "Green_Alpha_3": "Rust_Other_9"}
	f.controls.engaged_of = func(unit_name: String) -> String: return String(shooting.get(unit_name, ""))
	await f.key(KEY_1)
	assert_eq(f.controls.order_selection("attack", {"target": "Rust_Alpha_1"}), "", "the squad takes the attack")
	var element := f.controls.elements.of("Green_Alpha_1")
	assert_true(element != null and String(element.task.get("verb", "")) == "attack", "as a task (%s)" % [element.task if element else null])
	await _wait_s(RtsControls.COMPLY_GRACE_S + 0.5)
	var refused: Array = f.controls.order_refusals().map(func(r: Dictionary) -> String: return String(r["unit"]))
	assert_eq(refused, ["Green_Alpha_2", "Green_Alpha_3"], "the two members shooting something else are called out")
	var label := String(f.controls.order_mark_label(f.controls.order_marks()[0]))
	assert_true(label.begins_with("ATTACK · 1/3 on target"), "the squad's pin counts one gun on target (%s)" % label)
	assert_true(label.contains("2 NOT COMPLYING"), "and says two are not (%s)" % label)


## Refused at the moment it is given: every refusal reaches the player (the HUD shows command_issued errors as "Can't:
## ..."). Five refusals used to return their reason to nobody - the order simply didn't happen.
func test_a_task_refused_on_the_spot_is_announced() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	f.controls.elements = Elements.install(f.game_match, f.orders)
	var heard: Array = []
	f.controls.command_issued.connect(func(_command: Dictionary, error: String) -> void: heard.append(error))
	f.controls.selection.set_units(["Green_Alpha_1", "Green_Bravo_2"])  # not a whole element: no task can be given
	var error := f.controls.order_selection("screen", {"to": [0.0, -30.0]})
	assert_true(error != "", "the task is refused (%s)" % error)
	assert_eq(heard, [error], "and the refusal is announced, not just returned")

extends TestCase
## Control X4: command at 30+ units a side. Selection, groups, the panel and the edge markers have to stay
## readable and cheap with a real army on the field, and the player needs to reach "everything" and "whoever is
## doing nothing" in one key. The measurements the brief asks for (input-to-order latency, per-frame cost with
## 60 units selected) are printed as MEASURE lines and held to a budget here.

const Fixture := preload("res://tests/support/control_fixture.gd")
## A side, matching the lead's baseline ("a baseline of 30 units per side").
const PER_SIDE := 30
## Control's own per-frame work at this scale, in milliseconds. ai budgets 4 ms a tick for sixty brains; the UI
## reading the same world must cost a fraction of that.
## The old 2.0 ms frame budget in reference workloads (Fixture.reference_work, 0.077 ms on the idle laptop): 26. A loaded machine slows
## both, so this means the same on a shared builder0 (P- and E-cores) as on an idle laptop. Measured 18.8-20.2 (laptop).
## LIMIT: a CPU fully oversubscribed (every thread busy) still inflates the work far more than the reference - the order
## path starves on engine worker threads - so the ratio answers core type and throughput, not starvation.
const FRAME_BUDGET_REFERENCES := 26.0
## A player's order must reach Orders in well under a frame: the old 8 ms, in reference workloads (Fixture.reference_work
## is 0.077 ms on the idle laptop): 104. Measured 36-42 at 53a2af87+ (laptop, idle and loaded).
const ORDER_BUDGET_REFERENCES := 104.0


func _frames(count := 2) -> void:
	for i in count:
		await tree.process_frame


func _setup() -> Fixture:
	var f := Fixture.new(self)
	await f.build_scale(PER_SIDE)
	return f


func test_a_whole_army_can_be_selected_and_ordered_in_one_go() -> void:
	var f := await _setup()
	await f.key(KEY_A, false, true)
	assert_eq(f.controls.selection.units.size(), PER_SIDE, "ctrl+A selects the whole army")
	var error := f.controls.order_selection("move", {"to": [0.0, -60.0]})
	assert_eq(error, "", "and one order covers all of them")
	for unit_name in f.controls.selection.units:
		assert_eq(f.orders.current(unit_name).get("verb", ""), "move", "%s has the order" % unit_name)
	# Re-issuing is the same work; the fastest of ten (a 3 ms piece of work is longer than a scheduler slice, so on a
	# crowded machine most samples are preempted) against the reference (Fixture.fastest_ms).
	var timed := Fixture.fastest_ms(func() -> void: f.controls.order_selection("move", {"to": [0.0, -60.0]}), 10)
	var ratio := timed[0] / timed[1]
	print("MEASURE control_scale order_ms=%.2f reference_ms=%.3f ratio=%.1f units=%d" % [timed[0], timed[1], ratio, PER_SIDE])
	assert_true(ratio < ORDER_BUDGET_REFERENCES, "ordering %d units takes %.1f reference workloads (budget %.0f; %.2f ms)"
			% [PER_SIDE, ratio, ORDER_BUDGET_REFERENCES, timed[0]])


func test_input_to_order_latency_with_a_box_around_the_army() -> void:
	var f := await _setup()
	var screen := f.controls.get_viewport_rect()
	# Events are pushed synchronously (push_input runs _gui_input inline), so this times the work the click
	# causes, not how long the test then waits for a frame.
	var from := screen.position + Vector2(4, 4)
	var to := screen.end - Vector2(4, 4)
	var started := Time.get_ticks_usec()
	f.button(from, true)
	for i in range(1, 6):
		f.motion(from.lerp(to, i / 5.0))
	f.button(to, false)
	var box_ms := (Time.get_ticks_usec() - started) / 1000.0
	await tree.process_frame
	assert_eq(f.controls.selection.units.size(), PER_SIDE, "the box takes our whole army and none of theirs")
	var at := f.ground(Vector3(0, 0, -50))
	# The fastest of ten clicks (each re-issues the order; see above on preemption) against the reference: one bare sample on a shared machine
	# read 24 ms where the work is ~4 ms (laptop, load 7.8).
	var timed := Fixture.fastest_ms(func() -> void:
		f.button(at, true, MOUSE_BUTTON_RIGHT)
		f.button(at, false, MOUSE_BUTTON_RIGHT), 10)
	var order_ms: float = timed[0]
	var click_ratio := order_ms / timed[1]
	await tree.process_frame
	var ordered := f.controls.selection.units.filter(func(n: String) -> bool:
		return not f.orders.current(n).is_empty())
	assert_eq(ordered.size(), PER_SIDE, "every selected unit has an order on the same frame as the click")
	print("MEASURE control_scale box_ms=%.2f click_to_order_ms=%.2f reference_ms=%.3f ratio=%.1f units=%d" % [box_ms, order_ms,
			timed[1], click_ratio, PER_SIDE])
	assert_true(click_ratio < ORDER_BUDGET_REFERENCES, "a right click on %d units takes %.1f reference workloads (budget %.0f; %.2f ms)"
			% [PER_SIDE, click_ratio, ORDER_BUDGET_REFERENCES, order_ms])


func test_the_panel_groups_portraits_by_type_instead_of_showing_thirty() -> void:
	var f := await _setup()
	var panel := SelectionPanel.new()
	panel.controls = f.controls
	f.controls.add_child(panel)
	await _frames(2)
	await f.key(KEY_A, false, true)
	await _frames(2)
	var info := panel.summary()
	var portraits: Array = info["portraits"]
	assert_true(portraits.size() <= 6, "%d units show as %d portraits, one per type" % [PER_SIDE, portraits.size()])
	assert_eq(int(info["count"]), PER_SIDE, "the header carries the real count")
	var counted := 0
	for portrait: Dictionary in portraits:
		counted += int(portrait["count"])
		assert_true(String(portrait["key"]).begins_with("type:"), "each portrait stands for a type")
	assert_eq(counted, PER_SIDE, "and the counts add up to the selection")
	# The two armies are in sight of each other and already shooting, so "full strength" is only approximate;
	# what matters is that the number tracks damage.
	var before := float(info["strength"])
	assert_true(before > 0.8, "a fresh army reads as near full strength (%.2f)" % before)
	for i in 5:
		f.tank(f.controls.selection.units[i]).health = 1
	await _frames(2)
	assert_true(float(panel.summary()["strength"]) < before, "damage shows in the one strength number")
	# A small selection still shows every unit.
	f.controls.selection.set_units(f.controls.groups.members(1))
	await _frames(2)
	assert_eq((panel.summary()["portraits"] as Array).size(), f.controls.groups.members(1).size(),
			"a five-unit element still gets a portrait each")
	panel.queue_free()


func test_next_idle_element_walks_the_elements_that_are_doing_nothing() -> void:
	var f := await _setup()
	f.controls.selection.set_units(f.controls.groups.members(1))
	assert_eq(f.controls.order_selection("move", {"to": [0.0, -40.0]}), "", "group 1 is given something to do")
	await _frames(2)
	var first := f.controls.next_idle_element()
	assert_true(first != 1, "F2 skips the element that is busy (went to %d)" % first)
	assert_true(first > 1, "and lands on one that is idle")
	assert_eq(f.controls.selection.units, f.controls.groups.members(first), "selecting it")
	var second := f.controls.next_idle_element()
	assert_true(second != first, "pressing it again moves on (%d then %d)" % [first, second])


func test_the_ui_stays_cheap_with_a_full_army_selected() -> void:
	var f := await _setup()
	var panel := SelectionPanel.new()
	panel.controls = f.controls
	f.controls.add_child(panel)
	await _frames(2)
	await f.key(KEY_A, false, true)
	await _frames(2)
	# Under orders, so the order marks (round 7) have every unit's order to read.
	f.controls.order_selection("attack_move", {"to": [0.0, -40.0]})
	await _frames(2)
	var rounds := 30
	var costs := {}
	var work := {
		"vision_state": func() -> void: f.controls.vision_state(),
		"order_marks": func() -> void: f.controls.order_marks(),
		"awareness": func() -> void: f.controls.awareness.update(0.016),
		"edge_markers": func() -> void: f.markers.markers(),
		"panel_summary": func() -> void: panel.summary(),
		"horizon_zoom": func() -> void:
			RtsCamera.horizon_zoom(f.controls.vision_state()["region"], f.rig.focus, f.rig.yaw, 16.0 / 9.0),
	}
	var keys := work.keys()
	keys.sort()
	var total := 0.0
	# The fastest of the rounds, interleaved with a fixed reference workload timed the same way. A shared machine slows
	# both (#19 on 9c889025, builder0: a 2.33 ms frame where idle builder0 is ~0.65 ms), so the budget is their RATIO;
	# a real regression slows only the control work.
	var reference := INF
	for key: String in keys:
		costs[key] = INF
	for i in rounds:
		var started := Time.get_ticks_usec()
		Fixture.reference_work()
		reference = minf(reference, (Time.get_ticks_usec() - started) / 1000.0)
		for key: String in keys:
			started = Time.get_ticks_usec()
			(work[key] as Callable).call()
			costs[key] = minf(costs[key], (Time.get_ticks_usec() - started) / 1000.0)
	for key: String in keys:
		total += costs[key]
	# horizon_zoom runs once every RtsCamera.VISION_CAP_EVERY frames, so only its share counts against a frame.
	var per_frame: float = total - float(costs["horizon_zoom"]) * (1.0 - 1.0 / float(RtsCamera.VISION_CAP_EVERY))
	var parts: Array[String] = []
	for key: String in keys:
		parts.append("%s=%.3f" % [key, costs[key]])
	var ratio := per_frame / reference
	print("MEASURE control_scale_frame units=%d selected=%d %s per_frame_ms=%.3f reference_ms=%.3f ratio=%.2f" % [
			PER_SIDE * 2, f.controls.selection.units.size(), " ".join(parts), per_frame, reference, ratio])
	assert_true(ratio < FRAME_BUDGET_REFERENCES, "control costs %.2f reference workloads a frame with %d units (budget %.1f; %.3f ms): %s"
			% [ratio, PER_SIDE * 2, FRAME_BUDGET_REFERENCES, per_frame, " ".join(parts)])
	panel.queue_free()


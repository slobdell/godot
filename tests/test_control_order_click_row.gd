extends TestCase
## Round 44 (orders O0 / O1; CP44.0 and C44.2). His round-43 recording (2026-10-28T08-21-31-locks) held each squad's `to`
## and NOT the point he clicked, so the scatter of his group click could not be traced. Now every order of one click carries
## `click` (the ground point under his cursor, before any per-squad layout) and, for an order to two or more squads, `group`
## (how many), both on the recorder's `order` row (additive: an old row has neither, `to` keeps its meaning). `group` also
## reaches the element's task (R43.34: the task is built key by key, so manoeuvre's grouped() never saw it) and survives the
## controls' re-lays, which drop `halt_at` / `halt_shape` / `lay`.

const Fixture := preload("res://tests/support/control_fixture.gd")
const ALPHA := ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"]
const BRAVO := ["Green_Bravo_1", "Green_Bravo_2"]
const CLICK := [0.0, 0.0]
const SECOND := [0.0, -40.0]
const THIRD := [0.0, -80.0]
const DIR := "user://test_control_order_click_row"

var _recorder: MatchRecorder


func teardown() -> void:
	SelectionSquads.reset_g1()
	if _recorder != null and _recorder.path != "":
		DirAccess.remove_absolute(_recorder.path)
	_recorder = null
	super.teardown()


func _two_squads() -> Fixture:
	var f := Fixture.new(self)
	await f.build()
	f.controls.elements = Elements.install(f.game_match, f.orders)
	f.place("Rust_Alpha_1", Vector3(0.0, 0.0, -150.0))  # out of the fight
	f.controls.groups.save(1, ALPHA.duplicate())
	f.controls.groups.save(2, BRAVO.duplicate())
	_recorder = MatchRecorder.start(f.game_match, f.orders, f.controls, f.controls.elements, DIR, "click")
	await wait_physics_frames(1)
	return f


func _rows() -> Array:
	_recorder._exit_tree()
	var rows: Array = []
	for line in FileAccess.get_file_as_string(_recorder.path).split("\n"):
		if line.strip_edges() != "":
			rows.append(JSON.parse_string(line))
	return rows.filter(func(r: Dictionary) -> bool: return r["t"] == "order")


func _task_of(f: Fixture, unit_name: String) -> Dictionary:
	var element: Element = f.controls.elements.of(unit_name)
	assert_true(element != null, "%s has an element" % unit_name)
	return element.task if element != null else {}


func test_a_group_click_stamps_click_and_group_on_every_squads_row_and_task() -> void:
	var f := await _two_squads()
	f.controls.selection.set_units(ALPHA + BRAVO)
	assert_eq(f.controls.order_selection("move", {"to": CLICK}), "", "the group click is taken")
	for unit_name: String in ALPHA + BRAVO:
		var task := _task_of(f, unit_name)
		assert_eq(int(task.get("group", 0)), 2, "%s's task carries group = 2" % unit_name)
		assert_eq(ElementTask.validate(task), "", "%s's task validates with the key" % unit_name)
	var rows := _rows()
	assert_eq(rows.size(), 2, "one order row per squad")
	var tos := {}
	for row: Dictionary in rows:
		assert_eq(row.get("click"), CLICK, "the row carries his click")
		assert_eq(int(row.get("group", 0)), 2, "the row carries the squads of the click")
		assert_true(row.has("to") and row["to"] is Array, "the row keeps that squad's `to`")
		tos[str(row["to"])] = true
		for key in ["tick", "verb", "units", "source", "frame", "paused"]:
			assert_true(row.has(key), "the row keeps %s" % key)
	# The two squads were laid their own places, so `to` alone could never say where he clicked.
	assert_eq(tos.size(), 2, "the squads' `to`s differ (the click is not recoverable from them)")


func test_a_single_squads_click_has_the_click_and_no_group() -> void:
	var f := await _two_squads()
	f.controls.selection.set_units(ALPHA)
	assert_eq(f.controls.order_selection("move", {"to": CLICK}), "", "the click is taken")
	assert_true(not _task_of(f, ALPHA[0]).has("group"), "his one-squad order is not grouped (C44.3: manoeuvre's)")
	var rows := _rows()
	assert_eq(rows.size(), 1, "one row")
	assert_eq(rows[0].get("click"), CLICK, "his click")
	assert_true(not rows[0].has("group"), "no group on a one-squad order")


func test_group_survives_the_re_lays_of_a_route() -> void:
	var f := await _two_squads()
	f.controls.selection.set_units(ALPHA + BRAVO)
	assert_eq(f.controls.order_selection("move", {"to": CLICK}), "", "the first click is taken")
	# The shift-click queues a leg on every squad and re-lays the first click as a waypoint passed through
	# (_relay_previous_waypoint: retarget / relay_queued, which drop halt_at / halt_shape / lay).
	f.controls.selection.set_units(ALPHA + BRAVO)
	assert_eq(f.controls.order_selection("move", {"to": SECOND, "queue": true}), "", "the shift-click is taken")
	f.controls.selection.set_units(ALPHA + BRAVO)
	assert_eq(f.controls.order_selection("move", {"to": THIRD, "queue": true}), "", "the second shift-click is taken")
	for unit_name: String in ALPHA + BRAVO:
		var element: Element = f.controls.elements.of(unit_name)
		assert_true(element != null, "%s has an element" % unit_name)
		if element == null:
			continue
		assert_eq(int(element.task.get("group", 0)), 2, "%s: the running leg keeps group after the re-lay" % unit_name)
		assert_eq(element.queued_tasks.size(), 2, "%s: two legs queued" % unit_name)
		for i in element.queued_tasks.size():
			var leg: Dictionary = element.queued_tasks[i]
			assert_eq(int(leg.get("group", 0)), 2, "%s: queued leg %d keeps group" % [unit_name, i])
			assert_eq(ElementTask.validate(leg), "", "%s: queued leg %d validates" % [unit_name, i])
	var rows := _rows()
	assert_eq(rows.size(), 6, "three clicks x two squads")
	var clicks := {}
	for row: Dictionary in rows:
		clicks[str(row.get("click"))] = true
		assert_eq(int(row.get("group", 0)), 2, "every row of a two-squad click says group 2")
	assert_eq(clicks.size(), 3, "the three clicks he gave, as he gave them")


func test_an_old_style_command_writes_a_row_without_the_new_keys() -> void:
	var f := await _two_squads()
	_recorder._on_command({"verb": "move", "units": ["Green_Alpha_1"], "source": "player", "to": [1.0, 2.0]}, "")
	var rows := _rows()
	assert_eq(rows.size(), 1, "one row")
	assert_true(not rows[0].has("click") and not rows[0].has("group"), "no key invented for a command without them")
	assert_eq(rows[0]["to"], [1.0, 2.0], "`to` as before")
	# And a direct (no-element) order carrying the keys is not refused by the command validator.
	assert_eq(UnitCommand.validate({"verb": "move", "units": ["Green_Alpha_1"], "to": [1.0, 2.0], "click": [1.0, 2.0], "group": 2}), "",
			"click and group are command keys")
	assert_true(f != null, "fixture built")

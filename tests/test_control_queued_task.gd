extends TestCase
## Round 28 (brains B5), the lead's playtest (2026-10-13), through his input path (lesson 291):
##
##   *"When I start the game paused where I can plan initial movements in advance, I expect to be able to shift + screen
##   click on top of an existing waypoint such that my units will go to the first set of waypoints first … then set up
##   the screen from the angle defined by the preceding waypoint. As it stands if I shift + click for screen then it
##   just sets up the screen in a straight line from where the units currently are."*
##
## A shifted screen on a squad still driving its waypoints is QUEUED behind them (Element.enqueue), and its automatic
## facing is the way in from the last waypoint (point − waypoint). Both orders are given before the clock runs, as in
## his paused planning phase. Unshifted, a screen applies now as before.

const Fixture := preload("res://tests/support/control_fixture.gd")
const ALPHA := ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"]
## His waypoint, west of the squad (which starts round (-10, 40)), and the screen point east of it.
const WAYPOINT := Vector3(-35.0, 0.0, 10.0)
const POINT := Vector3(25.0, 0.0, 0.0)
const HEADING_DEG := 10.0


func _alpha() -> Fixture:
	var f := Fixture.new(self)
	await f.build()
	f.controls.elements = Elements.install(f.game_match, f.orders)
	# The fixture's enemy tank stands between his waypoint and his screen; out of the way, so no fight (unseeded fire)
	# moves the squad about.
	f.place("Rust_Alpha_1", Vector3(0.0, 0.0, -150.0))
	await f.select(ALPHA)
	f.controls.groups.save(1, ALPHA.duplicate())
	f.controls.selection.units.assign(ALPHA)
	return f


func _centre(f: Fixture) -> Vector3:
	var sum := Vector3.ZERO
	for unit_name: String in ALPHA:
		sum += f.tank(unit_name).global_position
	return Vector3(sum.x, 0.0, sum.z) / ALPHA.size()


static func _deg(a: Vector3, b: Vector3) -> float:
	return rad_to_deg(Vector3(a.x, 0.0, a.z).normalized().angle_to(Vector3(b.x, 0.0, b.z).normalized()))


## Step until the element's task is a screen (or `limit` frames), recording how near the squad's centre came to the
## waypoint before it. Returns [frames, nearest metres] (frames -1 = never).
func _until_screen(f: Fixture, element: Element, limit: int) -> Array:
	var nearest := INF
	var frames := 0
	while frames <= limit:
		if String(element.task.get("verb", "")) == "screen":
			return [frames, nearest]
		nearest = minf(nearest, _centre(f).distance_to(WAYPOINT))
		await wait_physics_frames(10)
		frames += 10
	return [-1, nearest]


func _screen_heading_check(f: Fixture, element: Element, label: String) -> void:
	# The line's heading, once the squad is on its line (Drills.on_screen_line: the centre within SCREEN_REACHED_M of the
	# point); on the way there the element heads for it from wherever it is.
	var waited := 0
	while waited < 60 * 60 and _centre(f).distance_to(POINT) > Drills.SCREEN_REACHED_M:
		await wait_physics_frames(10)
		waited += 10
	await wait_physics_frames(30)
	var wanted := POINT - WAYPOINT
	var from_start := POINT - Vector3(-10.0, 0.0, 40.0)
	assert_true(_deg(wanted, from_start) > 30.0, "setup %s: the two ways in differ (%.0f deg)" % [label, _deg(wanted, from_start)])
	var off := _deg(element.heading, wanted)
	print("MEASURE queued_screen %s heading_off_deg %.1f" % [label, off])
	assert_true(off <= HEADING_DEG, "%s: the screen faces point - waypoint within %d deg (%.1f off; heading %s)"
			% [label, int(HEADING_DEG), off, element.heading])


## His case: a right-click waypoint (the squad's move task), then shift + E + click: the screen waits behind the move.
func test_shift_screen_after_a_waypoint_drives_it_then_screens_from_it() -> void:
	var f := await _alpha()
	await f.right_click(f.ground(WAYPOINT))
	var element := f.controls.elements.of(ALPHA[0])
	assert_true(element != null and String(element.task.get("verb", "")) == "move", "setup: the waypoint is the squad's move")
	await f.key(KEY_E, true)
	await f.click(f.ground(POINT), true)
	assert_eq(String(element.task.get("verb", "")), "move", "the shifted screen did not replace the waypoint")
	assert_eq(element.queued_tasks.size(), 1, "it waits behind it (%s)" % [element.queued_tasks])
	var queued: Dictionary = element.queued_tasks[0] if not element.queued_tasks.is_empty() else {}
	assert_eq(String(queued.get("verb", "")), "screen", "the queued task is the screen")
	var took: Array = await _until_screen(f, element, 60 * 60)
	print("MEASURE queued_screen waypoint_first frames %d nearest_m %.1f" % [took[0], took[1]])
	assert_true(int(took[0]) >= 0, "the screen starts once the waypoint is reached")
	assert_true(float(took[1]) <= 12.0, "the squad drove the waypoint first (centre came within %.1f m)" % float(took[1]))
	await _screen_heading_check(f, element, "move_then_screen")


## His crews' own shift-queued waypoints (a direct route), then shift + E + click: the screen waits for the route.
func test_shift_screen_after_shift_waypoints_waits_for_the_route() -> void:
	var f := await _alpha()
	await f.right_click(f.ground(Vector3(-20.0, 0.0, 25.0)), true)
	await f.right_click(f.ground(WAYPOINT), true)
	await f.key(KEY_E, true)
	await f.click(f.ground(POINT), true)
	var element := f.controls.elements.of(ALPHA[0])
	assert_true(element != null, "the squad has a leader to carry the queued screen")
	if element == null:
		return
	assert_true(element.task.is_empty() and element.queued_tasks.size() == 1, "no task yet; the screen is queued (%s / %s)"
			% [element.task, element.queued_tasks])
	var took: Array = await _until_screen(f, element, 60 * 60)
	print("MEASURE queued_screen route_first frames %d nearest_m %.1f" % [took[0], took[1]])
	assert_true(int(took[0]) >= 0, "the screen starts once the route is driven")
	assert_true(float(took[1]) <= 12.0, "the squad drove its last waypoint first (centre came within %.1f m)" % float(took[1]))
	await _screen_heading_check(f, element, "route_then_screen")


## A drawn facing still wins over the waypoint's.
func test_a_drawn_facing_on_a_queued_screen_wins() -> void:
	var f := await _alpha()
	await f.right_click(f.ground(WAYPOINT))
	f.controls.order_selection("screen", {"to": [POINT.x, POINT.z], "facing": [0.0, -1.0], "queue": true})
	var element := f.controls.elements.of(ALPHA[0])
	var queued: Dictionary = element.queued_tasks[0] if element != null and not element.queued_tasks.is_empty() else {}
	assert_eq(queued.get("facing"), [0.0, -1.0], "his drawn facing is kept (%s)" % [queued])


## Unshifted: today's behaviour (the screen replaces the move at once, laid from where the squad stands).
func test_an_unshifted_screen_applies_now() -> void:
	var f := await _alpha()
	await f.right_click(f.ground(WAYPOINT))
	await f.key(KEY_E)
	await f.click(f.ground(POINT))
	var element := f.controls.elements.of(ALPHA[0])
	assert_true(element != null and String(element.task.get("verb", "")) == "screen", "the screen applies now")
	assert_true(element != null and element.queued_tasks.is_empty(), "nothing queued")
	assert_true(element != null and not element.task.has("facing"), "no automatic facing is added to an unshifted task")


## He plays with several squads selected: each squad queues the screen behind its own waypoint.
func test_several_squads_queue_the_screen_each_behind_its_own_waypoint() -> void:
	var f := Fixture.new(self)
	await f.build()
	f.controls.elements = Elements.install(f.game_match, f.orders)
	f.place("Rust_Alpha_1", Vector3(0.0, 0.0, -150.0))
	var bravo := ["Green_Bravo_1", "Green_Bravo_2"]
	f.controls.groups.save(1, ALPHA.duplicate())
	f.controls.groups.save(2, bravo.duplicate())
	await f.select(ALPHA + bravo)
	assert_true(f.controls.several_squads(), "setup: two squads selected")
	await f.right_click(f.ground(WAYPOINT))
	await f.key(KEY_E, true)
	await f.click(f.ground(POINT), true)
	for first: String in [ALPHA[0], bravo[0]]:
		var element := f.controls.elements.of(first)
		assert_true(element != null, "%s's squad has a leader" % first)
		if element == null:
			continue
		assert_eq(String(element.task.get("verb", "")), "move", "%s's squad still drives its waypoint" % first)
		assert_eq(element.queued_tasks.size(), 1, "and has the screen queued behind it (%s)" % [element.queued_tasks])


## He plans by looking: the queued screen is drawn at its point, linked from the waypoint before it.
func test_the_queued_screen_is_marked_from_its_waypoint() -> void:
	var f := await _alpha()
	await f.right_click(f.ground(WAYPOINT))
	await f.key(KEY_E, true)
	await f.click(f.ground(POINT), true)
	var marks := f.controls.queued_task_marks()
	assert_eq(marks.size(), 1, "one mark for the queued screen (%s)" % [marks])
	if marks.is_empty():
		return
	assert_eq(String(marks[0]["verb"]), "screen", "a screen mark")
	assert_true((marks[0]["point"] as Vector3).distance_to(POINT) < 1.0, "at the point he clicked")
	assert_true(marks[0].get("from") is Vector3 and (marks[0]["from"] as Vector3).distance_to(WAYPOINT) < 1.0,
			"linked from his waypoint (%s)" % [marks[0].get("from")])
	assert_true(_deg(marks[0].get("facing", Vector3.ZERO), POINT - WAYPOINT) < 1.0, "showing the way it will face")

extends TestCase
## Round 26, orders O1. The lead, 2026-10-10:
##
##   *"I was trying to get tanks oriented in a screen at a particular angle, and therefore I was trying to click on one
##   target then shift+screen at another point such that the first point would determine the direction of the screen,
##   but this didn't work. it short-circuit directly to screen and so the vehicles moved into a line abreast angle I
##   didn't want. This is probably the case for all our specialized cases (attack, ambush, screen, etc)."*
##
## An armed order (A attack-move on the ground, M move, E screen, R support by fire, B ambush) used to fire on the left
## PRESS, so it could carry no direction. It now takes the right-drag's gesture: PRESS at the spot, DRAG toward the
## way they should face, RELEASE. A click with no drag past FACING_DRAG_PX is the order it always was, with no
## `facing` key at all (C26.3: absent = automatic). Shift still queues, and a shift-drag queues a faced order.

const Fixture := preload("res://tests/support/control_fixture.gd")

## Empty ground on the fixture's west side, well clear of the row of vehicles at z = 40.
const LANE_X := -30.0
const ALPHA := ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"]
const TASKS := {KEY_E: "screen", KEY_R: "support_by_fire", KEY_B: "ambush"}


func _setup(with_elements := false) -> Fixture:
	var f := Fixture.new(self)
	await f.build(false)
	if with_elements:
		f.controls.elements = Elements.install(f.game_match, f.orders)
		var names: Array[String] = []
		names.assign(ALPHA)
		f.controls.groups.save(1, names)
	return f


static func _facing(order: Dictionary) -> Vector2:
	var way: Array = order.get("facing", [])
	return Vector2(float(way[0]), float(way[1])) if way.size() == 2 else Vector2.ZERO


## A left press, a drag with the LEFT button held, a release: the armed-order gesture.
func _armed_drag(f: Fixture, from: Vector2, to: Vector2, shift := false) -> void:
	f.button(from, true, MOUSE_BUTTON_LEFT, shift)
	for i in range(1, 6):
		f.motion(from.lerp(to, i / 5.0), shift)
	f.button(to, false, MOUSE_BUTTON_LEFT, shift)
	await tree.process_frame


## Every command the controls announce (orders and refusals), in order.
func _listen(f: Fixture) -> Array:
	var heard: Array = []
	f.controls.command_issued.connect(func(command: Dictionary, error: String) -> void:
		heard.append({"command": command.duplicate(true), "error": error}))
	return heard


func _task(f: Fixture) -> Dictionary:
	var element := f.controls.elements.of(String(ALPHA[0]))
	return element.task if element != null else {}


# ---- a click is exactly today's order ------------------------------------------------------------------------

## Byte-identical: the command a plain armed click announces is the one `armed_click_order` (main's only path)
## builds for the same point, and it never carries a facing.
func test_an_armed_move_click_is_the_order_it_always_was() -> void:
	await _click_is_mains(KEY_M, "move")


func test_an_armed_attack_move_click_is_the_order_it_always_was() -> void:
	await _click_is_mains(KEY_A, "attack_move")


func _click_is_mains(keycode: Key, mode: String) -> void:
	var armed := [keycode, mode]
	if true:
		var f := await _setup()
		var heard := _listen(f)
		await f.click(f.screen("Green_Alpha_1"))
		var at := f.ground(Vector3(LANE_X, 0.0, 10.0))
		await f.key(armed[0])
		assert_eq(f.controls.mode, armed[1], "setup: %s armed" % armed[1])
		await f.click(at)
		assert_eq(heard.size(), 1, "%s: one click, one order" % armed[1])
		var clicked: Dictionary = heard[0]["command"]
		assert_true(not clicked.has("facing"), "%s: a click carries no facing key (%s)" % [armed[1], clicked])
		assert_eq(f.controls.mode, "", "%s: the click spends the armed mode" % armed[1])
		f.controls.arm(armed[1])
		f.controls.armed_click_order(at, false)
		assert_eq(JSON.stringify(heard[1]["command"]), JSON.stringify(clicked),
				"%s: the click's command is main's for the same point" % armed[1])
		assert_true(not f.orders.current("Green_Alpha_1").has("facing"), "%s: and the unit's order has none" % armed[1])


func test_an_armed_screen_click_gives_the_task_with_no_facing() -> void:
	await _task_click(KEY_E)


func test_an_armed_support_by_fire_click_gives_the_task_with_no_facing() -> void:
	await _task_click(KEY_R)


func test_an_armed_ambush_click_gives_the_task_with_no_facing() -> void:
	await _task_click(KEY_B)


func _task_click(keycode: Key) -> void:
	if true:
		var f := await _setup(true)
		await f.select(ALPHA)
		await f.key(keycode)
		assert_eq(f.controls.mode, TASKS[keycode], "setup: %s armed" % TASKS[keycode])
		await f.click(f.ground(Vector3(LANE_X, 0.0, 10.0)))
		var task := _task(f)
		assert_eq(String(task.get("verb", "")), TASKS[keycode], "the squad took the %s (%s)" % [TASKS[keycode], task])
		assert_true(not task.has("facing"), "%s: a click leaves facing ABSENT (C26.3: automatic)" % TASKS[keycode])


## A twitch of the hand is a click, not a gesture: the same threshold as the right-drag.
func test_a_twitch_below_the_threshold_is_still_a_click() -> void:
	var f := await _setup()
	await f.click(f.screen("Green_Alpha_1"))
	await f.key(KEY_M)
	var at := f.ground(Vector3(LANE_X, 0.0, 10.0))
	await _armed_drag(f, at, at + Vector2(0.0, -RtsControls.FACING_DRAG_PX + 4.0))
	var order := f.orders.current("Green_Alpha_1")
	assert_eq(String(order.get("verb", "")), "move", "the twitch still moves")
	assert_true(not order.has("facing"), "and carries no facing (%s)" % [order])


# ---- a drag carries the facing ---------------------------------------------------------------------------------

func test_a_drag_faces_a_direct_move_toward_the_release() -> void:
	await _direct_drag(KEY_M, "move")


func test_a_drag_faces_a_direct_attack_move_toward_the_release() -> void:
	await _direct_drag(KEY_A, "attack_move")


func _direct_drag(keycode: Key, mode: String) -> void:
	var armed := [keycode, mode]
	if true:
		var f := await _setup()
		await f.click(f.screen("Green_Alpha_1"))
		await f.key(armed[0])
		var spot := Vector3(LANE_X, 0.0, 10.0)
		await _armed_drag(f, f.ground(spot), f.ground(spot + Vector3(20.0, 0.0, 0.0)))  # drag east
		var order := f.orders.current("Green_Alpha_1")
		assert_eq(String(order.get("verb", "")), armed[1], "the drag gives the %s on RELEASE" % armed[1])
		var to: Array = order.get("to", [])
		assert_true(to.size() == 2 and Vector2(to[0], to[1]).distance_to(Vector2(spot.x, spot.z)) < 2.0,
				"%s: the PRESS is the spot, not the release (%s)" % [armed[1], to])
		assert_true(_facing(order).distance_to(Vector2(1, 0)) < 0.08,
				"%s: facing east, toward the release, got %s" % [armed[1], _facing(order)])
		assert_true(absf(_facing(order).length() - 1.0) < 0.001, "%s: normalised" % armed[1])
		assert_eq(f.controls.mode, "", "%s: the release spends the armed mode" % armed[1])


## His case: the squad's task carries the heading he drew, for every task key.
func test_a_drag_faces_the_screen() -> void:
	await _task_drag(KEY_E)


func test_a_drag_faces_the_support_by_fire() -> void:
	await _task_drag(KEY_R)


func test_a_drag_faces_the_ambush() -> void:
	await _task_drag(KEY_B)


func _task_drag(keycode: Key) -> void:
	if true:
		var f := await _setup(true)
		await f.select(ALPHA)
		await f.key(keycode)
		var spot := Vector3(LANE_X, 0.0, 0.0)
		await _armed_drag(f, f.ground(spot), f.ground(spot + Vector3(-14.0, 0.0, -14.0)))  # drag north-west
		var task := _task(f)
		assert_eq(String(task.get("verb", "")), TASKS[keycode], "the squad took the %s (%s)" % [TASKS[keycode], task])
		var to: Array = task.get("to", [])
		assert_true(to.size() == 2 and Vector2(to[0], to[1]).distance_to(Vector2(spot.x, spot.z)) < 2.0,
				"%s: the task's place is the press (%s)" % [TASKS[keycode], to])
		assert_true(_facing(task).distance_to(Vector2(-1, -1).normalized()) < 0.08,
				"%s: task facing is north-west, got %s" % [TASKS[keycode], _facing(task)])


## Attack-move given to a whole squad is a move task with drills; its facing rides the task the same way.
func test_a_squad_attack_move_drag_faces_the_task() -> void:
	var f := await _setup(true)
	await f.select(ALPHA)
	await f.key(KEY_A)
	var spot := Vector3(LANE_X, 0.0, 0.0)
	await _armed_drag(f, f.ground(spot), f.ground(spot + Vector3(0.0, 0.0, 20.0)))  # drag south
	var task := _task(f)
	assert_eq(String(task.get("verb", "")), "move", "a squad's attack-move is a move task (%s)" % task)
	assert_true(bool(task.get("drills", true)), "with drills")
	assert_true(_facing(task).distance_to(Vector2(0, 1)) < 0.08, "facing south, got %s" % _facing(task))


## No drawing an arrow or a box while the button is down: the press is the order's, not the selection's.
func test_an_armed_drag_never_boxes_or_reselects() -> void:
	var f := await _setup()
	await f.click(f.screen("Green_Alpha_1"))
	await f.key(KEY_M)
	var before := f.controls.selection.units.duplicate()
	await _armed_drag(f, f.screen("Green_Alpha_2") + Vector2(-40, -40), f.screen("Green_Bravo_2") + Vector2(40, 40))
	assert_eq(f.controls.selection.units, before, "an armed drag across the row leaves the selection alone")
	assert_true(not f.controls._boxing, "and opens no box")
	assert_true(f.orders.current("Green_Alpha_1").has("facing"), "it orders the selected unit, faced")


## While the button is down, the controls know the gesture (the draw reads this): spot, and whether it is a facing yet.
func test_the_gesture_is_visible_while_the_button_is_down() -> void:
	var f := await _setup()
	await f.click(f.screen("Green_Alpha_1"))
	await f.key(KEY_E)  # a lone unit cannot screen: arm() refuses at the key
	assert_eq(f.controls.mode, "", "setup: a task key on a unit in no squad is refused at the key")
	await f.key(KEY_M)
	var spot := f.ground(Vector3(LANE_X, 0.0, 10.0))
	f.button(spot, true)
	assert_true(f.controls.armed_gesture().has("spot"), "the press is held as the order's spot")
	assert_true(not bool(f.controls.armed_gesture().get("facing", false)), "no arrow promised before the threshold")
	f.motion(spot + Vector2(60.0, 0.0))
	await tree.process_frame
	assert_true(bool(f.controls.armed_gesture().get("facing", false)), "past the threshold the arrow is drawn")
	assert_true(f.orders.current("Green_Alpha_1").is_empty(), "and nothing is ordered until the release")
	f.button(spot + Vector2(60.0, 0.0), false)
	await tree.process_frame
	assert_true(f.controls.armed_gesture().is_empty(), "the release ends the gesture")
	assert_true(f.orders.current("Green_Alpha_1").has("facing"), "and gives the faced order")


# ---- shift, cancel, and the horizon -----------------------------------------------------------------------------

func test_shift_drag_queues_a_faced_order_and_stays_armed() -> void:
	var f := await _setup()
	await f.click(f.screen("Green_Alpha_1"))
	await f.key(KEY_M)
	await _armed_drag(f, f.ground(Vector3(LANE_X, 0.0, 10.0)), f.ground(Vector3(LANE_X, 0.0, -10.0)), true)
	assert_eq(f.controls.mode, "move", "shift keeps the order armed for the next point")
	await _armed_drag(f, f.ground(Vector3(LANE_X, 0.0, -20.0)), f.ground(Vector3(LANE_X + 20.0, 0.0, -20.0)), true)
	assert_true(_facing(f.orders.current("Green_Alpha_1")).distance_to(Vector2(0, -1)) < 0.08,
			"the first leg faces north")
	assert_eq(f.orders.queue("Green_Alpha_1").size(), 1, "the second is queued behind it")
	var queued: Dictionary = f.orders.queue("Green_Alpha_1")[0]
	assert_true(_facing(queued).distance_to(Vector2(1, 0)) < 0.08, "the queued leg keeps its facing east, got %s" % [
			_facing(queued)])


func test_escape_during_the_drag_cancels_it() -> void:
	var f := await _setup()
	await f.click(f.screen("Green_Alpha_1"))
	await f.key(KEY_M)
	var spot := f.ground(Vector3(LANE_X, 0.0, 10.0))
	f.button(spot, true)
	f.motion(spot + Vector2(60.0, 0.0))
	await f.key(KEY_ESCAPE)
	f.button(spot + Vector2(60.0, 0.0), false)
	await tree.process_frame
	assert_true(f.orders.current("Green_Alpha_1").is_empty(), "Escape mid-drag: the release orders nothing")
	assert_eq(f.controls.mode, "", "and the order is disarmed")
	assert_eq(f.controls.selection.units, ["Green_Alpha_1"], "and the selection is kept (Escape spent on the drag)")


func test_a_right_press_during_the_drag_cancels_it() -> void:
	var f := await _setup()
	await f.click(f.screen("Green_Alpha_1"))
	await f.key(KEY_M)
	var spot := f.ground(Vector3(LANE_X, 0.0, 10.0))
	f.button(spot, true)
	f.motion(spot + Vector2(60.0, 0.0))
	f.button(spot + Vector2(60.0, 0.0), true, MOUSE_BUTTON_RIGHT)
	f.button(spot + Vector2(60.0, 0.0), false, MOUSE_BUTTON_RIGHT)
	f.button(spot + Vector2(60.0, 0.0), false)
	await tree.process_frame
	assert_true(f.orders.current("Green_Alpha_1").is_empty(), "a right press mid-drag cancels: no order at all")
	assert_eq(f.controls.mode, "", "and disarms")


func test_a_drag_released_above_the_horizon_refuses_with_a_notice() -> void:
	var f := await _setup()
	var heard := _listen(f)
	await f.click(f.screen("Green_Alpha_1"))
	await f.key(KEY_M)
	var spot := f.ground(Vector3(LANE_X, 0.0, 10.0))
	await _armed_drag(f, spot, Vector2(spot.x, -4000.0))  # far above the top of the frame: the ray misses the ground
	assert_true(f.controls.ground_under(Vector2(spot.x, -4000.0)) == null, "setup: the release has no ground under it")
	assert_true(f.orders.current("Green_Alpha_1").is_empty(), "no order: the heading he drew cannot be read")
	assert_true(not heard.is_empty() and String(heard[heard.size() - 1]["error"]) != "",
			"and he is told why (%s)" % [heard])
	assert_eq(f.controls.mode, "move", "the order stays armed so he can draw it again")


## A press on an enemy with attack-move armed is still an attack on that enemy, decided on the press: no facing.
func test_attack_move_on_an_enemy_attacks_it_drag_or_not() -> void:
	var f := await _setup()
	await f.click(f.screen("Green_Alpha_1"))
	await f.key(KEY_A)
	await _armed_drag(f, f.screen("Rust_Alpha_1"), f.screen("Rust_Alpha_1") + Vector2(80.0, 0.0))
	var order := f.orders.current("Green_Alpha_1")
	assert_eq(String(order.get("verb", "")), "attack", "pressing on an enemy attacks it (%s)" % [order])
	assert_true(not order.has("facing"), "an attack takes its heading from its target")


# ---- O3: he can see the gesture exists, and check what he gave ---------------------------------------------------

## The armed hint under the pointer names the drag for every order that takes one, and not for follow.
func test_the_armed_hint_names_the_drag() -> void:
	for armed: String in RtsControls.FACED_MODES:
		assert_true(String(RtsControls.MODE_HINTS[armed]).to_lower().contains("drag to face"),
				"%s's hint names the drag: %s" % [armed, RtsControls.MODE_HINTS[armed]])
	assert_true(not String(RtsControls.MODE_HINTS["follow"]).contains("drag"), "follow takes no facing")
	for id: String in ["screen", "support_by_fire", "ambush", "attack_move"]:
		assert_true(String(TaskPalette.row(id)["line"]).to_lower().contains("drag to face"),
				"the %s button's tooltip names the drag: %s" % [id, TaskPalette.row(id)["line"]])
	assert_true(" ".join(ControlHints.HINTS["tasks"]).to_lower().contains("drag to face"),
			"the first-time hint for the task keys names the drag: %s" % [ControlHints.HINTS["tasks"]])
	assert_true(" ".join(ControlHints.HINTS["attack_move"]).to_lower().contains("drag to face"),
			"and the attack-move hint: %s" % [ControlHints.HINTS["attack_move"]])


## After the fact: the squad's pin carries the heading he drew (the move's arrow), and the HUD line says it.
func test_the_order_marker_shows_the_drawn_facing() -> void:
	var f := await _setup(true)
	var heard := _listen(f)
	await f.select(ALPHA)
	await f.key(KEY_E)
	var spot := Vector3(LANE_X, 0.0, 0.0)
	await _armed_drag(f, f.ground(spot), f.ground(spot + Vector3(20.0, 0.0, 0.0)))  # drag east
	var marks := f.controls.order_marks()
	assert_eq(marks.size(), 1, "one pin for the squad (%s)" % [marks])
	assert_eq(String(marks[0]["verb"]), "screen", "a screen pin")
	assert_true(marks[0].has("facing") and (marks[0]["facing"] as Vector3).distance_to(Vector3(1, 0, 0)) < 0.08,
			"the pin carries the east facing he drew (%s)" % [marks[0]])
	var said := f.controls.describe(heard[heard.size() - 1]["command"])
	assert_true(said.contains("facing E"), "the HUD line says the heading in his compass: %s" % said)


func test_a_clicked_order_marker_invents_no_facing() -> void:
	var f := await _setup(true)
	await f.select(ALPHA)
	await f.key(KEY_E)
	await f.click(f.ground(Vector3(LANE_X, 0.0, 0.0)))
	var marks := f.controls.order_marks()
	assert_eq(marks.size(), 1, "one pin for the squad")
	assert_true(not marks[0].has("facing"), "a click's pin draws no heading the player never gave (%s)" % [marks[0]])


func test_a_direct_attack_move_marker_shows_the_drawn_facing() -> void:
	var f := await _setup()
	await f.click(f.screen("Green_Alpha_1"))
	await f.key(KEY_A)
	var spot := Vector3(LANE_X, 0.0, 10.0)
	await _armed_drag(f, f.ground(spot), f.ground(spot + Vector3(0.0, 0.0, -20.0)))  # drag north
	var marks := f.controls.order_marks()
	assert_true(marks.size() == 1 and marks[0].has("facing")
			and (marks[0]["facing"] as Vector3).distance_to(Vector3(0, 0, -1)) < 0.08,
			"the attack-move pin carries the north facing (%s)" % [marks])


# ---- O4 (stretch): a queued order shows the facing it was given ---------------------------------------------------

func test_a_queued_faced_order_shows_its_facing_on_the_queue() -> void:
	var f := await _setup()
	await f.select(["Green_Alpha_1", "Green_Alpha_2"])
	await f.key(KEY_A)
	await _armed_drag(f, f.ground(Vector3(LANE_X, 0.0, 10.0)), f.ground(Vector3(LANE_X, 0.0, -10.0)), true)
	await _armed_drag(f, f.ground(Vector3(LANE_X, 0.0, -20.0)), f.ground(Vector3(LANE_X + 20.0, 0.0, -20.0)), true)
	await f.click(f.ground(Vector3(LANE_X, 0.0, -40.0)), true)  # a third, clicked: queued with no facing
	var queued := f.controls.queued_facings()
	assert_eq(queued.size(), 1, "one mark for the queued faced order, one per order not per crew (%s)" % [queued])
	assert_true((queued[0]["facing"] as Vector3).distance_to(Vector3(1, 0, 0)) < 0.08,
			"it shows the east facing he drew (%s)" % [queued])
	assert_true(Vector2((queued[0]["point"] as Vector3).x, (queued[0]["point"] as Vector3).z)
			.distance_to(Vector2(LANE_X, -20.0)) < 8.0, "at the queued spot (%s)" % [queued])


## The longer hints fit a phone: near the right edge the text flips to the pointer's left and stays on screen.
func test_the_armed_hint_stays_on_a_phone_screen() -> void:
	var phone := Vector2(1200, 540)
	var at := RtsControls.mode_hint_at(Vector2(1150, 430), 340.0, phone)
	assert_true(at.x >= 0.0 and at.x + 340.0 <= phone.x, "the hint fits across (%s)" % at)
	assert_true(at.x + 340.0 <= 1150.0, "and sits left of the pointer near the right edge (%s)" % at)
	assert_eq(RtsControls.mode_hint_at(Vector2(100, 200), 340.0, phone), Vector2(118, 192),
			"in the open it is where it always was")

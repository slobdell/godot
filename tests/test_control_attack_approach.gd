extends TestCase
## Round 27, orders O1 (C27.3). The lead, round 26: *"I was trying to get tanks oriented ... This is probably the case
## for all our specialized cases (attack, ambush, screen, etc)."* Round 26 gave every armed order to a place a drawn
## facing; an attack (a press on an enemy) took none. Now: press on the enemy, drag out to the side the squad should
## come from, release. The attack task carries `approach` = the flat unit direction from the release toward the enemy.
## A click is today's attack, byte for byte. Both presses on an enemy take it: the right button, and the left with
## attack-move armed.

const Fixture := preload("res://tests/support/control_fixture.gd")

const ALPHA := ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"]
const ENEMY := "Rust_Alpha_1"
## The enemy stands at (0, 0, 20): a release on the ground due west of it draws an approach from the west, (1, 0).
const WEST := Vector3(-30.0, 0.0, 20.0)


func _setup(squad := true) -> Fixture:
	var f := Fixture.new(self)
	await f.build(false)
	f.controls.elements = Elements.install(f.game_match, f.orders)
	if squad:
		var names: Array[String] = []
		names.assign(ALPHA)
		f.controls.groups.save(1, names)
	return f


func _listen(f: Fixture) -> Array:
	var heard: Array = []
	f.controls.command_issued.connect(func(command: Dictionary, error: String) -> void:
		heard.append({"command": command.duplicate(true), "error": error}))
	return heard


func _notices(f: Fixture) -> Array:
	var said: Array = []
	f.controls.notice.connect(func(text: String, warning: bool) -> void: said.append([text, warning]))
	return said


func _task(f: Fixture) -> Dictionary:
	var element := f.controls.elements.of(String(ALPHA[0]))
	return element.task if element != null else {}


static func _approach(entry: Dictionary) -> Vector2:
	var side: Array = entry.get("approach", [])
	return Vector2(float(side[0]), float(side[1])) if side.size() == 2 else Vector2.ZERO


func _left_drag(f: Fixture, from: Vector2, to: Vector2, shift := false) -> void:
	f.button(from, true, MOUSE_BUTTON_LEFT, shift)
	for i in range(1, 6):
		f.motion(from.lerp(to, i / 5.0), shift)
	f.button(to, false, MOUSE_BUTTON_LEFT, shift)
	await tree.process_frame


## Whether brains' CP0 has taught the element task the key. Before it, the side is dropped at the task (its validator
## refuses unknown keys) and the attack is today's; after it, the task must carry exactly what was drawn.
static func _task_takes_approach() -> bool:
	return ElementTask.KEYS.has("approach")


func _assert_attack_from_west(f: Fixture, heard: Array, how: String) -> void:
	assert_true(not heard.is_empty(), "%s: an order was given" % how)
	var command: Dictionary = heard[heard.size() - 1]["command"]
	assert_eq(String(heard[heard.size() - 1]["error"]), "", "%s: nothing refused (%s)" % [how, heard])
	assert_eq(String(command.get("verb", "")), "attack", "%s: an attack (%s)" % [how, command])
	assert_eq(String(command.get("target", "")), ENEMY, "%s: on the enemy pressed" % how)
	assert_true(_approach(command).distance_to(Vector2(1.0, 0.0)) < 0.05,
			"%s: approach from the west, pointing east at the enemy (%s)" % [how, command.get("approach")])
	assert_true(not command.has("facing"), "%s: an approach is not a facing" % how)
	var task := _task(f)
	assert_eq(String(task.get("verb", "")), "attack", "%s: the squad took an attack task (%s)" % [how, task])
	if _task_takes_approach():
		assert_true(_approach(task).distance_to(Vector2(1.0, 0.0)) < 0.05, "%s: the task carries it (%s)" % [how, task])
	else:
		assert_true(not task.has("approach"), "%s: before CP0 the task is today's attack (%s)" % [how, task])
	assert_true(f.controls.describe(command).ends_with("from the W"), "%s: the HUD says the side (%s)"
			% [how, f.controls.describe(command)])


# ---- a click is today's attack -----------------------------------------------------------------------------------

func test_a_right_click_on_an_enemy_is_todays_attack_task() -> void:
	var f := await _setup()
	await f.select(ALPHA)
	var heard := _listen(f)
	await f.right_click(f.screen(ENEMY))
	assert_eq(heard.size(), 1, "one click, one order (%s)" % [heard])
	assert_true(not (heard[0]["command"] as Dictionary).has("approach"), "a click draws no side")
	var task := _task(f)
	assert_eq(String(task.get("verb", "")), "attack", "the squad attacks (%s)" % [task])
	assert_eq(String(task.get("target", "")), ENEMY, "that enemy")
	assert_true(not task.has("approach"), "and the task has no approach key (C27.3: absent = today)")


func test_a_right_click_attack_is_byte_identical_to_mains_path() -> void:
	var f := await _setup()
	await f.select(ALPHA)
	var heard := _listen(f)
	await f.right_click(f.screen(ENEMY))
	var clicked := JSON.stringify(heard[0]["command"])
	var task := JSON.stringify(_task(f))
	f.controls.right_click_order(f.screen(ENEMY), false)
	assert_eq(JSON.stringify(heard[1]["command"]), clicked, "the click's command is main's for the same point")
	assert_eq(JSON.stringify(_task(f)), task, "and so is the task")


func test_a_twitch_on_an_enemy_is_still_a_click() -> void:
	var f := await _setup()
	await f.select(ALPHA)
	var heard := _listen(f)
	var at := f.screen(ENEMY)
	await f.right_drag(at, at + Vector2(RtsControls.FACING_DRAG_PX - 4.0, 0.0))
	assert_eq(heard.size(), 1, "one order")
	assert_true(not (heard[0]["command"] as Dictionary).has("approach"), "a twitch draws no side (%s)" % [heard])


func test_an_armed_attack_move_click_on_an_enemy_is_todays_attack() -> void:
	var f := await _setup()
	await f.select(ALPHA)
	var heard := _listen(f)
	await f.key(KEY_A)
	await f.click(f.screen(ENEMY))
	assert_eq(heard.size(), 1, "one order (%s)" % [heard])
	assert_eq(String(heard[0]["command"]["verb"]), "attack", "an attack on the enemy clicked")
	assert_true(not (heard[0]["command"] as Dictionary).has("approach"), "no side")
	assert_eq(f.controls.mode, "", "the click spends the armed order")


# ---- a drag is an attack from that side ----------------------------------------------------------------------------

func test_a_right_drag_from_an_enemy_attacks_from_the_side_drawn() -> void:
	var f := await _setup()
	await f.select(ALPHA)
	var heard := _listen(f)
	await f.right_drag(f.screen(ENEMY), f.ground(WEST))
	_assert_attack_from_west(f, heard, "right drag")


func test_an_armed_attack_move_drag_from_an_enemy_attacks_from_the_side_drawn() -> void:
	var f := await _setup()
	await f.select(ALPHA)
	var heard := _listen(f)
	await f.key(KEY_A)
	await _left_drag(f, f.screen(ENEMY), f.ground(WEST))
	_assert_attack_from_west(f, heard, "armed drag")
	assert_eq(f.controls.mode, "", "the drag spends the armed order")
	assert_true(f.controls.selection.units.size() == ALPHA.size(), "and never boxes or reselects")


func test_a_shift_drag_keeps_attack_move_armed() -> void:
	var f := await _setup()
	await f.select(ALPHA)
	var heard := _listen(f)
	await f.key(KEY_A)
	await _left_drag(f, f.screen(ENEMY), f.ground(WEST), true)
	_assert_attack_from_west(f, heard, "shift drag")
	assert_eq(f.controls.mode, "attack_move", "shift keeps the order armed for the next one")


func test_two_squads_each_take_the_side() -> void:
	var f := await _setup()
	var bravo: Array[String] = ["Green_Bravo_1", "Green_Bravo_2"]
	f.controls.groups.save(2, bravo)
	await f.select(ALPHA + ["Green_Bravo_1", "Green_Bravo_2"])
	var heard := _listen(f)
	await f.right_drag(f.screen(ENEMY), f.ground(WEST))
	var attacks := heard.filter(func(entry: Dictionary) -> bool: return String(entry["command"]["verb"]) == "attack")
	assert_eq(attacks.size(), 2, "one attack per squad (%s)" % [heard])
	for entry: Dictionary in attacks:
		assert_eq(String(entry["error"]), "", "nothing refused")
		assert_true(_approach(entry["command"]).distance_to(Vector2(1.0, 0.0)) < 0.05, "each from the west (%s)" % [entry])
	if _task_takes_approach():
		var bravo_task: Dictionary = f.controls.elements.of("Green_Bravo_1").task
		assert_true(_approach(bravo_task).distance_to(Vector2(1.0, 0.0)) < 0.05, "Bravo's task too (%s)" % [bravo_task])


func test_a_drag_released_above_the_horizon_uses_the_last_ground_crossed() -> void:
	var f := await _setup()
	await f.select(ALPHA)
	var heard := _listen(f)
	var from := f.screen(ENEMY)
	f.button(from, true, MOUSE_BUTTON_RIGHT)
	f.motion(f.ground(WEST), false, MOUSE_BUTTON_MASK_RIGHT)
	f.button(Vector2(f.ground(WEST).x, -4000.0), false, MOUSE_BUTTON_RIGHT)
	await tree.process_frame
	_assert_attack_from_west(f, heard, "above the horizon")


# ---- a selection that cannot plan a flank, cancelling, seeing it ----------------------------------------------------

func test_a_drag_with_no_squad_attacks_head_on_and_says_why() -> void:
	var f := await _setup(false)
	await f.click(f.screen("Green_Alpha_1"))
	var heard := _listen(f)
	var said := _notices(f)
	await f.right_drag(f.screen(ENEMY), f.ground(WEST))
	var order := f.orders.current("Green_Alpha_1")
	assert_eq(String(order.get("verb", "")), "attack", "it still attacks (%s)" % [order])
	assert_true(not order.has("approach") and not order.has("facing"), "with no side on a unit order (%s)" % [order])
	assert_true(heard.all(func(entry: Dictionary) -> bool: return String(entry["error"]) == ""), "nothing refused (%s)" % [heard])
	assert_true(said.any(func(n: Array) -> bool: return String(n[0]).contains("squad")), "and says a squad draws a side (%s)" % [said])


func test_escape_during_a_right_drag_on_an_enemy_cancels_it() -> void:
	var f := await _setup()
	await f.select(ALPHA)
	var heard := _listen(f)
	f.button(f.screen(ENEMY), true, MOUSE_BUTTON_RIGHT)
	f.motion(f.ground(WEST), false, MOUSE_BUTTON_MASK_RIGHT)
	await f.key(KEY_ESCAPE)
	f.button(f.ground(WEST), false, MOUSE_BUTTON_RIGHT)
	await tree.process_frame
	assert_eq(heard.size(), 0, "no order (%s)" % [heard])
	assert_eq(f.controls.selection.units.size(), ALPHA.size(), "and the selection stays")


func test_a_right_press_during_an_armed_drag_on_an_enemy_cancels_it() -> void:
	var f := await _setup()
	await f.select(ALPHA)
	var heard := _listen(f)
	await f.key(KEY_A)
	f.button(f.screen(ENEMY), true, MOUSE_BUTTON_LEFT)
	f.motion(f.ground(WEST))
	f.button(f.ground(WEST), true, MOUSE_BUTTON_RIGHT)
	f.button(f.ground(WEST), false, MOUSE_BUTTON_RIGHT)
	f.button(f.ground(WEST), false, MOUSE_BUTTON_LEFT)
	await tree.process_frame
	assert_eq(heard.filter(func(entry: Dictionary) -> bool: return String(entry["command"]["verb"]) == "attack").size(), 0,
			"no attack (%s)" % [heard])
	assert_eq(f.controls.mode, "", "and the order is disarmed")


func test_the_attack_drag_is_visible_while_the_button_is_down() -> void:
	var f := await _setup()
	await f.select(ALPHA)
	var at := f.screen(ENEMY)
	f.button(at, true, MOUSE_BUTTON_RIGHT)
	await tree.process_frame
	var pressed := f.controls.attack_gesture()
	assert_eq(String(pressed.get("target", "")), ENEMY, "the press rings the enemy (%s)" % [pressed])
	assert_true(not bool(pressed.get("approach", true)), "a press alone promises no side")
	f.motion(f.ground(WEST), false, MOUSE_BUTTON_MASK_RIGHT)
	await tree.process_frame
	assert_true(bool(f.controls.attack_gesture().get("approach", false)), "past the threshold it shows the side")
	f.button(f.ground(WEST), false, MOUSE_BUTTON_RIGHT)
	await tree.process_frame
	assert_true(f.controls.attack_gesture().is_empty(), "and the release clears it")


# ---- O4: he can find the gesture ---------------------------------------------------------------------------------

func test_the_help_names_the_flank_drag() -> void:
	assert_true(String(RtsControls.MODE_HINTS["attack_move"]).contains("drag to flank"), "the armed hint names it")
	assert_true(String(TaskPalette.row("attack_move")["line"]).contains("attacks it from there"), "so does the card")
	assert_true(ControlHints.HINTS.has("flank"), "and a first-time hint teaches it")


func test_a_flank_drag_retires_its_hint() -> void:
	var f := await _setup()
	var hints := ControlHints.new()
	hints.store_path = ""
	f.controls.add_child(hints)
	await f.select(ALPHA)
	await f.right_drag(f.screen(ENEMY), f.ground(WEST))
	assert_true(hints._learned.has("flank"), "the first flank drag retires the hint")

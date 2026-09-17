extends TestCase
## Control X6 (round 5): the controls a new player can discover. A short hint set in the bottom-left corner that
## never nags: at most three at a time, each gone for good the first time the player does what it says (remembered
## across sessions), and none at all once they're all learned.

const STORE := "user://test_control_hints.cfg"


func _hints() -> ControlHints:
	tree.root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	var hints := ControlHints.new()
	hints.store_path = STORE
	add_to_tree(hints)
	return hints


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		tree.root.push_input(event)


func _right_click(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		tree.root.push_input(event)


func test_a_new_player_sees_three_hints_in_order() -> void:
	var hints := _hints()
	await tree.process_frame
	var shown := hints.shown()
	assert_eq(shown.size(), 3, "three at a time")
	assert_eq(shown[0], "select", "picking an element comes first")
	assert_true(hints.visible, "and they show")


func test_doing_it_retires_the_hint_for_good() -> void:
	var hints := _hints()
	await tree.process_frame
	_key(KEY_1)
	_right_click(Vector2(640, 300))
	await tree.process_frame
	assert_true(not hints.shown().has("select") and not hints.shown().has("order"), "used hints go (%s)" % [hints.shown()])
	assert_eq(hints.shown().size(), 3, "and the next ones move up")
	var again := ControlHints.new()
	again.store_path = STORE
	add_to_tree(again)
	await tree.process_frame
	assert_true(not again.shown().has("select") and not again.shown().has("order"), "a new session remembers what was learned")


func test_once_everything_is_learned_nothing_shows() -> void:
	var hints := _hints()
	await tree.process_frame
	for id: String in ControlHints.HINTS.keys():
		hints.learn(id)
	await tree.process_frame
	assert_true(hints.shown().is_empty() and not hints.visible, "no hints left, no panel")


func test_hints_never_swallow_input() -> void:
	var hints := _hints()
	await tree.process_frame
	assert_eq(hints.mouse_filter, Control.MOUSE_FILTER_IGNORE, "clicks pass through to the map")
	var rect := hints.panel_rect()
	assert_true(rect.has_area() and Rect2(0, 0, 1280, 720).encloses(rect), "the panel is on screen (%s)" % rect)
	assert_true(rect.end.x <= 1280 * 0.25 and rect.position.y >= 720 * 0.7, "bottom-left, clear of the command card and the radar")

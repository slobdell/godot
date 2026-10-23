extends TestCase
## Round 38 (feedback F1/F2): the end card. Once a match he commands is over, a click on the field or an order key reaches
## nothing that orders (round 37: his clicks after the end still answered "move"); the click says MATCH OVER instead, and Enter
## or Esc leads on. Input goes through the real viewport (pushed events), like his mouse.

const HUD := preload("res://game/ui/hud.tscn")
const MATCH := preload("res://game/match/match.tscn")


## Stands in for RtsControls on the HUD layer: a full-rect control that orders on any click or key it receives.
class FakeControls extends Control:
	var clicks := 0
	var keys := 0

	func _ready() -> void:
		name = "TacticalMap"
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			clicks += 1

	func _unhandled_key_input(event: InputEvent) -> void:
		if (event as InputEventKey).pressed:
			keys += 1


func _frames(count: int) -> void:
	for i in count:
		await tree.process_frame


func _rust_wins() -> Dictionary:
	return {"winner": "Rust", "reason": "control", "control": {"green": 61, "rust": 90}, "units_left": {"green": 2, "rust": 5}}


func _click(at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = at
		event.global_position = at
		tree.root.push_input(event)


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		tree.root.push_input(event)


func _setup() -> Array:
	if tree.root.size.x < 640:
		tree.root.size = Vector2i(1280, 720)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var hud: Hud = HUD.instantiate()
	hud.game_match = game_match
	add_to_tree(hud)
	var controls := FakeControls.new()
	hud.add_child(controls)
	await _frames(2)
	return [game_match, hud, controls]


func test_before_the_end_a_click_orders() -> void:
	var setup: Array = await _setup()
	var controls: FakeControls = setup[2]
	_click(Vector2(640, 500))
	await _frames(1)
	assert_eq(controls.clicks, 1, "the controls get the click while the match runs")
	assert_true((setup[1] as Hud).end_card == null, "no card before the end")


func test_after_the_end_a_click_says_match_over_and_orders_nothing() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var hud: Hud = setup[1]
	var controls: FakeControls = setup[2]
	game_match.finished.emit(_rust_wins())
	hud.show_banner("DEFEAT")  # skirmish's own handler, after (or before) ours
	await _frames(1)
	assert_true(hud.end_card != null, "the card is up")
	assert_true(not hud.banner.visible, "the old label does not double it")
	assert_eq(hud.end_card.headline, "DEFEAT", "the result")
	assert_eq(hud.end_card.reason, "Rust held the rings: 90 points to 61", "and why")
	_click(Vector2(640, 500))
	_click(Vector2(300, 400), MOUSE_BUTTON_RIGHT)
	await _frames(1)
	assert_eq(controls.clicks, 0, "no click reaches the controls after the end")
	assert_eq(hud.end_card.notices(), 2, "each click says MATCH OVER where it landed")
	_key(KEY_S)
	_key(KEY_1)
	await _frames(1)
	assert_eq(controls.keys, 0, "no order key or group recall reaches the controls")


func test_enter_plays_again_once_the_choices_show() -> void:
	var card := EndCard.new()
	card.setup(_rust_wins(), Match.Team.GREEN, false, {}, "a")
	var picked: Array[String] = []
	card.chosen.connect(func(choice: String) -> void: picked.append(choice))
	add_to_tree(card)
	assert_true(not card.choose("again"), "not before the choices show (a stray click at the end must not restart)")
	card.advance(float(EndCard.CHOICES_AFTER["a"]) + 0.01)
	assert_true(card.choose("again"), "then Enter plays again")
	assert_true(not card.choose("factions"), "once only")
	assert_eq(picked, ["again"] as Array[String], "one choice emitted")


func test_under_the_garage_loop_there_are_no_choices() -> void:
	var card := EndCard.new()
	card.setup(_rust_wins(), Match.Team.GREEN, false, {}, "plain")
	card.choices = false
	add_to_tree(card)
	card.advance(5.0)
	assert_true(not card.choose("again"), "the results screen follows instead")
	card.field_click(Vector2(10, 10))
	assert_eq(card.notices(), 1, "the guard still says MATCH OVER")


func test_every_look_draws() -> void:
	if tree.root.size.x < 640:
		tree.root.size = Vector2i(1280, 720)
	for look: String in MatchEnd.LOOKS:
		var card := EndCard.new()
		card.setup(_rust_wins(), Match.Team.GREEN, false, {Match.Team.RUST: "syndicate"}, look)
		add_to_tree(card)
		card.advance(3.0)
		card.field_click(Vector2(640, 360))
		await _frames(1)
		assert_eq(card.look, look, "look %s" % look)
		assert_true(card.choices_shown(), "%s: the choices show by 3 s" % look)
		card.queue_free()


func test_the_place_it_was_decided() -> void:
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.objectives = [{"name": "a", "position": Vector3(10, 0, 5), "radius": 8.0, "owner": Match.Team.GREEN},
			{"name": "b", "position": Vector3(-30, 0, 20), "radius": 8.0, "owner": Match.Team.RUST}]
	assert_eq(EndCard.decided_at(game_match, _rust_wins()), Vector3(-30, 0, 20), "the ring the winner holds")
	assert_eq(EndCard.decided_at(game_match, {"winner": "draw", "reason": "time_limit"}), null, "a draw: leave the camera")


## Stands in for ArmyLoop: its results screen comes up a few seconds after the end.
class FakeLoop extends Node:
	var results: Variant = null


func test_under_the_garage_loop_the_results_screen_gets_its_keys() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var hud: Hud = setup[1]
	var controls: FakeControls = setup[2]
	game_match.finished.emit(_rust_wins())
	await _frames(1)
	var loop := FakeLoop.new()
	add_to_tree(loop)
	hud.end_card.yield_to = loop
	_key(KEY_S)
	await _frames(1)
	assert_eq(controls.keys, 0, "before the results: still no order key")
	loop.results = Node.new()
	_key(KEY_ENTER)
	await _frames(1)
	assert_eq(controls.keys, 1, "with the results up, keys go on to the screen (here the stand-in)")
	(loop.results as Node).free()


func test_on_a_portrait_phone_no_line_is_wider_than_its_box() -> void:
	var font := CyberStyle.font()
	var boost := CyberStyle.touch_boost()
	CyberStyle.set_touch_boost(1.5)  # a phone grows the HUD 1.5x
	for look: String in MatchEnd.LOOKS:
		var card := EndCard.new()
		card.setup({"winner": "Rust", "reason": "control", "control": {"green": 61, "rust": 90},
				"units_left": {"green": 20, "rust": 20}}, Match.Team.GREEN, false, {Match.Team.RUST: "gangs"}, look)
		add_to_tree(card)
		card.set_anchors_preset(Control.PRESET_TOP_LEFT)
		card.size = Vector2(810, 1800)
		card.advance(3.0)
		await _frames(1)
		for choice: String in EndCard.CHOICES:
			var box: Rect2 = card._choice_rects[choice]
			assert_true(Rect2(Vector2.ZERO, card.size).encloses(box), "%s: %s's box is on screen (%s)" % [look, choice, box])
		card.queue_free()
	CyberStyle.set_touch_boost(boost)
	assert_true(font != null, "the HUD font loads")

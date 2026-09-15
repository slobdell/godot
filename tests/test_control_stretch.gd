extends TestCase
## Control stretch items: smart attack for a mixed selection (only units whose guns can hurt the target attack it; the
## rest escort them), a key that selects idle units, and hover tooltips with unit stats.

const Fixture := preload("res://tests/support/control_fixture.gd")


func _setup() -> Fixture:
	var f := Fixture.new(self)
	await f.build(false)
	return f


func test_right_clicking_a_tank_with_a_mixed_selection_sends_only_the_guns_that_hurt_it() -> void:
	var f := await _setup()
	# Green_Alpha_1 is a tank (its cannon hurts a tank), Green_Bravo_2 a scout (its machine gun barely scratches one).
	await f.select(["Green_Alpha_1", "Green_Bravo_2"])
	await f.right_click(f.screen("Rust_Alpha_1"))
	assert_eq(f.orders.current("Green_Alpha_1").get("verb", ""), "attack", "the tank attacks the enemy tank")
	assert_eq(f.orders.current("Green_Bravo_2").get("verb", ""), "follow", "the scout escorts instead of attacking")
	assert_eq(f.orders.current("Green_Bravo_2").get("target", ""), "Green_Alpha_1", "it follows the attacking tank")


func test_if_nothing_selected_can_hurt_the_target_everyone_attacks_anyway() -> void:
	var f := await _setup()
	await f.select(["Green_Bravo_2"])
	await f.right_click(f.screen("Rust_Alpha_1"))
	assert_eq(f.orders.current("Green_Bravo_2").get("verb", ""), "attack", "the player's explicit order wins")


func test_the_idle_key_selects_units_without_orders() -> void:
	var f := await _setup()
	await f.select(["Green_Alpha_1", "Green_Alpha_2"])
	await f.right_click(f.ground(Vector3(-15, 0, 15)))
	await f.key(KEY_F1)
	assert_eq(f.controls.selection.units, ["Green_Alpha_3", "Green_Bravo_1", "Green_Bravo_2"], "F1 selects every idle unit")
	await f.right_click(f.ground(Vector3(10, 0, 15)))
	await f.key(KEY_F1)
	assert_eq(f.controls.selection.units, ["Green_Alpha_3", "Green_Bravo_1", "Green_Bravo_2"], "with nobody idle the selection stays")


func test_resting_the_mouse_on_a_unit_shows_its_stats() -> void:
	var f := await _setup()
	f.motion(f.screen("Rust_Alpha_1"), false, 0)
	await wait_physics_frames(2)
	assert_eq(f.controls.tooltip(), {}, "no tooltip the instant the mouse arrives")
	for i in 30:
		await tree.create_timer(0.05).timeout
		if not f.controls.tooltip().is_empty():
			break
	var tip := f.controls.tooltip()
	assert_eq(tip.get("unit", ""), "Rust_Alpha_1", "resting on a unit shows its tooltip")
	assert_true(String(tip.get("title", "")).contains("Tank"), "titled with its type (%s)" % tip.get("title"))
	var text := "\n".join(tip.get("lines", []))
	assert_true(text.contains("Hull") and text.contains("Speed") and text.contains("Strong vs"), "with stats and matchups:\n%s" % text)
	f.motion(Vector2(20, 20), false, 0)
	await tree.process_frame
	assert_eq(f.controls.tooltip(), {}, "moving off the unit hides it")

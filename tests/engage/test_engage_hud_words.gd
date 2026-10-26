extends TestCase
## Round 42 (engage E3, C42.6): THE HUD'S WORDS FOLLOW THE TRUTH. His Rat Rod behind the container read NOT FIRING for 37 s
## while its gun had no line to the target. Pinned here: a crew driving for a shot reads as carrying the order out (nothing);
## one standing with no line says NO LINE OF FIRE; NOT FIRING is kept for a crew standing with a clear shot that does not
## fire; a move naming the target still reads as carrying the order out (round 8's rule).

const Fixture := preload("res://tests/support/control_fixture.gd")


func _keep_alive(f: Fixture, unit_name: String) -> void:
	f.tank(unit_name).max_health = 1_000_000
	f.tank(unit_name).health = 1_000_000


func test_the_words() -> void:
	var f := Fixture.new(self)
	await f.build(false)  # guns are stubbed: what each gun is on is the test's to say
	_keep_alive(f, "Rust_Alpha_1")
	_keep_alive(f, "Green_Alpha_1")
	f.controls.engaged_of = func(_unit_name: String) -> String: return ""
	var line := {"Green_Alpha_1": true}
	f.controls.line_of_fire = func(unit_name: String, _target: String) -> bool: return bool(line.get(unit_name, true))
	# In the gun's range (a tank's cannon reaches past 20 m), seen (reveal_all is only the HUD's picker; the match's intel
	# sees an enemy this close).
	var crew := f.tank("Green_Alpha_1")
	f.place("Rust_Alpha_1", crew.global_position + Vector3(0.0, 0.0, -20.0))
	await wait_physics_frames(2)
	await f.select(["Green_Alpha_1"])
	assert_eq(f.controls.order_selection("attack", {"target": "Rust_Alpha_1"}), "", "the attack order is taken")
	var order := {"target": "Rust_Alpha_1"}
	crew.estimated_velocity = Vector3.ZERO
	assert_eq(f.controls.attack_shortfall("Green_Alpha_1", order), "NOT FIRING",
			"standing with a clear shot and the gun on nothing: NOT FIRING (a bug, not a state)")
	line["Green_Alpha_1"] = false
	assert_eq(f.controls.attack_shortfall("Green_Alpha_1", order), "NO LINE OF FIRE",
			"standing with no line to the target: it says so")
	crew.estimated_velocity = Vector3(5.0, 0.0, 0.0)
	assert_eq(f.controls.attack_shortfall("Green_Alpha_1", order), "",
			"driving with no line: it is going for a shot, carrying the order out")
	line["Green_Alpha_1"] = true
	assert_eq(f.controls.attack_shortfall("Green_Alpha_1", order), "NOT FIRING",
			"driving in range with a clear shot and the gun on nothing: still NOT FIRING")
	# Round 8's rule stands: a move that names the target is the order being carried out, line or no line.
	line["Green_Alpha_1"] = false
	crew.estimated_velocity = Vector3.ZERO
	f.orders.issue({"units": ["Green_Alpha_1"], "verb": "move", "to": [40.0, 10.0], "target": "Rust_Alpha_1",
			"source": "element"}, Match.Team.GREEN)
	assert_eq(f.controls.attack_shortfall("Green_Alpha_1", order), "", "a move naming the target: carrying the order out")


func test_the_default_read_is_the_cover_map() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	_keep_alive(f, "Rust_Alpha_1")
	f.controls.engaged_of = func(_unit_name: String) -> String: return ""
	var crew := f.tank("Green_Alpha_1")
	f.place("Rust_Alpha_1", crew.global_position + Vector3(0.0, 0.0, -20.0))
	await wait_physics_frames(2)
	await f.select(["Green_Alpha_1"])
	f.controls.order_selection("attack", {"target": "Rust_Alpha_1"})
	crew.estimated_velocity = Vector3.ZERO
	var map := CoverMap.of(f.game_match)
	var expected := "NOT FIRING" if map == null or map.clear_line(crew.global_position, f.tank("Rust_Alpha_1").global_position) \
			else "NO LINE OF FIRE"
	assert_eq(f.controls.attack_shortfall("Green_Alpha_1", {"target": "Rust_Alpha_1"}), expected,
			"unset, the read is the arena's cover map (%s)" % expected)

extends TestCase
## Control X2: element focus and awareness. Element state (idle, moving, contact, under fire), the rate-limited
## alert feed you can jump to, the off-screen markers that keep the rest of your force on the screen edge, and
## the keys that move the camera between elements.

const Fixture := preload("res://tests/support/control_fixture.gd")


func _frames(count := 2) -> void:
	for i in count:
		await tree.process_frame


## The fixture with control groups: Alpha (three units) is 1, Bravo (two) is 2. `bravo_away` parks Bravo in the
## far corner before the first update, so it starts out of contact and its first sighting is a real transition.
func _setup(bravo_away := false) -> Fixture:
	var f := Fixture.new(self)
	await f.build(false)
	f.controls.groups.save(1, ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"])
	f.controls.groups.label(1, "Alpha")
	f.controls.groups.save(2, ["Green_Bravo_1", "Green_Bravo_2"])
	f.controls.groups.label(2, "Bravo")
	if bravo_away:
		f.tank("Green_Bravo_1").global_position = Vector3(90, 0, 100)
		f.tank("Green_Bravo_1").reset_physics_interpolation()  # teleport: interpolation must not draw it at its old spot
		f.tank("Green_Bravo_2").global_position = Vector3(96, 0, 100)
		f.tank("Green_Bravo_2").reset_physics_interpolation()  # teleport: interpolation must not draw it at its old spot
	f.rig.vision = f.controls.vision_state
	await _frames(2)
	return f


func _element(f: Fixture, number: int) -> Dictionary:
	for element: Dictionary in f.controls.awareness.elements():
		if int(element["number"]) == number:
			return element
	return {}


# ---- Element state ------------------------------------------------------------------------------------------

func test_an_element_reports_its_strength_and_where_it_is() -> void:
	var f := await _setup()
	var alpha := _element(f, 1)
	assert_eq(alpha.get("label", ""), "Alpha", "the element keeps the squad's name")
	assert_eq(alpha.get("alive", 0), 3, "three units alive")
	assert_near(float(alpha.get("health", 0.0)), 1.0, 0.01, "at full strength")
	var middle := (f.tank("Green_Alpha_1").global_position + f.tank("Green_Alpha_2").global_position
			+ f.tank("Green_Alpha_3").global_position) / 3.0
	assert_true((alpha["position"] as Vector3).distance_to(middle) < 1.0, "positioned at the element's middle")
	f.tank("Green_Alpha_2").health = f.tank("Green_Alpha_2").max_health / 2
	await _frames(2)
	assert_true(float(_element(f, 1)["health"]) < 0.9, "a hurt unit drags the element's health down")


func test_an_element_is_idle_then_moving_then_in_contact_then_under_fire() -> void:
	var f := await _setup(true)
	assert_eq(_element(f, 2).get("state", ""), "idle", "no orders, no enemy in sight")
	f.controls.selection.set_units(["Green_Bravo_1", "Green_Bravo_2"])
	f.controls.order_selection("move", {"to": [80.0, 60.0]})
	await _frames(2)
	assert_eq(_element(f, 2).get("state", ""), "moving", "an order it is still working on")
	f.tank("Rust_Alpha_1").global_position = Vector3(90, 0, 90)
	f.tank("Rust_Alpha_1").reset_physics_interpolation()  # teleport: interpolation must not draw it at its old spot
	await _frames(2)
	assert_eq(_element(f, 2).get("state", ""), "contact", "an enemy inside its sight outranks moving")
	f.tank("Green_Bravo_1").ticks_since_hit = 1
	await _frames(2)
	assert_eq(_element(f, 2).get("state", ""), "under_fire", "being hit outranks everything but being wiped out")
	for unit_name in ["Green_Bravo_1", "Green_Bravo_2"]:
		f.tank(unit_name).alive = false
	await _frames(2)
	assert_eq(_element(f, 2).get("state", ""), "lost", "an element with nobody left")


# ---- Alerts -------------------------------------------------------------------------------------------------

func test_contact_raises_one_alert_you_can_jump_to_not_a_stream_of_them() -> void:
	var f := await _setup(true)
	assert_true(f.controls.awareness.alerts.filter(func(a: Dictionary) -> bool: return int(a["element"]) == 2).is_empty(),
			"an element that has seen nothing has nothing to say")
	f.tank("Rust_Alpha_1").global_position = Vector3(90, 0, 90)
	f.tank("Rust_Alpha_1").reset_physics_interpolation()  # teleport: interpolation must not draw it at its old spot
	await _frames(3)
	var raised := f.controls.awareness.alerts.filter(func(a: Dictionary) -> bool: return int(a["element"]) == 2)
	assert_eq(raised.size(), 1, "entering contact raises exactly one alert (got %s)" % [raised.map(func(a: Dictionary) -> String: return a["text"])])
	assert_true(String(raised[0]["text"]).begins_with("Bravo"), "named after the element: %s" % raised[0]["text"])
	# Held in contact: the enemy stays put (left to its own brain it drives off and back into sight, which is a new
	# contact and a fair second alert). Count CONTACT alerts only — the same enemy shooting back raises an
	# "under fire" alert, which is a different thing to say and has its own cooldown.
	for frame in 20:
		f.tank("Rust_Alpha_1").global_position = Vector3(90, 0, 90)
		f.tank("Rust_Alpha_1").reset_physics_interpolation()  # teleport: interpolation must not draw it at its old spot
		await tree.process_frame
	raised = f.controls.awareness.alerts.filter(func(a: Dictionary) -> bool:
			return int(a["element"]) == 2 and String(a["kind"]) == "contact")
	assert_eq(raised.size(), 1, "staying in contact does not repeat it (%s)"
			% [f.controls.awareness.alerts.map(func(a: Dictionary) -> String: return a["text"])])


func test_jumping_to_an_alert_selects_that_element_and_moves_the_camera() -> void:
	var f := await _setup(true)
	f.controls.selection.set_units(["Green_Alpha_1"])
	await _frames(3)
	f.controls.awareness.forget()
	f.tank("Green_Bravo_1").ticks_since_hit = 1
	await _frames(3)
	assert_true(not f.controls.awareness.alerts.is_empty(), "being hit raises an alert")
	await f.key(KEY_Q)
	await _frames(2)
	assert_eq(f.controls.selection.units, ["Green_Bravo_1", "Green_Bravo_2"], "Q selects the element that called")
	assert_true(Vector2(f.rig.focus.x - 90.0, f.rig.focus.z - 100.0).length() < 30.0,
			"and the camera goes there (%s)" % f.rig.focus)
	# Alpha can see the enemy from the start, so there are other unseen alerts; what must not happen is being
	# handed Bravo's again.
	var bravo := f.controls.awareness.alerts.filter(func(a: Dictionary) -> bool: return int(a["element"]) == 2)
	assert_true(bravo.all(func(a: Dictionary) -> bool: return bool(a["seen"])), "the alert Q used is marked seen")
	var again := f.controls.awareness.take_alert()
	assert_true(again.is_empty() or int(again["element"]) != 2, "and is never offered a second time")


# ---- Off-screen markers -------------------------------------------------------------------------------------

func test_elements_off_screen_get_an_edge_marker_and_those_on_screen_do_not() -> void:
	var f := await _setup()
	for unit_name in ["Green_Bravo_1", "Green_Bravo_2"]:
		f.tank(unit_name).global_position = Vector3(-110, 0, -110)
		f.tank(unit_name).reset_physics_interpolation()  # teleport: interpolation must not draw it at its old spot
	f.controls.selection.set_units(["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"])
	await _frames(4)
	var marks := f.controls.markers.markers()
	var numbers := marks.map(func(m: Dictionary) -> int: return int(m["element"]))
	assert_true(numbers.has(2), "the element across the arena is marked on the edge")
	assert_true(not numbers.has(1), "the element you are watching is not")
	var mark: Dictionary = marks[numbers.find(2)]
	assert_eq(mark["label"], "Bravo", "the marker names it")
	assert_near(float(mark["health"]), 1.0, 0.01, "and carries its strength")
	var screen := f.controls.get_viewport_rect()
	assert_true(screen.has_point(mark["at"]), "the marker sits on screen (%s in %s)" % [mark["at"], screen.size])
	var inner := Rect2(screen.position, screen.size).grow(-EdgeMarkers.EDGE_PX)
	inner.size.y -= screen.size.y * EdgeMarkers.BOTTOM_FRACTION - EdgeMarkers.EDGE_PX
	assert_true(not inner.grow(-1.0).has_point(mark["at"]), "pinned to the edge, not floating in the middle")
	assert_true((mark["at"] as Vector2).y <= screen.size.y * (1.0 - EdgeMarkers.BOTTOM_FRACTION) + 1.0,
			"and clear of the command card (%s of %s)" % [mark["at"], screen.size])


func test_clicking_an_edge_marker_takes_you_to_that_element() -> void:
	var f := await _setup()
	for unit_name in ["Green_Bravo_1", "Green_Bravo_2"]:
		f.tank(unit_name).global_position = Vector3(-110, 0, -110)
		f.tank(unit_name).reset_physics_interpolation()  # teleport: interpolation must not draw it at its old spot
	f.controls.selection.set_units(["Green_Alpha_1"])
	await _frames(4)
	var marks := f.controls.markers.markers()
	var mark: Dictionary = marks.filter(func(m: Dictionary) -> bool: return int(m["element"]) == 2)[0]
	await f.click(mark["at"])
	await _frames(2)
	assert_eq(f.controls.selection.units, ["Green_Bravo_1", "Green_Bravo_2"], "the click selects that element")
	assert_true(Vector2(f.rig.focus.x + 110.0, f.rig.focus.z + 110.0).length() < 40.0,
			"and the camera follows it (%s)" % f.rig.focus)


# ---- The radar reads the map --------------------------------------------------------------------------------

func test_the_radar_shows_element_numbers_and_which_way_units_face() -> void:
	var f := await _setup()
	var radar := Radar.new()
	radar.game_match = f.game_match
	radar.controls = f.controls
	f.controls.add_child(radar)
	await _frames(2)
	var blips := radar.blips()
	var friendly := blips.filter(func(b: Dictionary) -> bool: return String(b["kind"]) in ["friendly", "selected"])
	assert_eq(friendly.size(), 5, "every living friendly is a blip")
	for blip: Dictionary in friendly:
		assert_true(blip.has("facing"), "each friendly blip carries a facing for its tick")
	var alpha := friendly.filter(func(b: Dictionary) -> bool: return int(b.get("element", 0)) == 1)
	assert_eq(alpha.size(), 3, "blips know which element they belong to")
	var elements := radar.element_labels()
	assert_eq(elements.size(), 2, "both elements get a label on the radar")
	radar.free()

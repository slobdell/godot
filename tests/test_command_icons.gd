extends TestCase
## C3: formation icons are drawn from the real formation geometry, every drill and formation has a
## plain-language description, and the picker fits a phone.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func test_formation_icons_are_the_real_geometry() -> void:
	var rect := Rect2(10, 20, 120, 80)
	for formation in Formations.NAMES:
		for count in [2, 3, 5]:
			var points := CommandIcons.formation_points(formation, rect, count)
			var offsets := Formations.offsets(formation, count, 1.0)
			assert_eq(points.size(), offsets.size(), "%s x%d: one mark per vehicle" % [formation, count])
			var grown := rect.grow(1.0)
			for p in points:
				assert_true(grown.has_point(p), "%s x%d: marks stay inside the icon (%s)" % [formation, count, p])
			# One uniform scale maps geometry to icon: the icon is the formation, only smaller.
			var scale := -1.0
			for i in range(1, offsets.size()):
				var geometry := offsets[i] - offsets[0]
				var drawn := points[i] - points[0]
				if geometry.length() < 0.001:
					continue
				var k := drawn.length() / geometry.length()
				if scale < 0.0:
					scale = k
				assert_near(k, scale, 0.01, "%s x%d: every gap is scaled alike" % [formation, count])
				assert_true(drawn.normalized().dot(geometry.normalized()) > 0.999,
						"%s x%d: vehicle %d sits in the same direction from the leader" % [formation, count, i])


func test_icon_shapes_read_the_way_their_names_say() -> void:
	var rect := Rect2(0, 0, 100, 100)
	var wedge := CommandIcons.formation_points("wedge", rect, 3)
	assert_true(wedge[0].y < wedge[1].y and wedge[0].y < wedge[2].y, "wedge: the leader is the point, in front")
	var vee := CommandIcons.formation_points("vee", rect, 3)
	assert_true(vee[0].y > vee[1].y and vee[0].y > vee[2].y, "vee: the leader is at the back")
	var line := CommandIcons.formation_points("line", rect, 3)
	assert_near(line[1].y, line[2].y, 0.01, "line: side by side")
	var column := CommandIcons.formation_points("column", rect, 3)
	assert_near(column[0].x, column[2].x, 0.01, "column: single file")
	var right := CommandIcons.formation_points("echelon_right", rect, 3)
	assert_true(right[2].x > right[1].x and right[1].x > right[0].x, "echelon right steps back to the right")


func test_every_drill_and_formation_is_explained() -> void:
	for verb in Squad.VERBS:
		assert_true(CommandIcons.DRILL_INFO.has(verb), "%s has a name and description" % verb)
		assert_true(String(CommandIcons.DRILL_INFO[verb][1]).length() > 10, "%s's description says something" % verb)
	for formation in Formations.NAMES:
		assert_true(CommandIcons.FORMATION_INFO.has(formation), "%s has a name, tagline, and description" % formation)
		assert_eq((CommandIcons.FORMATION_INFO[formation] as Array).size(), 3, "%s: [name, tagline, description]" % formation)


func test_every_brain_option_reads_as_player_words() -> void:
	for option in TankBrain.OPTIONS:
		assert_true(CommandIcons.INTENT_WORDS.has(option), "%s has player words for the unit card" % option)
	assert_eq(CommandIcons.intent_words("ENGAGE Rust_Gun_2"), "Engaging", "the target name is dropped")
	assert_eq(CommandIcons.intent_words("SOMETHING_NEW"), "Something New", "an unknown option still reads")


func _setup(screen: Vector2i) -> Array:
	tree.root.size = screen
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, Doctrine.load_file("res://doctrines/player_default.json")["doctrine"]), "",
			"setup: player doctrine")
	var camera := Camera3D.new()
	add_to_tree(camera)
	camera.make_current()
	var rig := RtsCamera.new()
	rig.camera = camera
	rig.edge_pan = false
	add_to_tree(rig)
	var map := TacticalMap.new()
	map.game_match = game_match
	map.camera = camera
	map.rig = rig
	add_to_tree(map)
	await wait_physics_frames(2)
	return [game_match, map]


func test_the_formation_picker_fits_a_phone_and_applies_a_formation() -> void:
	var setup: Array = await _setup(Vector2i(1200, 540))
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	(map._buttons["formations"] as Button).pressed.emit()
	await tree.process_frame
	await tree.process_frame
	assert_true(map._formation_row.visible, "the Formation button opens the picker")
	var screen := Rect2(Vector2.ZERO, Vector2(1200, 540))
	var picker := map._formation_row.get_global_rect()
	assert_true(screen.encloses(picker), "the picker fits a 1200x540 phone (%s)" % picker)
	assert_true(not picker.intersects(map._command_bar.get_global_rect()), "above the order bar, not over it")
	assert_true(not picker.intersects(map._squad_bar.get_global_rect()), "and below the squad bar")
	for formation in TacticalMap.PICKER_FORMATIONS:
		var card := map._buttons["formation:" + formation] as IconButton
		assert_true(card.size.y >= 48.0 and card.size.x >= 48.0, "%s's card is thumb-sized (%s)" % [formation, card.size])
	assert_true(map._formation_about.text.begins_with("Wedge:"), "the picker explains the current formation (%s)" % map._formation_about.text)
	(map._buttons["formation:echelon_left"] as Button).pressed.emit()
	assert_eq(game_match.squads["0/Alpha"].formation, "echelon_left", "tapping a card sets that exact formation")
	assert_true(not map._formation_row.visible, "and closes the picker")
	await tree.process_frame
	assert_eq((map._buttons["formations"] as IconButton).id, "echelon_left", "the Formation button now shows the echelon icon")


func test_the_info_line_teaches_the_next_order() -> void:
	var setup: Array = await _setup(Vector2i(1280, 720))
	var map: TacticalMap = setup[1]
	(map._buttons["verb:bound"] as Button).pressed.emit()
	assert_eq(map.pending_verb, "bound", "tapping Bound makes it the next order")
	await tree.process_frame  # process_frame fires before nodes process: wait for the map's refresh
	await tree.process_frame
	assert_true(map._info.text.contains("Bound") and map._info.text.contains("covers"),
			"after tapping Bound, the line says what bounding does (%s)" % map._info.text)
	var drill := map._buttons["verb:bound"] as IconButton
	assert_true(drill.button_pressed, "and the Bound button is lit")


func teardown() -> void:
	tree.root.size = Vector2i(1280, 720)
	super.teardown()


func test_unit_icons_skip_positions_a_camera_could_not_project() -> void:
	# The army loop's headless skirmish unprojected a vehicle to NaN on its first frame, and drawing that icon logged
	# "Invalid polygon data, triangulation failed" (an engine error fails this test).
	var canvas := Control.new()
	var drawn := [0]
	canvas.draw.connect(func() -> void:
		for role in ["tank", "scout", "ifv", "artillery", "lancer"]:
			CommandIcons.draw_unit(canvas, role, Vector2(NAN, NAN), 20.0, Color.WHITE)
			CommandIcons.draw_unit(canvas, role, Vector2(50, 50), 20.0, Color.WHITE, NAN)
			CommandIcons.draw_unit(canvas, role, Vector2(50, 50), 20.0, Color.WHITE, 0.3)
			drawn[0] += 1)
	add_to_tree(canvas)
	canvas.queue_redraw()
	await tree.process_frame
	await tree.process_frame
	assert_eq(drawn[0], 5, "the icons were drawn")

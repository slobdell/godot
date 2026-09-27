extends TestCase
## Water reads wet (arena, round 12, A1/A3): the lead, 2026-09-24, on the Crossing's river and the Locks' canal --
## "water reads black and should read wet". These hold the three things a picture cannot prove on its own:
##   - the pairs he judges move ONE decision each, begin at round 10's water and end at what ships;
##   - the water reflects the venue as BUILT, read from the dressing and the layout, never a copied table
##     (Invariant 0) -- a wall, bars, stands and lamps that exist, found where they were placed;
##   - the pits cannot take the wet look: they are a different shader, with none of its dials.

const WATER_SHADER := preload("res://game/theme/arena_kit/terrain/water.gdshader")
const PIT_SHADER := preload("res://game/theme/arena_kit/terrain/pit.gdshader")
const TERRAIN_VISUAL := preload("res://game/theme/arena_kit/terrain/terrain_visual.tscn")
const DRESSING := "res://game/theme/cyberpunk/arena_dressing.tscn"
const TRACE := "res://game/theme/arena_kit/terrain/terrain_trace.gdshaderinc"


func test_the_water_pairs_move_one_decision_at_a_time() -> void:
	var steps: Array = WaterLook.STEPS
	assert_true(steps.size() >= 5, "a pair per diagnosed step (a, b, c, d) after round 10: %d steps" % steps.size())
	assert_true((steps[0][2] as Dictionary).is_empty(), "step 0 is round 10 exactly: it moves nothing")
	var previous := WaterLook.at(steps[0][0])
	for i in range(1, steps.size()):
		var name: String = steps[i][0]
		var look := WaterLook.at(name)
		var moved: Array = []
		for dial: String in WaterLook.DIALS:
			if look[dial] != previous[dial]:
				moved.append(dial)
		assert_true(moved.size() >= 1 and moved.size() <= 2,
				"%s moves one decision (at most a coupled pair of dials): %s" % [name, moved])
		for dial: String in moved:
			assert_true(String(steps[i][1]).contains(dial), "%s's caption names the dial it moves (%s)" % [name, dial])
		previous = look


func test_the_water_pairs_end_at_what_ships() -> void:
	# Read from the shader's SOURCE: the headless test renderer does not compile shaders, so it cannot be asked.
	var defaults := _uniform_defaults(WATER_SHADER.code)
	var shipped := WaterLook.at(WaterLook.STEPS[-1][0])
	for dial: String in WaterLook.DIALS:
		assert_true(defaults.has(dial), "water.gdshader declares the dial %s with a default" % dial)
		if not defaults.has(dial):
			continue
		var have: Array = defaults[dial]
		var want: Variant = shipped[dial]
		var expected: Array = [want.r, want.g, want.b] if want is Color else [float(want)]
		assert_eq(have.size(), expected.size(), "%s has the shape of the last step's value" % dial)
		for i in mini(have.size(), expected.size()):
			assert_near(float(have[i]), float(expected[i]), 1e-5, "water.gdshader's %s default is the last step's (what ships)" % dial)


## {name: [numbers]} for every `uniform <type> <name> [: hints] = <value>;` in a shader's source.
func _uniform_defaults(code: String) -> Dictionary:
	var out := {}
	var pattern := RegEx.create_from_string("uniform\\s+\\w+\\s+(\\w+)\\s*(?::[^=;]*)?=\\s*([^;]+);")
	var number := RegEx.create_from_string("-?[0-9]*\\.?[0-9]+(?:e-?[0-9]+)?")
	for found in pattern.search_all(code):
		var values: Array = []
		# `vec3(0.02, ...)`: the 3 in the type's name is not a component.
		for n in number.search_all(RegEx.create_from_string("[a-z]+[0-9]*\\(").sub(found.get_string(2), "(", true)):
			values.append(float(n.get_string()))
		out[found.get_string(1)] = values
	return out


func test_round_10_is_reproducible_from_the_dials() -> void:
	# The dials whose zero IS round 10: the new looks must switch off completely, or the "before" frame of the first
	# pair is not the water he saw.
	var r10 := WaterLook.at("r10")
	assert_near(float(r10["venue_reflect"]), 0.0, 0.0, "round 10 reflected the horizon band only")
	assert_near(float(r10["glint"]), 0.0, 0.0, "round 10 had no lamp glints")
	assert_near(float(r10["lap"]), 0.0, 0.0, "round 10 had no lap line")
	assert_near(float(r10["legacy_streak"]), 1.0, 0.0, "round 10 had its one streak")
	assert_true((r10["water_deep"] as Color).is_equal_approx(Color(0.004, 0.012, 0.018)), "round 10's oily black")


func test_the_pits_are_their_own_shader_with_none_of_the_waters_dials() -> void:
	var visual := TERRAIN_VISUAL.instantiate()
	add_to_tree(visual)
	var terrain: Array = Arena.load_layout("sumps")["layout"].get("terrain", [])
	visual.call("setup", terrain)
	var pits := visual.get("pits") as MeshInstance3D
	assert_true(pits != null, "POSITIVE CONTROL: the Sumps draws pits")
	if pits == null:
		return
	var material := pits.material_override as ShaderMaterial
	assert_true(material.shader == PIT_SHADER, "a pit draws with pit.gdshader, not the water's")
	# Everything a pit compiles: its own source and the trace it includes.
	var pit_source := PIT_SHADER.code + FileAccess.get_file_as_string(TRACE)
	var pit_uniforms := _uniform_defaults(pit_source)
	for dial: String in WaterLook.DIALS:
		assert_true(not pit_uniforms.has(dial),
				"nothing a pit compiles declares '%s': the wet look cannot reach a pit" % dial)
	assert_true(pit_uniforms.has("depth") and pit_uniforms.has("flow"), "POSITIVE CONTROL: the pit's own uniforms were read")
	assert_true(_uniform_defaults(WATER_SHADER.code).has("lap"), "POSITIVE CONTROL: the same reader finds the water's lap")


func test_the_water_reflects_the_venue_as_built() -> void:
	var layout: Dictionary = Arena.load_layout("crossing")["layout"]
	var dressing := (load(DRESSING) as PackedScene).instantiate() as Node3D
	add_to_tree(dressing)
	dressing.call("setup", layout)
	var visual := TERRAIN_VISUAL.instantiate()
	add_to_tree(visual)
	visual.call("setup", layout.get("terrain", []))
	await tree.process_frame
	await tree.process_frame
	var counts: Dictionary = visual.get("reflection_counts")
	var sides := ArenaShape.sides(String(layout["shape"]["kind"]))
	assert_eq(int(counts.get("edges", 0)), sides, "the water reflects every wall of the %d-sided venue" % sides)
	assert_true(int(counts.get("bars", 0)) >= 1, "and the light bar on its inner face")
	assert_true(int(counts.get("stands", 0)) >= 3, "and the stands' profile (%d points)" % int(counts.get("stands", 0)))
	var floodlights := 0
	for prop: Dictionary in layout["props"]:
		if String(prop["type"]) == "floodlight":
			floodlights += 1
	assert_eq(int(counts.get("lamps", 0)), mini(sides + floodlights, TerrainVisual.MAX_LAMPS),
			"a glint source for every venue tower and every layout floodlight")
	assert_true(bool(counts.get("flood_map", false)), "the body is lit by the floor's own light map")


func test_every_reflected_lamp_is_a_lamp_the_venue_built() -> void:
	# Read, not copied: each tower lamp the dressing publishes stands over a tower it placed (outside the wall, high).
	var layout: Dictionary = Arena.load_layout("locks")["layout"]
	var dressing := (load(DRESSING) as PackedScene).instantiate() as Node3D
	add_to_tree(dressing)
	dressing.call("setup", layout)
	await tree.process_frame
	var venue: Dictionary = dressing.call("reflection_venue")
	var bound := float(layout.get("half_size", Match.ARENA_HALF_SIZE))
	var kind := String(layout["shape"]["kind"])
	var towers := 0
	for lamp: Array in venue["lamps"]:
		var at: Vector3 = lamp[0]
		if not ArenaShape.contains(kind, bound, Vector2(at.x, at.z), 0.0):
			towers += 1
			assert_true(at.y > float(dressing.get_script().get_script_constant_map()["WALL_HEIGHT"]) * 3.0, "a venue lamp head is high over the wall (%.1f m)" % at.y)
		else:
			assert_near(at.y, KitYard.MAST_HEIGHT, 0.01, "a layout floodlight's lamp tops KitYard's mast")
	assert_eq(towers, ArenaShape.sides(kind), "one lamp per venue tower, one tower per corner")
	for edge: Dictionary in venue["edges"]:
		var mid: Vector2 = ((edge["from"] as Vector2) + (edge["to"] as Vector2)) / 2.0
		assert_true(not ArenaShape.contains(kind, bound, mid * 1.02, 0.0) or ArenaShape.contains(kind, bound, mid * 0.98, 0.0),
				"each published edge is the wall's line (just inside it is the floor)")


func test_the_water_reflects_the_blocks_beside_it() -> void:
	var arena := await ArenaFixture.build(self, "locks")
	await tree.process_frame
	await tree.process_frame
	var visual: Node = null
	for node in arena.find_children("*", "", true, false):
		if node is TerrainVisual:
			visual = node
	assert_true(visual != null, "POSITIVE CONTROL: the Locks has its terrain visual")
	if visual == null:
		return
	var counts: Dictionary = visual.get("reflection_counts")
	assert_true(int(counts.get("boxes", 0)) >= 2, "the canal reflects the obstacles beside it (%s)" % counts)

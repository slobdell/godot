extends TestCase
## The GDScript half of the water/pit/bridge mirror (terrain, round 10). `tools/arena_terrain.py` mirrors
## `ArenaTerrain.rim_slabs()` and `rail_slabs()` so the arena report can route around water; a mirror is the thing
## this project writes lessons against (Invariant 0), so BOTH are held to one golden file,
## `tests/fixtures/terrain_golden.json` (the Python half: `tools/test_arena_terrain.py`, `make terrain-pytest`).
## If you change the rims or rails on purpose, change both and regenerate: `python3 tools/test_arena_terrain.py
## --write-golden`.

const GOLDEN := "res://tests/fixtures/terrain_golden.json"


func _sorted(boxes: Array) -> Array:
	var out := boxes.duplicate(true)
	out.sort_custom(func(a: Array, b: Array) -> bool:
		for i in a.size():
			if not is_equal_approx(float(a[i]), float(b[i])):
				return float(a[i]) < float(b[i])
		return false)
	return out


func _same(part: String, what: String, expected: Array, actual: Array) -> void:
	assert_eq(actual.size(), expected.size(), "%s of %s: %d boxes (golden %d)" % [part, what, actual.size(), expected.size()])
	if actual.size() != expected.size():
		return
	var a := _sorted(expected)
	var b := _sorted(actual)
	for i in a.size():
		for k in 4:
			assert_near(float(b[i][k]), float(a[i][k]), 0.001, "%s of %s, box %d: %s vs golden %s" % [part, what, i, b[i], a[i]])


func test_the_game_builds_the_rims_and_rails_the_report_measures() -> void:
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	assert_true(golden != null and golden.has("terrain"), "the golden file loads")
	var terrain: Array = golden["terrain"]
	var checked := 0
	for entry: Dictionary in terrain:
		var entry_name := String(entry["name"])
		if ArenaTerrain.carves(String(entry["kind"])):
			_same("rims", entry_name, golden["rims"][entry_name], ArenaTerrain.rim_slabs(entry, terrain))
			checked += 1
		elif ArenaTerrain.is_deck(String(entry["kind"])):
			_same("rails", entry_name, golden["rails"][entry_name], ArenaTerrain.rail_slabs(entry, terrain))
			checked += 1
	assert_eq(checked, terrain.size(), "every entry of the golden terrain was compared")

extends TestCase
## A layout's top-level keys (scale, round 9, at the show stream's request and the orchestrator's ruling).
##
## `Arena.validate()` used to ignore any top-level key it did not recognise, so `"shwo": {...}` loaded as a static
## arena with no complaint anywhere. That matters more than it looks: `arenas/*.json` are GENERATED, and the show
## stream's `show` key is hand-authored beside the generator and preserved across `make arenas` by an allowlist
## (`tools/make_arenas.PRESERVED_KEYS`) -- so a misspelled key would have survived every regeneration forever, as
## dead data that looks exactly like a working arena.
##
## The patch's CONTENTS stay a build-time concern (`make show-report`). `Arena` is read by `Match`, so it is on the
## simulation side, and a layout failing to LOAD because of something in `game/theme/` would invert the standing
## rule that art must never change the simulation.


func _shipped() -> Dictionary:
	var loaded := Arena.load_layout("yard")
	assert_true(not loaded.has("error"), "yard loads (%s)" % loaded.get("error", ""))
	return (loaded["layout"] as Dictionary).duplicate(true)


func test_every_key_every_shipped_layout_uses_is_allowed() -> void:
	# The direction that would break the game: a key the generator writes but `LAYOUT_KEYS` forgot would make every
	# map refuse to load. Checked across all ten rather than one.
	for name: String in Arena.layout_names():
		var loaded := Arena.load_layout(name)
		assert_true(not loaded.has("error"), "%s loads: %s" % [name, loaded.get("error", "")])
		for key: String in (loaded["layout"] as Dictionary):
			assert_true(Arena.LAYOUT_KEYS.has(key), "%s's key '%s' is in Arena.LAYOUT_KEYS" % [name, key])


func test_a_misspelled_key_is_refused_rather_than_ignored() -> void:
	var layout := _shipped()
	layout["shwo"] = {"channels": {}}
	var problem := Arena.validate(layout)
	assert_true(problem != "", "a layout with a misspelled top-level key is refused")
	assert_true(problem.contains("shwo"), "and the message names the key: %s" % problem)


func test_the_light_shows_key_is_allowed() -> void:
	# The other direction: the allowlist has to actually admit the key it was widened for, or the show stream's
	# data would be rejected at load the day it lands.
	var layout := _shipped()
	layout["show"] = {"channels": {"rim": {"programme": "breathe", "period": 24.0}}, "patch": []}
	assert_eq(Arena.validate(layout), "", "a layout carrying a `show` patch still loads")
	assert_true(Arena.LAYOUT_KEYS.has("show"), "and `show` is named in the allowlist rather than special-cased")

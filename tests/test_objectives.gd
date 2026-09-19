extends TestCase
## Squad's deciders ask Objectives where the fight's objective is. It knows only the single central zone until combat's
## N7 is on main, so it must REFUSE (an error), not answer plausibly, for a layout whose objective is anywhere else:
## a CPU competing for the wrong ground looks completely functional (lesson 77).


func test_every_shipping_layout_is_one_central_zone_today() -> void:
	var checked := 0
	for name in Arena.layout_names():
		var loaded := Arena.load_layout(name)
		assert_true(loaded.has("layout"), "setup: %s loads (%s)" % [name, loaded.get("error", "")])
		if not loaded.has("layout"):
			continue
		var layout: Dictionary = loaded["layout"]
		# Not vacuous: a layout with no objective at all would say nothing either way.
		assert_true(layout.has("control_point") or layout.has("objectives"), "setup: %s declares its objective" % name)
		assert_true(Objectives.describes_central_zone(layout), "%s: one objective, at the centre" % name)
		checked += 1
	assert_true(checked >= 5, "every shipping layout was checked (%d)" % checked)


func test_an_off_centre_or_second_objective_is_refused() -> void:
	assert_true(not Objectives.describes_central_zone({"control_point": {"position": [40, -10], "radius": 16}}),
			"an objective off the centre is not what the seam knows")
	assert_true(not Objectives.describes_central_zone({"objectives": [{"position": [0, 0]}, {"position": [50, 50]}]}),
			"nor is a pair")
	assert_true(Objectives.describes_central_zone({"control_point": {"radius": 16}}), "a radius alone is the central zone")
	assert_true(Objectives.describes_central_zone({}), "and so is a layout that says nothing")

extends TestCase
## Round 24 (stretch c): the element feed reads Element.feed_state() (a lean view built once per frame) instead of
## state(). EQUAL ANSWER: every key the feed reads holds what state() holds, and the context a crew gets is the same
## whichever the feed reads. Held here on a live element moving in formation, at several moments.

func test_the_feed_view_says_what_state_says_and_the_context_is_the_same() -> void:
	var lab := TacticsLab.create(self, 3, "yard")
	var names: Array = []
	for i in 4:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_F_%d" % (i + 1), Vector3(-20.0 + 8.0 * i, 0.0, 60.0), PI, "law_tank").name))
	await lab.start()
	var element := lab.elements.form(names, "Alpha")
	element.assign({"verb": "move", "to": [0.0, -40.0], "drills": false})
	for moment in 6:
		for tick in 45:
			await lab.step()
		var full := element.state()
		var lean := element.feed_state()
		for key: String in lean:
			assert_eq(var_to_str(lean[key]), var_to_str(full[key]), "moment %d: %s is state()'s" % [moment, key])
		for unit_name: String in names:
			for verb: String in ["", "move", "hold"]:
				ElementFeed.FEED_CACHE = false
				var before := ElementFeed.context(lab.elements, unit_name, verb)
				ElementFeed.FEED_CACHE = true
				var after := ElementFeed.context(lab.elements, unit_name, verb)
				assert_eq(var_to_str(after), var_to_str(before), "moment %d %s %s: the same context" % [moment, unit_name, verb])
	ElementFeed.FEED_CACHE = true
	lab.dispose()

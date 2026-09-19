extends TestCase
## Round 8, the lead: "not all units belong to a squad. There seem to be orphaned units that don't get selected at all
## when I cycle through the numbers on my keyboard." Faction armies field 6-10 squads; groups were seeded 1-5 only, so
## 4-17 vehicles per army were on no number key (CONTROL_GROUPS readout, laptop, round 8). Every unit gets a key.


func _squads(names_and_sizes: Array) -> Array:
	var result: Array = []
	for pair: Array in names_and_sizes:
		var roster: Array = []
		for i in int(pair[1]):
			roster.append("%s_%d" % [pair[0], i + 1])
		result.append({"name": pair[0], "roster": roster})
	return result


func _all(squads: Array) -> Array:
	var result: Array = []
	for entry: Dictionary in squads:
		result.append_array(entry["roster"])
	return result


func test_seven_squads_take_seven_keys() -> void:
	# condemned at 5200, as spawned in round 7: groups stopped at 5 and left Hunters2 and Lances (6 vehicles) keyless.
	var squads := _squads([["Guns", 5], ["Guns2", 5], ["Guns3", 5], ["Guns4", 1], ["Hunters", 5], ["Hunters2", 1], ["Lances", 5]])
	var groups := ControlGroups.plan(squads)
	assert_eq(groups.size(), 7, "one number key per squad, up to nine")
	assert_eq(groups[6]["name"], "Lances", "the seventh squad is on 7")


func test_past_nine_squads_every_unit_still_has_a_key() -> void:
	var squads := _squads([["Guns", 5], ["Guns2", 5], ["Guns3", 3], ["Hunters", 5], ["Hunters2", 5], ["Hunters3", 4],
			["Spears", 5], ["Spears2", 1], ["Wrenches", 5], ["Wrenches2", 2], ["Guns4", 2], ["Odd", 1]])
	var groups := ControlGroups.plan(squads)
	assert_eq(groups.size(), ControlGroups.COUNT, "nine keys, no more")
	var held: Array = []
	for group: Dictionary in groups:
		held.append_array(group["roster"])
	held.sort()
	var every := _all(squads)
	every.sort()
	assert_eq(held, every, "every unit is on exactly one key, none dropped")
	assert_true((groups[0]["roster"] as Array).has("Guns4_1"), "a tenth squad joins its own family (Guns4 -> Guns)")
	assert_true((groups[8]["roster"] as Array).has("Odd_1"), "and one with no family joins the last key")


func test_the_family_of_a_numbered_squad() -> void:
	assert_eq(ControlGroups.family("Guns4"), "Guns", "a numbered squad belongs to its family")
	assert_eq(ControlGroups.family("Hunters"), "Hunters", "an unnumbered one is its own family")
	assert_eq(ControlGroups.family("Eyes II"), "Eyes II", "squad's split squads keep their own name")


extends TestCase
## Round 18 (picker): the Formation button becomes a picker he can see. P1: one formation list and one card for the
## play view, the tactical map and G (FormationCatalog).


func test_every_formation_a_player_can_name_has_a_card() -> void:
	for id: String in Formations.NAMES:
		assert_true(FormationCatalog.ORDER.has(id), "%s (in the geometry a player can name) is in the picker" % id)
	for id: String in FormationCatalog.shapes():
		assert_true(TacticsFormation.NAMES.has(id), "%s has real geometry" % id)
		assert_true(Formations.NAMES.has(id), "%s is a shape a player can order" % id)
	for id: String in FormationCatalog.ORDER:
		var card := FormationCatalog.card(id)
		assert_eq(card.get("id", ""), id, "%s has a card" % id)
		assert_true(String(card["name"]) != "" and String(card["tagline"]) != "", "%s: a name and a tagline" % id)
		assert_true(String(card["line"]).length() > 20, "%s: a one-line description that says something" % id)
	assert_eq(FormationCatalog.ORDER[0], UnitCommand.AUTO, "AUTO is the first card")
	assert_eq(FormationCatalog.ORDER.size(), Formations.NAMES.size() + 1, "every shape once, plus AUTO")


func test_the_two_pickers_list_the_same_set_and_g_cycles_a_subset_in_order() -> void:
	assert_eq(TacticalMap.PICKER_FORMATIONS, FormationCatalog.shapes(), "the tactical map's picker is the same list")
	assert_eq(RtsControls.FORMATION_CYCLE, FormationCatalog.CYCLE, "G cycles the catalog's cycle")
	var last := -1
	for id: String in FormationCatalog.CYCLE:
		var at := FormationCatalog.ORDER.find(id)
		assert_true(at > last, "%s is in the list, after the cycle's previous step" % id)
		last = at
	for id: String in Formations.NAMES:
		assert_eq(CommandIcons.FORMATION_INFO.get(id), FormationCatalog.INFO[id], "%s: one description, not two" % id)


func test_g_from_a_shape_outside_the_cycle_goes_on_round() -> void:
	assert_eq(FormationCatalog.next_in_cycle(UnitCommand.AUTO), "wedge", "AUTO then wedge")
	assert_eq(FormationCatalog.next_in_cycle("vee"), UnitCommand.AUTO, "the last step wraps to AUTO")
	assert_eq(FormationCatalog.next_in_cycle("coil"), UnitCommand.AUTO, "coil (panel only) steps on round to AUTO")
	assert_eq(FormationCatalog.next_in_cycle("echelon_left"), UnitCommand.AUTO, "so does an echelon")
	assert_eq(FormationCatalog.next_in_cycle("nonsense"), UnitCommand.AUTO, "an unknown id goes back to AUTO")

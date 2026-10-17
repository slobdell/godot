extends TestCase
## Round 33 (R33.5/R33.6, brains): a CPU squad past Formations.MAX_MEMBERS gets elements. A showmatch's Green side is
## folded like a player's army (SquadConsolidation.for_player splits only past 8), so it fields squads of 6-8; Elements.form
## refuses each (C19.1), and they fought unseated while the commander re-tried every think (traffic's X1 census, builder0:
## ~470 ERRORs a fight). Now `form_squad` deals one into ceil(n / 5) elements, as his own side deals a big group
## (SelectionSquads.deal), and the commander seats any living crew of its squads left outside an element. The runner fails
## a test on any engine ERROR, so every test here also says "no refusal logged".

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _units(unit_id: String, count: int) -> Array:
	var units: Array = []
	for i in count:
		units.append({"unit": unit_id})
	return units


## A showmatch-shaped CPU side: a squad of 6, one of 8 and one of 3.
func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var army := {"name": "Folded", "squads": [{"name": "Guns", "units": _units("tank", 6)},
			{"name": "Hunters", "units": _units("ifv", 8)}, {"name": "Eyes", "units": _units("scout", 3)}]}
	assert_eq(game_match.load_doctrine(Match.Team.RUST, army), "", "setup: the army loads")
	return game_match


func _sizes(made: Array) -> Array:
	var sizes: Array = []
	for element: Element in made:
		sizes.append(element.roster.size())
	return sizes


func test_a_squad_past_five_is_dealt_into_even_elements() -> void:
	var game_match := _setup()
	var elements := Elements.install(game_match)
	await wait_physics_frames(2)
	var by_name := {}
	for squad: Squad in game_match.team_squads(Match.Team.RUST):
		by_name[String(squad.squad_name)] = elements.form_squad(Array(squad.roster), String(squad.squad_name))
	assert_eq(_sizes(by_name["Guns"]), [3, 3], "6 -> two elements of 3")
	assert_eq(_sizes(by_name["Hunters"]), [4, 4], "8 -> two elements of 4")
	assert_eq(_sizes(by_name["Eyes"]), [3], "3 -> one element, as `form`")
	assert_eq((by_name["Guns"][0] as Element).element_name, "Guns", "the first piece keeps the squad's name")
	assert_eq((by_name["Guns"][1] as Element).element_name, "Guns II", "the second is numbered")
	for squad: Squad in game_match.team_squads(Match.Team.RUST):
		for unit_name in squad.roster:
			assert_true(elements.of(String(unit_name)) != null, "%s is seated" % unit_name)


func test_the_commander_seats_a_big_squad_formed_whole_and_refused() -> void:
	var game_match := _setup()
	var elements := Elements.install(game_match)
	await wait_physics_frames(2)
	# The skirmish forms the small squad (as it would every squad that fits) before the commander starts.
	var eyes: Squad = null
	for squad: Squad in game_match.team_squads(Match.Team.RUST):
		if String(squad.squad_name) == "Eyes":
			eyes = squad
	elements.form_squad(Array(eyes.roster), "Eyes")
	ElementCommander.install(game_match, Match.Team.RUST, elements)
	await wait_physics_frames(ElementCommander.THINK_TICKS + 2)
	var unseated: Array = []
	for squad: Squad in game_match.team_squads(Match.Team.RUST):
		for unit_name in squad.roster:
			if elements.of(String(unit_name)) == null:
				unseated.append(unit_name)
	assert_eq(unseated, [], "every crew of every squad is in an element after the first think")
	assert_eq(elements.of_team(Match.Team.RUST).size(), 5, "Eyes + Guns x2 + Hunters x2")


## A respawn match: a crew that died was pruned from its element and comes back alive in no element. The commander seats
## it on its next think, alone, under its squad's name; the squad's living element keeps the rest (R33.6, kept as built:
## rejoining the living element is a round 34 candidate). Simulated by taking a living crew out of its element, which is
## the state the prune and the respawn leave.
func test_a_crew_back_from_a_respawn_gets_its_own_element() -> void:
	var game_match := _setup()
	var elements := Elements.install(game_match)
	await wait_physics_frames(2)
	ElementCommander.install(game_match, Match.Team.RUST, elements)
	await wait_physics_frames(ElementCommander.THINK_TICKS + 2)
	var eyes: Element = null
	for element: Element in elements.of_team(Match.Team.RUST):
		if element.element_name == "Eyes":
			eyes = element
	assert_true(eyes != null and eyes.members().size() == 3, "setup: Eyes is one element of 3")
	var back := String(eyes.members()[2])
	eyes.remove(back)
	assert_true(elements.of(back) == null, "setup: %s stands in no element" % back)
	await wait_physics_frames(ElementCommander.THINK_TICKS + 2)
	var seated := elements.of(back)
	assert_true(seated != null, "%s is seated again on the next think" % back)
	assert_true(seated != eyes, "in its own element, not Eyes'")
	assert_eq(seated.members().size(), 1, "alone")
	assert_eq(seated.element_name, "Eyes", "under its squad's name")
	assert_eq(eyes.members().size(), 2, "Eyes keeps the other two")

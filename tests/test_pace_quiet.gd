extends TestCase
## Round 25 (pace P1/P2, C24.7): the smarter quiet. A crew round 24 called quiet (in reach, not in the shooting) is
## quiet by ThinkQuiet only when nothing a fast decision would change is going on: no fresh order, not fighting from or
## going for cover, not giving way, no fast contact about (chasing or chased), not near water or a bridge deck.
## Simulation state only: the crew's own order, choice and movement, the team's contacts, the arena's terrain.


func _brain_in_reach() -> Array:
	var lab := TacticsLab.create(self, 1, "yard")
	var mine := lab.unit(Match.Team.GREEN, "Green_L_1", Vector3(0, 0, 30), PI, "law_tank")
	var enemy := lab.gun(Match.Team.RUST, "Rust_L_1", Vector3(0, 0, -10), 0.0, "law_tank")
	await lab.start()
	for tick in 20:
		await lab.step()  # the intel has the enemy in reach
	var brain := lab.game_match.brains.get_node(NodePath("Brain_" + String(mine.name))) as TankBrain
	return [lab, brain, mine, enemy]


func test_a_quiet_crew_and_each_reason_it_is_not() -> void:
	var parts: Array = await _brain_in_reach()
	var lab: TacticsLab = parts[0]
	var brain: TankBrain = parts[1]
	brain._order_dirty = false
	brain._element_dirty = false
	brain.order = {}
	brain.choice = {"option": "ENGAGE", "target": "Rust_L_1"}
	assert_eq(ThinkQuiet.why_not(brain), "", "a parked crew on a dry map, a parked enemy, no order: quiet")
	brain.choice = {"option": "COVER_FIRE", "target": "Rust_L_1"}
	assert_eq(ThinkQuiet.why_not(brain), "cover", "fighting from cover: not quiet")
	brain.choice = {"option": "TAKE_COVER", "target": ""}
	assert_eq(ThinkQuiet.why_not(brain), "cover", "going for cover: not quiet")
	brain.choice = {"option": "ENGAGE", "target": "Rust_L_1"}
	brain.order = {"verb": "move", "issued_tick": lab.game_match.tick - 5}
	assert_eq(ThinkQuiet.why_not(brain), "order", "a fresh order: not quiet")
	brain.order = {"verb": "move", "issued_tick": lab.game_match.tick - ThinkQuiet.FRESH_ORDER_TICKS}
	assert_eq(ThinkQuiet.why_not(brain), "", "an order 2 s old: quiet again")
	brain.order = {}
	brain._element_dirty = true
	assert_eq(ThinkQuiet.why_not(brain), "order", "an element call waiting: not quiet")
	brain._element_dirty = false
	brain.movement.yield_to = "Green_X"
	assert_eq(ThinkQuiet.why_not(brain), "giveway", "giving way to a friend: not quiet")
	brain.movement.yield_to = ""
	assert_eq(ThinkQuiet.why_not(brain), "", "and quiet once it is done")
	lab.dispose()


func test_a_fast_contact_makes_the_chaser_and_the_chased_not_quiet() -> void:
	var parts: Array = await _brain_in_reach()
	var lab: TacticsLab = parts[0]
	var brain: TankBrain = parts[1]
	brain.order = {}
	brain.choice = {"option": "ENGAGE", "target": "Rust_L_1"}
	var contacts: Dictionary = AiTickCache.contact_prototypes(lab.game_match, Match.Team.GREEN)
	assert_true(contacts.size() > 0, "the team knows the enemy")
	for known: Dictionary in contacts.values():
		known["velocity"] = Vector3(ThinkQuiet.FAST_MS + 1.0, 0, 0)
	assert_eq(ThinkQuiet.why_not(brain), "fast", "an enemy at 9 m/s about: not quiet")
	for known: Dictionary in contacts.values():
		known["velocity"] = Vector3(ThinkQuiet.FAST_MS - 1.0, 0, 0)
	assert_eq(ThinkQuiet.why_not(brain), "", "at 7 m/s: quiet")
	lab.dispose()


func test_near_water_is_the_carved_terrain_and_decks_grown_by_water_m() -> void:
	var data := {"terrain": [{"kind": "water", "rect": [0.0, 0.0, 20.0, 52.0]},
			{"kind": "bridge", "rect": [100.0, 0.0, 14.0, 34.0]}]}
	var water := ArenaTerrain.bounds(data["terrain"][0])
	var deck := ArenaTerrain.bounds(data["terrain"][1])
	var mid_z := (water[1] + water[3]) * 0.5
	assert_true(ThinkQuiet.near_water(Vector3((water[0] + water[2]) * 0.5, 0, mid_z), data), "on the water")
	assert_true(ThinkQuiet.near_water(Vector3(water[2] + ThinkQuiet.WATER_M - 1.0, 0, mid_z), data), "19 m off its edge")
	assert_true(not ThinkQuiet.near_water(Vector3(water[2] + ThinkQuiet.WATER_M + 1.0, 0, mid_z), data), "21 m off its edge")
	assert_true(ThinkQuiet.near_water(Vector3(deck[0] - 5.0, 0, (deck[1] + deck[3]) * 0.5), data), "at a bridge's mouth")
	assert_true(not ThinkQuiet.near_water(Vector3.ZERO, {"terrain": []}), "a dry map: never")
	assert_true(not ThinkQuiet.near_water(Vector3.ZERO, {}), "no terrain at all: never")

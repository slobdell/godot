extends TestCase
## Round 25 (pace P1/P2, C24.7): the smarter quiet. A crew round 24 called quiet (in reach, not in the shooting) is
## quiet by ThinkQuiet only when nothing a fast decision would change is going on: no fresh order, not fighting from or
## going for cover, not giving way, no fast contact about (chasing or chased), not near water or a bridge deck.
## Simulation state only: the crew's own order, choice and movement, the team's contacts, the arena's terrain.


func teardown() -> void:
	TankBrain.SMART_QUIET_HZ = TankBrain.PACE_SMART_HZ
	ThinkQuiet.ORDER_GUARD = ""
	super.teardown()


func test_the_order_guard_is_off_and_so_is_the_knob_until_it_ships() -> void:
	assert_eq(ThinkQuiet.ORDER_GUARD, "", "no order guard (pre-registered: every order change already wakes the crew)")
	assert_near(TankBrain.SMART_QUIET_HZ, TankBrain.PACE_SMART_HZ, 0.001, "the smarter quiet's rate is the shipped constant")


func test_the_smarter_quiet_slows_only_a_quiet_crew_with_nothing_to_watch() -> void:
	var parts: Array = await _brain_in_reach()
	var lab: TacticsLab = parts[0]
	var brain: TankBrain = parts[1]
	var tank: Tank = parts[2]
	var fight_hz := brain._contact_think_hz(BrainVariants.for_team(tank.team))
	brain.ticks_since_fire = 1000
	tank.ticks_since_hit = 1000
	brain._incoming_count = 0
	brain.order = {}
	brain.choice = {"option": "ENGAGE", "target": "Rust_L_1"}
	TankBrain.SMART_QUIET_HZ = 0.0
	assert_near(brain._think_rate(), fight_hz, 0.001, "knob off: the fight rate")
	TankBrain.SMART_QUIET_HZ = 2.0
	assert_near(brain._think_rate(), 2.0, 0.001, "in reach, quiet, nothing to watch: 2 Hz")
	assert_eq(brain._lod, "fight_quiet", "counted as quiet")
	brain.choice = {"option": "COVER_FIRE", "target": "Rust_L_1"}
	assert_near(brain._think_rate(), fight_hz, 0.001, "fighting from cover: the fight rate")
	brain.choice = {"option": "ENGAGE", "target": "Rust_L_1"}
	brain.ticks_since_fire = 0
	assert_near(brain._think_rate(), fight_hz, 0.001, "it fires: the fight rate")
	brain.ticks_since_fire = 1000
	tank.ticks_since_hit = 0
	assert_near(brain._think_rate(), fight_hz, 0.001, "it is hit: the fight rate")
	lab.dispose()


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
	brain.order = {"verb": "move", "issued_tick": lab.game_match.tick}
	assert_eq(ThinkQuiet.why_not(brain), "", "the shipped rule has no order guard: a new order wakes the crew, it is not a reason")
	brain.order = {}
	_age(brain, lab)
	# The guards themselves (census arms; `--quiet-guard=`):
	ThinkQuiet.ORDER_GUARD = "intent"
	brain.choice = {"option": "COVER_FIRE", "target": "Rust_L_1"}
	assert_eq(ThinkQuiet.why_not(brain), "cover", "fighting from cover: not quiet")
	brain.choice = {"option": "TAKE_COVER", "target": ""}
	assert_eq(ThinkQuiet.why_not(brain), "cover", "going for cover: not quiet")
	brain.choice = {"option": "ENGAGE", "target": "Rust_L_1"}
	brain.order = {"verb": "move", "issued_tick": lab.game_match.tick}
	assert_eq(ThinkQuiet.why_not(brain), "intent", "a new order (move after none): not quiet")
	# 2 s on (the record's change tick moved back rather than stepping a brain holding a hand-made order):
	_age(brain, lab)
	brain.order = {"verb": "move", "issued_tick": lab.game_match.tick}
	assert_eq(ThinkQuiet.why_not(brain), "", "the same move re-issued 2 s later (an element re-plan): quiet")
	brain.order = {"verb": "attack_move", "issued_tick": lab.game_match.tick}
	assert_eq(ThinkQuiet.why_not(brain), "", "move to attack-move on the same leg (an element's flip): the same intent, quiet")
	assert_true(Array(ThinkQuiet.reasons_for(brain)).has("order"), "...though the verb guard would call it fresh")
	brain.order = {"verb": "attack_move", "goal": Vector3(0, 0, -40), "issued_tick": lab.game_match.tick}
	assert_eq(ThinkQuiet.why_not(brain), "intent", "a destination given: a new intent")
	_age(brain, lab)
	brain.order = {"verb": "attack_move", "goal": Vector3(0, 0, -40 - ThinkQuiet.INTENT_MOVED_M + 1.0)}
	assert_eq(ThinkQuiet.why_not(brain), "", "the destination slid 24 m (a travelling slot): the same intent")
	brain.order = {"verb": "attack_move", "goal": Vector3(0, 0, -40 - ThinkQuiet.INTENT_MOVED_M - 1.0)}
	assert_eq(ThinkQuiet.why_not(brain), "intent", "moved 26 m from where it was given: a new destination")
	_age(brain, lab)
	brain.order = {}
	assert_eq(ThinkQuiet.why_not(brain), "intent", "an order cleared is a change too")
	_age(brain, lab)
	brain._element_dirty = true
	assert_eq(ThinkQuiet.why_not(brain), "intent", "an element call waiting: not quiet")
	brain._element_dirty = false
	brain.movement.yield_to = "Green_X"
	assert_eq(ThinkQuiet.why_not(brain), "giveway", "giving way to a friend: not quiet")
	brain.movement.yield_to = ""
	assert_eq(ThinkQuiet.why_not(brain), "", "and quiet once it is done")
	lab.dispose()


func test_a_target_running_away_is_a_chase_and_a_closing_enemy_is_not() -> void:
	var parts: Array = await _brain_in_reach()
	var lab: TacticsLab = parts[0]
	var brain: TankBrain = parts[1]
	var mine: Tank = parts[2]
	brain.order = {}
	brain._order_dirty = false
	brain._element_dirty = false
	brain.choice = {"option": "ENGAGE", "target": "Rust_L_1"}
	mine.estimated_velocity = Vector3.ZERO
	var contacts: Dictionary = AiTickCache.contact_prototypes(lab.game_match, Match.Team.GREEN)
	assert_true(contacts.has("Rust_L_1"), "the team knows the enemy (40 m north of the crew)")
	var known: Dictionary = contacts["Rust_L_1"]
	known["velocity"] = Vector3(0, 0, -(ThinkQuiet.FAST_MS + 1.0))
	assert_eq(ThinkQuiet.why_not(brain), "fast", "its target driving away faster than FAST_MS: a chase, not quiet")
	known["velocity"] = Vector3(0, 0, -(ThinkQuiet.FAST_MS - 1.0))
	assert_eq(ThinkQuiet.why_not(brain), "", "slower than FAST_MS: quiet")
	known["velocity"] = Vector3(0, 0, 15.0)
	assert_eq(ThinkQuiet.why_not(brain), "", "closing at 15 m/s: the opening clash, quiet")
	known["velocity"] = Vector3(0, 0, -(ThinkQuiet.FAST_MS + 1.0))
	brain.choice = {"option": "ENGAGE", "target": ""}
	assert_eq(ThinkQuiet.why_not(brain), "", "a contact running that is not its target: quiet")
	brain.order = {"verb": "attack", "target": "Rust_L_1"}
	assert_eq(ThinkQuiet.why_not(brain), "fast", "an attack order on it while it runs: a chase")
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


## The record's change ticks moved back 2 s, rather than stepping a brain that holds a hand-made order.
func _age(brain: TankBrain, lab: TacticsLab) -> void:
	var record := ThinkQuiet._order_record(brain)
	record[3] = lab.game_match.tick - ThinkQuiet.FRESH_ORDER_TICKS
	record[4] = lab.game_match.tick - ThinkQuiet.FRESH_ORDER_TICKS

extends TestCase
## Round-3 X5: CpuCommander policy v3 plans the whole army by squad role, in visible shapes (a scout V, a flanking wedge).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup() -> Array:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var army := {"name": "CPU", "squads": [
		{"name": "Guns", "units": [{"unit": "tank"}, {"unit": "tank"}, {"unit": "tank"}]},
		{"name": "Hunters", "units": [{"unit": "ifv"}, {"unit": "ifv"}]},
		{"name": "Scouts", "units": [{"unit": "scout"}, {"unit": "scout"}, {"unit": "scout"}]},
		{"name": "Battery", "units": [{"unit": "artillery"}]}]}
	assert_eq(game_match.load_doctrine(Match.Team.RUST, army), "", "setup: CPU army")
	var commander := CpuCommander.new()
	commander.game_match = game_match
	commander.team = Match.Team.RUST
	commander.policy = "v3"
	add_to_tree(commander)
	await wait_physics_frames(2)
	return [game_match, commander]


func _spot(game_match: Match, count: int, at: Vector3, unit := "tank") -> void:
	for i in count:
		game_match.intel[Match.Team.RUST]["Green_%s_%d" % [unit, i]] = {"position": at + Vector3(i * 6, 0, 0), "velocity": Vector3.ZERO,
				"forward": Vector3.FORWARD, "turret_forward": Vector3.FORWARD, "health": 300, "shield": 150, "weapon": "cannon",
				"unit": unit, "role": Units.role_of(unit), "visible": true, "seen_tick": game_match.tick}


func test_squads_are_classed_by_role() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var by_name := game_match.tanks_by_name()
	assert_eq(CpuCommander.squad_class(game_match.squads["1/Guns"], by_name), "line", "tanks hold the line")
	assert_eq(CpuCommander.squad_class(game_match.squads["1/Hunters"], by_name), "line", "IFVs too")
	assert_eq(CpuCommander.squad_class(game_match.squads["1/Scouts"], by_name), "fast", "scouts are fast")
	assert_eq(CpuCommander.squad_class(game_match.squads["1/Battery"], by_name), "support", "artillery supports")


func test_with_nothing_known_it_musters_in_formation() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var commander: CpuCommander = setup[1]
	var plans := commander.plan_team(game_match.tanks_by_name())
	assert_eq(commander.phase, "muster", "nothing known at the start: gather first")
	assert_eq(plans["Guns"]["formation"], "wedge", "the line musters in a wedge")
	assert_eq(plans["Scouts"]["formation"], "vee", "scouts in a V")
	assert_eq(plans["Battery"]["formation"], "column", "support in a column")
	var rally := Match.spawn_position(Match.Team.RUST, 0) + (Match.team_frame(Match.Team.RUST)["forward"] as Vector3) * CpuCommander.RALLY_AHEAD
	assert_near(Vector2(float(plans["Guns"]["to"][0]), float(plans["Guns"]["to"][1])).distance_to(Vector2(rally.x, rally.z)), 0.0, 1.0,
			"at the rally point ahead of base")


func test_on_contact_the_main_line_assaults_and_the_rest_flank_and_charge() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var commander: CpuCommander = setup[1]
	_spot(game_match, 2, Vector3(-10, 0, 10))
	_spot(game_match, 1, Vector3(30, 0, -5), "artillery")
	var by_name := game_match.tanks_by_name()
	var plans := commander.plan_team(by_name)
	assert_eq(commander.phase, "engage", "fresh contacts: engage")
	assert_eq(plans["Guns"]["verb"], "assault", "the strongest line squad assaults")
	assert_eq(plans["Hunters"]["verb"], "move", "the next line squad swings out first")
	assert_eq(plans["Hunters"]["formation"], "wedge", "...in a wedge")
	var guns_at := CpuCommander._center(game_match.squads["1/Guns"], by_name)
	var enemy := (Vector3(-10, 0, 10) + Vector3(-4, 0, 10) + Vector3(30, 0, -5)) / 3.0  # the three contacts' center
	var flank := Vector3(float(plans["Hunters"]["to"][0]), 0, float(plans["Hunters"]["to"][1]))
	var axis := (enemy - guns_at).normalized()
	var off_axis := absf((flank - enemy).dot(Vector3(-axis.z, 0, axis.x)))
	assert_true(off_axis >= CpuCommander.FLANK_OFFSET - 5.0, "the flank point is well off the main line's axis (%.0f m)" % off_axis)
	assert_eq(plans["Scouts"]["formation"], "vee", "the scouts charge in a V...")
	assert_near(float(plans["Scouts"]["to"][0]), 30.0, 1.0, "...at the enemy artillery")
	assert_eq(plans["Battery"]["verb"], "move", "support trails the line")


func test_clearly_outmatched_it_withdraws_and_a_worn_squad_rests() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var commander: CpuCommander = setup[1]
	_spot(game_match, 12, Vector3(-60, 0, 30))
	var plans := commander.plan_team(game_match.tanks_by_name())
	assert_eq(commander.phase, "withdraw", "twelve tanks far off: fall back")
	assert_eq(plans["Guns"]["verb"], "break_contact", "the line breaks contact")
	game_match.intel[Match.Team.RUST].clear()
	_spot(game_match, 1, Vector3(-10, 0, 10))
	var by_name := game_match.tanks_by_name()
	for member in game_match.squads["1/Hunters"].roster:
		var tank := by_name[member] as Tank
		tank.health = 40
		tank.shield = 0.0
	plans = commander.plan_team(by_name)
	assert_eq(commander.phase, "engage", "back in the fight")
	assert_eq(plans["Hunters"]["verb"], "break_contact", "the worn IFVs pull back to recover")
	assert_eq(plans["Guns"]["verb"], "assault", "the healthy line keeps fighting")

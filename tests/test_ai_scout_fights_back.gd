extends TestCase
## Round 34 (brains B1, C34.5; try 1 was R33.31): A SCOUT UNDER FIRE STANDS AND TRADES WHEN IT CAN WIN, AND LEAVES WHEN
## IT CAN'T (his C33.9 scout report; his "go with both of your recommendations", 2026-10-18). Rule
## (TankBrain.scout_fights_back): hit within SCOUT_FIGHT_HIT_TICKS, by a visible non-prey contact that can shoot it now
## (threatens_me), that it wins the duel against (advantage >= 1) and that stays inside its own effective range now and
## each second up to SCOUT_FIGHT_REACH_S ahead: SPOT drops to SCOUT_FIGHT_SPOT (0.15), so ENGAGE wins. Otherwise SPOT
## keeps its 0.88 and the scout opens distance. Try 1 also fought anything it couldn't outrun; that sent it into duels it
## lost (R33.31), so that clause is gone. `--scout-fight=off` (or env SCOUT_FIGHT=off) is main's rule.


func teardown() -> void:
	TankBrain.SCOUT_FIGHT_BACK = true
	super.teardown()


## A law_scout at the origin moving at `my_velocity`, hit `since_hit` ticks ago, and one contact `metres` north of it
## moving at `velocity`.
func _case(since_hit: int, unit := "syn_scout", metres := 15.0, threatens := true, visible := true,
		velocity := Vector3.ZERO, my_velocity := Vector3.ZERO) -> Array:
	var me := {"unit": "law_scout", "position": Vector3.ZERO, "since_hit": since_hit, "velocity": my_velocity,
			"weapon": Weapons.profile(String(Units.stat("law_scout", "weapon", "")))}
	var contacts := [{"name": "Rust_1", "unit": unit, "position": Vector3(0, 0, -metres), "visible": visible,
			"threatens_me": threatens, "role": Units.role_of(unit), "velocity": velocity}]
	return [me, contacts]


func _reach() -> float:
	var w := Weapons.profile(String(Units.stat("law_scout", "weapon", "")))
	return float(w.get("effective_range", w.get("range", 0.0)))


func test_setup_the_contact_sits_inside_the_scouts_reach() -> void:
	assert_true(_reach() > 15.0, "setup: law_scout's reach %.1f m is past the 15 m contact" % _reach())


func test_it_stands_and_trades_a_duel_it_wins_that_stays_in_reach() -> void:
	var c := _case(10)
	assert_true(TankBrain.scout_fights_back(c[0], c[1], {"Rust_1": {"advantage": 1.0}}), "even duel, in reach: fight")
	assert_true(TankBrain.scout_fights_back(c[0], c[1], {"Rust_1": {"advantage": 2.5}}), "winning duel, in reach: fight")


func test_outgunned_it_leaves_even_when_it_cannot_outrun_the_shooter() -> void:
	var c := _case(10)
	assert_true(float(Units.stat("syn_scout", "max_forward_speed")) >= 0.9 * float(Units.stat("law_scout", "max_forward_speed")),
			"setup: the syn scout is not slower than the law scout (try 1 fought this one)")
	assert_true(not TankBrain.scout_fights_back(c[0], c[1], {"Rust_1": {"advantage": 0.99}}), "losing duel: SPOT")
	var slow := _case(10, "law_tank")
	assert_true(not TankBrain.scout_fights_back(slow[0], slow[1], {"Rust_1": {"advantage": 0.4}}), "losing duel v a tank: SPOT")


func test_a_winning_duel_that_leaves_its_reach_within_two_seconds_is_not_taken() -> void:
	# R33.31: reach was judged at the tick, and an orbiter swinging through it pulled the scout into ENGAGE.
	var reach := _reach()
	var away := _case(10, "syn_scout", reach - 2.0, true, true, Vector3(0, 0, -3.0))
	assert_true(not TankBrain.scout_fights_back(away[0], away[1], {"Rust_1": {"advantage": 1.5}}), "leaves reach in 1 s")
	var later := _case(10, "syn_scout", reach - 5.0, true, true, Vector3(0, 0, -3.0))
	assert_true(not TankBrain.scout_fights_back(later[0], later[1], {"Rust_1": {"advantage": 1.5}}), "leaves reach in 2 s")
	var stays := _case(10, "syn_scout", reach - 7.0, true, true, Vector3(0, 0, -3.0), Vector3(0, 0, -3.0))
	assert_true(TankBrain.scout_fights_back(stays[0], stays[1], {"Rust_1": {"advantage": 1.5}}),
			"the scout keeping pace keeps it in reach: fight")
	var coming := _case(10, "syn_scout", reach + 3.0, true, true, Vector3(0, 0, 5.0))
	assert_true(not TankBrain.scout_fights_back(coming[0], coming[1], {"Rust_1": {"advantage": 1.5}}),
			"not in reach yet: SPOT")


func test_no_matchup_entry_is_not_a_won_duel() -> void:
	var c := _case(10)
	assert_true(not TankBrain.scout_fights_back(c[0], c[1], {}), "unknown duel: SPOT")


func test_not_hit_lately_it_keeps_its_distance() -> void:
	var c := _case(TankBrain.SCOUT_FIGHT_HIT_TICKS + 1)
	assert_true(not TankBrain.scout_fights_back(c[0], c[1], {"Rust_1": {"advantage": 2.0}}), "not under fire: SPOT")


func test_a_shooter_out_of_its_own_reach_or_out_of_sight_does_not_count() -> void:
	var far := _case(10, "syn_scout", 500.0)
	assert_true(not TankBrain.scout_fights_back(far[0], far[1], {"Rust_1": {"advantage": 2.0}}), "beyond its own range")
	var unseen := _case(10, "syn_scout", 15.0, true, false)
	assert_true(not TankBrain.scout_fights_back(unseen[0], unseen[1], {"Rust_1": {"advantage": 2.0}}), "not visible")
	var safe := _case(10, "syn_scout", 15.0, false)
	assert_true(not TankBrain.scout_fights_back(safe[0], safe[1], {"Rust_1": {"advantage": 2.0}}), "it can't shoot me")


func test_the_switch_off_is_mains_rule() -> void:
	TankBrain.SCOUT_FIGHT_BACK = false
	var c := _case(10)
	assert_true(not TankBrain.scout_fights_back(c[0], c[1], {"Rust_1": {"advantage": 2.0}}), "--scout-fight=off: SPOT")


## The rule inside decide, under the CHAMPION's features. The champion runs without matchups (an empty table), so the
## duel the rule needs is computed for a scout under fire alone (tuning, lab/brains-scout2: with the table empty the rule
## never fired, ENGAGE 0 in 144 runs).
func _decide_case(since_hit: int, enemy_unit: String, health_share: float) -> String:
	var unit := "law_scout"
	var enemy := {"name": "Rust_S_1", "unit": enemy_unit, "position": Vector3(0, 0, -15), "velocity": Vector3.ZERO,
			"forward": Vector3.BACK, "health": float(Units.stat(enemy_unit, "max_health")) * health_share,
			"weapon": String(Units.stat(enemy_unit, "weapon")), "visible": true, "age": 0, "exposed_face": "front",
			"facing_ally": false, "aiming_at_me": true, "threatens_me": true, "role": Units.role_of(enemy_unit)}
	var situation := {
		"tick": 1000,
		"self": {"name": "Green_A_1", "team": 0, "position": Vector3.ZERO, "forward": Vector3.FORWARD, "unit": unit,
				"class": "scout", "health": Units.stat(unit, "max_health"), "max_health": Units.stat(unit, "max_health"),
				"weapon": Weapons.profile(String(Units.stat(unit, "weapon"))), "since_hit": since_hit,
				"velocity": Vector3.ZERO},
		"directives": Directives.resolve([]), "contacts": [enemy], "allies": [], "objective": null,
		"objective_radius": 0.0, "squad_center": null, "cover": [], "rally": Vector3(0, 0, 42),
		"enemy_base": Vector3(0, 0, -42), "memory_ticks": Match.CONTACT_MEMORY_TICKS,
		"features": (BrainVariants.PROFILES[BrainVariants.CHAMPION] as Dictionary).duplicate(),
	}
	return String(TankBrain.decide(situation, {})["choice"]["option"])


func test_under_the_champion_a_scout_in_a_won_duel_stands_and_one_outgunned_spots() -> void:
	assert_true(not bool((BrainVariants.PROFILES[BrainVariants.CHAMPION] as Dictionary).get("matchups", true)),
			"setup: the champion runs without matchups")
	var weak := 0.1
	var duel := TankBrain.matchups_for({"self": {"unit": "law_scout", "position": Vector3.ZERO, "forward": Vector3.FORWARD,
			"health": Units.stat("law_scout", "max_health"), "weapon": Weapons.profile(String(Units.stat("law_scout", "weapon")))},
			"contacts": [{"name": "R", "unit": "gang_scout", "position": Vector3(0, 0, -15), "velocity": Vector3.ZERO,
			"forward": Vector3.BACK, "health": float(Units.stat("gang_scout", "max_health")) * weak, "age": 0,
			"exposed_face": "front", "weapon": String(Units.stat("gang_scout", "weapon"))}], "features": {}})
	assert_true(float(duel["R"]["advantage"]) >= 1.0, "setup: a crippled gang scout is a won duel (%s)" % duel["R"]["advantage"])
	assert_true(_decide_case(10, "gang_scout", weak) != "SPOT", "won duel, under fire: it stands and trades")
	assert_eq(_decide_case(TankBrain.SCOUT_FIGHT_HIT_TICKS + 1, "gang_scout", weak), "SPOT", "not under fire: it spots")
	TankBrain.SCOUT_FIGHT_BACK = false
	assert_eq(_decide_case(10, "gang_scout", weak), "SPOT", "--scout-fight=off: main's SPOT")

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

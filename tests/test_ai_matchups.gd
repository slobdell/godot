extends TestCase
## Matchups: mechanics-based damage estimates (game/ai/matchups.gd). Pure; profiles are hand-built in the shape of
## rules' catalog v2 (stream/rules R1/R2 numbers, 2026-09-15), so these tests don't depend on which catalog main has.

const SCOUT := {"role": "scout", "mount": "fixed", "hull_turn_rate_deg": 140.0, "turret_turn_rate_deg": 200.0, "fire_arc_deg": 16.0,
		"armor": {"front": 2.0, "side": 1.0, "rear": 1.0}, "good_vs": ["artillery", "lancer"], "weak_vs": ["ifv"]}
const TANK := {"role": "tank", "mount": "turret", "turret_turn_rate_deg": 50.0, "armor": {"front": 8.0, "side": 4.0, "rear": 2.0},
		"good_vs": ["ifv", "tank"], "weak_vs": ["scout"]}
const IFV := {"role": "ifv", "mount": "turret", "turret_turn_rate_deg": 180.0, "armor": {"front": 5.0, "side": 3.0, "rear": 2.0},
		"good_vs": ["scout"], "weak_vs": ["tank"]}
const CANNON := {"kind": Weapons.Kind.PROJECTILE, "penetration": 10.0, "range": 70.0, "damage": 34.0, "reload": 2.5, "spread_deg": 0.8, "shield_multiplier": 0.8}
const AUTOCANNON := {"kind": Weapons.Kind.PROJECTILE, "penetration": 4.0, "range": 60.0, "damage": 9.0, "reload": 0.35, "spread_deg": 1.0, "shield_multiplier": 0.9}
const MACHINE_GUN := {"kind": Weapons.Kind.BEAM, "penetration": 3.0, "range": 45.0, "damage": 4.0, "reload": 0.2, "spread_deg": 1.5, "shield_multiplier": 0.6}
const MORTAR := {"kind": Weapons.Kind.ARC, "penetration": 10.0, "range": 160.0, "min_range": 35.0, "damage": 70.0, "splash_radius": 8.0, "reload": 4.5}


func test_penetration_mirrors_the_rules_table() -> void:
	assert_near(Matchups.penetration_multiplier(10.0, 8.0), 0.5, 0.01, "a cannon on a tank's front: half")
	assert_near(Matchups.penetration_multiplier(10.0, 4.0), 1.0, 0.01, "on its side: full")
	assert_near(Matchups.penetration_multiplier(10.0, 2.0), 1.5, 0.01, "on its rear: the cap")
	assert_true(Matchups.penetration_multiplier(3.0, 8.0) < 0.2, "a machine gun barely scratches a tank's front")


func test_an_autocannon_shreds_a_scout_but_not_a_tank_front() -> void:
	var near := {"distance": 30.0, "face": "front"}
	var on_scout := Matchups.effective_dps(IFV, AUTOCANNON, SCOUT, near, false)
	var on_tank := Matchups.effective_dps(IFV, AUTOCANNON, TANK, near, false)
	assert_true(on_scout > 3.0 * on_tank, "30 mm on a scout vs on a tank's front (%.1f vs %.1f dps)" % [on_scout, on_tank])


func test_a_slow_turret_cant_track_a_circling_scout() -> void:
	var still := Matchups.effective_dps(TANK, CANNON, SCOUT, {"distance": 20.0, "face": "side", "angular_speed_deg": 10.0}, false)
	var circling := Matchups.effective_dps(TANK, CANNON, SCOUT, {"distance": 20.0, "face": "side", "angular_speed_deg": 55.0}, false)
	assert_true(circling < 0.3 * still, "a scout sweeping 55°/s around a 50°/s turret (%.1f vs %.1f dps)" % [circling, still])
	var ifv_on_circling := Matchups.effective_dps(IFV, AUTOCANNON, SCOUT, {"distance": 20.0, "face": "side", "angular_speed_deg": 55.0}, false)
	assert_true(ifv_on_circling > circling, "the IFV's fast turret keeps up where the tank's can't")


func test_a_fixed_gun_only_hits_what_the_hull_points_at() -> void:
	var ahead := Matchups.effective_dps(SCOUT, MACHINE_GUN, TANK, {"distance": 20.0, "face": "rear", "in_arc": true}, false)
	var beside := Matchups.effective_dps(SCOUT, MACHINE_GUN, TANK, {"distance": 20.0, "face": "rear", "in_arc": false}, false)
	assert_true(beside < 0.5 * ahead, "outside its 16° arc the scout has to turn first")


func test_shields_and_range_limits() -> void:
	var bare := Matchups.effective_dps(TANK, CANNON, TANK, {"distance": 30.0, "face": "side"}, false)
	var shielded := Matchups.effective_dps(TANK, CANNON, TANK, {"distance": 30.0, "face": "side"}, true)
	assert_true(shielded < bare, "a cannon is a hull breaker: less against a shield")
	assert_eq(Matchups.effective_dps(TANK, CANNON, TANK, {"distance": 90.0}, false), 0.0, "out of range: nothing")
	assert_eq(Matchups.effective_dps(TANK, MORTAR, TANK, {"distance": 20.0}, false), 0.0, "inside a mortar's minimum range: nothing")
	assert_true(Matchups.time_to_kill(TANK, CANNON, TANK, {"distance": 30.0, "face": "side"}, 300.0, 150.0)
			> Matchups.time_to_kill(TANK, CANNON, TANK, {"distance": 30.0, "face": "side"}, 300.0, 0.0), "a shield buys time")


func test_duels_follow_the_counters() -> void:
	var circle := {"distance": 20.0, "face": "side", "angular_speed_deg": 60.0}
	var scout_ttk_tank := Matchups.time_to_kill(SCOUT, MACHINE_GUN, TANK, {"distance": 20.0, "face": "rear"}, 300.0, 150.0)
	var tank_ttk_scout := Matchups.time_to_kill(TANK, CANNON, SCOUT, circle, 140.0, 80.0)
	var scout_vs_tank := Matchups.duel_advantage(scout_ttk_tank, tank_ttk_scout)
	var ifv_ttk_scout := Matchups.time_to_kill(IFV, AUTOCANNON, SCOUT, {"distance": 25.0, "face": "front", "angular_speed_deg": 30.0}, 140.0, 80.0)
	var scout_ttk_ifv := Matchups.time_to_kill(SCOUT, MACHINE_GUN, IFV, {"distance": 25.0, "face": "front"}, 220.0, 100.0)
	var ifv_vs_scout := Matchups.duel_advantage(ifv_ttk_scout, scout_ttk_ifv)
	var ifv_ttk_tank := Matchups.time_to_kill(IFV, AUTOCANNON, TANK, {"distance": 40.0, "face": "front"}, 300.0, 150.0)
	var tank_ttk_ifv := Matchups.time_to_kill(TANK, CANNON, IFV, {"distance": 40.0, "face": "front"}, 220.0, 100.0)
	var ifv_vs_tank := Matchups.duel_advantage(ifv_ttk_tank, tank_ttk_ifv)
	print("MEASURE ai_matchups duel advantage: scout circling a tank's rear %.2f, IFV vs scout %.2f, IFV vs tank front %.2f" % [
			scout_vs_tank, ifv_vs_scout, ifv_vs_tank])
	assert_true(ifv_vs_scout > 1.5, "an IFV beats a scout (%.2f)" % ifv_vs_scout)
	assert_true(ifv_vs_tank < 1.0, "an IFV loses to a tank head-on (%.2f)" % ifv_vs_tank)
	assert_true(scout_vs_tank > 1.0, "a scout circling a slow turret and shooting its rear wins (%.2f)" % scout_vs_tank)


func test_a_burst_weapon_counts_every_round_in_the_burst() -> void:
	var single := {"kind": Weapons.Kind.PROJECTILE, "penetration": 5.0, "range": 60.0, "damage": 15.0, "reload": 1.8}
	var burst := single.duplicate()
	burst["burst_count"] = 4
	var geometry := {"distance": 20.0, "face": "side"}
	assert_near(Matchups.effective_dps(IFV, burst, SCOUT, geometry, false),
			4.0 * Matchups.effective_dps(IFV, single, SCOUT, geometry, false), 0.001, "four rounds per pull: four times the damage")


func test_the_engine_deck_lets_a_light_gun_through() -> void:
	var rear := Matchups.effective_dps(SCOUT, MACHINE_GUN, TANK, {"distance": 20.0, "face": "rear"}, false)
	var deck := Matchups.effective_dps(SCOUT, MACHINE_GUN, TANK, {"distance": 20.0, "face": "rear", "weak_spot": true}, false)
	assert_true(deck > 1.5 * rear, "a stream on the engine deck (%.2f dps) beats one on the rear plate (%.2f)" % [deck, rear])
	var side_flag := Matchups.effective_dps(SCOUT, MACHINE_GUN, TANK, {"distance": 20.0, "face": "side", "weak_spot": true}, false)
	assert_near(side_flag, Matchups.effective_dps(SCOUT, MACHINE_GUN, TANK, {"distance": 20.0, "face": "side"}, false), 0.001,
			"the deck only faces astern")
	assert_near(Matchups.WEAK_SPOT_COS, cos(deg_to_rad(Armor.WEAK_SPOT_ARC_DEG)), 0.0001, "the arc mirrors the rules")
	assert_true(Matchups.is_weak_spot(Vector3(0, 0, -1), Vector3(0.2, 0, -1).normalized()), "a round up the tailpipe")
	assert_true(not Matchups.is_weak_spot(Vector3(0, 0, -1), Vector3(1, 0, -1).normalized()), "a quartering round hits the plate")

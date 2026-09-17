extends TestCase
## Round-5 X2 (ai): the two gates round 4 left in front of suppression, as golden decisions on hand-built situations.
##   1. SUPPRESS needed Matchups to know "my rounds don't hurt this", and the champion runs without matchups, so a
##      machine gun facing a tank's front never chose it. The proxy is the weapon's penetration against the armour the
##      target is showing me (the same Armor rule the damage uses).
##   2. A pinned enemy is a worse shooter, but fighting it from cover still out-scored going round it (COVER_FIRE won
##      1435 ticks of 1440). Cover buys safety from a gun that can hit you; a pinned gun mostly can't.
## Both are behind BrainVariants features ("suppress_proxy", "pinned_exposed") until a ladder adopts them.

const HERE := Vector3.ZERO


func _features(proxy: bool, pinned_exposed: bool) -> Dictionary:
	var features: Dictionary = BrainVariants.PROFILES["x4t9"].duplicate()
	features["suppress_proxy"] = proxy
	features["pinned_exposed"] = pinned_exposed
	return features


func _situation(unit: String, features: Dictionary, contacts: Array, overrides: Dictionary = {}) -> Dictionary:
	var situation := {
		"tick": 1000,
		"self": {"name": "Green_A_1", "team": 0, "position": HERE, "forward": Vector3.FORWARD, "unit": unit,
				"health": Units.stat(unit, "max_health"), "max_health": Units.stat(unit, "max_health"),
				"weapon": Weapons.profile(String(Units.stat(unit, "weapon")))},
		"directives": Directives.resolve([]),
		"contacts": contacts,
		"allies": [],
		"objective": null,
		"objective_radius": 0.0,
		"squad_center": null,
		"cover": [],
		"rally": Vector3(0, 0, 42),
		"enemy_base": Vector3(0, 0, -42),
		"memory_ticks": Match.CONTACT_MEMORY_TICKS,
		"features": features,
	}
	situation.merge(overrides, true)
	return situation


func _enemy(contact_name: String, unit: String, position: Vector3, overrides: Dictionary = {}) -> Dictionary:
	var contact := {"name": contact_name, "unit": unit, "position": position, "velocity": Vector3.ZERO,
			"forward": Vector3.BACK, "health": Units.stat(unit, "max_health"), "weapon": String(Units.stat(unit, "weapon")),
			"visible": true, "age": 0, "exposed_face": "front", "facing_ally": false, "aiming_at_me": false}
	contact.merge(overrides, true)
	return contact


func _choice(situation: Dictionary) -> String:
	return String(TankBrain.decide(situation, {})["choice"]["option"])


func test_a_machine_gun_facing_a_tanks_front_keeps_its_head_down_instead_of_plinking() -> void:
	var tank := _enemy("Rust_T_1", "law_tank", Vector3(0, 0, -25))
	assert_eq(_choice(_situation("gang_ifv", _features(true, false), [tank])), "SUPPRESS",
			"twin machine guns against 7 mm of front armour: pin it, don't pretend to kill it")
	assert_true(_choice(_situation("gang_ifv", _features(false, false), [tank])) != "SUPPRESS",
			"without the proxy (round 4's champion) the gate stays shut, which is what the proxy fixes")


func test_a_machine_gun_still_shoots_to_kill_what_its_rounds_go_through() -> void:
	var scout := _enemy("Rust_S_1", "gang_scout", Vector3(0, 0, -25))
	assert_eq(_choice(_situation("gang_ifv", _features(true, false), [scout])), "ENGAGE",
			"a scout's 1.5 mm plate is no reason to suppress: kill it")


func test_a_cannon_does_not_suppress_a_tank_it_can_hurt() -> void:
	var tank := _enemy("Rust_T_1", "law_tank", Vector3(0, 0, -40))
	assert_true(_choice(_situation("tank", _features(true, false), [tank])) != "SUPPRESS",
			"a cannon's shell goes through a tank's front: the proxy leaves it fighting")


## The round-4 case: a teammate holds the target down and this unit is the squad's flanker, sent round it
## (SquadTactics names it: tactics.flank_target), with a hide/peek pair available against the same target.
func _flanker_decision(pinned: bool, fixed: bool) -> Dictionary:
	var enemy := _enemy("Rust_T_1", "tank", Vector3(0, 0, -40), {"pinned": pinned,
			"suppression": 1.0 if pinned else 0.0})
	var s := _situation("tank", _features(false, fixed), [enemy],
			{"cover_fire": {"hide": Vector3(5, 0, 5), "peek": Vector3(8, 0, 0), "score": 0.8, "target": "Rust_T_1"},
			"tactics": {"focus": "Rust_T_1", "flank_target": "Rust_T_1", "cover_target": "", "fragile_threats": []}})
	var decision := TankBrain.decide(s, {})
	return decision


func test_the_flanker_goes_round_a_pinned_enemy_instead_of_fighting_it_from_cover() -> void:
	var before := _flanker_decision(true, false)
	assert_true(String(before["choice"]["option"]) != "FLANK",
			"round 4's champion: the flanker stayed to trade (the gate this fixes)")
	var after := _flanker_decision(true, true)
	assert_eq(String(after["choice"]["option"]), "FLANK", "its head is down: this is the moment to go round it")


func test_a_calm_enemy_is_still_fought_from_cover() -> void:
	assert_true(String(_flanker_decision(false, true)["choice"]["option"]) != "FLANK",
			"the flanker waits for its teammates to pin a calm enemy before it goes round")
	var enemy := _enemy("Rust_T_1", "tank", Vector3(0, 0, -40))
	var s := _situation("tank", _features(false, true), [enemy],
			{"cover_fire": {"hide": Vector3(5, 0, 5), "peek": Vector3(8, 0, 0), "score": 0.8, "target": "Rust_T_1"}})
	assert_eq(_choice(s), "COVER_FIRE", "an enemy that can shoot straight: fight it from cover, as before")

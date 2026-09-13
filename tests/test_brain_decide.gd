extends TestCase
## Golden tests for TankBrain.decide(): hand-built Situations, no physics, no scene.
## Each test names the behavior a player would expect from an autonomous tank.

const HERE := Vector3.ZERO


func _situation(overrides: Dictionary = {}) -> Dictionary:
	var situation := {
		"tick": 1000,
		"self": {"name": "Green_A_1", "team": 0, "position": HERE, "forward": Vector3.FORWARD,
				"health": 100, "max_health": 100, "weapon": Weapons.profile("cannon")},
		"directives": Directives.resolve([]),
		"contacts": [],
		"allies": [],
		"objective": null,
		"objective_radius": 0.0,
		"squad_center": null,
		"cover": [],
		"rally": Vector3(0, 0, 42),
		"enemy_base": Vector3(0, 0, -42),
		"memory_ticks": Match.CONTACT_MEMORY_TICKS,
	}
	situation.merge(overrides, true)
	return situation


func _enemy(contact_name: String, position: Vector3, overrides: Dictionary = {}) -> Dictionary:
	var contact := {"name": contact_name, "position": position, "velocity": Vector3.ZERO, "forward": Vector3.BACK,
			"health": 100, "weapon": "cannon", "visible": true, "age": 0, "exposed_face": "front",
			"facing_ally": false, "aiming_at_me": false}
	contact.merge(overrides, true)
	return contact


func _hurt(situation: Dictionary, health: int) -> Dictionary:
	situation["self"]["health"] = health
	return situation


func _choice(situation: Dictionary, current: Dictionary = {}) -> String:
	return TankBrain.label(TankBrain.decide(situation, current)["choice"])


func test_with_nothing_known_it_advances() -> void:
	assert_eq(_choice(_situation()), "ADVANCE", "no contacts, no objective: push toward the enemy base")


func test_a_visible_enemy_in_range_is_engaged() -> void:
	var s := _situation({"contacts": [_enemy("Rust_A_1", Vector3(0, 0, -40))]})
	assert_eq(_choice(s), "ENGAGE Rust_A_1", "a healthy tank fights what it can see")


func test_badly_hurt_with_enemies_in_sight_it_retreats() -> void:
	var s := _hurt(_situation({"contacts": [_enemy("Rust_A_1", Vector3(0, 0, -40), {"aiming_at_me": true})]}), 20)
	assert_eq(_choice(s), "RETREAT", "at 20 HP under fire, live to fight again")


func test_cautious_and_under_fire_it_takes_nearby_cover() -> void:
	var s := _situation({
		"directives": Directives.resolve([{"caution": 0.9}]),
		"contacts": [_enemy("Rust_A_1", Vector3(0, 0, -40), {"aiming_at_me": true}),
				_enemy("Rust_A_2", Vector3(10, 0, -40), {"aiming_at_me": true})],
		"cover": [Vector3(10, 0, 0)],
	})
	_hurt(s, 60)
	assert_eq(_choice(s), "TAKE_COVER", "two guns on a cautious, damaged tank: get out of sight")


func test_a_flanker_goes_for_the_side_of_an_enemy_busy_with_a_teammate() -> void:
	var s := _situation({
		"directives": Directives.resolve([{"role": "flanker"}]),
		"contacts": [_enemy("Rust_A_1", Vector3(0, 0, -40), {"facing_ally": true})],
	})
	assert_eq(_choice(s), "FLANK Rust_A_1", "the enemy faces an ally: swing to its side")


func test_a_flanker_already_seeing_the_side_just_shoots() -> void:
	var s := _situation({
		"directives": Directives.resolve([{"role": "flanker"}]),
		"contacts": [_enemy("Rust_A_1", Vector3(0, 0, -40), {"facing_ally": true, "exposed_face": "side"})],
	})
	assert_eq(_choice(s), "ENGAGE Rust_A_1", "no need to maneuver for an angle you already have")


func test_an_anchor_at_its_objective_holds() -> void:
	var s := _situation({"directives": Directives.resolve([{"role": "anchor"}]),
			"objective": Vector3(0, 0, 3), "objective_radius": 10.0})
	assert_eq(_choice(s), "HOLD", "anchors stay put once in position")


func test_a_leashed_tank_returns_to_its_objective() -> void:
	var s := _situation({"directives": Directives.resolve([{"role": "anchor", "leash": 15.0}]),
			"objective": Vector3(0, 0, 40), "objective_radius": 10.0,
			"contacts": [_enemy("Rust_A_1", Vector3(0, 0, -30))]})
	assert_eq(_choice(s), "ADVANCE", "40 m from its post with a 15 m leash: go back, even with an enemy in sight")


func test_a_stale_contact_is_investigated() -> void:
	var s := _situation({"contacts": [_enemy("Rust_A_1", Vector3(0, 0, -40), {"visible": false,
			"age": TankBrain.CONTACT_FRESH_TICKS + 60})]})
	assert_eq(_choice(s), "INVESTIGATE Rust_A_1", "an enemy seen a while ago: go look where it was")


func test_commitment_prevents_flip_flopping() -> void:
	var near := _enemy("Rust_A_1", Vector3(0, 0, -30))
	var far := _enemy("Rust_A_2", Vector3(0, 0, -36))
	var s := _situation({"contacts": [near, far]})
	assert_eq(_choice(s), "ENGAGE Rust_A_1", "fresh decision: the nearer enemy scores higher")
	var current := {"option": "ENGAGE", "target": "Rust_A_2", "since": 990}
	assert_eq(_choice(s, current), "ENGAGE Rust_A_2", "10 ticks into engaging the other one, it keeps its target")
	current["since"] = 1000 - TankBrain.MIN_COMMIT_TICKS - 1
	assert_eq(_choice(s, current), "ENGAGE Rust_A_2", "the commitment bonus still covers a small score gap")


func test_decide_is_deterministic() -> void:
	var s := _situation({"contacts": [_enemy("Rust_A_1", Vector3(5, 0, -40)), _enemy("Rust_A_2", Vector3(-5, 0, -40))]})
	var first := TankBrain.decide(s, {})
	for i in 5:
		var again := TankBrain.decide(s.duplicate(true), {})
		assert_true(again.recursive_equal(first, 4), "same situation → identical decision and ranking (run %d)" % i)
	assert_eq(TankBrain.label(first["choice"]), "ENGAGE Rust_A_1", "an exact tie goes to the earlier name")


func test_directives_resolve_in_layers() -> void:
	var resolved := Directives.resolve([{"role": "anchor"}, {"caution": 0.95}])
	assert_eq(resolved["leash"], 15.0, "the squad's role preset applies")
	assert_eq(resolved["caution"], 0.95, "a tank-level value overrides the preset")
	assert_eq(resolved["target_priority"], "nearest", "untouched keys keep defaults")
	assert_true(Directives.validate({"aggression": 2}) != "", "out-of-range weights are rejected")
	assert_true(Directives.validate({"role": "kamikaze"}) != "", "unknown roles are rejected")
	assert_true(Directives.validate({"objective": {"right": 1}}) != "", "incomplete objectives are rejected")
	assert_eq(Directives.validate({"role": "flanker", "objective": {"right": 40, "forward": 0, "radius": 8}}), "",
			"a well-formed directive passes")


func test_team_relative_coordinates_are_mirror_images() -> void:
	var green := Directives.to_world(Match.Team.GREEN, 40.0, 10.0)
	var rust := Directives.to_world(Match.Team.RUST, 40.0, 10.0)
	assert_true(green.is_equal_approx(-rust), "the same doctrine point is point-symmetric between teams (%s vs %s)" % [green, rust])
	assert_true(green.z < 0.0, "Green's forward is north (-z), toward Rust")


func test_doctrine_validation() -> void:
	assert_true(Doctrine.parse({"name": "x", "squads": []}).has("error"), "needs squads")
	var too_many := {"name": "x", "squads": [{"name": "A", "tanks": [{}, {}, {}, {}, {}, {}]}]}
	assert_true(Doctrine.parse(too_many).has("error"), "at most MAX_TANKS tanks")
	var bad_weapon := {"name": "x", "squads": [{"name": "A", "tanks": [{"weapon": "laser"}]}]}
	assert_true(String(Doctrine.parse(bad_weapon).get("error", "")).contains("laser"), "unknown weapons are named in the error")
	for path in ["res://doctrines/individuals.json", "res://doctrines/anvil_hammer.json", "res://doctrines/flame_rush.json"]:
		assert_true(Doctrine.load_file(path).has("doctrine"), "%s is valid: %s" % [path, Doctrine.load_file(path).get("error", "")])

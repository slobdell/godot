extends TestCase
## Round 28 (native N6.2): combat resolution's rules natively (NativeCombat -> combat_native.cpp) against the LIVE
## GDScript. (1) Match._land_hit_result's terms -- the armour face, the weak spot, the multiplier through armour, the
## shield factor -- for every unit of the roster as the victim, every unit's weapon as the attack, seeded directions;
## (2) Tank.take_hit from one snapshot both ways (shield, the damage accumulator, health, ticks_since_hit and the result),
## shields and accumulators seeded, hulls kept alive (health raised for the pair) so no death signal fires twice.

const MATCH := preload("res://game/match/match.tscn")


static func _gd_terms(game_match: Match, victim: Tank, weapon: Dictionary, direction: Vector3) -> Array:
	var forward := -victim.global_basis.z
	var face: String = Armor.FACING_NAMES[Armor.facing(forward, direction)]
	if weapon["kind"] == Weapons.Kind.ARC:
		face = "side"
	var weak := Match.is_weak_spot_hit(weapon, forward, direction)
	var through := Match.weak_spot_multiplier(weapon, victim.unit_id) if weak else Match.armor_multiplier(weapon, victim.unit_id, face)
	return [face, weak, through, float(weapon.get("shield_multiplier", 1.0)) * float(Armor.SHIELD_FACING[face])]


static func _snapshot(tank: Tank) -> Array:
	return [tank.shield, tank.damage_accumulator, tank.health, tank.ticks_since_hit, tank.alive]


static func _restore(tank: Tank, state: Array) -> void:
	tank.shield = state[0]
	tank.damage_accumulator = state[1]
	tank.health = state[2]
	tank.ticks_since_hit = state[3]


func test_combat_rules_are_the_live_gdscript() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the combat equality is not exercised in this run")
		return
	assert_true(NativeCombat.configure(), "the native combat rules take the live constants")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	await wait_physics_frames(1)
	var units: Array = Units.PROFILES.keys()
	units.sort()
	var victims: Array[Tank] = []
	for i in units.size():
		var tank := game_match.spawn_tank("Victim%02d" % i, 0, Match.Team.GREEN, String(units[i]))
		tank.global_position = Vector3(8.0 * (i % 8) - 30.0, 0.0, 8.0 * (i / 8) - 20.0)
		victims.append(tank)
	await wait_physics_frames(2)
	var weapons: Array[Dictionary] = []
	for unit: Variant in units:
		weapons.append(Weapons.profile(String(Units.PROFILES[unit].get("weapon", Weapons.DEFAULT))))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2829
	var was := BrainSwitches.native_combat
	var terms_compared := 0
	var hits_compared := 0
	var mismatches := 0
	var first := ""
	var faces := {}
	var weak_count := 0
	for victim in victims:
		victim.rotation.y = rng.randf_range(-PI, PI)
		for n in 40:
			var weapon: Dictionary = weapons[rng.randi_range(0, weapons.size() - 1)]
			var angle := rng.randf_range(0.0, TAU)
			var direction := Vector3(cos(angle), rng.randf_range(-0.3, 0.1), sin(angle))
			if n % 5 == 0:
				direction = -victim.global_basis.z.rotated(Vector3.UP, rng.randf_range(-0.4, 0.4))  # the engine deck
			var live := _gd_terms(game_match, victim, weapon, direction)
			var native: Array = NativeCombat.hit_terms(victim, weapon, direction)
			terms_compared += 1
			faces[live[0]] = int(faces.get(live[0], 0)) + 1
			weak_count += 1 if live[1] else 0
			if live != native:
				mismatches += 1
				if first == "":
					first = "terms %s (%s): live %s native %s" % [victim.unit_id, weapon.get("id", "?"), live, native]
			# take_hit both ways from one snapshot
			victim.shield = rng.randf_range(0.0, victim.max_shield) if rng.randf() < 0.7 else 0.0
			victim.damage_accumulator = rng.randf_range(0.0, 0.99)
			victim.health = 100000
			var start := _snapshot(victim)
			var raw := rng.randf_range(0.0, 120.0) if rng.randf() < 0.9 else 0.0
			BrainSwitches.native_combat = false
			var live_hit := victim.take_hit(raw, float(live[3]), float(live[2]))
			var live_after := _snapshot(victim)
			_restore(victim, start)
			BrainSwitches.native_combat = true
			var native_hit := victim.take_hit(raw, float(live[3]), float(live[2]))
			var native_after := _snapshot(victim)
			_restore(victim, start)
			BrainSwitches.native_combat = was
			hits_compared += 1
			if live_hit != native_hit or live_after != native_after:
				mismatches += 1
				if first == "":
					first = "take_hit %s raw %s: live %s %s native %s %s" % [victim.unit_id, raw, live_hit, live_after,
							native_hit, native_after]
	BrainSwitches.native_combat = was
	print("native combat: %d units, %d terms (faces %s, %d weak spots), %d take_hits, %d mismatches" % [units.size(),
			terms_compared, faces, weak_count, hits_compared, mismatches])
	assert_eq(mismatches, 0, "the native combat rules are the live GDScript: %s" % first)
	assert_true(terms_compared >= 400 and faces.size() == 3 and weak_count >= 20,
			"a real sample (%d terms, faces %s, %d weak)" % [terms_compared, faces, weak_count])

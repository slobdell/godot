extends TestCase
## Round 26 (perf, granted): `TankBrain._cover_spots` tests the crew's toughness BEFORE it builds the threat list. Proof
## that the answer did not move: in a real Sumps fight, every brain is asked both ways from the same state -- the live
## function and the round-25 order kept verbatim below -- with half the crews made worn (health and shield cut) so the
## query path runs too; the spots AND the cache each leaves behind must be equal.

const MATCH := preload("res://game/match/match.tscn")


func _doctrine(units: Array[String]) -> Dictionary:
	var entries := []
	for unit in units:
		entries.append({"unit": unit})
	return {"squads": [{"name": "Alpha", "units": entries.slice(0, 5)}, {"name": "Bravo", "units": entries.slice(5)}]}


## The round-25 `_cover_spots`, verbatim but for `brain.` (the threat list first, then the toughness test).
func _old(brain: TankBrain, contacts: Array, allies: Array, squad_context: Dictionary) -> Array:
	var tank := brain.tank
	var threats := TankBrain.threat_list(contacts, tank.global_position)
	var toughness := (tank.health + tank.shield) / maxf(tank.max_health + tank.max_shield, 1.0)
	var shield_down := tank.max_shield > 0.0 and tank.shield <= 0.0
	if threats.is_empty() or (toughness >= TankBrain.COVER_QUERY_TOUGHNESS and not shield_down):
		brain._cover_cache = {}
		return []
	if not brain._cover_cache.is_empty() and brain.game_match.tick - int(brain._cover_cache["tick"]) < TankBrain.QUERY_EVERY_TICKS \
			and tank.global_position.distance_to(brain._cover_cache["position"]) < TankBrain.QUERY_MOVED:
		return brain._cover_cache["result"]
	var request := {"position": tank.global_position, "threats": threats, "search_radius": TankBrain.COVER_SEARCH_RADIUS,
			"friends": allies.map(func(ally: Dictionary) -> Vector3: return ally["position"])}
	if squad_context.get("slot") != null:
		request["anchor"] = squad_context["slot"]
	elif brain.element.get("slot") != null and not ["bound", "maneuver"].has(String(brain.element.get("role", ""))):
		request["anchor"] = brain.element["slot"]
		request["anchor_radius"] = TankBrain.COVER_SEARCH_RADIUS * 0.6
	elif brain._order_home != null:
		if brain.order.is_empty():
			request["anchor"] = brain._order_home
			request["anchor_radius"] = TankBrain.IDLE_LEASH
	elif typeof(brain.directives["objective"]) == TYPE_DICTIONARY and float(brain.directives["leash"]) > 0.0:
		var o: Dictionary = brain.directives["objective"]
		request["anchor"] = Directives.to_world(tank.team, float(o["right"]), float(o["forward"]))
		request["anchor_radius"] = float(brain.directives["leash"])
	var result: Array = TacticalQuery.find_cover(CoverMap.of(tank), request).map(
			func(spot: Dictionary) -> Vector3: return spot["point"])
	brain._cover_cache = {"tick": brain.game_match.tick, "position": tank.global_position, "threats": threats.size(), "result": result}
	return result


func test_a_worn_crew_gets_the_same_spots() -> void:
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv", "tank"]
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _doctrine(units)), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _doctrine(units)), "", "rust loads")
	await wait_physics_frames(2)
	var asked := 0
	var worn_asked := 0
	var found := 0
	var mismatches := 0
	var first := ""
	for frame in 450:
		await wait_physics_frames(1)
		if frame % 15 != 14:
			continue
		var index := 0
		for node in game_match.brains.get_children():
			var brain := node as TankBrain
			if brain == null or brain.tank == null or not brain.tank.is_alive():
				continue
			index += 1
			var s := brain.build_situation()
			var squad_context: Dictionary = s["squad"] if s["squad"] != null else {}
			var tank := brain.tank
			var health := tank.health
			var shield := tank.shield
			var worn := index % 2 == 0
			if worn:  # under COVER_QUERY_TOUGHNESS, shield down: the query path
				tank.health = maxi(1, int(tank.max_health * 0.3))
				tank.shield = 0
			var cache_before: Dictionary = brain._cover_cache.duplicate()
			var old_spots := _old(brain, s["contacts"], s["allies"], squad_context)
			var old_cache: Dictionary = brain._cover_cache.duplicate()
			brain._cover_cache = cache_before
			var new_spots := brain._cover_spots(s["contacts"], s["allies"], squad_context)
			tank.health = health
			tank.shield = shield
			asked += 1
			worn_asked += 1 if worn else 0
			found += 1 if not old_spots.is_empty() else 0
			if old_spots != new_spots or old_cache != brain._cover_cache:
				mismatches += 1
				if first == "":
					first = "frame %d %s worn %s: %s v %s; cache %s v %s" % [frame, tank.name, worn, var_to_str(old_spots).left(160),
							var_to_str(new_spots).left(160), var_to_str(old_cache).left(160), var_to_str(brain._cover_cache).left(160)]
	print("cover spots: %d asked (%d worn), %d found spots, %d mismatches" % [asked, worn_asked, found, mismatches])
	assert_eq(mismatches, 0, "the reordered _cover_spots answers as before: %s" % first)
	assert_true(asked >= 200 and worn_asked >= 100 and found >= 30, "a real sample (%d asked, %d worn, %d found)" % [asked, worn_asked, found])

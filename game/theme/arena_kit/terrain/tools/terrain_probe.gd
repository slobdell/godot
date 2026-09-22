extends SceneTree
## `make terrain-series` (terrain, round 10): R9's second acceptance -- **is the expensive route actually used?**
## Boots the REAL match runner (main.tscn with the flags after `--`, as `tests/arena/arena_probe.gd` does) and, once a
## simulated second, counts where every live unit is, WITHOUT touching the simulation:
##   crossing_seconds    unit-seconds inside each of the layout's `chokepoint` regions (on the terrain maps these are
##                       the bridges, the catwalk and the causeways), total and by name
##   objective_seconds   unit-seconds inside each objective's radius, split into a team's OWN objective (its half's,
##                       the cheap one) and the CONTESTED one (the enemy's half)
##   contested_share     contested / (own + contested): the flanking rate the brief asks to see move
##   hits, winner, reason, sim_seconds
## The dry twin carries the same regions and objectives, so the two arms are counted over the same ground.
## POSITIVE CONTROL: `terrain_entries` (from Arena.active) proves which arm ran: > 0 wet, 0 dry.
## Prints `TERRAIN_PROBE <json>` next to the runner's MATCH_RESULT.

var game_match: Match
var chokepoints: Array = []
var objectives: Array = []
var unit_seconds := 0
var crossing := {}
var own_seconds := 0
var contested_seconds := 0
var hits := 0
var reported := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	game_match = main.get("game_match")
	game_match.projectile_impact.connect(_on_impact)
	game_match.finished.connect(_on_finished)
	physics_frame.connect(_sample)


func _on_impact(event: Dictionary) -> void:
	if event.has("target"):
		hits += 1


func _sample() -> void:
	if game_match == null or game_match.tick % SimClock.TICK_RATE != 0:
		return
	if chokepoints.is_empty() and objectives.is_empty():
		for region: Dictionary in Arena.active.get("regions", []):
			if String(region.get("kind", "")) == "chokepoint":
				chokepoints.append(region)
		objectives = Arena.objectives_of(Arena.active)
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank == null or not tank.is_alive():
			continue
		unit_seconds += 1
		var flat := Vector2(tank.global_position.x, tank.global_position.z)
		for region: Dictionary in chokepoints:
			var at := Vector2(float(region["position"][0]), float(region["position"][1]))
			if flat.distance_to(at) <= float(region["radius"]):
				var key := String(region["name"])
				crossing[key] = int(crossing.get(key, 0)) + 1
		# Green's side is +z (south) unless the bases were swapped: an objective on a team's own half is its cheap one.
		var home_sign := 1.0 if (tank.team == Match.Team.GREEN) != Match.swap_bases else -1.0
		for objective: Dictionary in objectives:
			var at: Vector3 = objective["position"]
			if flat.distance_to(Vector2(at.x, at.z)) > float(objective["radius"]):
				continue
			if at.z * home_sign > 0.0:
				own_seconds += 1
			else:
				contested_seconds += 1


func _on_finished(result: Dictionary) -> void:
	if reported:
		return
	reported = true
	var total_crossing := 0
	for key: String in crossing:
		total_crossing += int(crossing[key])
	print("TERRAIN_PROBE " + JSON.stringify({
		"arena": String(Arena.active.get("name", "")), "terrain_entries": (Arena.active.get("terrain", []) as Array).size(),
		"winner": result["winner"], "reason": result["reason"], "swap_bases": Match.swap_bases,
		"sim_seconds": result.get("sim_seconds", 0.0), "hits": hits, "unit_seconds": unit_seconds,
		"crossing_seconds": total_crossing, "crossing_by_name": crossing,
		"crossing_share": snappedf(float(total_crossing) / maxi(unit_seconds, 1), 0.0001),
		"own_objective_seconds": own_seconds, "contested_objective_seconds": contested_seconds,
		"contested_share": snappedf(float(contested_seconds) / maxi(own_seconds + contested_seconds, 1), 0.001)}))

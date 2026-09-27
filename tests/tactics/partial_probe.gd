extends SceneTree
## Round 12, squad S4: what a PARTIAL or MIXED selection does on the default path, measured the way he gives the order.
##
## A Condemned army of two squads -- Alpha (tank, tank, ifv, ifv, scout) and Bravo (tank, ifv, scout) -- deployed as
## skirmish deploys it (ArmyLayout), each squad on its number key exactly as skirmish puts it there
## (ControlGroups.from_squads). Then the real RtsControls.order_selection("move") 80 m toward the enemy for:
##
##   --case=whole    all of Alpha (the reference: a numbered squad takes the TASK path and the travelling anchor)
##   --case=partial  three of Alpha's five (box-selecting part of a squad)
##   --case=mixed    two of Alpha and two of Bravo (box-selecting across squads)
##
## Out: PARTIAL_PROBE {"case", "path": "task"|"direct", "readout" (the card's footer: task_refusal(true)), "formation"
## (the card's Formation button, CommandIcons.formation_readout), "group_formation" (the direct path's shape),
## "arrived_s" (every selected crew's order done), "stopped_s", "spread_m" (mean distance of the moving crews from their
## own centroid while any moves: how scattered they travel), "spread_max_m", "left_squad" (selected crews no longer in
## their element)} plus SETTLE_TRACK lines every 0.25 s for tools/tactics/plot_tracks.py.
##
##   make squad-partial CASE=partial ARENA=yard SEED=3

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const STILL_MPS := 0.3

var case: TestCase


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	var which := _flag("case", "partial")
	var arena := ARENA.instantiate() as Node3D
	arena.set("layout_name", _flag("arena", "yard"))
	case.add_to_tree(arena)
	for _frame in 60:
		await physics_frame
		if TacticsLab.navigation_is_this_arenas(arena):
			break
	var game_match := MATCH.instantiate() as Match
	case.add_to_tree(game_match)
	game_match.seed_spawns(int(_flag("seed", "3")), 0.0)
	game_match.set_meta("player_team", Match.Team.GREEN)
	var army := {"name": "Probe", "squads": [
		{"name": "Alpha", "units": [{"unit": "tank"}, {"unit": "tank"}, {"unit": "ifv"}, {"unit": "ifv"}, {"unit": "scout"}]},
		{"name": "Bravo", "units": [{"unit": "tank"}, {"unit": "ifv"}, {"unit": "scout"}]}]}
	var error := game_match.load_doctrine(Match.Team.GREEN, army)
	if error != "":
		print("PARTIAL_PROBE_ERROR %s" % error)
		quit(1)
		return
	var orders := Orders.new()
	Orders.attach(game_match, orders)
	var elements := Elements.install(game_match, orders)
	var controls := RtsControls.new()
	controls.orders = orders
	controls.elements = elements
	controls.game_match = game_match
	case.add_to_tree(controls)
	controls.groups = ControlGroups.from_squads(game_match, Match.Team.GREEN)
	for _frame in 30:
		await physics_frame
	var alpha: Array[String] = controls.groups.members(1)
	var bravo: Array[String] = controls.groups.members(2)
	var picked: Array[String] = []
	match which:
		"whole":
			picked = alpha.duplicate()
		"partial":
			picked = [alpha[0], alpha[2], alpha[4]]
		"mixed":
			picked = [alpha[0], alpha[1], bravo[0], bravo[1]]
	controls.selection.units = picked.duplicate()
	var centre := _centre(game_match, picked)
	var toward := TacticsFormation.flat(Vector3(-centre.x, 0.0, -centre.z))
	var goal := centre + toward * float(_flag("metres", "80"))
	var readout := controls.task_refusal(true)
	var path := "task" if controls.can_task() else "direct"
	var given: int = game_match.tick
	error = controls.order_selection("move", {"to": [goal.x, goal.z]})
	var formation := {}
	var group_formation := String((orders.current(picked[0]) as Dictionary).get("formation", ""))
	var spread_sum := 0.0
	var spread_n := 0
	var spread_max := 0.0
	var arrived := -1
	var stopped := -1
	var still_since := -1
	for tick in int(float(_flag("seconds", "60")) * SimClock.TICK_RATE):
		await physics_frame
		var now: int = game_match.tick - given
		var positions: Array = []
		var fastest := 0.0
		var done := true
		for unit_name in picked:
			var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if tank == null:
				continue
			positions.append(Vector3(tank.global_position.x, 0.0, tank.global_position.z))
			fastest = maxf(fastest, tank.estimated_velocity.length())
			var current: Dictionary = orders.current(unit_name)
			var owner := elements.of(unit_name)
			if owner != null:
				done = done and owner.arrived
			elif not current.is_empty() and String(current.get("verb", "")) != "hold":
				done = false
		if fastest > STILL_MPS:
			var mid := Vector3.ZERO
			for p: Vector3 in positions:
				mid += p
			mid /= maxf(positions.size(), 1)
			for p: Vector3 in positions:
				spread_sum += p.distance_to(mid)
				spread_n += 1
				spread_max = maxf(spread_max, p.distance_to(mid))
		if now == 2 * SimClock.TICK_RATE:
			# The card as he reads it once the leader has planned (a fresh element holds its default shape for one tick).
			var element := controls.selected_element()
			formation = CommandIcons.formation_readout(String(controls.formation), element.state() if element != null else {})
		if arrived < 0 and done and now > 5:
			arrived = now
		if now % maxi(SimClock.TICK_RATE / 4, 1) == 0:
			var track := {"t": snappedf(float(now) / SimClock.TICK_RATE, 0.01), "anchor": null, "crews": {}, "stations": {}}
			for unit_name in picked:
				var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
				if tank != null:
					track["crews"][unit_name] = [snappedf(tank.global_position.x, 0.1), snappedf(tank.global_position.z, 0.1)]
			print("SETTLE_TRACK " + JSON.stringify(track))
		if arrived >= 0 and fastest < STILL_MPS:
			if still_since < 0:
				still_since = now
			if now - still_since >= SimClock.TICK_RATE:
				stopped = still_since
				break
		else:
			still_since = -1
	var left := 0
	for unit_name in picked:
		if elements.of(unit_name) == null:
			left += 1
	print("PARTIAL_PROBE " + JSON.stringify({"case": which, "arena": _flag("arena", "yard"), "seed": int(_flag("seed", "3")),
			"picked": picked, "error": error, "path": path, "readout": readout, "formation": formation,
			"group_formation": group_formation,
			"arrived_s": snappedf(float(arrived) / SimClock.TICK_RATE, 0.1) if arrived >= 0 else null,
			"stopped_s": snappedf(float(stopped) / SimClock.TICK_RATE, 0.1) if stopped >= 0 else null,
			"spread_m": snappedf(spread_sum / spread_n, 0.1) if spread_n > 0 else -1.0,
			"spread_max_m": snappedf(spread_max, 0.1), "left_squad": left}))
	case.teardown()
	quit(0)


func _centre(game_match: Match, names: Array) -> Vector3:
	var sum := Vector3.ZERO
	for unit_name: String in names:
		sum += (game_match.tanks.get_node(NodePath(unit_name)) as Node3D).global_position
	sum /= float(names.size())
	return Vector3(sum.x, 0.0, sum.z)

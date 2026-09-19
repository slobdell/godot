extends SceneTree
## `make nav-orders` (nav, round 6): the lead's own test, headless and with BRAINS — "if we have a horde of units, and
## I tell different squads to move in different directions a bunch of cars just get stuck or blocked by other cars."
## Five player squads (30 vehicles, mixed roster) are ordered across one another at once, through control's Orders,
## exactly as a right-click would. Nobody fights (no enemy): this measures driving and order completion only.
##
## What it records per unit: when its order COMPLETED (Orders says idle again), how far from its goal it actually was
## at that moment, and where it is at the end. That is the instrument for TankBrain.ORDER_STALL_ARRIVE — a stalled
## unit within 12 m used to declare its order done — so "completed_far" is the number that rule inflates.
## Prints `NAV_ORDERS <json>`; exits 1 only if it could not run.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const ROSTER := ["tank", "tank", "ifv", "ifv", "scout", "tank"]
## Where each squad (spawned left to right) is sent: every squad crosses at least one other's path.
const TARGETS := [[70.0, -20.0], [-70.0, -30.0], [0.0, -60.0], [60.0, 40.0], [-60.0, 30.0]]
## Completing further than this from the goal is a completion the unit did not earn (ORDER_ARRIVE is 3.5 m, wheels
## up to 6 m; a formation slot is where the goal already is).
const FAR_M := 7.0

var game_match: Match
var orders: Orders
var units: Array[Tank] = []
var goal := {}          # name -> last goal Orders gave it (Vector3)
var completed_at := {}  # name -> seconds
var completed_far := {} # name -> distance at completion
var time_limit := 90.0
var issued_tick := 0


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	time_limit = float(_flag("time-limit", "90"))
	var arena: Arena = ARENA.instantiate()
	arena.layout_name = _flag("arena", "yard")
	root.add_child(arena)
	game_match = MATCH.instantiate()
	root.add_child(game_match)
	game_match.seed_spawns(int(_flag("seed", "1")), 0.0)
	game_match.set_meta("player_team", Match.Team.GREEN)
	await physics_frame
	for frame in 300:
		if Pathing.is_ready(arena):
			break
		await physics_frame
	var squads: Array = []
	for s in TARGETS.size():
		squads.append({"name": "S%d" % s, "units": ROSTER.map(func(unit: String) -> Dictionary: return {"unit": unit})})
	var error := game_match.load_doctrine(Match.Team.GREEN, {"name": "NavOrders", "squads": squads})
	if error != "":
		push_error("nav-orders: " + error)
		quit(1)
		return
	orders = Orders.new()
	Orders.attach(game_match, orders)
	var executor := OrderExecutor.new()
	executor.game_match = game_match
	executor.orders = orders
	root.add_child(executor)
	for tank: Tank in game_match.tanks.get_children():
		units.append(tank)
	# Let the brains settle on their posts, then order every squad at once.
	for frame in SimClock.TICK_RATE:
		await physics_frame
	for s in TARGETS.size():
		var names: Array = []
		for tank in units:
			if String(tank.name).begins_with("Green_S%d_" % s):
				names.append(String(tank.name))
		var result := orders.issue(UnitCommand.make(names, "move", {"to": TARGETS[s]}))
		if result != "":
			push_error("nav-orders: " + result)
	issued_tick = game_match.tick
	print("NAV_ORDERS_ISSUED %d units in %d squads on %s" % [units.size(), TARGETS.size(), Arena.active.get("name", "?")])
	physics_frame.connect(_sample)


func _sample() -> void:
	var elapsed := float(game_match.tick - issued_tick) / float(SimClock.TICK_RATE)
	for tank in units:
		var key := String(tank.name)
		if completed_at.has(key):
			continue
		var g: Variant = orders.goal_position(key)
		if g != null:
			goal[key] = g
		elif goal.has(key) and orders.is_idle(key):
			completed_at[key] = elapsed
			completed_far[key] = _flat(tank.global_position, goal[key])
	if completed_at.size() == units.size() or elapsed >= time_limit:
		_report(elapsed)


func _report(elapsed: float) -> void:
	physics_frame.disconnect(_sample)
	var times: Array = completed_at.values()
	times.sort()
	var far := 0
	var worst: Array = []
	for key: String in completed_far:
		if float(completed_far[key]) > FAR_M:
			far += 1
	for tank in units:
		var key := String(tank.name)
		var final := _flat(tank.global_position, goal[key]) if goal.has(key) else -1.0
		worst.append({"unit": key, "completed_s": snappedf(float(completed_at.get(key, -1.0)), 0.1),
				"at_completion_m": snappedf(float(completed_far.get(key, -1.0)), 0.1), "final_m": snappedf(final, 0.1),
				"phase": String(Movement.state(tank).get("phase", "?"))})
	worst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["final_m"] > b["final_m"])
	var at := func(fraction: float) -> float:
		var need := int(ceil(float(units.size()) * fraction))
		return snappedf(times[need - 1], 0.1) if need > 0 and times.size() >= need else -1.0
	var out := {"arena": String(Arena.active.get("name", "?")), "units": units.size(), "seconds": snappedf(elapsed, 0.1),
			"completed": completed_at.size(), "completed_far": far, "never_completed": units.size() - completed_at.size(),
			"t50_s": at.call(0.5), "t90_s": at.call(0.9), "t100_s": at.call(1.0), "worst": worst.slice(0, 6)}
	print("NAV_ORDERS %s" % JSON.stringify(out))
	quit(0)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

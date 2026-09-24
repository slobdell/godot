extends SceneTree
## `make nav-terminus-drive` (nav, round 10, item 2): **the round's bar, measured.** The lead: *"I'll know that the
## units are doing what I want when I can navigate them through the Terminus streets"* and *"Units are still driving
## into walls."* One player squad, ordered through control's `Orders` exactly as a right-click would, street to street
## across Terminus on the DEFAULT path (no flags): spawn → the ring road → the west street → the plaza → the far ring
## road. Each leg is issued when the previous one completes (every crew idle again) or times out. Nobody fights.
##
## Two squads, run one after the other in separate processes (`--squad=mixed|rigs`): a mixed Condemned squad, and a
## squad of War Rigs (`gang_tank`, 3.32 × 14 m, the widest and longest hull).
##
## The instrument is `WallContact` (game/ai/wall_contact.gd): every unit-tick a hull's slide touched a wall, with its
## cause (bake / route / avoid / steer / plant), the layer that drove it, the collider and the lane.
##
## PASS (the brief's): every unit arrives on every leg; zero wall contacts for the mixed squad; the rigs' contacts named
## by cause. Prints `NAV_DRIVE_LEG <json>` per leg and `NAV_DRIVE <json>` at the end (with `"pass"`); exits 1 only if it
## could not run.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const ROSTERS := {
	"mixed": ["tank", "ifv", "scout", "lancer", "artillery", "ifv"],
	"rigs": ["gang_tank", "gang_tank", "gang_tank", "gang_tank"],
}
## The course. Each point sits on a declared lane (Arena.active's `lanes`), so a contact's lane name says which street.
const LEGS := [
	{"name": "ring road", "to": [-40.0, 30.0]},
	{"name": "west street", "to": [-70.0, -10.0]},
	{"name": "plaza", "to": [0.0, 0.0]},
	{"name": "far ring road", "to": [40.0, -30.0]},
]
## A crew counts as arrived when its order completed within this of its own slot goal (order_probe's FAR_M).
const ARRIVED_M := 7.0

var game_match: Match
var orders: Orders
var units: Array[Tank] = []
var leg_index := -1
var leg_started_tick := 0
var leg_goal := {}         # name -> slot goal Orders gave it this leg (Vector3)
var leg_done := {}         # name -> seconds to completion
var leg_contacts_before := {}
var leg_results: Array = []
var time_per_leg := 90.0
var squad_kind := "mixed"
## Round 11 (R1): gear changes (cusps) per unit, the brief's second observable, counted here from the plant's own
## signed speed with a CUSP_SPEED dead band (a hull rolling at 0.1 m/s either way is not changing gear). A three-point
## turn is 2 cusps; a good fix moves cusps EARLIER and makes them fewer per manoeuvre, it does not remove them.
const CUSP_SPEED := 0.3
var gear_of := {}          # name -> last gear (+1 / -1)
var cusps := {}            # name -> gear changes
var reverse_ticks := 0     # unit-ticks rolling backward faster than CUSP_SPEED


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	time_per_leg = float(_flag("leg-time", "90"))
	squad_kind = _flag("squad", "mixed")
	if not ROSTERS.has(squad_kind):
		push_error("nav-terminus-drive: --squad=%s; have %s" % [squad_kind, ROSTERS.keys()])
		quit(1)
		return
	var arena: Arena = ARENA.instantiate()
	arena.layout_name = _flag("arena", "terminus")
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
	if String(Arena.active.get("name", "")) != _flag("arena", "terminus"):
		push_error("nav-terminus-drive control FAILED: asked for %s, built %s (lesson 80)" % [_flag("arena", "terminus"), Arena.active.get("name", "?")])
		quit(1)
		return
	var roster: Array = ROSTERS[squad_kind]
	var error := game_match.load_doctrine(Match.Team.GREEN, {"name": "NavDrive",
			"squads": [{"name": "S0", "units": roster.map(func(unit: String) -> Dictionary: return {"unit": unit})}]})
	if error != "":
		push_error("nav-terminus-drive: " + error)
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
	for frame in SimClock.TICK_RATE:
		await physics_frame
	WallContact.reset()
	Movement.reset_route_arms()
	print("NAV_DRIVE_ARM press=%s inflate=%s nosestop=%s oriented=%s off=%s" % [Movement.press_on(), Movement.inflate_on(),
			Movement.nose_stop_on(), Avoidance.oriented_on(), Movement._off])
	print("NAV_DRIVE_CONTROL arena %s squad %s units %d (%s)" % [Arena.active.get("name", "?"), squad_kind, units.size(),
			", ".join(units.map(func(t: Tank) -> String: return t.unit_id))])
	_next_leg()
	physics_frame.connect(_sample)


func _next_leg() -> void:
	leg_index += 1
	leg_goal = {}
	leg_done = {}
	leg_contacts_before = WallContact.by_cause.duplicate()
	leg_started_tick = game_match.tick
	if leg_index >= LEGS.size():
		return
	var names: Array = units.map(func(t: Tank) -> String: return String(t.name))
	# `source: player`, as `RtsControls` stamps a right-click (rts_controls.gd): the path the lead drives, and the one
	# R2b's goal grounding applies to (control grounds player orders only).
	var result := orders.issue(UnitCommand.make(names, "move", {"to": LEGS[leg_index]["to"], "source": "player"}))
	if result != "":
		push_error("nav-terminus-drive: " + result)


func _sample() -> void:
	var elapsed := float(game_match.tick - leg_started_tick) / float(SimClock.TICK_RATE)
	for tank in units:
		var speed := tank.speed()
		if absf(speed) < CUSP_SPEED:
			continue
		var gear := 1 if speed > 0.0 else -1
		if gear < 0:
			reverse_ticks += 1
		var key := String(tank.name)
		if gear_of.has(key) and int(gear_of[key]) != gear:
			cusps[key] = int(cusps.get(key, 0)) + 1
		gear_of[key] = gear
	for tank in units:
		var key := String(tank.name)
		if leg_done.has(key):
			continue
		var g: Variant = orders.goal_position(key)
		if g != null:
			leg_goal[key] = g
		elif leg_goal.has(key) and orders.is_idle(key):
			leg_done[key] = elapsed
	if leg_done.size() == units.size() or elapsed >= time_per_leg:
		_close_leg(elapsed)
		_next_leg()
		if leg_index >= LEGS.size():
			_report()


func _close_leg(elapsed: float) -> void:
	var arrived := 0
	var misses: Array = []
	for tank in units:
		var key := String(tank.name)
		var gap := _flat(tank.global_position, leg_goal[key]) if leg_goal.has(key) else -1.0
		if leg_done.has(key) and gap >= 0.0 and gap <= ARRIVED_M:
			arrived += 1
		else:
			var reading := Movement.state(tank)
			misses.append({"unit": key, "id": tank.unit_id, "gap_m": snappedf(gap, 0.1),
					"completed": leg_done.has(key), "phase": String(reading.get("phase", "?")),
					"blocked_by": String(reading.get("blocked_by", "")), "reachable": bool(reading.get("reachable", true)),
					"goal_off_mesh_m": snappedf(float(reading.get("goal_gap_m", 0.0)), 0.1),
					"goal": [snappedf(leg_goal[key].x, 0.1), snappedf(leg_goal[key].z, 0.1)] if leg_goal.has(key) else null,
					# What the crew was ACTUALLY driving to (the controller's move order, which Movement's goal_gap_m
					# measures), beside Orders' published goal above and the verb Orders holds for it (squad's ask).
					"move_order": _move_order_of(tank), "orders_verb": String((orders.call("current", key) as Dictionary).get("verb", "")),
					"at": [snappedf(tank.global_position.x, 0.1), snappedf(tank.global_position.z, 0.1)]})
	var contacts := {}
	for cause: String in WallContact.by_cause:
		var n := int(WallContact.by_cause[cause]) - int(leg_contacts_before.get(cause, 0))
		if n > 0:
			contacts[cause] = n
	var times: Array = leg_done.values()
	times.sort()
	var row := {"leg": LEGS[leg_index]["name"], "to": LEGS[leg_index]["to"], "seconds": snappedf(elapsed, 0.1),
			"arrived": arrived, "units": units.size(), "last_done_s": snappedf(times[-1], 0.1) if not times.is_empty() else -1.0,
			"contact_unit_ticks": contacts, "misses": misses}
	leg_results.append(row)
	print("NAV_DRIVE_LEG %s" % JSON.stringify(row))


func _report() -> void:
	physics_frame.disconnect(_sample)
	var arrived_all := leg_results.all(func(row: Dictionary) -> bool: return int(row["arrived"]) == int(row["units"]))
	var report := WallContact.report()
	# Every episode (unit, cause, collider), uncapped, longest first.
	var episodes: Array = WallContact.episodes.values()
	episodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["ticks"]) > int(b["ticks"]))
	var mixed_ok := squad_kind != "mixed" or int(report["contact_unit_ticks"]) == 0
	var out := {"arena": String(Arena.active.get("name", "?")), "squad": squad_kind, "units": units.size(),
			"legs": leg_results.size(), "arrived_every_leg": arrived_all, "wall_contacts": report,
			"route_arms": Movement.route_arms(), "off": Array(Movement._off), "seed": int(_flag("seed", "1")),
			"cusps": cusps.values().reduce(func(a: int, b: int) -> int: return a + b, 0), "cusps_by_unit": cusps,
			"reverse_unit_ticks": reverse_ticks,
			"episodes": episodes.slice(0, 40), "pass": arrived_all and mixed_ok and int(report["observed_unit_ticks"]) > 0}
	print("NAV_DRIVE %s" % JSON.stringify(out))
	quit(0)


func _move_order_of(tank: Tank) -> Variant:
	var brain := game_match.brains.get_node_or_null(NodePath("Brain_" + String(tank.name))) as OrderController
	if brain == null:
		return null
	var order: Dictionary = brain.move_order
	return {"type": order.get("type"), "x": snappedf(float(order.get("x", 0.0)), 0.1), "z": snappedf(float(order.get("z", 0.0)), 0.1)}


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

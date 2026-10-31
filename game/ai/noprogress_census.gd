class_name NoProgressCensus
extends RefCounted
## Round 47 (manoeuvre M3, Bar M's deciding instrument): **crew-seconds with no progress toward the seat.** Measurement only:
## nothing here changes a command, and it reads the navigation server directly (no project memo, no path budget), so a run with
## it is the same match as one without.
##
## His words (2026-10-30): a crew "drove straight forward into a building and got stuck", "vehicles getting stuck behind containers".
## M1's trace: what he saw was a crew not getting closer to where its squad was taking it while the squad drove on. So, per crew,
## about every SAMPLE_TICKS while the crew has a `move_to` order: the ROUTE distance from the crew to its
## FINAL goal (a brain's order goal, its seat; else the mover's goal). A sample counts NO PROGRESS (SAMPLE_TICKS of crew-time) when
## that distance has not fallen by PROGRESS_M since the sample WINDOW_SAMPLES before, the crew is more than FAR_M from the goal,
## and the goal is the same one (within GOAL_SAME_M; a new order restarts the window). A crew he HOLDs is not driving (no drive
## tick), so it never counts.
##
## `--noprogress-census` turns it on; NOPROGRESS <json> is printed every PRINT_EVERY_TICKS with the running totals per team
## ({"0": {"s": crew-seconds, "n": crews seen, "worst": [crew, s], "contact_s": sampled crew-seconds touching a wall or prop}, "1": ...});
## the last line is the run's.

const SAMPLE_TICKS := SimClock.TICK_RATE / 2
const WINDOW_SAMPLES := 2
const PROGRESS_M := 1.0
const FAR_M := 15.0
const GOAL_SAME_M := 3.0
const PRINT_EVERY_TICKS := SimClock.TICK_RATE * 5

static var on := OS.get_cmdline_user_args().has("--noprogress-census")
## crew name -> [goal, [distances...]] ; totals per team.
static var _crews := {}
static var _seconds := {}
static var _team := {}
static var _last_print := -1
static var _sampled := {}
static var _contact := {}


static func reset() -> void:
	_sampled.clear()
	_contact.clear()
	_crews.clear()
	_seconds.clear()
	_team.clear()
	_last_print = -1


static var _installed := false


## Connects the sampler to the physics frame once (Movement._init calls it: GDScript on every path, native execute included). Every live mover with a `move_to` order is observed.
static func install() -> void:
	if _installed or not on:
		return
	_installed = true
	(Engine.get_main_loop() as SceneTree).physics_frame.connect(_sample)


static func _sample() -> void:
	var now := Engine.get_physics_frames()
	for id: int in Movement._registry:
		var mover: Movement = Movement._registry[id]
		if mover == null or not is_instance_valid(mover.ctl) or mover.ctl.tank == null or not mover.ctl.tank.is_alive():
			continue
		if String(mover.ctl.move_order.get("type", "")) != "move_to":
			continue
		observe(mover, now)


## Every sampled tick of every live crew with a move order.
static func observe(mover: Movement, now: int) -> void:
	var tank := mover.ctl.tank
	var name := String(tank.name)
	var last := int(_sampled.get(name, -1000000))
	if now - last < SAMPLE_TICKS:
		return
	var elapsed := minf(float(now - last), float(SAMPLE_TICKS) * 2.0) / SimClock.TICK_RATE  # a gap (no move order between) counts at most two samples
	_sampled[name] = now
	var goal := mover._goal
	var brain := mover.ctl as TankBrain
	if brain != null and not brain.order.is_empty() and brain.order.get("goal") is Vector3:
		goal = brain.order["goal"]
	if goal == Vector3.INF:
		return
	var map := tank.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, tank.global_position, goal, true)
	var to_go := 0.0
	var from := tank.global_position
	for point in path:
		to_go += Vector2(point.x - from.x, point.z - from.z).length()
		from = point
	if path.is_empty():
		to_go = Vector2(goal.x - tank.global_position.x, goal.z - tank.global_position.z).length()
	var held: Array = _crews.get(name, [])
	if held.is_empty() or Vector2((held[0] as Vector3).x - goal.x, (held[0] as Vector3).z - goal.z).length() > GOAL_SAME_M:
		held = [goal, []]
		_crews[name] = held
	var history: Array = held[1]
	history.append(to_go)
	if history.size() > WINDOW_SAMPLES + 1:
		history.pop_front()
	_team[name] = int(tank.team)
	if mover.contact.touching:
		_contact[name] = float(_contact.get(name, 0.0)) + elapsed  # a wall / prop contact on a drive tick (guard: brushing buildings)
	if history.size() > WINDOW_SAMPLES and to_go > FAR_M and float(history[0]) - to_go < PROGRESS_M:
		_seconds[name] = float(_seconds.get(name, 0.0)) + elapsed
	if _last_print < 0 or now - _last_print >= PRINT_EVERY_TICKS:
		_last_print = now
		var row := report()
		row["swaps"] = Movement.buried_swaps  # the buried rule's swaps so far (0 in an arm without it: the cells it touched)
		row["watch"] = NoProgressWatch.trips  # the no-progress watchdog's reroutes so far
		print("NOPROGRESS " + JSON.stringify(row))


static func report() -> Dictionary:
	var out := {}
	for name: String in _team:
		var key := str(_team[name])
		if not out.has(key):
			out[key] = {"s": 0.0, "n": 0, "worst": ["", 0.0], "contact_s": 0.0}
		var row: Dictionary = out[key]
		row["contact_s"] = float(row["contact_s"]) + float(_contact.get(name, 0.0))
		var s := float(_seconds.get(name, 0.0))
		row["s"] = float(row["s"]) + s
		row["n"] = int(row["n"]) + 1
		if s > float((row["worst"] as Array)[1]):
			row["worst"] = [name, s]
	return out

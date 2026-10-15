extends SceneTree
## Round 31 (planner P6): **how many hulls ask for a plan in one tick, in a real fight** — the number the per-tick
## slice's one-deep queue is sized by. Boots the real match (main.tscn with the flags after `--`, headless, fixed fps,
## the pattern of tests/nav/lever_drive_probe.gd), on the GDScript drive (`--brains-off=native`, so every plan event
## increments Movement's and Manoeuvre's statics), and every physics tick reads the plan-event counters today's code
## increments where it makes a plan of legs: `kturns` (a single reverse leg, or the circle plan), `kturn_multi` (a
## back-and-fill), `kturn_none` (asked, nothing fit), `face_plans` / `face_none` (a face at rest). The sum's change in a
## tick is the number of plan REQUESTS that tick would have made of the planner. At the end, one line:
##
##   PLANNER_CENSUS {"arena", "seed", "ticks", "hulls", "events", "ticks_with": {"1": n, "2": n, ...}, "max_per_tick",
##                   "per_tick_mean", "busiest_second": {"tick", "events"}, "by_kind": {...}}
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/planner/plan_census.gd -- --match --elimination \
##       --control --arena=sumps --green-doctrine=res://build/perf-armies/green_25.json --rust-doctrine=... \
##       --budget=100000 --time-limit=120 --seed=92721 --green-elements --rust-elements --brains-off=native

var _match: Node = null
var _ticks := 0
var _limit_ticks := 0
var _last := {}
var _events := 0
var _histogram := {}
var _max := 0
var _max_at := 0
var _by_kind := {}
var _window: Array[int] = []   # events in the last 30 ticks
var _busiest_second := 0
var _busiest_at := 0
var _hulls := 0
var _reported := false
var _seed := ""
## `--plan-probe=N`: every N ticks, plan one offline fixture (the T-junction rig, PlannerFixtures) on the native
## path INSIDE the running fight and keep its microseconds: the price of a plan under a fight's load (C31.5's
## "foundry 25 a side" number). Measurement only: the plan is thrown away, nothing in the fight reads it.
var _probe_every := 0
var _probe_usec: PackedInt64Array = []
var _probe_expansions := 0
var _probe_path := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var flags := LaunchFlags.from_environment()
	_seed = flags.text("seed", "1")
	_limit_ticks = int(float(flags.text("time-limit", "120")) * SimClock.TICK_RATE) - 10
	_probe_every = int(flags.text("plan-probe", "0"))
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(_tick)


func _find_match(node: Node) -> Node:
	if node is Match:
		return node
	for child in node.get_children():
		var found := _find_match(child)
		if found != null:
			return found
	return null


func _counters() -> Dictionary:
	return {"kturn": Movement.kturns, "kturn_multi": Movement.kturn_multi, "kturn_none": Movement.kturn_none,
			"circle": Movement.kturn_circle, "face": Manoeuvre.face_plans, "face_none": Manoeuvre.face_none}


func _tick() -> void:
	if _match == null:
		_match = _find_match(root)
		if _match == null:
			return
		_last = _counters()
	_ticks += 1
	var now := _counters()
	var here := 0
	for kind: String in now:
		var d := int(now[kind]) - int(_last[kind])
		if kind == "circle":
			d = 0  # the circle plan also bumps `kturns`: counted there
		if d > 0:
			_by_kind[kind] = int(_by_kind.get(kind, 0)) + d
			here += d
	_last = now
	_events += here
	if here > 0:
		_histogram[str(here)] = int(_histogram.get(str(here), 0)) + 1
	if here > _max:
		_max = here
		_max_at = _ticks
	_window.append(here)
	if _window.size() > SimClock.TICK_RATE:
		_window.pop_front()
	var in_window := 0
	for e in _window:
		in_window += e
	if in_window > _busiest_second:
		_busiest_second = in_window
		_busiest_at = _ticks
	var tanks: Node = _match.get("tanks")
	if tanks != null and _ticks % 30 == 0:
		var alive := 0
		for tank: Node in tanks.get_children():
			if tank is Tank and (tank as Tank).is_alive():
				alive += 1
		_hulls = maxi(_hulls, alive)
	if _probe_every > 0 and _ticks % _probe_every == 0:
		var req := PlannerFixtures.t_junction("gang_tank")
		req.budget = 3000
		var t0 := Time.get_ticks_usec()
		var plan := Planner.plan(req)
		_probe_usec.append(Time.get_ticks_usec() - t0)
		_probe_expansions = plan.expansions
		_probe_path = "native" if Planner.native_usable() else "gdscript"
	if _ticks >= _limit_ticks:
		_report()


func _finalize() -> void:
	if not _reported:
		_report()


func _report() -> void:
	_reported = true
	var row := {"arena": String(Arena.active.get("name", "")) if Arena.active != null else "", "seed": _seed, "ticks": _ticks,
			"hulls": _hulls, "events": _events, "ticks_with": _histogram, "max_per_tick": _max, "max_at_tick": _max_at,
			"per_tick_mean": snappedf(float(_events) / maxf(float(_ticks), 1.0), 0.0001),
			"busiest_second": {"tick": _busiest_at, "events": _busiest_second}, "by_kind": _by_kind,
			"off": Array(Movement._off), "native": BrainSwitches.native}
	if _probe_usec.size() > 0:
		var sorted := Array(_probe_usec)
		sorted.sort()
		row["plan_probe"] = {"path": _probe_path, "fixture": "T-junction rig", "expansions": _probe_expansions,
				"plans": sorted.size(), "min_us": sorted[0], "median_us": sorted[sorted.size() / 2], "max_us": sorted[-1]}
	print("PLANNER_CENSUS " + JSON.stringify(row))
	quit(0)

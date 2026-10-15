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
## `--plan-probe=N`: every N ticks, plan INSIDE the running fight on the native path and keep the microseconds: the
## price of a plan under a fight's load (C31.5's "foundry 25 a side" number; SLICE is chosen from it). Two probes a
## turn: the offline T-junction fixture (rectangles: the search's own price) and THE SEAM'S OWN REQUEST for a live hull
## (a face-about on the arena's navmesh with the fight's hulls, `PlannerSeam.BUDGET` / `HORIZON_M`, as `_request`
## builds it): the field's cells through the C++ cache, cold on the first plans and warm later, so the row keeps the
## first-quarter and last-quarter medians apart. Measurement only: the plans are thrown away, nothing in the fight reads them.
var _probe_every := 0
var _probe_usec: PackedInt64Array = []
var _probe_expansions := 0
var _probe_path := ""
var _nav_usec: PackedInt64Array = []
var _nav_expansions: PackedInt64Array = []
var _nav_codes := {}
## R31.7: the events BY HULL CLASS (the seam's scope is chosen from it): per tick, per controller, a Movement that
## ENTERS a k-turn leg (`in_kturn()` false -> true: the single reverse, the back-and-fill, the circle plan) or a face
## plan (`_face_legs` or `_face_left_m` from empty / 0: a plan_face that fit), attributed to its hull's length class
## (`long` = PlannerSeam.SCOPE_MIN_HULL_M and over, else `short`). A plan refused today (kturn_none / face_none) has
## no leg to enter and is not here; the statics above count it.
var _was_kturn := {}
var _was_face := {}
var _by_hull := {"long": {"kturn": 0, "face": 0, "hulls": 0}, "short": {"kturn": 0, "face": 0, "hulls": 0}}
var _short_usec: PackedInt64Array = []
var _short_expansions: PackedInt64Array = []
var _short_codes := {}


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
	_attribute()
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
		var hull := _a_live_hull(tanks, true)
		if hull != null:
			var nav_req := _face_about(hull, tanks)
			var t1 := Time.get_ticks_usec()
			var nav_plan := Planner.plan(nav_req)
			_nav_usec.append(Time.get_ticks_usec() - t1)
			_nav_expansions.append(nav_plan.expansions)
			_nav_codes[nav_plan.code] = int(_nav_codes.get(nav_plan.code, 0)) + 1
		var short_hull := _a_live_hull(tanks, false)
		if short_hull != null:
			var short_req := _face_about(short_hull, tanks)
			var t2 := Time.get_ticks_usec()
			var short_plan := Planner.plan(short_req)
			_short_usec.append(Time.get_ticks_usec() - t2)
			_short_expansions.append(short_plan.expansions)
			_short_codes[short_plan.code] = int(_short_codes.get(short_plan.code, 0)) + 1
	if _ticks >= _limit_ticks:
		_report()


## The longest live hull (a War Rig when one lives: the seam's customer), or the shortest (the hull the seam never
## takes: the comparison row), else null.
func _a_live_hull(tanks: Node, longest: bool) -> Tank:
	if tanks == null:
		return null
	var best: Tank = null
	var best_len := -1.0 if longest else INF
	for node: Node in tanks.get_children():
		var tank := node as Tank
		if tank == null or not tank.is_alive():
			continue
		var box: Array = Movement.hull_box(tank.unit_id)
		if (longest and float(box[2]) > best_len) or (not longest and float(box[2]) < best_len):
			best_len = float(box[2])
			best = tank
	return best


## The plan events this tick, by the hull class that made them (see `_by_hull`).
func _attribute() -> void:
	var brains: Node = _match.get("brains")
	if brains == null:
		return
	for child in brains.get_children():
		var ctl := child as OrderController
		if ctl == null or ctl.movement == null or ctl.tank == null:
			continue
		var mover: Movement = ctl.movement
		var name := String(ctl.tank.name)
		var cls := "long" if PlannerSeam.in_scope(ctl.tank.unit_id) else "short"
		if not _was_kturn.has(name):
			_by_hull[cls]["hulls"] = int(_by_hull[cls]["hulls"]) + 1
		var kturn := mover.in_kturn()
		if kturn and not bool(_was_kturn.get(name, false)):
			_by_hull[cls]["kturn"] = int(_by_hull[cls]["kturn"]) + 1
		_was_kturn[name] = kturn
		var face: bool = mover._face_left_m > 0.0 or not mover._face_legs.is_empty()
		if face and not bool(_was_face.get(name, false)):
			_by_hull[cls]["face"] = int(_by_hull[cls]["face"]) + 1
		_was_face[name] = face


## PlannerSeam._request's "face" request, turned about: the seam's own ask for this hull, here, now.
func _face_about(tank: Tank, tanks: Node) -> PlanRequest:
	var req := PlanRequest.for_unit(tank.unit_id)
	var here := tank.global_position
	var forward := Vector3(-tank.global_basis.z.x, 0.0, -tank.global_basis.z.z).normalized()
	req.at(here.x, here.z, forward.x, forward.z)
	var stay := maxf(Movement.settle_radius(tank.unit_id) - 1.0, 1.5)
	req.to(here.x, here.z, -forward.x, -forward.z, stay, PlannerSeam.FACE_TOL_DEG)
	req.arrive_gear = 0
	req.budget = PlannerSeam.BUDGET
	req.horizon_m = PlannerSeam.HORIZON_M
	req.in_world(PlannerNavWorld.for_tank(tank, tanks))
	return req


static func _quartiles(values: Array) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	var n := sorted.size()
	var first := sorted.slice(0, maxi(n / 4, 1))
	var last := sorted.slice(n - maxi(n / 4, 1), n)
	return {"n": n, "min": sorted[0], "median": sorted[n / 2], "max": sorted[-1],
			"first_quarter_median": first[first.size() / 2], "last_quarter_median": last[last.size() / 2]}


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
	if _nav_usec.size() > 0:
		# In the order planned (cold first): the first and last quarters' medians are the cold and the warm price.
		var usec := Array(_nav_usec)
		var exps := Array(_nav_expansions)
		var q := _nav_usec.size() / 4
		var per: Array = []
		for i in usec.size():
			per.append(float(usec[i]) / maxf(float(exps[i]), 1.0))
		var early := per.slice(0, maxi(q, 1))
		var late := per.slice(per.size() - maxi(q, 1), per.size())
		early.sort()
		late.sort()
		row["nav_probe"] = {"path": _probe_path, "fixture": "a live hull's face-about on the arena navmesh (the seam's request)",
				"plans": usec.size(), "codes": _nav_codes, "usec": _quartiles(usec), "expansions": _quartiles(exps),
				"us_per_expansion": {"early_median": snappedf(early[early.size() / 2], 0.1), "late_median": snappedf(late[late.size() / 2], 0.1)},
				"cache": Planner.native_cache_stats()}
	if _short_usec.size() > 0:
		var susec := Array(_short_usec)
		var sexps := Array(_short_expansions)
		var sper: Array = []
		for i in susec.size():
			sper.append(float(susec[i]) / maxf(float(sexps[i]), 1.0))
		sper.sort()
		row["nav_probe_short"] = {"fixture": "the shortest live hull's face-about (never in scope)", "plans": susec.size(),
				"codes": _short_codes, "usec": _quartiles(susec), "expansions": _quartiles(sexps),
				"us_per_expansion_median": snappedf(sper[sper.size() / 2], 0.1)}
	print("PLANNER_CENSUS " + JSON.stringify(row))
	quit(0)

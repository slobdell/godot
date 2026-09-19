extends SceneTree
## `make nav-maze` (arena X1, round 6, contract N3 / checkpoint CP2): send a horde across The Maze and report what
## happened to it. This is NAV'S ACCEPTANCE TEST, so it deliberately measures only things a stopwatch and a tape
## measure could see -- positions over time -- and never reaches into how movement is implemented. nav can rewrite
## everything under the order and this probe keeps meaning the same thing.
##
##   .tools/.../godot --headless --path . --script res://tests/arena/maze_probe.gd -- \
##       --units=30 --arena=maze --time-limit=180 --seed=1 --json=build/nav-maze.json [--both-ways]
##
## Every unit is ordered to the 180 deg mirror of its own spawn point, so each has its own goal (a single shared
## goal would measure a pile-up at the destination, not the crossing) and the whole force has to cross the arena.
## `--both-ways` splits the units between the two bases so the two streams meet HEAD-ON in the shared corridor --
## the peer-to-peer right-of-way case the lead described ("an in-game command could be sent peer to peer between
## units to move out of the way"). One-way traffic never exercises it, so a green one-way run proves less than it
## looks. Both sides still hold fire: this is a driving test, and a firefight would end it before the far side.
## It prints `NAV_MAZE <json>`:
##   units, arrived, arrived_fraction            how many got there
##   t50_s, t90_s, t100_s                        seconds until 50 / 90 / 100% had arrived (-1 = never)
##   crawl_unit_seconds, crawl_share             unit-seconds under CRAWL_SPEED while still under way
##   stuck_events, stuck_units                   times a unit made no progress for STUCK_SECONDS (and how many did)
##   off_navmesh                                 units further than OFF_NAVMESH_M from the navmesh at the end
##   worst                                       the five units that got least far, with their final distance
##   progress_m, distance_m                      metres advanced vs metres of route they were given
## and exits 1 if it could not even run (no arena, no navmesh), never on a bad result: a red number is a finding
## for nav to act on, not a broken tool.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
## Within this of its goal counts as arrived: a hull is up to 5 m long and this is a crossing test, not a parking test.
const ARRIVE_M := 8.0
## "Crawling": slower than this while still under way. A tank's top speed is ~11 m/s; 0.5 m/s is walking pace.
const CRAWL_SPEED := 0.5
## No progress toward the goal for this long is one stuck event (matched to OrderController's own stall clock).
const STUCK_SECONDS := 3.0
## Further than this (measured FLAT: x/z only) from the nearest navmesh point and the unit has been pushed off the
## drivable surface. Flat because a hull's centre sits ~0.7 m above the mesh and a 3D distance charges that height to
## every unit, turning "hugging a wall" into "off the map".
const OFF_NAVMESH_M := 3.0

var game_match: Match
var arena: Arena
var units: Array[Tank] = []
var goals := {}          # tank name -> Vector3
var route_m := {}        # tank name -> metres of navmesh route it was given at t0
var arrived_at := {}     # tank name -> seconds
var best_remaining := {} # tank name -> closest it has come to its goal
var stall_seconds := {}  # tank name -> seconds since it last improved on best_remaining
var stuck_events := {}   # tank name -> count
## Round 8: the lead's stall, measured as OSCILLATION rather than blockage (pre-registration in
## _agents/streams/references/arena/stuck_preregistration.md, committed before this code existed).
##
## "Moving back and forth indefinitely trying to get unstuck" is not `blocked`: a unit that is MOVING fails a
## speed test, so a blocked-by-terrain counter reads zero while the player watches a vehicle shuffle in place.
## Over a window, a unit that is going somewhere has net displacement close to its path length; a unit shuffling
## has a large path and almost no net. The ratio separates them and is scale-free, so it needs no per-unit tuning.
const WINDOW_S := 4.0
const OSCILLATE_PATH_M := 8.0
const OSCILLATE_RATIO := 0.25
## The third pre-registered measure, and the one that covers the gap between the other two. `crawl` catches a unit
## too SLOW to be going anywhere (< 0.5 m/s); `oscillating` catches one travelling far enough to be obviously
## shuffling (>= 8 m of path). **A unit creeping back and forth at 1-2 m/s is neither** -- too fast to crawl, too
## little path to oscillate -- and that is exactly what being pinned against a barrier end looks like. `no_progress`
## asks the question directly: over the window, did this unit get any closer to where it was sent?
const PROGRESS_M := 2.0
var trail := {}            # tank name -> Array[Vector3], one per tick over the window
var goal_trail := {}       # tank name -> Array[float], distance to goal per tick
var oscillating_ticks := {}
var no_progress_ticks := {}
var crawl_ticks := 0
var under_way_ticks := 0
var time_limit := 180.0
var reported := false


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	var layout := _flag("arena", "maze")
	var wanted := int(_flag("units", "30"))
	time_limit = float(_flag("time-limit", "180"))
	arena = ARENA.instantiate()
	arena.layout_name = layout
	root.add_child(arena)
	game_match = MATCH.instantiate()
	root.add_child(game_match)
	game_match.seed_spawns(int(_flag("seed", "1")), 0.0)
	game_match.elimination = true
	if Arena.active.get("name", "") != layout:
		push_error("nav-maze: arena %s did not load" % layout)
		quit(1)
		return
	await physics_frame
	for frame in 300:
		if Pathing.is_ready(arena):
			break
		await physics_frame
	if not Pathing.is_ready(arena):
		push_error("nav-maze: %s's navmesh never synced -- the fixture is broken, not the movement" % layout)
		quit(1)
		return
	_deploy(wanted)
	physics_frame.connect(_sample)


## The crossing force, ordered straight across. One way by default (all green); `--both-ways` alternates the sides so
## the two streams meet head-on. Everyone holds fire either way: this measures driving, and a firefight would end the
## run before the far side was reached.
func _deploy(wanted: int) -> void:
	var both_ways := OS.get_cmdline_user_args().has("--both-ways")
	# A layout has a fixed number of spawn points (52 today) and `Arena.spawn_spot` wraps with `slot % size`, so
	# asking for more units than that lands pairs on the same spot. Offset the surplus laterally by half a column
	# so `--units=N` really does mean N distinct start points: the run should BE the experiment it names, rather
	# than the probe refusing to run it.
	var spots: int = (Arena.active.get("spawns", {}).get("green", []) as Array).size()
	for i in wanted:
		var team: int = Match.Team.RUST if both_ways and i % 2 == 1 else Match.Team.GREEN
		var tank := game_match.spawn_tank("Cross_%d" % i, 0, team, "tank")
		if tank == null:
			break
		var goal := -tank.global_position
		goal.y = 0.0
		var controller := OrderController.new()
		controller.name = "Orders_Cross_%d" % i
		controller.tank = tank
		controller.tanks_root = game_match.tanks
		game_match.brains.add_child(controller)
		controller.set_orders({"type": "move_to", "x": goal.x, "z": goal.z}, {"type": "hold_fire"})
		if spots > 0 and tank.slot >= spots:
			# Half a column (columns are 11 m apart), alternating, so an offset unit never lands on another spawn.
			var wraps := int(tank.slot / spots)
			tank.global_position += Vector3(5.5 * (1.0 if wraps % 2 == 1 else -1.0), 0.0, 0.0)
			if tank.has_method("reset_physics_interpolation"):
				tank.reset_physics_interpolation()
		units.append(tank)
		var key := String(tank.name)
		goals[key] = goal
		best_remaining[key] = _flat(tank.global_position, goal)
		stall_seconds[key] = 0.0
		stuck_events[key] = 0
		route_m[key] = _path_length(Pathing.find_path(arena, tank.global_position, goal))
	print("NAV_MAZE_DEPLOYED %d units on %s%s" % [units.size(), Arena.active.get("name", "?"),
			" (both ways)" if both_ways else " (one way)"])
	_positive_control(wanted, both_ways)


## POSITIVE CONTROL: assert the run is the run we think it is, from INSIDE it.
##
## Every wrong number this stream published would have been caught by one of three assertions — the map is the one
## named, the objectives are where the layout says, the armies are the size requested. A fixed measurement window
## stops a metric being *gamed*; only an assertion inside the run catches the setup silently not being what you
## asked for. (combat's idea, after two of its runs measured a different game than it thought and no check caught
## either.)
##
## The case that proves it here is real and cost a published baseline: a layout has 52 spawn points and
## `Arena.spawn_spot` wraps with `slot % size`, so `NAV_UNITS=60` put **eight pairs of hulls in eight positions**
## and those never moved. Eight phantom stragglers in every 60-unit run, attributed to congestion, until nav found
## it by asking WHICH units failed. `no two units start on top of each other` would have caught it on the first run.
##
## A failed control exits 1: a number from a run whose conditions were not met is worse than no number, because it
## looks exactly like a real one.
##
## **A control states the condition it checked and what it therefore refuses to report. It does not explain why the
## condition matters.** The first version of this one added "and those hulls cannot move, so every arrival number
## below would be wrong" — a DIAGNOSIS the control cannot verify, and one that had gone stale a round earlier:
## coincident hulls part by name since round 6 (`avoidance.gd`, "two hulls on the same spot"). It was true when it
## was written and false when it was read. **A stale diagnosis in a failure message is worse than one in a
## document, because it arrives at the moment someone is deciding what to do** — that sentence nearly had nav's
## 60/60 arrival result held out of a merge as void.
func _positive_control(wanted: int, both_ways: bool) -> void:
	var problems: Array = []
	var arena_name := String(Arena.active.get("name", ""))
	var asked := _flag("arena", "maze")
	if arena_name != asked:
		problems.append("asked for arena '%s' and got '%s'" % [asked, arena_name])
	if units.size() != wanted:
		problems.append("asked for %d units and deployed %d (the layout may have fewer spawn slots)"
				% [wanted, units.size()])
	var coincident := 0
	for i in units.size():
		for j in range(i + 1, units.size()):
			if units[i].global_position.distance_to(units[j].global_position) < 1.0:
				coincident += 1
	if coincident > 0:
		problems.append("%d pairs of units started on top of each other: spawn slots wrapped, so this run is not "
				% coincident + "the experiment named (%d distinct start points)" % wanted)
	# Every unit must start somewhere it can drive from. Cheap, and it is the condition the surplus-unit offset
	# above could plausibly break: shifting a hull half a column sideways could put it inside cover on a layout
	# whose spawn zone is tighter than the maze's.
	var map := arena.get_world_3d().navigation_map
	var stranded := 0
	for tank in units:
		var at := tank.global_position
		if Vector2(at.x, at.z).distance_to(_flat_of(NavigationServer3D.map_get_closest_point(map, at))) > 3.0:
			stranded += 1
	if stranded > 0:
		problems.append("%d units started off the navmesh, so they cannot be given a route" % stranded)
	var teams := {}
	for tank in units:
		teams[tank.team] = true
	if both_ways and teams.size() < 2:
		problems.append("--both-ways asked for head-on traffic and every unit is on one side")
	if not both_ways and teams.size() > 1:
		problems.append("one-way run has units on both sides")
	if problems.is_empty():
		print("NAV_MAZE_CONTROL ok: %s, %d units, %d side(s), no coincident spawns, all on the navmesh"
				% [arena_name, units.size(), teams.size()])
		return
	for problem: String in problems:
		push_error("nav-maze control FAILED: %s" % problem)
	print("NAV_MAZE_CONTROL FAILED %s" % JSON.stringify(problems))
	quit(1)


func _sample() -> void:
	if reported:
		return
	var dt := 1.0 / float(SimClock.TICK_RATE)
	var elapsed := float(game_match.tick) * dt
	for tank in units:
		var key := String(tank.name)
		if arrived_at.has(key):
			continue
		var remaining := _flat(tank.global_position, goals[key])
		if remaining <= ARRIVE_M:
			arrived_at[key] = elapsed
			continue
		under_way_ticks += 1
		if tank.speed() < CRAWL_SPEED:
			crawl_ticks += 1
		_sample_trail(tank, key)
		# Progress is measured against the BEST it has ever done, not against the last tick: a unit shuffling back
		# and forth in a gap moves every tick and arrives never, and that is exactly the failure we are counting.
		if remaining < best_remaining[key] - 0.5:
			best_remaining[key] = remaining
			stall_seconds[key] = 0.0
		else:
			stall_seconds[key] += dt
			if stall_seconds[key] >= STUCK_SECONDS:
				stuck_events[key] += 1
				stall_seconds[key] = 0.0
	if arrived_at.size() == units.size() or elapsed >= time_limit:
		_report(elapsed)


## One tick of the oscillation window for `tank`.
func _sample_trail(tank: Tank, key: String) -> void:
	var span_goal := int(WINDOW_S * SimClock.TICK_RATE)
	var goals: Array = goal_trail.get(key, [])
	goals.append(_flat(tank.global_position, goals_of(key)))
	if goals.size() > span_goal:
		goals.remove_at(0)
	goal_trail[key] = goals
	if goals.size() == span_goal and float(goals[0]) - float(goals[goals.size() - 1]) < PROGRESS_M:
		no_progress_ticks[key] = int(no_progress_ticks.get(key, 0)) + 1
	var history: Array = trail.get(key, [])
	history.append(tank.global_position)
	var span := int(WINDOW_S * SimClock.TICK_RATE)
	if history.size() > span:
		history.remove_at(0)
	trail[key] = history
	if history.size() < span:
		return
	var path := 0.0
	for i in range(1, history.size()):
		path += _flat(history[i - 1], history[i])
	if path < OSCILLATE_PATH_M:
		return  # not moving enough to be "moving back and forth"; that is the blocked case, counted separately
	if _flat(history[0], history[history.size() - 1]) / path < OSCILLATE_RATIO:
		oscillating_ticks[key] = int(oscillating_ticks.get(key, 0)) + 1


func _total(counter: Dictionary) -> int:
	var sum := 0
	for tank in units:
		sum += int(counter.get(String(tank.name), 0))
	return sum


func _with_any(counter: Dictionary) -> int:
	var count := 0
	for tank in units:
		if int(counter.get(String(tank.name), 0)) > 0:
			count += 1
	return count


func _report(elapsed: float) -> void:
	reported = true
	var times: Array = arrived_at.values()
	times.sort()
	var at := func(fraction: float) -> float:
		var need := int(ceil(float(units.size()) * fraction))
		return snappedf(times[need - 1], 0.01) if need > 0 and times.size() >= need else -1.0
	var stuck_units := 0
	var total_stuck := 0
	var progress := 0.0
	var route_total := 0.0
	var finals: Array = []
	for tank in units:
		var key := String(tank.name)
		total_stuck += int(stuck_events[key])
		if int(stuck_events[key]) > 0:
			stuck_units += 1
		var start_distance := _flat(Match.spawn_position(tank.team, tank.slot), goals[key])
		progress += maxf(0.0, start_distance - _flat(tank.global_position, goals[key]))
		route_total += float(route_m[key])
		finals.append({"unit": key, "remaining_m": snappedf(_flat(tank.global_position, goals[key]), 0.1),
				"arrived_s": snappedf(float(arrived_at.get(key, -1.0)), 0.01), "stuck_events": int(stuck_events[key])})
	finals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["remaining_m"] > b["remaining_m"])
	var map := arena.get_world_3d().navigation_map
	var off := 0
	for tank in units:
		if _flat(tank.global_position, NavigationServer3D.map_get_closest_point(map, tank.global_position)) > OFF_NAVMESH_M:
			off += 1
	var oscillating_total := 0
	var oscillating_units := 0
	for tank in units:
		var ticks := int(oscillating_ticks.get(String(tank.name), 0))
		oscillating_total += ticks
		if ticks > 0:
			oscillating_units += 1
	var out := {
		"arena": String(Arena.active.get("name", "?")), "units": units.size(), "seconds": snappedf(elapsed, 0.01),
		# THE LEAD'S STALL. Separate from `crawl_*`, which is the blocked case: a unit can be in one, the other,
		# both or neither, and reporting them pooled would hide exactly the distinction being tested.
		"oscillating_unit_seconds": snappedf(float(oscillating_total) / float(SimClock.TICK_RATE), 0.1),
		"oscillating_share": snappedf(float(oscillating_total) / maxf(1.0, float(under_way_ticks)), 0.001),
		"oscillating_units": oscillating_units,
		"no_progress_unit_seconds": snappedf(float(_total(no_progress_ticks)) / float(SimClock.TICK_RATE), 0.1),
		"no_progress_share": snappedf(float(_total(no_progress_ticks)) / maxf(1.0, float(under_way_ticks)), 0.001),
		"no_progress_units": _with_any(no_progress_ticks),
		"both_ways": OS.get_cmdline_user_args().has("--both-ways"),
		"time_limit_s": time_limit, "arrived": arrived_at.size(),
		"arrived_fraction": snappedf(float(arrived_at.size()) / maxf(1.0, float(units.size())), 0.001),
		"t50_s": at.call(0.5), "t90_s": at.call(0.9), "t100_s": at.call(1.0),
		"crawl_unit_seconds": snappedf(float(crawl_ticks) / float(SimClock.TICK_RATE), 0.1),
		"crawl_share": snappedf(float(crawl_ticks) / maxf(1.0, float(under_way_ticks)), 0.001),
		"stuck_events": total_stuck, "stuck_units": stuck_units, "off_navmesh": off,
		"progress_m": snappedf(progress, 0.1), "distance_m": snappedf(route_total, 0.1),
		"worst": finals.slice(0, 5),
	}
	print("NAV_MAZE %s" % JSON.stringify(out))
	var path := _flag("json", "")
	if path != "":
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(out, "\t") + "\n")
			file.close()
			print("NAV_MAZE_JSON %s" % path)
	quit(0)


func goals_of(key: String) -> Vector3:
	return goals[key]


func _flat_of(a: Vector3) -> Vector2:
	return Vector2(a.x, a.z)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total

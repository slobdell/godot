extends SceneTree
## Round 43 (engage A4, Bar A's workload): HIS TURNAROUND AS A PROBE. Two friendly squads of one side meet head-on in a street
## (round 29 T1's stage): squad A comes out of the open toward the street and WAITS (its lead reaches the middle later), squad
## B comes through. A's front rank is at the stage's start; A's REAR crews stand FAR_MIN..FAR_MAX m behind it (by seed), well
## beyond the spot grid's reach (HOLD_BACK_M's 43 m + a hull): his lead War Rig, 80 m from the mouth. One run = one seed; the
## arm is Traffic's `holdfar` (`--traffic-on=holdfar`; OFF = round 29's rule: every crew of the waiting squad is dealt a spot at
## the mouth). Arena, hulls, the far distance and the jitter are drawn from the seed, so the two arms see the same stage.
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/engage/hold_probe.gd -- --seed=N [--stage=terminus_west] [--seconds=75]
##         [--traffic-on=holdfar] [--trace=on]
## Prints ENGAGE_HOLD {json} once (read by tests/engage/hold_table.py):
##   away_s        crew-seconds (A's crews) UNDER A STREET HOLD with the distance to their own K1 goal rising (> AWAY_M a second):
##                 driving away from where they were sent to reach a hold spot (the deciding line; his War Rig: 15 s)
##   away_m        the largest rise of that distance under a hold, any crew (his: 82 m)
##   held_s        crew-seconds holding (Traffic.holding), a_held_s the same for A's crews (A waited at all: the exercised test);
##                 held_off_s / held_on_s: A's crews the stage says never route through the street (`off_street`) / the others;
##                 off_arrive_s the mean arrival of those off-street crews (-1 when the stage has none): Bar A6's deciding line
##                 far_released / far_held: Traffic's counters
##   arrive_a_s    seconds until each A crew is within ARRIVED_M of A's destination (the window when never); last_a_s the last;
##                 far_arrive_s the mean over A's far crews (the crews the rule is about: what the player sees of them)
##   arrive_b_s    the same for B
##   contacts      friendly hull contacts (box gap < CONTACT_GAP_M, counted once per touch), contacts_fast (closing > 2 m/s),
##                 contacts_cross (between the two squads), contacts_mouth (within MOUTH_R_M of the street's middle),
##                 contacts_far (a touch involving one of A's far crews within MOUTH_R_M of the middle while B is still coming):
##                 round 29 T1's purpose, and the released far crew meeting the passer (R43.8's guard)
##   stuck_s       crew-seconds under STILL_MPS before arriving (both squads), jam_s the same within MOUTH_R_M of the middle

const STILL_MPS := 0.5
const CONTACT_GAP_M := 0.15
const FAST_CONTACT_MPS := 2.0
const ARRIVED_M := 20.0
const AWAY_M := 1.0
const MOUTH_R_M := 25.0
const JITTER_M := 1.5
const SQUAD_PITCH_M := 9.0
const FAR_MIN_M := 55.0
const FAR_MAX_M := 95.0
## The stages (by seed): round 29 T1's head-on meeting in Terminus's west street (blocks at x -120..-80 and -60..-20, z -20..20),
## its mirror in the east street, and the Locks' LOCK (the 16 m deck over the canal, walled by water both sides: a one-lane
## crossing, his attack-move across the canal). Squad A's start and destination, squad B's start and destination (B starts
## lead INSIDE the street on terminus, so A, still in the open, waits; dev 7002 with B at -30 had B wait), the street's middle.
## A starts 40-50 m from the middle so
## that its rear rank, 55-95 m further back, stays inside the arena (the first terminus stage at 75 m had the clamp pull the rear
## rank in to 42 m: inside the grid's reach). yard_open and the Locks' west quay were tried (dev 7001 / 7003): no street there.
const STAGES := [
	{"name": "terminus_west", "arena": "terminus", "a": [Vector3(-70, 0, 50), Vector3(-70, 0, -55)], "b": [Vector3(-70, 0, -15), Vector3(-70, 0, 75)], "middle": Vector3(-70, 0, 0)},
	{"name": "terminus_east", "arena": "terminus", "a": [Vector3(70, 0, 50), Vector3(70, 0, -55)], "b": [Vector3(70, 0, -15), Vector3(70, 0, 75)], "middle": Vector3(70, 0, 0)},
	{"name": "locks_lock", "arena": "locks", "a": [Vector3(0, 0, 40), Vector3(0, 0, -70)], "b": [Vector3(0, 0, -40), Vector3(0, 0, 70)], "middle": Vector3(0, 0, 0)},
]
## R43.12's SIDE-STREET stage, his geometry planted (Locks, seed 56416, tick 478): squad A's lead crew stands in the east-west
## corridor between the block at (-30, 42) (40 m square, north edge z 62) with the container_40 at (-30, 66) and the two
## container_20s at (-42, 80) / (-20, 80): a street ~10 m wide at z 68-77. It has just been told to go SOUTH-WEST (the far quay
## over the west swing bridge) and its NOSE is still east (his Guns_3, yielding); squad B (his Hunters) comes WEST through the
## corridor at it. Traffic reads a head-on meeting in a street, A waits, and A's way is read from its crews' noses (east), so the
## spots go behind the corridor's mouth: north and east, off every A crew's route. A's far crews stand where his War Rigs stood,
## 60-80 m south-west, their seats south: in round 29's rule they are sent to the spots (AWAY); under holdfar they are released.
## Explicit placements ([x, z, yaw deg], his census at tick 480; yaw -90 = nose east); `middle` is the corridor's west end.
## The planting that fires: Terminus's west street (blocks at x -120..-80 and -60..-20, z -20..20, 40 m walls). Squad A has
## just been told to go EAST along the north ring road (its destination (30, 40)); its lead crew stands at the street's north
## mouth with its NOSE SOUTH, into the street (his Guns_3, yielding into the corridor), in the open (z 24, past the blocks'
## end), two squadmates beside it, and its far crews 65-75 m EAST near the destination. Squad B comes NORTH through the street
## at it. Traffic reads a head-on meeting in a street; A's lead is in the open and B's inside it, so A waits whatever the
## speeds; A's way reads south (its crews' noses), so the spots go behind the mouth: north of the blocks, 55-70 m WEST of the
## far crews' seats: AWAY from where they were sent (his geometry). Under holdfar the far crews are released (their route
## east never passes the west street). Yaw 0 = nose south (-z), 180 = north, -90 = east.
const SIDE_STAGE := {"name": "terminus_side", "arena": "terminus", "a_to": Vector3(30, 0, 40), "b_to": Vector3(-70, 0, 75),
	"a_crews": [[-70.0, 24.0, 0.0], [-62.0, 30.0, 0.0], [-78.0, 30.0, 0.0], [-8.0, 58.0, -90.0], [2.0, 52.0, -90.0]],
	"b_crews": [[-70.0, 2.0, 180.0], [-67.0, -8.0, 180.0], [-73.0, -8.0, 180.0], [-70.0, -17.0, 180.0], [-70.0, -26.0, 180.0]],
	"middle": Vector3(-70, 0, 10), "off_street": [3, 4]}
## R43.12 asked for a side-street workload with his AWAY geometry as a second deciding line, time-boxed. Four plantings (dev
## 7007-7013, laptop) failed to make it: (1) his corridor with the leads inside it: the verdict went to B on half the seeds
## (both leads "in the open" by the 6 m containers, the tie by speed); (2) A's lead west of the corridor: its own route found
## the BRIDGE as the mouth (on the squad's way); (3) both leads inside: the meeting's middle fell between the containers (no
## street) on 3 of 4 seeds; (4) this terminus stage: every seed a verdict, but the mouth lands on A's own way east, or at the
## far crews' feet when they are the farthest along the squad's mean heading (the lead), so no crew drives away. The stage is
## kept for `--stage=terminus_side` and the record; Bar A's seeds all cycle the head-on stages (R43.12's line (1) alone).
const SIDE_SEEDS_ODD := true
## His case's hulls first (gangs: three War Rigs); the other draws keep a squad of 14 m hulls and lighter ones.
const HULL_SETS := [
	["gang_tank", "gang_tank", "gang_ifv", "gang_tank", "gang_support"],
	["law_tank", "law_ifv", "law_scout", "law_tank", "law_ifv"],
	["gang_tank", "gang_ifv", "gang_scout", "gang_tank", "gang_scout"],
	["tank", "ifv", "scout", "tank", "ifv"],
]

var case: TestCase


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _r(x: float) -> float:
	return snappedf(x, 0.1)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	BrainSwitches.ensure_parsed()
	var seed_value := int(_flag("seed", "10301"))
	var seconds := float(_flag("seconds", "75"))
	var trace := _flag("trace", "off") == "on"
	var stage: Dictionary = SIDE_STAGE if SIDE_SEEDS_ODD and seed_value % 2 == 1 else STAGES[(seed_value / 2) % STAGES.size()]
	for candidate: Dictionary in STAGES + [SIDE_STAGE]:
		if String(candidate["name"]) == _flag("stage", ""):
			stage = candidate
	var arena := String(stage["arena"])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var hulls: Array = HULL_SETS[rng.randi_range(0, HULL_SETS.size() - 1)]
	var far_m := rng.randf_range(FAR_MIN_M, FAR_MAX_M)
	Traffic.reset_counters()
	Traffic.log_waits = trace
	var lab := TacticsLab.create(case, seed_value, arena)
	var game_match := lab.game_match
	game_match.set_meta("player_team", Match.Team.GREEN)
	var members := {}
	var far_crews: Array = []
	if stage.has("a_crews"):
		# The planted stage: every crew where the stage says, the hull set's hulls in order; A's last two are the far crews.
		for squad: String in ["a", "b"]:
			var names: Array = []
			var crews: Array = stage[squad + "_crews"]
			for i in crews.size():
				var c: Array = crews[i]
				var at := Vector3(float(c[0]) + rng.randf_range(-JITTER_M, JITTER_M), 0.0, float(c[1]) + rng.randf_range(-JITTER_M, JITTER_M))
				var face := deg_to_rad(float(c[2]) + rng.randf_range(-8.0, 8.0))
				var unit_name := "Green_%s_%d" % [squad.to_upper(), i + 1]
				names.append(String(lab.unit(Match.Team.GREEN, unit_name, at, face, String(hulls[i])).name))
				if squad == "a" and i >= crews.size() - 2:
					far_crews.append(unit_name)
			members[squad] = names
		stage = stage.duplicate()
		stage["a"] = [Vector3((stage["a_crews"][0] as Array)[0], 0.0, (stage["a_crews"][0] as Array)[1]), stage["a_to"]]
		stage["b"] = [Vector3((stage["b_crews"][0] as Array)[0], 0.0, (stage["b_crews"][0] as Array)[1]), stage["b_to"]]
	for squad: String in (["a", "b"] if not stage.has("a_crews") else []):
		var from: Vector3 = stage[squad][0]
		var to: Vector3 = stage[squad][1]
		var along := (to - from).normalized()
		var across := Vector3(-along.z, 0.0, along.x)
		var yaw := atan2(-along.x, -along.z)
		var names: Array = []
		for i in hulls.size():
			var rank := float(i / 3)
			var file := float(i % 3) - 1.0
			var back := rank * SQUAD_PITCH_M
			# A's rear rank stands far behind the front (his War Rig); B's is a loose block.
			if squad == "a" and rank >= 1.0:
				back = far_m + (file + 1.0) * 4.0
			var at := from + across * file * SQUAD_PITCH_M - along * back \
					+ Vector3(rng.randf_range(-JITTER_M, JITTER_M), 0.0, rng.randf_range(-JITTER_M, JITTER_M))
			at = ElementPlan.clamp_to_arena(at)
			var face := yaw + deg_to_rad(rng.randf_range(-10.0, 10.0))
			var unit_name := "Green_%s_%d" % [squad.to_upper(), i + 1]
			names.append(String(lab.unit(Match.Team.GREEN, unit_name, at, face, String(hulls[i])).name))
			if squad == "a" and rank >= 1.0:
				far_crews.append(unit_name)
		members[squad] = names
	await lab.start()
	var far_actual := 0.0
	for unit_name: String in far_crews:
		if stage.has("a_crews"):
			far_actual = maxf(far_actual, _flat(lab.tank_of(unit_name).global_position).distance_to(stage["middle"]))
			continue
		var a_along: Vector3 = ((stage["a"][1] as Vector3) - (stage["a"][0] as Vector3)).normalized()
		far_actual = maxf(far_actual, -(_flat(lab.tank_of(unit_name).global_position) - (stage["a"][0] as Vector3)).dot(a_along))
	var everyone: Array = []
	for squad: String in ["a", "b"]:
		for unit_name: String in members[squad]:
			var t := lab.tank_of(unit_name)
			var at := SlotGround.for_unit(t, t.global_position, String(t.unit_id))
			t.global_position = Vector3(at.x, 0.0, at.z)
			t.velocity = Vector3.ZERO
			everyone.append(unit_name)
	for i in 3:
		await lab.step()
	var elements := {}
	for squad: String in ["a", "b"]:
		var element := lab.elements.form(members[squad], "Squad" + squad.to_upper())
		var to: Vector3 = stage[squad][1]
		element.assign({"verb": "move", "to": [to.x, to.z]})
		elements[squad] = element
	var given: int = game_match.tick
	var orders := lab.orders
	var middle: Vector3 = stage["middle"]
	var away_s := 0.0
	var away_m := 0.0
	var held_s := 0.0
	var a_held_s := 0.0
	# Round 43 (Bar A6): the crews the stage says never route through the street (`off_street`, indices into A), and A's others.
	var off_crews: Array = []
	for i: int in stage.get("off_street", []):
		off_crews.append("Green_A_%d" % (int(i) + 1))
	var held_off_s := 0.0
	var held_on_s := 0.0
	var stuck_s := 0.0
	var jam_s := 0.0
	var arrive := {}
	var last_goal_d := {}  # crew -> [distance to its K1 goal a second ago, the goal it was measured against]
	var nearest := {}
	var in_contact := {}
	var contacts := 0
	var contacts_fast := 0
	var contacts_cross := 0
	var contacts_mouth := 0
	var contacts_far := 0
	var b_through := false
	var rows := 0
	var total := int(seconds * SimClock.TICK_RATE)
	for tick in total:
		await lab.step()
		var now := game_match.tick - given
		var hulls_alive: Array = []
		for unit_name: String in everyone:
			var t := lab.tank_of(unit_name)
			if t != null and t.is_alive():
				hulls_alive.append(t)
		# B is through once every B crew is on A's side of the middle (past it along B's way).
		if not b_through:
			var b_along: Vector3 = ((stage["b"][1] as Vector3) - (stage["b"][0] as Vector3)).normalized()
			b_through = true
			for unit_name: String in members["b"]:
				var t := lab.tank_of(unit_name)
				if t != null and t.is_alive() and (_flat(t.global_position) - middle).dot(b_along) < 8.0:
					b_through = false
					break
		# Contacts (once per touch), by pair.
		for i in hulls_alive.size():
			for j in range(i + 1, hulls_alive.size()):
				var a: Tank = hulls_alive[i]
				var b: Tank = hulls_alive[j]
				var key := "%s|%s" % [a.name, b.name]
				var touching := TrafficStage.box_gap(a, b) < CONTACT_GAP_M
				if touching and not in_contact.get(key, false):
					contacts += 1
					if TrafficStage.closing_speed(a, b) > FAST_CONTACT_MPS:
						contacts_fast += 1
					var squad_a := "a" if String(a.name).begins_with("Green_A_") else "b"
					var squad_b := "a" if String(b.name).begins_with("Green_A_") else "b"
					if squad_a != squad_b:
						contacts_cross += 1
					var near_mouth := _flat(a.global_position).distance_to(middle) <= MOUTH_R_M \
							or _flat(b.global_position).distance_to(middle) <= MOUTH_R_M
					if near_mouth:
						contacts_mouth += 1
						if (far_crews.has(String(a.name)) or far_crews.has(String(b.name))) and not b_through:
							contacts_far += 1
				in_contact[key] = touching
		# Once a second: the hold / away / stuck / arrival lines.
		if now % SimClock.TICK_RATE != 0:
			continue
		for squad: String in ["a", "b"]:
			var to: Vector3 = stage[squad][1]
			for unit_name: String in members[squad]:
				var t := lab.tank_of(unit_name)
				if t == null or not t.is_alive():
					continue
				var here := _flat(t.global_position)
				var d_to := here.distance_to(to)
				nearest[unit_name] = minf(float(nearest.get(unit_name, INF)), d_to)
				if not arrive.has(unit_name) and d_to <= ARRIVED_M:
					arrive[unit_name] = float(now) / SimClock.TICK_RATE
				var speed := Vector2(t.estimated_velocity.x, t.estimated_velocity.z).length()
				if not arrive.has(unit_name) and speed < STILL_MPS:
					stuck_s += 1.0
					if here.distance_to(middle) <= MOUTH_R_M:
						jam_s += 1.0
				var holding := Traffic.holding(unit_name)
				if holding:
					held_s += 1.0
					if squad == "a":
						a_held_s += 1.0
						if off_crews.has(unit_name):
							held_off_s += 1.0
						else:
							held_on_s += 1.0
				# Away: the distance to its own K1 goal rising while under a hold.
				var order: Dictionary = orders.call("current", unit_name)
				var goal: Variant = order.get("goal")
				if goal is Array and (goal as Array).size() >= 2:
					var g := Vector3(float(goal[0]), 0.0, float(goal[1]))
					var d_goal := here.distance_to(g)
					var was: Variant = last_goal_d.get(unit_name)
					if was is Array and ((was as Array)[1] as Vector3).distance_to(g) < 2.0:
						var rise: float = d_goal - float((was as Array)[0])
						if holding and rise > AWAY_M:
							away_s += 1.0
							away_m = maxf(away_m, rise + float((was as Array)[2]))
							last_goal_d[unit_name] = [d_goal, g, rise + float((was as Array)[2])]
							continue
					last_goal_d[unit_name] = [d_goal, g, 0.0]
				if trace and squad == "a":
					var mover := Movement.of(t)
					print("ENGAGE_HOLD_TRACE t=%d %s at (%.1f, %.1f) d_to %.1f goal %s holding %s phase %s" % [now, unit_name,
							here.x, here.z, d_to, goal, holding, mover.phase if mover != null else "-"])
					rows += 1
	var a_arrivals: Array = []
	var b_arrivals: Array = []
	var far_arrivals: Array = []
	for unit_name: String in far_crews:
		far_arrivals.append(float(arrive.get(unit_name, seconds)))
	var far_arrive_mean := 0.0
	for a: float in far_arrivals:
		far_arrive_mean += a / float(maxi(far_arrivals.size(), 1))
	var off_arrivals: Array = []
	for unit_name: String in off_crews:
		off_arrivals.append(float(arrive.get(unit_name, seconds)))
	var off_arrive_mean := -1.0
	if not off_arrivals.is_empty():
		off_arrive_mean = 0.0
		for a: float in off_arrivals:
			off_arrive_mean += a / float(off_arrivals.size())
	for unit_name: String in members["a"]:
		a_arrivals.append(float(arrive.get(unit_name, seconds)))
	for unit_name: String in members["b"]:
		b_arrivals.append(float(arrive.get(unit_name, seconds)))
	var report := Traffic.report()
	print("ENGAGE_HOLD %s" % JSON.stringify({"seed": seed_value, "arena": arena, "arm": "on" if not (Traffic.off("holdfar") and Traffic.off("holdway") and Traffic.off("holdroute")) else "off",
			"switches": ("holdfar " if not Traffic.off("holdfar") else "") + ("holdway " if not Traffic.off("holdway") else "") + ("holdroute" if not Traffic.off("holdroute") else ""),
			"stage": stage["name"], "hulls": hulls, "far_m": _r(far_actual), "far_drawn_m": _r(far_m), "far_crews": far_crews, "seconds": seconds,
			"away_s": away_s, "away_m": _r(away_m), "held_s": held_s, "a_held_s": a_held_s, "held_off_s": held_off_s, "held_on_s": held_on_s,
			"off_crews": off_crews, "off_arrive_s": _r(off_arrive_mean), "way_released": report.get("tr_way_released", 0),
			"route_ms_per_verdict": _r(float(report.get("tr_route_usec", 0)) / 1000.0 / float(maxi(int(report.get("tr_verdicts", 0)), 1))),
			"route_queries": report.get("tr_route_queries", 0),
			"far_released": report.get("tr_far_released", 0), "far_held": report.get("tr_far_held", 0),
			"verdicts": report.get("tr_verdicts", 0), "holds": report.get("tr_holds", 0),
			"arrive_a_s": a_arrivals, "last_a_s": a_arrivals.max(), "far_arrive_s": _r(far_arrive_mean), "far_arrivals": far_arrivals, "arrive_b_s": b_arrivals, "last_b_s": b_arrivals.max(),
			"nearest_a_m": members["a"].map(func(n: String) -> float: return _r(float(nearest.get(n, -1.0)))),
			"contacts": contacts, "contacts_fast": contacts_fast, "contacts_cross": contacts_cross, "contacts_mouth": contacts_mouth,
			"contacts_far": contacts_far, "stuck_s": stuck_s, "jam_s": jam_s, "b_through": b_through, "rows": rows}))
	print("ENGAGE_HOLD_DONE")
	lab.dispose()
	quit(0)

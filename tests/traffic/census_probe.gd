extends SceneTree
## Round 26 (traffic T1/T3): THE CLUMP CENSUS. His hypothesis: *"If I was able to induce such congestion on a simple
## case, there's likely congestion problems when armies get clumped together"*. A CPU-v-CPU fight (both sides under the
## computer's squad leaders, as `make army-series` sets it up) where every tick every crew whose mover is under way and
## that has not moved STILL_MPS in the last second is counted as stuck, labelled by what is in its way (C26.5's labels,
## computed here so the census does not wait on manoeuvre's counters): a FRIENDLY hull, an ENEMY hull (a box within
## WAY_GAP_M ahead along where it is trying to go), or STATIC (nothing: a wall, a rock, the water's edge, or simply
## nowhere to go). Also friendly contacts (and those closing over 2 m/s) and k-turns started with a friend at the nose.
##
##   godot --headless --path . --script res://tests/traffic/census_probe.gd -- --arena=sumps --seed=1
##         --green=law --rust=gangs --credits=1000 --army=opponent --seconds=120
##   TRAFFIC_CENSUS {"arena", "seed", "units": [g, r], "under_way_s", "stuck_s", "stuck_friend_s", "stuck_enemy_s",
##                   "stuck_static_s", "friend_share", "contacts_friend", "contacts_friend_fast", "kturns",
##                   "kturns_friend", "ended_s"}

const STILL_MPS := 0.5
const NEAR_M := 18.0
## Round 30 (T1c-b, the orchestrator's addition (a)): a refused asker that is not past the set-up hull this long after the
## refusal (s) never went round.
const GO_ROUND_S := 20.0

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
	BrainSwitches.ensure_parsed()
	TacticsFlags.requested()
	var seed_value := int(_flag("seed", "1"))
	var arena := _flag("arena", "sumps")
	var credits := int(_flag("credits", "1000"))
	var kind := _flag("army", "opponent")
	var factions := {Match.Team.GREEN: _flag("green", "law"), Match.Team.RUST: _flag("rust", "gangs")}
	var army_probe: GDScript = load("res://tests/tactics/army_probe.gd")
	var lab := TacticsLab.create(case, seed_value, arena)
	lab.game_match.control_point = true
	lab.game_match.load_objectives()
	var units := [0, 0]
	for team: int in factions:
		var built: Dictionary = army_probe.army(String(factions[team]), seed_value * 2 + team, credits, kind)
		if built.has("error"):
			push_error("census: %s" % built["error"])
			quit(1)
			return
		var doctrine: Dictionary = built["doctrine"]
		for squad: Dictionary in doctrine["squads"]:
			units[team] += (squad["units"] as Array).size()
		var error := lab.game_match.load_doctrine(team, doctrine)
		if error != "":
			push_error("census load_doctrine: %s" % error)
			quit(1)
			return
	await lab.start()
	for team: int in factions:
		for squad in lab.game_match.team_squads(team):
			lab.elements.form(Array(squad.roster), String(squad.squad_name))
		ElementCommander.install(lab.game_match, team, lab.elements)
	var trails := {}
	# Round 30 (traffic T1c-b): a battery packing up (its legs were fully down and start to rise); those packed up while
	# giving way; and THE DEFECT: packed up while giving way to an ask it got ON ITS FIRE POST (set up, still ordered to
	# fire, no move of its own: Movement.on_fire_post the tick before the give-way began). Shots by artillery.
	var deployed := {}
	var on_post := {}
	var yield_from_post := {}
	var was_yielding := {}
	var art_shots := [0]
	var art_by := {}  # T1c-b's worst-run read: shots per battery; refusals per battery; seconds set up per battery
	var refused_by := {}
	var set_up_ticks := {}
	lab.game_match.weapon_fired.connect(func(event: Dictionary) -> void:
		var shooter := lab.tank_of(String(event.get("shooter", "")))
		if shooter != null and Units.role_of(shooter.unit_id) == "artillery":
			art_shots[0] += 1
			art_by[String(shooter.name)] = int(art_by.get(String(shooter.name), 0)) + 1)
	Movement.setup_refusals = 0
	# The orchestrator's additions: (a) does a refused asker GO ROUND? An episode per (asker, hull): resolved when the asker
	# is past the hull along the way it was going, or no longer under way; stuck when neither within GO_ROUND_S. (b) per side.
	Movement.setup_log = true
	Movement.setup_log_rows = []
	var episodes := {}  # "asker|hull" -> [frame, the asker's way (Vector2)]
	var side_counts := [{"repacks_while_firing": 0, "setup_refusals": 0, "went_round": 0, "never_past": 0},
			{"repacks_while_firing": 0, "setup_refusals": 0, "went_round": 0, "never_past": 0}]
	var in_contact := {}
	var was_kturn := {}
	var counts := {"under_way": 0, "stuck": 0, "friend": 0, "enemy": 0, "static": 0, "contacts": 0, "fast": 0,
			"kturns": 0, "kturns_friend": 0, "repacks": 0, "repacks_yield": 0, "repacks_while_firing": 0}
	var ended := -1
	for tick in int(float(_flag("seconds", "120")) * SimClock.TICK_RATE):
		await lab.step()
		var hulls: Array = []
		var alive := [0, 0]
		for child in lab.game_match.tanks.get_children():
			var t := child as Tank
			if t != null and t.is_alive():
				hulls.append(t)
				alive[t.team] += 1
		for row: Array in Movement.setup_log_rows:
			var asker := lab.tank_of(String(row[0]))
			var hull := lab.tank_of(String(row[1]))
			if asker == null or hull == null:
				continue
			side_counts[hull.team]["setup_refusals"] += 1
			refused_by[String(row[1])] = int(refused_by.get(String(row[1]), 0)) + 1
			var pair := "%s|%s" % [row[0], row[1]]
			if not episodes.has(pair):
				var way := Vector2(hull.global_position.x - asker.global_position.x, hull.global_position.z - asker.global_position.z)
				episodes[pair] = [int(row[2]), way.normalized()]
		Movement.setup_log_rows = []
		for pair: String in episodes.keys():
			var names := pair.split("|")
			var asker := lab.tank_of(names[0])
			var hull := lab.tank_of(names[1])
			var ep: Array = episodes[pair]
			if asker == null or hull == null or not asker.is_alive():
				episodes.erase(pair)
				continue
			var mover_a := Movement.of(asker)
			var past := Vector2(asker.global_position.x - hull.global_position.x,
					asker.global_position.z - hull.global_position.z).dot(ep[1]) > 0.0
			if past or mover_a == null or not mover_a.is_under_way():
				side_counts[asker.team]["went_round"] += 1
				episodes.erase(pair)
			elif Engine.get_physics_frames() - int(ep[0]) > GO_ROUND_S * SimClock.TICK_RATE:
				side_counts[asker.team]["never_past"] += 1
				episodes.erase(pair)
		for t: Tank in hulls:
			var key := String(t.name)
			var trail: PackedVector3Array = trails.get(key, PackedVector3Array())
			var here := Vector3(t.global_position.x, 0.0, t.global_position.z)
			trail.append(here)
			if trail.size() > SimClock.TICK_RATE + 1:
				trail.remove_at(0)
			trails[key] = trail
			var mover := Movement.of(t)
			if mover != null and t.deploy_seconds > 0.0:
				var yielding := mover.yield_to != ""
				if yielding and not bool(was_yielding.get(key, false)):
					yield_from_post[key] = bool(on_post.get(key, false))
				was_yielding[key] = yielding
				if bool(deployed.get(key, false)) and t.deploy_ratio < 1.0:
					counts["repacks"] += 1
					if yielding:
						counts["repacks_yield"] += 1
						if bool(yield_from_post.get(key, false)):
							counts["repacks_while_firing"] += 1
							side_counts[t.team]["repacks_while_firing"] += 1
				deployed[key] = t.deploy_ratio >= 1.0
				if t.deploy_ratio >= 1.0:
					set_up_ticks[key] = int(set_up_ticks.get(key, 0)) + 1
				on_post[key] = not yielding and mover.on_fire_post()
			if mover == null or not mover.is_under_way():
				continue
			counts["under_way"] += 1
			var turning := mover.in_kturn()
			if turning and not bool(was_kturn.get(key, false)):
				counts["kturns"] += 1
				var nose := Vector2(-t.global_basis.z.x, -t.global_basis.z.z).normalized()
				var ahead: Variant = _in_way(t, nose, hulls)
				if ahead != null and (ahead as Tank).team == t.team:
					counts["kturns_friend"] += 1
			was_kturn[key] = turning
			if trail.size() <= SimClock.TICK_RATE or trail[0].distance_to(here) >= STILL_MPS:
				continue
			counts["stuck"] += 1
			var blocker: Variant = _in_way(t, TrafficStage._way(t, mover), hulls)
			if blocker == null:
				counts["static"] += 1
			elif (blocker as Tank).team == t.team:
				counts["friend"] += 1
			else:
				counts["enemy"] += 1
		for i in hulls.size():
			var a: Tank = hulls[i]
			for j in range(i + 1, hulls.size()):
				var b: Tank = hulls[j]
				if a.team != b.team:
					continue
				var dx := a.global_position.x - b.global_position.x
				var dz := a.global_position.z - b.global_position.z
				if dx * dx + dz * dz > NEAR_M * NEAR_M:
					in_contact.erase("%s|%s" % [a.name, b.name])
					continue
				var pair := "%s|%s" % [a.name, b.name]
				var touching := TrafficStage.box_gap(a, b) <= TrafficStage.CONTACT_GAP_M
				if touching and not in_contact.get(pair, false):
					counts["contacts"] += 1
					if TrafficStage.closing_speed(a, b) > TrafficStage.FAST_CONTACT_MPS:
						counts["fast"] += 1
				in_contact[pair] = touching
		if alive[0] == 0 or alive[1] == 0:
			ended = tick
			break
	var s := func(ticks: int) -> float: return snappedf(float(ticks) / SimClock.TICK_RATE, 0.1)
	var report := {"arena": arena, "seed": seed_value, "army": kind, "green": factions[0], "rust": factions[1],
			"credits": credits, "units": units, "under_way_s": s.call(counts["under_way"]), "stuck_s": s.call(counts["stuck"]),
			"stuck_friend_s": s.call(counts["friend"]), "stuck_enemy_s": s.call(counts["enemy"]),
			"stuck_static_s": s.call(counts["static"]),
			"friend_share": snappedf(float(counts["friend"]) / maxf(counts["stuck"], 1), 0.001),
			"contacts_friend": counts["contacts"], "contacts_friend_fast": counts["fast"], "kturns": counts["kturns"],
			"kturns_friend": counts["kturns_friend"],
			"ended_s": snappedf(ended / float(SimClock.TICK_RATE), 0.1) if ended >= 0 else -1.0,
			"traffic_off": _flag("traffic-off", ""), "repacks": counts["repacks"], "repacks_yield": counts["repacks_yield"],
			"repacks_while_firing": counts["repacks_while_firing"], "setup_refusals": Movement.setup_refusals,
			"art_shots": art_shots[0], "by_side": side_counts, "go_round_pending": episodes.size(),
			"art_by": art_by, "refused_by": refused_by, "set_up_s": set_up_ticks.keys().map(
				func(k: String) -> Array: return [k, snappedf(set_up_ticks[k] / float(SimClock.TICK_RATE), 0.1)])}
	print("TRAFFIC_CENSUS " + JSON.stringify(report))
	lab.dispose()
	case.teardown()
	quit(0)


## The nearest hull (any team) whose box is within WAY_GAP_M of this one's and whose centre lies ahead along `way`.
static func _in_way(t: Tank, way: Vector2, hulls: Array) -> Variant:
	var best: Variant = null
	var best_gap := INF
	for other: Tank in hulls:
		if other == t:
			continue
		var offset := Vector2(other.global_position.x - t.global_position.x, other.global_position.z - t.global_position.z)
		var distance := offset.length()
		if distance < 0.01 or distance > NEAR_M or offset.dot(way) / distance < TrafficStage.AHEAD_COS:
			continue
		var gap := TrafficStage.box_gap(t, other)
		if gap <= TrafficStage.WAY_GAP_M and gap < best_gap:
			best = other
			best_gap = gap
	return best

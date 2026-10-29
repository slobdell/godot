extends SceneTree
## Round 45 (engage E3, Bar E1's workload): HIS CASE AS A PROBE. A crew he is steering near contact: alone (a squad of one,
## his Gorge scout) or one crew of a squad of three, driving toward an enemy gun that shoots back, gets ONE order of his
## 2.5 s in, given the way RtsControls gives it:
##   hold   a squad of one: a squad TASK (his Gorge hold); in a squad: half the seeds the whole squad's hold task, half a
##          direct hold to one crew
##   stop   direct (a squad of one's element is disbanded; a squad's crew leaves its element), as his S key does
##   move   a squad of one: a squad task with drills off (his right-click); in a squad: a direct move to one crew
## The crew's order then stands WINDOW_S. Then the take-back: his squad task to the whole squad (the group re-formed, as
## RtsControls' assign_task forms it) must reach the crew. Everything is drawn from the seed; the arm is
## `--player-authority=on|off`, so the two arms see the same stage and pair by seed.
##   godot --headless --fixed-fps 30 --path . --script res://tests/engage/authority_probe.gd -- --seed=N [--player-authority=off]
## Prints AUTHORITY_PROBE {json} once (tests/engage/authority_table.py):
##   moved_m       hold / stop: the farthest the ordered crew went from where it first came to rest after the order (braking
##                 is physics, not disobedience); move: -
##   pushed_rows   samples (every 3 ticks) while his order stands on which the crew's K1 order is an element's that sends it
##                 somewhere (attack, attack_move, or a move whose goal is over 3 m from the crew)
##   toward_m      how much nearer the enemy the crew ended the window than where it was when he ordered (+ = closer)
##   end_m         move: the crew's distance from his click at the end of the window; arrive_m the arrival radius
##   shots, hits   the ordered crew's rounds fired and hits on the enemy in the window (a held crew still shoots back)
##   died          the ordered crew died in the window; enemy_hp the gun's health left (fights)
##   taken_back    after the squad task: the crew's K1 order became the element's within 1 s

const ARENAS := ["gorge", "locks", "terminus", "crossing"]
const HULLS := ["gang_scout", "scout", "law_scout", "tank", "gang_ifv", "ifv", "syn_scout", "law_artillery"]
const VERBS := ["hold", "stop", "move"]
const ENEMY := ["tank", "ifv", "syn_artillery", "gang_ifv"]
const WINDOW_S := 15.0
const ORDER_AT_S := 2.5
const PUSH_M := 3.0

var case: TestCase


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _r(x: float) -> float:
	return snappedf(x, 0.1)


## A start for the squad: open ground `distance` from a gun spot, both standable, both well inside the arena.
func _stage(map: CoverMap, rng: RandomNumberGenerator, count: int, reach: float) -> Dictionary:
	var limit := Match.DRIVABLE_LIMIT - 15.0
	for attempt in 200:
		var gun := Vector3(rng.randf_range(-limit, limit), 0.0, rng.randf_range(-limit, limit))
		var bearing := rng.randf_range(0.0, TAU)
		var away := Vector3(sin(bearing), 0.0, cos(bearing))
		# Just outside the crew's own range: the squad's drive at the gun brings it into the fight before his order.
		var start := gun + away * (reach + rng.randf_range(5.0, 20.0))
		if absf(start.x) > limit or absf(start.z) > limit:
			continue
		var across := Vector3(-away.z, 0.0, away.x)
		var spots: Array = []
		for i in count:
			spots.append(start + across * (float(i) - (count - 1) * 0.5) * 9.0)
		var points := spots + [gun]
		if points.all(func(p: Vector3) -> bool: return not map.inside_any(Vector2(p.x, p.z), 4.0)):
			return {"gun": gun, "spots": spots, "away": away}
	return {}


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	BrainSwitches.ensure_parsed()  # `--brains-off=native` (the C45.4 arm) before anything reads a switch
	var seed_value := int(_flag("seed", "7001"))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var arena: String = _flag("arena", ARENAS[seed_value % ARENAS.size()])
	var hull: String = _flag("hull", HULLS[rng.randi_range(0, HULLS.size() - 1)])
	var enemy_unit: String = ENEMY[rng.randi_range(0, ENEMY.size() - 1)]
	var verb: String = _flag("verb", VERBS[rng.randi_range(0, VERBS.size() - 1)])
	var count := int(_flag("crews", str([1, 1, 3][rng.randi_range(0, 2)])))
	var squad_hold := count > 1 and verb == "hold" and rng.randf() < 0.5
	var lab := TacticsLab.create(case, seed_value, arena)
	var game_match := lab.game_match
	game_match.set_meta("player_team", Match.Team.GREEN)
	var reach := float(Weapons.profile(String(Units.stat(hull, "weapon"))).get("range", 60.0))
	var stage := _stage(CoverMap.of(game_match), rng, count, reach)
	var out := {"seed": seed_value, "arena": arena, "hull": hull, "enemy": enemy_unit, "verb": verb, "crews": count,
			"path": "", "arm": "off" if not Drills.PLAYER_AUTHORITY else "on"}
	if stage.is_empty():
		out["error"] = "no stage stands"
		print("AUTHORITY_PROBE " + JSON.stringify(out))
		quit(0)
		return
	var away: Vector3 = stage["away"]
	var yaw := atan2(away.x, away.z)  # facing the gun (forward is -Z)
	var names: Array = []
	for i in count:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1), stage["spots"][i], yaw, hull).name))
	var gun := lab.gun(Match.Team.RUST, "Rust_G_1", stage["gun"], yaw + PI, enemy_unit)
	var ordered := String(names[0])
	var shots := {"n": 0, "hits": 0}
	var shooters := {}
	game_match.weapon_fired.connect(func(event: Dictionary) -> void:
		shooters[int(event.get("projectile_id", -1))] = String(event.get("shooter", ""))
		if String(event.get("shooter", "")) == ordered and bool(shots.get("open", false)):
			shots["n"] = int(shots["n"]) + 1)
	game_match.projectile_impact.connect(func(event: Dictionary) -> void:
		if String(shooters.get(int(event.get("projectile_id", -1)), "")) == ordered and bool(shots.get("open", false)) \
				and float(event.get("damage", 0.0)) > 0.0:
			shots["hits"] = int(shots["hits"]) + 1)
	await lab.start()
	var orders: Orders = lab.orders
	# Driving at the enemy: his squad's move task toward the gun, drills on (an attack-move), as a squad closes before he
	# takes one crew in hand.
	var element := lab.elements.form(names, "Alpha")
	var toward_gun: Vector3 = _flat(stage["gun"]) + away * 20.0
	element.assign({"verb": "move", "to": [toward_gun.x, toward_gun.z]})
	for i in int(ORDER_AT_S * SimClock.TICK_RATE):
		await lab.step()
	var crew := lab.tank_of(ordered)
	if crew == null or not crew.is_alive():
		out["error"] = "the crew died before his order"
		print("AUTHORITY_PROBE " + JSON.stringify(out))
		quit(0)
		return
	var at_order := _flat(crew.global_position)
	var click := at_order + Vector3(-away.z, 0.0, away.x) * 18.0 + away * 10.0  # aside and back, out of the fight
	if verb == "hold" and (count == 1 or squad_hold):
		out["path"] = "task"
		element.assign({"verb": "hold"})
	elif verb == "move" and count == 1:
		out["path"] = "task"
		element.assign({"verb": "move", "to": [click.x, click.z], "drills": false})
	else:
		out["path"] = "direct"
		# RtsControls' direct order: a one-crew element is disbanded, a squad's crew leaves its element.
		if count == 1:
			lab.elements.disband(element)
		else:
			element.remove(ordered)
		var command := {"units": [ordered], "verb": verb, "source": "player"}
		if verb == "move":
			command["to"] = [click.x, click.z]
		var said := orders.issue(command)
		if said != "":
			out["error"] = "order refused: " + said
	shots["open"] = true
	var rest: Variant = null
	var moved := 0.0
	var pushed := 0
	var window := int(WINDOW_S * SimClock.TICK_RATE)
	for tick in window:
		await lab.step()
		if not crew.is_alive():
			break
		var here := _flat(crew.global_position)
		if rest == null and crew.estimated_velocity.length() < TankBrain.STOPPED_SPEED:
			rest = here
		if rest is Vector3:
			moved = maxf(moved, here.distance_to(rest))
		if _flag("trace", "off") == "on" and tick % 30 == 0:
			var brain := game_match.brains.get_node_or_null("Brain_" + ordered) as TankBrain
			print("AUTHORITY_TRACE t=%d pos=(%.1f, %.1f) v=%.1f order=%s/%s option=%s engaged=%s gun_visible=%s gap=%.1f" % [
					game_match.tick, here.x, here.z, crew.estimated_velocity.length(), orders.current(ordered).get("verb", "-"),
					orders.current(ordered).get("source", "-"), brain.choice.get("option", "") if brain != null else "-",
					brain.engaged_target if brain != null else "-", game_match.is_visible_to(Match.Team.GREEN, gun),
					here.distance_to(_flat(gun.global_position))])
		if tick % 3 == 0:
			var now := orders.current(ordered)
			if String(now.get("source", "")) == "element":
				var v := String(now.get("verb", ""))
				var goal: Variant = orders.goal_position(ordered)
				# His move task's own rows drive the crew to his click: only a goal elsewhere is the element's own idea.
				var elsewhere: bool = goal is Vector3 and (goal as Vector3).distance_to(here if verb != "move" else click) > PUSH_M
				if v == "attack" or v == "attack_move" or (v == "move" and elsewhere):
					pushed += 1
	shots["open"] = false
	var alive := crew.is_alive()
	var end := _flat(crew.global_position)
	out["moved_m"] = _r(moved) if verb != "move" else null
	out["rested"] = rest != null
	out["pushed_rows"] = pushed
	out["toward_m"] = _r(at_order.distance_to(_flat(stage["gun"])) - end.distance_to(_flat(stage["gun"])))
	out["end_m"] = _r(end.distance_to(click)) if verb == "move" else null
	out["end_phase"] = String(Movement.state(crew).get("phase", "")) if alive else "dead"
	# The crew's own arrival radius: the brain completes a move within it (wheeled hulls settle wider than Orders' 3 m).
	out["arrive_m"] = _r(maxf(TankBrain.ORDER_ARRIVE, Movement.settle_radius(crew.unit_id)))
	out["range_m"] = _r(reach)
	out["gap_at_order_m"] = _r(at_order.distance_to(_flat(stage["gun"])))
	out["shots"] = int(shots["n"])
	out["hits"] = int(shots["hits"])
	out["died"] = not alive
	out["enemy_hp"] = _r(gun.health) if gun.is_alive() else 0.0
	# The take-back: his squad task to the whole squad (the group re-formed, as assign_task forms it).
	out["taken_back"] = null
	if alive:
		var living := names.filter(func(n: String) -> bool: return lab.tank_of(n) != null and lab.tank_of(n).is_alive())
		var last_id := int(orders.current(ordered).get("id", -1))
		var squad := lab.elements.form(living, "Alpha")
		var back := at_order + away * 30.0
		squad.assign({"verb": "move", "to": [back.x, back.z], "drills": false})
		var taken := false
		for tick in SimClock.TICK_RATE:
			await lab.step()
			# Newest word wins: the crew is on the squad's new order (an element's, or for a squad of one his order itself,
			# which the element hands the crew as his) whose goal is his new point or the crew's slot round it.
			var now := orders.current(ordered)
			var goal: Variant = orders.goal_position(ordered)
			if not now.is_empty() and int(now.get("id", -1)) != int(last_id) and goal is Vector3 \
					and (goal as Vector3).distance_to(back) <= 20.0:
				taken = true
				break
		out["taken_back"] = taken
	out["native_decide"] = NativeDecide.usable()
	print("AUTHORITY_PROBE " + JSON.stringify(out))
	quit(0)

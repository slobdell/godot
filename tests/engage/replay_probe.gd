extends SceneTree
## Round 42 (engage E1): HIS CREW BEHIND THE CONTAINER, rebuilt. His recording
## (`_agents/streams/references/round42/engage/2026-10-26T14-15-45-locks.jsonl`, Locks, seed 49326, Gangs v Syndicate):
## his `attack` on Rust_Battery_1 (tick 3293) went to Green_Spears2_3 + Green_Spears2_4 (Rat Rods). Spears2_3 (17 hp)
## sat "arrived" at (44.3, -74.4) from tick 3240 to his move at 4350, 26 m from the Missile Ring at (24.3, -91.7), with
## the 20-ft container at (42, -80) between them; HUD: NOT FIRING. Spears2_4 at (46.4, -95.1) killed it.
##
## This probe stands the three hulls where the census put them, gives the squad his attack task, and prints one
## ENGAGE_TRACE line per sample tick (and on every change) for the crew: what the element issued it, what its brain
## chose and asked its mover, what the mover reports, what its gun is on, both sight reads (the crew's own ray, the
## team's intel) and the HUD's verdict mirrored from RtsControls.attack_shortfall.
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/engage/replay_probe.gd -- --seconds=40 --every=15
##         --hp=17 --crew=44.3,-74.4 --target=24.3,-91.7 [--second-crew=on|off]
##   ENGAGE_TRACE {...} per sample; ENGAGE_REPLAY {...} summary; ENGAGE_REPLAY_DONE

var case: TestCase


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _v(text: String) -> Vector3:
	var parts := text.split(",")
	return Vector3(float(parts[0]), 0.0, float(parts[1]))


func _r(x: float) -> float:
	return snappedf(x, 0.1)


## RtsControls.attack_shortfall, mirrored (the HUD's own words for this crew's attack order).
func _hud(game_match: Match, orders: Object, unit_name: String, target: Tank, engaged: String) -> String:
	var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
	if target == null or not target.is_alive() or tank == null:
		return ""
	if engaged == String(target.name):
		return ""
	if engaged != "":
		return "FIRING ON " + engaged
	var order: Dictionary = orders.call("current", unit_name)
	if String(order.get("target", "")) == String(target.name) and String(order.get("verb", "")) in ["move", "attack_move"]:
		return ""  # moving round
	if not game_match.is_visible_to(tank.team, target):
		return "CAN'T SEE TARGET"
	var out_of_range := tank.global_position.distance_to(target.global_position) > float(tank.weapon.get("range", 0.0))
	if out_of_range and tank.estimated_velocity.length() > 0.5:
		return ""
	return "NOT FIRING"


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	var seconds := float(_flag("seconds", "40"))
	var every := int(_flag("every", "15"))
	var crew_at := _v(_flag("crew", "44.3,-74.4"))
	var second_at := _v(_flag("second", "46.4,-95.1"))
	var target_at := _v(_flag("target", "24.3,-91.7"))
	var with_second := _flag("second-crew", "on") != "off"
	var lab := TacticsLab.create(case, int(_flag("seed", "49326")), "locks")
	var game_match := lab.game_match
	game_match.set_meta("player_team", Match.Team.GREEN)
	var toward := TacticsFormation.flat(target_at - crew_at)
	var yaw := atan2(-toward.x, -toward.z)
	var names: Array = []
	var crew := lab.unit(Match.Team.GREEN, "Green_Spears2_3", crew_at, yaw, "gang_scout")
	crew.health = int(_flag("hp", "17"))
	names.append(String(crew.name))
	if with_second:
		var second := lab.unit(Match.Team.GREEN, "Green_Spears2_4", second_at, yaw, "gang_scout")
		names.append(String(second.name))
	var target := lab.gun(Match.Team.RUST, "Rust_Battery_1", target_at, yaw + PI, "syn_artillery")
	# Kept alive so the window is his 37 s, not the time the other Rat Rod needs to kill it.
	target.max_health = 1_000_000
	target.health = 1_000_000
	await lab.start()
	var element := lab.elements.form(names, "Spears2")
	element.assign({"verb": "attack", "target": String(target.name), "formation": "echelon_right"})
	var brain := game_match.brains.get_node("Brain_" + String(crew.name)) as TankBrain
	var orders := lab.orders
	var last := ""
	var still_ticks := 0
	var moved_m := 0.0
	var last_pos := crew_at
	var cover := CoverMap.of(game_match)
	var rows := 0
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		if not crew.is_alive():
			break
		var pos := Vector3(crew.global_position.x, 0.0, crew.global_position.z)
		moved_m += pos.distance_to(last_pos)
		last_pos = pos
		var speed := Vector2(crew.estimated_velocity.x, crew.estimated_velocity.z).length()
		if speed < 0.5:
			still_ticks += 1
		var order: Dictionary = orders.call("current", String(crew.name))
		var mover := Movement.of(crew)
		var engaged := brain.engaged_target
		var ray := Perception.has_line_of_sight(crew, target)
		var row := {
			"tick": game_match.tick, "pos": [_r(pos.x), _r(pos.z)], "speed": _r(speed),
			"dist": _r(pos.distance_to(target_at)), "hp": crew.health,
			"order": String(order.get("verb", "")), "order_target": String(order.get("target", "")),
			"order_to": order.get("goal", null), "order_src": String(order.get("source", "")),
			"issued": String(element.issued_to(String(crew.name)).get("verb", "")),
			"task": element.task.get("verb", ""), "drill": element.drill, "why_el": element.reason,
			"choice": String(brain.choice.get("option", "")), "choice_target": String(brain.choice.get("target", "")),
			"why": brain.why,
			"move": String(brain.move_order.get("type", "")),
			"move_to": [_r(float(brain.move_order.get("x", 0.0))), _r(float(brain.move_order.get("z", 0.0)))]
					if brain.move_order.has("x") else null,
			"weapon": String(brain.weapon_order.get("type", "")),
			"phase": mover.phase if mover != null else "-", "blocked": mover.blocked_by if mover != null else "-",
			"stalled": mover.stalled_ticks if mover != null else -1,
			"goal": [_r(mover._goal.x), _r(mover._goal.z)] if mover != null and mover._goal != Vector3.INF else null,
			"engaged": engaged, "ray": ray, "map_clear": cover.clear_line(pos, target_at),
			"team_sees": game_match.is_visible_to(Match.Team.GREEN, target),
			"slot": brain.element.get("slot"), "role": brain.element.get("role", ""),
			"hud": _hud(game_match, orders, String(crew.name), target, engaged),
		}
		var key := "%s|%s|%s|%s|%s|%s" % [row["order"], row["choice"], row["move"], row["phase"], row["engaged"], row["hud"]]
		if key != last or tick % every == 0:
			print("ENGAGE_TRACE %s" % JSON.stringify(row))
			rows += 1
		last = key
	print("ENGAGE_REPLAY %s" % JSON.stringify({"seconds": seconds, "still_s": _r(float(still_ticks) / SimClock.TICK_RATE),
			"moved_m": _r(moved_m), "end_pos": [_r(last_pos.x), _r(last_pos.z)], "end_dist": _r(last_pos.distance_to(target_at)),
			"target_hp": target.health, "target_hits": 1_000_000 - target.health, "rows": rows}))
	print("ENGAGE_REPLAY_DONE")
	lab.dispose()
	quit(0)

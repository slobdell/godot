extends SceneTree
## Round 28 (brains B3): WHO ORDERS SCOUTS INTO THE ENEMY. Scout's census (`make scout-census`) counted most fixed-gun hull
## contacts with an enemy under an ordered MOVE (seed 5, Parade: Rust_Eyes4/5/6 into Green_Sirens round (0, -11)). This
## plays the same showmatch headless (main.tscn, the census's flags) and prints, every second, each element whose roster
## matches --recon-match (default "Eyes": the recon squads): its task, drill, the leader's reason, its centre, the task's point,
## and how far its nearest crew is from the nearest enemy it knows.
##
##   godot --headless --fixed-fps 60 --path . --script res://tests/tactics/recon_probe.gd -- --skirmish --demo-match
##         --clean --seed=5 --arena=random --mute [--seconds=60] [--recon-match=Eyes]
##   RECON t=<s> <element> task=<verb> to=<x,z> drill=<d> centre=<x,z> point_to_enemy=<m> nearest_enemy=<m> why=<reason>


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var game_match: Match = main.get("game_match")
	var seconds := float(_flag("seconds", "60"))
	var pattern := _flag("recon-match", "Eyes")
	var started := -1
	var last_tick := -1
	var frames := 0
	while true:
		await physics_frame
		frames += 1
		if game_match == null or not is_instance_valid(game_match):
			break
		var tick := game_match.tick
		if tick == last_tick:
			if frames > 60 * 60 * 10:
				break
			continue
		last_tick = tick
		if started < 0:
			started = tick
		var t := float(tick - started) / SimClock.TICK_RATE
		if t > seconds:
			break
		if (tick - started) % SimClock.TICK_RATE != 0:
			continue
		var elements := Elements.of_match(game_match)
		if elements == null:
			continue
		for team in [Match.Team.GREEN, Match.Team.RUST]:
			for element: Element in elements.of_team(team):
				if not ",".join(element.roster).contains(pattern):
					continue
				var crews: Array = []
				for unit_name in element.roster:
					var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
					if tank != null and tank.is_alive():
						crews.append(tank)
				if crews.is_empty():
					continue
				var centre := Vector3.ZERO
				for tank: Tank in crews:
					centre += tank.global_position
				centre /= crews.size()
				var nearest := INF
				var point: Variant = ElementTask.destination(element.task)
				var point_to_enemy := INF
				for child in game_match.tanks.get_children():
					var enemy := child as Tank
					if enemy == null or not enemy.is_alive() or enemy.team == team:
						continue
					for tank: Tank in crews:
						nearest = minf(nearest, tank.global_position.distance_to(enemy.global_position))
					if point is Vector3:
						point_to_enemy = minf(point_to_enemy, (point as Vector3).distance_to(enemy.global_position))
				print("RECON t=%.0f %s task=%s to=%s drill=%s centre=(%.0f, %.0f) point_to_enemy=%.0f nearest_enemy=%.0f why=%s" % [
						t, ",".join(element.roster), String(element.task.get("verb", "-")), str(element.task.get("to", "-")),
						element.drill, centre.x, centre.z, point_to_enemy, nearest, element.reason])
	print("RECON_DONE")
	quit(0)

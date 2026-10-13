extends SceneTree
## Round 28 (brains B5): HIS QUEUED SCREEN, in a window. A skirmish starts in its planning pause; squad 1 is given a
## waypoint (a right-click move) and then, shifted, a screen beyond it, as he does it. Then the clock runs and frames are
## taken when the screen starts (the squad at the waypoint), when it is forming, and settled. Prints QUEUED_SHOTS with the
## screen line's heading against point − waypoint.
##
##   godot --path . --resolution 1854x1011 --script res://tests/tactics/queued_screen_shots.gd -- --skirmish --seed=3
##         --no-pick-faction --mute --arena=yard_open --enemy=<quiet> --no-element-cpu --shots=<dir>

var _shots := ""


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _shot(label: String) -> void:
	if _shots == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_shots)
	root.get_viewport().get_texture().get_image().save_png(_shots.path_join(label + ".png"))


func _centroid(controls: RtsControls, members: Array) -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for unit_name: String in members:
		var tank := controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank != null and tank.is_alive():
			sum += tank.global_position
			count += 1
	return Vector3(sum.x, 0.0, sum.z) / maxf(1.0, float(count))


func _all_in(controls: RtsControls, element: Element, metres: float) -> bool:
	if element.slots.is_empty():
		return false
	for unit_name in element.members():
		var tank := controls.game_match.tanks.get_node_or_null(NodePath(String(unit_name))) as Tank
		var slot: Variant = element.slots.get(String(unit_name))
		if tank == null or not tank.is_alive() or not slot is Vector3:
			continue
		if Vector2(tank.global_position.x - (slot as Vector3).x, tank.global_position.z - (slot as Vector3).z).length() > metres:
			return false
	return true


func _run() -> void:
	_shots = _flag("shots", "")
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var controls: RtsControls = null
	for attempt in 600:
		await process_frame
		var found := root.find_children("TacticalMap", "RtsControls", true, false)
		if not found.is_empty():
			controls = found[0] as RtsControls
			break
	if controls == null:
		print("QUEUED_SHOTS {\"error\": \"no controls\"}")
		quit(1)
		return
	await _seconds(1.5)
	var members: Array = Array(controls.groups.members(1))
	if members.is_empty():
		for child in controls.game_match.tanks.get_children():
			var tank := child as Tank
			if tank != null and tank.team == Match.Team.GREEN and members.size() < 4:
				members.append(String(tank.name))
	controls.selection.units.assign(members)
	var start := _centroid(controls, members)
	var forward: Vector3 = Match.team_frame(Match.Team.GREEN)["forward"]
	var right := Vector3(-forward.z, 0.0, forward.x)
	var waypoint := ElementPlan.clamp_to_arena(start + forward * 40.0 - right * 40.0)
	var point := ElementPlan.clamp_to_arena(waypoint + right * 70.0 + forward * 20.0)
	var planned_paused := paused
	var moved := controls.order_selection("move", {"to": [waypoint.x, waypoint.z]})
	var queued := controls.order_selection("screen", {"to": [point.x, point.z], "queue": true})
	if controls.rig != null:
		controls.rig.focus = (waypoint + point) * 0.5
		controls.rig.snap()
	await _seconds(0.5)
	await _shot("1_planned")
	controls.set_paused(false, "")
	var element := controls.elements.of(String(members[0])) if controls.elements != null else null
	var screen_s := -1.0
	var nearest := INF
	for i in 900:
		await _seconds(0.1)
		if element == null:
			break
		nearest = minf(nearest, _centroid(controls, members).distance_to(waypoint))
		if String(element.task.get("verb", "")) == "screen":
			screen_s = i * 0.1
			break
	await _shot("2_screen_starts")
	await _seconds(4.0)
	await _shot("3_forming")
	# Settled: every living crew within 8 m of its place on the line (the element's 8 m line), at most 30 s.
	var settled_s := -1.0
	for i in 300:
		if element != null and _all_in(controls, element, 8.0):
			settled_s = 4.0 + i * 0.1
			break
		await _seconds(0.1)
	await _seconds(1.0)
	await _shot("4_settled")
	var wanted := (point - waypoint)
	var off := -1.0
	if element != null:
		off = rad_to_deg(Vector3(element.heading.x, 0.0, element.heading.z).normalized().angle_to(Vector3(wanted.x, 0.0,
				wanted.z).normalized()))
	print("QUEUED_SHOTS " + JSON.stringify({"paused_when_planned": planned_paused, "move": moved, "queued": queued,
			"screen_started_s": screen_s, "settled_after_screen_s": snappedf(settled_s, 0.1),
			"panel": controls.element_state().get("reason", "") if controls.has_method("element_state") else "", "nearest_to_waypoint_m": snappedf(nearest, 0.1), "heading_off_deg": snappedf(off, 0.1),
			"waypoint": [snappedf(waypoint.x, 0.1), snappedf(waypoint.z, 0.1)], "point": [snappedf(point.x, 0.1),
			snappedf(point.z, 0.1)]}))
	quit(0)

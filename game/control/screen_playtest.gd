class_name ScreenPlaytest
extends Node
## Round 11 follow-up. The lead, playing the merged build (2026-09-24): *"I also noticed a bug where I had a group of
## trucks and I commanded them to go and screen to a certain point and they did nothing. I could still just tell them
## to move though."*
##
## Reading the code found several places a task CAN be swallowed and no way to tell which one did it, so this rides a
## real skirmish through real input and reports the facts instead:
##
##   1. **grouped** — squad 1 (a control group, so `can_task()` is true), Screen armed with E, left-click a point
##      60 m off. This is the path his words describe if "group of trucks" means a control group.
##   2. **ungrouped** — the same crews selected by name with NO control group, then Screen. The arm should REFUSE and
##      say why (round 10's R1); if it silently does nothing, that is the bug.
##   3. **near** — grouped, but the point is 20 m away, inside `Drills.SCREEN_REACHED_M` (30 m), where the element
##      plans "on the line" rather than a march. A player cannot know about a 30 m threshold, so if this stands still
##      it is a defect whatever the doctrine intends.
##   4. **move_after** — his own control: a plain move to the same point, which he reports DOES work.
##
## Per scenario it prints what the controls returned (a refusal or ""), the element's task, drill and reason, the
## order each crew is CARRYING (lesson 183: what was issued, not what was intended), and how far each hull actually
## travelled. `--screen-test=DIR` on a skirmish: prints SCREEN lines, writes DIR/screen.json, prints SCREEN_DONE.

## How far off the squad's centre the screened point lands, and the near variant's distance.
const OFF_M := 60.0
const NEAR_M := 20.0
## How long to watch after the order before judging "nothing happened".
const WATCH_S := 8.0
## A hull that travels less than this in WATCH_S did nothing a player would call moving.
const MOVED_M := 3.0

## Round 26 (orders O2): his case, every armed task. Two squads selected, the task armed with its key, then the REAL
## gesture - press at a point, drag toward a second point, release - and, on arrival, the heading the crews
## actually stand on against the one he drew. Run only when asked (`--screen-only=faced_screen,...`, or `faced` for all
## five; `make facing-probe`), so the four scenarios above keep their meaning.
const FACED := {"faced_screen": KEY_E, "faced_support_by_fire": KEY_R, "faced_ambush": KEY_B,
		"faced_attack_move": KEY_A, "faced_move": KEY_M, "faced_right": KEY_NONE}
## The drawn facing is this far off the travel (counter-clockwise of it): far enough that the automatic pick (the travel, or the
## threat) cannot pass by accident at FACED_TOLERANCE_DEG.
const FACED_OFF_TRAVEL_DEG := 60.0
const FACED_WATCH_S := 75.0
## Every living crew below FACED_STILL_MPS for this long = settled.
const FACED_STILL_S := 3.0
const FACED_STILL_MPS := 0.3
const FACED_TOLERANCE_DEG := 15.0
## The release is drawn this far along the facing from the press (metres on the ground; at least FACING_DRAG_PX on screen).
const FACED_DRAG_M := 14.0

var out_dir := ""
var controls: RtsControls
var only: PackedStringArray = []
## Windowed runs: frames of the drag (the arrow) and the settled line go here ("" = none; headless never has frames).
var shots_dir := ""

var _results: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	if shots_dir == "" and DisplayServer.get_name() != "headless":
		shots_dir = out_dir.path_join("shots")  # a window has frames to give; the flags stay the skirmish's own
	if DisplayServer.get_name() == "headless":
		get_tree().root.size = Vector2i(1920, 1080)  # headless roots are 64x64 (trip-up 31)
	await _seconds(1.0)
	_resume()
	await _seconds(1.0)
	_resume()
	var wanted: Array = ["grouped", "ungrouped", "near", "move_after"]
	if not only.is_empty():
		wanted = []
		for name: String in only:
			if name == "faced":
				wanted.append_array(FACED.keys())
			else:
				wanted.append(name)
	for scenario: String in wanted:
		if scenario == "flank":
			await _flank()
		elif FACED.has(scenario):
			await _faced(scenario)
		elif scenario in ["grouped", "ungrouped", "near", "move_after"]:
			await _scenario(scenario)
	var file := FileAccess.open(out_dir.path_join("screen.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_results, "  "))
	var stalled: Array = _results.filter(func(r: Dictionary) -> bool: return bool(r.get("nobody_moved", false))) \
			.map(func(r: Dictionary) -> String: return String(r["scenario"]))
	var unfaced: Array = _results.filter(func(r: Dictionary) -> bool: return r.has("faced_ok") and not bool(r["faced_ok"])) \
			.map(func(r: Dictionary) -> String: return String(r["scenario"]))
	print("SCREEN_DONE scenarios=%d nobody_moved=%s ignored_facing=%s" % [_results.size(), ",".join(stalled),
			",".join(unfaced)])
	get_tree().quit(0)


func _scenario(scenario: String) -> void:
	await _key(KEY_1)  # select squad 1 (a control group: this is what makes a task possible at all)
	await _seconds(0.3)
	var members: Array = controls.selection.units.duplicate()
	if members.is_empty():
		_results.append({"scenario": scenario, "why": "squad 1 has no living members"})
		return
	if scenario == "ungrouped":
		# The same crews, selected directly, belonging to no control group: what a box-select gives him.
		controls.groups.save(1, [])
		controls.selection.units = members.duplicate()
	var centre := _centroid(members)
	var reach := NEAR_M if scenario == "near" else OFF_M
	var at := ElementPlan.clamp_to_arena(centre + Vector3(reach, 0.0, 0.0))
	var before := {}
	for unit_name: String in members:
		before[unit_name] = _position_of(unit_name)

	_resume()
	var row := {"scenario": scenario, "members": members.size(), "paused": get_tree().paused,
			"centre": [snappedf(centre.x, 0.1), snappedf(centre.z, 0.1)],
			"at": [snappedf(at.x, 0.1), snappedf(at.z, 0.1)],
			"distance_m": snappedf(Vector2(centre.x, centre.z).distance_to(Vector2(at.x, at.z)), 0.1),
			"screen_reached_m": Drills.SCREEN_REACHED_M,
			"can_task": controls.can_task(), "selected_group": controls.selected_group(),
			"task_refusal": controls.task_refusal()}

	var verb := "move" if scenario == "move_after" else "screen"
	row["verb"] = verb
	# Through the real call the armed click makes, so the input guards are exercised rather than bypassed.
	row["returned"] = controls.order_selection(verb, {"to": [at.x, at.z]})

	var element: Object = controls.elements.of(String(members[0])) if controls.elements != null else null
	row["element_formed"] = element != null
	if element != null:
		row["task_at_issue"] = str(element.get("task"))

	var tick_before: int = controls.game_match.tick
	await _seconds(WATCH_S)
	row["ticks_elapsed"] = controls.game_match.tick - tick_before
	if element != null:
		row["task_after"] = str(element.get("task"))
		row["drill"] = String(element.get("drill"))
		row["reason"] = String(element.get("reason"))
		row["arrived"] = bool(element.get("arrived"))
		row["anchor"] = str(element.get("anchor"))
	var moved := {}
	var carrying := {}
	var any := false
	for unit_name: String in members:
		var travelled: float = (before[unit_name] as Vector3).distance_to(_position_of(unit_name))
		moved[unit_name] = snappedf(travelled, 0.1)
		if travelled >= MOVED_M:
			any = true
		var current: Dictionary = controls.orders.call("current", unit_name)
		var tank: Node3D = controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Node3D
		var mover: Dictionary = Movement.state(tank) if tank != null else {}
		carrying[unit_name] = "%s src=%s phase=%s by=%s" % [String(current.get("verb", "(none)")),
				String(current.get("source", "-")), String(mover.get("phase", "-")),
				String(mover.get("blocked_by", ""))]
	row["moved_m"] = moved
	row["carrying"] = carrying
	row["nobody_moved"] = not any
	print("SCREEN %s" % JSON.stringify(row))
	_results.append(row)
	# Put them back under one order so the next scenario starts from rest, not mid-manoeuvre.
	controls.order_selection("stop", {})
	await _seconds(1.0)


## O2: one armed task given by the real gesture to squads 1 and 2 together, then judged on the ground.
func _faced(scenario: String) -> void:
	var members: Array[String] = []
	for number in [1, 2]:
		for unit_name: String in controls.groups.members(number):
			if _alive(unit_name):
				members.append(unit_name)
	var row := {"scenario": scenario, "members": members.size()}
	if members.size() < 2:
		row["why"] = "squads 1 and 2 have fewer than two living crews"
		_results.append(row)
		return
	_resume()
	controls.selection.set_units(members)
	# ACROSS our own half, toward the arena's middle line, not forward: forward 60 m ran the squads into a holding
	# enemy's base on Foundry (the quiet arm met it within 3-33 m), so the arm meant to be out of contact was not.
	var right: Vector3 = Match.team_frame(controls.team)["right"]
	var centre := _centroid(members)
	var travel := -right if centre.dot(right) > 0.0 else right
	var at := ElementPlan.clamp_to_arena(centre + travel * OFF_M)
	var facing := travel.rotated(Vector3.UP, deg_to_rad(FACED_OFF_TRAVEL_DEG)).normalized()
	row["nearest_enemy_at_press_m"] = snappedf(_nearest_enemy(members), 0.1)
	row["at"] = [snappedf(at.x, 0.1), snappedf(at.z, 0.1)]
	row["drawn"] = [snappedf(facing.x, 0.001), snappedf(facing.z, 0.001)]
	# Look at the spot from his pose: the press must land on the ground there, the release toward the facing.
	var rig := controls.rig
	if rig != null:
		rig.focus = at
		rig.snap()
	# faced_right: round 9's right-drag move, the gesture the armed orders copied (no key: the right button).
	var button := MOUSE_BUTTON_RIGHT if scenario == "faced_right" else MOUSE_BUTTON_LEFT
	if FACED[scenario] != KEY_NONE:
		await _key(FACED[scenario])
	row["armed"] = controls.mode
	# The vision camera keeps framing the selection, so every screen point is read from the camera of the frame it is
	# pushed in (a press read one frame early lands metres off, and the heading it draws turns with it).
	var camera := controls.camera
	if rig != null:
		rig.focus = at
		rig.snap()
	var press := camera.unproject_position(at)
	var release := camera.unproject_position(at + facing * FACED_DRAG_M)
	# Round 27 (O3): `--faced-click` is the A/B's other arm: the same order CLICKED at the same spot (automatic facing),
	# judged against the same heading, so what the drawn facing buys the hulls is read on the same seeds.
	var clicked := LaunchFlags.from_environment().has("faced-click")
	row["clicked"] = clicked
	if clicked:
		release = press
	row["drag_px"] = snappedf(press.distance_to(release), 0.1)
	_mouse(press, true, button)
	for i in range(1, 7):
		_motion(press.lerp(release, i / 6.0), button)
	await get_tree().process_frame
	await _shot(scenario + "_1_drag")
	var spot: Variant = controls.armed_gesture().get("spot", controls._right_press_ground)
	if spot is Vector3 and not clicked:
		release = camera.unproject_position((spot as Vector3) + facing * FACED_DRAG_M)  # this frame's camera
	_motion(release, button)
	_mouse(release, false, button)
	await get_tree().process_frame
	var given := {}
	var given_way := Vector3.ZERO
	for unit_name in members:
		var element: Element = controls.elements.of(unit_name) if controls.elements != null else null
		var carried: Dictionary = element.task if element != null else controls.orders.current(unit_name)
		var way: Variant = carried.get("facing", null)
		given[String(carried.get("verb", "(none)"))] = way if way != null else "none"
		if way is Array and (way as Array).size() == 2:
			given_way = Vector3(float(way[0]), 0.0, float(way[1])).normalized()
	row["given"] = given
	row["gesture_error_deg"] = snappedf(rad_to_deg(Vector2(given_way.x, given_way.z).angle_to(Vector2(facing.x, facing.z))), 0.1) \
			if given_way != Vector3.ZERO else -1.0
	var lines := scenario in ["faced_screen", "faced_support_by_fire", "faced_ambush"]
	await _seconds(10.0)
	await _shot(scenario + "_2_moving")
	# Judged where they ended up: every hull still for FACED_STILL_S (the element's `arrived` is OPERATIONAL arrival,
	# before the crews dress onto their slots - the first frames showed "ARRIVED · dressing 1/4" with most still driving;
	# support by fire and ambush never set it), or FACED_WATCH_S.
	var waited := 10.0
	var still := 0.0
	while waited < FACED_WATCH_S and still < FACED_STILL_S:
		await _seconds(0.5)
		waited += 0.5
		still = still + 0.5 if _all_still(members) else 0.0
	row["settled_after_s"] = waited if still >= FACED_STILL_S else -1.0
	row["arrived"] = _both_arrived()
	# The frame the lead looks at: taken at the judging moment, from the drag frame's pose (focused on the spot he drew),
	# so the pin's arrow and the line it should match are in one picture.
	if rig != null:
		rig.focus = at
		rig.snap()
	await get_tree().process_frame
	await _shot(scenario + "_3_settled")
	var squads := []
	var ok := true
	# Judged per ELEMENT (a squad's leader and its line), not per control group: a faction's control group can hold two
	# elements, and one line fitted through two lines 120 m apart measures nothing.
	var by_element := {}
	var order: Array = []
	for unit_name in members:
		if not _alive(unit_name):
			continue
		var element: Element = controls.elements.of(unit_name) if controls.elements != null else null
		var key: Variant = element.get_instance_id() if element != null else unit_name
		if not by_element.has(key):
			by_element[key] = {"element": element, "crews": [] as Array[String]}
			order.append(key)
		(by_element[key]["crews"] as Array[String]).append(unit_name)
	for key: Variant in order:
		var crews: Array[String] = by_element[key]["crews"]
		var element: Element = by_element[key]["element"]
		var judged := _judge(crews, given_way if given_way != Vector3.ZERO else facing, lines)
		judged["squad"] = element.element_name if element != null else ""
		judged["arrived"] = bool(element.get("arrived")) if element != null else false
		judged["moving"] = crews.filter(func(n: String) -> bool: return not _all_still([n] as Array[String])).size()
		squads.append(judged)
		ok = ok and bool(judged["ok"])
	row["squads"] = squads
	# Contact confounds the verdict: a crew with an enemy in sight faces the enemy, by design (tank_brain), not the
	# drawn post facing. How many enemies the player can see when it is judged, so each arm can be read for what it is.
	# Measured on the ground (`can_see` answers true for everything under reveal_all): an enemy within some crew's own
	# sight radius is in sight.
	var seen := 0
	var nearest := INF
	for child in controls.game_match.tanks.get_children():
		var enemy := child as Tank
		if enemy == null or enemy.team == controls.team or not enemy.is_alive():
			continue
		var spotted := false
		for unit_name: String in members:
			var crew := controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if crew == null or not crew.is_alive():
				continue
			var apart := crew.global_position.distance_to(enemy.global_position)
			nearest = minf(nearest, apart)
			spotted = spotted or apart <= crew.sight_radius
		if spotted:
			seen += 1
	row["enemies_seen"] = seen
	row["nearest_enemy_m"] = snappedf(nearest, 0.1) if nearest < INF else -1.0
	row["faced_ok"] = ok
	print("SCREEN %s" % JSON.stringify(row))
	_results.append(row)
	controls.order_selection("stop", {})
	await _seconds(1.0)


## Round 27 (orders O1, C27.3, lesson 291: the path the player's input takes). Squad 1 recalled with its key, then the
## REAL right-drag: press on the nearest enemy, drag out FLANK_SIDE_DEG off the line from the squad, release. Every second
## the squad's bearing from its target against the side drawn. `--faced-click` clicks the same enemy instead (today's
## attack), judged against the same side: the A/B on the same seed. `--flank-side=left|right` picks the side.
const FLANK_SIDE_DEG := 90.0
const FLANK_DRAG_M := 30.0
const FLANK_WATCH_S := 90.0
const FLANK_WITHIN_DEG := 35.0
const FLANK_START_M := 55.0


func _flank() -> void:
	var flags := LaunchFlags.from_environment()
	var clicked := flags.has("faced-click")
	var row := {"scenario": "flank", "clicked": clicked}
	await _key(KEY_1)
	await _seconds(0.3)
	var members: Array[String] = []
	members.assign(controls.selection.units)
	if members.is_empty():
		row["why"] = "squad 1 has no living members"
		_results.append(row)
		return
	_resume()
	var centre := _centroid(members)
	var target: Tank = null
	for child in controls.game_match.tanks.get_children():
		var enemy := child as Tank
		if enemy != null and enemy.team != controls.team and enemy.is_alive() \
				and (target == null or enemy.global_position.distance_to(centre) < target.global_position.distance_to(centre)):
			target = enemy
	if target == null:
		row["why"] = "no enemy"
		_results.append(row)
		return
	# He attacks what he can see (a tank sees ~62 m; brains' stage starts 50 m out): the target is brought FLANK_START_M
	# ahead of the squad, toward the enemy's side, before the press. The quiet arm's enemy holds; a target off its slot
	# may drive back, so every sample reads where it is now.
	var ahead := Vector3(target.global_position.x - centre.x, 0.0, target.global_position.z - centre.z).normalized()
	target.global_position = ElementPlan.clamp_to_arena(centre + ahead * FLANK_START_M)
	target.reset_physics_interpolation()
	# Holding there: a target driving back to its slot is a mover, and brains pursues a mover (>= 2 m/s) with the side
	# ignored (its B0 rule), so the first probe measured the pursuit, not the flank. Out of its element first, so its
	# leader does not re-slot it.
	var owner: Element = controls.elements.of(String(target.name)) if controls.elements != null else null
	if owner != null:
		owner.remove(String(target.name))
	row["target_hold"] = controls.orders.issue({"units": [String(target.name)], "verb": "hold", "source": "player"}, target.team)
	await _seconds(0.5)
	controls.reveal_all = true
	var to_target := Vector3(target.global_position.x - centre.x, 0.0, target.global_position.z - centre.z).normalized()
	var turn := FLANK_SIDE_DEG if flags.text("flank-side", "left") == "left" else -FLANK_SIDE_DEG
	var side := (-to_target).rotated(Vector3.UP, deg_to_rad(turn)).normalized()  # from the target out to the drawn side
	row["target"] = String(target.name)
	row["start_m"] = snappedf(centre.distance_to(target.global_position), 0.1)
	row["side"] = [snappedf(side.x, 0.001), snappedf(side.z, 0.001)]
	var rig := controls.rig
	if rig != null:
		rig.focus = target.global_position
		rig.snap()
	await get_tree().process_frame
	if rig != null:
		rig.focus = target.global_position
		rig.snap()
	var camera := controls.camera
	var press := camera.unproject_position(target.global_position)
	var release := press if clicked else camera.unproject_position(target.global_position + side * FLANK_DRAG_M)
	_mouse(press, true, MOUSE_BUTTON_RIGHT)
	for i in range(1, 7):
		_motion(press.lerp(release, i / 6.0), MOUSE_BUTTON_RIGHT)
	await get_tree().process_frame
	await _shot("flank_1_drag")
	_mouse(release, false, MOUSE_BUTTON_RIGHT)
	await get_tree().process_frame
	var element: Element = controls.elements.of(members[0]) if controls.elements != null else null
	var task: Dictionary = element.task if element != null else {}
	row["task_verb"] = String(task.get("verb", ""))
	row["task_target"] = String(task.get("target", ""))
	row["task_approach"] = task.get("approach", [])
	var trace := []
	var reached := -1.0
	var waited := 0.0
	while waited < FLANK_WATCH_S:
		await _seconds(1.0)
		waited += 1.0
		if not target.is_alive():
			break
		var alive := members.filter(func(n: String) -> bool: return _alive(n))
		if alive.is_empty():
			break
		var at := _centroid(alive)
		var out := Vector3(at.x - target.global_position.x, 0.0, at.z - target.global_position.z)
		var error := rad_to_deg(absf(Vector2(out.x, out.z).angle_to(Vector2(side.x, side.z))))
		trace.append([waited, snappedf(error, 0.1), snappedf(out.length(), 0.1),
				snappedf(Vector2(target.velocity.x, target.velocity.z).length(), 0.1)])
		if reached < 0.0 and error <= FLANK_WITHIN_DEG:
			reached = waited
		if waited == 30.0:
			await _shot("flank_2_closing")
	await _shot("flank_3_end")
	row["trace"] = trace
	row["reached_side_s"] = reached
	if not trace.is_empty():
		row["end_side_error_deg"] = trace[trace.size() - 1][1]
		row["end_m"] = trace[trace.size() - 1][2]
		var best := 180.0
		for sample: Array in trace:
			best = minf(best, float(sample[1]))
		row["best_side_error_deg"] = best
	print("SCREEN %s" % JSON.stringify(row))
	_results.append(row)


func _nearest_enemy(members: Array[String]) -> float:
	var nearest := INF
	for child in controls.game_match.tanks.get_children():
		var enemy := child as Tank
		if enemy == null or enemy.team == controls.team or not enemy.is_alive():
			continue
		for unit_name: String in members:
			if _alive(unit_name):
				nearest = minf(nearest, _position_of(unit_name).distance_to(enemy.global_position))
	return nearest if nearest < INF else -1.0


func _all_still(members: Array[String]) -> bool:
	for unit_name in members:
		var tank := controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank != null and tank.is_alive() and Vector2(tank.velocity.x, tank.velocity.z).length() > FACED_STILL_MPS:
			return false
	return true


func _both_arrived() -> bool:
	for number in [1, 2]:
		for unit_name: String in controls.groups.members(number):
			if not _alive(unit_name):
				continue
			var element: Element = controls.elements.of(unit_name) if controls.elements != null else null
			if element == null or not bool(element.get("arrived")):
				return false
			break
	return true


## The heading a squad stands on: its hulls' mean heading, and for a line task (three or more crews) the way its line
## LOOKS (the normal of the line through them, on the facing's side). Both within FACED_TOLERANCE_DEG of the facing the
## task was GIVEN (what brains is asked to honour; the gesture's own error is `gesture_error_deg` on the row).
func _judge(crews: Array[String], facing: Vector3, lines := true) -> Dictionary:
	var heading := Vector3.ZERO
	var guns := Vector3.ZERO
	var points: Array[Vector3] = []
	# Round 27 (O3): every crew's own hull error and hull class (locomotion/mount), so the tail can be read per class.
	var each := []
	for unit_name in crews:
		var tank := controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		var nose := -tank.global_basis.z
		heading += Vector3(nose.x, 0.0, nose.z).normalized()
		each.append({"unit": unit_name, "id": tank.unit_id,
				"class": "%s/%s" % [Units.stat(tank.unit_id, "locomotion", "?"), Units.stat(tank.unit_id, "mount", "?")],
				"hull_error_deg": snappedf(absf(rad_to_deg(Vector2(nose.x, nose.z).angle_to(Vector2(facing.x, facing.z)))), 0.1),
				"still": _all_still([unit_name] as Array[String])})
		# Where the gun points (a turret's heading), which is what "faces it" means for a turreted crew.
		var gun := -tank.turret.global_basis.z if tank.turret != null else nose
		guns += Vector3(gun.x, 0.0, gun.z).normalized()
		points.append(_position_of(unit_name))
	var result := {"crews": crews.size(), "each": each}
	if crews.is_empty():
		result["ok"] = true
		return result
	var hull_error := rad_to_deg(Vector2(heading.x, heading.z).angle_to(Vector2(facing.x, facing.z)))
	result["hull_error_deg"] = snappedf(absf(hull_error), 0.1)
	result["gun_error_deg"] = snappedf(absf(rad_to_deg(Vector2(guns.x, guns.z).angle_to(Vector2(facing.x, facing.z)))), 0.1)
	var ok := absf(hull_error) <= FACED_TOLERANCE_DEG
	if lines and points.size() >= 3:
		var axis := _line_axis(points)
		var looks := Vector3(-axis.z, 0.0, axis.x)
		if looks.dot(facing) < 0.0:
			looks = -looks
		var line_error := rad_to_deg(Vector2(looks.x, looks.z).angle_to(Vector2(facing.x, facing.z)))
		result["line_error_deg"] = snappedf(absf(line_error), 0.1)
		result["line_spread_m"] = snappedf(_spread(points, axis), 0.1)
		ok = ok and absf(line_error) <= FACED_TOLERANCE_DEG
	# Whether the leader passed the heading on: crews whose own order carries it (within the tolerance). Zero told and
	# far off = the task dropped it; all told and still far off = the crews were told and did not turn.
	var told := 0
	for unit_name in crews:
		var way: Array = (controls.orders.current(unit_name) as Dictionary).get("facing", [])
		if way.size() == 2 and rad_to_deg(absf(Vector2(float(way[0]), float(way[1])).angle_to(Vector2(facing.x, facing.z)))) \
				<= FACED_TOLERANCE_DEG:
			told += 1
	result["crews_told"] = told
	result["ok"] = ok
	return result


## The principal axis of the points on the ground (their line), as a unit vector.
static func _line_axis(points: Array[Vector3]) -> Vector3:
	var mean := Vector3.ZERO
	for p in points:
		mean += p
	mean /= float(points.size())
	var xx := 0.0
	var xz := 0.0
	var zz := 0.0
	for p in points:
		var d := p - mean
		xx += d.x * d.x
		xz += d.x * d.z
		zz += d.z * d.z
	var angle := 0.5 * atan2(2.0 * xz, xx - zz)
	return Vector3(cos(angle), 0.0, sin(angle))


static func _spread(points: Array[Vector3], axis: Vector3) -> float:
	var low := INF
	var high := -INF
	for p in points:
		low = minf(low, p.dot(axis))
		high = maxf(high, p.dot(axis))
	return high - low


func _alive(unit_name: String) -> bool:
	var tank := controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
	return tank != null and tank.is_alive()


func _mouse(at: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = at
	event.global_position = at
	_point_at(at)
	get_viewport().push_input(event)


func _motion(at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT if button == MOUSE_BUTTON_RIGHT else MOUSE_BUTTON_MASK_LEFT
	_point_at(at)
	get_viewport().push_input(event)


## The hint and the hover tooltip follow the OS pointer, not the events pushed here, so a windowed run moves the
## pointer too or its frames show the hint wherever the window's pointer was left (over the command card at 1200x540).
## Headless runs (the measured probe) are untouched.
func _point_at(at: Vector2) -> void:
	if shots_dir != "" and DisplayServer.get_name() != "headless":
		get_viewport().warp_mouse(at)


func _shot(label: String) -> void:
	if shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(label + ".png"))


func _position_of(unit_name: String) -> Vector3:
	var tank: Node3D = controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Node3D
	return tank.global_position if tank != null else Vector3.ZERO


func _centroid(members: Array) -> Vector3:
	var sum := Vector3.ZERO
	for unit_name: String in members:
		sum += _position_of(unit_name)
	return sum / maxf(1.0, float(members.size()))


func _resume() -> void:
	if get_tree().paused:
		controls.set_paused(false, "")


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)
	await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

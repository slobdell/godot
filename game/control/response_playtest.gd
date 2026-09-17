class_name ResponsePlaytest
extends Node
## Round 5 reopened (the lead: *"the units aren't very responsive to my input"*). "Not responsive" can mean four
## different things with three different owners, so this measures the whole path from the click to the vehicle visibly
## moving, in milliseconds, at a real army size, and splits it:
##
##   input      the click reaching the controls          (control; the frame rate decides it)
##   order      the controls issuing the K1 order        (control; K1's 100 ms contract)
##   ack        the order marker appearing on screen     (control; what makes a click *feel* answered)
##   frame      the next frame actually drawn            (render + the simulation tick)
##   move       the vehicle visibly turning or moving    (combat's locomotion, once the order is in)
##
## **Run this on a machine that actually draws frames** — the lead's laptop, not builder0, whose remote desktop draws
## about one frame a second and turns every number here into nonsense.
##
## The standing target: the median "vehicle visibly starts" under ~150 ms at 30 a side. Nothing else in the project
## measures how the game *feels* to a hand on a mouse, as opposed to how fast it computes.
##
## Each sample is one right-click ordering the whole selection somewhere, repeated ORDERS times at both army sizes the
## run is given. `--response-test=DIR` on a skirmish: prints RESPONSE_TEST lines and a RESPONSE_TEST_SUMMARY JSON,
## writes DIR/response.json, then quits. Movement is judged on the *drawn* position (Shown), not the tick's, because
## that is what the player sees.

## A vehicle counts as visibly responding once it has moved this far or turned this much from where it was clicked.
const MOVED_M := 0.35
const TURNED_DEG := 2.0
## How many orders to measure, and how long to wait for each before giving up.
const ORDERS := 6
const WAIT_SECONDS := 3.0
## Settle time between orders, so each sample starts from a standing group.
const BETWEEN_SECONDS := 1.5

var out_dir := ""
var controls: RtsControls

var _samples: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var tree := get_tree()
	_resume()
	await _seconds(2.0)
	_resume()  # the planning pause is set after the mode finishes building the controls, so lift it once more
	await _seconds(6.0)  # let the armies deploy and the first contact start, so the frame rate is realistic
	for i in ORDERS:
		await _one_order(i)
		await _seconds(BETWEEN_SECONDS)
	var report := summarize(_samples)
	report["vehicles"] = controls.game_match.alive_count(Match.Team.GREEN) + controls.game_match.alive_count(Match.Team.RUST)
	report["response_ms_contract"] = Orders.RESPONSE_MS
	print("RESPONSE_TEST_SUMMARY ", JSON.stringify(report))
	var file := FileAccess.open(out_dir.path_join("response.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"summary": report, "samples": _samples}, "  "))
	print("RESPONSE_TEST_DONE dir=%s" % out_dir)
	tree.quit(0)


## One click, measured: select the army, right-click a spot behind it (so every vehicle has to turn round, the worst
## case the lead would feel), and watch each stage arrive.
func _one_order(index: int) -> void:
	_resume()
	controls.select_army()
	await _frames(2)
	var units := controls.selection.units.duplicate()
	if units.is_empty():
		return
	var before := {}
	for unit_name: String in units:
		var tank := _tank(unit_name)
		if tank != null:
			before[unit_name] = [Shown.ground(tank), Shown.forward(tank)]
	var middle := Vector3.ZERO
	for at: Array in before.values():
		middle += at[0]
	middle /= maxf(before.size(), 1.0)
	# A point well away from the group but always on screen, alternating up and down the screen, so the order is one a
	# player could actually give (and every vehicle has to turn).
	var rect := get_viewport().get_visible_rect()
	var screen := rect.get_center() + Vector2(0.0, rect.size.y * (0.3 if index % 2 == 0 else -0.3))
	var acks := controls.last_ack()
	var issued: Array = []
	var watch := func(_command: Dictionary, _error: String) -> void: issued.append(Time.get_ticks_usec() / 1000.0)
	controls.command_issued.connect(watch)
	var clicked := Time.get_ticks_usec() / 1000.0
	_right_click(screen)
	var handled := Time.get_ticks_usec() / 1000.0
	controls.command_issued.disconnect(watch)
	var ordered_at: float = issued[0] if not issued.is_empty() else -1.0
	var sample := {"order": index, "units": units.size(), "input_ms": handled - clicked,
			"order_ms": (ordered_at - clicked) if ordered_at >= 0.0 else -1.0}
	var frame_at := -1.0
	var ack_at := -1.0
	var moved := {}
	var turning := {}
	var frames := 0
	var first_tick := controls.game_match.tick
	var deadline := clicked + WAIT_SECONDS * 1000.0
	while Time.get_ticks_usec() / 1000.0 < deadline and moved.size() < before.size():
		await RenderingServer.frame_post_draw
		frames += 1
		var now := Time.get_ticks_usec() / 1000.0
		if frame_at < 0.0:
			frame_at = now
		if ack_at < 0.0 and controls.last_ack() != acks:
			ack_at = now
		for unit_name: String in before:
			var tank := _tank(unit_name)
			if tank == null or not tank.is_alive():
				moved[unit_name] = -1.0
				turning[unit_name] = -1.0
				continue
			var was: Array = before[unit_name]
			# The tick's own truth (has the vehicle started?) and what the screen shows are different questions; both
			# matter, because the player only believes the second one.
			if not turning.has(unit_name) and _started(tank, was, false):
				turning[unit_name] = float(controls.game_match.tick - first_tick)
			if not moved.has(unit_name) and _started(tank, was, true):
				moved[unit_name] = now - clicked
	sample["frame_ms"] = frame_at - clicked if frame_at >= 0.0 else -1.0
	sample["ack_ms"] = ack_at - clicked if ack_at >= 0.0 else -1.0
	sample["fps"] = snappedf(frames * 1000.0 / maxf(Time.get_ticks_usec() / 1000.0 - clicked, 1.0), 0.1)
	sample["sim_ticks_per_frame"] = snappedf(float(controls.game_match.tick - first_tick) / maxf(frames, 1), 0.01)
	var times: Array = moved.values().filter(func(ms: float) -> bool: return ms >= 0.0)
	times.sort()
	var ticks: Array = turning.values().filter(func(t: float) -> bool: return t >= 0.0)
	ticks.sort()
	sample["moved_of"] = [times.size(), before.size()]
	sample["move_ms_median"] = times[times.size() / 2] if not times.is_empty() else -1.0
	sample["move_ms_slowest"] = times[-1] if not times.is_empty() else -1.0
	sample["move_ticks_median"] = ticks[ticks.size() / 2] if not ticks.is_empty() else -1.0
	_samples.append(sample)
	print("RESPONSE_TEST ", JSON.stringify(sample))


## Medians and worst cases per stage, for the summary. Pure, so a test can check the arithmetic.
static func summarize(samples: Array) -> Dictionary:
	var report := {"orders": samples.size()}
	for key: String in ["input_ms", "order_ms", "ack_ms", "frame_ms", "fps", "sim_ticks_per_frame", "move_ms_median",
			"move_ms_slowest", "move_ticks_median"]:
		var values: Array = []
		for sample: Dictionary in samples:
			if float(sample.get(key, -1.0)) >= 0.0:
				values.append(float(sample[key]))
		values.sort()
		report[key] = {"median": snappedf(values[values.size() / 2], 0.1), "worst": snappedf(values[-1], 0.1)} if not values.is_empty() else {}
	return report


## Whether `tank` has visibly started: moved or turned from where it was when the order was given. `drawn` asks the
## question the player's eye asks (the interpolated transform); otherwise it asks the simulation's.
static func _started(tank: Tank, was: Array, drawn: bool) -> bool:
	var at := Shown.ground(tank) if drawn else Vector3(tank.global_position.x, 0.0, tank.global_position.z)
	var facing := Shown.forward(tank) if drawn else -tank.global_basis.z
	var turned := rad_to_deg(Vector2(was[1].x, was[1].z).angle_to(Vector2(facing.x, facing.z)))
	return at.distance_to(was[0]) >= MOVED_M or absf(turned) >= TURNED_DEG


## The match must be running: a paused simulation answers every click instantly and moves nothing, which would measure
## the opposite of what the lead is complaining about.
func _resume() -> void:
	if get_tree().paused:
		controls.set_paused(false, "")


# ---- helpers ------------------------------------------------------------------------------------------------

func _tank(unit_name: String) -> Tank:
	return controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank


func _screen_point(world: Vector3) -> Variant:
	var camera := controls.camera
	if camera == null or camera.is_position_behind(world):
		return null
	var at := camera.unproject_position(world)
	return at if get_viewport().get_visible_rect().has_point(at) else null


func _right_click(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		get_viewport().push_input(event)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

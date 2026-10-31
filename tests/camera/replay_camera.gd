extends "res://tests/replay_orders.gd"
## Round 47 (camera K1): his match replayed (tests/replay_orders.gd: his seed, arena, armies, spawn and orders) with HIS
## SELECTIONS too, and a model of his hand on the mouse, sampling where the camera looks against his selection.
## Measurement only: nothing here feeds the camera but what his own input would have (a selection, a moving mouse).
##
## On top of the orders replay:
##   * each `sel` row of the recording selects its units at its tick, as his click on a squad did (RtsControls'
##     `_watch_selection`: the camera is handed back to the commanded element), so a selection made WITHOUT an order (his
##     "select Bravo, look, then order") is replayed, which the orders replay alone never sees;
##   * `--camera-hand=model` (default) moves the mouse as an RTS hand does: HAND_MOVE_S moving, then HAND_REST_S resting
##     (under the rig's HOVER_HOLD_S, so the aim hold applies as it did for him), every cycle; each order is a click (it
##     spends the aim). `--camera-hand=rest`: moving 0.15 s of each second (a hand mostly resting: the aim hold most of the
##     time); `busy`: 0.95 s (a hand almost never still: the hand's pace all the time). `--camera-hand=off`: no mouse at all
##     (round 46's replay: no aim hold, no hand pace).
## Every SAMPLE_TICKS it prints
##   CAMK {"tick", "sel": [names], "centre": [x, z], "look": [x, z] (shown), "goal": [x, z] (wanted), "goal_gap", "gap", "dist", "mode", "holding", "urgent"}
## and CAMK_SEL {"tick", "units", "gap"} at each selection change; tests/camera/k1_gap.py adds them up.
##   godot --headless --fixed-fps 30 --path . --script res://tests/camera/replay_camera.gd -- --orders=<his.jsonl>
##         --seconds=N --record-dir=DIR --camera-screen=1920x1080 [--camera-hand=model|off] [any switch]

const SAMPLE_TICKS := 5
const HAND_MOVE_S := 0.6
const HAND_REST_S := 0.4

var _sels: Array = []
var _next_sel := 0
var _hand := "model"
var _last_names: Array = []


func _run() -> void:
	_hand = _flag("camera-hand", "model")
	for line in FileAccess.get_file_as_string(_flag("orders", "")).split("\n"):
		var row: Variant = JSON.parse_string(line) if line.strip_edges() != "" else null
		if row is Dictionary and row["t"] == "sel":
			_sels.append(row)
	await super._run()


func _step() -> void:
	if _match != null and _controls != null and _controls.rig != null:
		_select()
		_move_hand()
		_sample()
	super._step()


func _select() -> void:
	while _next_sel < _sels.size() and int(_sels[_next_sel]["tick"]) <= _match.tick:
		var row: Dictionary = _sels[_next_sel]
		_next_sel += 1
		var names: Array[String] = []
		for n in row["units"]:
			var tank := _match.tanks.get_node_or_null(NodePath(String(n))) as Tank
			if tank != null and tank.is_alive():
				names.append(String(n))
		if names.is_empty():
			continue
		_controls.selection.set_units(names)
		_controls._watch_selection()
		_click()


## A click spends the aim (RtsCamera._input on a button release).
func _click() -> void:
	if _hand == "off":
		return
	_controls.rig._mouse_moved_at = _controls.rig._clock
	_controls.rig._aim_spent_at = _controls.rig._clock


func _issue() -> void:
	var before := _next
	super._issue()
	if _next > before and _match != null:
		_click()


func _move_hand() -> void:
	if _hand == "off":
		return
	var rig := _controls.rig
	var moving: float = {"model": HAND_MOVE_S, "rest": 0.15, "busy": 0.95}.get(_hand, HAND_MOVE_S)
	var phase := fmod(rig._clock, HAND_MOVE_S + HAND_REST_S)
	if phase < moving:
		rig._mouse_moved_at = rig._clock
		rig._mouse_at = Vector2(960, 540)


func _sample() -> void:
	var names: Array = _controls.selection.units.duplicate()
	var changed := names != _last_names
	if not changed and _match.tick % SAMPLE_TICKS != 0:
		return
	var centre := Vector3.ZERO
	var alive := 0
	for n in names:
		var tank := _match.tanks.get_node_or_null(NodePath(String(n))) as Tank
		if tank != null and tank.is_alive():
			centre += tank.global_position
			alive += 1
	if alive == 0:
		return
	centre /= float(alive)
	var rig := _controls.rig
	var row := rig.record_row()
	var look := Vector2(float(row["target"][0]), float(row["target"][1]))
	var gap := look.distance_to(Vector2(centre.x, centre.z))
	if changed:
		_last_names = names
		print("CAMK_SEL " + JSON.stringify({"tick": _match.tick, "units": names, "gap": snappedf(gap, 0.1)}))
	print("CAMK " + JSON.stringify({"tick": _match.tick, "sel": names, "centre": [snappedf(centre.x, 0.1), snappedf(centre.z, 0.1)],
			"look": row["target"], "goal": [snappedf(rig.focus.x, 0.1), snappedf(rig.focus.z, 0.1)],
			"goal_gap": snappedf(Vector2(rig.focus.x, rig.focus.z).distance_to(Vector2(centre.x, centre.z)), 0.1), "gap": snappedf(gap, 0.1), "dist": row["dist"], "mode": row["mode"], "holding": rig.holding,
			"urgent": rig.planner_urgent}))

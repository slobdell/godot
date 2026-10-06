extends SceneTree
## Round 19 (board, S2): the score bug in every state the brief names, as frames to look at (`make board-shots`):
## a fresh match, one zone taken, both, contested, a kill, a lead change, the final seconds, the one-centre map, and a
## match without control. Hand-made snapshots in `Match.score_snapshot()`'s shape over a dark arena-coloured backdrop,
## at his window (1854x1011) or the phone (1200x540): `--resolution WxH -s res://game/ui/scoreboard_shots.gd -- --out=DIR`.

var out_dir := "user://board-shots"  # make board-shots passes --out; never a res:// path (export-guard reads it as a packed folder)
var suffix := "desktop"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--suffix="):
			suffix = arg.trim_prefix("--suffix=")
	GameTheme.use("cyberpunk")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


static func zone(label: String, x: float, owner: int, progress: float, contested := false) -> Dictionary:
	return {"name": label, "label": label, "owner": owner, "progress": progress, "position": Vector3(x, 0, 0),
			"radius": 15.0, "present": [1 if contested else 0, 1 if contested else 0], "contested": contested}


static func snap(points: Array, kills: Array, credits: Array, zones: Array, control := true) -> Dictionary:
	var sides: Array = []
	var held := [0, 0]
	for z: Dictionary in zones:
		if int(z["owner"]) >= 0:
			held[int(z["owner"])] += 1
	for t in 2:
		var own: Array = []
		for z: Dictionary in zones:
			own.append({"name": z["name"], "label": z["label"], "held": int(z["owner"]) == t,
					"fill": clampf(float(z["progress"]) * (1.0 if t == 0 else -1.0), 0.0, 1.0)})
		sides.append({"team": t, "faction": ["condemned", "law"][t], "name": ["CONDEMNED", "LAW"][t],
				"points": points[t], "points_to_win": 90, "to_win": 90 - int(points[t]),
				"rate": float(held[t]) / float(maxi(1, zones.size())) if control else 0.0, "zones": own,
				"zones_held": held[t], "kills": kills[t], "points_destroyed": credits[t], "units_alive": 20})
	var shell := {"version": 1, "tick": 0, "seconds": 0.0, "control": control, "finished": false, "points_to_win": 90,
			"objectives": zones, "sides": sides}
	shell["leader"] = MatchScore.leader(sides, control)
	return shell


func _run() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#1a1c26")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.add_child(backdrop)
	var floor_hint := ColorRect.new()  # a lighter band where the arena floor would be, so contrast is honest
	floor_hint.color = Color("#3a3f4f")
	floor_hint.position = Vector2(0, root.size.y * 0.25)
	floor_hint.size = Vector2(root.size.x, root.size.y * 0.75)
	layer.add_child(floor_hint)
	var west := "the west ring"
	var east := "the east ring"
	var states := [
		["1_fresh", [], snap([0, 0], [0, 0], [0, 0], [zone(west, -75, -1, 0.0), zone(east, 75, -1, 0.0)]), 0.1],
		["2_one_taken", snap([0, 0], [0, 0], [0, 0], [zone(west, -75, -1, 0.9), zone(east, 75, -1, 0.0)]),
				snap([3, 0], [0, 0], [0, 0], [zone(west, -75, 0, 1.0), zone(east, 75, -1, 0.0)]), 0.9],
		["3_both", snap([46, 0], [1, 0], [180, 0], [zone(west, -75, 0, 1.0), zone(east, 75, -1, 0.95)]),
				snap([47, 0], [1, 0], [180, 0], [zone(west, -75, 0, 1.0), zone(east, 75, 0, 1.0)]), 0.3],
		["4_contested", [], snap([22, 18], [2, 3], [420, 610], [zone(west, -75, -1, 0.4, true), zone(east, 75, 1, -1.0)]), 0.4],
		["5_kill", snap([22, 18], [2, 3], [420, 610], [zone(west, -75, -1, 0.4), zone(east, 75, 1, -1.0)]),
				snap([22, 18], [3, 3], [820, 610], [zone(west, -75, -1, 0.4), zone(east, 75, 1, -1.0)]), 0.25],
		["6_lead_change", snap([40, 40], [3, 4], [700, 650], [zone(west, -75, -1, 0.0), zone(east, 75, 1, -1.0)]),
				snap([40, 41], [3, 4], [700, 650], [zone(west, -75, -1, 0.0), zone(east, 75, 1, -1.0)]), 0.6],
		["6b_lead_change_rust", snap([40, 41], [3, 4], [700, 650], [zone(west, -75, 0, 1.0), zone(east, 75, 1, -1.0)]),
				snap([42, 41], [3, 4], [700, 650], [zone(west, -75, 0, 1.0), zone(east, 75, 1, -1.0)]), 0.6],
		["7_final_seconds", snap([83, 61], [6, 5], [1940, 1310], [zone(west, -75, 0, 1.0), zone(east, 75, 0, 1.0)]),
				snap([84, 61], [6, 5], [1940, 1310], [zone(west, -75, 0, 1.0), zone(east, 75, 0, 1.0)]), 0.2],
		["8_centre_map", [], snap([12, 30], [1, 2], [150, 460], [zone("the centre", 0, 1, -1.0)]), 0.4],
		["9_no_control", [], snap([0, 0], [4, 2], [1100, 520], [], false), 0.4],
	]
	for state in states:
		var bug := ScoreBug.new()
		layer.add_child(bug)
		var s := CyberStyle.ui_scale(Vector2(root.size))
		bug.size = ScoreBug.SIZE_1080 * s
		bug.position = Vector2(round((root.size.x - bug.size.x) / 2.0), round(10.0 * s))
		if state[1] is Dictionary:
			bug.set_snapshot(state[1])
			bug._animate(5.0)
		bug.set_snapshot(state[2])
		bug._animate(float(state[3]))
		bug.set_process(false)
		for i in 3:
			await process_frame
		var image := root.get_texture().get_image()
		var path := "%s/%s_%s.png" % [out_dir, state[0], suffix]
		image.save_png(path)
		print("BOARD_SHOT %s" % path)
		bug.queue_free()
		await process_frame
	quit()

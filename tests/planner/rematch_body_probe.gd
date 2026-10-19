extends SceneTree
## Round 34 (planner, C34.6 (1); measurement only): traffic's same-process rematch case (ov_replay.md), on brains' body
## stage (BodyStage, the Locks, body OFF), `--runs=N` times in ONE process after `--idle=K` physics frames. Each run
## prints REMATCH_BODY {"run", "alone_s", "arrived_s", "digest"}: the digest hashes every tank's position, rotation and
## both velocities at every match tick, so runs (and processes) compare bit for bit.
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/planner/rematch_body_probe.gd -- --seed=5 --runs=3

var _match: Match
var _digest := 0
var _last_tick := -1
var _rows: Array = []  # per run: tick -> rows


func _initialize() -> void:
	physics_frame.connect(_sample)
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _sample() -> void:
	if _match == null or not is_instance_valid(_match) or not _match.is_inside_tree():
		_match = null
		for node in root.find_children("*", "Match", true, false):
			_match = node as Match
		if _match == null:
			return
	if _match.tick < int(_flag("from", "1")) or _match.tick == _last_tick:
		return  # only match ticks from `--from=T` (the stage snaps its hulls to their spawns after tick 1) are compared
	_last_tick = _match.tick
	var rows: Array = []
	for tank in _match._sorted_tanks():
		rows.append([String(tank.name), tank.global_position, tank.rotation, tank.velocity, tank.real_velocity])
	_digest = hash([_digest, _match.tick, rows])
	(_rows[_rows.size() - 1] as Dictionary)[_match.tick] = rows


## The first match tick where this run's rows differ from the previous run's, and every unit that differs then.
func _first_diff(run: int) -> void:
	var was: Dictionary = _rows[run - 1]
	var now: Dictionary = _rows[run]
	var ticks := now.keys()
	ticks.sort()
	for tick: int in ticks:
		if var_to_bytes(was.get(tick, [])) == var_to_bytes(now[tick]):
			continue
		var before: Array = was.get(tick, [])
		for i in (now[tick] as Array).size():
			if i >= before.size() or var_to_bytes(before[i]) != var_to_bytes(now[tick][i]):
				print("REMATCH_BODY_DIFF run=%d tick=%d was=%s now=%s" % [run, tick, str(before[i] if i < before.size() else []),
						str(now[tick][i])])
		return


func _run() -> void:
	for i in int(_flag("idle", "0")):
		await physics_frame
	var case := TestCase.new()
	case.tree = self
	Element.BODY_ENABLED = false
	for run in int(_flag("runs", "3")):
		_match = null
		_digest = 0
		_last_tick = -1
		_rows.append({})
		var report: Dictionary = await BodyStage.run(case, int(_flag("seed", "1")), float(_flag("seconds", "60")))
		print("REMATCH_BODY " + JSON.stringify({"run": run, "seed": int(_flag("seed", "1")), "idle": int(_flag("idle", "0")),
				"alone_s": report["alone_s"], "arrived_s": report["arrived_s"], "digest": _digest}))
		if run > 0:
			_first_diff(run)
	Element.BODY_ENABLED = true
	await case._teardown()
	quit(0)

extends SceneTree
## Round 29 (brains B4): the gang trucks' screen slots. Manoeuvre's lead (round 28): four gang gun trucks (10 m hulls)
## screening to [LANE_X, 0] facing east from 50 m south get slots one truck must parallel-park into (TacticsLab seed 61);
## it shuffles about a minute. Prints every second the slots in force, their pitch against the hull length, and each crew's
## distance off its slot, heading and movement phase, and the second the last crew is in.
##
##   godot --headless --path . --script res://tests/tactics/screen_slots_probe.gd -- --seed=61 --unit=gang_tank
##         --seconds=90 [--facing=east|none]
##   SCREEN_SLOTS lines; SCREEN_SLOTS_PROBE {report}

const IN_M := 4.0


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	var case := TestCase.new()
	case.tree = self
	BrainSwitches.ensure_parsed()
	TacticsFlags.requested()
	var unit_id := _flag("unit", "gang_tank")
	var lab := TacticsLab.create(case, int(_flag("seed", "61")))
	var names: Array = []
	for i in 4:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1),
				Vector3(TacticsScenarios.LANE_X + i * 8.0 - 12.0, 0, 50), 0.0, unit_id).name))
	var alpha := lab.element(names, "Alpha")
	await lab.start()
	var task := {"verb": "screen", "to": [TacticsScenarios.LANE_X, 0.0]}
	if _flag("facing", "east") == "east":
		task["facing"] = [1.0, 0.0]
	var refused := alpha.assign(task)
	var seconds := float(_flag("seconds", "90"))
	var all_in_s := -1.0
	var pitch_m := -1.0
	var in_s := {}
	var worst_off := {}
	for tick in int(SimClock.TICK_RATE * seconds):
		await lab.step()
		var t := (tick + 1) / float(SimClock.TICK_RATE)
		var slots: Array = []
		for unit_name: String in names:
			if alpha.slots.get(unit_name) is Vector3:
				slots.append(alpha.slots[unit_name])
		var pitch_now := INF
		for a in slots.size():
			for b in range(a + 1, slots.size()):
				pitch_now = minf(pitch_now, Vector2((slots[a] as Vector3).x - (slots[b] as Vector3).x,
						(slots[a] as Vector3).z - (slots[b] as Vector3).z).length())
		if String(alpha.formation) == "line" and slots.size() == names.size():
			pitch_m = pitch_now if pitch_m < 0.0 else minf(pitch_m, pitch_now)
		if (tick + 1) % SimClock.TICK_RATE == 0:
			var shown := PackedStringArray()
			for slot: Vector3 in slots:
				shown.append("(%.1f, %.1f)" % [slot.x, slot.z])
			print("SCREEN_SLOTS t=%.0f formation %s drill %s heading %s pitch %.1f m (hull %.1f m) slots %s" % [t,
					alpha.formation, alpha.drill, str(alpha.heading), pitch_now,
					float((Units.stat(unit_id, "hull_size", [0, 0, -1.0]) as Array)[2]), " ".join(shown)])
		var every := true
		for unit_name: String in names:
			var tank := lab.tank_of(unit_name)
			var slot: Variant = alpha.slots.get(unit_name)
			if tank == null or not (slot is Vector3):
				every = false
				continue
			var off := Vector2(tank.global_position.x - (slot as Vector3).x, tank.global_position.z - (slot as Vector3).z).length()
			worst_off[unit_name] = off
			if off <= IN_M and not in_s.has(unit_name):
				in_s[unit_name] = t
			if off > IN_M:
				every = false
		if every and all_in_s < 0.0:
			all_in_s = t
		if (tick + 1) % SimClock.TICK_RATE == 0:
			var parts := PackedStringArray()
			for unit_name: String in names:
				var tank := lab.tank_of(unit_name)
				var ctl := lab.game_match.brains.get_node_or_null(NodePath("Brain_" + unit_name)) as OrderController
				var fwd := -tank.global_basis.z
				parts.append("%s off %.1f hdg (%.2f, %.2f) %s %s" % [unit_name.trim_prefix("Green_"),
						float(worst_off.get(unit_name, -1.0)), fwd.x, fwd.z,
						String(ctl.movement.phase) if ctl != null else "-",
						String(ctl.movement.get("blocked_by")) if ctl != null else ""])
			print("SCREEN_SLOTS t=%.0f %s" % [t, " | ".join(parts)])
	var report := {"seed": int(_flag("seed", "61")), "unit": unit_id, "refused": refused, "pitch_m": pitch_m,
			"all_in_s": all_in_s, "in_s": in_s, "end_off_m": worst_off, "heading": str(alpha.heading)}
	print("SCREEN_SLOTS_PROBE " + JSON.stringify(report))
	lab.dispose()
	case.teardown()
	quit(0)

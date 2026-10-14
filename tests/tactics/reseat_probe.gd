extends SceneTree
## Round 29 (brains B5a): the element's seating traced in traffic's crossing cases (TrafficStage, its own stage, run
## through its `on_tick` hook). Traffic's Terminus head-on (seed 1, tick 11) and round 28's Sumps cell both leave crews
## re-seated beside a block, on seats whose slot reads `no_path`. Every element event (re-seat, make room) is printed as it
## happens, and whenever a crew's seat or slot changes: its slot, how far the navmesh path from the crew ends short of the
## slot (the gap Movement reads as `no_path` past NO_PATH_MARGIN) and its movement phase.
##
##   godot --headless --path . --script res://tests/tactics/reseat_probe.gd -- --arena=terminus --kind=head --seed=1
##         --seconds=90 [--lab-start-tick=N]
##   RESEAT_TRACE lines; RESEAT_PROBE {report}

var case: TestCase
var _seen_events := {}
var _last_slots := {}


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	BrainSwitches.ensure_parsed()
	TacticsFlags.requested()
	var report := await TrafficStage.run(case, int(_flag("seed", "1")), _flag("arena", "terminus"),
			_flag("kind", "head"), _flag("which", "both"), float(_flag("seconds", "90")), _flag("side", "green"),
			false, _watch)
	report["gates_given_up"] = Movement.gates_given_up
	report["gates_reached_latched"] = Movement.gates_reached_latched
	report["gates_shortened"] = Movement.gates_shortened
	report["gate_refusals"] = Movement.gate_refusals.duplicate()
	report["gates_aimed"] = Movement.gates_aimed
	print("RESEAT_PROBE " + JSON.stringify(report))
	case.teardown()
	quit(0)


func _watch(lab: TacticsLab, ticks: int) -> void:
	var t := ticks / float(SimClock.TICK_RATE)
	# Every two seconds, a crew not yet in: where it is, which way it points, what its route aims at, and its phase.
	if ticks % (SimClock.TICK_RATE * 2) == 0:
		for element: Element in lab.elements.all():
			for unit_name: String in element.slots:
				var ctl := lab.game_match.brains.get_node_or_null(NodePath("Brain_" + unit_name)) as OrderController
				var tank := lab.tank_of(unit_name)
				var slot: Variant = element.slots[unit_name]
				if ctl == null or tank == null or not (slot is Vector3) or String(ctl.movement.phase) == "arrived":
					continue
				var fwd := -tank.global_basis.z
				print("RESEAT_TRACE t=%.1f TRACK %s at (%.1f, %.1f) heading (%.2f, %.2f) slot (%.1f, %.1f) %.1f m off; phase %s blocked %s path_goal %s gate_dropped_for %s stalled %d" % [
						t, unit_name, tank.global_position.x, tank.global_position.z, fwd.x, fwd.z, (slot as Vector3).x,
						(slot as Vector3).z, Vector2(tank.global_position.x - (slot as Vector3).x,
						tank.global_position.z - (slot as Vector3).z).length(), String(ctl.movement.phase),
						String(ctl.movement.get("blocked_by")), str(ctl.movement.get("_path_goal")),
						str(ctl.movement.get("_gate_dropped_for")), int(ctl.movement.stalled_ticks)])
	# Every half second, a crew reading blocked/no_path: what its Movement planned to and what the route reading said.
	if ticks % (SimClock.TICK_RATE / 2) == 0:
		for element: Element in lab.elements.all():
			for unit_name: String in element.slots:
				var ctl := lab.game_match.brains.get_node_or_null(NodePath("Brain_" + unit_name)) as OrderController
				if ctl == null or String(ctl.movement.phase) != "blocked" or String(ctl.movement.blocked_by) != "no_path":
					continue
				var path: PackedVector3Array = ctl.movement.get("_path")
				var reading: Dictionary = ctl.movement.get("_route_reading")
				var tank := lab.tank_of(unit_name)
				print("RESEAT_TRACE t=%.1f NOPATH %s at (%.1f, %.1f) path_goal %s path_end %s (%d points) reachable=%s reading end_gap %.1f goal_gap %.1f last_replan %s gate %s move %s" % [
						t, unit_name, tank.global_position.x, tank.global_position.z, str(ctl.movement.get("_path_goal")),
						str(path[path.size() - 1]) if path.size() > 0 else "-", path.size(), ctl.movement.get("_reachable"),
						float(reading.get("end_gap_m", -1.0)), float(reading.get("goal_gap_m", -1.0)),
						str(ctl.movement.get("last_replan")), str(ctl.movement.get("_gate")) if "_gate" in ctl.movement else "?",
						JSON.stringify(ctl.move_order)])
	for element: Element in lab.elements.all():
		var key := element.element_name
		var seen: int = _seen_events.get(key, 0)
		# events is a capped ring: print what is new since the last look.
		var fresh := element.events.size() - seen if element.events.size() >= seen else element.events.size()
		for i in range(element.events.size() - fresh, element.events.size()):
			print("RESEAT_TRACE t=%.1f %s EVENT %s" % [t, key, element.events[i]])
		_seen_events[key] = element.events.size()
		for unit_name: String in element.slots:
			var slot: Variant = element.slots[unit_name]
			var seat: Variant = element.seats.get(unit_name)
			var was: Array = _last_slots.get(unit_name, [null, null])
			if slot is Vector3 and was[0] is Vector3 and (slot as Vector3).distance_to(was[0]) < 1.0 and str(seat) == str(was[1]):
				continue
			_last_slots[unit_name] = [slot, seat]
			var tank := lab.tank_of(unit_name)
			if tank == null or not (slot is Vector3):
				continue
			var here := Vector3(tank.global_position.x, 0.0, tank.global_position.z)
			var path := Pathing.find_path(tank, here, slot)
			var short := (Vector2(path[path.size() - 1].x - (slot as Vector3).x,
					path[path.size() - 1].z - (slot as Vector3).z).length()) if path.size() > 0 else -1.0
			var ctl := lab.game_match.brains.get_node_or_null(NodePath("Orders_" + unit_name)) as OrderController
			if ctl == null:
				ctl = lab.game_match.brains.get_node_or_null(NodePath("Brain_" + unit_name)) as OrderController
			print("RESEAT_TRACE t=%.1f %s SEAT %s seat %s slot (%.1f, %.1f) crew (%.1f, %.1f) %.1f m off; path ends %.1f m short%s; arrived=%s phase %s blocked %s" % [
					t, key, unit_name, str(seat), (slot as Vector3).x, (slot as Vector3).z, here.x, here.z,
					here.distance_to(slot), short, " NO_PATH" if short > Movement.NO_PATH_MARGIN else "", element.arrived,
					String(ctl.movement.phase) if ctl != null else "-",
					String(ctl.movement.get("blocked_by")) if ctl != null else "-"])

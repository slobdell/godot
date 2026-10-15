extends SceneTree
## Round 30 (brains B6): support by fire, traced per crew. Round 29's hull-rest probe (control's screen playtest) judged a
## drawn SBF when every hull had been still 3 s, but support by fire never sets the element's `arrived`, and in every law
## run, both arms, the crews were read on the way ("settled" ~19 s, crews still short of their slots). This probe reads
## each crew ONLY once it is truly in: within IN_M of its slot and still for STILL_S. Four crews of `--unit` in a column
## on the TacticsLab ground are given support by fire on a point 100 m ahead, with a drawn facing (`--facing=drawn`,
## FACED_OFF_TRAVEL_DEG off the travel, as control's probe draws it) or none (`--facing=none`, the automatic pick).
## No enemy: contact would turn the guns to it, by design.
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/tactics/sbf_probe.gd -- --unit=law_tank --seed=1
##         --facing=drawn|none [--seconds=60] [--trace=on]
##   SBF_TRACK lines (each crew once a second, --trace=on); SBF_PROBE {report}

const LANE_X := -98.0
const IN_M := 8.0
const STILL_S := 2.0
const STILL_MPS := 0.3
const FACED_OFF_TRAVEL_DEG := 60.0

var case: TestCase


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


static func _err(tank: Tank, facing: Vector3) -> float:
	var nose := -tank.global_basis.z
	return absf(rad_to_deg(Vector2(nose.x, nose.z).angle_to(Vector2(facing.x, facing.z))))


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	BrainSwitches.ensure_parsed()
	TacticsFlags.requested()
	var unit_id := _flag("unit", "law_tank")
	var seed_value := int(_flag("seed", "1"))
	var drawn := _flag("facing", "drawn") == "drawn"
	var seconds := float(_flag("seconds", "60"))
	var trace := _flag("trace", "off") == "on"
	var lab := TacticsLab.create(case, seed_value)
	var names: Array = []
	# The seed jitters each crew's start (±3 m, ±10 degrees), so seeds are different runs (the lab alone is deterministic).
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value
	for i in 4:
		var at := Vector3(LANE_X + jitter.randf_range(-3.0, 3.0), 0.0, 40.0 + i * 14.0 + jitter.randf_range(-3.0, 3.0))
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1), at,
				deg_to_rad(jitter.randf_range(-10.0, 10.0)), unit_id).name))
	var point := Vector3(LANE_X, 0.0, -60.0)
	var travel := Vector3(0, 0, -1)
	var facing := travel.rotated(Vector3.UP, deg_to_rad(FACED_OFF_TRAVEL_DEG)).normalized()
	var alpha := lab.element(names, "Alpha")
	await lab.start()
	var task := {"verb": "support_by_fire", "to": [point.x, point.z]}
	if drawn:
		task["facing"] = [facing.x, facing.z]
	alpha.assign(task)
	var still := {}
	var in_s := {}
	var err_in := {}
	var last := {}
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		if tick % SimClock.TICK_RATE != 0 and tick % (SimClock.TICK_RATE / 2) != 0:
			continue
		var t := tick / float(SimClock.TICK_RATE)
		var want := facing  # both arms judged against the same heading (control's O3 rule): what drawing it buys
		for unit_name: String in names:
			var tank := lab.tank_of(unit_name)
			if tank == null or not tank.is_alive():
				continue
			var at := Vector3(tank.global_position.x, 0.0, tank.global_position.z)
			var slot: Variant = alpha.slots.get(unit_name)
			var off := at.distance_to(slot) if slot is Vector3 else INF
			var moving := tank.estimated_velocity.length() > STILL_MPS
			still[unit_name] = 0.0 if moving else float(still.get(unit_name, 0.0)) + 0.5
			if not in_s.has(unit_name) and off <= IN_M and float(still[unit_name]) >= STILL_S:
				in_s[unit_name] = t
				err_in[unit_name] = snappedf(_err(tank, want), 0.1)
			last[unit_name] = {"off_m": snappedf(off, 0.1), "err_deg": snappedf(_err(tank, want), 0.1), "moving": moving}
			if trace and tick % SimClock.TICK_RATE == 0:
				var st := Movement.state(tank)
				print("SBF_TRACK " + JSON.stringify({"t": t, "n": unit_name, "at": [snappedf(at.x, 0.1), snappedf(at.z, 0.1)],
						"slot": [snappedf((slot as Vector3).x, 0.1), snappedf((slot as Vector3).z, 0.1)] if slot is Vector3 else null,
						"off_m": snappedf(off, 0.1), "err_deg": snappedf(_err(tank, want), 0.1), "v": snappedf(tank.estimated_velocity.length(), 0.1),
						"phase": String(st.get("phase", "")), "blocked": st.get("blocked_by"), "drill": alpha.drill,
						"formation": alpha.formation, "k1": lab.orders.call("current", unit_name)}))
	var errs: Array = err_in.values()
	errs.sort()
	var report := {"unit": unit_id, "seed": seed_value, "facing": "drawn" if drawn else "none",
			"in_s": in_s, "err_in_deg": err_in, "end": last, "crews_in": in_s.size(), "crews": names.size(),
			"median_err_in_deg": errs[errs.size() / 2] if not errs.is_empty() else -1.0,
			"sbf_told_replaced": int(ElementPlan.get("sbf_told_replaced")) if ElementPlan.get("sbf_told_replaced") != null else -1}
	print("SBF_PROBE " + JSON.stringify(report))
	case.teardown()
	quit(0)

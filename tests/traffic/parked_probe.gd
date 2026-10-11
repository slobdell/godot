extends SceneTree
## Round 26 (traffic CP1a2, the orchestrator's falsifier): a friend PARKED in the only lane to where another crew is
## sent. The maze's west serpentine is 8 m wide (two War Rigs cannot pass: their avoidance radii sum to ~9.2 m). Crew P
## is moved into the lane and parks there; then crew A, behind it, is sent past it to just beyond. Does A get there (P
## gives way when asked, or ORCA/unstick squeeze it past), or do they deadlock? Run both arms: `--traffic-off=parked`
## is the old rule (a refused asker gives way to the parked friend itself).
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/traffic/parked_probe.gd -- --seed=1
##         --parked=gang_tank --asker=law_tank --seconds=60 [--traffic-off=parked] [--trace=on]
##   PARKED_PROBE {"reached_s", "gap_m", "parked_moved_m", "asks_refused", "parked_refusals", "yields_started", ...}

const LANE_X := -56.0
const PARK_Z := 76.0
const ASKER_Z := 89.0
const GOAL_Z := 66.0
const REACHED_M := 4.0

var case: TestCase


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
	var trace := _flag("trace", "off") == "on"
	var lab := TacticsLab.create(case, int(_flag("seed", "1")), "maze")
	lab.game_match.set_meta("player_team", Match.Team.GREEN)
	var south := atan2(0.0, 1.0)  # facing -Z (forward is -Z): yaw 0
	var parked := lab.unit(Match.Team.GREEN, "Green_P_1", Vector3(LANE_X, 0.0, PARK_Z + 6.0), south, _flag("parked", "gang_tank"))
	var asker := lab.unit(Match.Team.GREEN, "Green_A_1", Vector3(LANE_X, 0.0, ASKER_Z + 8.0), south, _flag("asker", "law_tank"))
	await lab.start()
	var p_element := lab.elements.form([String(parked.name)], "Parked")
	p_element.assign({"verb": "move", "to": [LANE_X, PARK_Z]})
	for tick in SimClock.TICK_RATE * 15:
		await lab.step()
		if p_element.arrived and parked.estimated_velocity.length() < 0.3 and tick > SimClock.TICK_RATE * 3:
			break
	var parked_at := Vector3(parked.global_position.x, 0.0, parked.global_position.z)
	var a_element := lab.elements.form([String(asker.name)], "Asker")
	a_element.assign({"verb": "move", "to": [LANE_X, GOAL_Z]})
	var goal := Vector3(LANE_X, 0.0, GOAL_Z)
	var reached := -1
	var parked_moved := 0.0
	var seconds := float(_flag("seconds", "60"))
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		var here := Vector3(asker.global_position.x, 0.0, asker.global_position.z)
		parked_moved = maxf(parked_moved, parked_at.distance_to(Vector3(parked.global_position.x, 0.0, parked.global_position.z)))
		if trace and tick % (SimClock.TICK_RATE / 2) == 0:
			for t: Tank in [asker, parked]:
				var r := Movement.state(t)
				print("PARKED_TRACK " + JSON.stringify({"t": snappedf(float(tick) / SimClock.TICK_RATE, 0.1), "n": String(t.name),
						"at": [snappedf(t.global_position.x, 0.1), snappedf(t.global_position.z, 0.1)],
						"phase": String(r.get("phase", "")), "blocked": r.get("blocked_by"), "yield": r.get("yield_to"),
						"kturn": Movement.of(t).in_kturn()}))
		if reached < 0 and here.distance_to(goal) <= REACHED_M:
			reached = tick
			break
	var arms := Movement.route_arms()
	var report := {"seed": int(_flag("seed", "1")), "parked": _flag("parked", "gang_tank"), "asker": _flag("asker", "law_tank"),
			"parked_at": [snappedf(parked_at.x, 0.1), snappedf(parked_at.z, 0.1)],
			"reached_s": snappedf(float(reached) / SimClock.TICK_RATE, 0.1) if reached >= 0 else -1.0,
			"gap_m": snappedf(Vector3(asker.global_position.x, 0.0, asker.global_position.z).distance_to(goal), 0.1),
			"parked_moved_m": snappedf(parked_moved, 0.1), "asks_refused": arms.get("asks_refused"),
			"parked_refusals": arms.get("parked_refusals"), "yields_started": arms.get("yields_started"),
			"unstick_fires": arms.get("unstick_fires"), "traffic_off": _flag("traffic-off", "")}
	print("PARKED_PROBE " + JSON.stringify(report))
	lab.dispose()
	case.teardown()
	quit(0)

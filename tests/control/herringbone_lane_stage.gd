class_name HerringboneLaneStage
extends RefCounted
## Round 36 (orders O1, C36.4): AN ARRIVED HERRINGBONE ACROSS ANOTHER SQUAD'S LANE, built deterministically. The body stage's
## s1 (R35.17, R35.72, R35.77): Hunters2 arrives at its spot on the Locks' west corner (~(-65, 70)), deploys from its travel
## wedge into the Law's lane halt (a herringbone), and Hunters2_3's seat lands ~2 m into the street the Sirens turn south
## down; Sirens_1 is held 9+ s. In the body stage that happens in 1 seed of 12 (the jitter decides who is where when the
## deploy fires), so no series line could see a fix through its noise (R35.77). Here both squads start from s1's own
## snapshot (the trace at tick 147, no jitter) and get their goals on one frame, so the deploy fires while the Sirens are a
## street behind it, every run. `lead_m` slides the Sirens back along their street (each cell a fixed geometry).
## Shared by tests/control/herringbone_lane_probe.gd (one process a run, R33.14) and tests/test_control_herringbone_lane.gd.
##
## Report: the Sirens' arrival (`sirens_s`, the stage's all-in), Hunters2's arrival and deploy tick, THE JAM'S OWN COUNTER
## (`held_s`: Sirens crew-seconds standing, under HELD_SPEED, within HELD_NEAR_M of a Hunters2 crew, before the Sirens are
## in; `held_worst_s` the worst crew's), and the deploy waits X3b's DEPLOY_PASS made (`pass_waits`).

const HUNTERS2 := {"name": "Hunters2", "unit": "law_ifv", "at": [[-43.8, 85.1], [-51.2, 71.8], [-21.4, 69.4]], "to": [-64.8, 69.8]}
const SIRENS := {"name": "Sirens", "unit": "law_suppressor", "at": [[-7.2, 58.5], [-7.5, 64.3], [-13.0, 70.0], [-5.5, 73.1]],
		"to": [-68.5, 20.8]}
## The Sirens' street runs west from their start: `lead_m` moves them east (back) along it, +x.
const SIRENS_BACK := Vector3(1.0, 0.0, 0.0)
const HELD_SPEED := 0.5
const HELD_NEAR_M := 9.0
const SEED := 1
## Measurement only: every crew's position and Hunters2's formation every 0.5 s (HERRINGBONE_TICK lines).
static var TRACE := OS.get_cmdline_user_args().has("--herringbone-trace")


static func run(case: TestCase, seconds: float, lead_m := 0.0, goal_dx := 0.0, goal_dz := 0.0) -> Dictionary:
	var lab := TacticsLab.create(case, SEED, "locks")
	var game_match := lab.game_match
	game_match.set_meta("player_team", Match.Team.GREEN)
	var squads: Array = []
	for spec: Dictionary in [HUNTERS2, SIRENS]:
		var to := Vector3(float(spec["to"][0]) + (goal_dx if spec == HUNTERS2 else 0.0), 0.0, float(spec["to"][1]) + (goal_dz if spec == HUNTERS2 else 0.0))
		var back := SIRENS_BACK * lead_m if spec == SIRENS else Vector3.ZERO
		var names: Array = []
		for i in (spec["at"] as Array).size():
			var p: Array = spec["at"][i]
			var at := Vector3(float(p[0]), 0.0, float(p[1])) + back
			var face := (to - at).normalized()
			var made := lab.unit(Match.Team.GREEN, "Green_%s_%d" % [spec["name"], i + 1], at, atan2(-face.x, -face.z), String(spec["unit"]))
			names.append(String(made.name))
		squads.append({"name": spec["name"], "names": names, "to": to})
	await lab.start()
	for squad: Dictionary in squads:
		for unit_name: String in squad["names"]:
			var t := lab.tank_of(unit_name)
			var at := SlotGround.for_unit(t, t.global_position, String(t.unit_id))
			t.place(Vector3(at.x, 0.0, at.z), t.rotation.y)
			t.velocity = Vector3.ZERO
	for i in 3:
		await lab.step()
	for squad: Dictionary in squads:
		squad["element"] = lab.elements.form(squad["names"], String(squad["name"]))
	var waits_before := int(ElementPlan.deploy_pass_waits)
	for squad: Dictionary in squads:
		(squad["element"] as Element).assign({"verb": "move", "to": [(squad["to"] as Vector3).x, (squad["to"] as Vector3).z],
				"drills": false})
	var given: int = game_match.tick
	var hunters2: Dictionary = squads[0]
	var sirens: Dictionary = squads[1]
	var arrived := {}
	var deployed_tick := -1
	var held := {}
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		for squad: Dictionary in squads:
			if (squad["element"] as Element).arrived and not arrived.has(squad["name"]):
				arrived[squad["name"]] = game_match.tick - given
		var element: Element = hunters2["element"]
		if deployed_tick < 0 and bool(element.deploy.get("deployed", false)):
			deployed_tick = game_match.tick - given
		if TRACE and tick % (SimClock.TICK_RATE / 2) == 0:
			var parts: Array = ["%s[%s %s]" % [element.formation, element.arrived, element.deploy.get("deployed", false)]]
			for squad: Dictionary in squads:
				for unit_name: String in squad["names"]:
					var t := lab.tank_of(unit_name)
					parts.append("%s(%.1f,%.1f %.1f)" % [unit_name.trim_prefix("Green_"), t.global_position.x, t.global_position.z,
							Vector2(t.velocity.x, t.velocity.z).length()])
			print("HERRINGBONE_TICK %d %s" % [tick, " ".join(parts)])
		if arrived.has("Sirens"):
			break
		for unit_name: String in sirens["names"]:
			var t := lab.tank_of(unit_name)
			if t == null or Vector2(t.velocity.x, t.velocity.z).length() >= HELD_SPEED:
				continue
			for other: String in hunters2["names"]:
				var o := lab.tank_of(other)
				if o != null and Vector2(o.global_position.x - t.global_position.x, o.global_position.z - t.global_position.z).length() <= HELD_NEAR_M:
					held[unit_name] = int(held.get(unit_name, 0)) + 1
					break
	var total := 0
	var worst := 0
	for unit_name: String in held:
		total += int(held[unit_name])
		worst = maxi(worst, int(held[unit_name]))
	var report := {"lead_m": lead_m, "goal_dx": goal_dx, "goal_dz": goal_dz, "pass": ElementPlan.DEPLOY_PASS, "step": ElementPlan.DEPLOY_STEP,
			"sirens_s": _s(int(arrived.get("Sirens", -1))), "hunters2_s": _s(int(arrived.get("Hunters2", -1))),
			"deployed_s": _s(deployed_tick), "held_s": _s(total), "held_worst_s": _s(worst),
			"pass_waits": int(ElementPlan.deploy_pass_waits) - waits_before}
	lab.dispose()
	return report


static func _s(ticks: int) -> float:
	return snappedf(ticks / float(SimClock.TICK_RATE), 0.1) if ticks >= 0 else -1.0

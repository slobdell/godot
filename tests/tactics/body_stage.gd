class_name BodyStage
extends RefCounted
## Round 24 (brains R2): HIS "one squad took a whole different route" case, measured. His recording (the Locks, seed
## 15833, 26.8 s): three squads selected together and moved west - Sirens (four suppressors at ~(4, 62)) to (-69, 21),
## Hunters 2/3/4/6 (~(-31, 104)) to (-61, 117), Hunters 1/5/7 (~(-8, 67)) to (-65, 70). The Sirens drove south down
## the middle toward the canal, alone, and lost a crew in 4 s; the Hunters went west along the north. Here the same
## three squads stand where his census put them (jittered by `seed`), get their three goals on ONE frame (a plain move,
## as his selection gives), and run without an enemy (the route is the question). Shared by tests/tactics/body_probe.gd
## and tests/test_tactics_body.gd.
##
## Report: alone_s / widest_gap_m (CoherenceProbe, R2's meter), each squad's route choice (Element.body_choice) and
## arrival, the last arrival (arrived_s), and the farthest any squad's centre got from the other squads' (widest_gap_m).

const SQUADS := [
	{"name": "Sirens", "unit": "law_suppressor", "at": [[-0.6, 55.5], [-2.4, 60.9], [1.1, 64.9], [16.1, 65.0]], "to": [-68.5, 20.8]},
	{"name": "Hunters", "unit": "law_ifv", "at": [[-40.5, 110.0], [-14.5, 104.6], [-31.4, 107.6], [-38.9, 92.9]], "to": [-61.2, 117.2]},
	{"name": "Hunters2", "unit": "law_ifv", "at": [[-12.6, 84.5], [-9.0, 68.0], [-1.4, 48.8]], "to": [-64.8, 69.8]},
]
## A split that PAYS (the cost is a cost, not a ban): two squads ordered across the Locks together, one by each flank
## swing bridge. The body's route runs over the lock in the middle; keeping with it would cost each squad ~180 m of
## detour, so each should take its own bridge.
const SPLIT := [
	{"name": "West", "unit": "law_tank", "at": [[-96.0, 40.0], [-88.0, 40.0], [-96.0, 48.0], [-88.0, 48.0]], "to": [-92.0, -40.0]},
	{"name": "East", "unit": "law_tank", "at": [[96.0, 40.0], [88.0, 40.0], [96.0, 48.0], [88.0, 48.0]], "to": [92.0, -40.0]},
]
const JITTER_M := 2.0


## `cpu`: the squads are the COMPUTER's (his team is the other one) and their task runs drills, as a CPU commander's
## grouped move does (ElementPlan._route_step weighs the body's route then).
static func run(case: TestCase, seed_value: int, seconds: float, mirror := false, cpu := false, specs: Array = SQUADS) -> Dictionary:
	var lab := TacticsLab.create(case, seed_value, "locks")
	var game_match := lab.game_match
	var team := Match.Team.RUST if mirror else Match.Team.GREEN
	var flip := -1.0 if mirror else 1.0
	game_match.set_meta("player_team", (Match.Team.GREEN if mirror else Match.Team.RUST) if cpu else team)
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value
	var squads: Array = []
	for squad: Dictionary in specs:
		var names: Array = []
		var to := Vector3(float(squad["to"][0]), 0.0, float(squad["to"][1])) * flip
		for i in (squad["at"] as Array).size():
			var p: Array = squad["at"][i]
			var at := Vector3(p[0] + jitter.randf_range(-JITTER_M, JITTER_M), 0.0, p[1] + jitter.randf_range(-JITTER_M, JITTER_M)) * flip
			var face := (to - at).normalized()
			names.append(String(lab.unit(team, "%s_%s_%d" % ["Rust" if mirror else "Green", squad["name"], i + 1], at,
					atan2(-face.x, -face.z), String(squad["unit"])).name))
		squads.append({"name": squad["name"], "names": names, "to": to})
	await lab.start()
	for squad: Dictionary in squads:
		for unit_name: String in squad["names"]:
			var t := lab.tank_of(unit_name)
			var at := SlotGround.for_unit(t, t.global_position, String(t.unit_id))
			t.global_position = Vector3(at.x, 0.0, at.z)
	for i in 3:
		await lab.step()
	var probe := CoherenceProbe.attach(game_match)
	for squad: Dictionary in squads:
		squad["element"] = lab.elements.form(squad["names"], String(squad["name"]))
	# One frame: his selection's order reaches every squad together.
	for squad: Dictionary in squads:
		var task := {"verb": "move", "to": [(squad["to"] as Vector3).x, (squad["to"] as Vector3).z]}
		if not cpu:
			task["drills"] = false
		(squad["element"] as Element).assign(task)
	var given: int = game_match.tick
	var arrived := {}
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		for squad: Dictionary in squads:
			var element: Element = squad["element"]
			if element.arrived and not arrived.has(squad["name"]):
				arrived[squad["name"]] = game_match.tick - given
		if arrived.size() == squads.size():
			break
	var report := {"seed": seed_value, "side": ("cpu-" if cpu else "") + ("rust" if mirror else "green"),
			"body": "on" if Element.BODY_ENABLED else "off"}
	var coherence: Dictionary = probe.report()["rust" if mirror else "green"]
	report["alone_s"] = coherence["alone_s"]
	report["widest_gap_m"] = coherence["widest_gap_m"]
	var last := -1
	for squad: Dictionary in squads:
		var element: Element = squad["element"]
		var a := int(arrived.get(squad["name"], -1))
		report[String(squad["name"])] = {"choice": element.body_choice, "arrived_s": _s(a)}
		last = maxi(last, a)
	report["arrived_s"] = _s(last) if arrived.size() == squads.size() else -1.0
	lab.dispose()
	return report


static func _s(ticks: int) -> float:
	return snappedf(ticks / float(SimClock.TICK_RATE), 0.1) if ticks >= 0 else -1.0

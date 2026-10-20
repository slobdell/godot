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


## Round 32 (R32.6): spawns are set apart before the match starts. The jitter put Sirens 2 and 3 3.8 m apart, their hulls
## overlapping, and the physics separated them on the first frame of the FIRST match in a process only (traced, builder0:
## no brain moved them, order stop, velocity 0; ~2 m each), so the same stage read alone_s 12.0 run first and 24.5 run after
## any other match, and test_tactics_body passed or failed by the order of the shard. `apart`: each spawn pushed straight
## away from any earlier one until their turning envelopes (SlotGround.envelope_of) no longer meet.
static var SPAWN_APART := true


## Every crew's [spawn point, envelope], in spec order: the spec plus the seeded jitter, set apart (SPAWN_APART). Pure.
static func spawns(seed_value: int, specs: Array = SQUADS, mirror := false) -> Array:
	var flip := -1.0 if mirror else 1.0
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value
	var placed: Array = []
	for squad: Dictionary in specs:
		var envelope := SlotGround.envelope_of(String(squad["unit"]))
		for p: Array in squad["at"]:
			var at := Vector3(p[0] + jitter.randf_range(-JITTER_M, JITTER_M), 0.0, p[1] + jitter.randf_range(-JITTER_M, JITTER_M)) * flip
			if SPAWN_APART:
				at = BodyStage.apart(at, envelope, placed)
			placed.append([at, envelope])
	return placed


static func apart(at: Vector3, envelope: float, placed: Array) -> Vector3:
	for _pass in 16:  # pushing off one may land on another: until none meets (bounded)
		var moved := false
		for spot: Array in placed:
			var other: Vector3 = spot[0]
			var need := envelope + float(spot[1])
			var away := Vector3(at.x - other.x, 0.0, at.z - other.z)
			if away.length() >= need - 0.001:
				continue
			var direction := away.normalized() if away.length() > 0.01 else Vector3.RIGHT
			at = Vector3(other.x, at.y, other.z) + direction * need
			moved = true
		if not moved:
			break
	return at


## Round 32 (R32.6), MEASUREMENT ONLY: every crew's position, brain option and order every 0.25 s (BODY_TICK lines), to
## find where two runs of the same stage part.
static var TRACE := OS.get_cmdline_user_args().has("--body-trace")


static func _trace_bare(game_match: Match, squads: Array, tick: int) -> void:
	var parts: Array = []
	for squad: Dictionary in squads:
		for unit_name: String in squad["names"]:
			var t := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if t != null:
				parts.append("%s(%.2f,%.2f)" % [unit_name, t.global_position.x, t.global_position.z])
	print("BODY_TICK %d %s" % [tick, " ".join(parts)])


static func _trace(game_match: Match, squads: Array, tick: int) -> void:
	var parts: Array = []
	for squad: Dictionary in squads:
		var element: Element = squad["element"]
		parts.append("%s[%s %s]" % [squad["name"], element.formation, element.arrived])
		for unit_name: String in squad["names"]:
			var t := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if t == null:
				continue
			var option := ""
			var mover := Movement.of(t)
			if mover != null and mover.ctl is TankBrain:
				option = String((mover.ctl as TankBrain).choice.get("option", ""))
			parts.append("%s(%.1f,%.1f %s)" % [unit_name.substr(unit_name.length() - 2), t.global_position.x,
					t.global_position.z, option])
	print("BODY_TICK %d %s" % [tick, " ".join(parts)])


## `cpu`: the squads are the COMPUTER's (his team is the other one) and their task runs drills, as a CPU commander's
## grouped move does (ElementPlan._route_step weighs the body's route then).
static func run(case: TestCase, seed_value: int, seconds: float, mirror := false, cpu := false, specs: Array = SQUADS) -> Dictionary:
	var lab := TacticsLab.create(case, seed_value, "locks")
	var game_match := lab.game_match
	var team := Match.Team.RUST if mirror else Match.Team.GREEN
	var flip := -1.0 if mirror else 1.0
	game_match.set_meta("player_team", (Match.Team.GREEN if mirror else Match.Team.RUST) if cpu else team)
	var points := BodyStage.spawns(seed_value, specs, mirror)
	var spawned := {}
	var squads: Array = []
	var n := 0
	for squad: Dictionary in specs:
		var names: Array = []
		var to := Vector3(float(squad["to"][0]), 0.0, float(squad["to"][1])) * flip
		for i in (squad["at"] as Array).size():
			var at: Vector3 = (points[n] as Array)[0]
			n += 1
			var face := (to - at).normalized()
			spawned["%s_%s_%d" % ["Rust" if mirror else "Green", squad["name"], i + 1]] = at
			var made := lab.unit(team, "%s_%s_%d" % ["Rust" if mirror else "Green", squad["name"], i + 1], at,
					atan2(-face.x, -face.z), String(squad["unit"]))
			if TRACE:
				print("BODY_SPAWN %s asked (%.2f, %.2f) set (%.2f, %.2f)" % [made.name, at.x, at.z, made.global_position.x,
						made.global_position.z])
			names.append(String(made.name))
		squads.append({"name": squad["name"], "names": names, "to": to})
	await lab.start()
	if TRACE:
		print("BODY_START waited %d frames for the navmesh, match tick %d" % [lab.waited_frames, game_match.tick])
		for squad: Dictionary in squads:
			for unit_name: String in squad["names"]:
				var t := lab.tank_of(unit_name)
				var mover := Movement.of(t)
				var brain := mover.ctl as TankBrain if mover != null else null
				print("BODY_START %s at (%.2f, %.2f) velocity (%.2f, %.2f) option %s move %s" % [unit_name, t.global_position.x,
						t.global_position.z, t.velocity.x, t.velocity.z, brain.choice.get("option", "") if brain != null else "-",
						brain.move_order if brain != null else "-"])
	for squad: Dictionary in squads:
		for unit_name: String in squad["names"]:
			var t := lab.tank_of(unit_name)
			if TRACE:
				print("BODY_PLACE %s spawned (%.2f, %.2f)" % [unit_name, t.global_position.x, t.global_position.z])
			# Round 32 (R32.6): snap the INTENDED spawn, not where the first frame left the hull. A hull touching anything at
			# spawn is moved by the physics on the first frame of a process's first match only (off arm: 41.0, 37.0, 28.5 on
			# three matches in one process, builder0; Hunters2_1 already 7 cm apart at start), so the stage started each
			# match from a different spot.
			var intended: Vector3 = spawned[unit_name]
			var at := SlotGround.for_unit(t, intended, String(t.unit_id))
			t.place(Vector3(at.x, 0.0, at.z), t.rotation.y)  # round 35 (E4): the body with the node, not a tick later
			t.velocity = Vector3.ZERO
			if TRACE:
				print("BODY_PLACE %s snapped (%.2f, %.2f)" % [unit_name, at.x, at.z])
	for i in 3:
		await lab.step()
		if TRACE:
			_trace_bare(game_match, squads, -1 - i)
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
		if TRACE and tick % (SimClock.TICK_RATE / 4) == 0:
			_trace(game_match, squads, tick)
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

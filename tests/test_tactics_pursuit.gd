extends TestCase
## Round 21 (brains P2): AN ATTACK ON A NAMED TARGET THAT MOVES IS A PURSUIT. His game (foundry, seed 29989,
## build/recordings/2026-10-06T18-38-40.jsonl, tick 1827): he named `Rust_Eyes_3`, a Syndicate spotter retreating from
## (-33, 6) to (15, -112) over 17 s; Bravo_1 drove past the target's old spot and back (an orbit ~40 m across) and
## Delta_1, the last of his scouts, "arrived" 70 m short and sat. *"even when there was only one vehicle remaining it was
## still just driving in circles instead of actually moving to the target I designated"*.
##
## The stage: the open yard, five gang scouts (Rat Rods, 18 m/s, the spear's 30 m) abreast at the Green spawn, HIS squad,
## {"verb": "attack", "target": <it>, "formation": "vee"}; one Syndicate spotter platform 70 m ahead that drives away
## from them, then doglegs, at a set speed. Measured every half second while the target lives:
##   * closing: for every crew and every t after the first leg (FIRST_LEG_S) at which it is still chasing (farther than
##     FIGHTING_M), its distance to the target at t + 5 s is not more than at t (+ CLOSING_SLACK_M);
##   * no orbit: no chasing crew's HULL heading turns more than REVERSAL_DEG within REVERSAL_WINDOW_S while it drives
##     (above DRIVING_MPS). The hull, not the direction of travel: a crew backing a metre to get round a squadmate
##     flips its velocity 180 degrees without turning at all, and an orbit is the hull going round.

const FIRST_LEG_S := 5.0
const CLOSING_WINDOW_S := 5.0
const CLOSING_SLACK_M := 2.0
const REVERSAL_DEG := 120.0
const REVERSAL_WINDOW_S := 4.0
## A crew counts as driving (its heading means something) above this speed (m/s).
const DRIVING_MPS := 4.0
## Both measures are of the CHASE: a crew within this of the target (the spear's 30 m band and a little) is fighting it,
## and turning round a target it is shooting at is the brain's fight (ORBIT, FLANK), not the bug he saw.
const FIGHTING_M := 35.0
const SAMPLE_TICKS := SimClock.TICK_RATE / 2
## The open yard (round 18's yard with its containers lifted): the pursuit is measured where nothing but the chase turns a
## hull. On the container yard a crew that meets a 12 m container backs round it, which is routing, not an orbit.
const ARENA := "yard_open"


## {"closing_worst_m", "closing_at", "reversal_worst_deg", "reversal_at", "lived_s", "start_m", "end_m": {crew: m},
##  "drills", "why"}
func _pursue(speed_mps: float, seconds: float, seed_value := 3, start_m := 70.0, pursuer := "gang_scout") -> Dictionary:
	var lab := TacticsLab.create(self, seed_value, ARENA)
	var game_match := lab.game_match
	game_match.set_meta("player_team", Match.Team.GREEN)
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	home.y = 0.0
	var toward := TacticsFormation.flat(Vector3(-home.x, 0.0, -home.z))
	var right := Vector3(-toward.z, 0.0, toward.x)
	var yaw := atan2(-toward.x, -toward.z)
	var names: Array = []
	for i in 5:
		var at := home + right * ((i - 2) * 6.0) - toward * (i % 2) * 4.0
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1), at, yaw, pursuer).name))
	var start := home + toward * start_m
	var target := lab.gun(Match.Team.RUST, "Rust_Eyes_1", start, yaw, "syn_lancer")
	target.max_forward_speed = maxf(speed_mps, target.max_forward_speed)
	var pace := clampf(speed_mps / target.max_forward_speed, 0.2, 1.0)
	# Away from them, then bearing off to the right (60 degrees, then 90): a target that only ran straight would hide an
	# orbit's cause. It never turns back toward them (a pursuer has to turn round for that, and it is no orbit).
	var waypoints: Array = []
	for w: Vector3 in [start + toward * 80.0, start + toward * 120.0 + right * 70.0, start + toward * 120.0 + right * 160.0]:
		waypoints.append(ElementPlan.clamp_to_arena(w))
	var controller := game_match.brains.get_node("Orders_Rust_Eyes_1") as OrderController
	await lab.start()
	if OS.get_environment("PURSUIT_OBSTACLES") != "":
		var stack: Array = [lab.arena]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			stack.append_array(node.get_children())
			if node is StaticBody3D:
				var at := _flat((node as Node3D).global_position)
				if at.distance_to(Vector3(-20, 0, 30)) < 25.0:
					print("OBSTACLE %s at %s" % [node.name, at.round()])
	var element := lab.elements.form(names, "Alpha")
	element.assign({"verb": "attack", "target": String(target.name), "formation": "vee"})
	var leg := 0
	controller.set_orders(_drive(waypoints[0], pace), {"type": "fire_at_will"})
	var distances := {}
	var headings := {}
	var starts := {}
	for unit_name: String in names:
		distances[unit_name] = []
		headings[unit_name] = []
		starts[unit_name] = lab.tank_of(unit_name).global_position.distance_to(target.global_position)
	var lived := 0
	var arrived_ticks := 0
	var forgotten_ticks := 0
	var whys := {}
	for tick in int(seconds * SimClock.TICK_RATE):
		if leg < waypoints.size() and _flat(target.global_position).distance_to(_flat(waypoints[leg])) < 6.0:
			leg += 1
			if leg < waypoints.size():
				controller.set_orders(_drive(waypoints[leg], pace), {"type": "fire_at_will"})
		await lab.step()
		if not target.is_alive():
			break
		lived = tick + 1
		if tick > SimClock.TICK_RATE and element.arrived:
			arrived_ticks += 1
		if not (game_match.intel[Match.Team.GREEN] as Dictionary).has(String(target.name)):
			forgotten_ticks += 1
		if element.reason != "":
			whys[element.reason] = true
		if OS.get_environment("PURSUIT_CREW") != "" and tick % 6 == 0:
			for crew: String in OS.get_environment("PURSUIT_CREW").split(","):
				var t := lab.tank_of(crew)
				if t == null or not t.is_alive():
					continue
				var brain := game_match.brains.get_node_or_null("Brain_" + crew)
				var order: Dictionary = lab.orders.call("current", crew)
				print("CREW t=%.1f %s pos=%s v=%s d=%.1f order=%s/%s to=%s brain=%s slot=%s" % [float(tick) / SimClock.TICK_RATE, crew,
						_flat(t.global_position).round(), _flat(t.estimated_velocity).round(),
						_flat(t.global_position).distance_to(_flat(target.global_position)), order.get("verb", "-"),
						order.get("target", ""), order.get("to", "-"), "-" if brain == null else "%s %s" % [brain.get("choice").get("option", ""), brain.get("why")],
						element.slots.get(crew, "-")])
		if OS.get_environment("PURSUIT_TRACE") != "" and tick % 15 == 0:
			var known: Dictionary = game_match.intel[Match.Team.GREEN].get(String(target.name), {})
			print("TRACE t=%.1f drill=%s why=%s arrived=%s anchor=%s center=%s target=%s known=%s vis=%s" % [float(tick) / SimClock.TICK_RATE,
					element.drill, element.reason, element.arrived, element.anchor, lab.center_of(names).round(),
					_flat(target.global_position).round(), known.get("position", Vector3.INF).round() if not known.is_empty() else "-",
					known.get("visible", "-")])
		if tick % SAMPLE_TICKS != 0:
			continue
		for unit_name: String in names:
			var tank := lab.tank_of(unit_name)
			var alive := tank != null and tank.is_alive()
			(distances[unit_name] as Array).append(
					_flat(tank.global_position).distance_to(_flat(target.global_position)) if alive else -1.0)
			var velocity := _flat(tank.estimated_velocity) if alive else Vector3.ZERO
			var chasing := alive and _flat(tank.global_position).distance_to(_flat(target.global_position)) > FIGHTING_M
			var hull := _flat(-tank.global_basis.z).normalized() if alive else Vector3.ZERO
			(headings[unit_name] as Array).append(hull if chasing and velocity.length() >= DRIVING_MPS else Vector3.ZERO)
	var result := {"closing_worst_m": -INF, "closing_at": "", "reversal_worst_deg": 0.0, "reversal_at": "",
			"lived_s": snappedf(float(lived) / SimClock.TICK_RATE, 0.1), "start_m": {}, "end_m": {},
			"drills": lab.drills_of(element), "why": whys.keys(),
			"arrived_s": snappedf(float(arrived_ticks) / SimClock.TICK_RATE, 0.1),
			"forgotten_s": snappedf(float(forgotten_ticks) / SimClock.TICK_RATE, 0.1),
			"center_to_target_m": snappedf(_flat(lab.center_of(names)).distance_to(_flat(target.global_position)), 0.1)
					if lab.alive(names) > 0 and target.is_alive() else -1.0}
	var per_s := float(SimClock.TICK_RATE) / SAMPLE_TICKS
	var first := int(FIRST_LEG_S * per_s)
	var window := int(CLOSING_WINDOW_S * per_s)
	var turn_window := int(REVERSAL_WINDOW_S * per_s)
	for unit_name: String in names:
		var d: Array = distances[unit_name]
		var h: Array = headings[unit_name]
		result["start_m"][unit_name] = snappedf(float(starts[unit_name]), 0.1)
		result["end_m"][unit_name] = snappedf(float(d[-1]), 0.1) if not d.is_empty() else -1.0
		for i in range(first, d.size() - window):
			if float(d[i]) < FIGHTING_M or float(d[i + window]) < 0.0:
				continue
			var opened := float(d[i + window]) - float(d[i])
			if opened > float(result["closing_worst_m"]):
				result["closing_worst_m"] = snappedf(opened, 0.1)
				result["closing_at"] = "%s at %.1f s (%.1f -> %.1f m)" % [unit_name, i / per_s, d[i], d[i + window]]
		for i in h.size():
			if (h[i] as Vector3) == Vector3.ZERO:
				continue
			for j in range(i + 1, mini(h.size(), i + turn_window + 1)):
				if (h[j] as Vector3) == Vector3.ZERO:
					continue
				var turned := rad_to_deg((h[i] as Vector3).angle_to(h[j]))
				if turned > float(result["reversal_worst_deg"]):
					result["reversal_worst_deg"] = snappedf(turned, 1.0)
					result["reversal_at"] = "%s %.1f -> %.1f s" % [unit_name, i / per_s, j / per_s]
	lab.dispose()
	return result


static func _drive(point: Vector3, pace: float) -> Dictionary:
	return {"type": "move_to", "x": point.x, "z": point.z, "speed": pace}


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _assert_pursuit(result: Dictionary, label: String) -> void:
	assert_true(float(result["closing_worst_m"]) <= CLOSING_SLACK_M,
			"%s: a crew opened the range over 5 s after the first leg (worst +%.1f m: %s)"
			% [label, float(result["closing_worst_m"]), result["closing_at"]])
	assert_true(float(result["reversal_worst_deg"]) <= REVERSAL_DEG,
			"%s: a crew reversed its heading (worst %.0f deg: %s)" % [label, float(result["reversal_worst_deg"]),
			result["reversal_at"]])


func test_a_spotter_retreating_at_8_mps_is_chased_down() -> void:
	var result: Dictionary = await _pursue(8.0, 30.0)
	print("MEASURE pursuit %s seed 3 five gang scouts v a spotter at 8 m/s: %s" % [ARENA, result])
	_assert_pursuit(result, "8 m/s")


func test_a_target_they_cannot_catch_is_still_chased_not_orbited() -> void:
	var result: Dictionary = await _pursue(18.0, 25.0)
	print("MEASURE pursuit %s seed 3 five gang scouts v a spotter at 18 m/s: %s" % [ARENA, result])
	_assert_pursuit(result, "18 m/s")


## The recording's case (the orchestrator's question): a target that leaves the squad's sight ENTIRELY, long enough
## for its team's intel to forget it (12 s). Five Law tanks (12 m/s, 78 m of sight) see it 60 m off and it drives away at
## 18 m/s, out of their sight. Before P2 the squad "arrived" short and sat once intel forgot it; now it follows its own
## track of it: never arrived while the target lives, and it finds it again.
func test_a_target_that_drives_out_of_sight_is_followed_not_given_up() -> void:
	var result: Dictionary = await _pursue(18.0, 40.0, 3, 60.0, "law_tank")
	print("MEASURE pursuit %s seed 3 five Law tanks v a spotter at 18 m/s out of sight: %s" % [ARENA, result])
	assert_true(float(result["forgotten_s"]) >= 3.0, "the stage does take it out of intel (%s s)" % result["forgotten_s"])
	assert_eq(float(result["arrived_s"]), 0.0, "the squad never reports arrived while it lives")
	assert_true(float(result["center_to_target_m"]) >= 0.0 and float(result["center_to_target_m"]) <= 40.0,
			"and finds it again: the squad ends on it (%s m)" % result["center_to_target_m"])
	# Not asserted here: the 120-degree turn. Out of sight the target turned twice and the track carried it straight on,
	# so a crew that sees it again off to its side turns round ONCE to it (164 degrees, seed 3, laptop): a wrong guess
	# corrected, not a circle. The orbit is measured on the visible chases above.


# ---- Pure: the pieces of the pursuit ------------------------------------------------------------------------------

func test_the_pursuit_point_is_the_last_sighting_carried_forward_then_held() -> void:
	var track := {"name": "Rust_Eyes_1", "position": Vector3(0, 0, -20), "velocity": Vector3(0, 0, -8), "seen_tick": 300}
	assert_eq(ElementPlan.pursuit_point(track, 300), Vector3(0, 0, -20), "seen this tick: where it is")
	var later: Vector3 = ElementPlan.pursuit_point(track, 300 + SimClock.TICK_RATE * 2)
	assert_near(later.z, -36.0, 0.01, "2 s out of sight at 8 m/s: 16 m on")
	var long_gone: Vector3 = ElementPlan.pursuit_point(track, 300 + SimClock.TICK_RATE * 60)
	var capped: Vector3 = ElementPlan.pursuit_point(track, 300 + int(SimClock.TICK_RATE * ElementPlan.PURSUIT_MEMORY_S))
	assert_eq(long_gone, capped, "the memory ends at PURSUIT_MEMORY_S: never back to the old spot, never on forever")
	assert_eq(ElementPlan.pursuit_point({}, 300), null, "no track, no point")


func test_an_attack_on_a_running_or_unseen_target_is_a_pursuit_and_stays_one() -> void:
	var task := {"verb": "attack", "target": "Rust_Eyes_1"}
	var seen := {"tick": 300, "contacts": [{"name": "Rust_Eyes_1", "position": Vector3(0, 0, -40), "visible": true}]}
	var running := {"name": "Rust_Eyes_1", "position": Vector3(0, 0, -40), "velocity": Vector3(0, 0, -8), "seen_tick": 300}
	var parked := running.duplicate()
	parked["velocity"] = Vector3.ZERO
	assert_true(ElementPlan.pursues(task, {"pursuit": running}, seen), "a running target: a pursuit")
	assert_true(not ElementPlan.pursues(task, {"pursuit": parked}, seen), "a parked target in sight: an attack as before")
	assert_true(ElementPlan.pursues(task, {"pursuit": parked}, {"tick": 300, "contacts": []}), "out of sight: a pursuit")
	assert_true(ElementPlan.pursues(task, {"pursuit": parked, "pursuing": true}, seen), "sticky for the task")
	assert_true(not ElementPlan.pursues({"verb": "attack", "to": [0, -40]}, {"pursuit": running}, seen), "a point: no")
	assert_true(not ElementPlan.pursues({"verb": "attack", "target": "Rust_2"}, {"pursuit": running}, seen),
			"a track of another vehicle is not this target's")


func test_a_squad_of_one_drives_straight_at_it_and_a_squad_lays_its_shape_ahead_of_it() -> void:
	var table: DoctrineTable = DoctrineTable.load_table("gangs")["table"]
	var track := {"name": "Rust_Eyes_1", "position": Vector3(0, 0, -80), "velocity": Vector3(8, 0, 0), "seen_tick": 300}
	var state := {"task": {"verb": "attack", "target": "Rust_Eyes_1", "formation": "vee"}, "pursuit": track,
			"pursuing": true, "heading": Vector3.FORWARD}
	var one := _situation(1)
	var plan := ElementPlan.build(one, state.duplicate(true), table)
	assert_eq(plan["orders"]["Green_1"]["verb"], "attack", "alone: straight at it (%s)" % plan["orders"])
	assert_eq(plan["orders"]["Green_1"]["target"], "Rust_Eyes_1", "at the one it was told")
	assert_true(not bool(plan["arrived"]), "never arrived short")
	var five := ElementPlan.build(_situation(5), state.duplicate(true), table)
	assert_true(not bool(five["arrived"]), "a pursuing squad never arrives outside its reach")
	for unit_name: String in five["orders"]:
		var order: Dictionary = five["orders"][unit_name]
		assert_eq(order["verb"], "attack_move", "%s drives for its station on an attack-move" % unit_name)
		assert_eq(order["target"], "Rust_Eyes_1", "%s: naming the target" % unit_name)
	var ahead := 0
	for unit_name: String in five["slots"]:
		if (five["slots"][unit_name] as Vector3).x > 4.0:
			ahead += 1
	assert_true(ahead >= 3, "the shape is laid where it is going (led to +x): %s" % five["slots"])


func test_the_contact_drills_give_way_to_a_pursuit_but_an_ambush_by_another_does_not() -> void:
	var table: DoctrineTable = DoctrineTable.load_table("standard")["table"]
	var running := {"name": "Rust_1", "visible": true, "distance": 60.0, "age": 500, "position": Vector3(0, 0, -60)}
	var task := {"verb": "attack", "target": "Rust_1"}
	var situation := _situation(4, [running], "contact")
	assert_eq(Drills.select(situation, {"task": task, "pursuing": false}, table)["drill"], "react_to_contact",
			"an attack that is not a pursuit reacts to contact as before")
	assert_eq(Drills.select(situation, {"task": task, "pursuing": true}, table)["drill"], "",
			"a pursuit does not stop to react to the target it is chasing")
	var far := Drills.select(situation, {"task": task, "pursuing": true, "drill": "far_ambush", "drill_tick": 990,
			"drill_why": "far ambush"}, table)
	assert_eq(far["drill"], "", "a far ambush already running stops")
	var popped := running.duplicate()
	popped["distance"] = 30.0
	popped["age"] = 0
	popped["position"] = Vector3(0, 0, -30)
	assert_true(Drills.select(_situation(4, [popped], "contact"), {"task": task, "pursuing": true}, table)["drill"] \
			!= "near_ambush", "the target coming back into sight is not an ambush")
	var stranger := popped.duplicate()
	stranger["name"] = "Rust_9"
	assert_eq(Drills.select(_situation(4, [stranger, running], "contact"), {"task": task, "pursuing": true}, table)["drill"],
			"near_ambush", "a sudden enemy who is not the target is still an ambush")


func test_a_brain_chases_the_target_it_was_told_to_kill_when_it_runs() -> void:
	var spear := Weapons.profile("spear_gun")
	var me := Vector3.ZERO
	var running := {"name": "Rust_1", "position": Vector3(0, 0, -40), "velocity": Vector3(0, 0, -8)}
	assert_true(TankBrain.chases({"verb": "attack", "target": "Rust_1"}, running, me, spear), "running beyond the band")
	assert_true(TankBrain.chases({"verb": "attack_move", "target": "Rust_1"}, running, me, spear), "a named attack-move")
	assert_true(not TankBrain.chases({"verb": "attack_move", "target": ""}, running, me, spear), "an unnamed attack-move")
	assert_true(not TankBrain.chases({"verb": "attack", "target": "Rust_2"}, running, me, spear), "another target")
	var close := running.duplicate()
	close["position"] = Vector3(0, 0, -20)
	assert_true(not TankBrain.chases({"verb": "attack", "target": "Rust_1"}, close, me, spear), "inside the band: fight")
	var coming := running.duplicate()
	coming["velocity"] = Vector3(0, 0, 8)
	assert_true(not TankBrain.chases({"verb": "attack", "target": "Rust_1"}, coming, me, spear), "closing on us: fight")


func _situation(count: int, contacts: Array = [], threat := "none") -> Dictionary:
	var members: Array = []
	var center := Vector3.ZERO
	for i in count:
		var at := Vector3(i * 6.0 - (count - 1) * 3.0, 0.0, 0.0)
		members.append({"name": "Green_%d" % (i + 1), "position": at, "forward": Vector3.FORWARD, "role": "scout",
				"unit": "gang_scout", "speed": 18.0, "range": 30.0, "effective_range": 24.0, "sight": 105.0,
				"health": 1.0, "suppression": 0.0, "taking_fire": false})
		center += at
	center /= float(maxi(count, 1))
	return {"tick": 1000, "team": 0, "center": center, "heading": Vector3.FORWARD, "leader": "Green_1",
			"members": members, "contacts": contacts, "terrain": "open", "threat": threat, "composition": "light",
			"strength": 400.0 * count, "enemy_strength": 400.0, "taking_fire": false, "arrived": false}

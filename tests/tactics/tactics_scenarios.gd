class_name TacticsScenarios
extends RefCounted
## Seeded battle-drill scenarios and formation measurements (doctrine X3/X4). Each one builds a small fight
## in the real arena, runs it faster than real time, and returns numbers — so the same body is both a test
## (tests/test_tactics_scenarios.gd, inside `make test`) and a measurement (`make tactics-drills`,
## `make tactics-measure`, which print MEASURE lines for _agents/doctrine.md).
##
## Scenarios are laid out in the arena's open western strip (x ≈ -100), away from the obstacle field, so the
## behaviour under test is the element's and not the navmesh's.

## Where scenarios are staged.
const LANE_X := -98.0
const SECONDS := 60.0


## An element of four walks into an ambush sprung at 25 m: doctrine says turn into it and assault through.
static func near_ambush(case: TestCase, seconds := 22.0) -> Dictionary:
	var lab := TacticsLab.create(case, 11)
	var names := _column(lab, 4, Vector3(LANE_X, 0.0, 40.0))
	var alpha := lab.element(names, "Alpha")
	await lab.start()
	alpha.assign({"verb": "move", "to": [LANE_X, -40.0]})
	var ambush: Array = []
	var sprung := -1
	var through_tick := -1
	var closest := INF
	var ambush_point := Vector3.ZERO
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		var center := lab.center_of(names)
		if sprung < 0 and center.z < 12.0:
			# The ambush party opens up from 25 m off the route, abreast of the element.
			sprung = tick
			ambush_point = Vector3(LANE_X + 25.0, 0.0, center.z - 6.0)
			for i in 2:
				ambush.append(String(lab.gun(Match.Team.RUST, "Rust_Ambush_%d" % (i + 1),
						ambush_point + Vector3(0.0, 0.0, i * 8.0), -PI * 0.5).name))
		elif sprung >= 0 and through_tick < 0 and center.x > ambush_point.x:
			# Through it: the element drove into the ambush and out the far side of it.
			through_tick = tick
		if sprung >= 0:
			closest = minf(closest, center.distance_to(ambush_point))
	var result := {"drills": Array(lab.drills_of(alpha)), "sprung_tick": sprung, "through_tick": through_tick,
			"closest_m": closest if is_finite(closest) else -1.0,
			"assault_seconds": (through_tick - sprung) / float(SimClock.TICK_RATE) if through_tick > 0 and sprung > 0 else -1.0,
			"survivors": lab.alive(names), "enemy_left": lab.alive(ambush)}
	lab.dispose()
	return result


## Fire and maneuver: an element that meets guns at 85 m pins them with one half and flanks with the other.
static func far_ambush(case: TestCase, seconds := 26.0) -> Dictionary:
	var lab := TacticsLab.create(case, 13)
	var names := _column(lab, 4, Vector3(LANE_X, 0.0, 40.0))
	var enemy: Array = []
	for i in 2:
		enemy.append(String(lab.gun(Match.Team.RUST, "Rust_Gun_%d" % (i + 1),
				Vector3(LANE_X - 6.0 + i * 12.0, 0.0, -45.0), PI).name))
	var alpha := lab.element(names, "Alpha")
	await lab.start()
	alpha.assign({"verb": "move", "to": [LANE_X, -60.0]})
	var widest_lateral := 0.0
	# Fire and maneuver means the halves do different things: one holds the line of contact and shoots, the
	# other goes round. So measure each vehicle's own furthest step off the axis, not the element's average.
	# (Taken once: the guns don't move, and center_of() of a wiped-out element reads as the origin.)
	var enemy_center := lab.center_of(enemy)
	var off_axis := {}
	for unit_name: String in names:
		off_axis[unit_name] = 0.0
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		for unit_name: String in names:
			var tank := lab.tank_of(unit_name)
			if tank != null and tank.is_alive():
				var lateral := absf(tank.global_position.x - enemy_center.x)
				widest_lateral = maxf(widest_lateral, lateral)
				off_axis[unit_name] = maxf(float(off_axis[unit_name]), lateral)
	var swung: Array = off_axis.values()
	swung.sort()
	var result := {"drills": Array(lab.drills_of(alpha)), "widest_lateral": widest_lateral,
			"off_axis_m": swung, "held_the_line_m": float(swung[0]),
			"survivors": lab.alive(names), "enemy_left": lab.alive(enemy)}
	lab.dispose()
	return result


## Bounding overwatch: one half is always set and covering while the other moves.
static func bounding(case: TestCase, seconds := 18.0, technique := "bounding_overwatch") -> Dictionary:
	var lab := TacticsLab.create(case, 17)
	var names := _column(lab, 4, Vector3(LANE_X, 0.0, 50.0))
	# Something known but far away, so the doctrine's "contact likely" branch is the one under test.
	var watcher := String(lab.gun(Match.Team.RUST, "Rust_Watch_1", Vector3(LANE_X, 0.0, -60.0), PI).name)
	var alpha := lab.element(names, "Alpha", TacticsLab.table_of("wedge", technique))
	await lab.start()
	alpha.assign({"verb": "move", "to": [LANE_X, -30.0]})
	var both_moving := 0
	var one_set := 0
	var samples := 0
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		if tick % 6 != 0 or tick < 60:
			continue
		samples += 1
		var still := lab.standing(names)
		var moving := lab.alive(names) - still
		if still > 0 and moving > 0:
			one_set += 1
		elif moving > 0:
			both_moving += 1
	var result := {"set_fraction": float(one_set) / maxf(samples, 1.0),
			"all_moving_fraction": float(both_moving) / maxf(samples, 1.0),
			"advanced_m": 50.0 - lab.center_of(names).z, "watcher_alive": lab.alive([watcher])}
	lab.dispose()
	return result


## An outgunned element bounds back instead of dying in place.
static func break_contact(case: TestCase, seconds := 20.0) -> Dictionary:
	var lab := TacticsLab.create(case, 19)
	var names: Array = []
	for i in 2:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_B_%d" % (i + 1),
				Vector3(LANE_X - 6.0 + i * 12.0, 0.0, 30.0), 0.0, "scout").name))
	var enemy: Array = []
	for i in 3:
		enemy.append(String(lab.gun(Match.Team.RUST, "Rust_Wall_%d" % (i + 1),
				Vector3(LANE_X - 12.0 + i * 12.0, 0.0, -50.0), PI).name))
	# break_contact is off in every shipped table since round 5: this measures the drill itself, switched on.
	var parsed := DoctrineTable.parse({"name": "with_break_contact",
			"drills": {"enabled": DoctrineTable.DRILL_DEFAULTS["enabled"] + ["break_contact"]},
			"movement": (DoctrineTable.load_table("standard")["table"] as DoctrineTable).movement})
	var bravo := lab.element(names, "Bravo", parsed["table"])
	await lab.start()
	var started := lab.center_of(names).distance_to(lab.center_of(enemy))
	bravo.assign({"verb": "move", "to": [LANE_X, -20.0]})
	var closest := started
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		if lab.alive(names) > 0:
			closest = minf(closest, lab.center_of(names).distance_to(lab.center_of(enemy)))
	var ended := lab.center_of(names).distance_to(lab.center_of(enemy)) if lab.alive(names) > 0 else -1.0
	var result := {"drills": Array(lab.drills_of(bravo)), "closest_m": closest, "ended_m": ended,
			"survivors": lab.alive(names)}
	lab.dispose()
	return result


## A halt with something out there: the herringbone faces alternate flanks instead of all one way.
static func herringbone(case: TestCase, seconds := 10.0) -> Dictionary:
	var lab := TacticsLab.create(case, 23)
	var names := _column(lab, 4, Vector3(LANE_X, 0.0, 20.0))
	lab.gun(Match.Team.RUST, "Rust_Far_1", Vector3(LANE_X, 0.0, -80.0), PI)
	var alpha := lab.element(names, "Alpha")
	await lab.start()
	alpha.assign({"verb": "hold"})
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
	var bearings: Array = []
	for unit_name: String in names:
		var tank := lab.tank_of(unit_name)
		if tank != null and tank.is_alive():
			bearings.append(ElementSituation.bearing_deg(Vector3.FORWARD, -tank.global_basis.z))
	var left := 0
	var right := 0
	for bearing: float in bearings:
		if absf(bearing) < 30.0:
			continue
		if bearing > 0.0:
			right += 1
		else:
			left += 1
	var result := {"formation": alpha.formation, "drill": alpha.drill, "bearings": bearings,
			"left": left, "right": right,
			"coverage": TacticsFormation.coverage(alpha.formation, names.size())}
	lab.dispose()
	return result


## X4: the same element walks into the same guns, once in its doctrinal formation and once in a clump.
## Returns what each shape cost.
static func formation_trial(case: TestCase, formation: String, spacing: float, seconds := 20.0,
		enemy_unit := "tank") -> Dictionary:
	var lab := TacticsLab.create(case, 29)
	var names := _column(lab, 4, Vector3(LANE_X, 0.0, 45.0))
	var enemy: Array = []
	for i in 2:
		# With artillery on the other side the trial measures dispersion against splash; the second vehicle
		# is always a gun tank, because indirect fire needs someone to see for it.
		enemy.append(String(lab.gun(Match.Team.RUST, "Rust_Pos_%d" % (i + 1),
				Vector3(LANE_X - 10.0 + i * 20.0, 0.0, -35.0), PI,
				enemy_unit if i == 0 else "tank").name))
	var table := TacticsLab.table_of(formation, "traveling",
			{"spacing_m": {"open": spacing, "lanes": spacing, "dense": spacing},
			 "drills": {"enabled": ["react_to_contact", "far_ambush", "support_by_fire", "herringbone"]}})
	var alpha := lab.element(names, "Alpha", table)
	await lab.start()
	var started := lab.strength(names)
	var enemy_started := lab.strength(enemy)
	alpha.assign({"verb": "move", "to": [LANE_X, -55.0]})
	var first_shot := -1
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		if first_shot < 0 and lab.strength(enemy) < enemy_started - 1.0:
			first_shot = tick
	var result := {"formation": formation, "spacing": spacing, "enemy_unit": enemy_unit,
			"survival": lab.survival(names, started), "alive": lab.alive(names),
			"enemy_survival": lab.survival(enemy, enemy_started),
			"first_hit_seconds": first_shot / float(SimClock.TICK_RATE) if first_shot >= 0 else -1.0,
			"spread_m": lab.spread_of(names),
			"closest_pair_m": TacticsFormation.closest_pair(formation, 4, spacing),
			"coverage": TacticsFormation.coverage(formation, 4),
			"frontage_m": TacticsFormation.frontage(formation, 4, spacing)}
	lab.dispose()
	return result


## X4: the same advance into the same guns under each movement technique.
static func technique_trial(case: TestCase, technique: String, seconds := 24.0) -> Dictionary:
	var lab := TacticsLab.create(case, 31)
	var names := _column(lab, 4, Vector3(LANE_X, 0.0, 50.0))
	var enemy: Array = []
	for i in 2:
		enemy.append(String(lab.gun(Match.Team.RUST, "Rust_Pos_%d" % (i + 1),
				Vector3(LANE_X - 10.0 + i * 20.0, 0.0, -40.0), PI).name))
	var alpha := lab.element(names, "Alpha", TacticsLab.table_of("wedge", technique,
			{"drills": {"enabled": ["react_to_contact", "far_ambush", "support_by_fire", "herringbone"]}}))
	await lab.start()
	var started := lab.strength(names)
	var enemy_started := lab.strength(enemy)
	alpha.assign({"verb": "move", "to": [LANE_X, -60.0]})
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
	var result := {"technique": technique, "survival": lab.survival(names, started), "alive": lab.alive(names),
			"enemy_survival": lab.survival(enemy, enemy_started), "enemy_alive": lab.alive(enemy),
			"advanced_m": 50.0 - lab.center_of(names).z}
	lab.dispose()
	return result


## X4: a halted element jumped from the flank, in a herringbone versus parked in the shape it drove in.
static func halt_trial(case: TestCase, formation: String, seconds := 14.0) -> Dictionary:
	var lab := TacticsLab.create(case, 37)
	var names := _column(lab, 4, Vector3(LANE_X, 0.0, 10.0))
	var alpha := lab.element(names, "Alpha", TacticsLab.table_of(formation, "traveling",
			{"drills": {"enabled": ["react_to_contact", "far_ambush", "support_by_fire"]}}))
	await lab.start()
	alpha.assign({"verb": "hold"})
	for tick in 240:
		await lab.step()
	var started := lab.strength(names)
	# Jumped from the flank, 45 m out.
	var enemy: Array = []
	for i in 2:
		enemy.append(String(lab.gun(Match.Team.RUST, "Rust_Flank_%d" % (i + 1),
				Vector3(LANE_X + 45.0, 0.0, 4.0 + i * 10.0), -PI * 0.5).name))
	var enemy_started := lab.strength(enemy)
	var first_reply := -1
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		if first_reply < 0 and lab.strength(enemy) < enemy_started - 1.0:
			first_reply = tick
	var result := {"formation": formation, "survival": lab.survival(names, started),
			"enemy_survival": lab.survival(enemy, enemy_started),
			"reply_seconds": first_reply / float(SimClock.TICK_RATE) if first_reply >= 0 else -1.0,
			"coverage": TacticsFormation.coverage(formation, 4)}
	lab.dispose()
	return result


static func _column(lab: TacticsLab, count: int, front: Vector3, unit_id := "tank") -> Array:
	var names: Array = []
	for i in count:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1),
				front + Vector3(0.0, 0.0, i * 10.0), 0.0, unit_id).name))
	return names


## Does a gang pack's doctrine beat the standard one with the SAME vehicles against the SAME enemy? The
## lead asked for the gangs to be "noticeably less military disciplined ... circular swarms"; this is whether
## that is worth anything. `table_name` picks the doctrine; everything else is identical, seed included.
##
## The prey is a Lancer and an artillery piece — what scouts are FOR (game_design.md: "scouts counter
## artillery and Lancers"). Against two dug-in tanks the same pack dies whatever its doctrine, because
## machine guns do not go through 8/4 armour, and a scenario like that measures the matchup, not the drills.
## A table by name, or "<name>-no-<drill>" for the same table with one drill switched off, so a drill can be
## measured on its own instead of being credited with whatever the rest of the doctrine does.
static func table_for(table_name: String) -> DoctrineTable:
	if not table_name.contains("-no-"):
		return DoctrineTable.load_table(table_name).get("table")
	var parts := table_name.split("-no-")
	var file := FileAccess.open(DoctrineTable.path_for(parts[0]), FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	var drills: Dictionary = data.get("drills", {})
	var enabled: Array = drills.get("enabled", (DoctrineTable.DRILL_DEFAULTS["enabled"] as Array).duplicate())
	enabled.erase(parts[1])
	drills["enabled"] = enabled
	data["drills"] = drills
	data["name"] = table_name
	return DoctrineTable.parse(data).get("table")


## `chasers` gives the enemy brains instead of standing orders, so it advances and can be led: the only
## situation a bait drill is for.
static func gang_pack(case: TestCase, table_name := "gangs", seconds := 26.0, chasers := false) -> Dictionary:
	var lab := TacticsLab.create(case, 53)
	var names: Array = []
	for i in 4:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1),
				Vector3(LANE_X - 12.0 + i * 8.0, 0.0, 45.0), 0.0, "scout" if i > 0 else "ifv").name))
	var enemy: Array = []
	for i in 2:
		var spot := Vector3(LANE_X - 6.0 + i * 12.0, 0.0, -35.0)
		var unit_id := "lancer" if i == 0 else "artillery"
		if chasers:
			# Something that will follow a lure: brain-driven, and able to hurt what it catches.
			enemy.append(String(lab.unit(Match.Team.RUST, "Rust_Hunt_%d" % (i + 1), spot, PI, "ifv").name))
		else:
			enemy.append(String(lab.gun(Match.Team.RUST, "Rust_Gun_%d" % (i + 1), spot, PI, unit_id).name))
	var alpha := lab.element(names, "Pack", table_for(table_name))
	await lab.start()
	var started := lab.strength(names)
	var enemy_started := lab.strength(enemy)
	alpha.assign({"verb": "attack", "target": enemy[0]})
	var enemy_center := lab.center_of(enemy)
	# How much of the circle the pack covers around the enemy, and how far apart it stays.
	var arcs := {}
	var widest_spread := 0.0
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		if tick % 30 != 0:
			continue
		widest_spread = maxf(widest_spread, lab.spread_of(names))
		for unit_name: String in names:
			var tank := lab.tank_of(unit_name)
			if tank != null and tank.is_alive() and tank.global_position.distance_to(enemy_center) < 90.0:
				var bearing := ElementSituation.bearing_deg(Vector3.FORWARD,
						tank.global_position - enemy_center)
				arcs[int(floor((bearing + 180.0) / 45.0))] = true
	var result := {"doctrine": table_name, "drills": Array(lab.drills_of(alpha)), "arcs_covered": arcs.size(),
			"widest_spread_m": snappedf(widest_spread, 0.1), "survival": snappedf(lab.survival(names, started), 0.001),
			"survivors": lab.alive(names), "enemy_survival": snappedf(lab.survival(enemy, enemy_started), 0.001),
			"enemy_left": lab.alive(enemy)}
	lab.dispose()
	return result


## Round 6 (squad X5, N4): does a task produce the posture its name claims, in the real arena with real brains?
## `verb` is "support_by_fire", "screen" or "move"; four tanks start in a column at z 40..70 on the western strip and
## are tasked at `point` (support by fire: at a durable enemy gun standing on it). Both sides are durable, so the
## posture is measured without deaths reshaping the element. Returns what a player would see.
static func task_posture(case: TestCase, verb: String, seconds := 30.0) -> Dictionary:
	var lab := TacticsLab.create(case, 17)
	var names := _column(lab, 4, Vector3(LANE_X, 0.0, 40.0))
	for unit_name: String in names:
		AiScenario.make_durable(lab.tank_of(unit_name))
	var point: Vector3 = {"support_by_fire": Vector3(LANE_X, 0.0, -60.0), "screen": Vector3(LANE_X, 0.0, 0.0),
			"move": Vector3(LANE_X + 5.0, 0.0, -30.0)}[verb]
	var enemy: Array = []
	if verb == "support_by_fire":
		var gun := lab.gun(Match.Team.RUST, "Rust_Gun_1", point, PI)
		AiScenario.make_durable(gun)
		enemy.append(String(gun.name))
	var alpha := lab.element(names, "Alpha")
	await lab.start()
	var fired := {"count": 0}
	var on_fired := func(event: Dictionary) -> void:
		if names.has(String(event.get("shooter", ""))):
			fired["count"] = int(fired["count"]) + 1
	lab.game_match.weapon_fired.connect(on_fired)
	var issued := {"late": 0}
	var total := int(seconds * SimClock.TICK_RATE)
	var ticks := {"now": 0}
	var on_issued := func(_command: Dictionary) -> void:
		if int(ticks["now"]) >= total - 10 * SimClock.TICK_RATE:
			issued["late"] = int(issued["late"]) + 1
	(lab.orders as Orders).issued.connect(on_issued)
	var task := {"verb": verb, "to": [point.x, point.z]}
	if verb == "move":
		task["drills"] = false  # the player's right-click (X4)
	alpha.assign(task)
	var closest := INF
	for tick in total:
		ticks["now"] = tick
		await lab.step()
		for unit_name: String in names:
			closest = minf(closest, lab.tank_of(unit_name).global_position.distance_to(point))
	var xs: Array = []
	var zs: Array = []
	var facing_point := 0
	var to_point: Array = []
	var off_slot := 0.0
	for unit_name: String in names:
		var tank := lab.tank_of(unit_name)
		var at := Vector3(tank.global_position.x, 0.0, tank.global_position.z)
		xs.append(at.x)
		zs.append(at.z)
		to_point.append(snappedf(at.distance_to(point), 0.1))
		if (-tank.global_basis.z).dot(TacticsFormation.flat(point - at)) > 0.7:
			facing_point += 1
		var slot: Variant = alpha.slots.get(unit_name)
		if slot is Vector3:
			off_slot = maxf(off_slot, at.distance_to(slot))
	var result := {"verb": verb, "drills": Array(lab.drills_of(alpha)), "formation": alpha.formation,
			"closest_m": snappedf(closest, 0.1), "to_point_m": to_point, "frontage_m": snappedf(xs.max() - xs.min(), 0.1),
			"depth_m": snappedf(zs.max() - zs.min(), 0.1), "facing_point": facing_point, "shots": int(fired["count"]),
			"center_to_point_m": snappedf(lab.center_of(names).distance_to(point), 0.1),
			"worst_off_slot_m": snappedf(off_slot, 0.1), "orders_last_10s": int(issued["late"])}
	# Lambdas must not outlive the scenario on signals of objects that do (a heap corruption at exit otherwise).
	lab.game_match.weapon_fired.disconnect(on_fired)
	(lab.orders as Orders).issued.disconnect(on_issued)
	lab.dispose()
	return result

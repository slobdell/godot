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
	for tick in int(seconds * 60.0):
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
			"assault_seconds": (through_tick - sprung) / 60.0 if through_tick > 0 and sprung > 0 else -1.0,
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
	for tick in int(seconds * 60.0):
		await lab.step()
		var enemy_center := lab.center_of(enemy)
		for unit_name: String in names:
			var tank := lab.tank_of(unit_name)
			if tank != null and tank.is_alive():
				widest_lateral = maxf(widest_lateral, absf(tank.global_position.x - enemy_center.x))
	var result := {"drills": Array(lab.drills_of(alpha)), "widest_lateral": widest_lateral,
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
	for tick in int(seconds * 60.0):
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
	var bravo := lab.element(names, "Bravo")
	await lab.start()
	var started := lab.center_of(names).distance_to(lab.center_of(enemy))
	bravo.assign({"verb": "move", "to": [LANE_X, -20.0]})
	var closest := started
	for tick in int(seconds * 60.0):
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
	for tick in int(seconds * 60.0):
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
	for tick in int(seconds * 60.0):
		await lab.step()
		if first_shot < 0 and lab.strength(enemy) < enemy_started - 1.0:
			first_shot = tick
	var result := {"formation": formation, "spacing": spacing, "enemy_unit": enemy_unit,
			"survival": lab.survival(names, started), "alive": lab.alive(names),
			"enemy_survival": lab.survival(enemy, enemy_started),
			"first_hit_seconds": first_shot / 60.0 if first_shot >= 0 else -1.0,
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
	for tick in int(seconds * 60.0):
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
	for tick in int(seconds * 60.0):
		await lab.step()
		if first_reply < 0 and lab.strength(enemy) < enemy_started - 1.0:
			first_reply = tick
	var result := {"formation": formation, "survival": lab.survival(names, started),
			"enemy_survival": lab.survival(enemy, enemy_started),
			"reply_seconds": first_reply / 60.0 if first_reply >= 0 else -1.0,
			"coverage": TacticsFormation.coverage(formation, 4)}
	lab.dispose()
	return result


static func _column(lab: TacticsLab, count: int, front: Vector3, unit_id := "tank") -> Array:
	var names: Array = []
	for i in count:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1),
				front + Vector3(0.0, 0.0, i * 10.0), 0.0, unit_id).name))
	return names

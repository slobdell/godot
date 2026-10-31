extends SceneTree
## Round 47 (engage E10, Bar E10's workload): OUTRANGED. A squad of 3 crews whose guns are shorter than their enemy's,
## staged on crossing / terminus / locks (by seed) at a distance inside the enemy's reach and beyond their own, the enemy
## 1-2 fixed guns shooting at what they see. The squad's order by seed: an element `attack` on the nearest gun (closing is
## allowed) or a `hold` on its spot (it is not). One run = one seed; the arm is `--outranged=on|off`. Everything is drawn
## from the seed, so the arms see the same stage and pair by seed. `--hurt=<fraction>` starts the crews hurt (Bar E10's D2
## workload: where RETREAT takes them and how). `--his-side=off` makes the squad nobody's (the CPU's side).
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/engage/outranged_probe.gd -- --seed=N [--arena=A]
##         [--seconds=60] [--outranged=on|off] [--hurt=F] [--his-side=on|off] [--order=attack|hold] [--trace=on]
## Prints OUTRANGED_PROBE {json} once (read by tests/engage/outranged_table.py). Every line is measured by the probe's own
## memory (an Outranged fed the same events), the same in both arms:
##   out_damage    damage the squad took from rounds fired beyond the victim's own weapon range (+ MARGIN_M) or by a gun
##                 it could not see: the deciding line D1
##   out_s         crew-seconds a crew read as outranged (Outranged.read non-empty)
##   deaths        squad crews that died; enemy_deaths, dealt (the squad's damage on the enemy), friendly_hits
##   retreat_m     per RETREAT episode: metres from the squad's other living crews' centre when it ended (D2), and
##   reverse_m     metres driven in reverse while choosing RETREAT (D2)

const ARENAS := ["crossing", "terminus", "locks"]
## Short guns (scrap_cannon 50 m, twin_mg 35, spear_gun 30, machine_gun 45) against long ones (laser 90, railgun 110,
## pulse_cannon 70): every pair outranges.
const HULLS := ["gang_tank", "gang_tank", "gang_ifv", "gang_scout", "law_scout"]
const SHOOTERS := ["syn_lancer", "syn_lancer", "syn_tank", "syn_ifv"]
const CREWS := 3
const STAND_M := 3.0

var case: TestCase


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


static func _r(x: float) -> float:
	return snappedf(x, 0.1)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _standable(map: CoverMap, point: Vector3) -> bool:
	var limit := Match.DRIVABLE_LIMIT - 8.0
	return absf(point.x) <= limit and absf(point.z) <= limit and not map.inside_any(Vector2(point.x, point.z), STAND_M)


## The stage: the guns at a standable spot, the squad `distance` m off along a seeded bearing, 7 m apart abreast. {} when a
## spot cannot stand or the squad cannot see the guns' spot (no outranging to measure).
func _stage(map: CoverMap, rng: RandomNumberGenerator, distance: float, guns: int) -> Dictionary:
	for attempt in 40:
		var at := Vector3(rng.randf_range(-70.0, 70.0), 0.0, rng.randf_range(-70.0, 70.0))
		var bearing := rng.randf_range(-PI, PI)
		var toward := Vector3(sin(bearing), 0.0, cos(bearing))
		var side := Vector3(-toward.z, 0.0, toward.x)
		var squad_center := at + toward * distance
		var spots: Array = []
		for i in CREWS:
			spots.append(squad_center + side * (float(i) - 1.0) * 7.0)
		var gun_spots: Array = []
		for i in guns:
			gun_spots.append(at + side * (float(i) - 0.5 * float(guns - 1)) * 8.0)
		var ok := true
		for spot: Vector3 in spots + gun_spots:
			ok = ok and _standable(map, spot)
		if ok and map.clear_line(squad_center, at):
			return {"guns": gun_spots, "spots": spots, "toward": toward}
	return {}


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	var seed_value := int(_flag("seed", "13025"))
	var seconds := float(_flag("seconds", "60"))
	var trace := _flag("trace", "off") == "on"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var arena := _flag("arena", ARENAS[seed_value % ARENAS.size()])
	var hull: String = _flag("hull", HULLS[rng.randi_range(0, HULLS.size() - 1)])
	var shooter_unit: String = _flag("shooter", SHOOTERS[rng.randi_range(0, SHOOTERS.size() - 1)])
	var guns := 1 + rng.randi_range(0, 1)
	var order_kind := _flag("order", "hold" if rng.randi_range(0, 2) == 0 else "attack")
	var reach := float(Weapons.profile(String(Units.stat(hull, "weapon", "cannon")))["range"])
	var their_reach := float(Weapons.profile(String(Units.stat(shooter_unit, "weapon", "cannon")))["range"])
	var distance := float(_flag("distance", str(_r(rng.randf_range(maxf(reach + 12.0, their_reach - 30.0), their_reach - 6.0)))))
	var lab := TacticsLab.create(case, seed_value, arena)
	var game_match := lab.game_match
	if _flag("his-side", "on") != "off":
		game_match.set_meta("player_team", Match.Team.GREEN)
	var map := CoverMap.of(game_match)
	var stage := _stage(map, rng, distance, guns)
	if stage.is_empty():
		print("OUTRANGED_PROBE %s" % JSON.stringify({"seed": seed_value, "arena": arena, "error": "no stage stands"}))
		quit(0)
		return
	var toward: Vector3 = stage["toward"]
	var yaw := atan2(toward.x, toward.z)  # the squad faces the guns (-z forward: yaw so that -basis.z = -toward)
	var names: Array = []
	for i in CREWS:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_O_%d" % (i + 1), stage["spots"][i], yaw, hull).name))
	var gun_names: Array = []
	for i in guns:
		gun_names.append(String(lab.gun(Match.Team.RUST, "Rust_G_%d" % (i + 1), stage["guns"][i], yaw + PI, shooter_unit).name))
	# The probe's own memory: what the crews could read, the same in both arms.
	var memory := Outranged.new()
	var counted := {"out_damage": 0.0, "dealt": 0.0, "friendly_hits": 0}
	var launched := {}
	game_match.weapon_fired.connect(func(event: Dictionary) -> void:
		memory._on_fired(event)
		launched[int(event.get("projectile_id", -1))] = String(event.get("shooter", "")))
	game_match.projectile_impact.connect(func(event: Dictionary) -> void:
		var shooter := String(launched.get(int(event.get("projectile_id", -1)), ""))
		var victims: Array = event.get("victims", [])
		if victims.is_empty() and event.has("target"):
			victims = [{"target": event["target"], "damage": event.get("damage", 0.0)}]
		for victim: Dictionary in victims:
			var hit := String(victim.get("target", ""))
			var damage := float(victim.get("damage", 0.0))
			if damage <= 0.0:
				continue
			if gun_names.has(shooter) and names.has(hit):
				var crew := lab.tank_of(hit)
				var from: Vector3 = memory._fired.get(int(event.get("projectile_id", -1)), {}).get("from", Vector3.ZERO)
				var seen := game_match.is_visible_to(Match.Team.GREEN, lab.tank_of(shooter)) if lab.tank_of(shooter) != null else false
				if crew != null and (not seen or _flat(from - crew.global_position).length() > reach + Outranged.MARGIN_M):
					counted["out_damage"] = float(counted["out_damage"]) + damage
			elif names.has(shooter) and gun_names.has(hit):
				counted["dealt"] = float(counted["dealt"]) + damage
			elif names.has(shooter) and names.has(hit):
				counted["friendly_hits"] = int(counted["friendly_hits"]) + 1
		memory._on_impact(event))
	var deaths := {}
	game_match.unit_destroyed.connect(func(event: Dictionary) -> void:
		deaths[String(event.get("unit", ""))] = int(event.get("tick", game_match.tick)))
	await lab.start()
	var ground_node := game_match.tanks.get_child(0) as Node3D
	for unit_name: String in names + gun_names:
		var tank := lab.tank_of(unit_name)
		var at := SlotGround.standable_for(ground_node, _flat(tank.global_position), SlotGround.envelope_of(tank.unit_id))
		if at.distance_to(_flat(tank.global_position)) > 0.5:
			tank.place(at, yaw if names.has(unit_name) else yaw + PI)
	var hurt := float(_flag("hurt", "0"))
	if hurt > 0.0:
		for unit_name: String in names:
			var tank := lab.tank_of(unit_name)
			tank.health = maxi(1, int(float(tank.max_health) * hurt))
	for i in 3:
		await lab.step()
	var element := lab.elements.form(names, "Oscar")
	if order_kind == "attack":
		element.assign({"verb": "attack", "target": gun_names[0], "formation": "line"})
	else:
		var center := Vector3.ZERO
		for unit_name: String in names:
			center += _flat(lab.tank_of(unit_name).global_position) / float(names.size())
		element.assign({"verb": "hold", "to": center, "facing": toward * -1.0})
	var out_ticks := 0
	var reverse_m := 0.0
	var retreats: Array = []   # metres from the squad's centre when each RETREAT episode ended
	var retreating := {}
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		var alive_guns := gun_names.filter(func(n: String) -> bool: return lab.tank_of(n) != null and lab.tank_of(n).is_alive())
		var alive := names.filter(func(n: String) -> bool: return lab.tank_of(n) != null and lab.tank_of(n).is_alive())
		if alive_guns.is_empty() or alive.is_empty():
			break
		var seen := {}
		for g: String in alive_guns:
			if game_match.is_visible_to(Match.Team.GREEN, lab.tank_of(g)):
				seen[g] = true
		for unit_name: String in names:
			var tank := lab.tank_of(unit_name)
			var brain := game_match.brains.get_node_or_null("Brain_" + unit_name) as TankBrain
			var option := String(brain.choice.get("option", "")) if brain != null else ""
			var living := tank != null and tank.is_alive()
			if living and not memory.read(unit_name, tank.global_position, reach, game_match.tick, seen, float(tank.max_health)).is_empty():
				out_ticks += 1
			if living and option == "RETREAT":
				retreating[unit_name] = true
				var forward := -tank.global_basis.z
				if tank.estimated_velocity.dot(forward) < -0.3:
					reverse_m += tank.estimated_velocity.length() / SimClock.TICK_RATE
			elif retreating.has(unit_name):
				retreating.erase(unit_name)
				if living:
					retreats.append(_r(_from_squad(lab, names, unit_name)))
			if trace and living and tick % 15 == 0:
				var read := memory.read(unit_name, tank.global_position, reach, game_match.tick, seen, float(tank.max_health))
				print("OUTRANGED_TRACE t=%d %s at (%.1f, %.1f) hp %d choice %s why '%s' outranged %s v %.1f" % [game_match.tick, unit_name,
						tank.global_position.x, tank.global_position.z, tank.health, option, brain.why if brain != null else "-",
						str(not read.is_empty()), tank.estimated_velocity.dot(-tank.global_basis.z)])
	for unit_name: String in retreating:
		var tank := lab.tank_of(unit_name)
		if tank != null and tank.is_alive():
			retreats.append(_r(_from_squad(lab, names, unit_name)))
	var squad_deaths := names.filter(func(n: String) -> bool: return deaths.has(n)).size()
	var enemy_deaths := gun_names.filter(func(n: String) -> bool: return deaths.has(n)).size()
	print("OUTRANGED_PROBE %s" % JSON.stringify({"seed": seed_value, "arena": arena, "arm": "on" if Outranged.ON else "off",
			"hull": hull, "shooter": shooter_unit, "guns": guns, "order": order_kind, "distance": distance, "reach": reach,
			"their_reach": their_reach, "hurt": hurt, "out_damage": _r(float(counted["out_damage"])),
			"out_s": _r(float(out_ticks) / SimClock.TICK_RATE), "deaths": squad_deaths, "enemy_deaths": enemy_deaths,
			"dealt": _r(float(counted["dealt"])), "friendly_hits": counted["friendly_hits"], "retreat_m": retreats,
			"reverse_m": _r(reverse_m), "seconds": seconds}))
	lab.dispose()
	quit(0)


## Metres from `unit_name` to the centre of the squad's OTHER living crews (0 when it is the last one).
static func _from_squad(lab: TacticsLab, names: Array, unit_name: String) -> float:
	var center := Vector3.ZERO
	var n := 0
	for other: String in names:
		var tank := lab.tank_of(other)
		if other != unit_name and tank != null and tank.is_alive():
			center += _flat(tank.global_position)
			n += 1
	if n == 0:
		return 0.0
	return _flat(lab.tank_of(unit_name).global_position).distance_to(center / float(n))

class_name Round3Firefight
extends Node3D
## The FX lab's round-3 worst case (feel X7): 50 vehicles, 25 a side, with round 3's weapons feeding K2-shaped events
## straight into WeaponFx: tanks' slow shells (glowing slugs, devastating hits, kills that burn), IFVs' 25 mm bursts,
## scouts' machine-gun streams, artillery arcs, and Lancer beams, while every vehicle keeps moving (dust, drift marks,
## lurches) and the player's orders drop markers. Seeded and scripted, so every config replays the same fight.
## Visual only: vehicles are slot visuals, projectiles are plain nodes carrying the fx.shell slot.

## Per side, the roster and each weapon's rhythm (seconds between trigger pulls, rounds per pull, seconds between rounds).
const ROSTER := [
	{"unit": "tank", "count": 5, "model": "shell", "weapon": "cannon", "every": 5.0, "rounds": 1, "gap": 0.0, "speed": 75.0},
	{"unit": "ifv", "count": 8, "model": "burst", "weapon": "autocannon", "every": 1.8, "rounds": 4, "gap": 0.12, "speed": 180.0},
	{"unit": "scout", "count": 8, "model": "stream", "weapon": "machine_gun", "every": 2.5, "rounds": 16, "gap": 0.09, "speed": 0.0},
	{"unit": "artillery", "count": 2, "model": "arc", "weapon": "mortar", "every": 4.5, "rounds": 1, "gap": 0.0, "speed": 40.0},
	{"unit": "lancer", "count": 2, "model": "beam", "weapon": "laser", "every": 0.6, "rounds": 1, "gap": 0.0, "speed": 0.0},
]
const LINE_Z := 34.0
const SPACING := 4.4
## Chance a round misses its target (lands in the dirt), and that a hit is on a weak spot or kills.
const MISS := 0.3
const WEAK_SPOT := 0.12
const KILL := {"shell": 0.25, "arc": 0.15, "burst": 0.02, "stream": 0.005, "beam": 0.02}
const ORDER_EVERY := 1.5

var vehicles: Array[Node3D] = []
## OrderFeedback looks vehicles up under `tanks`, like a Match.
var tanks: Node = self
var weapons_on := true
var motion_on := true

var _fx: FxWorld
var _rng := RandomNumberGenerator.new()
var _shots: Array[Dictionary] = []
var _flying: Array[Dictionary] = []
var _next_id := 1
var _time := 0.0
var _next_order := 0.0
var _orders: RefCounted
var _controls: Node


func build() -> void:
	for team in 2:
		var slot := 0
		for group: Dictionary in ROSTER:
			for i in int(group["count"]):
				var vehicle := _vehicle(String(group["unit"]), team, slot)
				vehicles.append(vehicle)
				_shots.append({"vehicle": vehicle, "team": team, "group": group, "next": 0.0, "left": 0, "base": vehicle.position,
						"phase": float(slot) * 0.7})
				slot += 1


func reset(fx: FxWorld) -> void:
	_fx = fx
	_rng.seed = 2026
	_time = 0.0
	_next_order = 0.5
	_next_id = 1
	for projectile in _flying:
		if is_instance_valid(projectile["node"]):
			(projectile["node"] as Node).free()
	_flying.clear()
	for i in _shots.size():
		_shots[i]["next"] = 0.3 + float(i % 13) * 0.17
		_shots[i]["left"] = 0
	fx.weapons.resolver = func(unit_name: String) -> Node: return find_child(unit_name, false, false)
	fx.weapons.units = func() -> Array: return vehicles
	if _orders == null:
		var script := GDScript.new()
		script.source_code = "extends RefCounted\nsignal order_changed(unit_name: String)\nsignal queue_changed(unit_name: String)\n" \
				+ "var current_orders := {}\nfunc current(n: String) -> Dictionary:\n\treturn current_orders.get(n, {})\n" \
				+ "func queue(_n: String) -> Array:\n\treturn []\n"
		script.reload()
		_orders = script.new()
		_controls = Node.new()
		add_child(_controls)
	fx.order_feedback.attach(_orders, self, _controls)


func step(delta: float, camera_position: Vector3) -> void:
	_time += delta
	for shot in _shots:
		_drive(shot)
	if motion_on:
		_fx.motion.update(vehicles, camera_position, _fx.now, delta)
	if not weapons_on:
		return
	for shot in _shots:
		_trigger(shot)
	_fly(delta)
	if _time >= _next_order:
		_next_order += ORDER_EVERY
		_issue_order()


## Everyone keeps moving: heavies weave slowly, scouts circle fast (they drift), IFVs strafe back and forth.
func _drive(shot: Dictionary) -> void:
	var vehicle: Node3D = shot["vehicle"]
	var base: Vector3 = shot["base"]
	var phase := float(shot["phase"]) + _time
	match String(shot["group"]["unit"]):
		"scout":
			var angle := phase * 0.9
			vehicle.position = base + Vector3(cos(angle) * 9.0, 0.0, sin(angle) * 6.0)
			vehicle.rotation.y = -angle - 0.5
		"ifv":
			vehicle.position = base + Vector3(sin(phase * 0.8) * 6.0, 0.0, 0.0)
		_:
			vehicle.position = base + Vector3(sin(phase * 0.35) * 3.0, 0.0, cos(phase * 0.3) * 2.0)


func _trigger(shot: Dictionary) -> void:
	if _time < float(shot["next"]):
		return
	var group: Dictionary = shot["group"]
	if int(shot["left"]) <= 0:
		shot["left"] = int(group["rounds"])
	shot["left"] = int(shot["left"]) - 1
	shot["next"] = float(shot["next"]) + (float(group["gap"]) if int(shot["left"]) > 0 else float(group["every"]))
	var vehicle: Node3D = shot["vehicle"]
	var team: int = shot["team"]
	var target := vehicles[(1 - team) * 25 + _rng.randi_range(0, 24)]
	var muzzle := vehicle.global_position + Vector3.UP * 1.25
	var aim := target.global_position + Vector3.UP * 1.0
	var miss := _rng.randf() < MISS
	if miss:
		aim += Vector3(_rng.randf_range(-7.0, 7.0), -1.0, _rng.randf_range(-5.0, 5.0))
	var direction := (aim - muzzle).normalized()
	var id := _next_id
	_next_id += 1
	var model := String(group["model"])
	_fx.weapons.fired({"tick": 0, "shooter": String(vehicle.name), "weapon": String(group["weapon"]), "fire_model": model,
			"muzzle": K2Events.from_vector(muzzle), "direction": K2Events.from_vector(direction), "projectile_id": id,
			"speed_mps": float(group["speed"]), "range": 120.0})
	var impact := _impact(id, model, aim, target, miss)
	if model == "beam":
		var beam := VisualSlot.new()
		beam.slot = "fx.laser_beam"
		add_child(beam)
		beam.invoke("setup", [muzzle, aim])
		get_tree().create_timer(0.2).timeout.connect(beam.queue_free)
		_fx.weapons.impact(impact)
	elif float(group["speed"]) <= 0.0:
		_fx.weapons.impact(impact)
	else:
		var node := Node3D.new()
		node.name = "Round%d" % id
		node.set_meta("fire_model", model)
		node.set_meta("team", team)
		var slot := VisualSlot.new()
		slot.slot = "fx.shell"
		node.add_child(slot)
		add_child(node)
		node.global_position = muzzle
		node.look_at(aim, Vector3.UP)
		_flying.append({"node": node, "to": aim, "speed": float(group["speed"]), "impact": impact})


func _impact(id: int, model: String, at: Vector3, target: Node3D, miss: bool) -> Dictionary:
	var event := {"tick": 0, "projectile_id": id, "position": K2Events.from_vector(at), "normal": [0.0, 1.0, 0.0],
			"weak_spot": false, "damage": 0.0, "killed": false}
	if not miss:
		event["target"] = String(target.name)
		event["weak_spot"] = _rng.randf() < WEAK_SPOT
		event["killed"] = _rng.randf() < float(KILL[model])
	return event


func _fly(delta: float) -> void:
	for i in range(_flying.size() - 1, -1, -1):
		var projectile: Dictionary = _flying[i]
		var node: Node3D = projectile["node"]
		var to: Vector3 = projectile["to"]
		var step := float(projectile["speed"]) * delta
		if node.global_position.distance_to(to) <= step:
			_fx.weapons.impact(projectile["impact"])
			node.free()
			_flying.remove_at(i)
		else:
			node.global_position = node.global_position.move_toward(to, step)


func _issue_order() -> void:
	var units: Array = []
	for k in 5:
		units.append(String(vehicles[_rng.randi_range(0, 24)].name))
	var verb: String = ["move", "attack_move", "attack"][_rng.randi_range(0, 2)]
	var id := _next_id
	_next_id += 1
	for unit_name: String in units:
		var order := {"id": id, "verb": verb, "units": units}
		if verb == "attack":
			order["target"] = String(vehicles[25 + _rng.randi_range(0, 24)].name)
		else:
			order["to"] = [_rng.randf_range(-40.0, 40.0), _rng.randf_range(-10.0, 30.0)]
		_orders.current_orders[unit_name] = order
		_orders.order_changed.emit(unit_name)


func _vehicle(unit: String, team: int, slot: int) -> Node3D:
	var profile: Dictionary = Units.PROFILES.get(unit, Units.PROFILES["tank"])
	var vehicle := Node3D.new()
	vehicle.name = "R3_%d_%s_%d" % [team, unit, slot]
	vehicle.set_meta("unit_id", unit)
	vehicle.set_meta("team", team)
	var row := slot / 13
	var x := (float(slot % 13) - 6.0) * SPACING
	var z := (LINE_Z + row * 7.0) * (1.0 if team == 0 else -1.0)
	vehicle.position = Vector3(x, 0.0, z)
	vehicle.rotation.y = 0.0 if team == 0 else PI
	add_child(vehicle)
	var hull := VisualSlot.new()
	hull.name = "HullVisual"
	hull.slot = "unit.%s.hull" % unit if GameTheme.slots.has("unit.%s.hull" % unit) else "tank.hull"
	vehicle.add_child(hull)
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, float(profile.get("muzzle_height", 1.27)) - 0.05, 0.2)
	vehicle.add_child(turret)
	for slot_name in ["unit.%s.turret" % unit, "unit.%s.weapon" % unit]:
		if GameTheme.slots.has(slot_name):
			var part := VisualSlot.new()
			part.slot = slot_name
			turret.add_child(part)
	for part in vehicle.find_children("*", "Node3D", true, false):
		if part is VisualSlot:
			(part as VisualSlot).invoke("set_team_color", [GameTheme.team_color(team)])
	return vehicle

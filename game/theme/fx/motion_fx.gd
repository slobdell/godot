class_name MotionFx
extends Node3D
## Vehicles in motion (feel X6): dust kicked up behind moving treads and tires, drift marks where a wheeled unit slides
## sideways (K3's lateral_grip lets wheels drift), and a lurch of the art on hard braking or a hard launch. Everything is
## measured from how each vehicle's node moved between frames, never read from the simulation, so it works on every
## peer. Only the EMITTERS vehicles nearest the camera spend the budget; dust has its own pooled bursts and marks their
## own MultiMesh, so a big battle's weapons never recycle them.

const SKID_SHADER := preload("res://game/theme/fx/shaders/skid.gdshader")
const WORLD_AABB := AABB(Vector3(-200, -20, -200), Vector3(400, 80, 400))
## Vehicles (nearest the camera) that raise dust and lay marks, per tier.
const EMITTERS := {FxQuality.Tier.LOW: 6, FxQuality.Tier.MEDIUM: 12, FxQuality.Tier.HIGH: 20}
const DUST_POOL := {FxQuality.Tier.LOW: 64, FxQuality.Tier.MEDIUM: 128, FxQuality.Tier.HIGH: 256}
const SKID_POOL := {FxQuality.Tier.LOW: 128, FxQuality.Tier.MEDIUM: 256, FxQuality.Tier.HIGH: 512}
## Moving slower than this raises no dust (m/s).
const DUST_SPEED := 2.5
## Meters driven between dust puffs at a crawl and at full speed.
const DUST_SPACING := Vector2(3.0, 1.6)
const TOP_SPEED := 14.0
## A wheeled unit sliding sideways faster than this (m/s) while moving faster than DRIFT_SPEED lays marks.
const DRIFT_SLIDE := 2.5
const DRIFT_SPEED := 4.0
const SKID_SPACING := 0.6
const SKID_SECONDS := 16.0
## Forward acceleration (m/s²) that lurches the art: braking below -LURCH_BRAKE, launching above LURCH_LAUNCH.
const LURCH_BRAKE := 12.0
const LURCH_LAUNCH := 14.0
const LURCH_EVERY := 0.8
const DUST_COLOR := Color(0.52, 0.43, 0.33)
## Faster than any vehicle drives (m/s): a jump like that isn't motion.
const MAX_SPEED := 40.0

var dust: BurstSystem
## Totals since load (tests and the bench).
var puffs_started := 0
## How many vehicles spent the budget on the last update, and the most at once since load (tests, the bench).
var emitters_last := 0
var emitters_peak := 0
var lurches := 0
var last_lurch_at := -10.0
## A vehicle must be watched this long before it can lurch (its first frames read as a launch from standstill).
const WARMUP_SECONDS := 0.35

var _fx: FxWorld
## vehicle -> {position, speed, accel, travelled, skid_travelled, wheels: [left, right], dust, skids, last_lurch}
var _state := {}
var _skids := MultiMeshInstance3D.new()
var _skid_material := ShaderMaterial.new()
var _next_skid := 0
## Render X5: vehicles ranked by distance to the camera, refreshed every RANK_SECONDS (sorting 60 every frame cost more
## than the effects it chose).
var _ranked: Array = []
var _ranked_at := -1000.0
const RANK_SECONDS := 0.2


func _init(fx: FxWorld = null) -> void:
	name = "Motion"
	_fx = fx
	dust = BurstSystem.new(DUST_POOL[FxQuality.tier()])
	dust.name = "Dust"
	add_child(dust)
	_skid_material.shader = SKID_SHADER
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane.get_mesh_arrays())
	mesh.surface_set_material(0, _skid_material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	_skids.multimesh = multimesh
	_skids.name = "Skids"
	_skids.custom_aabb = WORLD_AABB
	_skids.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_skids)
	resize()


## Apply the tier's pool sizes.
func resize() -> void:
	dust.resize(DUST_POOL[FxQuality.tier()])
	var multimesh := _skids.multimesh
	multimesh.instance_count = SKID_POOL[FxQuality.tier()]
	for i in multimesh.instance_count:
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3.ZERO))
		multimesh.set_instance_custom_data(i, Color(-1000.0, 0.001, 0.0, 0.0))
	_next_skid = 0


func dust_from(vehicle: Node) -> int:
	return int(_state.get(vehicle, {}).get("dust", 0))


func skids_from(vehicle: Node) -> int:
	return int(_state.get(vehicle, {}).get("skids", 0))


## Watch `vehicles` move this frame. FxWorld calls it with the attached match's vehicles.
func update(vehicles: Array, camera_position: Vector3, now: float, delta: float) -> void:
	dust.update(now)
	_skid_material.set_shader_parameter("now", now)
	if delta <= 0.0:
		return
	if now - _ranked_at >= RANK_SECONDS or now < _ranked_at:
		_ranked_at = now
		_rank(vehicles, camera_position)
	var budget := int(EMITTERS[FxQuality.tier()])
	emitters_last = 0
	for rank in _ranked.size():
		var vehicle := _ranked[rank] as Node3D
		if is_instance_valid(vehicle) and vehicle.is_inside_tree() and vehicle.is_visible_in_tree():
			_watch(vehicle, rank < budget, now, delta)
			emitters_last += 1 if rank < budget else 0
	emitters_peak = maxi(emitters_peak, emitters_last)


func _rank(vehicles: Array, camera_position: Vector3) -> void:
	var live := {}
	var ranked: Array = []
	for node in vehicles:
		var vehicle := node as Node3D
		if vehicle == null or not vehicle.is_inside_tree() or not vehicle.is_visible_in_tree():
			continue
		live[vehicle] = true
		ranked.append([vehicle.global_position.distance_squared_to(camera_position), vehicle])
	for vehicle in _state.keys():
		if not live.has(vehicle):
			_state.erase(vehicle)
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_ranked = ranked.map(func(entry: Array) -> Node3D: return entry[1])


func _watch(vehicle: Node3D, emits: bool, now: float, delta: float) -> void:
	var position := vehicle.global_position
	var state: Dictionary = _state.get(vehicle, {})
	if state.is_empty():
		_state[vehicle] = {"position": position, "speed": 0.0, "accel": 0.0, "travelled": 0.0, "skid_travelled": 0.0,
				"wheels": [], "dust": 0, "skids": 0, "last_lurch": -10.0, "since": now}
		return
	if not emits:
		# Far from the camera: nothing to show, so only remember where it is (and restart its warm-up, so becoming an
		# emitter again can't read the gap as a launch).
		state["position"] = position
		state["since"] = now
		state["wheels"] = []
		return
	var moved := position - (state["position"] as Vector3)
	moved.y = 0.0
	state["position"] = position
	if moved.length() > MAX_SPEED * maxf(delta, 1.0 / 30.0):
		return  # a respawn, a teleport, or network smoothing catching up: not driving
	var velocity := moved / delta
	var forward := -vehicle.global_basis.z
	var right := vehicle.global_basis.x
	var forward_speed := velocity.dot(forward)
	var slide := absf(velocity.dot(right))
	var speed := velocity.length()
	# Smoothed over a few frames so frame-time jitter doesn't read as a lurch.
	var previous := float(state["speed"])
	var smoothed := lerpf(previous, forward_speed, 0.35)
	state["accel"] = lerpf(float(state["accel"]), (smoothed - previous) / delta, 0.35)
	state["speed"] = smoothed
	if speed > DUST_SPEED:
		_raise_dust(vehicle, state, speed * delta, speed, forward, right, now)
	var unit_id := _unit_id(vehicle)
	if _locomotion(unit_id) == "wheels" and slide > DRIFT_SLIDE and speed > DRIFT_SPEED:
		_lay_marks(vehicle, state, moved.length(), forward, right, now)
	else:
		state["wheels"] = []
	_lurch(vehicle, state, forward, now)


func _raise_dust(vehicle: Node3D, state: Dictionary, moved: float, speed: float, forward: Vector3, right: Vector3, now: float) -> void:
	var low := FxQuality.tier() == FxQuality.Tier.LOW
	state["travelled"] = float(state["travelled"]) + moved
	var spacing := lerpf(DUST_SPACING.x, DUST_SPACING.y, clampf(speed / TOP_SPEED, 0.0, 1.0)) * (1.6 if low else 1.0)
	if float(state["travelled"]) < spacing:
		return
	state["travelled"] = 0.0
	var size := _hull_size(_unit_id(vehicle))
	var rear := vehicle.global_position - forward * size.z * 0.5
	var sides := [0.0] if low else [-0.4, 0.4]
	for side: float in sides:
		var at := rear + right * size.x * side + Vector3.UP * 0.4
		dust.spawn(BurstSystem.Kind.SMOKE, at, 1.4 + speed * 0.14, 1.1 + speed * 0.04,
				Color(DUST_COLOR.r, DUST_COLOR.g, DUST_COLOR.b, 0.05), now, -forward * speed * 0.25 + right * side * 2.0, 2.2, 0.0, 0.5)
		puffs_started += 1
	state["dust"] = int(state["dust"]) + 1


func _lay_marks(vehicle: Node3D, state: Dictionary, moved: float, forward: Vector3, right: Vector3, now: float) -> void:
	var size := _hull_size(_unit_id(vehicle))
	var rear := vehicle.global_position - forward * size.z * 0.38
	var wheels := [rear - right * size.x * 0.42, rear + right * size.x * 0.42]
	var last: Array = state["wheels"]
	state["skid_travelled"] = float(state["skid_travelled"]) + moved
	if last.is_empty():
		state["wheels"] = wheels
		return
	if float(state["skid_travelled"]) < SKID_SPACING:
		return
	state["skid_travelled"] = 0.0
	var multimesh := _skids.multimesh
	for k in 2:
		var from: Vector3 = last[k]
		var to: Vector3 = wheels[k]
		var along := Vector3(to.x - from.x, 0.0, to.z - from.z)
		if along.length() < 0.05:
			continue
		var across := Vector3.UP.cross(along.normalized()) * 0.32
		var basis := Basis(across, Vector3.UP, along)
		var middle := (from + to) * 0.5
		multimesh.set_instance_transform(_next_skid, Transform3D(basis, Vector3(middle.x, 0.0, middle.z)))
		multimesh.set_instance_custom_data(_next_skid, Color(now, SKID_SECONDS, 1.0, 0.0))
		_next_skid = (_next_skid + 1) % multimesh.instance_count
	state["wheels"] = wheels
	state["skids"] = int(state["skids"]) + 1


func _lurch(vehicle: Node3D, state: Dictionary, forward: Vector3, now: float) -> void:
	if _fx == null or now - float(state["last_lurch"]) < LURCH_EVERY or now - float(state["since"]) < WARMUP_SECONDS:
		return
	var accel := float(state["accel"])
	if accel < -LURCH_BRAKE:
		# Braking pitches the nose down: the art is shoved forward.
		_fx.jolts.kick(vehicle, forward, clampf(-accel / 10.0, 1.0, 3.5), 0.12, now, 9.0, 4.0)
	elif accel > LURCH_LAUNCH:
		_fx.jolts.kick(vehicle, -forward, clampf(accel / 12.0, 0.8, 2.5), 0.08, now, 9.0, 4.0)
	else:
		return
	state["last_lurch"] = now
	last_lurch_at = now
	lurches += 1


static func _unit_id(vehicle: Node) -> String:
	var id: Variant = vehicle.get("unit_id")
	if id == null and vehicle.has_meta("unit_id"):
		id = vehicle.get_meta("unit_id")
	return String(id) if id != null else ""


## K3 locomotion from the unit catalog; before combat's K3 lands, the game design's proposal (tank on tracks, the rest
## on wheels).
static func _locomotion(unit_id: String) -> String:
	var profile: Dictionary = Units.PROFILES.get(unit_id, {})
	if profile.has("locomotion"):
		return String(profile["locomotion"])
	return "tracks" if String(profile.get("role", unit_id)) == "tank" else "wheels"


static func _hull_size(unit_id: String) -> Vector3:
	var size: Variant = Units.PROFILES.get(unit_id, {}).get("hull_size")
	return Vector3(float(size[0]), float(size[1]), float(size[2])) if size is Array and (size as Array).size() >= 3 else Vector3(2.4, 1.6, 3.6)

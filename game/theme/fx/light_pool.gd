class_name LightPool
extends Node3D
## A fixed set of real OmniLight3Ds handed out each frame to the effects that most deserve them
## (explosion > laser impact > muzzle flash > tracer nearest the camera). The Compatibility
## renderer allows 8 lights per object and 32 per frame, so dozens of projectiles each carrying
## a light can't work; effects fake their glow with emissive + splats and borrow a real light
## only when they win it here. Nothing is allocated after `resize()`.
##
## Per frame: effects call `request()` (continuous: tracers, beams) or `flash()` (timed:
## explosions, muzzle flashes; the pool fades them), then FxWorld calls `commit()` once.

## Priorities. Within a priority, nearer the camera wins.
const PRIORITY_VEHICLE := 0.5
const PRIORITY_TRACER := 1.0
const PRIORITY_MUZZLE := 2.0
const PRIORITY_BEAM := 3.0
const PRIORITY_EXPLOSION := 4.0

## Most timed flashes alive at once; the oldest is replaced when full.
const MAX_FLASHES := 48

var lights: Array[OmniLight3D] = []
## Lights lit by the last commit() (for the perf overlay and tests).
var lit_count := 0
var enabled := true

# This frame's continuous requests (parallel arrays, reused).
var _positions := PackedVector3Array()
var _colors := PackedColorArray()
var _energies := PackedFloat32Array()
var _ranges := PackedFloat32Array()
var _priorities := PackedFloat32Array()
var _count := 0
# Timed flashes: position, color, peak energy, range, start, duration, priority.
var _flashes: Array[Dictionary] = []


func _init(size := 8) -> void:
	name = "LightPool"
	resize(size)


func resize(size: int) -> void:
	for light in lights:
		light.free()
	lights.clear()
	for i in size:
		var light := OmniLight3D.new()
		light.name = "PoolLight%d" % i
		light.shadow_enabled = false
		light.light_bake_mode = Light3D.BAKE_DISABLED
		light.omni_attenuation = 1.6
		light.visible = false
		add_child(light)
		lights.append(light)


## A light wanted for this frame only.
func request(position: Vector3, color: Color, energy: float, light_range: float, priority: float) -> void:
	if _count >= _positions.size():
		var grow := maxi(16, _positions.size())
		_positions.resize(_positions.size() + grow)
		_colors.resize(_colors.size() + grow)
		_energies.resize(_energies.size() + grow)
		_ranges.resize(_ranges.size() + grow)
		_priorities.resize(_priorities.size() + grow)
	_positions[_count] = position
	_colors[_count] = color
	_energies[_count] = energy
	_ranges[_count] = light_range
	_priorities[_count] = priority
	_count += 1


## A light that decays from `energy` to 0 over `duration` seconds (quadratic falloff).
func flash(position: Vector3, color: Color, energy: float, light_range: float, duration: float, priority: float, now: float) -> void:
	var entry := {"position": position, "color": color, "energy": energy, "range": light_range,
			"start": now, "duration": maxf(duration, 0.001), "priority": priority}
	if _flashes.size() >= MAX_FLASHES:
		_flashes.pop_front()
	_flashes.append(entry)


## Assign the pool to the best requests and clear the frame's requests.
func commit(camera_position: Vector3, now: float) -> void:
	var i := 0
	while i < _flashes.size():
		var entry: Dictionary = _flashes[i]
		var age: float = (now - float(entry["start"])) / float(entry["duration"])
		if age >= 1.0:
			_flashes.remove_at(i)
			continue
		var fade := (1.0 - age) * (1.0 - age)
		request(entry["position"], entry["color"], float(entry["energy"]) * fade, entry["range"], entry["priority"])
		i += 1
	var chosen := choose(_positions, _priorities, _count, camera_position, lights.size() if enabled else 0)
	for slot in lights.size():
		var light := lights[slot]
		if slot < chosen.size():
			var index := chosen[slot]
			light.position = _positions[index]
			light.light_color = _colors[index]
			light.light_energy = _energies[index]
			light.omni_range = _ranges[index]
			light.visible = true
		else:
			light.visible = false
	lit_count = chosen.size()
	_count = 0


## Which of `count` requests get one of `capacity` lights: highest priority first, then nearest
## the camera. Pure, so tests can check the policy without a renderer.
static func choose(positions: PackedVector3Array, priorities: PackedFloat32Array, count: int,
		camera_position: Vector3, capacity: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if capacity <= 0 or count <= 0:
		return result
	var scored: Array = []
	for i in count:
		# Priority dominates (1000 m per level); distance breaks ties.
		scored.append([priorities[i] * 1000.0 - positions[i].distance_to(camera_position), i])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for k in mini(capacity, scored.size()):
		result.append(scored[k][1])
	return result

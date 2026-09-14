class_name CameraShake
extends Node
## Trauma-based camera shake (the Eiserloh model): events add trauma 0..1, it decays linearly, and
## the view shakes by trauma² × smooth noise, so small hits barely register while a kill next to the
## camera jolts. Applied through Camera3D.h_offset / v_offset on the current camera, which move the
## VIEW without moving the camera node, so it composes with whatever gameplay does to the camera and
## never touches the simulation. Scaled by distance to the event; capped by FxQuality-independent
## settings (it's free).

## Trauma lost per second.
const DECAY := 1.6
## Largest view offset at trauma 1, in meters (perspective) / ortho size fraction (tactical view).
const MAX_OFFSET := 0.9
const ORTHO_MAX_FRACTION := 0.006
## Noise speed (Hz-ish).
const FREQUENCY := 22.0

var trauma := 0.0
var enabled := true

var _time := 0.0
var _noise := FastNoiseLite.new()
var _camera: Camera3D
var _applied := Vector2.ZERO


func _init() -> void:
	name = "CameraShake"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.seed = 3
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0


## Add trauma for an event at `position` (null = no falloff). Full strength within `radius` of the
## camera's focus, fading to nothing at 4× the radius.
func add(amount: float, position: Variant = null, radius := 25.0) -> void:
	if not enabled:
		return
	var strength := amount
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if position is Vector3 and camera != null:
		strength *= falloff(focus_point(camera).distance_to(position), radius)
	trauma = clampf(trauma + strength, 0.0, 1.0)


## 1 within `radius`, fading linearly to 0 at 4× radius.
static func falloff(distance: float, radius: float) -> float:
	return clampf(1.0 - (distance - radius) / (radius * 3.0), 0.0, 1.0)


## The offset (x, y) for a trauma level at time t; pure for tests.
func offset_at(level: float, t: float) -> Vector2:
	var shake := level * level
	return Vector2(_noise.get_noise_2d(t * FREQUENCY, 0.0), _noise.get_noise_2d(0.0, t * FREQUENCY)) * shake


func _process(delta: float) -> void:
	_time += delta
	var camera := get_viewport().get_camera_3d()
	if camera != _camera:
		_restore()
		_camera = camera
	if _camera == null:
		return
	if trauma <= 0.0 and _applied == Vector2.ZERO:
		return
	trauma = maxf(0.0, trauma - DECAY * delta)
	var scale := MAX_OFFSET if _camera.projection == Camera3D.PROJECTION_PERSPECTIVE else _camera.size * ORTHO_MAX_FRACTION
	var offset := offset_at(trauma, _time) * scale
	# Remove last frame's shake before adding this frame's, so other offsets on the camera survive.
	_camera.h_offset += offset.x - _applied.x
	_camera.v_offset += offset.y - _applied.y
	_applied = offset


func _restore() -> void:
	if _camera != null and is_instance_valid(_camera):
		_camera.h_offset -= _applied.x
		_camera.v_offset -= _applied.y
	_applied = Vector2.ZERO


func _exit_tree() -> void:
	_restore()


## Where the camera is looking on the ground plane (y = 0): distance falloff is measured from here,
## so a top-down camera 200 m up still shakes for hits in the middle of its view.
static func focus_point(camera: Camera3D) -> Vector3:
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	if absf(forward.y) < 0.01:
		return origin
	var t := -origin.y / forward.y
	return origin + forward * maxf(t, 0.0)

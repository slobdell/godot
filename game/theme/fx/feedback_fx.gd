class_name FeedbackFx
extends Node3D
## Round 37 (feedback, C37.6): the rules the player could not see, drawn in the world, as the lead picked them
## (FeedbackLook): a hit lights the struck side on a ring segment under the tank, a Tanker mending a friend draws a beam
## to it, and a Sonic Emitter blowing shimmers as a cone in the air. FeedbackReader says what is true; this draws it, and
## keeps what UnitBars, the radar and the card read (`mending_of`, `pinned_of`).
##
## Everything is pooled: one MultiMesh of ring segments (feedback_ground.gdshader), one of mending beams
## (feedback_ribbon.gdshader) and a few cone meshes (sonic_cone.gdshader). Fog is respected: nothing is drawn on a
## vehicle the local player cannot see. Visual only: it reads the match, never writes.

const GROUND_SHADER := preload("res://game/theme/fx/shaders/feedback_ground.gdshader")
const RIBBON_SHADER := preload("res://game/theme/fx/shaders/feedback_ribbon.gdshader")
const CONE_SHADER := preload("res://game/theme/fx/shaders/sonic_cone.gdshader")
const WORLD_AABB := AABB(Vector3(-200, -20, -200), Vector3(400, 80, 400))

## The colours of the facts (never a team colour: those are cyan and magenta).
const FACE_COLORS := {"front": Color(0.55, 0.7, 1.0), "side": Color(1.0, 0.9, 0.15), "rear": Color(1.0, 0.12, 0.08)}
const MEND_COLOR := Color(0.35, 1.0, 0.55)

## Ring segments (a ring buffer: each plays once), beams and cones (rewritten every frame).
const HIT_MARKS := 32
const BEAMS := 48
const CONES := 6
## How long a hit's ring segment plays (s).
const HIT_SECTOR_S := 0.9
## His approved flank / rear hit sounds (F3), over the round's own impact: one per target this often at most, and only
## for a gun's round (a machine gun's or a flamer's stream is not a flank shot; artillery from above has no flank).
const HIT_SOUNDS := {"side": "flank_hit", "rear": "rear_hit"}
const HIT_SOUND_EVERY_S := 0.4
const SOUNDLESS_MODELS := ["stream", "arc"]
## Fired rounds remembered until they land (for where the shot came from and whether it fell from above).
const MAX_TRACKED := 256
## Who is pinned and who is being mended changes over seconds, so the reading (every unit, fog, menders) is redone this
## often; the marks of the units it found still follow them every frame. perf-scene a8690b304 builder0: the reading
## every frame cost ~0.2 ms with every look off.
const REREAD_S := 0.1

var reader := FeedbackReader.new()
## Hits drawn since load, by kind, and the last ring segment's {kind, toward} (tests and the showcase).
var hits_drawn := {}
var last_segment := {}
## Patient name -> where its repair sounds (this frame's mending beams, for RepairHum).
var mending_points := {}
## What the last update held: beams and cones (tests and the showcase).
var last_counts := {}

var _fx: FxWorld
var _ground := MultiMeshInstance3D.new()
var _beams := MultiMeshInstance3D.new()
var _ground_material := ShaderMaterial.new()
var _ribbon_material := ShaderMaterial.new()
var _cone_material := ShaderMaterial.new()
var _cones: Array[MeshInstance3D] = []
var _next_hit := 0
## projectile id -> {muzzle: Vector3, arc: bool, model: String}
var _shots := {}
var _shot_order: Array[int] = []
## target name -> when its last flank / rear sound played.
var _last_sound := {}
## patient name -> {node, rate}; name -> pinned level. This frame's, for UnitBars.
var _mending := {}
var _pinned := {}
## The units the last reading found pinned or mended (and visible), and when to read again.
var _marked: Array = []
var _next_read := 0.0
var _controls: Node
var _search_left := 0.0


func _init(fx: FxWorld = null) -> void:
	name = "FeedbackFx"
	_fx = fx
	_ground_material.shader = GROUND_SHADER
	_ribbon_material.shader = RIBBON_SHADER
	_cone_material.shader = CONE_SHADER
	_setup(_ground, _ground_material, HIT_MARKS, "Marks")
	_setup(_beams, _ribbon_material, BEAMS, "Beams")
	for i in HIT_MARKS:
		_ground.multimesh.set_instance_custom_data(i, Color(-1000.0, 0.001, 0.0, 0.0))
	for i in CONES:
		var cone := MeshInstance3D.new()
		cone.name = "SoundCone%d" % i
		cone.visible = false
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.material_override = _cone_material
		add_child(cone)
		_cones.append(cone)


func _setup(instance: MultiMeshInstance3D, material: ShaderMaterial, count: int, node_name: String) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, quad.get_mesh_arrays())
	mesh.surface_set_material(0, material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	FxMultiMesh.resize(multimesh, count)
	instance.multimesh = multimesh
	FxMultiMesh.never_interpolated(instance)
	instance.name = node_name
	instance.custom_aabb = WORLD_AABB
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


## K2 weapon_fired (from MatchFxLink): where each round left from, and the Emitter's puffs.
func fired(event: Dictionary, now: float) -> void:
	reader.fired(event, now)
	var id := int(event.get("projectile_id", -1))
	if id < 0:
		return
	var model := String(event.get("fire_model", ""))
	_shots[id] = {"muzzle": K2Events.to_vector(event.get("muzzle", [0, 0, 0])), "arc": model == "arc", "model": model}
	_shot_order.append(id)
	if _shot_order.size() > MAX_TRACKED:
		_shots.erase(_shot_order.pop_front())


## K2 projectile_impact (from MatchFxLink): a hit on a vehicle, drawn by the face it struck.
func impact(event: Dictionary, now: float) -> void:
	var id := int(event.get("projectile_id", -1))
	var shot: Dictionary = _shots.get(id, {})
	_shots.erase(id)
	var kind := FeedbackReader.hit_kind(event)
	if kind == "" or bool(shot.get("arc", false)):
		return  # a miss, or a round from above (artillery has no flank)
	var target_name := String(event["target"])
	var target := _unit(target_name)
	if target == null or not _shown(target):
		return
	var at := K2Events.to_vector(event.get("position"))
	var origin: Vector3 = shot.get("muzzle", at - K2Events.to_vector(event.get("normal", [0, 0, 1])) * 10.0)
	var toward := Vector3(origin.x - target.global_position.x, 0.0, origin.z - target.global_position.z)
	toward = toward.normalized() if toward.length() > 0.01 else Vector3.FORWARD
	if kind == "deck" or not FeedbackLook.on("hit"):
		return  # the engine deck already flares gold and crunches (WeaponFx)
	if HIT_SOUNDS.has(kind) and not SOUNDLESS_MODELS.has(String(shot.get("model", ""))):
		_hit_sound(kind, target_name, at, now)
	hits_drawn[kind] = int(hits_drawn.get(kind, 0)) + 1
	last_segment = {"kind": kind, "toward": toward}
	_sector(kind, target, toward, now)


## This frame's mending of `unit_name` ({node, rate}) or {}.
func mending_of(unit_name: StringName) -> Dictionary:
	return _mending.get(unit_name, {})


## This frame's pinned level of `unit_name` (0..1).
func pinned_of(unit_name: StringName) -> float:
	return float(_pinned.get(unit_name, 0.0))


func update(now: float) -> void:
	_ground_material.set_shader_parameter("now", now)
	_ribbon_material.set_shader_parameter("now", now)
	_cone_material.set_shader_parameter("now", now)
	var beams := 0
	var cones := 0
	mending_points.clear()
	var game_match := _fx.link.attached_match() if _fx != null else null
	if game_match == null:
		_mending.clear()
		_pinned.clear()
		_marked.clear()
	else:
		if now >= _next_read or now < _next_read - REREAD_S:
			_next_read = now + REREAD_S
			_read()
		for node in _marked if FeedbackLook.on("repair") else []:
			var tank := node as Tank
			var link: Dictionary = _mending.get(tank.name, {}) if is_instance_valid(tank) and tank.is_alive() else {}
			if link.is_empty() or link["node"] == tank or not is_instance_valid(link["node"]) or beams >= BEAMS:
				continue
			var mender: Tank = link["node"]
			var from := FxWorld.visual_transform(mender).origin + Vector3.UP * _top(mender) * 0.8
			var to := FxWorld.visual_transform(tank).origin + Vector3.UP * _top(tank) * 0.7
			_beam(beams, from, to)
			beams += 1
			mending_points[String(tank.name)] = to
		for cone: Dictionary in reader.active_cones(now) if FeedbackLook.on("cone") else []:
			var shooter := _unit(String(cone["shooter"]))
			if shooter == null or not _shown(shooter) or cones >= CONES:
				continue
			_air_cone(_cones[cones], cone["origin"], cone["direction"], float(cone["range"]), float(cone["cone_deg"]))
			cones += 1
	_beams.multimesh.visible_instance_count = beams
	for i in range(cones, CONES):
		_cones[i].visible = false
	last_counts = {"beams": beams, "cones": cones}


func _hit_sound(kind: String, target_name: String, at: Vector3, now: float) -> void:
	if _fx == null or _fx.sfx == null or now - float(_last_sound.get(target_name, -10.0)) < HIT_SOUND_EVERY_S:
		return
	if _last_sound.size() > 64:
		_last_sound.clear()
	_last_sound[target_name] = now
	_fx.sfx.play_at(String(HIT_SOUNDS[kind]), at)


## The struck face's quarter of a ring under the target, toward where the round came from.
func _sector(kind: String, target: Tank, toward: Vector3, now: float) -> void:
	var i := _next_hit
	_next_hit = (_next_hit + 1) % HIT_MARKS
	var place := FxWorld.visual_transform(target).origin
	_ground.multimesh.set_instance_transform(i, Transform3D(_yaw_basis(toward), place))
	_ground.multimesh.set_instance_color(i, Color(FACE_COLORS[kind], 1.0))
	_ground.multimesh.set_instance_custom_data(i, Color(now, HIT_SECTOR_S, _hull_span(target) * 1.7, 0.0))


func _beam(i: int, from: Vector3, to: Vector3) -> void:
	var basis := Basis(Vector3.RIGHT, Vector3.UP, to - from)
	_beams.multimesh.set_instance_transform(i, Transform3D(basis, from))
	_beams.multimesh.set_instance_color(i, Color(MEND_COLOR, 1.0))
	_beams.multimesh.set_instance_custom_data(i, Color(0.0, 0.0, 0.7, 1.5))


func _air_cone(cone: MeshInstance3D, origin: Vector3, direction: Vector3, reach: float, cone_deg: float) -> void:
	var mesh := cone.mesh as CylinderMesh
	if mesh == null or not is_equal_approx(mesh.height, reach):
		mesh = CylinderMesh.new()
		mesh.top_radius = 0.4
		mesh.bottom_radius = tan(deg_to_rad(cone_deg) * 0.5) * reach
		mesh.height = reach
		mesh.cap_top = false
		mesh.cap_bottom = false
		mesh.radial_segments = 24
		mesh.rings = 1
		cone.mesh = mesh
	var flat := Vector3(direction.x, 0.0, direction.z)
	flat = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	# The cylinder's axis is +Y with its narrow top at +height/2: turn +Y to +Z (back at the horns), centre it mid-reach.
	var basis := Basis(Vector3.RIGHT, PI / 2.0)
	basis = _yaw_basis(flat) * basis
	cone.global_transform = Transform3D(basis, origin + flat * reach * 0.5)
	cone.visible = true


## A basis whose forward (-Z) is `forward`, flattened.
static func _yaw_basis(forward: Vector3) -> Basis:
	var flat := Vector3(forward.x, 0.0, forward.z)
	if flat.length() < 0.001:
		return Basis.IDENTITY
	return Basis(Vector3.UP, atan2(-flat.x, -flat.z))


func _unit(unit_name: String) -> Tank:
	return _fx.link.find_unit(unit_name) as Tank if _fx != null else null


## The longer side of a hull's footprint (m).
static func _hull_span(tank: Tank) -> float:
	var size: Variant = Units.stat(String(tank.unit_id), "hull_size", [])
	return maxf(float(size[0]), float(size[2])) if size is Array and (size as Array).size() == 3 else 4.0


static func _top(tank: Tank) -> float:
	var size: Variant = Units.stat(String(tank.unit_id), "hull_size", [])
	return float(size[1]) if size is Array and (size as Array).size() == 3 else 2.0


## The reading: every visible unit's pinned level and mender, for the marks and for UnitBars, the radar and the card.
func _read() -> void:
	_find_controls()
	_mending.clear()
	_pinned.clear()
	_marked.clear()
	var tanks: Array = _fx.link.unit_nodes()
	var menders := FeedbackReader.menders(tanks)
	for node in tanks:
		var tank := node as Tank
		if tank == null or not tank.is_alive():
			continue
		var level := FeedbackReader.pinned_level(tank.suppression)
		var link := FeedbackReader.mending(tank, menders)
		if (level <= 0.0 and link.is_empty()) or not _shown(tank):
			continue
		_marked.append(tank)
		if level > 0.0:
			_pinned[tank.name] = level
		if not link.is_empty():
			_mending[tank.name] = link


## Whether the local player may see `tank` (fog); with no local player (a showcase, a spectator) everything shows.
func _shown(tank: Tank) -> bool:
	var game_match := _fx.link.attached_match() as Match if _fx != null else null
	if game_match == null or not is_instance_valid(_controls):
		return true
	var team: Variant = _controls.get("team")
	return team == null or int(team) < 0 or game_match.is_visible_to(int(team), tank)


func _find_controls() -> void:
	if is_instance_valid(_controls):
		return
	_search_left -= get_process_delta_time()
	if _search_left > 0.0 or not is_inside_tree() or get_tree().current_scene == null:
		return
	_search_left = 0.5
	_controls = get_tree().current_scene.find_child("TacticalMap", true, false)

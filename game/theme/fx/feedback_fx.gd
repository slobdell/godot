class_name FeedbackFx
extends Node3D
## Round 37 (feedback, C37.6): the rules the player could not see, drawn in the world. FeedbackReader says what is true
## (a hit's face, a pinned crew, a Tanker mending, an Emitter blowing); FeedbackLook says which look each slot uses; this
## draws the world half of those looks, and keeps what UnitBars needs for the screen half (`recent_hit`, `mending_of`,
## `pinned_of`).
##
## Everything is pooled: one MultiMesh of ground marks (feedback_ground.gdshader), one of mending beams
## (feedback_ribbon.gdshader), a few cone meshes (sonic_cone.gdshader), and FxWorld's bursts and lights. Fog is
## respected: nothing is drawn on a vehicle the local player cannot see. Visual only: it reads the match, never writes.

const GROUND_SHADER := preload("res://game/theme/fx/shaders/feedback_ground.gdshader")
const RIBBON_SHADER := preload("res://game/theme/fx/shaders/feedback_ribbon.gdshader")
const CONE_SHADER := preload("res://game/theme/fx/shaders/sonic_cone.gdshader")
const WORLD_AABB := AABB(Vector3(-200, -20, -200), Vector3(400, 80, 400))

enum Mark { HIT_SECTOR, PIN_RING, REACH_RING, MENDING_GLOW, RIPPLES, FOOTPRINT }

## The colours of the facts (never a team colour: those are cyan and magenta).
const FACE_COLORS := {"front": Color(0.55, 0.7, 1.0), "side": Color(1.0, 0.9, 0.15), "rear": Color(1.0, 0.12, 0.08),
		"deck": Color(1.0, 0.8, 0.22)}
const PIN_COLOR := Color(1.0, 0.86, 0.25)
const MEND_COLOR := Color(0.35, 1.0, 0.55)
const SOUND_COLOR := Color(0.62, 0.48, 1.0)

## Transient hit marks (a ring buffer) and held marks (rewritten every frame).
const HIT_MARKS := 32
const HELD_MARKS := 128
const BEAMS := 48
const CONES := 6
## How long a hit is remembered for the screen marker, and how long its ring sector plays (s).
const HIT_MEMORY_S := 1.2
const HIT_SECTOR_S := 0.9
## One flank/rear flare per target this often at most: a machine gun's stream is not eleven flares a second.
const FLARE_EVERY_S := 0.3
## Fired rounds remembered until they land (for where the shot came from and whether it fell from above).
const MAX_TRACKED := 256
## Who is pinned and who is being mended changes over seconds, so the reading (every unit, fog, menders) is redone this
## often; the marks of the units it found still follow them every frame. perf-scene a8690b304 builder0: the reading
## every frame cost ~0.2 ms with every look off.
const REREAD_S := 0.1

var reader := FeedbackReader.new()
## Hits drawn since load, by kind (tests and the showcase).
var hits_drawn := {}
## What the last update held: counts per mark kind, beams and cones (tests and the showcase).
var last_counts := {}

var _fx: FxWorld
var _ground := MultiMeshInstance3D.new()
var _beams := MultiMeshInstance3D.new()
var _ground_material := ShaderMaterial.new()
var _ribbon_material := ShaderMaterial.new()
var _cone_material := ShaderMaterial.new()
var _cones: Array[MeshInstance3D] = []
var _next_hit := 0
## projectile id -> {muzzle: Vector3, arc: bool}
var _shots := {}
var _shot_order: Array[int] = []
## target name -> {kind, time, toward: Vector3 (flat, from the target toward the shot's origin)}
var _hits := {}
var _last_flare := {}
## patient name -> {node, rate}; name -> pinned level. This frame's, for UnitBars.
var _mending := {}
var _pinned := {}
## The units the last reading found pinned or mended (and visible), and when to read again.
var _marked: Array = []
var _next_read := 0.0
var _cone_half_deg := 20.0
var _controls: Node
var _search_left := 0.0


func _init(fx: FxWorld = null) -> void:
	name = "FeedbackFx"
	_fx = fx
	_ground_material.shader = GROUND_SHADER
	_ribbon_material.shader = RIBBON_SHADER
	_cone_material.shader = CONE_SHADER
	_cone_half_deg = float(Weapons.profile("sonic_emitter").get("cone_deg", 40.0)) * 0.5
	_setup(_ground, _ground_material, HIT_MARKS + HELD_MARKS, "Marks")
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
	_shots[id] = {"muzzle": K2Events.to_vector(event.get("muzzle", [0, 0, 0])), "arc": String(event.get("fire_model", "")) == "arc"}
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
	_hits[target_name] = {"kind": kind, "time": now, "toward": toward}
	hits_drawn[kind] = int(hits_drawn.get(kind, 0)) + 1
	if FeedbackLook.has("hit", "a"):
		_flare(kind, at, toward, target_name, now)
	if FeedbackLook.has("hit", "c") and kind != "deck":
		_sector(kind, target, toward, now)


## The last hit on `unit_name` still worth showing at `now`: {kind, time, toward} or {}.
func recent_hit(unit_name: String, now: float) -> Dictionary:
	var hit: Dictionary = _hits.get(unit_name, {})
	if hit.is_empty() or now - float(hit["time"]) > HIT_MEMORY_S:
		return {}
	return hit


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
	_ground_material.set_shader_parameter("cone_half_deg", _cone_half_deg)
	var held := 0
	var beams := 0
	var cones := 0
	var counts := {}
	var game_match := _fx.link.attached_match() if _fx != null else null
	if game_match == null:
		_mending.clear()
		_pinned.clear()
		_marked.clear()
	else:
		if now >= _next_read or now < _next_read - REREAD_S:
			_next_read = now + REREAD_S
			_read()
		var reaching := {}
		for node in _marked:
			var tank := node as Tank
			if not is_instance_valid(tank) or not tank.is_alive():
				continue
			var place := FxWorld.visual_transform(tank).origin
			var level := float(_pinned.get(tank.name, 0.0))
			if level > 0.0 and FeedbackLook.has("pinned", "b") and held < HELD_MARKS:
				held = _held(held, Mark.PIN_RING, place, Vector3.FORWARD, _hull_span(tank) * 1.5, PIN_COLOR, level, counts)
			var link: Dictionary = _mending.get(tank.name, {})
			if link.is_empty():
				continue
			var mender: Tank = link["node"]
			if not is_instance_valid(mender):
				continue
			reaching[mender] = true
			if FeedbackLook.has("repair", "a") and mender != tank and beams < BEAMS:
				var from := FxWorld.visual_transform(mender).origin + Vector3.UP * _top(mender) * 0.8
				var to := place + Vector3.UP * _top(tank) * 0.7
				_beam(beams, from, to)
				beams += 1
			if FeedbackLook.has("repair", "b") and held < HELD_MARKS:
				held = _held(held, Mark.MENDING_GLOW, place, Vector3.FORWARD, _hull_span(tank) * 2.0, MEND_COLOR, 1.0, counts)
		if FeedbackLook.has("repair", "b"):
			for mender: Tank in reaching:
				var radius := float(Units.stat(mender.unit_id, "repair_radius_m", 0.0))
				if held < HELD_MARKS:
					held = _held(held, Mark.REACH_RING, FxWorld.visual_transform(mender).origin, Vector3.FORWARD, radius * 2.0,
							MEND_COLOR, 0.9, counts)
		for cone: Dictionary in reader.active_cones(now):
			var shooter := _unit(String(cone["shooter"]))
			if shooter == null or not _shown(shooter):
				continue
			var origin: Vector3 = cone["origin"]
			var direction: Vector3 = cone["direction"]
			var reach := float(cone["range"])
			if FeedbackLook.has("cone", "a") and held < HELD_MARKS:
				held = _held(held, Mark.RIPPLES, origin, direction, reach * 2.0, SOUND_COLOR, 1.0, counts)
			if FeedbackLook.has("cone", "b") and held < HELD_MARKS:
				held = _held(held, Mark.FOOTPRINT, origin, direction, reach * 2.0, SOUND_COLOR, 0.8, counts)
			if FeedbackLook.has("cone", "c") and cones < CONES:
				_air_cone(_cones[cones], origin, direction, reach, float(cone["cone_deg"]))
				cones += 1
	_ground.multimesh.visible_instance_count = HIT_MARKS + held
	_beams.multimesh.visible_instance_count = beams
	for i in range(cones, CONES):
		_cones[i].visible = false
	counts["beams"] = beams
	counts["cones"] = cones
	last_counts = counts


## A flank, rear or deck hit's flare at the impact (look a): side amber, rear red and bigger, the front a pale glance.
## The deck already flares gold in WeaponFx; this adds nothing to it.
func _flare(kind: String, at: Vector3, toward: Vector3, target_name: String, now: float) -> void:
	if kind == "deck" or _fx == null:
		return
	if now - float(_last_flare.get(target_name, -10.0)) < FLARE_EVERY_S:
		return
	_last_flare[target_name] = now
	if _last_flare.size() > 64:
		_last_flare.clear()
	var color: Color = FACE_COLORS[kind]
	var lift := at + Vector3.UP * 0.4 + toward * 0.3
	match kind:
		"front":
			# The armour held: a small pale glance thrown back the way the round came.
			_fx.bursts.spawn(BurstSystem.Kind.STAR, lift, 1.6, 0.12, color, now)
			_fx.bursts.spawn(BurstSystem.Kind.SPARKS, lift, 2.2, 0.25, color, now, toward * 6.0 + Vector3.UP * 2.0, 3.0)
		"side":
			# Bigger than the round's own fireball and a colour it never has, so it reads over it.
			_fx.bursts.spawn(BurstSystem.Kind.FLARE, lift + Vector3.UP * 0.6, 9.0, 0.5, color, now)
			_fx.bursts.spawn(BurstSystem.Kind.SPARKS, lift, 7.0, 0.6, color, now, Vector3.UP * 4.0, 1.5)
			_fx.lights.flash(lift + Vector3.UP, color, 3.5, 10.0, 0.25, LightPool.PRIORITY_EXPLOSION, now)
		"rear":
			_fx.bursts.spawn(BurstSystem.Kind.FLARE, lift + Vector3.UP * 0.8, 13.0, 0.6, color, now)
			_fx.bursts.spawn(BurstSystem.Kind.SHOCKWAVE, at + Vector3.UP * 0.3, 10.0, 0.5, color, now)
			_fx.bursts.spawn(BurstSystem.Kind.SPARKS, lift, 9.0, 0.8, color, now, Vector3.UP * 6.0, 1.5)
			_fx.lights.flash(lift + Vector3.UP, color, 5.0, 12.0, 0.3, LightPool.PRIORITY_EXPLOSION, now)


## Look c: the struck face's quarter of a ring under the target.
func _sector(kind: String, target: Tank, toward: Vector3, now: float) -> void:
	var i := _next_hit
	_next_hit = (_next_hit + 1) % HIT_MARKS
	var place := FxWorld.visual_transform(target).origin
	_ground.multimesh.set_instance_transform(i, Transform3D(_yaw_basis(toward), place))
	_ground.multimesh.set_instance_color(i, Color(FACE_COLORS[kind], 1.0))
	_ground.multimesh.set_instance_custom_data(i, Color(now, HIT_SECTOR_S, _hull_span(target) * 1.7, float(Mark.HIT_SECTOR)))


func _held(index: int, mark: int, place: Vector3, forward: Vector3, size: float, color: Color, strength: float,
		counts: Dictionary) -> int:
	var i := HIT_MARKS + index
	_ground.multimesh.set_instance_transform(i, Transform3D(_yaw_basis(forward), Vector3(place.x, place.y, place.z)))
	_ground.multimesh.set_instance_color(i, Color(color, strength))
	_ground.multimesh.set_instance_custom_data(i, Color(0.0, -1.0, size, float(mark)))
	counts[mark] = int(counts.get(mark, 0)) + 1
	return index + 1


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


## Whether the local player may see `tank` (fog); with no local player (a showcase, a spectator) everything shows.
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

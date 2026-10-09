class_name NativeRecord
extends RefCounted
## Round 24 (native, N3a): the data the C++ owns for the per-vehicle tick, handed over ONCE a tick in one call each.
## `fill` packs one record per living hull under `tanks_root` (the same hulls, in the same order, as Avoidance's
## table) into flat columns and calls `TankNative.record_load`; `fill_contacts` packs each team's intel into its
## contacts table (`contacts_load`). The column layout is `native/src/tank_record.h`'s (RecordLayout, ContactLayout);
## `layout_ok()` holds these constants to the library's. Nothing reads the record yet: N3b/N3c's ported execute step
## will, in place of `ctl.tank.*` and the Dictionaries. `_agents/native.md` *N3*; the proof tests/test_native_record.gd.
##
## Widths (native.md hazard 1): Vector3 members go in float32 columns, GDScript floats (tank.speed(), the command's
## throttle/turn, the hull's radii) in float64 columns, so the C++ reads the bits the GDScript reads.

const F32 := 15  # position 0, forward 3, velocity 6, the last aim 9, the turret's forward 12
const F64 := 9  # speed, throttle, turn, max_forward_speed, hull_turn_rate, radius, half_w, half_l, wheel_radius
const I32 := 4  # team, health, fire, path_index
const CONTACT_F32 := 12  # position 0, velocity 3, forward 6, turret_forward 9
const CONTACT_F64 := 2  # suppression, weapon_range
const CONTACT_I32 := 4  # health, shield, visible, seen_tick

## The physics frame and root the record was last filled for (once a tick, whoever asks first).
static var _frame := -1
static var _root := 0
## Measurement (make native-bench / the record test): rows in the last fill.
static var rows := 0


## Do this script's strides match the loaded library's? (False without the library.)
static func layout_ok() -> bool:
	if not NativeBridge.available:
		return false
	var layout: Dictionary = NativeBridge.impl.record_layout()
	return layout == {"f32": F32, "f64": F64, "i32": I32, "contact_f32": CONTACT_F32, "contact_f64": CONTACT_F64,
			"contact_i32": CONTACT_I32}


## Movement.wheel_radius() for a unit, without a mover (the player's hull has none): the same expression.
static func wheel_radius_of(unit_id: String) -> float:
	if String(Units.stat(unit_id, "locomotion", "tracks")) == "wheels":
		return maxf(float(Units.stat(unit_id, "min_turn_radius_m", 0.0)), 0.5)
	return 0.0


## The record for this tick (once per physics frame and root; `force` refills, for tests). False without the library.
static func fill(tanks_root: Node, force := false) -> bool:
	if not NativeBridge.available or tanks_root == null:
		return false
	var frame := Engine.get_physics_frames()
	var root := tanks_root.get_instance_id()
	if not force and frame == _frame and root == _root:
		return true
	_frame = frame
	_root = root
	# The neighbour set is Avoidance's, so its table must be this tick's (a no-op when a mover already refreshed it).
	Avoidance.refresh(tanks_root)
	var names := PackedStringArray()
	var units := PackedStringArray()
	var f32 := PackedFloat32Array()
	var f64 := PackedFloat64Array()
	var i32 := PackedInt32Array()
	var route := PackedVector3Array()
	var offsets := PackedInt32Array([0])
	for child in tanks_root.get_children():
		var tank := child as Tank
		if tank == null or not tank.is_alive():
			continue  # Avoidance.refresh's filter: the same rows in the same order
		names.append(String(tank.name))
		units.append(tank.unit_id)
		var p := tank.global_position
		var forward := -tank.global_basis.z
		var velocity := tank.estimated_velocity
		var aim := tank.command.aim_point
		var turret := tank.turret_forward()
		f32.append_array([p.x, p.y, p.z, forward.x, forward.y, forward.z, velocity.x, velocity.y, velocity.z,
				aim.x, aim.y, aim.z, turret.x, turret.y, turret.z])
		var halves: Vector2 = Avoidance._halves_of(tank.unit_id)
		var mover := Movement.of(tank)
		f64.append_array([tank.speed(), tank.command.throttle, tank.command.turn, tank.max_forward_speed,
				tank.hull_turn_rate, Avoidance.radius_of(tank.unit_id), halves.x, halves.y,
				mover.wheel_radius() if mover != null else wheel_radius_of(tank.unit_id)])
		i32.append_array([tank.team, tank.health, 1 if tank.command.fire else 0, mover._path_index if mover != null else 0])
		if mover != null:
			route.append_array(mover._path)
		offsets.append(route.size())
	var cover := 0
	var cover_map := CoverMap.of(tanks_root)
	if cover_map != null and cover_map._native != null:
		cover = cover_map._native.get_instance_id()
	rows = names.size()
	return NativeBridge.impl.record_load(names, units, f32, f64, i32, route, offsets, cover)


## Each team's contacts table from the match's intel: one row per contact, in name order (AiTickCache.intel_names'
## order, sorted here without touching that cache's memo), the raw intel fields plus the weapon's range.
static func fill_contacts(game_match: Match) -> bool:
	if not NativeBridge.available or game_match == null:
		return false
	var ok := true
	for side in 2:
		var intel: Dictionary = game_match.intel[side]
		var keys := intel.keys()
		keys.sort()
		var names := PackedStringArray()
		var units := PackedStringArray()
		var weapons := PackedStringArray()
		var roles := PackedStringArray()
		var f32 := PackedFloat32Array()
		var f64 := PackedFloat64Array()
		var i32 := PackedInt32Array()
		for contact_name: String in keys:
			var known: Dictionary = intel[contact_name]
			var weapon_id := String(known["weapon"])
			names.append(contact_name)
			units.append(String(known.get("unit", "")))
			weapons.append(weapon_id)
			roles.append(String(known.get("role", "")))
			var p: Vector3 = known["position"]
			var v: Vector3 = known["velocity"]
			var fw: Vector3 = known["forward"]
			var tf: Vector3 = known["turret_forward"]
			f32.append_array([p.x, p.y, p.z, v.x, v.y, v.z, fw.x, fw.y, fw.z, tf.x, tf.y, tf.z])
			f64.append_array([float(known.get("suppression", 0.0)), float(Weapons.profile(weapon_id)["range"])])
			i32.append_array([int(known["health"]), int(known.get("shield", 0)), 1 if bool(known["visible"]) else 0,
					int(known["seen_tick"])])
		ok = NativeBridge.impl.contacts_load(side, names, units, weapons, roles, f32, f64, i32) and ok
	return ok

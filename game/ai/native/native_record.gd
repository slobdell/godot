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
	# NOT Avoidance.refresh here: its table reads every mover's is_under_way(), which changes as the controllers run,
	# so building it earlier than the first mover that avoids would change it. The neighbour set is asked of the
	# avoidance table when it is needed (record_neighbours), as the GDScript asks Avoidance.neighbours.
	var hulls: Array[Tank] = []
	for child in tanks_root.get_children():
		var tank := child as Tank
		if tank != null and tank.is_alive():
			hulls.append(tank)  # Avoidance.refresh's filter: the same rows in the same order
	var n := hulls.size()
	# Pre-sized columns written by index: no temporary Arrays (the first version's append_array([...]) cost ~12 usec
	# a row at 50 v 50).
	var names := PackedStringArray()
	names.resize(n)
	var units := PackedStringArray()
	units.resize(n)
	var f32 := PackedFloat32Array()
	f32.resize(n * F32)
	var f64 := PackedFloat64Array()
	f64.resize(n * F64)
	var i32 := PackedInt32Array()
	i32.resize(n * I32)
	var route := PackedVector3Array()
	var offsets := PackedInt32Array()
	offsets.resize(n + 1)
	offsets[0] = 0
	for r in n:
		var tank := hulls[r]
		names[r] = String(tank.name)
		units[r] = tank.unit_id
		var a := r * F32
		var p := tank.global_position
		f32[a] = p.x
		f32[a + 1] = p.y
		f32[a + 2] = p.z
		var forward := -tank.global_basis.z
		f32[a + 3] = forward.x
		f32[a + 4] = forward.y
		f32[a + 5] = forward.z
		var velocity := tank.estimated_velocity
		f32[a + 6] = velocity.x
		f32[a + 7] = velocity.y
		f32[a + 8] = velocity.z
		var command := tank.command
		var aim := command.aim_point
		f32[a + 9] = aim.x
		f32[a + 10] = aim.y
		f32[a + 11] = aim.z
		var turret := tank.turret_forward()
		f32[a + 12] = turret.x
		f32[a + 13] = turret.y
		f32[a + 14] = turret.z
		var mover := Movement.of(tank)
		var b := r * F64
		f64[b] = tank.speed()
		f64[b + 1] = command.throttle
		f64[b + 2] = command.turn
		f64[b + 3] = tank.max_forward_speed
		f64[b + 4] = tank.hull_turn_rate
		f64[b + 5] = Avoidance.radius_of(tank.unit_id)
		var halves: Vector2 = Avoidance._halves_of(tank.unit_id)
		f64[b + 6] = halves.x
		f64[b + 7] = halves.y
		f64[b + 8] = mover.wheel_radius() if mover != null else wheel_radius_of(tank.unit_id)
		var c := r * I32
		i32[c] = tank.team
		i32[c + 1] = tank.health
		i32[c + 2] = 1 if command.fire else 0
		i32[c + 3] = mover._path_index if mover != null else 0
		if mover != null:
			route.append_array(mover._path)
		offsets[r + 1] = route.size()
	var cover := 0
	var cover_map := CoverMap.of(tanks_root)
	if cover_map != null and cover_map._native != null:
		cover = cover_map._native.get_instance_id()
	rows = n
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
		var n := keys.size()
		var names := PackedStringArray()
		names.resize(n)
		var units := PackedStringArray()
		units.resize(n)
		var weapons := PackedStringArray()
		weapons.resize(n)
		var roles := PackedStringArray()
		roles.resize(n)
		var f32 := PackedFloat32Array()
		f32.resize(n * CONTACT_F32)
		var f64 := PackedFloat64Array()
		f64.resize(n * CONTACT_F64)
		var i32 := PackedInt32Array()
		i32.resize(n * CONTACT_I32)
		for r in n:
			var contact_name: String = keys[r]
			var known: Dictionary = intel[contact_name]
			var weapon_id := String(known["weapon"])
			names[r] = contact_name
			units[r] = String(known.get("unit", ""))
			weapons[r] = weapon_id
			roles[r] = String(known.get("role", ""))
			var a := r * CONTACT_F32
			var p: Vector3 = known["position"]
			f32[a] = p.x
			f32[a + 1] = p.y
			f32[a + 2] = p.z
			var v: Vector3 = known["velocity"]
			f32[a + 3] = v.x
			f32[a + 4] = v.y
			f32[a + 5] = v.z
			var fw: Vector3 = known["forward"]
			f32[a + 6] = fw.x
			f32[a + 7] = fw.y
			f32[a + 8] = fw.z
			var tf: Vector3 = known["turret_forward"]
			f32[a + 9] = tf.x
			f32[a + 10] = tf.y
			f32[a + 11] = tf.z
			f64[r * CONTACT_F64] = float(known.get("suppression", 0.0))
			f64[r * CONTACT_F64 + 1] = float(Weapons.profile(weapon_id)["range"])
			var c := r * CONTACT_I32
			i32[c] = int(known["health"])
			i32[c + 1] = int(known.get("shield", 0))
			i32[c + 2] = 1 if bool(known["visible"]) else 0
			i32[c + 3] = int(known["seen_tick"])
		ok = NativeBridge.impl.contacts_load(side, names, units, weapons, roles, f32, f64, i32) and ok
	return ok

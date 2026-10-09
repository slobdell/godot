class_name NativeRecord
extends RefCounted
## Round 24 (native, N3a): the data the C++ owns for the per-vehicle tick, gathered ONCE a tick in one call each.
## `fill` has the C++ walk `tanks_root` and read every living hull's members itself (`TankNative.record_gather`: a
## member read from C++ is 0.03 usec, where packing the columns here cost ~12 usec a row, +3.8 % of the band at
## 50 v 50); `fill_contacts` hands each team's intel Dictionary over (`contacts_gather`). This script only supplies
## what is a GDScript static (each unit's hull numbers, each weapon's range), once per id. The layout is
## `native/src/tank_record.h`'s (RecordLayout, ContactLayout);
## `layout_ok()` holds these constants to the library's. Nothing reads the record yet: N3b/N3c's ported execute step
## will, in place of `ctl.tank.*` and the Dictionaries. `_agents/native.md` *N3*; the proof tests/test_native_record.gd.
##
## Widths (native.md hazard 1): Vector3 members go in float32 columns, GDScript floats (tank.speed(), the command's
## throttle/turn, the hull's radii) in float64 columns, so the C++ holds the bits the GDScript reads.

const F32 := 15  # position 0, forward 3, velocity 6, the last aim 9, the turret's forward 12
const F64 := 9  # speed, throttle, turn, max_forward_speed, hull_turn_rate, radius, half_w, half_l, wheel_radius
const I32 := 4  # team, health, fire, path_index
const CONTACT_F32 := 12  # position 0, velocity 3, forward 6, turret_forward 9
const CONTACT_F64 := 2  # suppression, weapon_range
const CONTACT_I32 := 4  # health, shield, visible, seen_tick

## The physics frame and root the record was last filled for (once a tick, whoever asks first).
static var _frame := -1
static var _root := 0
## Measurement (the record test): rows in the last fill.
static var rows := 0
## unit id -> PackedFloat64Array[Avoidance.radius_of, half width, half length, Movement.wheel_radius()], and weapon id
## -> Weapons.profile(id)["range"]: the GDScript statics the C++ cannot call, added the first time an id is seen.
static var _hulls := {}
static var _ranges := {}


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
	var cover := 0
	var cover_map := CoverMap.of(tanks_root)
	if cover_map != null and cover_map._native != null:
		cover = cover_map._native.get_instance_id()
	var missing: PackedStringArray = NativeBridge.impl.record_gather(tanks_root, Movement._registry, _hulls, cover)
	if not missing.is_empty():
		for unit_id in missing:
			var halves: Vector2 = Avoidance._halves_of(unit_id)
			_hulls[unit_id] = PackedFloat64Array([Avoidance.radius_of(unit_id), halves.x, halves.y, wheel_radius_of(unit_id)])
		missing = NativeBridge.impl.record_gather(tanks_root, Movement._registry, _hulls, cover)
	rows = NativeBridge.impl.record_size()
	return missing.is_empty()


## Each team's contacts table from the match's intel: one row per contact, in name order (AiTickCache.intel_names'
## order, sorted natively without touching that cache's memo), the raw intel fields plus the weapon's range.
static func fill_contacts(game_match: Match) -> bool:
	if not NativeBridge.available or game_match == null:
		return false
	var ok := true
	for side in 2:
		var missing: PackedStringArray = NativeBridge.impl.contacts_gather(side, game_match.intel[side], _ranges)
		if not missing.is_empty():
			for weapon_id in missing:
				_ranges[weapon_id] = float(Weapons.profile(weapon_id)["range"])
			missing = NativeBridge.impl.contacts_gather(side, game_match.intel[side], _ranges)
		ok = ok and missing.is_empty()
	return ok

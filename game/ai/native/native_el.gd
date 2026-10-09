class_name NativeEl
extends RefCounted
## Round 24 (native, N4 under grant C24.8): SlotGround's grounding natively (native/src/el_native.cpp). First the water
## rules (his bridge, round 24 R1): `on_anchor_side` and `pulled_dry` with wet / over_water / leg_wet / dry_leg_end
## over the arena's terrain rectangles. The seams are at the top of those two functions in slot_ground.gd (brains' file;
## the grant covers seams there and nothing else); tests/test_native_el.gd asks the live functions on every arena
## with water, on points from real fights and on points laid round every rectangle.
##
## The terrain is handed over once per terrain LIST (`is_same` and its size): ArenaTerrain.bounds for each entry and
## whether its kind carves or is a deck. An arena's terrain is set at load and never edited in place.

static var _terrain: Variant = null
static var _terrain_size := -1


static func usable() -> bool:
	return BrainSwitches.native and BrainSwitches.native_el and NativeBridge.available


## The native table holds `data`'s terrain; false when `data` has none (then every water rule is the identity).
static func _terrain_for(data: Dictionary) -> bool:
	if not data.has("terrain"):
		return false
	var terrain: Array = data["terrain"]
	if not is_same(terrain, _terrain) or terrain.size() != _terrain_size:
		var boxes := PackedFloat32Array()
		var kinds := PackedByteArray()
		for entry: Dictionary in terrain:
			boxes.append_array(ArenaTerrain.bounds(entry))
			var kind := String(entry["kind"])
			kinds.append((1 if ArenaTerrain.carves(kind) else 0) | (2 if ArenaTerrain.is_deck(kind) else 0))
		NativeBridge.impl.el_terrain(boxes, kinds, PackedFloat64Array([SlotGround.WET_STEP_M, SlotGround.DRY_MARGIN_M,
				SlotGround.MOUTH_CLEAR_M]))
		_terrain = terrain
		_terrain_size = terrain.size()
	return true


static func on_anchor_side(slot: Vector3, anchor: Vector3, data: Dictionary) -> Vector3:
	if not SlotGround.WET_ENABLED or not _terrain_for(data):
		return slot
	return NativeBridge.impl.el_on_anchor_side(slot, anchor)


static func pulled_dry(point: Vector3, toward: Vector3, data: Dictionary) -> Vector3:
	if not SlotGround.WET_ENABLED or not _terrain_for(data):
		return point
	return NativeBridge.impl.el_pulled_dry(point, toward)


## SlotGround.standable_for natively (C24.8): the hull's clearance pushes, the fit test and the rings over NavNative's
## closest point (native_nav), memoised in the C++ for the map's iteration. Only where the GDScript would reach its
## memo (ground_memo on, the node in a tree, Pathing ready): the guards stay here, and anything else runs the live
## function. SlotGround's `_ground_map` / `_ground_iteration` are kept as the GDScript keeps them, because
## standable_from clears its side memo on them.
static var _ground_configured := false


static func grounds(node: Node3D) -> bool:
	return usable() and BrainSwitches.native_nav and BrainSwitches.ground_memo and node != null \
			and node.is_inside_tree() and Pathing.enabled and Pathing.is_ready(node) and _configure_ground()


static func _configure_ground() -> bool:
	if not _ground_configured:
		_ground_configured = NativeBridge.impl.el_configure(PackedFloat64Array([SlotGround.TOLERANCE_M,
				SlotGround.PROBE_TOLERANCE_M, SlotGround.CLEARANCE_PROBES, SlotGround.CLEARANCE_ITERATIONS,
				SlotGround.FIT_RINGS, SlotGround.GROUND_MEMO_LIMIT]))
	return _ground_configured


static func standable_for(node: Node3D, point: Vector3, clearance: float) -> Vector3:
	var map := node.get_world_3d().navigation_map
	var iteration := NavigationServer3D.map_get_iteration_id(map)
	if map != SlotGround._ground_map or iteration != SlotGround._ground_iteration:
		SlotGround._ground_map = map
		SlotGround._ground_iteration = iteration
		SlotGround._ground_memo.clear()
	return NativeBridge.impl.el_standable_for(NativeBridge.nav, map, iteration, point, clearance, SlotGround.bake_radius())

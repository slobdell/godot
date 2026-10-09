class_name NativeScan
extends RefCounted
## Round 24 (native, N3b `weapon.scan`): `Gunnery._nearest_shootable` as ONE native call over the per-tank record
## (`TankNative.scan_nearest`): the loop over the other team's hulls, the range and "seen" gates and the sight-line ray
## in C++, the same answer as the GDScript (tests/test_native_scan.gd asks the LIVE function on the same poses). The
## seam in gunnery.gd (after CP1) is `if NativeScan.usable(self): return NativeScan.nearest(self)`.
##
## "Seen" (Engagement.is_seen): acquisition off -> every contact; a spotter -> the team's intel says visible (both
## spotters in the game are `Match.is_visible_to(the tank's team, other)`: tank_brain.gd, order_executor.gd); no
## spotter -> the shooter's own sight radius.

## The physics frame the contacts tables were last filled for, per match.
static var _contacts_frame := -1
static var _contacts_match := 0


## Can this gunner's scan go native this tick? (The library, the switch, a match to read intel from.)
static func usable(gunnery: Gunnery) -> bool:
	return BrainSwitches.native and BrainSwitches.native_scan and gunnery.tanks_root != null \
			and gunnery.tanks_root.get_parent() is Match


## The record and the contacts for this physics frame (each filled once, by whoever asks first).
static func ensure_filled(tanks_root: Node, force := false) -> void:
	NativeRecord.fill(tanks_root, force)
	var game_match := tanks_root.get_parent() as Match
	var frame := Engine.get_physics_frames()
	if force or frame != _contacts_frame or _contacts_match != game_match.get_instance_id():
		_contacts_frame = frame
		_contacts_match = game_match.get_instance_id()
		NativeRecord.fill_contacts(game_match)


## `_nearest_shootable()`'s answer, natively. Null when nothing is shootable.
## `force` refills the record and the contacts (tests that move hulls without a physics frame).
static func nearest(gunnery: Gunnery, force := false) -> Tank:
	var tank := gunnery.tank
	ensure_filled(gunnery.tanks_root, force)
	var impl: Object = NativeBridge.impl
	var row: int = impl.record_find(String(tank.name))
	if row < 0:
		return null
	var sector := Vector3.ZERO
	var sector_cos := -1.0
	var facing: Variant = gunnery.weapon_order.get("sector")
	if facing != null:
		var point: Variant = OrderFeed.point(facing)
		if point != null and (point as Vector3).length_squared() > 0.0001:
			sector = (point as Vector3).normalized()
			sector_cos = float(gunnery.weapon_order.get("sector_cos", 0.5))
	var seen_mode := 0 if not Engagement.acquisition_enabled else (1 if gunnery.spotter.is_valid() else 2)
	var pick: int = impl.scan_nearest(row, float(tank.weapon["range"]), sector, sector_cos, seen_mode, tank.sight_radius,
			tank.get_world_3d().space)
	if pick < 0:
		return null
	return gunnery.tanks_root.get_node_or_null(NodePath(impl.record_name(pick))) as Tank

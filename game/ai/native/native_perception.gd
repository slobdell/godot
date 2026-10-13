class_name NativePerception
extends RefCounted
## Round 28 (native N6.3, perception only): who sees whom as one batched pass a team (native/src/perception_native.cpp):
## Match._update_intel's sight line (the first viewer alive, within its sight_radius, on a clear line, for each enemy)
## and its gun-ready sample (a ready viewer with an enemy in range on a clear line). Intel -- the contacts recorded,
## their fields, seen_tick, forgetting -- stays GDScript (match.gd). BrainSwitches.native_perception. The detailed
## profile's per-ray laps (los.ray in Perception.has_line_of_sight) are the GDScript's only; natively the rays are
## counted for SimProfile (intel/los_queries) and not lapped (see NativePathing: the tick profile turns profile_detail on).

static var _configured := false
static var _ok := false
## The lines cast by this intel pass's native calls (summed over both teams' calls; match.gd hands it to SimProfile).
static var rays_cast := 0


static func usable() -> bool:
	var ok := BrainSwitches.native and BrainSwitches.native_perception and configure()
	if ok and NativeBridge.counting:
		NativeBridge.took("perception")
	return ok


static func configure() -> bool:
	if _configured:
		return _ok
	_configured = true
	if not NativeBridge.available:
		return false
	_ok = NativeBridge.impl.perception_configure({"EYE_HEIGHT": Perception.EYE_HEIGHT, "WORLD_MASK": Perception.WORLD_MASK})
	return _ok


## For each enemy: -2 dead, -1 seen by none, else the index of the first viewer that sees it.
static func sight(viewers: Array[Tank], enemies: Array[Tank]) -> PackedInt32Array:
	var out: PackedInt32Array = NativeBridge.impl.perception_sight(viewers, enemies)
	rays_cast += int(NativeBridge.impl.perception_rays())
	return out


## For each viewer: 1 when it is alive, ready to fire and has an enemy in range on a clear line.
static func gun_ready(viewers: Array[Tank], enemies: Array[Tank]) -> PackedByteArray:
	var out: PackedByteArray = NativeBridge.impl.perception_gun_ready(viewers, enemies)
	rays_cast += int(NativeBridge.impl.perception_rays())
	return out

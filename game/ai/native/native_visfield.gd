class_name NativeVisfield
extends RefCounted
## Round 48 (native, R48.8): VisibilityField.look_from's ray fan natively (native/src/visfield_native.cpp). His laptop at the cost cap
## (lock held, Crossing seed 101, stream/native 4c01aa748, --native-tick-profile 8-40 s): visfield 0.466 ms a tick, rays 0.376 of it,
## ~1.1 ms a frame. Seam: look_from asks for VisibilityField._rays; its GDScript stays the reference (tests/test_native_visfield.gd).
## BrainSwitches.native_visfield.

## TANK_NATIVE_VISFIELD_VERIFY=1 (env): every native fan is also cast in GDScript and compared (byte for byte); a mismatch prints
## "NativeVisfield verify mismatch ..." and every VERIFY_EVERY calls a "NATIVE_VISFIELD verified N, M mismatches" line. Runs the
## C++ even while native_visfield is OFF.
static var verify := OS.get_environment("TANK_NATIVE_VISFIELD_VERIFY") == "1"
static var verified := 0
static var mismatches := 0
const VERIFY_EVERY := 500


static func usable() -> bool:
	var ok := BrainSwitches.native and (BrainSwitches.native_visfield or verify) and NativeBridge.available
	if ok and NativeBridge.counting:
		NativeBridge.took("visfield")
	return ok


static func rays(field: VisibilityField, viewer: Node3D, eye: Vector3, radius: float, directions: PackedVector3Array,
		space: PhysicsDirectSpaceState3D) -> Array:
	var out: Array = NativeBridge.impl.visfield_rays(viewer, eye, radius, directions, Perception.eye_mask())
	if out.size() != 2:
		return field._rays(eye, radius, directions, space)
	if verify:
		verified += 1
		var live := field._rays(eye, radius, directions, space)
		if var_to_bytes(live) != var_to_bytes(out):
			mismatches += 1
			print("NativeVisfield verify mismatch %s eye %s radius %s: live %s native %s" % [viewer.name, eye, radius,
					var_to_str(live).left(400), var_to_str(out).left(400)])
		if verified % VERIFY_EVERY == 0:
			print("NATIVE_VISFIELD verified %d, %d mismatches" % [verified, mismatches])
	return out

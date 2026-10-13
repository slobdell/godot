class_name NativeHold
extends RefCounted
## Round 29 (native, C29.2 scaffold for traffic's T1): the street hold as a record the native execute reads
## (native/src/hold_native.h). Traffic writes a crew's hold here when it starts (`hold`) and when it ends (`release`);
## until T1's hold is ported into the drive, the native execute hands a holding crew back to the GDScript (counted as
## "holding") and the native drive's seam steps aside for it, so the hold runs as traffic wrote it. Nothing writes a hold
## yet: with the table empty the execute and the drive are what they were (tests/test_native_hold.gd).

## Holds written and not released, so the drive's seam asks the library only while a street meeting holds someone.
static var _held := 0


## The crew (its Movement) holds at `spot` from `since` (match seconds).
static func hold(mover: Movement, spot: Vector3, since: float) -> void:
	if NativeBridge.available and mover != null:
		NativeBridge.impl.hold_set(mover, spot, since)
		_held = NativeBridge.impl.hold_count()


static func release(mover: Movement) -> void:
	if NativeBridge.available and mover != null and _held > 0:
		NativeBridge.impl.hold_clear(mover)
		_held = NativeBridge.impl.hold_count()


static func release_all() -> void:
	if NativeBridge.available:
		NativeBridge.impl.hold_clear_all()
	_held = 0


static func holding(mover: Movement) -> bool:
	return _held > 0 and NativeBridge.impl.hold_has(mover)


## [spot, since] or null.
static func of(mover: Movement) -> Variant:
	return NativeBridge.impl.hold_of(mover) if NativeBridge.available and _held > 0 else null

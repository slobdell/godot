class_name HudClock
extends RefCounted
## Round 16 (hud H1): what each HUD widget's `_process` and `_draw` cost, by counter rather than by removal. Every
## per-frame entry point of the HUD wraps its body in `begin()`/`end(key)`; while `on` is false (always, except under
## `make hud-profile`) that is one static call and a bool test. `changed(key)` counts how often a widget's drawn state
## actually differed from the frame before (the dirty flags of H3 report it), so redraws can be compared with changes.

static var on := false
static var usec := {}
static var calls := {}
static var changes := {}


static func begin() -> int:
	return Time.get_ticks_usec() if on else 0


static func end(key: StringName, started: int) -> void:
	if not on:
		return
	usec[key] = int(usec.get(key, 0)) + Time.get_ticks_usec() - started
	calls[key] = int(calls.get(key, 0)) + 1


static func changed(key: StringName) -> void:
	if on:
		changes[key] = int(changes.get(key, 0)) + 1


## The yardstick (tests/support/control_fixture.gd's `reference_work`, the same work): timed beside the HUD each frame
## of a profile, so a cost can be read as a multiple of it and compared across a loaded and a quiet machine.
static func reference_work() -> void:
	var seen := {}
	for i in 600:
		seen[i % 64] = Vector3(float(i), 0.0, -float(i)).length() + float(i)


static func reset() -> void:
	usec.clear()
	calls.clear()
	changes.clear()


## {key: {calls, usec, usec_per_call, changes}} sorted by total cost, heaviest first.
static func report() -> Array:
	var rows: Array = []
	for key: StringName in usec:
		var count := int(calls.get(key, 0))
		rows.append({"key": String(key), "calls": count, "usec": int(usec[key]),
				"usec_per_call": snappedf(float(usec[key]) / maxf(1.0, count), 0.1), "changes": int(changes.get(key, -1))})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["usec"]) > int(b["usec"]))
	return rows

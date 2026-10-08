class_name NativeBridge
extends RefCounted
## Round 23 (native): the one place that says whether the native library (native/, C++ through godot-cpp) is loaded,
## and holds the instance the ported seams call. `_agents/native.md`.
##
## The library is ON when `make native` has written native/bin/tank_squad.gdextension beside its .so and the import
## registered it (ClassDB then has TankNative); OFF when the file is absent (NATIVE=off, the web build, a machine
## without a C++ toolchain). The seams read `BrainSwitches.native`, which is this availability AND the round's switch
## (`--brains-off=native`, the in-run A/B), so one flag runs either path and the match hash is the proof.
##
## `impl` is an Object, called dynamically (`impl.closest_approach(...)`): the class name cannot appear in GDScript,
## which would not parse without the library. That dynamic call is the per-call price N0 measures.

const CLASS_NAME := "TankNative"
const GDEXTENSION_PATH := "res://native/bin/tank_squad.gdextension"

static var available: bool = ClassDB.class_exists(CLASS_NAME)
static var impl: Object = ClassDB.instantiate(CLASS_NAME) if available else null


## The library's build_info() ("godot-cpp ... | gcc ... | flags | built on <host> | real_t 32 bits"), or why it is off.
static func describe() -> String:
	if available:
		return str(impl.build_info())
	if FileAccess.file_exists(GDEXTENSION_PATH):
		return "OFF: %s exists but ClassDB has no %s (the library did not load; see the engine log)" % [GDEXTENSION_PATH, CLASS_NAME]
	return "OFF: no %s (make native builds it)" % GDEXTENSION_PATH

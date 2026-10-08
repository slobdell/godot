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
## Where `make native` writes the .gdextension, relative to the project (no `res://` literal here on purpose: Godot
## loads the file, not this script, and tools/web_pack/export_guard.py would otherwise count it as a file the game
## reaches for and find it, rightly, in no pack).
const GDEXTENSION_FILE := "native/bin/tank_squad.gdextension"

static var available: bool = ClassDB.class_exists(CLASS_NAME)
static var impl: Object = ClassDB.instantiate(CLASS_NAME) if available else null


## The library's build_info() ("godot-cpp ... | gcc ... | flags | built on <host> | real_t 32 bits"), or why it is off.
static func describe() -> String:
	if available:
		return str(impl.build_info())
	if FileAccess.file_exists(ProjectSettings.globalize_path("res://").path_join(GDEXTENSION_FILE)):
		return "OFF: %s exists but ClassDB has no %s (the library did not load; see the engine log)" % [GDEXTENSION_FILE, CLASS_NAME]
	return "OFF: no %s (make native builds it)" % GDEXTENSION_FILE

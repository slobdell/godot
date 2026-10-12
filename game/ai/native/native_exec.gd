class_name NativeExec
extends RefCounted
## Round 27 (native, stage 1): the execute step's state owned by the C++ (native/src/exec_state.h). E1: the field table,
## pull and push, proven field by field (tests/test_native_exec_state.gd) and, over a whole match, by the mirror below.
##
## `--native-exec-mirror` (measurement only, native-proof's `mirror` arm): at the top of every crew's
## `OrderController.compute_command` the C++ pulls every member of its Movement, Gunnery and Lay, overwrites every one of
## them with a different value, and pushes the struct back. The match must hash as one run without it: push is lossless.

static var mirror := NativeBridge.available and OS.get_cmdline_user_args().has("--native-exec-mirror")


## E5: can this crew's execute step go native this tick? (The library, the switches, the drive's default configuration,
## the gun configured.) The native call itself still hands back (NIL) anything off the common path.
static func usable(ctl: OrderController) -> bool:
	return BrainSwitches.native and BrainSwitches.native_exec and ctl.tank.alive \
			and NativeDrive.usable(ctl.movement) and NativeGun.configure()


## E5b: `--native-exec-verify` (with `--native-exec-owned`): before every owned execute the C++ reads the members afresh
## and compares them with the state it owns (a door into the state that does not set `native_stale` shows up here).
## The environment's TANK_NATIVE_EXEC_VERIFY=1 does the same for every Godot a make target starts (`make native-verify-suite`:
## the whole suite and the AI scenarios with every owned execute verified; a mismatch is an engine ERROR, so it fails).
static var verify := OS.get_cmdline_user_args().has("--native-exec-verify") \
		or OS.get_environment("TANK_NATIVE_EXEC_VERIFY") == "1"
const EXEC_LIVE := 0
const EXEC_OWNED := 1
const EXEC_OWNED_VERIFY := 2
const REPORT_EVERY := 20000
static var _executes := 0


## Measurement only: `--native-exec-profile` prints NATIVE_EXEC_PROFILE (us an execute in each part of the native
## execute, execute_native.cpp's clocks, and the drive's callbacks through --native-drive-profile's) every REPORT_EVERY.
static var profile := OS.get_cmdline_user_args().has("--native-exec-profile")
static var _profile_set := false


## The crew's command for this tick natively, or null (the GDScript compute_command runs).
static func execute(ctl: OrderController, delta: float) -> Variant:
	if profile:
		if not _profile_set:
			_profile_set = true
			NativeBridge.impl.execute_profile_on(true)
		if (_executes + 1) % REPORT_EVERY == 0:
			var p: Dictionary = NativeBridge.impl.execute_profile(false)
			var n := maxi(int(p["executes"]), 1)
			var parts := []
			for key: String in p:
				if key != "executes":
					parts.append("%s %.2f" % [key, float(p[key]) / n])
			print("NATIVE_EXEC_PROFILE %d executes, usec an execute: %s" % [n, ", ".join(parts)])
			var d: Dictionary = NativeBridge.impl.drive_profile(false)
			var dparts := []
			for key: String in d:
				if key != "drives":
					dparts.append("%s %.2f" % [key, float(d[key]) / maxi(int(d["drives"]), 1)])
			print("NATIVE_EXEC_DRIVE %d drives, usec a drive: %s" % [int(d["drives"]), ", ".join(dparts)])
	var mode := (EXEC_OWNED_VERIFY if verify else EXEC_OWNED) if NativeDrive.owned or BrainSwitches.native_owned \
			else EXEC_LIVE
	_executes += 1
	if mode != EXEC_LIVE and _executes % REPORT_EVERY == 0:
		var c: Dictionary = NativeBridge.impl.execute_counts(false)
		print("NATIVE_EXEC %d native, %d handed back (dead %d, reflexes %d, yielding %d, face %d, drive %d, other %d), %d stale pulls, %d part pulls, %d verified, %d verify mismatches %s" % [
				int(c["native"]), int(c["handed_back"]), int(c["dead"]), int(c["reflexes"]), int(c["yielding"]),
				int(c["face"]), int(c["drive"]), int(c["other_order"]), int(c["stale_pulls"]), int(c["part_pulls"]), int(c["verified"]),
				int(c["verify_mismatches"]), c["first_mismatch"]])
	return NativeBridge.impl.execute(ctl, delta, mode)
## Measurement: crews mirrored, members scrambled (a mirror that scrambled nothing proves nothing).
static var mirrored := 0
static var scrambled := 0


static func mirror_one(mover: Movement) -> void:
	var changed: int = NativeBridge.impl.exec_mirror(mover)
	if changed < 0:
		push_error("NativeExec: a member of %s did not have its declared type" % mover.ctl.tank.name)
		return
	mirrored += 1
	scrambled += changed
	if mirrored % 5000 == 0:
		print("NATIVE_EXEC_MIRROR %d crews mirrored, %d members scrambled" % [mirrored, scrambled])

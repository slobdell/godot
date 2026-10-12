class_name NativeExec
extends RefCounted
## Round 27 (native, stage 1): the execute step's state owned by the C++ (native/src/exec_state.h). E1: the field table,
## pull and push, proven field by field (tests/test_native_exec_state.gd) and, over a whole match, by the mirror below.
##
## `--native-exec-mirror` (measurement only, native-proof's `mirror` arm): at the top of every crew's
## `OrderController.compute_command` the C++ pulls every member of its Movement, Gunnery and Lay, overwrites every one of
## them with a different value, and pushes the struct back. The match must hash as one run without it: push is lossless.

static var mirror := NativeBridge.available and OS.get_cmdline_user_args().has("--native-exec-mirror")
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

class_name NativeExpect
extends RefCounted
## Round 34 (native N4, the library refusal the rest of the way): a twin with no library returns early ("native:
## absent") and passes without comparing anything. `make test` refuses that up front for its own FILTERs (core.mk
## `_native-ready`), but not for a FILTER that matches a twin without saying "native", a shard, or another recipe's
## run_tests.gd call. So every twin asks here instead of reading NativeBridge.available: make exports
## TANK_NATIVE_EXPECTED=1 when NATIVE is on and the machine has a C++ toolchain (mk/native.mk), and an absent library
## then FAILS the twin. With NATIVE=off, or on a machine without a toolchain (the web build's case), it stays a skip.


## True when the library is absent (the caller returns early); a failure on `test` when make expected one.
static func absent(test: TestCase) -> bool:
	if NativeBridge.available:
		return false
	if expected():
		test.failures.append(("native: the library is expected (make ran with NATIVE on and a C++ toolchain) but absent "
				+ "(%s), so this twin would pass without running. Build it (make native), or run with NATIVE=off on purpose.")
				% NativeBridge.GDEXTENSION_FILE)
	return true


static func expected() -> bool:
	return OS.get_environment("TANK_NATIVE_EXPECTED") == "1"

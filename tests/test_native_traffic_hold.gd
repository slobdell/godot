extends TestCase
## Round 29 (native, C29.2: traffic's T1 street hold, the pair). His Terminus head-on case through traffic's own stage;
## the harness is TrafficTwin (tests/native/traffic_twin.gd). Round 31 (C31.9): split from one file (486 s, the
## shard plan's floor): this file is the native drive on the live members; `_owned` on the C++-owned state.
## The hold must fire: crews reach their spots and hold there (lesson 300).

var _saved_native := false


func teardown() -> void:
	BrainSwitches.native = _saved_native
	BrainSwitches.native_drive = true
	NativeDrive.owned = false
	Traffic.set_off("hold", false)
	super.teardown()


func test_the_street_hold_drives_as_the_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the hold's drive equality is not exercised in this run")
		return
	if NativeTraffic.drive_config().is_empty():
		print("native: this tree's Traffic has no street hold (traffic T1 not merged): nothing to compare")
		return
	_saved_native = BrainSwitches.native
	Traffic.set_off("hold", false)
	var acc: Dictionary = await TrafficTwin.run(self, false, "terminus", "head", 30.0)
	var report: Dictionary = acc["report"]
	print("native traffic hold: %d drives compared (%d holding: %d at the spot, %d approaching), %d unsticks (%d holding), %d mismatches; the stage: %s" % [
			acc["drives"], acc["held"], acc["at_spot"], acc["approach"], acc["unsticks"], acc["held_unsticks"],
			acc["mismatches"], report])
	assert_eq(int(acc["mismatches"]), 0, "the native drive holds as the GDScript: %s" % acc["first"])
	assert_true(int(acc["drives"]) >= 2000, "a real sample (%d drives)" % acc["drives"])
	assert_true(int(acc["at_spot"]) >= 30 and int(acc["approach"]) >= 30, "the hold fired both ways: at the spot %d, approaching %d" % [
			acc["at_spot"], acc["approach"]])
	assert_true(int(acc["held_unsticks"]) >= 5, "a holding crew's unstick was compared (%d)" % acc["held_unsticks"])
	assert_true(int(report["tr_holds"]) > 0, "the stage held a squad: %s" % report)

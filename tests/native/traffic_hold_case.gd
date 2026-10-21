class_name TrafficHoldCase
extends TestCase
## Round 29 (native, C29.2: traffic's T1 street hold, the pair). His Terminus head-on case through traffic's own stage;
## the harness is TrafficTwin (tests/native/traffic_twin.gd). The hold must fire: crews reach their spots and hold there
## (lesson 300). Round 31 (C31.9) split it live / owned; round 32 (C32.8) splits each by crew (even, odd): four files,
## test_native_traffic_hold{,_odd,_owned,_owned_odd}, each the whole stage with half the crews compared. This base holds
## the case (the round-31 body, but for the crew split and the sample floor divided by it).

var _saved_native := false


func teardown() -> void:
	BrainSwitches.native = _saved_native
	BrainSwitches.native_drive = true
	NativeDrive.owned = false
	Traffic.set_off("hold", false)
	super.teardown()


## `owned`: the native arm on the C++-owned state; only the crews at `part` mod `parts` are compared (TrafficTwin.run).
func _hold_case(owned: bool, part: int, parts: int) -> void:
	if NativeExpect.absent(self):
		print("native: absent, the hold's drive equality is not exercised in this run")
		return
	if NativeTraffic.drive_config().is_empty():
		print("native: this tree's Traffic has no street hold (traffic T1 not merged): nothing to compare")
		return
	_saved_native = BrainSwitches.native
	Traffic.set_off("hold", false)
	var intent := (Manoeuvre as Script).get_script_constant_map().has("STALL_INTENT_DEFAULT")  # round 35 (W1c)
	var intent_before: int = Manoeuvre.stall_intent_ticks if intent else 0
	var acc: Dictionary = await TrafficTwin.run(self, owned, "terminus", "head", 30.0, part, parts)
	var report: Dictionary = acc["report"]
	if intent:
		print("native traffic hold%s, crews %d/%d: stall intent ticks (the stage's own drives) %d (STALL_INTENT_DEFAULT %s)" % [
				" (owned state)" if owned else "", part, parts, Manoeuvre.stall_intent_ticks - intent_before, Manoeuvre.STALL_INTENT_DEFAULT])
	print("native traffic hold%s, crews %d/%d: %d drives compared (%d holding: %d at the spot, %d approaching), %d unsticks (%d holding), %d mismatches; the stage: %s" % [
			" (owned state)" if owned else "", part, parts, acc["drives"], acc["held"], acc["at_spot"], acc["approach"], acc["unsticks"], acc["held_unsticks"],
			acc["mismatches"], report])
	assert_eq(int(acc["mismatches"]), 0, "the native drive holds as the GDScript: %s" % acc["first"])
	assert_true(int(acc["drives"]) * parts >= 2000, "a real sample (%d drives; 2000 over every crew)" % acc["drives"])
	assert_true(int(acc["at_spot"]) >= 30 and int(acc["approach"]) >= 30, "the hold fired both ways: at the spot %d, approaching %d" % [
			acc["at_spot"], acc["approach"]])
	assert_true(int(acc["held_unsticks"]) >= 5, "a holding crew's unstick was compared (%d)" % acc["held_unsticks"])
	assert_true(int(report["tr_holds"]) > 0, "the stage held a squad: %s" % report)

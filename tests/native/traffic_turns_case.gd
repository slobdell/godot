class_name TrafficTurnsCase
extends TestCase
## Round 31 (native, C31.2: traffic's T3b crossing, the pair). His Terminus crossing through traffic's own stage (the
## avenue against the ring road): the two squads meet, one squad pair's verdict, the yielding squad's wish slowed by
## Traffic.shape. The harness is TrafficTwin (tests/native/traffic_twin.gd): every crew's drive, GDScript then native from
## one snapshot, equal bit for bit (command, every mover, every Traffic static). The rule must fire on the compared
## drives (lesson 300). Round 32 (C32.8, after T3b-c shipped ON): split live / owned and by crew (even, odd), four files
## test_native_traffic_turns{,_odd,_owned,_owned_odd}; this base holds the case (the round-31 body, but for the crew
## split and the sample floor divided by it).

var _saved_native := false


func teardown() -> void:
	BrainSwitches.native = _saved_native
	BrainSwitches.native_drive = true
	NativeDrive.owned = false
	Traffic.set_off("turns", TrafficTwin.default_off("turns"))
	super.teardown()


## `owned`: the native arm on the C++-owned state; only the crews at `part` mod `parts` are compared (TrafficTwin.run).
func _turns_case(owned: bool, part: int, parts: int) -> void:
	if not NativeBridge.available:
		print("native: absent, the crossing's drive equality is not exercised in this run")
		return
	if not bool(NativeTraffic.drive_config().get("traffic_shape", false)):
		print("native: this tree's Traffic has no crossing (Traffic.shape, traffic T3b not merged): nothing to compare")
		return
	_saved_native = BrainSwitches.native
	Traffic.set_off("turns", false)
	var acc: Dictionary = await TrafficTwin.run(self, owned, "terminus", "cross", 20.0, part, parts)  # the squads meet in the first ~15 s; 20 s keeps the test off the shard floor (C31.9)
	var report: Dictionary = acc["report"]
	print("native traffic turns%s, crews %d/%d: %d drives compared (%d shaped), %d unsticks, %d mismatches; the stage: %s" % [
			" (owned state)" if owned else "", part, parts, acc["drives"], acc["shaped"], acc["unsticks"], acc["mismatches"], report])
	assert_eq(int(acc["mismatches"]), 0, "the native drive crosses as the GDScript: %s" % acc["first"])
	assert_true(int(acc["drives"]) * parts >= 2000, "a real sample (%d drives; 2000 over every crew)" % acc["drives"])
	assert_true(int(acc["shaped"]) >= 30, "the crossing slowed a wish on the compared drives (%d)" % acc["shaped"])
	assert_true(int(report["tr_cross_verdicts"]) > 0, "the stage made a squad-pair verdict: %s" % report)

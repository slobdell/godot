extends TestCase
## Round 31 (brains B8, CP-H consumer, `--brains-off=realslow` opt-in): the re-seat / make-room clock's "slow" reading
## on the honest speed (Element.reads_slow). The case is manoeuvre's round-30 pair-check trace (`test_tactics_mixed_legs`,
## Sumps causeway): an 8x8 21.5 m from its slot at plant 0.86 m/s, real 0.00, re-seats 0 for the rest of the run.


## The switch as the run had it (a scratch tree flips the default ON): restored after each test, never forced off.
var _was := BrainSwitches.realslow


func teardown() -> void:
	BrainSwitches.realslow = _was


func test_off_is_the_plant_reading_as_before() -> void:
	BrainSwitches.realslow = false
	assert_true(Element.reads_slow(Vector3(0.86, 0, 0), Vector3.ZERO), "off: plant 0.86 under STUCK_MPS reads slow (the trace)")
	assert_true(not Element.reads_slow(Vector3(3, 0, 0), Vector3.ZERO), "off: plant 3 reads driving whatever the real motion")
	assert_true(Element.reads_slow(Vector3(0.2, 0, 0), Vector3(5, 0, 0)), "off: the real speed is not read")


func test_on_a_hull_driven_that_goes_nowhere_is_stuck_not_waiting() -> void:
	BrainSwitches.realslow = true
	assert_true(not Element.reads_slow(Vector3(0.86, 0, 0), Vector3.ZERO),
			"on: the trace's stranded 8x8 (plant 0.86, real 0.00) is driving without closing: its clock runs")
	assert_true(not Element.reads_slow(Vector3(3, 0, 0), Vector3(0.1, 0, 0)), "on: grinding at plant 3, real 0.1: stuck")


func test_on_a_crew_that_waits_or_drives_reads_as_before() -> void:
	BrainSwitches.realslow = true
	assert_true(Element.reads_slow(Vector3(0.2, 0, 0), Vector3(0.2, 0, 0)), "on: creeping for real at 0.2: waiting")
	assert_true(Element.reads_slow(Vector3.ZERO, Vector3.ZERO), "on: stopped: waiting")
	assert_true(not Element.reads_slow(Vector3(5, 0, 0), Vector3(5, 0, 0)), "on: driving at 5: driving")
	assert_true(Element.reads_slow(Vector3(0.6, 3, 0), Vector3(0.6, 0, 0)), "on: flat speeds only (a hull on a slope)")


func test_naming_the_switch_turns_it_on_and_all_never_does() -> void:
	BrainSwitches.realslow = false
	assert_true(not BrainSwitches.NAMES.has("realslow"), "not in NAMES: set_all (--brains-off=all, ai-parity's proof) never turns it on")
	BrainSwitches.apply_args(PackedStringArray(["--brains-off=realslow"]))
	assert_true(BrainSwitches.realslow, "--brains-off=realslow turns it ON (R31.1)")

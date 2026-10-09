extends TestCase
## Round 23 (native, N0): the native library (native/, C++ through godot-cpp) behind BrainSwitches.native. The suite
## passes BOTH WAYS (`make check` builds the .so; `make check NATIVE=off` runs without it, the web build's case) and
## says which way it ran: the NATIVE line below. With the library: every ported seam gives the GDScript's answer BIT
## FOR BIT over seeded inputs (`==`, never approx) -- the unit half of the proof whose other half is the match hash
## (`make native-proof`, `make ai-ab-match AB_SWITCH=native`, the thirteen lines; _agents/native.md).

const SAMPLES := 4000
const GDEXTENSION_PATH := "res://native/bin/tank_squad.gdextension"


func test_the_bridge_says_which_way_this_run_goes() -> void:
	print("NATIVE %s | switch %s" % [NativeBridge.describe(), "on" if BrainSwitches.native else "off"])
	assert_eq(GDEXTENSION_PATH, "res://" + NativeBridge.GDEXTENSION_FILE, "the bridge names the file make native writes")
	if FileAccess.file_exists(GDEXTENSION_PATH):
		assert_true(NativeBridge.available, "%s exists, so the library must have loaded (ClassDB has %s); a load failure is red, not a silent OFF"
				% [GDEXTENSION_PATH, NativeBridge.CLASS_NAME])
	else:
		assert_true(not NativeBridge.available, "without %s nothing is loaded" % GDEXTENSION_PATH)
	assert_eq(ClassDB.class_exists(NativeBridge.CLASS_NAME), NativeBridge.available, "available = ClassDB has the class")
	assert_eq(NativeBridge.impl != null, NativeBridge.available, "impl exists exactly when available")
	assert_true(BrainSwitches.NAMES.has("native"), "the switch is a BrainSwitches name (--brains-off=native, the in-run A/B)")


func test_the_switch_never_routes_to_a_missing_library() -> void:
	# Every switch is restored at the end (round 24: set_all(true) below used to leave the OFF-shipping native switches
	# ON for the rest of the shard, so a later test could pass or fail by its shard).
	var saved := {}
	for name in BrainSwitches.NAMES:
		saved[name] = _switch(name)
	var before := BrainSwitches.native
	BrainSwitches.set_named("native", true)
	assert_eq(BrainSwitches.native, NativeBridge.available, "set_named(native, true) is masked by availability (set_all(true) on a machine without the .so)")
	BrainSwitches.set_named("native", false)
	assert_eq(BrainSwitches.native, false, "and off is off")
	BrainSwitches.set_all(true)
	assert_eq(BrainSwitches.native, NativeBridge.available, "set_all(true) too")
	BrainSwitches.native = before
	for name: String in saved:
		BrainSwitches.set_named(name, saved[name])
	assert_eq(BrainSwitches.native, before, "native restored")


## A switch's current value (BrainSwitches' statics, read through the script).
func _switch(name: String) -> bool:
	return bool((BrainSwitches as Script).get(name))


func test_closest_approach_is_the_gdscript_bit_for_bit() -> void:
	if not NativeBridge.available:
		print("native: absent, the closest_approach equality is not exercised in this run")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 2023
	var impl: Object = NativeBridge.impl
	var before := BrainSwitches.native
	var mismatches := 0
	var first := ""
	for i in SAMPLES:
		var scale: float = [1.0, 50.0, 400.0, 5000.0][i % 4]
		var here := Vector3(rng.randf_range(-scale, scale), rng.randf_range(-3.0, 3.0), rng.randf_range(-scale, scale))
		var velocity := Vector3(rng.randf_range(-40.0, 40.0), 0.0, rng.randf_range(-40.0, 40.0))
		var round_position := Vector3(rng.randf_range(-scale, scale), rng.randf_range(0.0, 4.0), rng.randf_range(-scale, scale))
		var round_velocity := Vector3(rng.randf_range(-120.0, 120.0), rng.randf_range(-5.0, 5.0), rng.randf_range(-120.0, 120.0))
		var seconds := rng.randf_range(0.0, 3.0)
		match i % 13:
			0:  # no relative motion: the speed_squared < 1e-6 branch
				round_velocity = velocity
			1:  # a hair of relative motion, either side of the 1e-6 test
				round_velocity = velocity + Vector3(rng.randf_range(-0.002, 0.002), 0.0, rng.randf_range(-0.002, 0.002))
			2:  # the clamp's far end: the closest point lies past `seconds`
				round_velocity = velocity + Vector3(0.0, 0.0, 0.001)
				seconds = 0.01
			3:  # the clamp's near end: driving apart
				round_velocity = velocity * 2.0
			4:  # the round's position step as combat_motion.gd:1069 forms it (position + velocity * t)
				round_position = round_position + round_velocity * rng.randf_range(0.0, 2.0)
			5:
				seconds = 0.0
		var ours := IncomingFire.closest_approach(here, velocity, round_position, round_velocity, seconds)  # native (the switch is on)
		BrainSwitches.native = false
		var reference := IncomingFire.closest_approach(here, velocity, round_position, round_velocity, seconds)
		BrainSwitches.native = true
		var direct: float = impl.closest_approach(here, velocity, round_position, round_velocity, seconds)
		if ours != reference or direct != reference or var_to_bytes(ours) != var_to_bytes(reference):
			mismatches += 1
			if first == "":
				first = "sample %d: native %s (%s) vs gdscript %s for here=%s velocity=%s round=%s rv=%s seconds=%s" % [
						i, ours, direct, reference, here, velocity, round_position, round_velocity, seconds]
	BrainSwitches.native = before
	print("MEASURE native closest_approach %d samples, %d mismatches" % [SAMPLES, mismatches])
	assert_eq(mismatches, 0, "every sample equal bit for bit; first mismatch: %s" % first)


func test_closest_approach_known_answers() -> void:
	# The GDScript's answers on paper, both ways (with the library these go through C++).
	for on in ([true, false] if NativeBridge.available else [false]):
		BrainSwitches.native = on
		assert_eq(IncomingFire.closest_approach(Vector3.ZERO, Vector3.ZERO, Vector3(3.0, 0.0, 4.0), Vector3.ZERO, 1.0), 5.0,
				"no motion: the distance now (native %s)" % on)
		assert_eq(IncomingFire.closest_approach(Vector3.ZERO, Vector3.ZERO, Vector3(0.0, 0.0, 10.0), Vector3(0.0, 0.0, -10.0), 2.0), 0.0,
				"a round driving straight through the hull meets it at t=1 (native %s)" % on)
		assert_eq(IncomingFire.closest_approach(Vector3.ZERO, Vector3.ZERO, Vector3(0.0, 0.0, 10.0), Vector3(0.0, 0.0, -10.0), 0.5), 5.0,
				"within half a second it gets to 5 m (the clamp) (native %s)" % on)
		assert_eq(IncomingFire.closest_approach(Vector3.ZERO, Vector3.ZERO, Vector3(0.0, 7.0, 10.0), Vector3(0.0, 0.0, -10.0), 2.0), 0.0,
				"height is ignored: flat geometry (native %s)" % on)
	BrainSwitches.native = NativeBridge.available

extends TestCase
## Round 47 (native, R47.36, mapkit P3's request): the C++ eye rays ask Perception.eye_mask() (eye_mask.h: WORLD_MASK | the sight
## layer while ArenaKit.sight_on), so a sight screen blinds native eyes as it blinds the GDScript's. On mapkit's screen fixture
## (tests/mapkit/test_sight_screens.gd's layout: foundry's strip cleared, two screens), random eye pairs around both screens, the
## switch on and off: the native line of sight (TankNative.line_of_sight, the perception pass's and the gun's same mask) must be
## Perception.has_line_of_sight's, and some pairs must be blinded by a screen (on) and clear (off).

const SightScreens := preload("res://tests/mapkit/test_sight_screens.gd")


func teardown() -> void:
	ArenaKit.sight_on = true
	super.teardown()


func test_native_eyes_see_what_the_gdscript_eyes_see() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the eye mask equality is not exercised in this run")
		return
	var fixture: Object = SightScreens.new()
	var layout: Dictionary = fixture.call("_layout")
	if fixture is Node:
		(fixture as Node).free()
	var arena := await ArenaFixture.build_layout(self, layout)
	await wait_physics_frames(2)
	var a := Node3D.new()
	var b := Node3D.new()
	arena.add_child(a)
	arena.add_child(b)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4736
	var compared := 0
	var mismatches := 0
	var blinded_on := 0
	var first := ""
	var space := arena.get_world_3d().space
	for trial in 400:
		ArenaKit.sight_on = trial % 4 != 3
		var side := 1.0 if trial % 2 == 0 else -1.0
		a.global_position = Vector3(rng.randf_range(-25.0, 25.0), 0.0, side * 20.0 + rng.randf_range(4.0, 25.0))
		b.global_position = Vector3(rng.randf_range(-25.0, 25.0), 0.0, side * 20.0 - rng.randf_range(4.0, 25.0))
		if trial % 50 == 0:
			await wait_physics_frames(1)
		var live := Perception.has_line_of_sight(a, b)
		var native: bool = NativeBridge.impl.line_of_sight(space, a.global_position, b.global_position)
		compared += 1
		if ArenaKit.sight_on and not live:
			blinded_on += 1
		if live != native:
			mismatches += 1
			if first == "":
				first = "trial %d sight_on %s %s -> %s: live %s native %s" % [trial, ArenaKit.sight_on, a.global_position,
						b.global_position, live, native]
	print("MEASURE native_eye_mask compared=%d mismatches=%d blinded=%d" % [compared, mismatches, blinded_on])
	assert_eq(mismatches, 0, "the native eye = Perception.has_line_of_sight (%d); first: %s" % [compared, first])
	assert_true(blinded_on >= 20, "the screens blinded some looks with the class on (%d)" % blinded_on)

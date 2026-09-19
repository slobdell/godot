extends TestCase
## Round 6 (the lead: "I'm not seeing any cool machine gun fire from the scouts"): a machine gun's stream of rounds must
## be visible as a stream, several tracers in the air at once, not one dash at a time.


func test_a_scouts_stream_keeps_several_tracers_in_the_air() -> void:
	var weapon := Weapons.profile("machine_gun")
	var rate := 1.0 / float(weapon.get("reload_s", weapon.get("reload", 0.1)))
	var style: Dictionary = TracerSystem.STYLES["stream"]
	var speed := float(style.get("speed", TracerSystem.HITSCAN_SPEED))
	var in_air := rate * 26.0 / speed  # rounds in flight at the showcase's 26 m
	assert_true(in_air >= 2.5, "%.1f rounds in the air at 26 m (at %.0f m/s): a stream, not a dash" % [in_air, speed])
	assert_true(float(style["tail"]) >= 6.0 and float(style["width"]) >= 0.25, "tracers long and wide enough to read from the RTS camera")


func test_a_stream_round_flies_at_its_own_speed() -> void:
	var tracers := TracerSystem.new()
	add_to_tree(tracers)
	var index := tracers.shoot(Vector3.ZERO, Vector3(0, 0, -30), Color.WHITE, "stream", 0.0)
	var head := tracers.round_head(index, 0.1)
	assert_near(head.length(), float(TracerSystem.STYLES["stream"]["speed"]) * 0.1, 0.01, "the stream's own speed")
	var other := tracers.shoot(Vector3.ZERO, Vector3(0, 0, -30), Color.WHITE, "burst", 0.0)
	assert_near(tracers.round_head(other, 0.1).length(), TracerSystem.HITSCAN_SPEED * 0.1, 0.01, "other styles unchanged")

extends TestCase
## Round 24 (native): the instruments that re-take the laptop's windowed in-contact table (`make native-tick-profile`):
## `--native-tick-profile=A,B` (TickProfile) and `--brains-on=` (BrainSwitches.apply_args, for arms that turn on a seam
## shipped OFF). Measurement only: neither may change a fight, so a profiled match's hash is checked against an
## unprofiled one elsewhere (the windowed arms run with it); here: the parsing, and that a profile over a short window
## of a real match reports its parts.

const MATCH := preload("res://game/match/match.tscn")


func test_the_window_is_parsed() -> void:
	assert_eq(TickProfile.parse_window(PackedStringArray(["--native-tick-profile=8,20"])), Vector2(8.0, 20.0), "A,B")
	assert_eq(TickProfile.parse_window(PackedStringArray(["--x", "--native-tick-profile=0.5,1.5"])), Vector2(0.5, 1.5),
			"fractions, among other arguments")
	assert_eq(TickProfile.parse_window(PackedStringArray(["--native-tick-profile=8"])), Vector2(-1.0, -1.0), "malformed: off")
	assert_eq(TickProfile.parse_window(PackedStringArray()), Vector2(-1.0, -1.0), "absent: off")


func test_brains_on_turns_a_shipped_off_switch_on_and_off_still_wins() -> void:
	var saved := [BrainSwitches.native_situation, BrainSwitches.native_matchups, BrainSwitches.native_drive]
	BrainSwitches.native_situation = false
	BrainSwitches.native_matchups = false
	BrainSwitches.apply_args(PackedStringArray(["--brains-on=native_situation,native_matchups"]))
	assert_true(BrainSwitches.native_situation and BrainSwitches.native_matchups, "--brains-on turns them on")
	BrainSwitches.apply_args(PackedStringArray(["--brains-on=native_situation", "--brains-off=native_situation,native_drive"]))
	assert_true(not BrainSwitches.native_situation and not BrainSwitches.native_drive,
			"--brains-off is applied after --brains-on, whatever the order on the line")
	BrainSwitches.native_situation = saved[0]
	BrainSwitches.native_matchups = saved[1]
	BrainSwitches.native_drive = saved[2]


func test_a_window_of_a_real_match_reports_its_parts() -> void:
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	for i in 6:
		var tank := game_match.spawn_tank("Profiled%d" % i, 0, Match.Team.GREEN if i % 2 == 0 else Match.Team.RUST, "tank")
		tank.global_position = Vector3(8.0 * i - 20.0, 0.0, 5.0 * (i % 2))
		var orders := OrderController.new()
		orders.tank = tank
		orders.tanks_root = game_match.tanks
		add_to_tree(orders)
		orders.set_orders({"type": "move_to", "x": 40.0 - 15.0 * i, "z": 30.0}, null)
	await wait_physics_frames(2)
	game_match.simulate = true
	var from := float(game_match.tick) / float(SimClock.TICK_RATE) + 0.1
	TickProfile.start_for_test(game_match.tanks, from, from + 0.8)
	var waited := 0
	while TickProfile.last_report.is_empty() and waited < 120:
		await wait_physics_frames(1)
		Avoidance.refresh(game_match.tanks)  # the hook a mover calls (harmless: once a tick)
		waited += 1
	var report := TickProfile.last_report
	TickProfile.stop_for_test()
	assert_true(not report.is_empty(), "the window closed and reported (ticks %d after start)" % waited)
	if report.is_empty():
		return
	var window: Array = report["window_s"]
	assert_true(absf(float(window[0]) - from) < 1e-5 and absf(float(window[1]) - from - 0.8) < 1e-5,
			"the window as asked (a Vector2: float32) %s" % [window])
	assert_true(int(report["sim"]["ticks"]) >= 20, "SimProfile counted the window's ticks (%d)" % int(report["sim"]["ticks"]))
	assert_true((report["sim"]["sections"] as Dictionary).has("segment:controllers"), "the controllers' segment is split out")
	assert_true(int(report["alive"][0]) == 6, "six hulls alive at the start")
	assert_true(float(report["frame_wall_ms"]) > 0.0 and float(report["ticks_per_frame"]) > 0.0, "the frame's readings")

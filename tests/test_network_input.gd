extends TestCase
## Server-side validation of client commands. No sockets: `accept()` takes the
## sender id and the clock as arguments, exactly as the RPC handler passes them.

const OWNER := 7


func _input_for_owner() -> NetworkInput:
	var input := NetworkInput.new()
	input.owner_peer_id = OWNER
	return input


func test_owner_command_is_applied() -> void:
	var input := _input_for_owner()
	assert_true(input.accept(OWNER, 1000, TankCommand.new(1.0, -0.5, Vector3(3, 0, 4))),
			"the tank's owner may drive it")
	var cmd := input.current_command(1010)
	assert_eq(cmd.throttle, 1.0, "accepted throttle is applied")
	assert_eq(cmd.aim_point, Vector3(3, 0, 4), "accepted aim is applied")
	input.free()


func test_other_peer_cannot_drive_my_tank() -> void:
	var input := _input_for_owner()
	assert_true(not input.accept(OWNER + 1, 1000, TankCommand.new(1.0)),
			"a different peer's command for this tank is rejected")
	assert_eq(input.current_command(1010).throttle, 0.0, "the tank stays still")
	assert_eq(input.rejected_count, 1, "the rejection is counted")
	input.free()


func test_non_finite_values_are_rejected() -> void:
	var input := _input_for_owner()
	assert_true(not input.accept(OWNER, 1000, TankCommand.new(NAN)), "NaN throttle is rejected")
	assert_true(not input.accept(OWNER, 1000, TankCommand.new(0.0, 0.0, Vector3(INF, 0, 0))),
			"infinite aim point is rejected (it would poison the turret angle)")
	input.free()


func test_out_of_range_values_are_clamped() -> void:
	var input := _input_for_owner()
	input.accept(OWNER, 1000, TankCommand.new(50.0, -9.0))
	var cmd := input.current_command(1000)
	assert_eq(cmd.throttle, 1.0, "a hacked client can't exceed full throttle")
	assert_eq(cmd.turn, -1.0, "or full turn rate")
	input.free()


func test_flooding_is_rate_limited() -> void:
	var input := _input_for_owner()
	var accepted := 0
	for i in NetworkInput.MAX_COMMANDS_PER_SEC + 50:
		if input.accept(OWNER, 5000, TankCommand.new(1.0)):
			accepted += 1
	assert_eq(accepted, NetworkInput.MAX_COMMANDS_PER_SEC, "only MAX_COMMANDS_PER_SEC per second get through")
	assert_true(input.accept(OWNER, 6000, TankCommand.new(1.0)), "the budget refills the next second")
	input.free()


func test_silent_owner_stops_but_keeps_aim() -> void:
	var input := _input_for_owner()
	input.accept(OWNER, 1000, TankCommand.new(1.0, 1.0, Vector3(0, 0, -9)))
	var cmd := input.current_command(1000 + NetworkInput.STALE_AFTER_MSEC + 1)
	assert_eq(cmd.throttle, 0.0, "a tank whose player went quiet stops driving")
	assert_eq(cmd.turn, 0.0, "and stops turning")
	assert_eq(cmd.aim_point, Vector3(0, 0, -9), "but the turret keeps its last aim")
	input.free()


func test_a_slow_host_frame_does_not_make_a_fresh_command_stale() -> void:
	# Measured 2026-09-14: a browser host rendering at 2 fps read commands ~500 ms before simulating
	# them, and every player's tank stood still. Staleness counts from the last network read.
	var input := _input_for_owner()
	input.note_poll(1000)
	input.accept(OWNER, 1000, TankCommand.new(1.0))
	# ...the frame renders for 700 ms, then the physics ticks run...
	assert_eq(input.command_for_tick().throttle, 1.0, "the command read this frame still drives the tank")
	input.note_poll(1000 + NetworkInput.STALE_AFTER_MSEC + 200)
	assert_eq(input.command_for_tick().throttle, 0.0, "but a later read with nothing new stops it")
	input.free()


func test_client_sends_changes_and_keepalives_not_every_tick() -> void:
	var input := _input_for_owner()
	var held := TankCommand.new(1.0, 0.0, Vector3(0, 0, -20))
	var sent := 0
	# One second of 60 Hz ticks holding the same command.
	for tick in 60:
		if input.should_send(held, 1000 + tick * 16):
			sent += 1
	assert_true(sent >= 9 and sent <= 11, "a held command goes out ~10 times a second as a keepalive (sent %d)" % sent)
	input.free()


func test_client_sends_changes_promptly_but_at_most_every_other_tick() -> void:
	var input := _input_for_owner()
	var sent := 0
	for tick in 60:
		# The aim sweeps a meter every tick: always "changed".
		if input.should_send(TankCommand.new(1.0, 0.0, Vector3(tick, 0, -20)), 1000 + tick * 16):
			sent += 1
	assert_true(sent >= 29 and sent <= 31, "a constantly changing command is capped near 30 per second (sent %d)" % sent)
	input.free()


func test_trigger_pull_is_sent_on_the_same_tick() -> void:
	var input := _input_for_owner()
	input.should_send(TankCommand.new(), 1000)
	assert_true(input.should_send(TankCommand.new(0.0, 0.0, Vector3.ZERO, true), 1016),
			"fire goes out immediately, even right after another send (a one-tick trigger pull isn't lost)")
	input.free()

extends TestCase
## R47.44 (granted to engage, the E3 ship): R2's short halt when the shot drops mid-halt. The plant's cancel ("the shot is
## gone") arms the cooldown, so an ordered move drives on; but inside a cooldown that followed a halt with NO round fired, a
## long round worth halting for waits for the next halt instead of leaving on the move (test_rules_spread's 98 m round on
## 11 m/s: the pick dropped for a tick, the halt cancelled, and the fully laid round left rolling). Driven tick by tick
## through Tank._short_halt with a toy hull: throttle accelerates it, a zeroed throttle brakes it.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const DT := 1.0 / 30.0
const ACCEL := 6.0  # m/s^2 under throttle
const BRAKE := 12.0  # m/s^2 braking: top speed to SHORT_HALT_STILL inside SHORT_HALT_MAX_S, as test_rules_spread's hull (11 -> 1.1 m/s)


func _crew() -> Tank:
	var arena := add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.set_meta("arena", arena)
	var crew := game_match.spawn_tank("Green_Rail_1", 0, Match.Team.GREEN, "syn_tank")
	crew.place(Vector3(-110.0, 0.0, 90.0), 0.0)
	crew._speed = 0.8 * crew.max_forward_speed
	return crew


## Runs `ticks` plant ticks with the trigger from `wants(i)`; returns {"braked": ticks with the throttle zeroed,
## "rolling_long": rounds that left with the hull at or above SHORT_HALT_STILL, "rounds": rounds that left}.
func _run(crew: Tank, ticks: int, wants: Callable) -> Dictionary:
	var out := {"braked": 0, "rolling_long": 0, "rounds": 0}
	var aim := crew.global_position + Vector3(0.0, 0.0, -99.0)  # 99 m: a round R2 halts for
	for i in ticks:
		var cmd := TankCommand.new()
		cmd.fire = bool(wants.call(i)) and crew._reload_ticks <= 1  # one round a run: the toy has no reload
		cmd.aim_point = aim
		var drive := TankCommand.new()
		drive.throttle = 1.0
		crew._short_halt(cmd, drive, DT)
		if drive.throttle == 0.0:
			out["braked"] += 1
			crew._speed = maxf(0.0, crew._speed - BRAKE * DT)
		else:
			crew._speed = minf(crew.max_forward_speed, crew._speed + ACCEL * DT)
		if cmd.fire:
			out["rounds"] += 1
			crew._reload_ticks = 1 << 30
			if absf(crew._speed) >= Tank.SHORT_HALT_STILL * crew.max_forward_speed:
				out["rolling_long"] += 1
	return out


## The bug: one dropped tick mid-halt, then a steady trigger. No long round leaves rolling; one leaves steady.
func test_a_halt_whose_shot_drops_for_a_tick_never_lets_the_round_go_rolling() -> void:
	var crew := _crew()
	var got := _run(crew, 10 * 30, func(i: int) -> bool: return i != 5)
	assert_true(int(got["rolling_long"]) == 0, "no 99 m round on the move (%s)" % [got])
	assert_true(int(got["rounds"]) >= 1, "and the round still goes, from a steady hull (%s)" % [got])


## The risk the orchestrator named: a shot that flickers every few ticks for 10 s must not chain halts into a stall.
## Braked at most a quarter of the time, so his ordered move still completes; and still no long round leaves rolling.
func test_a_flickering_shot_does_not_chain_halts_into_a_stall() -> void:
	var crew := _crew()
	var got := _run(crew, 10 * 30, func(i: int) -> bool: return i % 4 != 3)
	assert_true(int(got["braked"]) <= 75, "braked %d of 300 ticks (bound 75): the move drives on (%s)" % [got["braked"], got])
	assert_true(int(got["rolling_long"]) == 0, "no 99 m round on the move (%s)" % [got])


## `--halt-cancel=old`, the replay escape: the same dropped tick lets the long round leave rolling, as before R47.44.
func test_halt_cancel_old_restores_the_rolling_round() -> void:
	var crew := _crew()
	Tank.HALT_CANCEL_OLD = true
	var got := _run(crew, 10 * 30, func(i: int) -> bool: return i != 5)
	Tank.HALT_CANCEL_OLD = false
	assert_true(int(got["rolling_long"]) == 1, "the old cancel: the 99 m round leaves on the move (%s)" % [got])

extends TestCase
## Round-3 X5 (_agents/streams/archive/round3/ai.md): a CPU that maneuvers where the player can see it. The lead: *"There's no action from
## the computer player to use different formations or flanking maneuvers … a V formation of scouts from the gang coming
## at you would be scary."* CpuCommander policy from COMMANDER_POLICY against plain brains.

const PENDING := []
const COMMANDER_POLICY := CpuCommander.DEFAULT_POLICY


func _army(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func test_the_cpu_scouts_charge_in_a_v() -> void:
	var s := AiScenario.create(self, 4)
	assert_eq(s.game_match.load_doctrine(Match.Team.RUST, _army("res://tests/ai_scenarios/armies/swarm.json")), "", "setup: CPU swarm")
	assert_eq(s.game_match.load_doctrine(Match.Team.GREEN, _army("res://tests/ai_scenarios/armies/balanced.json")), "", "setup: defenders")
	var commander := CpuCommander.new()
	commander.game_match = s.game_match
	commander.team = Match.Team.RUST
	commander.policy = COMMANDER_POLICY
	add_to_tree(commander)
	var squad: Squad = s.game_match.squads["1/Eyes"]
	var charging := 0
	var v_ticks := 0
	var best_spread := 0.0
	await s.start()
	for tick in SimClock.TICK_RATE * 45:
		await s.step()
		var last: Dictionary = commander.last_commands.get("Eyes", {})
		if last.get("verb", "") != "move" or last.get("formation", "") != "vee":
			continue
		charging += 1
		var by_name := s.game_match.tanks_by_name()
		var alive := squad.alive_members(by_name)
		if alive.size() < 3:
			continue
		# Spread across the charge direction, and everyone driving.
		var heading := squad.heading
		var across := Vector3(-heading.z, 0, heading.x)
		var lowest := INF
		var highest := -INF
		var all_fast := true
		for member in alive:
			var tank := by_name[member] as Tank
			var side := tank.global_position.dot(across)
			lowest = minf(lowest, side)
			highest = maxf(highest, side)
			all_fast = all_fast and tank.estimated_velocity.length() > 5.0
		best_spread = maxf(best_spread, highest - lowest)
		if highest - lowest >= 12.0 and all_fast:
			v_ticks += 1
	print("MEASURE ai_scout_v commander %s: charging orders %.1f s, spread V at speed %.1f s (widest %.0f m)" % [COMMANDER_POLICY,
			charging / float(SimClock.TICK_RATE), v_ticks / float(SimClock.TICK_RATE), best_spread])
	assert_true(v_ticks >= SimClock.TICK_RATE * 2, "the scouts charge in a visible V for 2 s+ (%.1f s)" % (v_ticks / float(SimClock.TICK_RATE)))

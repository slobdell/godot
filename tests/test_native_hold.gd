extends TestCase
## Round 29 (native, C29.2 scaffold for traffic's T1): the street hold's record (NativeHold, native/src/hold_native.h).
## Nothing in the game writes a hold yet, so the execute is unchanged with the table empty (test_native_execute's
## equality runs with it empty). Here, on a live Sumps fight: a hold reads back bit for bit; a holding crew's native
## execute hands back having written nothing (both views), counted as "holding"; the native drive's seam steps aside for
## it and only for it; a release (or the crew's exec_forget) puts it back on the native path.

const MATCH := preload("res://game/match/match.tscn")
const EXECUTE := preload("res://tests/test_native_execute.gd")


func _doctrine(units: Array[String]) -> Dictionary:
	var entries := []
	for unit in units:
		entries.append({"unit": unit})
	return {"squads": [{"name": "Alpha", "units": entries.slice(0, 5)}, {"name": "Bravo", "units": entries.slice(5)}]}


func test_a_holding_crew_is_handed_back_and_nothing_else_moves() -> void:
	if not NativeBridge.available:
		print("native: absent, the hold's record is not exercised in this run")
		return
	assert_true(NativeGun.configure() and NativeDrive.configure(), "the native drive and gun take the live constants")
	NativeHold.release_all()
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv", "tank"]
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _doctrine(units)), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _doctrine(units)), "", "rust loads")
	var delta := 1.0 / float(SimClock.TICK_RATE)
	var was_exec := BrainSwitches.native_exec
	BrainSwitches.native_exec = false
	await wait_physics_frames(60)
	var movers: Array[Movement] = []
	for node in game_match.tanks.get_children():
		var mover := Movement.of(node)
		if mover != null and mover.ctl != null and mover.ctl.gunnery != null and mover.ctl.tank.alive:
			movers.append(mover)
	assert_true(movers.size() >= 10, "a fight to hold crews in (%d crews)" % movers.size())

	# The record: empty, then one crew's hold read back bit for bit.
	assert_eq(NativeBridge.impl.hold_count(), 0, "no hold before traffic writes one")
	var held: Movement = movers[0]
	var spot := Vector3(12.25, 0.0, -7.125)
	NativeHold.hold(held, spot, 3.5)
	assert_eq(NativeBridge.impl.hold_count(), 1, "one hold written")
	assert_true(NativeHold.holding(held), "the held crew holds")
	assert_eq(NativeHold.of(held), [spot, 3.5], "the hold reads back as written")
	for other in movers.slice(1):
		assert_false(NativeHold.holding(other), "%s does not hold" % other.ctl.tank.name)
	assert_false(NativeDrive.usable(held), "the native drive steps aside for a holding crew")
	assert_true(NativeDrive.usable(movers[1]), "and only for it")

	# The execute: over several ticks, the held crew is handed back untouched in both views; the others are unchanged by
	# the hold (the same answer with the hold written and with the table empty).
	var before: Dictionary = NativeBridge.impl.execute_counts(true)
	var handed := 0
	var mismatches := 0
	var others_native := 0
	var first := ""
	for frame in 40:
		await wait_physics_frames(1)
		for mover in movers:
			if not mover.ctl.tank.alive:
				continue
			var ctl := mover.ctl
			var start := EXECUTE._capture(movers, ctl)
			for owned in [false, true]:
				var mode := NativeExec.EXEC_OWNED_VERIFY if owned else NativeExec.EXEC_LIVE
				var answers := []
				var afters := []
				for with_hold in [true, false]:
					EXECUTE._restore(movers, ctl, start)
					for each in movers:
						each.native_stale = Movement.STALE_ALL
					if with_hold:
						NativeHold.hold(held, spot, 3.5)
					else:
						NativeHold.release(held)
					var answer: Variant = NativeBridge.impl.execute(ctl, delta, mode)
					answers.append(EXECUTE._command(answer) if answer != null else null)
					afters.append(EXECUTE._capture(movers, ctl))
				NativeHold.hold(held, spot, 3.5)
				if mover == held:
					var wrote := EXECUTE._diff(start, afters[0])
					if answers[0] != null or wrote != "":
						mismatches += 1
						if first == "":
							first = "frame %d: the held crew answered %s, wrote %s" % [frame, answers[0], wrote]
					else:
						handed += 1
				else:
					if answers[0] != null:
						others_native += 1
					var differ := EXECUTE._diff(afters[0], afters[1])
					if answers[0] != answers[1] or differ != "":
						mismatches += 1
						if first == "":
							first = "frame %d %s: with the hold %s, without %s; %s" % [frame, ctl.tank.name, answers[0],
									answers[1], differ]
			EXECUTE._restore(movers, ctl, start)
			for each in movers:
				each.native_stale = Movement.STALE_ALL
	var counts: Dictionary = NativeBridge.impl.execute_counts(true)
	print("native hold: %d held executes handed back, %d other crews' executes native, counts %s (before %s)" % [handed,
			others_native, counts, before])
	assert_eq(mismatches, 0, "a hold hands its crew back and moves nobody else: %s" % first)
	assert_true(handed >= 60, "the held crew was asked (%d)" % handed)
	assert_true(others_native >= 200, "the others went native (%d)" % others_native)
	assert_true(int(counts["holding"]) >= handed, "each hand-back is counted as holding (%d)" % int(counts["holding"]))

	# Released: back on the native drive. Forgotten with its execute state: the hold goes too.
	NativeHold.release(held)
	assert_false(NativeHold.holding(held), "released")
	assert_true(NativeDrive.usable(held), "the native drive takes it again")
	NativeHold.hold(held, spot, 3.5)
	NativeBridge.impl.exec_forget(held)
	assert_false(NativeHold.holding(held), "a crew's exec_forget drops its hold")
	NativeHold.release_all()
	assert_eq(NativeBridge.impl.hold_count(), 0, "release_all empties the table")
	BrainSwitches.native_exec = was_exec

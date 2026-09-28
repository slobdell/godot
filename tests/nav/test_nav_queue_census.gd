extends TestCase
## Round 14 (nav N4): the queue census (`Movement.queue_census`, `Movement.QueueTally`). A hull is QUEUED behind a
## yielder when its `blocked_by` chain, through other blocked hulls, ends at a hull giving way; the yielder is
## labelled by its spot kind, so "does a hull that HOLDS block the street behind it" is a count, not a guess.
## Measurement only: the movers' states are set by hand here, nothing is driven.

const MATCH := preload("res://game/match/match.tscn")


func _movers(names: Array) -> Dictionary:
	await ArenaFixture.build(self, "terminus")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var out := {"match": game_match}
	for i in names.size():
		var tank := game_match.spawn_tank(names[i], i, Match.Team.GREEN, "gang_tank")
		tank.global_position = Vector3(-40.0 + 16.0 * i, 0.0, 30.0)
		var orders := OrderController.new()
		orders.tank = tank
		orders.tanks_root = game_match.tanks
		add_to_tree(orders)
	await wait_physics_frames(2)
	for name: String in names:
		out[name] = Movement.of(game_match.tanks.get_node(name))
	return out


func test_a_chain_of_blocked_hulls_is_queued_behind_the_holder() -> void:
	var m := await _movers(["Holder", "Asker", "Second", "Third", "Free"])
	var holder: Movement = m["Holder"]
	holder.phase = "yielding"
	holder.yield_to = "Asker"
	holder.yield_spot = "hold"
	(m["Second"] as Movement).phase = "blocked"
	(m["Second"] as Movement).blocked_by = "Holder"
	(m["Third"] as Movement).phase = "blocked"
	(m["Third"] as Movement).blocked_by = "Second"
	(m["Asker"] as Movement).phase = "driving"
	var census := Movement.queue_census((m["match"] as Match).tanks)
	assert_eq(census["yielders"], {"Holder": "hold"}, "the holder is the one yielder, labelled hold (%s)" % census)
	assert_eq(census["queued"], {"Second": "Holder", "Third": "Holder"}, "both hulls behind it are queued on it (%s)" % census)
	var tally := Movement.QueueTally.new()
	tally.add(census)
	tally.add(census)
	holder.phase = "driving"
	holder.yield_to = ""
	tally.add(Movement.queue_census((m["match"] as Match).tanks))
	var report := tally.report()
	assert_eq(int(report["queued_unit_ticks"].get("hold", 0)), 4, "2 hulls x 2 ticks (%s)" % report)
	assert_eq(int(report["longest_queue"]), 2, "(%s)" % report)
	var row: Dictionary = report["episodes_by_kind"]["hold"]
	assert_eq([int(row["episodes"]), int(row["ticks"]), int(row["with_queue"])], [1, 2, 1], "one hold episode of 2 ticks, with a queue (%s)" % report)


func test_a_hull_blocked_by_a_driving_hull_is_not_queued() -> void:
	var m := await _movers(["Mover", "Behind"])
	(m["Behind"] as Movement).phase = "blocked"
	(m["Behind"] as Movement).blocked_by = "Mover"
	(m["Mover"] as Movement).phase = "driving"
	var census := Movement.queue_census((m["match"] as Match).tanks)
	assert_true((census["queued"] as Dictionary).is_empty(), "no yielder, no queue (%s)" % census)

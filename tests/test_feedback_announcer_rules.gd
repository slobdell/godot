extends TestCase
## Round 39 (feedback stretch, his six approved caller lines): the booth calls two of round 37's rules in a real match,
## ON by default (his call at round 39's close; `--announcer-rules=off` mutes them). The live match counts shells fired on the move that hit nothing
## (R2) and crews crawling under fire (R3), and hands them to the booth on momentum's optional `rules` field (K5 stays
## as it is); AnnouncerMemory turns them into moving_miss and pinned_slow moments, which his lines answer.

const MATCH := preload("res://game/match/match.tscn")
const LINES := {"moving_miss": "caller.moving_miss.%02d", "pinned_slow": "caller.pinned_slow.%02d"}


func _memory(contact := true) -> AnnouncerMemory:
	var memory := AnnouncerMemory.new(AnnouncerLibrary.load_default())
	memory.observe({"type": "match_start", "tick": 0, "t": 0.0, "arena": "terminus", "budget": 1000, "control_point": true,
			"teams": [{"team": "green", "faction": "gangs", "units": [{"id": "g1", "unit": "tank", "squad": "A"}]},
					{"team": "rust", "faction": "law", "units": [{"id": "r1", "unit": "ifv", "squad": "B"}]}]})
	if contact:
		memory.observe({"type": "first_contact", "tick": 60, "t": 1.0, "team": "green", "unit_id": "g1", "unit": "tank",
				"target_id": "r1", "target_unit": "ifv"})
	return memory


func _momentum(memory: AnnouncerMemory, rules: Variant) -> Array:
	var event := {"type": "momentum", "tick": 600, "t": 10.0, "army_health": {"green": 1.0, "rust": 1.0}}
	if rules != null:
		event["rules"] = rules
	return memory.observe(event).map(func(found: Dictionary) -> String: return "%s/%s" % [found["kind"], found["team"]])


func test_on_by_default() -> void:
	var game_match: Match = add_to_tree(MATCH.instantiate())
	assert_true(MatchEventAdapter.new(game_match, "terminus").rules_calls, "his six lines are on unless --announcer-rules=off")
	assert_eq(_momentum(_memory(), null), [], "a momentum without them says nothing new")


func test_the_rules_become_moments() -> void:
	var rules := {"moving": {"green": [3, 0], "rust": [5, 1]}, "slowed": {"green": "", "rust": "ifv"}}
	assert_eq(_momentum(_memory(), rules), ["moving_miss/green", "pinned_slow/rust"],
			"three misses on the move and no hit is a moving_miss; a hit spoils it; a crew crawling is a pinned_slow")
	assert_eq(_momentum(_memory(), {"moving": {"green": [2, 0]}, "slowed": {}}), [], "two misses are not a story")
	assert_eq(_momentum(_memory(false), rules), [], "nothing before the first shot of the match")


func test_his_lines_answer_them() -> void:
	var memory := _memory()
	var found := memory.observe({"type": "momentum", "tick": 600, "t": 10.0, "army_health": {"green": 1.0, "rust": 1.0},
			"rules": {"moving": {"green": [4, 0]}, "slowed": {"rust": "tank"}}})
	assert_eq(found.size(), 2, "both moments")
	for moment: Dictionary in found:
		var ids := memory.library.candidates("caller", ["call"], moment, {}).map(
				func(line: Dictionary) -> String: return String(line["id"]))
		for n in [1, 2, 3]:
			assert_true(ids.has(LINES[moment["kind"]] % n), "%s answers %s" % [LINES[moment["kind"]] % n, moment["kind"]])
		assert_true(memory.library.moments.has(moment["kind"]), "%s has a beat" % moment["kind"])


func test_the_live_match_counts_shells_fired_on_the_move() -> void:
	var game_match: Match = add_to_tree(MATCH.instantiate())
	var adapter := MatchEventAdapter.new(game_match, "terminus")
	adapter.rules_calls = true
	adapter._units = {"Rust_1": {"team": 1, "unit": "ifv", "alive": true}, "Green_1": {"team": 0, "unit": "tank", "alive": true}}
	adapter._moving_rounds = {1: [0, 0.0], 2: [0, 0.0], 3: [0, 0.0], 4: [1, 0.0]}
	game_match.projectile_impact.emit({"tick": 0, "projectile_id": 1})  # a wall
	game_match.projectile_impact.emit({"tick": 0, "projectile_id": 2, "target": "Green_1", "face": "rear"})  # its own
	game_match.projectile_impact.emit({"tick": 0, "projectile_id": 4, "target": "Green_1", "face": "side"})
	game_match.tick += roundi((MatchEventAdapter.RULE_MISS_WAIT_S + 0.1) * Engine.physics_ticks_per_second)
	adapter._moving_rounds[5] = [0, adapter.seconds()]  # just fired: not a miss yet
	adapter._slow_since = {"Rust_1": 0.0}
	var rules := adapter._rules_since()
	assert_eq(rules["moving"]["green"], [3, 0], "a wall, a friend and a shell never heard of again are misses")
	assert_eq(rules["moving"]["rust"], [0, 1], "a hit on an enemy is a hit")
	assert_eq(rules["slowed"], {"green": "", "rust": "ifv"}, "a crew slowed long enough is named by its unit")
	assert_eq(adapter._rules_since()["moving"]["green"], [0, 0], "a fresh count each momentum")
	assert_true(adapter._moving_rounds.has(5), "the shell still in the air waits for its impact")


func test_his_lines_are_recorded() -> void:
	var library := AnnouncerLibrary.load_default()
	assert_true(library.load_manifest("res://assets/announcer/clips/manifest.json"), "the clip manifest loads")
	for kind: String in LINES:
		for n in [1, 2, 3]:
			var id: String = LINES[kind] % n
			assert_true(float(library.clip_seconds.get(id, 0.0)) > 1.0, "%s has a recorded clip in the manifest" % id)
			assert_true(FileAccess.file_exists("res://assets/announcer/clips/caller/%s.ogg" % id), "%s's clip ships" % id)

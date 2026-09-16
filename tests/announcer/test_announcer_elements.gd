extends TestCase
## L1 (doctrine, 2026-09-16): the booth listens to why an element is lining up the way it is, so the Veteran can
## explain the tactics instead of the HUD showing them. The adapter only listens, and stamps the clock — doctrine
## sends its decisions without one.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


## Stands in for doctrine's Elements until that branch merges: the adapter finds it by its signal, not its class.
class FakeElements:
	extends Node
	signal element_reported(event: Dictionary)


func _match() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var army := {"name": "A", "squads": [{"name": "Alpha", "units": [{"unit": "tank"}]}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, army), "", "setup: green")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, army), "", "setup: rust")
	return game_match


func test_the_booth_hears_an_elements_decision_and_stamps_it() -> void:
	var game_match := _match()
	var elements := FakeElements.new()
	elements.name = "Elements"
	game_match.add_child(elements)
	var adapter := MatchEventAdapter.new(game_match, "foundry")
	assert_true(adapter.listen_for_elements(), "the adapter finds whatever publishes element decisions")
	await wait_physics_frames(2)
	adapter.poll()
	game_match.tick = 318
	# Doctrine's own sample shape, verbatim, with no clock on it.
	elements.element_reported.emit({"type": "element_drill", "team": "green", "element": "Battery", "size": 1,
			"reason": "outgunned here: break contact and bound back", "drill": "break_contact",
			"formation": "column", "distance": 118.7, "target": "Rust_Anvil_1"})
	var events := adapter.poll()
	var drills := events.filter(func(e: Dictionary) -> bool: return e["type"] == "element_drill")
	assert_eq(drills.size(), 1, "the decision reaches the booth: %s" % [events.map(func(e: Dictionary) -> String: return e["type"])])
	assert_eq(drills[0]["tick"], 318, "stamped with the match's tick, which doctrine does not send")
	assert_true(drills[0].has("t"), "and with a time")
	assert_eq(drills[0]["reason"], "outgunned here: break contact and bound back",
			"the element's own words survive, for the subtitle and the demo page's why")
	for event in events:
		assert_eq(AnnouncerEvents.validate_event(event), PackedStringArray(),
				"every event the booth heard is valid K5: %s" % [event])


func test_both_element_types_are_part_of_the_contract() -> void:
	for type in ["element_formation", "element_drill"]:
		assert_true(AnnouncerEvents.REQUIRED.has(type), "%s is in the K5 contract" % type)
		assert_true(AnnouncerEvents.REQUIRED[type].has("reason"), "%s carries the element's reasoning" % type)


func test_a_booth_with_nobody_publishing_elements_is_simply_quiet() -> void:
	var game_match := _match()
	var adapter := MatchEventAdapter.new(game_match, "foundry")
	assert_true(not adapter.listen_for_elements(), "nothing to listen to before doctrine merges, and no error")
	await wait_physics_frames(2)
	for event in adapter.poll():
		assert_eq(AnnouncerEvents.validate_event(event), PackedStringArray(), "the match still reports normally")

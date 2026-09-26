extends TestCase
## Round 11 follow-up. The lead, playing the merged build (2026-09-25):
##
##   *"I had a group of trucks and I commanded them to go and screen to a certain point and they did nothing. I could
##   still just tell them to move though."* … *"I get warning when I try to use screen: Can't 'verb' must be one of
##   move, attack…"* … *"I'm telling you that the screen button isn't working. I can't get the units to set up a
##   screen."*
##
## The cause was two predicates for one question. `can_task()` — which the Screen key, the card button and the armed
## click all gate on — asks "is this selection a squad". `_is_task()`, which routes the verb to the task path, asks
## that AND `formation == AUTO` AND `not queue`. So choosing a formation with G, or shift-queuing, left every guard
## passing while the verb fell through to the single-vehicle order path, where no unit has a verb called "screen".
##
## These tests are written from his three sentences, not from the fix: each one fails on the old behaviour.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup() -> Array:
	var arena := add_to_tree(ARENA.instantiate()) as Node3D
	for _frame in 60:
		await tree.physics_frame
		if TacticsLab.navigation_is_this_arenas(arena):
			break
	var game_match := MATCH.instantiate() as Match
	add_to_tree(game_match)
	var squad := {"name": "Trucks", "units": [{"unit": "gang_support"}, {"unit": "gang_ifv"}, {"unit": "gang_support"}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, {"name": "T", "squads": [squad]}), "", "setup")
	var orders := Orders.new()
	Orders.attach(game_match, orders)
	# Elements.install is the real constructor: it wires game_match and Orders, without which `_tank()` finds
	# nothing, every roster comes out empty and `of()` answers null for a squad that looks formed.
	var elements := Elements.install(game_match, orders)
	var controls := RtsControls.new()
	controls.orders = orders
	controls.elements = elements
	controls.game_match = game_match
	add_to_tree(controls)
	var names: Array[String] = []  # Selection.units is Array[String]: a plain Array will not assign
	for child in game_match.tanks.get_children():
		var tank := child as Tank
		if tank != null and tank.team == Match.Team.GREEN:
			names.append(String(tank.name))
	controls.selection.units = names.duplicate()
	return [controls, elements, names]


## His headline: the Screen button works. No Ctrl+1 first, no formation cycling — select trucks, screen a point.
func test_screen_on_a_plain_selection_forms_a_squad_and_takes_the_task() -> void:
	var setup: Array = await _setup()
	var controls: RtsControls = setup[0]
	var elements: Elements = setup[1]
	var names: Array[String] = setup[2]
	assert_true(not controls.can_task(), "setup: a plain selection is in no squad yet")
	var error := controls.order_selection("screen", {"to": [40.0, 0.0]})
	assert_eq(error, "", "Screen is accepted on a plain selection (%s)" % error)
	var element := elements.of(String(names[0]))
	assert_true(element != null, "and a real, numbered squad was formed to carry it")
	assert_eq(String((element.task as Dictionary).get("verb", "")), "screen",
			"and the squad's task is the screen he asked for (%s)" % element.task)
	assert_true(controls.selected_group() > 0,
			"the squad has a control-group number, so he can re-select it (round 10's ruling: no transient elements)")


## The cause, as its own test: a chosen formation must not turn a task into an invalid unit order.
func test_choosing_a_formation_does_not_cancel_a_task() -> void:
	var setup: Array = await _setup()
	var controls: RtsControls = setup[0]
	var elements: Elements = setup[1]
	var names: Array[String] = setup[2]
	controls.groups.save(1, names.duplicate())
	controls.selection.units = names.duplicate()
	assert_true(controls.can_task(), "setup: this selection is a squad")
	controls.cycle_formation()  # G: anything but AUTO
	assert_true(controls.formation != UnitCommand.AUTO, "setup: a formation is chosen (%s)" % controls.formation)
	var error := controls.order_selection("screen", {"to": [40.0, 0.0]})
	assert_eq(error, "", "Screen still works with a formation chosen (%s)" % error)
	var element := elements.of(String(names[0]))
	assert_true(element != null and String((element.task as Dictionary).get("verb", "")) == "screen",
			"and it is the element's task, not a unit order nothing can carry out")


## The other half of the same gap: shift-queuing a task must not produce the developer's verb list either.
func test_a_queued_task_is_applied_rather_than_refused_as_an_unknown_verb() -> void:
	var setup: Array = await _setup()
	var controls: RtsControls = setup[0]
	var elements: Elements = setup[1]
	var names: Array[String] = setup[2]
	controls.groups.save(1, names.duplicate())
	controls.selection.units = names.duplicate()
	var error := controls.order_selection("screen", {"to": [40.0, 0.0], "queue": true})
	assert_true(not error.contains("'verb' must be one of"),
			"a queued task never reaches the unit-order validator (%s)" % error)
	var element := elements.of(String(names[0]))
	assert_true(element != null and String((element.task as Dictionary).get("verb", "")) == "screen",
			"tasks replace rather than stack, so it applies now")


## And the refusal that remains is one he can act on, never the six-verb list.
func test_a_task_that_cannot_be_given_says_something_a_player_can_act_on() -> void:
	var setup: Array = await _setup()
	var controls: RtsControls = setup[0]
	controls.elements = null  # a match running without the doctrine layer
	var error := controls.order_selection("screen", {"to": [40.0, 0.0]})
	assert_true(error != "" and not error.contains("'verb' must be one of"),
			"the refusal is in the player's language, not the validator's (%s)" % error)


## Round 11 (the lead, 2026-09-25): *"they're still not really forming up when I give them a formation to use"*.
## Before this there was no channel for the shape he picks with G to reach a squad at all: choosing one sent the
## order down the DIRECT path, which dissolves the element, so he could have his shape or the squad's brain and
## never both. His choice now rides the task and beats the doctrine table's pick.
func test_the_formation_he_chose_reaches_the_squad_and_beats_the_table() -> void:
	var setup: Array = await _setup()
	var controls: RtsControls = setup[0]
	var elements: Elements = setup[1]
	var names: Array[String] = setup[2]
	controls.groups.save(1, names.duplicate())
	controls.selection.units = names.duplicate()
	while controls.formation == UnitCommand.AUTO or controls.formation == "wedge":
		controls.cycle_formation()  # land on a shape the table would not pick by default
	var chosen := controls.formation
	assert_eq(controls.order_selection("move", {"to": [40.0, 0.0]}), "", "the squad takes the order")
	var element := elements.of(String(names[0]))
	assert_true(element != null, "a squad carries it")
	assert_eq(String((element.task as Dictionary).get("formation", "")), chosen,
			"the task carries the shape he chose (%s)" % element.task)


## And AUTO still means what his 2026-09-16 ruling asked for: the leader decides, and no shape is forced on it.
func test_auto_leaves_the_leader_to_decide() -> void:
	var setup: Array = await _setup()
	var controls: RtsControls = setup[0]
	var elements: Elements = setup[1]
	var names: Array[String] = setup[2]
	controls.groups.save(1, names.duplicate())
	controls.selection.units = names.duplicate()
	assert_eq(controls.formation, UnitCommand.AUTO, "setup: AUTO is the default")
	assert_eq(controls.order_selection("screen", {"to": [40.0, 0.0]}), "", "the squad takes the task")
	var element := elements.of(String(names[0]))
	assert_true(element != null and not (element.task as Dictionary).has("formation"),
			"no shape is forced: the leader picks from its DoctrineTable (%s)" % element.task)

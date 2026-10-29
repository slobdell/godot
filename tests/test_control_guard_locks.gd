extends TestCase
## Round 45 (orders O2): THE GROUP GUARD (G2) on the Locks: his two north-edge squads (the round-43 recording's Hunters and
## Spears at tick 1500, tests/test_control_his_locks_click.gd) and one click (a) beside the lock on the north bank, where today's
## `row` lays the second squad on the lock's mouth, and (b) on the west swing bridge's deck, where today's row puts one squad
## across the canal. With the guard ON every place is dry, off any deck, on the click's side of the water and in one body.

const SQUADS := {
	"Green_Hunters": ["Green_Hunters_1", "Green_Hunters_2", "Green_Hunters_3", "Green_Hunters_4", "Green_Hunters_5"],
	"Green_Spears": ["Green_Spears_1", "Green_Spears_2", "Green_Spears_3", "Green_Spears_4", "Green_Spears_5"],
}
const AT := {
	"Green_Hunters_1": ["gang_ifv", Vector3(-21.100, 0, 89.000)],
	"Green_Hunters_2": ["gang_ifv", Vector3(-14.600, 0, 89.000)],
	"Green_Hunters_3": ["gang_ifv", Vector3(-17.900, 0, 95.500)],
	"Green_Hunters_4": ["gang_ifv", Vector3(-8.100, 0, 89.000)],
	"Green_Hunters_5": ["gang_ifv", Vector3(-11.400, 0, 95.500)],
	"Green_Spears_1": ["gang_scout", Vector3(-3.800, 0, 101.300)],
	"Green_Spears_2": ["gang_scout", Vector3(4.700, 0, 89.800)],
	"Green_Spears_3": ["gang_scout", Vector3(19.600, 0, 93.400)],
	"Green_Spears_4": ["gang_scout", Vector3(25.300, 0, 83.000)],
	"Green_Spears_5": ["gang_tank", Vector3(22.900, 0, 90.000)],
}
## Locks: the canal x -150..150, z -7..7; the lock's deck x -8..8, z -12..12; the west swing bridge x -99..-85, z -12..12.
const BESIDE_LOCK := Vector3(-22.0, 0.0, 13.0)
const ON_DECK := Vector3(-92.0, 0.0, 0.0)

var _lab: TacticsLab
var _controls: RtsControls


func teardown() -> void:
	RtsControls.order_trace_keep = false
	SelectionSquads.GROUP_GUARD = not OS.get_cmdline_user_args().has("--group-guard=off")
	SelectionSquads.reset_g1()
	if _controls != null and is_instance_valid(_controls):
		_controls.queue_free()
	_controls = null
	if _lab != null:
		_lab.dispose()
	_lab = null
	super.teardown()


func _all() -> Array:
	var out: Array = []
	for squad: String in SQUADS:
		out.append_array(SQUADS[squad])
	return out


func _build() -> void:
	_lab = TacticsLab.create(self, 56416, "locks")
	for unit_name: String in AT:
		_lab.unit(Match.Team.GREEN, unit_name, AT[unit_name][1], 0.0, String(AT[unit_name][0]))
	await _lab.start()
	_controls = RtsControls.new()
	_controls.game_match = _lab.game_match
	_controls.orders = _lab.orders
	_controls.elements = _lab.elements
	_controls.reveal_all = true
	add_to_tree(_controls)
	var number := 1
	for squad: String in SQUADS:
		_controls.groups.save(number, (SQUADS[squad] as Array).duplicate())
		number += 1
	await wait_physics_frames(1)


func _click(at: Vector3, label: String) -> Dictionary:
	_controls.selection.set_units(_all())
	RtsControls.order_trace_keep = true
	var said := _controls.order_selection("move", {"to": [at.x, at.z]})
	var out := {}
	for squad: String in SQUADS:
		var element: Element = _controls.elements.of(SQUADS[squad][0])
		out[squad] = Vector3(float(element.task["to"][0]), 0.0, float(element.task["to"][1])) if element != null and element.task.has("to") else null
	for squad: String in SQUADS:
		var element: Element = _controls.elements.of(SQUADS[squad][0])
		if element != null:
			_controls.elements.disband(element)
	assert_eq(said, "", "%s: the click was taken" % label)
	for row: Dictionary in RtsControls.order_trace:
		var text := ""
		for place: Dictionary in row["places"]:
			text += " %s:(%.1f, %.1f)" % [String(place["squad"]).trim_prefix("Green_"), (place["at"] as Vector3).x, (place["at"] as Vector3).z]
		print("GUARD_LOCKS %s %-14s%s" % [label, row["stage"], text])
	print("GUARD_LOCKS %s -> %s" % [label, out])
	return out


func _check_body(laid: Dictionary, click: Vector3, label: String) -> void:
	for squad: String in SQUADS:
		assert_true(laid[squad] != null, "%s %s: got a place" % [label, squad])
		if laid[squad] == null:
			continue
		var at: Vector3 = laid[squad]
		assert_true(not (SlotGround.over_water(at)), "%s %s: dry and off any deck (%.1f, %.1f)" % [label, squad, at.x, at.z])
		assert_true(at.z > 7.0, "%s %s: on the north bank, the click's side (z %.1f)" % [label, squad, at.z])
		assert_true(Vector2(at.x - click.x, at.z - click.z).length() <= SelectionSquads.guard_last_reach_m + 6.0,
				"%s %s: within the body's reach %.0f m of the click (%.0f m)" % [label, squad, SelectionSquads.guard_last_reach_m,
				Vector2(at.x - click.x, at.z - click.z).length()])
	var apart: float = (laid["Green_Hunters"] as Vector3).distance_to(laid["Green_Spears"]) if laid["Green_Hunters"] != null and laid["Green_Spears"] != null else 0.0
	assert_true(apart >= 20.0, "%s: the two squads stand apart (%.0f m)" % [label, apart])


func test_today_lays_one_squad_on_the_locks_mouth_or_across() -> void:
	await _build()
	SelectionSquads.GROUP_GUARD = false
	var beside := _click(BESIDE_LOCK, "today-beside")
	var wet_beside := 0
	for squad: String in SQUADS:
		if beside[squad] != null and (SlotGround.over_water(beside[squad]) or (beside[squad] as Vector3).z < 7.0):
			wet_beside += 1
	var deck := _click(ON_DECK, "today-deck")
	var wet_deck := 0
	for squad: String in SQUADS:
		if deck[squad] != null and (SlotGround.over_water(deck[squad]) or (deck[squad] as Vector3).z < -7.0):
			wet_deck += 1
	print("GUARD_LOCKS today: beside the lock %d place(s) on the mouth or across; on the deck %d" % [wet_beside, wet_deck])
	assert_true(wet_beside + wet_deck >= 1, "today at least one of the two clicks puts a squad on the mouth, the deck or across the canal")


func test_guard_keeps_both_squads_on_the_bank() -> void:
	await _build()
	SelectionSquads.GROUP_GUARD = true
	_check_body(_click(BESIDE_LOCK, "guard-beside"), BESIDE_LOCK, "beside the lock")
	_check_body(_click(ON_DECK, "guard-deck"), ON_DECK, "on the deck")

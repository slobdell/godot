extends TestCase
## Round 46 (orders V1, R46.1): THE VETO-ONLY GROUP GUARD through the real group click (RtsControls.order_selection) on real
## navmeshes. Every click is laid twice, the veto OFF (today) and ON: a place today's lay gives that passes the veto
## (SelectionSquads.veto_failures) must come out byte-identical, a click with no failing place byte-identical as a whole, and
## every place under the veto passes it. His Gorge click is tests/test_control_his_gorge_click.gd.

## Terminus, his round-37 click among the streets (tests/test_control_group_click.gd): today's lay is a column on the streets.
const TERMINUS_CLICK := Vector3(-29.3, 0, 85.8)
const TERMINUS := {
	"Hunters": [["Green_Hunters_1", "syn_ifv", Vector3(-6.2, 0, 45.3)], ["Green_Hunters_2", "syn_ifv", Vector3(-1.1, 0, 59.9)]],
	"Battery": [["Green_Battery_1", "syn_artillery", Vector3(-9.9, 0, 85.4)], ["Green_Battery_2", "syn_artillery", Vector3(-8.7, 0, 93.2)],
			["Green_Battery_3", "syn_artillery", Vector3(-2.8, 0, 70.0)], ["Green_Battery_4", "syn_scout", Vector3(-11.3, 0, 28.0)],
			["Green_Battery_5", "syn_lancer", Vector3(-1.6, 0, 41.2)]],
	"Eyes": [["Green_Eyes_1", "syn_scout", Vector3(0.9, 0, 57.0)], ["Green_Eyes_2", "syn_scout", Vector3(31.1, 0, 84.3)],
			["Green_Eyes_3", "syn_scout", Vector3(0.7, 0, 64.9)], ["Green_Eyes_4", "syn_scout", Vector3(-4.2, 0, 53.4)],
			["Green_Eyes_5", "syn_scout", Vector3(-25.4, 0, 38.6)]],
}
## Terminus, three squads in their spawn rows clicking down the east street (the G1 lab's street click, 3801's army).
const TERMINUS_SPAWN := {
	"West": [["Green_West_1", "law_tank", Vector3(-58.1, 0, 95.8)], ["Green_West_2", "law_tank", Vector3(-26.7, 0, 94.2)]],
	"Mid": [["Green_Mid_1", "law_tank", Vector3(2.2, 0, 87.8)], ["Green_Mid_2", "law_tank", Vector3(12.2, 0, 92.8)]],
	"East": [["Green_East_1", "law_tank", Vector3(32.4, 0, 92.5)], ["Green_East_2", "law_tank", Vector3(59.0, 0, 93.3)]],
}
## Locks, his round-43 north-edge squads (tests/test_control_guard_locks.gd): a click beside the lock, one on the west swing
## bridge's deck.
const LOCKS := {
	"Hunters": [["Green_Hunters_1", "gang_ifv", Vector3(-21.1, 0, 89.0)], ["Green_Hunters_2", "gang_ifv", Vector3(-14.6, 0, 89.0)],
			["Green_Hunters_3", "gang_ifv", Vector3(-17.9, 0, 95.5)], ["Green_Hunters_4", "gang_ifv", Vector3(-8.1, 0, 89.0)],
			["Green_Hunters_5", "gang_ifv", Vector3(-11.4, 0, 95.5)]],
	"Spears": [["Green_Spears_1", "gang_scout", Vector3(-3.8, 0, 101.3)], ["Green_Spears_2", "gang_scout", Vector3(4.7, 0, 89.8)],
			["Green_Spears_3", "gang_scout", Vector3(19.6, 0, 93.4)], ["Green_Spears_4", "gang_scout", Vector3(25.3, 0, 83.0)],
			["Green_Spears_5", "gang_tank", Vector3(22.9, 0, 90.0)]],
}
const BESIDE_LOCK := Vector3(-22.0, 0.0, 13.0)
const ON_DECK := Vector3(-92.0, 0.0, 0.0)

var _lab: TacticsLab
var _controls: RtsControls
var _squads: Dictionary


func teardown() -> void:
	RtsControls.order_trace_keep = false
	SelectionSquads.GROUP_GUARD = SelectionSquads.guard_default()
	SelectionSquads.GROUP_VETO = SelectionSquads.veto_default()
	SelectionSquads.reset_g1()
	if _controls != null and is_instance_valid(_controls):
		_controls.queue_free()
	_controls = null
	if _lab != null:
		_lab.dispose()
	_lab = null
	super.teardown()


func _build(seed_n: int, arena: String, squads: Dictionary) -> void:
	_squads = squads
	_lab = TacticsLab.create(self, seed_n, arena)
	for squad: String in squads:
		for m: Array in squads[squad]:
			_lab.unit(Match.Team.GREEN, String(m[0]), m[2], 0.0, String(m[1]))
	await _lab.start()
	_controls = RtsControls.new()
	_controls.game_match = _lab.game_match
	_controls.orders = _lab.orders
	_controls.elements = _lab.elements
	_controls.reveal_all = true
	add_to_tree(_controls)
	var number := 1
	for squad: String in squads:
		var names: Array = []
		for m: Array in squads[squad]:
			names.append(String(m[0]))
		_controls.groups.save(number, names)
		number += 1
	await wait_physics_frames(1)


func _names(squad: String) -> Array:
	var out: Array = []
	for m: Array in _squads[squad]:
		out.append(String(m[0]))
	return out


func _start(squad: String) -> Vector3:
	var c := Vector3.ZERO
	for m: Array in _squads[squad]:
		c += (m[2] as Vector3) / (_squads[squad] as Array).size()
	return c


## One plain group click with the veto as given: {squad: its element's `to`} (null when it got none).
func _click(at: Vector3, veto: bool, label: String) -> Dictionary:
	SelectionSquads.GROUP_GUARD = false
	SelectionSquads.GROUP_VETO = veto
	var all: Array = []
	for squad: String in _squads:
		all.append_array(_names(squad))
	_controls.selection.set_units(all)
	RtsControls.order_trace_keep = true
	var said := _controls.order_selection("move", {"to": [at.x, at.z]})
	assert_eq(said, "", "%s: the click was taken" % label)
	var out := {}
	for squad: String in _squads:
		var element: Element = _controls.elements.of(_names(squad)[0])
		out[squad] = Vector3(float(element.task["to"][0]), 0.0, float(element.task["to"][1])) \
				if element != null and element.task.has("to") else null
	for squad: String in _squads:
		var element: Element = _controls.elements.of(_names(squad)[0])
		if element != null:
			_controls.elements.disband(element)
	print("GROUP_VETO %s veto %s -> %s" % [label, veto, out])
	return out


## The click laid OFF and ON: every place today gives that passes the veto is identical ON; every ON place passes the veto.
## Returns [today, vetoed, failing squads today].
func _compare(at: Vector3, label: String) -> Array:
	var today := _click(at, false, label)
	var clicks_before := SelectionSquads.veto_clicks
	var vetoed := _click(at, true, label)
	var again := _click(at, false, label + "-again")
	assert_eq(str(again), str(today), "%s: today's lay is deterministic (two OFF clicks agree)" % label)
	var forward: Vector3 = Match.team_frame(Match.Team.GREEN)["forward"]
	var approach := SelectionSquads.approach_of(_starts(), at, forward)
	var flat := SelectionSquads.veto_front(at, approach.normalized())  # his click, or the bank behind a deck he clicked
	var failing: Array = []
	for squad: String in _squads:
		if today[squad] == null:
			continue
		if SelectionSquads.veto_refuses(today[squad], _start(squad), flat, approach, forward):
			failing.append(squad)
		else:
			assert_eq(vetoed[squad], today[squad], "%s %s: a passing place is byte-identical" % [label, squad])
		if vetoed[squad] != null:
			assert_true(not SelectionSquads.veto_refuses(vetoed[squad], _start(squad), flat, approach, forward),
					"%s %s: the vetoed place passes (%s)" % [label, squad, vetoed[squad]])
	assert_eq(SelectionSquads.veto_clicks - clicks_before, 1 if not failing.is_empty() else 0,
			"%s: the veto counted the click only when a place failed (%s)" % [label, failing])
	print("GROUP_VETO %s failing today: %s" % [label, failing])
	return [today, vetoed, failing]


func _starts() -> Array:
	var out: Array = []
	for squad: String in _squads:
		out.append({"center": _start(squad)})
	return out


## His round-37 Terminus click among the streets: no place fails, the whole click is today's.
func test_terminus_street_click_is_todays_exactly() -> void:
	await _build(44742, "terminus", TERMINUS)
	var read := _compare(TERMINUS_CLICK, "terminus-his37")
	assert_eq((read[2] as Array).size(), 0, "no place fails on his street click")
	assert_eq(str(read[1]), str(read[0]), "the whole click is byte-identical")


## Three squads from their spawn rows down Terminus' east street: a column on the street, today's exactly.
func test_terminus_east_street_click_is_todays_exactly() -> void:
	await _build(3801, "terminus", TERMINUS_SPAWN)
	var read := _compare(Vector3(70, 0, 50), "terminus-east")
	assert_eq((read[2] as Array).size(), 0, "no place fails down the east street")
	assert_eq(str(read[1]), str(read[0]), "the whole click is byte-identical")


## Beside the lock and on the swing bridge's deck: no vetoed place on the south bank (across the canal from his squads).
func test_locks_clicks_keep_the_north_bank() -> void:
	await _build(56416, "locks", LOCKS)
	for case: Array in [[BESIDE_LOCK, "locks-beside"], [ON_DECK, "locks-deck"]]:
		var read := _compare(case[0], case[1])
		var vetoed: Dictionary = read[1]
		for squad: String in _squads:
			assert_true(vetoed[squad] != null, "%s %s got a place" % [case[1], squad])
			if vetoed[squad] == null:
				continue
			var at: Vector3 = vetoed[squad]
			assert_true(at.z > -7.0, "%s %s: not on the south bank (z %.1f)" % [case[1], squad, at.z])

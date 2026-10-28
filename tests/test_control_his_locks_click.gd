extends TestCase
## Round 44 (orders O2): HIS LOCKS GROUP CLICK (2026-10-28T08-21-31-locks.jsonl, seed 56416, Gangs v Condemned, laptop, cap 4).
## At tick 1512 his four squads stood side by side along the north edge (Hunters, Spears, Wrenches in their spawn rows,
## Guns_4 alone just south) and one click "to the west side of the map" became four destinations ~100 m apart north to
## south: Guns_4 (-50.5, 15.2), Hunters (-45.9, 69.5), Spears (7.9, 57.7), Wrenches (-25.5, 117.2). The recording holds each
## squad's `to` and not his click (O1 records it from now on), so this lab lays his squads where they stood on the real
## Locks navmesh, through RtsControls.order_selection as his click goes, and
##   HIS_CLICK_SEARCH=1  searches the west half for the click whose four places match the recording (prints the best);
##   (default)           pins the reproduction at the inferred click and prints the per-stage table (RtsControls.order_trace).

const SQUADS := {
	"Green_Guns": ["Green_Guns_4"],
	"Green_Hunters": ["Green_Hunters_1", "Green_Hunters_2", "Green_Hunters_3", "Green_Hunters_4", "Green_Hunters_5"],
	"Green_Spears": ["Green_Spears_1", "Green_Spears_2", "Green_Spears_3", "Green_Spears_4", "Green_Spears_5"],
	"Green_Wrenches": ["Green_Wrenches_1", "Green_Wrenches_2", "Green_Wrenches_3", "Green_Wrenches_4", "Green_Wrenches_5"],
}
## His living Green vehicles at the census of tick 1500 (12 ticks before the click): unit, position.
const AT_1500 := {
	"Green_Guns_4": ["gang_tank", Vector3(-7.700, 0, 77.600)],
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
	"Green_Wrenches_1": ["gang_support", Vector3(37.400, 0, 89.000)],
	"Green_Wrenches_2": ["gang_support", Vector3(50.400, 0, 89.000)],
	"Green_Wrenches_3": ["gang_support", Vector3(43.900, 0, 89.000)],
	"Green_Wrenches_4": ["gang_ifv", Vector3(47.100, 0, 97.600)],
	"Green_Wrenches_5": ["gang_ifv", Vector3(40.600, 0, 97.600)],
}
## His living Green vehicles at the census of tick 1800 (8 ticks before his second click): mid-move after the first.
const AT_1800 := {
	"Green_Guns_4": ["gang_tank", Vector3(-10.900, 0, 14.000)],
	"Green_Hunters_1": ["gang_ifv", Vector3(-68.400, 0, 81.700)],
	"Green_Hunters_2": ["gang_ifv", Vector3(-38.200, 0, 67.200)],
	"Green_Hunters_3": ["gang_ifv", Vector3(-52.100, 0, 83.600)],
	"Green_Hunters_4": ["gang_ifv", Vector3(-50.800, 0, 63.300)],
	"Green_Hunters_5": ["gang_ifv", Vector3(-29.900, 0, 80.700)],
	"Green_Spears_1": ["gang_scout", Vector3(-52.500, 0, 37.200)],
	"Green_Spears_2": ["gang_scout", Vector3(-23.100, 0, 63.600)],
	"Green_Spears_3": ["gang_scout", Vector3(37.900, 0, 89.800)],
	"Green_Spears_4": ["gang_scout", Vector3(2.400, 0, 25.300)],
	"Green_Spears_5": ["gang_tank", Vector3(64.200, 0, 69.500)],
	"Green_Wrenches_1": ["gang_support", Vector3(-12.500, 0, 77.500)],
	"Green_Wrenches_2": ["gang_support", Vector3(9.300, 0, 94.400)],
	"Green_Wrenches_3": ["gang_support", Vector3(35.700, 0, 77.800)],
	"Green_Wrenches_4": ["gang_ifv", Vector3(-9.700, 0, 112.900)],
	"Green_Wrenches_5": ["gang_ifv", Vector3(-25.600, 0, 116.100)],
}
## The recording's `to` per squad at tick 1512.
const TO_1512 := {
	"Green_Guns": Vector3(-50.459, 0, 15.235), "Green_Hunters": Vector3(-45.852, 0, 69.504),
	"Green_Spears": Vector3(7.903, 0, 57.651), "Green_Wrenches": Vector3(-25.491, 0, 117.244),
}
## The recording's `to` per squad at tick 1808 (his second click, the same army 10 s on).
const TO_1808 := {
	"Green_Guns": Vector3(-59.520, 0, 19.932), "Green_Hunters": Vector3(-65.774, 0, 58.487),
	"Green_Spears": Vector3(-1.055, 0, 66.386), "Green_Wrenches": Vector3(-72.028, 0, 109.730),
}
## The clicks the search inferred (HIS_CLICK_SEARCH=1; the search's output is in the Status). Vector3.ZERO = not yet.
## Tick 1512: the fine search's best (-35, 97) scored 4.5 m over the four squads (laptop, 716e6304e + the trace); tick 1808:
## (-61, 59), 21.8 m (the squads were under way, the census 8 ticks old: a looser pin). Evidence
## `references/round44/orders/o2-his-click-lab-laptop/`.
const INFERRED := {1512: Vector3(-35.0, 0.0, 97.0), 1808: Vector3(-61.0, 0.0, 59.0)}
const PIN_M := {1512: 3.0, 1808: 15.0}
const CASES := {1512: [AT_1500, TO_1512], 1808: [AT_1800, TO_1808]}

var _lab: TacticsLab
var _controls: RtsControls


func teardown() -> void:
	RtsControls.order_trace_keep = false
	SelectionSquads.reset_g1()
	if _lab != null:
		_lab.dispose()
	_lab = null
	super.teardown()


func _all() -> Array:
	var out: Array = []
	for squad: String in SQUADS:
		out.append_array(SQUADS[squad])
	return out


func _build(at: Dictionary) -> void:
	_lab = TacticsLab.create(self, 56416, "locks")
	for unit_name: String in at:
		_lab.unit(Match.Team.GREEN, unit_name, at[unit_name][1], 0.0, String(at[unit_name][0]))
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


## One group click as his: every squad selected, one plain move; {squad: its element's `to`}. Then every element is
## disbanded, so the next click finds the squads as his did (control groups with no element).
func _click(at: Vector3) -> Dictionary:
	_controls.selection.set_units(_all())
	var said := _controls.order_selection("move", {"to": [at.x, at.z]})
	var out := {}
	for squad: String in SQUADS:
		var element: Element = _controls.elements.of(SQUADS[squad][0])
		if element == null or not element.task.has("to"):
			out[squad] = null
			continue
		out[squad] = Vector3(float(element.task["to"][0]), 0.0, float(element.task["to"][1]))
	for squad: String in SQUADS:
		var element: Element = _controls.elements.of(SQUADS[squad][0])
		if element != null:
			_controls.elements.disband(element)
	if said != "":
		print("HIS_CLICK refused at (%.1f, %.1f): %s" % [at.x, at.z, said])
	return out


static func _score(laid: Dictionary, to: Dictionary) -> float:
	var total := 0.0
	for squad: String in to:
		if laid.get(squad) == null:
			return INF
		total += (laid[squad] as Vector3).distance_to(to[squad])
	return total


func _search(xs: Array, zs: Array, best: Array, to: Dictionary) -> void:
	for z: float in zs:
		var row := ""
		for x: float in xs:
			var at := Vector3(x, 0.0, z)
			var score := _score(_click(at), to)
			row += " %5.0f" % score if score < INF else "   inf"
			best.append([score, at])
		print("HIS_CLICK_ROW z=%6.1f:%s" % [z, row])
	best.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


## The layout's own reads at `click`, before the order: the body's heading, how many abreast, the corridor at the click.
func _diagnose(click: Vector3) -> void:
	_controls.selection.set_units(_all())
	var found: Dictionary = _controls.selection_squads()
	var blocks: Array = []
	for squad: Dictionary in found["squads"]:
		blocks.append(_controls._squad_block(squad))
	var forward: Vector3 = Match.team_frame(Match.Team.GREEN)["forward"]
	var heading := SelectionSquads._heading(blocks, Vector3(click.x, 0.0, click.z), null, forward)
	var widest := 0.0
	for block: Dictionary in blocks:
		widest = maxf(widest, float(block["width"]))
		print("HIS_CLICK_BLOCK %s centre (%.1f, %.1f) width %.1f depth %.1f shape %s halt %s" % [(found["squads"][blocks.find(block)]["units"] as Array)[0],
				(block["center"] as Vector3).x, (block["center"] as Vector3).z, float(block["width"]), float(block.get("depth", 0.0)),
				block.get("shape", "-"), block.get("halt", "-")])
	var ground: Tank = _lab.tank_of(_all()[0])
	var drive := SelectionSquads.drive_on(ground)
	var crosses := SelectionSquads.crosses_or_edge(SelectionSquads.crosses_on(ground))
	var across := Vector3(-heading.z, 0.0, heading.x)
	var sides := RtsControls.gate_width(click, across, drive, crosses, SelectionSquads.GROUP_SCAN_M)
	print("HIS_CLICK_DIAG click (%.1f, %.1f) heading (%.2f, %.2f) across (%.2f, %.2f) widest %.1f rank_sizes %s one_rank %s corridor at the click [%.0f, %.0f] m" % [
			click.x, click.z, heading.x, heading.z, across.x, across.z, widest, SelectionSquads.rank_sizes(blocks.size(), widest),
			SelectionSquads._fits_one_rank(blocks), sides[0], sides[1]])
	var raw := SelectionSquads.ranks(blocks, click, null, forward)
	var fitted := SelectionSquads.fit_inside(raw, func(p: Vector3) -> Vector3: return Orders.clamp_to_arena(p))
	for i in blocks.size():
		print("HIS_CLICK_RANKS %s raw (%.1f, %.1f) fitted (%.1f, %.1f) aside %.1f behind %.1f" % [(found["squads"][i]["units"] as Array)[0],
				raw[i].x, raw[i].z, fitted[i].x, fitted[i].z, (fitted[i] - click).dot(across), -(fitted[i] - click).dot(heading)])
	_controls.selection.set_units([])


func test_search_for_his_click() -> void:
	if OS.get_environment("HIS_CLICK_SEARCH") != "1":
		print("HIS_CLICK search skipped (HIS_CLICK_SEARCH=1 runs it)")
		return
	var tick := int(OS.get_environment("HIS_CLICK_TICK")) if OS.get_environment("HIS_CLICK_TICK") != "" else 1512
	var to: Dictionary = CASES[tick][1]
	await _build(CASES[tick][0])
	var best: Array = []
	var xs: Array = []
	var zs: Array = []
	for x in range(-135, 1, 10):
		xs.append(float(x))
	for z in range(-135, 136, 10):
		zs.append(float(z))
	_search(xs, zs, best, to)
	print("HIS_CLICK tick %d coarse best: %s" % [tick, best.slice(0, 8)])
	# Refine round the five best at 2 m.
	var fine: Array = []
	for k in mini(5, best.size()):
		var c: Vector3 = best[k][1]
		var fx: Array = []
		var fz: Array = []
		for dx in range(-8, 9, 2):
			fx.append(c.x + dx)
		for dz in range(-8, 9, 2):
			fz.append(c.z + dz)
		_search(fx, fz, fine, to)
	fine.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	print("HIS_CLICK tick %d fine best: %s" % [tick, fine.slice(0, 8)])
	var top: Vector3 = fine[0][1]
	_diagnose(top)
	RtsControls.order_trace_keep = true
	var laid := _click(top)
	print("HIS_CLICK tick %d best click (%.1f, %.1f) score %.1f: %s" % [tick, top.x, top.z, float(fine[0][0]), laid])
	_print_stages()


func _print_stages() -> void:
	for row: Dictionary in RtsControls.order_trace:
		var text := ""
		for place: Dictionary in row["places"]:
			text += " %s:(%.1f, %.1f)" % [String(place["squad"]).trim_prefix("Green_"), (place["at"] as Vector3).x, (place["at"] as Vector3).z]
		print("HIS_CLICK_STAGE %-14s%s" % [row["stage"], text])


func test_the_inferred_clicks_reproduce_his_places() -> void:
	for tick: int in INFERRED:
		var click: Vector3 = INFERRED[tick]
		if click == Vector3.ZERO:
			print("HIS_CLICK tick %d: no inferred click yet (HIS_CLICK_SEARCH=1 HIS_CLICK_TICK=%d)" % [tick, tick])
			continue
		await _build(CASES[tick][0])
		var kept_before := SelectionSquads.bodies_kept
		var laid_before := SelectionSquads.columns_laid
		_diagnose(click)
		SelectionSquads.COLUMN_TRACE = true
		RtsControls.order_trace_keep = true
		var laid := _click(click)
		SelectionSquads.COLUMN_TRACE = false
		print("HIS_CLICK tick %d at (%.1f, %.1f): bodies_kept +%d columns_laid +%d" % [tick, click.x, click.z,
				SelectionSquads.bodies_kept - kept_before, SelectionSquads.columns_laid - laid_before])
		_print_stages()
		var to: Dictionary = CASES[tick][1]
		var north := INF
		var south := -INF
		for squad: String in to:
			assert_true(laid[squad] != null and (laid[squad] as Vector3).distance_to(to[squad]) < float(PIN_M[tick]),
					"tick %d %s: laid %s v his recording %s" % [tick, squad, laid[squad], to[squad]])
			if laid[squad] != null:
				north = minf(north, (laid[squad] as Vector3).z)
				south = maxf(south, (laid[squad] as Vector3).z)
		# The mechanism (the reproduction, not yet the fix): a westward click laid the squads along a north-south front wider than
		# 80 m, and the column of wedges never ran (today's body kept on the open yard).
		assert_true(south - north > 80.0, "tick %d: his squads' places span %.0f m north to south (the recording: ~100 m)" % [tick, south - north])
		assert_eq(SelectionSquads.columns_laid - laid_before, 0, "tick %d: no column was laid" % tick)
		assert_eq(SelectionSquads.bodies_kept - kept_before, 1, "tick %d: today's body was kept as on clear ground" % tick)
		_lab.dispose()
		_lab = null
		_controls.queue_free()
		await wait_physics_frames(2)

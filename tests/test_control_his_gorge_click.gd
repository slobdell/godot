extends TestCase
## Round 45 (orders O1 / O2): HIS GORGE GROUP CLICK (references/round44/playtest/2026-10-29T09-35-51-gorge.jsonl, seed 91711,
## Gangs v Condemned, laptop, cap 4). At tick 0 (paused) his Hunters, Spears and Wrenches stood in their spawn rows along z 90-99
## and one click at (-43.2, 53.2), just on his side of the west neck of the drop (pits z 38-50; the neck x -48..-32, R45.1), became
## three places on one line 58 m apart laid ACROSS his approach: Spears on the click, Hunters (-76.0, 101.0) 58 m north-west of it
## behind his own start line, Wrenches (-10.4, 5.4) 58 m south-east of it THROUGH the neck and across the drop toward the enemy
## ("a far away waypoint that was north of the bridge for one of the squads"). The replay's order trace (builder0, main 8d59b2bdf):
## `ranks` laid those three, the column (G1 v9) never ran (every place on clear ground), never_behind / ground_cap /
## ground_anchors left them. This lab lays his squads where they spawned on the real Gorge navmesh and clicks as he did.
##   test_today_reproduces_his_places      the mechanism, with the guard OFF (what main does)
##   test_guard_keeps_every_squad_on_his_side   G2 (`--group-guard=on`): every place on his side of the drop, in one body
##   test_veto_keeps_his_spears_and_redeals_the_rest   V1 (round 46, ON): the Spears' place exactly as today, the other two re-dealt

const SQUADS := {
	"Green_Hunters": ["Green_Hunters_1", "Green_Hunters_2", "Green_Hunters_3", "Green_Hunters_4", "Green_Hunters_5"],
	"Green_Spears": ["Green_Spears_1", "Green_Spears_2", "Green_Spears_3", "Green_Spears_4", "Green_Spears_5"],
	"Green_Wrenches": ["Green_Wrenches_1", "Green_Wrenches_2", "Green_Wrenches_3", "Green_Wrenches_4", "Green_Wrenches_5"],
}
## The recording's `spawn` (match row): unit, where it stood at his click (tick 0, nothing had moved).
const AT_0 := {
	"Green_Hunters_1": ["gang_ifv", Vector3(-21.125, 0, 90.000)],
	"Green_Hunters_2": ["gang_ifv", Vector3(-14.625, 0, 90.000)],
	"Green_Hunters_3": ["gang_ifv", Vector3(-8.125, 0, 90.000)],
	"Green_Hunters_4": ["gang_ifv", Vector3(-17.875, 0, 96.500)],
	"Green_Hunters_5": ["gang_scout", Vector3(-11.375, 0, 96.500)],
	"Green_Spears_1": ["gang_scout", Vector3(8.125, 0, 90.000)],
	"Green_Spears_2": ["gang_scout", Vector3(11.375, 0, 96.500)],
	"Green_Spears_3": ["gang_scout", Vector3(17.875, 0, 96.500)],
	"Green_Spears_4": ["gang_scout", Vector3(14.625, 0, 90.000)],
	"Green_Spears_5": ["gang_scout", Vector3(21.125, 0, 90.000)],
	"Green_Wrenches_1": ["gang_support", Vector3(37.375, 0, 90.000)],
	"Green_Wrenches_2": ["gang_support", Vector3(50.375, 0, 90.000)],
	"Green_Wrenches_3": ["gang_support", Vector3(43.875, 0, 90.000)],
	"Green_Wrenches_4": ["gang_artillery", Vector3(47.125, 0, 98.890)],
	"Green_Wrenches_5": ["gang_artillery", Vector3(40.625, 0, 98.890)],
}
## His click (the order rows' `click`) and the `to` each squad got.
const CLICK := Vector3(-43.2177, 0.0, 53.1925)
const TO_0 := {
	"Green_Hunters": Vector3(-76.032, 0, 100.971), "Green_Spears": Vector3(-43.218, 0, 53.193), "Green_Wrenches": Vector3(-10.403, 0, 5.414),
}
## R45.1: the drop's pits run z 38-50; his side is z > 50.
const DROP_NEAR_Z := 50.0

var _lab: TacticsLab
var _controls: RtsControls


func teardown() -> void:
	RtsControls.order_trace_keep = false
	SelectionSquads.GROUP_GUARD = SelectionSquads.guard_default()
	SelectionSquads.GROUP_VETO = SelectionSquads.veto_default()
	SelectionSquads.GROUP_PACK = SelectionSquads.pack_default()
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
	_lab = TacticsLab.create(self, 91711, "gorge")
	for unit_name: String in AT_0:
		_lab.unit(Match.Team.GREEN, unit_name, AT_0[unit_name][1], 0.0, String(AT_0[unit_name][0]))
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


## One group click as his: every squad selected, one plain move; {squad: its element's `to`}.
func _click(at: Vector3) -> Dictionary:
	_controls.selection.set_units(_all())
	RtsControls.order_trace_keep = true
	var started := Time.get_ticks_usec()
	var said := _controls.order_selection("move", {"to": [at.x, at.z]})
	# V3 (round 46, native's ask): his click's own cost, the veto's re-deal (guard_lay) included when it runs.
	print("HIS_GORGE_MS click (%.1f, %.1f) veto %s pack %s: %.2f ms" % [at.x, at.z, SelectionSquads.GROUP_VETO, SelectionSquads.GROUP_PACK,
			(Time.get_ticks_usec() - started) / 1000.0])
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
		print("HIS_GORGE refused at (%.1f, %.1f): %s" % [at.x, at.z, said])
	for row: Dictionary in RtsControls.order_trace:
		var text := ""
		for place: Dictionary in row["places"]:
			text += " %s:(%.1f, %.1f)" % [String(place["squad"]).trim_prefix("Green_"), (place["at"] as Vector3).x, (place["at"] as Vector3).z]
		print("HIS_GORGE_STAGE %-14s%s" % [row["stage"], text])
	return out


func _start_of(squad: String) -> Vector3:
	var start := Vector3.ZERO
	for unit_name: String in SQUADS[squad]:
		start += AT_0[unit_name][1] / (SQUADS[squad] as Array).size()
	return start


## The layout's own reads at his click: the approach, the clear ground across it (the fit), the blocks.
func _diagnose() -> Dictionary:
	_controls.selection.set_units(_all())
	var found: Dictionary = _controls.selection_squads()
	var blocks: Array = []
	for squad: Dictionary in found["squads"]:
		blocks.append(_controls._squad_block(squad))
	var forward: Vector3 = Match.team_frame(Match.Team.GREEN)["forward"]
	var heading := SelectionSquads.approach_of(blocks, CLICK, forward)
	var across := Vector3(-heading.z, 0.0, heading.x)
	var widest := 0.0
	for i in blocks.size():
		var block: Dictionary = blocks[i]
		widest = maxf(widest, float(block["width"]))
		print("HIS_GORGE_BLOCK %s centre (%.1f, %.1f) width %.1f depth %.1f shape %s halt %s halt_depth %.1f" % [(found["squads"][i]["units"] as Array)[0],
				(block["center"] as Vector3).x, (block["center"] as Vector3).z, float(block["width"]), float(block.get("depth", 0.0)),
				block.get("shape", "-"), block.get("halt", "-"), float(block.get("halt_depth", 0.0))])
	var ground: Tank = _lab.tank_of(_all()[0])
	var drive := SelectionSquads.drive_on(ground)
	var crosses := SelectionSquads.crosses_or_edge(SelectionSquads.crosses_on(ground))
	var sides := RtsControls.gate_width(CLICK, across, drive, crosses, SelectionSquads.GROUP_SCAN_M)
	var trimmed := SelectionSquads.guard_trim_sides(CLICK, across, sides, heading, RtsControls.GATE_STEP_M)
	var fit := SelectionSquads.guard_fit(widest, trimmed)
	print("HIS_GORGE_DIAG click (%.1f, %.1f) approach (%.3f, %.3f) across (%.3f, %.3f) widest %.1f clear [%.0f, %.0f] m, cut at the gap [%.0f, %.0f] m, fit %d one_rank %s" % [
			CLICK.x, CLICK.z, heading.x, heading.z, across.x, across.z, widest, sides[0], sides[1], trimmed[0], trimmed[1], fit, SelectionSquads._fits_one_rank(blocks)])
	_controls.selection.set_units([])
	return {"heading": heading, "across": across, "widest": widest, "sides": sides, "fit": fit, "blocks": blocks}


func test_today_reproduces_his_places() -> void:
	await _build()
	SelectionSquads.GROUP_GUARD = false
	SelectionSquads.GROUP_VETO = false  # V1 (round 46): today's lay without the veto is his recording
	var diag := _diagnose()
	var kept_before := SelectionSquads.bodies_kept
	var laid_before := SelectionSquads.columns_laid
	var laid := _click(CLICK)
	print("HIS_GORGE today: %s (bodies_kept +%d columns_laid +%d)" % [laid, SelectionSquads.bodies_kept - kept_before,
			SelectionSquads.columns_laid - laid_before])
	for squad: String in TO_0:
		assert_true(laid[squad] != null and (laid[squad] as Vector3).distance_to(TO_0[squad]) < 3.0,
				"%s: laid %s v his recording %s" % [squad, laid[squad], TO_0[squad]])
	# The mechanism: `ranks` lays three abreast (one rank fits MAX_ABREAST) 58 m apart across a diagonal approach; the column never
	# runs; the neck is no deck and the drive through it is barely longer than the straight line, so the ground cap keeps the far
	# place; never_behind reads along the approach, where the north-west place is level with the click.
	assert_eq(SelectionSquads.columns_laid - laid_before, 0, "no column was laid")
	assert_eq(SelectionSquads.bodies_kept - kept_before, 1, "today's body was kept as on clear ground")
	assert_true((laid["Green_Wrenches"] as Vector3).z < DROP_NEAR_Z, "the Wrenches' place is across the drop (z %.1f)" % (laid["Green_Wrenches"] as Vector3).z)
	assert_true((laid["Green_Hunters"] as Vector3).z > _start_of("Green_Hunters").z, "the Hunters' place is behind their own start")
	assert_true(int(diag["fit"]) == 1, "the ground at his click fits one squad abreast once the scan is cut at the neck: %d" % int(diag["fit"]))


## G2 (O2): the guard ON. Every squad's place is on his side of the drop (z > 50, no pit on the straight leg from his click, not
## through the neck), within one packed body of his click (single file here: the neck leaves room for one abreast), nobody behind
## its own start along the approach; the Spears, nearest, on the click.
func test_guard_keeps_every_squad_on_his_side() -> void:
	await _build()
	SelectionSquads.GROUP_GUARD = true
	var diag := _diagnose()
	var redealt_before := SelectionSquads.guard_relaid
	var capped_before := SelectionSquads.guard_fit_capped
	var laid := _click(CLICK)
	print("HIS_GORGE guard: %s (relaid +%d, fit capped +%d)" % [laid, SelectionSquads.guard_relaid - redealt_before,
			SelectionSquads.guard_fit_capped - capped_before])
	var heading: Vector3 = diag["heading"]
	var across: Vector3 = diag["across"]
	var widest: float = diag["widest"]
	var farthest := 0.0
	for squad: String in SQUADS:
		assert_true(laid[squad] != null, "%s got a place" % squad)
		if laid[squad] == null:
			continue
		var at: Vector3 = laid[squad]
		var start := _start_of(squad)
		var aside := absf((at - CLICK).dot(across))
		var back := (start - CLICK).dot(heading) - (at - CLICK).dot(heading)
		var dist := Vector2(at.x - CLICK.x, at.z - CLICK.z).length()
		farthest = maxf(farthest, dist)
		print("HIS_GORGE guard %s start (%.1f, %.1f) place (%.1f, %.1f) aside %.1f m, behind its start %.1f m, %.1f m from his click" % [
				squad, start.x, start.z, at.x, at.z, aside, back, dist])
		assert_true(at.z > DROP_NEAR_Z, "%s: on his side of the drop (z %.1f)" % [squad, at.z])
		assert_true(not SlotGround.leg_wet(CLICK, at), "%s: no pit on the straight leg from his click" % squad)
		assert_true(not SelectionSquads.beyond_neck(CLICK, at), "%s: not through the neck" % squad)
		assert_true(aside <= widest * 0.5 + SelectionSquads.GUARD_SLACK_M, "%s: on the click line (aside %.1f m)" % [squad, aside])
		assert_true(back <= SelectionSquads.GUARD_BEHIND_M, "%s: not behind its own start (%.1f m)" % [squad, back])
	# Nearest in front: the Hunters (48.6 m from his click) on it, the Spears (70 m) next, the Wrenches (96 m) at the back, one file.
	assert_true((laid["Green_Hunters"] as Vector3).distance_to(CLICK) < 3.0, "the Hunters, nearest, land on his click")
	assert_true((laid["Green_Spears"] as Vector3).distance_to(CLICK) < (laid["Green_Wrenches"] as Vector3).distance_to(CLICK),
			"the Spears stand before the Wrenches")
	assert_true(farthest <= SelectionSquads.guard_last_reach_m + 6.0, "the farthest place is within the body's reach of his click (%.0f m v reach %.0f m)" % [
			farthest, SelectionSquads.guard_last_reach_m])
	# The body in his terms: Spears on the click, Hunters next behind, Wrenches last, one line along his approach.
	# Fit first did it: the body was laid in file (capped under three abreast by the fit), one body laid by the guard.
	assert_eq(SelectionSquads.guard_fit_capped - capped_before, 1, "the lay was capped by the fit at his click")
	assert_eq(SelectionSquads.guard_relaid - redealt_before, 1, "the guard laid his body once")


## The guard's "through a neck" read, pure: his Wrenches' leg threads the west neck (x -48..-32 between two pits) and comes out
## beyond it; the Hunters' leg north-west of the click passes no neck; a leg that ENDS in the neck is not beyond it.
func test_beyond_neck_reads_his_legs() -> void:
	await _build()
	assert_true(SelectionSquads.beyond_neck(CLICK, TO_0["Green_Wrenches"]), "the Wrenches' place is beyond the neck")
	assert_true(not (SelectionSquads.beyond_neck(CLICK, TO_0["Green_Hunters"])), "the Hunters' place is not through a neck")
	assert_true(not (SelectionSquads.beyond_neck(CLICK, Vector3(-40.0, 0.0, 44.0))), "a place in the neck itself is not beyond it")
	assert_true(not (SelectionSquads.beyond_neck(CLICK, Vector3(-40.0, 0.0, 80.0))), "a place behind the click, away from the neck")
	var necks := SelectionSquads.neck_segments()
	print("HIS_GORGE necks: %s" % [necks])
	assert_eq(necks.size(), 4, "Gorge has four necks (two a side between its three drops)")
	var west := necks.filter(func(n: Array) -> bool: return (n[0] as Vector3).z > 0.0 and (n[0] as Vector3).x < 0.0)
	assert_eq(west.size(), 1, "one neck on his side west of the middle")
	if west.size() == 1:
		assert_true(minf((west[0][0] as Vector3).x, (west[0][1] as Vector3).x) == -48.0 and maxf((west[0][0] as Vector3).x, (west[0][1] as Vector3).x) == -32.0
				and absf((west[0][0] as Vector3).z - 44.0) < 0.01, "the west neck runs x -48..-32 at z 44: %s" % [west[0]])


## V1 (round 46, R46.1, the default): today's lay, vetoed. The Wrenches' place (through the neck, across the drop) and the
## Hunters' (61 m west and 8.4 m north of where they stood, 9.3 m farther from his click: behind where they started) fail and are
## re-dealt to seats of the fitted body on his side behind the Spears; the Spears' (on his click) stands EXACTLY as today.
func test_veto_keeps_his_spears_and_redeals_the_rest() -> void:
	await _build()
	SelectionSquads.GROUP_GUARD = false
	SelectionSquads.GROUP_VETO = true
	var clicks_before := SelectionSquads.veto_clicks
	var redealt_before := SelectionSquads.veto_redealt
	var held_before := SelectionSquads.veto_held
	var laid := _click(CLICK)
	print("HIS_GORGE veto: %s (clicks +%d redealt +%d held +%d)" % [laid, SelectionSquads.veto_clicks - clicks_before,
			SelectionSquads.veto_redealt - redealt_before, SelectionSquads.veto_held - held_before])
	assert_eq(SelectionSquads.veto_clicks - clicks_before, 1, "his click had a failing place")
	assert_true(laid["Green_Spears"] != null and (laid["Green_Spears"] as Vector3).distance_to(TO_0["Green_Spears"]) < 0.01,
			"the Spears' place is today's exactly: %s" % [laid["Green_Spears"]])
	var forward: Vector3 = Match.team_frame(Match.Team.GREEN)["forward"]
	for squad: String in SQUADS:
		assert_true(laid[squad] != null, "%s got a place" % squad)
		if laid[squad] == null:
			continue
		var at: Vector3 = laid[squad]
		var start := _start_of(squad)
		print("HIS_GORGE veto %s start (%.1f, %.1f) place (%.1f, %.1f), %.1f m from his click" % [squad, start.x, start.z, at.x, at.z,
				Vector2(at.x - CLICK.x, at.z - CLICK.z).length()])
		assert_true(at.z > DROP_NEAR_Z, "%s: on his side of the drop (z %.1f)" % [squad, at.z])
		assert_true(not SlotGround.leg_wet(CLICK, at), "%s: no pit on the straight leg from his click" % squad)
		assert_true(not SelectionSquads.beyond_neck(CLICK, at), "%s: not through the neck" % squad)
		var approach := SelectionSquads.approach_of([{"center": _start_of("Green_Hunters")}, {"center": _start_of("Green_Spears")},
				{"center": _start_of("Green_Wrenches")}], CLICK, forward)
		assert_true(not SelectionSquads.veto_refuses(at, start, CLICK, approach, forward), "%s: passes the veto" % squad)
	assert_true((laid["Green_Wrenches"] as Vector3).distance_to(TO_0["Green_Wrenches"]) > 1.0, "the Wrenches were re-dealt")
	assert_eq(SelectionSquads.veto_redealt - redealt_before, 2, "two places re-dealt")
	assert_eq(SelectionSquads.veto_held - held_before, 0, "nobody held")
	for moved: String in ["Green_Wrenches", "Green_Hunters"]:
		assert_true((laid[moved] as Vector3).distance_to(TO_0[moved]) > 1.0, "the %s were re-dealt" % moved)
		assert_true((laid[moved] as Vector3).distance_to(CLICK) < _start_of(moved).distance_to(CLICK),
				"the %s' seat is nearer his click than where they stand" % moved)


## V1 pure: the veto reads his three recorded places: the Wrenches' (through the neck) and the Hunters' (behind their start toward
## his base, farther from his click) fail; the Spears' passes.
## A place 30 m behind the Spears' start along the approach fails (sent back); the same place for a squad standing beyond it
## (called back toward his click) passes.
func test_veto_failures_reads_his_places() -> void:
	await _build()
	var blocks: Array = []
	var anchors: Array[Vector3] = []
	for squad: String in SQUADS:
		blocks.append({"center": _start_of(squad), "width": 30.0})
		anchors.append(TO_0[squad])
	var forward: Vector3 = Match.team_frame(Match.Team.GREEN)["forward"]
	var approach := SelectionSquads.approach_of(blocks, CLICK, forward)
	var failed := SelectionSquads.veto_failures(anchors, blocks, CLICK, approach, forward)
	print("HIS_GORGE veto_failures approach (%.3f, %.3f): %s (order %s)" % [approach.x, approach.z, failed, SQUADS.keys()])
	assert_eq(failed, [0, 2] as Array[int], "the Hunters and the Wrenches fail, the Spears pass")
	assert_true(not SelectionSquads.veto_refuses(TO_0["Green_Hunters"], _start_of("Green_Hunters"), CLICK, approach, Vector3.ZERO),
			"without the team's forward the Hunters' place passes (level with his click along the approach)")
	var flat_click := Vector3(CLICK.x, 0.0, CLICK.z)
	var spears := _start_of("Green_Spears")
	var back := spears + approach * -30.0
	assert_true(SelectionSquads.veto_refuses(back, spears, flat_click, approach, forward), "30 m behind the Spears' start: sent back")
	assert_true(not SelectionSquads.veto_refuses(back, back + approach * -40.0, flat_click, approach, forward),
			"the same place for a squad 40 m beyond it: called toward his click, passes")
	assert_true(not SelectionSquads.veto_refuses(spears + approach * -8.0, spears, flat_click, approach, Vector3.ZERO), "8 m back: under the 10 m slack")


## V4 (round 46, R46.2, `--group-pack=on`): the same vetoed click in the tighter file: the Spears on his click as today, the file
## behind it shorter (the brief's target: a 3-squad file within ~50 m of his click; today 65.5 m, packed 44.0 m: the step halves
## but floors at the squads' own pitch), every place passing the veto.
func test_tighter_file_halves_his_file() -> void:
	await _build()
	SelectionSquads.GROUP_GUARD = false
	SelectionSquads.GROUP_VETO = true
	SelectionSquads.GROUP_PACK = false
	var loose := _click(CLICK)
	SelectionSquads.GROUP_PACK = true
	var packed := _click(CLICK)
	var far_loose := 0.0
	var far_packed := 0.0
	var forward: Vector3 = Match.team_frame(Match.Team.GREEN)["forward"]
	var approach := SelectionSquads.approach_of([{"center": _start_of("Green_Hunters")}, {"center": _start_of("Green_Spears")},
			{"center": _start_of("Green_Wrenches")}], CLICK, forward)
	for squad: String in SQUADS:
		far_loose = maxf(far_loose, (loose[squad] as Vector3).distance_to(CLICK))
		far_packed = maxf(far_packed, (packed[squad] as Vector3).distance_to(CLICK))
		assert_true(not SelectionSquads.veto_refuses(packed[squad], _start_of(squad), CLICK, approach, forward), "%s: passes the veto packed" % squad)
	print("HIS_GORGE pack: file %.1f m -> %.1f m: %s" % [far_loose, far_packed, packed])
	assert_true((packed["Green_Spears"] as Vector3).distance_to(TO_0["Green_Spears"]) < 0.01, "the Spears' place is today's exactly")
	assert_true(far_packed <= 50.0, "his three squads within 50 m of his click (%.1f m)" % far_packed)
	assert_true(far_packed < far_loose - 10.0, "a shorter file (%.1f v %.1f m; the step floors at the squads' own pitch)" % [far_packed, far_loose])


## V4 pure: the step halves, never under the squads' own pitch, and is today's with the switch OFF.
func test_pack_step() -> void:
	var blocks := [{"pitch_v": Vector2(14.0, 14.0)}]
	SelectionSquads.GROUP_PACK = false
	assert_eq(SelectionSquads.pack_step(50.0, blocks), 50.0, "OFF: today's step")
	SelectionSquads.GROUP_PACK = true
	assert_eq(SelectionSquads.pack_step(50.0, blocks), 25.0, "ON: half")
	assert_eq(SelectionSquads.pack_step(20.0, blocks), 14.0, "ON: never under the squads' pitch")
	assert_eq(SelectionSquads.pack_step(10.0, blocks), 10.0, "ON: a step already under the pitch stays")

class_name HudCostProbe
extends Node
## Control X4 (CP1's HUD line: ≤ 130 draw calls, ≤ 1 ms of `_process` at 60 vehicles): what each piece of the HUD costs,
## in a live skirmish. After a warm-up it measures the whole HUD, then hides one widget at a time (and stops its
## processing) for PHASE_SECONDS with an `all` phase either side, so a widget's cost is the difference and the battle's
## drift cancels out. Canvas draw calls come from the viewport's own counter, so the 3D scene doesn't blur them.
## `--hud-cost=PATH` on a skirmish: prints HUD_COST lines, writes PATH (JSON), then HUD_COST_DONE and quits.

const WARMUP_SECONDS := 10.0
const PHASE_SECONDS := 1.5

var out_path := ""
var main: Main

var _rows: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run()


func run() -> void:
	var tree := get_tree()
	await tree.create_timer(2.0, true, false, true).timeout
	var controls := main.get_node_or_null("HUD/TacticalMap") as RtsControls
	if controls != null:
		controls.set_paused(false)
	await tree.create_timer(WARMUP_SECONDS, true, false, true).timeout
	var hud := main.get_node("HUD") as CanvasLayer
	var widgets: Array[Node] = []
	for child in hud.get_children():
		if child is CanvasItem and child.name != "TacticalMap":
			widgets.append(child)
	if controls != null:
		for child in controls.get_children():
			if child is CanvasItem:
				widgets.append(child)
	var markers := main.get_node_or_null("SelectionMarkers")
	var baseline := await _measure("all")
	var hud_off := await _measure_hidden("whole_hud", [hud], baseline)
	if controls != null:
		# Every widget under the map at once; the map's own drawing (rings, bars, waypoints) is whole_hud minus the rest.
		await _measure_hidden("tactical_map_children", [controls], baseline, true)
	for widget in widgets:
		await _measure_hidden(String(widget.name), [widget], baseline)
	if markers != null:
		await _measure_hidden("selection_markers_3d", [markers], baseline)
	var vehicles: int = main.game_match.alive_count(Match.Team.GREEN) + main.game_match.alive_count(Match.Team.RUST)
	var report := {"vehicles": vehicles, "screen": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
			"all": baseline, "hud_canvas_draw_calls": baseline["canvas_draw_calls"] - hud_off["canvas_draw_calls"],
			"hud_process_ms": snappedf(baseline["process_ms"] - hud_off["process_ms"], 0.01), "widgets": _rows}
	print("HUD_COST_SUMMARY ", JSON.stringify(report))
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
	print("HUD_COST_DONE")
	tree.quit(0)


func _measure_hidden(label: String, nodes: Array, before: Dictionary, children_only := false) -> Dictionary:
	var hidden: Array = []
	for node: Node in nodes:
		var targets: Array = node.get_children().filter(func(c: Node) -> bool: return c is CanvasItem) if children_only else [node]
		for target: Node in targets:
			hidden.append([target, target.get("visible"), target.process_mode])
			target.set("visible", false)
			target.process_mode = Node.PROCESS_MODE_DISABLED
	var off := await _measure("no_" + label)
	for entry in hidden:
		(entry[0] as Node).set("visible", entry[1])
		(entry[0] as Node).process_mode = entry[2]
	var after := await _measure("all")
	var draws: float = (before["canvas_draw_calls"] + after["canvas_draw_calls"]) / 2.0 - off["canvas_draw_calls"]
	var total: float = (before["draw_calls"] + after["draw_calls"]) / 2.0 - off["draw_calls"]
	var ms: float = (before["process_ms"] + after["process_ms"]) / 2.0 - off["process_ms"]
	var row := {"widget": label, "canvas_draw_calls": roundi(draws), "draw_calls": roundi(total), "process_ms": snappedf(ms, 0.01)}
	_rows.append(row)
	print("HUD_COST ", JSON.stringify(row))
	return off


func _measure(label: String) -> Dictionary:
	var tree := get_tree()
	await tree.process_frame
	await tree.process_frame
	var frames := 0
	var canvas := 0.0
	var total := 0.0
	var process := 0.0
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < PHASE_SECONDS * 1000.0:
		await RenderingServer.frame_post_draw
		frames += 1
		canvas += get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		total += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		process += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	frames = maxi(frames, 1)
	return {"label": label, "frames": frames, "canvas_draw_calls": canvas / frames, "draw_calls": total / frames,
			"process_ms": process / frames}

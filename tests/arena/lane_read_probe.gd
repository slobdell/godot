extends SceneTree
## LaneReadability for every shipping map, as JSON for `tools/street_page.py` (the page is Python; the measurement is
## the game's own GDScript, so it is run, not re-implemented). Headless: pure geometry, no renderer.
##   godot --headless --path . --script res://tests/arena/lane_read_probe.gd -- --out=/abs/path.json

func _initialize() -> void:
	var flags := LaunchFlags.from_environment()
	var out := {}
	for layout_name in Arena.layout_names():
		var data: Dictionary = Arena.load_layout(layout_name)["layout"]
		if data.get("lanes", []).is_empty() or Arena.is_fixture(data):
			continue
		var rows: Array = []
		for row: Dictionary in LaneReadability.measure(data):
			rows.append({"name": row["name"], "throat_m": row["throat_m"], "throat_px": row["throat_px"],
					"visible_fraction": row["visible_fraction"], "hull_px": row["hull_px"], "margin_px": row["margin_px"]})
		out[layout_name] = rows
	var file := FileAccess.open(flags.text("out"), FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "  "))
	file.close()
	print("LANE_READ_PROBE layouts=%d" % out.size())
	quit(0)

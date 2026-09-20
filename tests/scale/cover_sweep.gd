extends SceneTree
## `make arena-cover` (scale, round 9, catalogue row A3): what a hull of each length ACTUALLY gets from each map,
## under `Arena.cover_fraction` -- the mean fraction of a hull's own centreline chord occluded from a watcher on
## the far side of the contested field.
##
##   .tools/.../godot --headless --path . --script res://tests/scale/cover_sweep.gd -- [--arenas=yard,pit] [--json=path]
##
## This is the figure that REPLACES `make arena-report`'s centre-point `hull_cover.reach`. The two are different
## quantities and are deliberately printed apart: the old one is "what share of the field is within 45 m of a prop
## at least as long as the whole hull", a step function of hull length; this one is "how much of the hull is
## actually behind something", which is what the game asks. Both are shown for one round (lesson 49) and then the
## point sample goes.
##
## Prints one `ARENA_COVER {json}` per map and `ARENA_COVER_DONE`. Exits 1 only if it could not run.

const LENGTHS := [2.93, 4.04, 6.0, 8.62, 12.0, 12.19, 12.5, 14.0]
## The contested field, matching `arena_report.FIELD_Z`, sampled on this pitch.
const FIELD_Z := 80.0
const STEP_M := 8.0
## Where the threat stands: beyond the far spawn row, which is the shot cover has to defeat.
const WATCHER_Z := 110.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var flags := LaunchFlags.from_environment()
	var names := Array(flags.text("arenas").split(",", false))
	if names.is_empty():
		names = Array(Arena.layout_names())
	var report := {"lengths": LENGTHS, "maps": {}}
	for name: String in names:
		var loaded := Arena.load_layout(name)
		if loaded.has("error"):
			push_error("arena-cover: %s" % loaded["error"])
			quit(1)
			return
		var tables := CoverTables.build(loaded["layout"])
		if not tables.is_built():
			push_error("arena-cover: %s built no tables" % name)
			quit(1)
			return
		var by_length := {}
		for length: float in LENGTHS:
			by_length[length] = snappedf(_mean_cover(tables, length), 0.001)
		var values: Array = by_length.values()
		report["maps"][name] = {"cells": tables.cell_count(), "by_length": by_length,
				"spread": snappedf(values.max() - values.min(), 0.001)}
		print("ARENA_COVER " + JSON.stringify({"map": name, "by_length": by_length,
				"spread": report["maps"][name]["spread"]}))
	if flags.text("json") != "":
		var file := FileAccess.open(flags.text("json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "  "))
			file.close()
	print("ARENA_COVER_DONE")
	quit()


## Mean occluded chord fraction over the contested field, hull lying across the field, watcher on the far side.
func _mean_cover(tables: CoverTables, length: float) -> float:
	var east := Vector3(1.0, 0.0, 0.0)
	var total := 0.0
	var points := 0
	var z := -FIELD_Z
	while z <= FIELD_Z:
		var x := -FIELD_Z
		while x <= FIELD_Z:
			points += 1
			var viewer := Vector3(x, 0.0, -WATCHER_Z if z > 0.0 else WATCHER_Z)
			total += tables.cover_fraction(viewer, Vector3(x, 0.0, z), east, length)
			x += STEP_M
		z += STEP_M
	return total / maxf(float(points), 1.0)

extends SceneTree
## What A3's tables cost to build, per arena. `Arena._ready()` builds them, and FIGHT's load time is a number the
## lead noticed (round 6: 7.6 s -> 1.4 s), so this stream does not get to add to it silently.
##
##   .tools/.../godot --headless --path . --script res://tests/scale/cover_bench.gd

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for name: String in Arena.ROTATION:
		var loaded := Arena.load_layout(name)
		var best := INF
		var cells := 0
		for run in 3:
			var started := Time.get_ticks_usec()
			var tables := CoverTables.build(loaded["layout"])
			best = minf(best, float(Time.get_ticks_usec() - started) / 1000.0)
			cells = tables.cell_count()
		print("COVER_BENCH %s: %.1f ms, %d x %d cells, %d prefix tables"
				% [name, best, cells, cells, CoverTables.HEADINGS * 4])
	print("COVER_BENCH_DONE")
	quit()

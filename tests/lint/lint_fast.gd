extends SceneTree
## `make lint-fast` (round 41 native N5, R41.2): every listed script loaded in ONE Godot process.
##
## `make lint` checks one script per process (`--check-only`), and each process re-loads that file's whole dependency graph:
## 1,212 files at ~3.5 s each, 715 s of builder0's 2,208 s check, with every other target waiting on it. Here each script is
## loaded once, as a project resource with the class_name globals registered: ~14 s on builder0. Godot prints a broken script's
## `SCRIPT ERROR: Parse Error: ...` with `at: GDScript::reload (res://<file>:<line>)` on stderr; tools/lint_fast.py turns that
## into findings. This script only adds what stderr cannot say: a file that did not load at all, and how many it tried.
##
##     godot --headless --path . --script res://tests/lint/lint_fast.gd -- <file list, one res-relative path a line>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("LINT_FAST usage: -- <file list>")
		quit(2)
		return
	var f := FileAccess.open(args[0], FileAccess.READ)
	if f == null:
		printerr("LINT_FAST cannot read the file list %s" % args[0])
		quit(2)
		return
	var t0 := Time.get_ticks_msec()
	var n := 0
	while not f.eof_reached():
		var p := f.get_line().strip_edges()
		if p.is_empty():
			continue
		n += 1
		var s: Resource = ResourceLoader.load("res://" + p, "", ResourceLoader.CACHE_MODE_REUSE)
		if s == null:
			print("LINT_FAST_NOLOAD %s" % p)
	print("LINT_FAST_DONE files=%d ms=%d" % [n, Time.get_ticks_msec() - t0])
	quit()

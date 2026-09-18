extends SceneTree
## `make arena-reach` (arena X2, round 6): write the covering ranges the exposure analysis assumes into
## build/arena-reach.json, so tools/arena_report.py reads them from the CATALOG instead of carrying its own copy.
##
## The constants in arena_report.py were right when they were written and would have gone stale the next time a
## weapon band moved -- exactly the failure that had its plot printing one "exposure" while its table printed
## another. Engagement.covering_range() is derived from Units.PROFILES + Weapons.PROFILES on purpose; this just
## carries its answer across the language boundary.
##
##   idle    what a defender covers on its OWN judgement  (Engagement.covering_range())
##   posted  what it covers once a commander spends a support-by-fire task, which lifts fire discipline to the
##           weapon's FULL range (squad's `long_shot`). Same median, taken over full range rather than effective.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var full: Array[float] = []
	for unit_id: String in Units.PROFILES:
		var weapon := Weapons.profile(String(Units.PROFILES[unit_id].get("weapon", "")))
		if not weapon.has("effective_range"):
			continue
		full.append(minf(float(weapon.get("range", 0.0)), float(Units.stat(unit_id, "sight_radius", 0.0))))
	full.sort()
	var posted := 0.0
	if not full.is_empty():
		var mid := full.size() / 2
		posted = full[mid] if full.size() % 2 == 1 else (full[mid - 1] + full[mid]) / 2.0
	var out := {"idle": Engagement.covering_range(), "posted": posted, "units": full.size()}
	print("ARENA_REACH %s" % JSON.stringify(out))
	var path := "build/arena-reach.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--json="):
			path = arg.trim_prefix("--json=")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(out, "\t") + "\n")
		file.close()
	quit(0)

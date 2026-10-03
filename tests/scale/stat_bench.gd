extends SceneTree
## S4 (round 16): what one `Units.stat` read costs, untuned, against the pre-S4 form (a "unit.key" String per call),
## measured in the same process. Light: runs locally.
##
##   .tools/.../godot --headless --path . --script res://tests/scale/stat_bench.gd

const CALLS := 200000


func _init() -> void:
	_run.call_deferred()


static func _old_stat(unit_id: String, key: String, fallback: Variant = null) -> Variant:
	Units._ensure_env_tuning()
	var tuned_key := "%s.%s" % [unit_id, key]
	if Units.tuning.has(tuned_key):
		return Units.tuning[tuned_key]
	if not Units.PROFILES.has(unit_id):
		return fallback
	return Units.PROFILES[unit_id].get(key, fallback)


func _run() -> void:
	var ids: Array[String] = ["tank", "scout", "ifv", "law_ifv"]
	var best_old := INF
	var best_new := INF
	for run in 5:
		var started := Time.get_ticks_usec()
		for i in CALLS:
			_old_stat(ids[i & 3], "max_health")
		best_old = minf(best_old, float(Time.get_ticks_usec() - started))
		started = Time.get_ticks_usec()
		for i in CALLS:
			Units.stat(ids[i & 3], "max_health")
		best_new = minf(best_new, float(Time.get_ticks_usec() - started))
	print("STAT_BENCH old %.3f us/call, new %.3f us/call (%d calls, best of 5)"
			% [best_old / CALLS, best_new / CALLS, CALLS])
	quit()

extends SceneTree
## `make show-report ARENA=<name>` (S6): print the patch an arena's `show` key resolves to — every knob it landed on,
## so a wrong value shows up in the artefact instead of in a frame three days later (orchestration.md lesson 44).
##
## With no ARENA it reports every layout in `arenas/`, derived from the directory and never hard-coded (lesson 3), and
## exits non-zero if any of them has a patch the validator refuses. That is what makes a bad patch a build failure
## rather than a silently static arena.

## Arena owns the directory and its listing; deriving the list from it (never hard-coding one) is lesson 3.
const ARENAS_DIR := Arena.LAYOUT_DIR


func _init() -> void:
	var wanted := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--arena="):
			wanted = argument.trim_prefix("--arena=")
	var names := _layout_names()
	if wanted != "":
		if not names.has(wanted):
			printerr("SHOW_REPORT no arena '%s' (have %s)" % [wanted, ", ".join(names)])
			quit(2)
			return
		names = PackedStringArray([wanted])
	var failed := 0
	var patched := 0
	for name in names:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARENAS_DIR.path_join("%s.json" % name)))
		if typeof(data) != TYPE_DICTIONARY:
			printerr("SHOW_REPORT %s: not a JSON object" % name)
			failed += 1
			continue
		var show := Show.new()
		var problem := show.load_patch(data.get("show"), name)
		if problem != "":
			printerr("SHOW_REPORT %s FAILED: %s" % [name, problem])
			failed += 1
			continue
		if not data.has("show"):
			print("SHOW_REPORT %-12s no 'show' key: today's static look" % name)
			continue
		patched += 1
		_print_report(name, show)
	print("SHOW_REPORT_DONE arenas=%d patched=%d failed=%d" % [names.size(), patched, failed])
	quit(1 if failed > 0 else 0)


func _print_report(name: String, show: Show) -> void:
	var report := show.report()
	print("SHOW_REPORT %s" % name)
	var channels: Dictionary = report["channels"]
	var channel_names: Array = channels.keys()
	channel_names.sort()
	for key: Variant in channel_names:
		var row: Dictionary = channels[key]
		print("  channel %-10s %-8s period %6.2f s  phase %5.2f rad  floor %.2f  ceiling %.2f  sharpness %5.1f%s"
				% [key, row["programme"], row["period_s"], row["phase_rad"], row["floor"], row["ceiling"],
				row["sharpness"], "  colour #%s x%.2f" % [row["color"], row["color_mix"]] if row["color"] != "" else ""])
	for entry: Dictionary in report["patch"]:
		print("  patch   %-12s %-7s -> %-10s uniform %-12s spread %.2f"
				% [entry["fixture"], entry["parameter"], entry["channel"], entry["uniform"], entry["spread"]])
	# The number that has to stay small: writes are per PATCH ENTRY, never per instance.
	print("  cost    %d uniform writes per frame from %d patch entries (never per instance)"
			% [report["writes_per_frame"] if report["writes_per_frame"] > 0 else report["bound_patch_entries"],
			report["bound_patch_entries"]])


func _layout_names() -> PackedStringArray:
	var names := Arena.layout_names()
	names.sort()
	return names

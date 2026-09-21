extends SceneTree
## What integer does a Logger actually receive for each kind of engine message?
##
## `make remote T=error-type-probe`. It exists because `tests/run_tests.gd` classifies a message as a
## warning with `error_type == Logger.ERROR_TYPE_WARNING`, and on builder0 a Jolt job-system message that
## Godot's own console printed as `WARNING:` arrived at that check as an ERROR and failed a test whose every
## assertion had passed. A GDScript `push_warning` in the same run classified correctly. So either the enum
## comparison is wrong, or engine-side (C++) warnings carry a different type, or that message is genuinely
## an error its console mislabels -- three different fixes, and guessing between them is how I spent an hour
## on `lint` this morning before a probe settled it in minutes.
##
## It prints the enum's own values, then one PROBE_TYPE line per message observed, and asserts nothing.


class Probe extends Logger:
	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var text := rationale if rationale != "" else code
		print("PROBE_TYPE type=%d | %s | %s:%d in %s" % [error_type, text, file, line, function])


func _initialize() -> void:
	print("PROBE_ENUM error=%d warning=%d script=%d shader=%d" % [
			Logger.ERROR_TYPE_ERROR, Logger.ERROR_TYPE_WARNING,
			Logger.ERROR_TYPE_SCRIPT, Logger.ERROR_TYPE_SHADER])
	OS.add_logger(Probe.new())

	print("PROBE_CASE gdscript push_warning")
	push_warning("PROBE gdscript warning")
	print("PROBE_CASE gdscript push_error")
	push_error("PROBE gdscript error")

	# C++-side paths. Each is only a CANDIDATE: the probe reports what arrives and does not require any of
	# them to produce a message, because a probe that insists on its own expectations answers nothing.
	print("PROBE_CASE image load of a missing file")
	var image := Image.new()
	image.load("res://tests/probes/definitely_not_here.png")

	print("PROBE_CASE resource load of a missing file")
	ResourceLoader.load("res://tests/probes/definitely_not_here.tscn")

	print("PROBE_CASE navigation mesh with no source geometry")
	var mesh := NavigationMesh.new()
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationMeshGenerator.bake_from_source_geometry_data(mesh, source)

	print("PROBE_DONE")
	quit(0)

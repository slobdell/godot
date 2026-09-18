extends TestCase
## Render (round 5, after the 30 Hz tick): every MultiMesh whose instances are written from `_process` must be marked
## not-interpolated, or the renderer logs "[Physics interpolation] MultiMesh interpolation is being triggered from
## outside physics process" on every write and drowns control's clean-console gate. The flag is reset by any
## `instance_count` change, so the rule is that resizes go through FxMultiMesh.

const THEME_DIR := "res://game/theme"


func test_no_theme_code_sets_instance_count_directly() -> void:
	var offenders: Array[String] = []
	for path in _theme_scripts(THEME_DIR):
		if path.ends_with("fx_multimesh.gd"):
			continue
		var line_number := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			line_number += 1
			var code := line.strip_edges()
			if code.begins_with("#") or code.begins_with("##"):
				continue
			if code.contains("instance_count =") and not code.contains("visible_instance_count"):
				offenders.append("%s:%d" % [path, line_number])
	assert_true(offenders.is_empty(),
			"resize through FxMultiMesh.resize() so interpolation stays off after the buffers are rebuilt: %s" % [offenders])


func test_every_mesh_node_is_told_never_to_interpolate() -> void:
	## The node pushes its own interpolation state to the server whenever it changes — entering the tree included —
	## so a server-side flag alone does not hold. One call per mesh node, right where it gets its multimesh.
	var offenders: Array[String] = []
	for path in _theme_scripts(THEME_DIR):
		if path.ends_with("fx_multimesh.gd"):
			continue
		var code := FileAccess.get_file_as_string(path)
		var meshes := code.count(".multimesh = ")
		var switches := code.count("FxMultiMesh.never_interpolated(")
		if meshes != switches:
			offenders.append("%s: %d mesh nodes, %d never_interpolated()" % [path, meshes, switches])
	assert_true(offenders.is_empty(), "each mesh node needs FxMultiMesh.never_interpolated(node): %s" % [offenders])


func test_every_theme_multimesh_goes_through_the_helper() -> void:
	var offenders: Array[String] = []
	for path in _theme_scripts(THEME_DIR):
		var code := FileAccess.get_file_as_string(path)
		if code.contains("MultiMesh.new()") and not code.contains("FxMultiMesh"):
			offenders.append(path)
	assert_true(offenders.is_empty(), "a MultiMesh built without FxMultiMesh is interpolated by the renderer: %s" % [offenders])


func test_the_helper_resizes_and_survives_a_rebuild() -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	FxMultiMesh.resize(multimesh, 8)
	assert_eq(multimesh.instance_count, 8, "it resizes")
	FxMultiMesh.resize(multimesh, 64)
	assert_eq(multimesh.instance_count, 64, "and grows, re-asserting the flag the rebuild cleared")
	FxMultiMesh.no_interpolation(null)  # must not crash where nothing renders

	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	FxMultiMesh.never_interpolated(node)
	assert_true(not node.is_physics_interpolated_and_enabled(), "the node stops claiming interpolation")
	node.free()


func _theme_scripts(directory: String) -> Array[String]:
	var found: Array[String] = []
	for entry in DirAccess.get_directories_at(directory):
		found.append_array(_theme_scripts(directory.path_join(entry)))
	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".gd"):
			found.append(directory.path_join(file))
	return found

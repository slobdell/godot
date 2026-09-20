extends SceneTree
## `make roster-scale`'s Godot half (scale, round 9, contract S1). For every unit in the catalog it reports the
## APPROVED MESH's own size and the box that mesh fills at a chosen length, using feel's
## `SizeLook.box_at_length()` -- called, never reimplemented, because a second copy of that formula in Python is
## exactly the mirror Invariant 0 forbids.
##
##   .tools/.../godot --headless --path . --script res://tests/scale/roster_boxes.gd -- \
##       --roster-json=build/roster-boxes.json [--roster-lengths=gang_tank:14,tank:8.6]
##
## Per unit: `natural` (the model's own [w, h, l] before any fitting, zeros when the unit has no hull art of its
## own and wears the shared dozer instead), `box` (today's hull_size), `target_m` (scale_reference.length_m x
## Units.SCALE_K when the unit carries a reference, overridden by --roster-lengths, else today's length) and
## `box_at_target` (what the mesh's proportions make of that length).
##
## `--roster-lengths` exists so the table can be READ BEFORE the catalog is changed: the reference choices are the
## judgment call in this stream, and they go in front of the orchestrator as numbers, not as a diff.
##
## Exits 1 only if it could not run at all. A surprising box is a finding for the table, not a broken tool.


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var flags := LaunchFlags.from_environment()
	var out_path := flags.text("roster-json")
	var overrides := {}
	for pair in flags.text("roster-lengths").split(",", false):
		var bits := String(pair).split(":", false)
		if bits.size() == 2:
			overrides[bits[0]] = float(bits[1])
	GameTheme.use("cyberpunk")
	var units := {}
	for unit_id: String in Units.PROFILES:
		var natural := SizeLook.natural_size(unit_id)
		var box: Array = Units.stat(unit_id, "hull_size")
		var target := float(box[2])
		if overrides.has(unit_id):
			target = float(overrides[unit_id])
		elif Units.PROFILES[unit_id].has("scale_reference"):
			target = float(Units.PROFILES[unit_id]["scale_reference"]["length_m"]) * Units.SCALE_K
		units[unit_id] = {
			"natural": [snappedf(natural.x, 0.001), snappedf(natural.y, 0.001), snappedf(natural.z, 0.001)],
			"has_mesh": natural.z > 0.01,
			"box": box,
			"muzzle_height": float(Units.stat(unit_id, "muzzle_height")),
			"target_m": snappedf(target, 0.01),
			"box_at_target": SizeLook.box_at_length(unit_id, snappedf(target, 0.01)),
			# feel's round-8 finding, per unit: today's box against the mesh's proportions at TODAY's length.
			"box_at_today": SizeLook.box_at_length(unit_id, float(box[2])),
		}
	var report := {"scale_k": Units.SCALE_K, "rig": Units.RIG_UNIT, "rig_length_m": Units.RIG_LENGTH_M, "units": units}
	if out_path != "":
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file == null:
			push_error("roster_boxes: cannot write %s" % out_path)
			quit(1)
			return
		file.store_string(JSON.stringify(report, "  "))
		file.close()
		print("ROSTER_BOXES -> %s" % out_path)
	print("ROSTER_BOXES_DONE")
	quit()

extends "res://game/theme/cyberpunk/dozer_part.gd"
## The crane carrier's hull (`unit.artillery.hull`, assets X5): the generated model with its four outrigger legs cut
## loose (OutriggerRig) and posed by `set_deployed(ratio)` (0 = stowed for driving, 1 = braced to fire; combat's X5).
## Until gameplay calls it the legs stay down, the pose the lead approved in the concept.

## The legs in the normalized hull (look: make assets-unit THEME=roster UNIT=artillery): outside the wheels on both
## sides, from behind the cab to the tail, below the bed.
const LEG_BOXES: Array[AABB] = [AABB(Vector3(0.0, 0.0, 0.22), Vector3(0.25, 0.6, 0.74)), AABB(Vector3(0.75, 0.0, 0.22), Vector3(0.25, 0.6, 0.74))]

var deployed := 1.0
var legs: Array[MeshInstance3D] = []


func _prepare_model() -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var source := node as MeshInstance3D
		if not (source.mesh is ArrayMesh):
			continue
		for surface in source.mesh.get_surface_count():  # bake imported overrides into the cut meshes' materials
			if source.get_surface_override_material(surface) != null:
				source.mesh.surface_set_material(surface, source.get_surface_override_material(surface))
		var cut := OutriggerRig.cut(source.mesh, LEG_BOXES)
		source.mesh = cut["rest"]
		for leg: Dictionary in cut["legs"]:
			var instance := MeshInstance3D.new()
			instance.name = "Outrigger_%d" % legs.size()
			instance.mesh = leg["mesh"]
			instance.transform = source.transform
			instance.set_meta("side", leg["side"])
			instance.set_meta("rest", source.transform)
			source.get_parent().add_child(instance)
			legs.append(instance)


func set_deployed(ratio: float) -> void:
	deployed = clampf(ratio, 0.0, 1.0)
	for leg in legs:
		var rest: Transform3D = leg.get_meta("rest")
		leg.position = rest.origin + rest.basis * OutriggerRig.offset(leg.get_meta("side"), deployed)

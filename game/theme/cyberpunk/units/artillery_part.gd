extends "res://game/theme/cyberpunk/dozer_part.gd"
## The crane carrier's hull (`unit.artillery.hull`, assets X5): the generated model with its four outrigger legs cut
## loose (OutriggerRig) and posed by `set_deployed(ratio)` (0 = stowed for driving, 1 = braced to fire; combat's X5).
## Tank (combat CP2) calls it every frame; before anything does, the legs stay down (the approved concept's pose).

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


## The crane carrier STOWED, which is the pose it is shot at in while it moves. Measured with the part's own cut and
## its own `offset(side, 0)`, so it cannot drift from what `set_deployed(0)` actually draws — a second copy of the
## leg geometry or a hand-typed width is exactly the mirror that produced the 4.74 m in the first place.
func driving_bounds(source: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for node in source.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		var to_model := _relative_to(instance, source)
		var pieces: Array = []
		if instance.mesh is ArrayMesh:
			var cut := OutriggerRig.cut(instance.mesh, LEG_BOXES)
			if cut["rest"] != null:
				pieces.append([cut["rest"], Vector3.ZERO])
			for leg: Dictionary in cut["legs"]:
				# The leg instance is a sibling carrying `source.transform`, shifted by rest.basis * offset -- which
				# is the same as translating the mesh by `offset` before that transform. Stowed is ratio 0.
				pieces.append([leg["mesh"], OutriggerRig.offset(leg["side"], 0.0)])
		else:
			pieces.append([instance.mesh, Vector3.ZERO])
		for piece: Array in pieces:
			var mesh: Mesh = piece[0]
			if mesh == null or mesh.get_surface_count() == 0:
				continue
			var local := mesh.get_aabb()
			local.position += piece[1] as Vector3
			var box := to_model * local
			result = box if first else result.merge(box)
			first = false
	return result


func set_deployed(ratio: float) -> void:
	deployed = clampf(ratio, 0.0, 1.0)
	for leg in legs:
		var rest: Transform3D = leg.get_meta("rest")
		leg.position = rest.origin + rest.basis * OutriggerRig.offset(leg.get_meta("side"), deployed)

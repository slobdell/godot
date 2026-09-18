class_name CitySkyline
extends MeshInstance3D
## The city around the arena (feel X4, round 6): an open ring of building silhouettes and lit windows far outside the
## stands (skyline.gdshader), so a low camera's horizon lands on a place instead of black. One draw call, no light, no
## shadow, no collision. Built by the cyberpunk arena environment.

const RADIUS := 640.0
const HEIGHT := 220.0
## The ring's foot sits below the floor so no gap shows under the nearest buildings.
const FOOT := -30.0
const SEGMENTS := 128
const SHADER := preload("res://game/theme/fx/shaders/skyline.gdshader")
const GROUND_SHADER := preload("res://game/theme/fx/shaders/city_ground.gdshader")
## The streets out to the ring, just under the arena floor (which covers them inside its 160 m): without them a low or
## far camera saw a void past the stands (control's played session at 12 degrees).
const GROUND_DEPTH := -0.15


func _init() -> void:
	name = "CitySkyline"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mesh = CitySkyline.ring(RADIUS, HEIGHT, FOOT, SEGMENTS)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("height_m", HEIGHT)
	material.set_shader_parameter("circumference_m", TAU * RADIUS)
	material_override = material
	# Drawn whatever the camera's far distance culls around it (the ring is bigger than any sensible AABB test).
	extra_cull_margin = 16384.0
	var ground := MeshInstance3D.new()
	ground.name = "CityGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * RADIUS * 2.0
	ground.mesh = plane
	var ground_material := ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	ground.material_override = ground_material
	ground.position.y = GROUND_DEPTH
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(ground)


## An open cylinder: UV.x once around, UV.y from the foot (0) to the top (1), normals facing the centre. Pure, for tests.
static func ring(radius: float, height: float, foot: float, segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in segments + 1:
		var t := float(i) / segments
		var angle := t * TAU
		var out := Vector3(cos(angle), 0.0, sin(angle))
		for level in 2:
			vertices.append(out * radius + Vector3(0.0, foot + height * level, 0.0))
			normals.append(-out)
			uvs.append(Vector2(t, float(level)))
	for i in segments:
		var a := i * 2
		indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

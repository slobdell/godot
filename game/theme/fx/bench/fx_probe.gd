extends SceneTree
## FX lab support probe: builds one scene with each feature whose Compatibility support was
## [verify] in fx_tricks.md, renders it, and saves a screenshot so a human (or agent) can see
## which ones draw. Left→right: instance-uniform heat glow (3 cubes, 3 values), a Decal on the
## floor, GPUParticles3D sparks, CPUParticles3D sparks, a ReflectionProbe-lit metal sphere.
##   godot --path . --script res://game/theme/fx/bench/fx_probe.gd -- --out=/abs/probe.png

const HEAT_SHADER := """
shader_type spatial;
render_mode unshaded;
instance uniform float heat = 0.0;
void fragment() { ALBEDO = mix(vec3(0.1), vec3(1.0, 0.3, 0.05) * 3.0, heat); }
"""


func _initialize() -> void:
	var root_node := Node3D.new()
	root.add_child(root_node)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.05, 0.1)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.4, 0.4, 0.5)
	root_node.add_child(env)
	env.environment.glow_enabled = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root_node.add_child(sun)
	var camera := Camera3D.new()
	camera.look_at_from_position(Vector3(0, 7, 12), Vector3.ZERO)
	root_node.add_child(camera)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 20)
	floor_mesh.mesh = plane
	root_node.add_child(floor_mesh)

	var shader := Shader.new()
	shader.code = HEAT_SHADER
	var heat_material := ShaderMaterial.new()
	heat_material.shader = shader
	for i in 3:
		var cube := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.material = heat_material
		cube.mesh = box
		cube.position = Vector3(-9 + i * 1.3, 0.5, 0)
		root_node.add_child(cube)
		cube.set_instance_shader_parameter("heat", i / 2.0)

	var decal := Decal.new()
	decal.size = Vector3(3, 2, 3)
	decal.position = Vector3(-3, 0, 0)
	var image := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 1, 1, 1))
	decal.texture_albedo = ImageTexture.create_from_image(image)
	decal.emission_energy = 2.0
	root_node.add_child(decal)

	for gpu in [true, false]:
		var particles: GeometryInstance3D = GPUParticles3D.new() if gpu else CPUParticles3D.new()
		particles.position = Vector3(1.5 if gpu else 5.0, 0.5, 0)
		var quad := QuadMesh.new()
		quad.size = Vector2(0.15, 0.15)
		var spark := StandardMaterial3D.new()
		spark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark.albedo_color = Color(1, 0.8, 0.2) if gpu else Color(0.2, 1, 0.3)
		spark.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		quad.material = spark
		if gpu:
			var p := particles as GPUParticles3D
			p.amount = 200
			p.draw_pass_1 = quad
			var process := ParticleProcessMaterial.new()
			process.direction = Vector3.UP
			process.spread = 60.0
			process.initial_velocity_min = 3.0
			process.initial_velocity_max = 6.0
			p.process_material = process
		else:
			var c := particles as CPUParticles3D
			c.amount = 200
			c.mesh = quad
			c.direction = Vector3.UP
			c.spread = 60.0
			c.initial_velocity_min = 3.0
			c.initial_velocity_max = 6.0
		root_node.add_child(particles)

	var sphere := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	var metal := StandardMaterial3D.new()
	metal.metallic = 1.0
	metal.roughness = 0.05
	sphere_mesh.material = metal
	sphere.mesh = sphere_mesh
	sphere.position = Vector3(8.5, 1, 0)
	root_node.add_child(sphere)
	var probe := ReflectionProbe.new()
	probe.size = Vector3(20, 10, 20)
	probe.position = Vector3(8.5, 2, 0)
	root_node.add_child(probe)
	var neon := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.3, 3, 0.3)
	var neon_material := StandardMaterial3D.new()
	neon_material.emission_enabled = true
	neon_material.emission = Color(1, 0, 0.6)
	neon_material.emission_energy_multiplier = 4.0
	bar.material = neon_material
	neon.mesh = bar
	neon.position = Vector3(10.5, 1.5, 1)
	root_node.add_child(neon)

	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var out := "/tmp/fx_probe.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	root.get_texture().get_image().save_png(out)
	print("FX_PROBE saved ", out)
	quit()

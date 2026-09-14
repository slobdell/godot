extends MeshInstance3D
## Default fog of war (added by gameplay G1 as a placeholder; look & feel owns the real look):
## a ground-hugging sheet over the arena that darkens ground the team can't see right now, and
## darkens never-seen ground more. Driven by VisibilityField's texture (L8: 0 never, ~90 seen, 255 visible).

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D visibility : filter_linear, repeat_disable;
uniform float never_alpha = 0.72;
uniform float seen_alpha = 0.45;
void fragment() {
	float v = texture(visibility, UV).r;
	float seen = smoothstep(0.05, 0.3, v);
	float lit = smoothstep(0.5, 0.95, v);
	ALBEDO = vec3(0.02, 0.03, 0.05);
	ALPHA = mix(mix(never_alpha, seen_alpha, seen), 0.0, lit);
}
"""

var _material := ShaderMaterial.new()


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shader = Shader.new()
	_material.shader.code = SHADER
	material_override = _material


## data: {"texture": Texture2D, "origin": Vector2 (world xz of the texture's top-left), "size": float (meters)}
func setup(data: Dictionary) -> void:
	var size: float = data["size"]
	var origin: Vector2 = data["origin"]
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	mesh = plane
	# PlaneMesh UV (0,0) is at (-x, -z): exactly the texture's top-left at `origin`.
	position = Vector3(origin.x + size / 2.0, 0.06, origin.y + size / 2.0)
	_material.set_shader_parameter("visibility", data["texture"])

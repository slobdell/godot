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
// Round 39 (F1): lit ground clipped to the crews' sight circles as they are now (FogViewers; the cyberpunk shader's clip).
uniform vec4 viewers[64];
uniform int viewer_count = -1;
uniform vec2 origin_m = vec2(-160.0, -160.0);
uniform float size_m = 320.0;
uniform float seen_v = 0.3529;
uniform float clip_soft_m = 1.5;
float clip_to_sight(float v, vec2 at) {
	if (viewer_count < 0 || v <= seen_v) {
		return v;
	}
	float best = 1e9;
	for (int i = 0; i < viewer_count; i++) {
		best = min(best, distance(at, viewers[i].xy) - viewers[i].z);
		if (best <= -clip_soft_m) {
			break;
		}
	}
	return mix(min(v, seen_v), v, 1.0 - smoothstep(-clip_soft_m, 0.0, best));
}
void fragment() {
	float v = clip_to_sight(texture(visibility, UV).r, origin_m + UV * size_m);
	float seen = smoothstep(0.05, 0.3, v);
	float lit = smoothstep(0.5, 0.95, v);
	ALBEDO = vec3(0.02, 0.03, 0.05);
	ALPHA = mix(mix(never_alpha, seen_alpha, seen), 0.0, lit);
}
"""

var _material := ShaderMaterial.new()
var _field: VisibilityField
var _texture: Texture2D
var _looks := 0


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
	_material.set_shader_parameter("size_m", size)
	_material.set_shader_parameter("origin_m", origin)
	_texture = data["texture"]


func _process(_delta: float) -> void:
	if _field == null:
		if _looks >= FogViewers.FIND_FRAMES:
			return
		_looks += 1
		_field = FogViewers.find_field(get_tree(), _texture)
		if _field == null:
			return
	FogViewers.apply(_material, _field)

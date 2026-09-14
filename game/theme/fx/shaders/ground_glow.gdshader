// A single additive radial glow on the floor (non-instanced counterpart of splat.gdshader).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.45, 0.1);
uniform float intensity = 0.8;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float falloff = clamp(1.0 - dot(p, p), 0.0, 1.0);
	float flicker = 0.85 + 0.15 * sin(TIME * 23.0) * sin(TIME * 7.0);
	ALBEDO = color * falloff * falloff * intensity * flicker;
}

// LaneMarks (B10, round 10): a warm pool of light on the pavement at a junction, as a flat additive decal -- no light.
// A smooth radial falloff so the edge never reads as a disc; unshaded, so it costs one texture-free fragment pass.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.71, 0.42);
uniform float energy = 0.55;

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float falloff = pow(clamp(1.0 - r, 0.0, 1.0), 2.2);
	ALBEDO = color * falloff * energy;
	ALPHA = 1.0;
}

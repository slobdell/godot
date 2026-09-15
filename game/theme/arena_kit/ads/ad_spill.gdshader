// The light a giant screen throws on the ground (assets X2): an additive oval tinted by the channel's current ad color
// (AdBroadcast.light_color), brightest near the screen. Painted light, not a real light (references/fx_tricks.md).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.3, 0.3, 0.4, 1.0);
uniform float energy = 0.9;

void fragment() {
	// UV.y = 0 at the far edge, 1 at the screen's foot.
	vec2 p = (UV - vec2(0.5, 1.0)) * vec2(2.0, 1.0);
	float falloff = 1.0 - smoothstep(0.0, 1.0, length(p));
	ALBEDO = color.rgb * falloff * falloff * energy;
}

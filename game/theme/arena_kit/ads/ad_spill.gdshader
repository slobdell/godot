// The light a giant screen throws on the ground (assets X2): an additive oval tinted by the channel's current ad color
// (AdBroadcast.light_color), brightest near the screen. Painted light, not a real light (references/fx_tricks.md).
// fog_disabled (render, round 5): the Compatibility renderer fogs per vertex, so fog on this additive 34 m quad added a
// flat rectangle of fog color that read as a hard-edged box of light once screens stood in the field.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.3, 0.3, 0.4, 1.0);
uniform float energy = 0.9;

void fragment() {
	// UV.y = 0 at the far edge, 1 at the screen's foot.
	vec2 p = (UV - vec2(0.5, 1.0)) * vec2(2.0, 1.0);
	// Render (round 5): cubed, zero well inside the plane's edges, and capped, so a bright ad pools light at the foot of the
	// screen instead of flooding its whole quad (which glow and tonemapping turned into a hard-edged box in the field).
	float falloff = 1.0 - smoothstep(0.0, 0.85, length(p));
	ALBEDO = min(color.rgb * energy, vec3(0.45)) * falloff * falloff * falloff;
}

// Ground light splats: an additive radial glow lying on the floor under each projectile, so the
// ground visibly lights up along the shot's path without a real light. One MultiMesh, one draw.
// Mesh: a 1×1 PlaneMesh (XZ). Per instance: transform scales it into an ellipse along the travel
// direction; COLOR = tint; INSTANCE_CUSTOM.x = intensity (fades with height).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;


// S6, the arena light show (_agents/lighting.md; show carve-out, feel reviews at merge). Defaults are the identity:
// show_level's floor is 1 and its span 0, so show_value() returns exactly 1.0 and nothing changes.
#include "res://game/theme/fx/shaders/show.gdshaderinc"
uniform vec4 show_level = vec4(1.0, 0.0, 0.0, 1.0);
uniform float show_spread = 0.0;
uniform vec3 show_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float show_color_mix = 0.0;

const float SHOW_TAU = 6.28318530718;

varying vec3 v_color;
varying float v_intensity;
varying float v_show_phase;

void vertex() {
	v_color = COLOR.rgb;
	v_intensity = INSTANCE_CUSTOM.x;
	// .y is the pool's own phase, written once when the venue is built. It was a spare lane (projectile splats
	// leave it at 0, which puts every one of them in phase -- exactly today's behaviour).
	v_show_phase = INSTANCE_CUSTOM.y * SHOW_TAU;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float falloff = clamp(1.0 - dot(p, p), 0.0, 1.0);
	ALBEDO = mix(v_color, show_color, show_color_mix) * falloff * falloff * v_intensity
			* show_value(show_level, v_show_phase * show_spread);
}

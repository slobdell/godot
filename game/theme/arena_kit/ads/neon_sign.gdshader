// Neon tube signs on the grandstands (assets stretch): additive glass tubes and their glow from one atlas
// (neon_signs.png: R = tube core, G = glow). Per instance: COLOR = neon color, INSTANCE_CUSTOM.r = atlas row / CELLS,
// .g = flicker seed. Tubes buzz, and now and then one sign stutters like a failing transformer. Visual only.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;
uniform float cells = 4.0;
uniform float energy = 3.6;

// S6, the arena light show (_agents/lighting.md; show carve-out, feel reviews at merge). Defaults are the identity:
// show_level's floor is 1 and its span 0, so show_value() returns exactly 1.0 and nothing changes.
#include "res://game/theme/fx/shaders/show.gdshaderinc"
uniform vec4 show_level = vec4(1.0, 0.0, 0.0, 1.0);
uniform float show_spread = 0.0;
uniform vec3 show_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float show_color_mix = 0.0;

const float SHOW_TAU = 6.28318530718;

varying flat vec4 v_look;
varying vec3 v_color;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void vertex() {
	v_look = INSTANCE_CUSTOM;
	v_color = COLOR.rgb;
}

void fragment() {
	float row = floor(v_look.r * cells + 0.5);
	vec4 tex = texture(atlas, vec2(UV.x, (row + UV.y) / cells));
	float t = TIME + v_look.g * 97.0;
	float buzz = 0.93 + 0.07 * sin(t * 120.0);
	// A stutter: a couple of seconds in every ~20 the sign drops out in bursts.
	float window = step(0.9, hash(floor(t / 2.3) + v_look.g * 13.0));
	float stutter = mix(1.0, step(0.45, hash(floor(t * 14.0))), window);
	float light = (tex.r * 1.6 + tex.g * 0.45) * buzz * stutter;
	// Per-sign phase: INSTANCE_CUSTOM.a, which was written as zero and read by nothing until the show (feel
	// confirmed .b and .a unclaimed, 2026-09-20). No new MultiMesh, no new draw, no new light -- one uniform
	// write drives every sign in the venue and they still chase in order along the stands.
	ALBEDO = mix(v_color, show_color, show_color_mix) * light * energy
			* show_value(show_level, v_look.a * SHOW_TAU * show_spread);
}

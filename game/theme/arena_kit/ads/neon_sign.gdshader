// Neon tube signs on the grandstands (assets stretch): additive glass tubes and their glow from one atlas
// (neon_signs.png: R = tube core, G = glow). Per instance: COLOR = neon color, INSTANCE_CUSTOM.r = atlas row / CELLS,
// .g = flicker seed. Tubes buzz, and now and then one sign stutters like a failing transformer. Visual only.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;
uniform float cells = 4.0;
uniform float energy = 3.6;

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
	ALBEDO = v_color * light * energy;
}

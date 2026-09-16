// Heat haze over fires (feel stretch): camera-facing quads that bend what's behind them with rising, wobbling noise.
// Reads the screen texture, so the tier gates it (high only) and the FX lab measures it. One MultiMesh, one draw.
// Per instance: INSTANCE_CUSTOM = (strength 0..1, seed, unused, unused).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled, shadows_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float now = 0.0;

varying float v_strength;
varying float v_seed;

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), 1.0);
	vec4 view_center = VIEW_MATRIX * vec4(center, 1.0);
	VERTEX = view_center.xyz + vec3(VERTEX.x * size.x, VERTEX.y * size.y, 0.0);
	v_strength = INSTANCE_CUSTOM.x;
	v_seed = INSTANCE_CUSTOM.y;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// Strongest low and in the middle, fading out to the sides and the top.
	float mask = (1.0 - smoothstep(0.2, 0.5, abs(UV.x - 0.5))) * smoothstep(0.0, 0.25, 1.0 - UV.y) * smoothstep(0.0, 0.15, UV.y);
	vec2 flow = vec2(UV.x * 5.0 + v_seed * 13.0, UV.y * 4.0 + now * 2.2);
	vec2 bend = vec2(noise(flow) - 0.5, noise(flow + vec2(7.3, 1.9)) - 0.5);
	vec2 offset = bend * 0.012 * v_strength * mask;
	ALBEDO = texture(screen_texture, SCREEN_UV + offset).rgb;
	ALPHA = mask * v_strength;
}

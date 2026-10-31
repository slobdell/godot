// Mapkit P1 concept (looks page only): a soft column of vent steam, rising noise on a quad, alpha-blended.
// The sight-screen direction C's cost question is exactly this surface's overdraw on the laptop's UHD 620.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

instance uniform float seed = 0.0;
uniform vec3 tint : source_color = vec3(0.78, 0.8, 0.86);
uniform vec3 glow : source_color = vec3(1.0, 0.45, 0.12);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed * 7.13) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float rise = 1.0 - uv.y;  // 0 at the grate, 1 at the top
	vec2 p = vec2(uv.x * 3.0, uv.y * 4.0 + TIME * 0.6 + seed);
	float n = noise(p) * 0.6 + noise(p * 2.3) * 0.4;
	float column = smoothstep(0.5, 0.15 + 0.2 * rise, abs(uv.x - 0.5));
	float a = column * n * smoothstep(1.0, 0.3, rise) * smoothstep(0.0, 0.08, rise);
	ALBEDO = mix(glow, tint, smoothstep(0.0, 0.35, rise));
	ALPHA = clamp(a * 0.75, 0.0, 0.8);
}

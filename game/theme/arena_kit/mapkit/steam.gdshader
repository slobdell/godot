// Mapkit P4 (round 47; the lead's pick C for sight screens): vent steam, soft rising noise on a quad, alpha-blended.
// Per instance (MultiMesh custom data): x = seed. High tier only (overdraw: the laptop's UHD 620 cost, C47.10); the low and
// medium tiers draw the opaque strip curtain instead (sight_screen_prop.gd).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.78, 0.8, 0.86);
uniform vec3 glow : source_color = vec3(1.0, 0.45, 0.12);

varying float v_seed;

void vertex() {
	v_seed = INSTANCE_CUSTOM.x;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + v_seed * 7.13) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	float rise = 1.0 - UV.y;
	vec2 p = vec2(UV.x * 3.0, UV.y * 4.0 + TIME * 0.6 + v_seed);
	float n = noise(p) * 0.6 + noise(p * 2.3) * 0.4;
	float column = smoothstep(0.5, 0.15 + 0.2 * rise, abs(UV.x - 0.5));
	float a = column * n * smoothstep(1.0, 0.3, rise) * smoothstep(0.0, 0.08, rise);
	ALBEDO = mix(glow, tint, smoothstep(0.0, 0.35, rise));
	ALPHA = clamp(a * 0.85, 0.0, 0.85);
}

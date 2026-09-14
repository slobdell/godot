// Flamethrower jet: an open cone drawn additively, white-hot at the nozzle cooling to orange and red,
// with turbulent noise scrolling outward (TIME) and soft edges (view-facing fresnel). No texture.
// CylinderMesh UV.y: 0 at the top cap ring (the nozzle, narrow end) → 1 at the far end.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;

uniform float intensity = 0.6;
uniform float scroll_speed = 3.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	float along = UV.y;
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	vec2 flow = vec2(UV.x * 6.0, along * 5.0 - TIME * scroll_speed);
	float turbulence = noise(flow) * 0.6 + noise(flow * 2.3 + 7.0) * 0.4;
	float body = pow(facing, 3.0) * smoothstep(1.0, 0.5, along) * smoothstep(0.0, 0.04, along);
	// Tongues: turbulence cuts gaps into the jet, more of them farther from the nozzle.
	float tongues = smoothstep(0.35 + along * 0.4, 0.95, turbulence + (1.0 - along) * 0.3);
	float fire = clamp(body * tongues, 0.0, 1.0);
	vec3 hot = mix(vec3(1.0, 0.95, 0.75), vec3(1.0, 0.45, 0.08), smoothstep(0.0, 0.45, along));
	vec3 color = mix(hot, vec3(0.7, 0.08, 0.02), smoothstep(0.45, 0.95, along));
	ALBEDO = color * fire * 2.2 * intensity;
}

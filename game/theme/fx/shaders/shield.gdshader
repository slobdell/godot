// Vehicle energy shield: an ellipsoid shell, invisible at rest. Per instance (set from the hull's
// set_shield while an event is playing): `hit` 1→0 after a hit (rim flare + hex shimmer), `down` 1→0
// when the shield breaks (red crackle), `recharge` 0..1 while recharging (a sweep band climbing the
// shell), `strength` = shield ratio (how solid the hexes look), `ripple` 0→1 after a hit at `ripple_from` (a unit
// direction in the shell's local space; feel X4): a bright ring of cells spreading out from where it was struck.
// Additive, no textures.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;

uniform vec3 color : source_color = vec3(0.4, 0.95, 1.0);
instance uniform float hit = 0.0;
instance uniform float down = 0.0;
instance uniform float recharge = 0.0;
instance uniform float strength = 1.0;
instance uniform vec3 tint = vec3(0.4, 0.95, 1.0);
instance uniform float ripple = 0.0;
instance uniform vec3 ripple_from = vec3(0.0, 0.0, 1.0);

varying vec3 local_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Distance to the nearest hex-cell edge (0 at an edge).
float hex_edge(vec2 p) {
	p *= vec2(1.0, 1.1547);
	vec2 a = mod(p, vec2(1.0, 1.7320508)) - vec2(0.5, 0.8660254);
	vec2 b = mod(p + vec2(0.5, 0.8660254), vec2(1.0, 1.7320508)) - vec2(0.5, 0.8660254);
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 q = abs(g);
	return 0.5 - max(dot(q, vec2(0.8660254, 0.5)), q.y);
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.5);
	vec2 uv = vec2(atan(local_pos.x, local_pos.z) * 2.2, local_pos.y * 3.0);
	float edge = 1.0 - smoothstep(0.0, 0.06, hex_edge(uv * 2.0));
	float shimmer = 0.6 + 0.4 * sin(TIME * 18.0 + uv.y * 6.0 + uv.x * 3.0);
	vec3 team = tint;
	vec3 glow = team * (rim * 1.4 + edge * 0.9 * strength * shimmer) * hit * 2.0;
	// Recharge: a bright band sweeping up the shell.
	float band = 1.0 - smoothstep(0.0, 0.18, abs(local_pos.y - mix(-1.0, 1.0, fract(recharge))));
	glow += team * (band * (0.8 + edge) + rim * 0.25) * step(0.001, recharge) * (1.0 - hit);
	// Down: red-orange crackle in broken cells.
	float cell = hash(floor(uv * 2.0) + floor(TIME * 20.0));
	glow += vec3(1.0, 0.25, 0.1) * edge * step(0.72, cell) * down * 2.5 + vec3(1.0, 0.3, 0.15) * rim * down;
	// Ripple: a ring racing across the shell from the struck point, brightest in the hex edges, with a flash at impact.
	if (ripple > 0.0) {
		float along = acos(clamp(dot(normalize(local_pos), normalize(ripple_from)), -1.0, 1.0)) / 3.14159;
		float front = ripple * 0.85;
		float ring = exp(-pow((along - front) / 0.06, 2.0)) * (1.0 - ripple);
		float core = exp(-along * 18.0) * (1.0 - ripple) * (1.0 - ripple);
		glow += mix(team, vec3(1.0), 0.35) * (ring * (0.6 + edge * 1.6) * 2.2 + core * 4.0);
	}
	ALBEDO = glow;
}

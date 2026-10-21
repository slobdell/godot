// Round 37 (feedback, F1): the rules made visible on the ground, one MultiMesh, one draw. Flat quads just above the floor,
// additive. The instance basis turns the pattern: local +y is the basis's forward (-Z).
// Per instance: COLOR.rgb = tint, COLOR.a = strength (0..1); INSTANCE_CUSTOM = (start s, duration s, size m, kind).
// duration <= 0 = held (rewritten every frame while the fact holds); otherwise it plays once from start.
//   0 hit sector: the struck face's quarter of a ring flares (forward = toward the shot's origin)
//   1 pin ring: a dashed ring that tightens and brightens with how pinned the crew is, four pins pointing in
//   2 reach ring: the Tanker's repair radius, dashed and slowly turning, a faint fill
//   3 mending glow: a soft pulsing disc and a plus under a vehicle being repaired
//   4 sound ripples: arcs running out of the cone (forward = the cone's axis, the quad's edge = its range)
//   5 cone footprint: the cone's whole reach, a faint fill, bright edges and end
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

uniform float now = 0.0;
uniform float cone_half_deg = 20.0;

varying float v_age;
varying float v_kind;
varying float v_held;
varying vec4 v_color;

void vertex() {
	float duration = INSTANCE_CUSTOM.y;
	v_held = step(duration, 0.0);
	v_age = v_held > 0.5 ? 0.5 : (now - INSTANCE_CUSTOM.x) / max(duration, 0.001);
	v_kind = INSTANCE_CUSTOM.w;
	float alive = v_held > 0.5 ? 1.0 : step(0.0, v_age) * step(v_age, 1.0);
	float size = INSTANCE_CUSTOM.z * alive;
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 right = normalize(MODEL_MATRIX[0].xyz);
	vec3 back = normalize(MODEL_MATRIX[2].xyz);
	vec3 world = center + right * VERTEX.x * size - back * VERTEX.y * size + vec3(0.0, 0.11, 0.0);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = vec3(0.0, 1.0, 0.0);
	v_color = COLOR;
}

float band(float value, float at, float width) {
	return 1.0 - smoothstep(width * 0.5, width, abs(value - at));
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);  // +y forward
	float r = length(p);
	float angle = atan(p.x, p.y);  // 0 forward, +/- PI behind
	float t = clamp(v_age, 0.0, 1.0);
	float snap = 1.0 - pow(1.0 - clamp(t / 0.2, 0.0, 1.0), 3.0);
	float fade = v_held > 0.5 ? 1.0 : 1.0 - smoothstep(0.45, 1.0, t);
	float strength = v_color.a;
	float light = 0.0;
	if (v_kind < 0.5) {
		float radius = mix(0.55, 0.8, snap);
		float sector = 1.0 - smoothstep(0.62, 0.82, abs(angle));
		light = band(r, radius, 0.1) * 0.3 + band(r, radius, 0.34) * sector * 2.4;
		light += (1.0 - smoothstep(0.0, 0.5, abs(angle))) * band(r, radius + 0.14, 0.08) * 0.8;
	} else if (v_kind < 1.5) {
		float radius = mix(0.95, 0.72, strength);
		float dashes = step(0.45, fract(angle / 6.2832 * 12.0 + now * 0.35));
		light = band(r, radius, 0.09) * (0.35 + 0.65 * dashes);
		for (int i = 0; i < 4; i++) {
			float a = float(i) * 1.5708 + 0.785;
			float along = abs(sin(angle - a)) * r;
			float inward = smoothstep(radius - 0.32, radius - 0.3, r) * (1.0 - smoothstep(radius - 0.05, radius - 0.03, r));
			light += (1.0 - smoothstep(0.02, 0.05, along)) * inward * step(0.0, cos(angle - a)) * 0.9;
		}
		light *= 0.45 + 0.55 * strength;
	} else if (v_kind < 2.5) {
		float dashes = step(0.5, fract(angle / 6.2832 * 36.0 - now * 0.12));
		light = band(r, 0.97, 0.025) * (0.25 + 0.75 * dashes);
		light += smoothstep(0.55, 0.97, r) * step(r, 0.97) * 0.07;
		light *= strength;
	} else if (v_kind < 3.5) {
		float pulse = 0.65 + 0.35 * sin(now * 5.0);
		light = (1.0 - smoothstep(0.1, 0.95, r)) * 1.1 * pulse;
		float plus = (1.0 - smoothstep(0.06, 0.09, abs(p.x))) * step(abs(p.y), 0.3)
				+ (1.0 - smoothstep(0.06, 0.09, abs(p.y))) * step(abs(p.x), 0.3);
		light += min(plus, 1.0) * 1.6;
		light *= strength;
	} else if (v_kind < 4.5) {
		float half_cone = radians(cone_half_deg);
		float inside = 1.0 - smoothstep(half_cone - 0.03, half_cone + 0.02, abs(angle));
		float ripples = band(fract(r * 4.0 - now * 1.8), 0.5, 0.22) * smoothstep(0.04, 0.15, r) * (1.0 - smoothstep(0.85, 1.0, r));
		light = inside * (ripples * mix(1.0, 0.45, r) + 0.05) * strength;
	} else {
		float half_cone = radians(cone_half_deg);
		float inside = (1.0 - smoothstep(half_cone - 0.01, half_cone + 0.01, abs(angle))) * step(r, 1.0);
		float edge = band(abs(angle), half_cone, 0.03 / max(r, 0.05)) * step(r, 1.0) + band(r, 0.985, 0.025) * inside;
		float flow = 0.5 + 0.5 * sin(r * 26.0 - now * 7.0);
		light = (inside * (0.1 + 0.05 * flow) + edge * 0.9) * smoothstep(0.03, 0.1, r) * strength;
	}
	ALBEDO = v_color.rgb * light * fade;
}

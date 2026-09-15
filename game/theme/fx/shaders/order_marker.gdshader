// Order and selection feedback on the ground (feel X5): one MultiMesh, one draw for every marker. Flat quads just above
// the floor, additive, animated here from a start time.
// Per instance: COLOR.rgb = tint, COLOR.a = phase (trail dots); INSTANCE_CUSTOM = (start s, duration s, size m, kind).
//   0 move: a ring that snaps in and settles, with four ticks     1 attack: a shrinking ring, brackets closing in, a cross
//   2 attack-move: a ring with three chevrons turning inward      3 follow: a ring and a pulsing diamond
//   4 hold: a square frame settling in                             5 stop: an X
//   6 waypoint: a small ring and dot                               7 selection pulse: a ring swelling out and fading
//   8 trail dot: a soft dot with a light running along the trail (steady while it exists)
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

uniform float now = 0.0;

varying float v_age;
varying float v_kind;
varying vec4 v_color;

void vertex() {
	float duration = max(INSTANCE_CUSTOM.y, 0.001);
	v_age = (now - INSTANCE_CUSTOM.x) / duration;
	v_kind = INSTANCE_CUSTOM.w;
	float alive = step(0.0, v_age) * step(v_age, 1.0);
	vec3 center = MODEL_MATRIX[3].xyz;
	vec2 corner = VERTEX.xy * INSTANCE_CUSTOM.z * alive;
	VERTEX = (VIEW_MATRIX * vec4(center.x + corner.x, center.y + 0.09, center.z + corner.y, 1.0)).xyz;
	NORMAL = vec3(0.0, 1.0, 0.0);
	v_color = COLOR;
}

float band(float value, float at, float width) {
	return 1.0 - smoothstep(width * 0.5, width, abs(value - at));
}

float segment(vec2 p, vec2 a, vec2 b, float width) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.00001), 0.0, 1.0);
	return 1.0 - smoothstep(width * 0.5, width, length(pa - ba * h));
}

mat2 rotation(float angle) {
	return mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float t = clamp(v_age, 0.0, 1.0);
	float snap = 1.0 - pow(1.0 - clamp(t / 0.25, 0.0, 1.0), 3.0);
	float fade = 1.0 - smoothstep(0.6, 1.0, t);
	float light = 0.0;
	if (v_kind < 0.5) {
		float radius = mix(0.95, 0.55, snap);
		light = band(r, radius, 0.14) + (1.0 - smoothstep(0.06, 0.1, r)) * 0.8;
		for (int i = 0; i < 4; i++) {
			vec2 dir = rotation(float(i) * 1.5708) * vec2(0.0, 1.0);
			light += segment(p, dir * (radius + 0.08), dir * (radius + 0.25), 0.07);
		}
	} else if (v_kind < 1.5) {
		float radius = mix(1.0, 0.5, snap);
		light = band(r, radius, 0.12);
		vec2 q = rotation(snap * 0.785) * p;
		for (int i = 0; i < 4; i++) {
			vec2 c = rotation(float(i) * 1.5708) * vec2(0.62, 0.62) * mix(1.25, 0.95, snap);
			light += segment(q, c, c + rotation(float(i) * 1.5708) * vec2(-0.3, 0.0), 0.12);
			light += segment(q, c, c + rotation(float(i) * 1.5708) * vec2(0.0, -0.3), 0.12);
		}
		light += (segment(p, vec2(-0.22, 0.0), vec2(0.22, 0.0), 0.05) + segment(p, vec2(0.0, -0.22), vec2(0.0, 0.22), 0.05)) * 0.9;
	} else if (v_kind < 2.5) {
		float radius = mix(0.95, 0.6, snap);
		light = band(r, radius, 0.12);
		vec2 q = rotation(t * 2.2) * p;
		for (int i = 0; i < 3; i++) {
			mat2 turn = rotation(float(i) * 2.0944);
			vec2 tip = turn * vec2(0.0, 0.25);
			light += segment(q, turn * vec2(-0.16, 0.45), tip, 0.11) + segment(q, turn * vec2(0.16, 0.45), tip, 0.11);
		}
	} else if (v_kind < 3.5) {
		light = band(r, mix(0.9, 0.62, snap), 0.12);
		float pulse = 0.28 + 0.06 * sin(now * 12.0);
		light += band(abs(p.x) + abs(p.y), pulse, 0.07) * 1.2;
	} else if (v_kind < 4.5) {
		float half_size = mix(0.9, 0.55, snap);
		light = band(max(abs(p.x), abs(p.y)), half_size, 0.13);
		light *= step(0.15, min(abs(abs(p.x) - abs(p.y)) + 0.2, 1.0));
	} else if (v_kind < 5.5) {
		float arm = mix(0.2, 0.45, snap);
		light = segment(p, vec2(-arm), vec2(arm), 0.1) + segment(p, vec2(-arm, arm), vec2(arm, -arm), 0.1);
	} else if (v_kind < 6.5) {
		light = band(r, 0.7, 0.14) + (1.0 - smoothstep(0.2, 0.3, r));
	} else if (v_kind < 7.5) {
		float radius = mix(0.45, 1.0, 1.0 - pow(1.0 - t, 2.0));
		light = band(r, radius, mix(0.24, 0.1, t)) * (1.0 - t) * 2.0;
		fade = 1.0;
	} else {
		// Trail dot: soft, with a brighter pulse running along the trail (COLOR.a is the dot's place along it).
		float run = 0.55 + 0.45 * pow(0.5 + 0.5 * sin(now * 6.0 - v_color.a * 0.9), 6.0);
		light = (1.0 - smoothstep(0.35, 1.0, r)) * run;
		fade = 1.0;
	}
	// Above 1 so the glow catches it: markers must read from the RTS camera 40 m up.
	ALBEDO = v_color.rgb * light * fade * 2.6;
}

// Round 37 (feedback, his pick "hit C"): the struck face's quarter of a ring flares under the tank, toward where the
// round came from, so a flank or rear hit teaches facing. One MultiMesh, one draw; flat quads just above the floor,
// additive. The instance basis turns the pattern: local +y is the basis's forward (-Z) = toward the shot's origin.
// Per instance: COLOR.rgb = the face's colour, COLOR.a = strength; INSTANCE_CUSTOM = (start s, duration s, size m,
// unused). Plays once. Additive, so the light is clamped: overlapping segments must not bloom into a white disc.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

uniform float now = 0.0;

varying float v_age;
varying vec4 v_color;

void vertex() {
	v_age = (now - INSTANCE_CUSTOM.x) / max(INSTANCE_CUSTOM.y, 0.001);
	float alive = step(0.0, v_age) * step(v_age, 1.0);
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
	float fade = 1.0 - smoothstep(0.45, 1.0, t);
	float radius = mix(0.55, 0.8, snap);
	float sector = 1.0 - smoothstep(0.62, 0.82, abs(angle));
	float light = band(r, radius, 0.1) * 0.25 + band(r, radius, 0.34) * sector * 1.5;
	light += (1.0 - smoothstep(0.0, 0.5, abs(angle))) * band(r, radius + 0.14, 0.08) * 0.6;
	ALBEDO = v_color.rgb * min(light, 1.2) * fade * v_color.a;
}

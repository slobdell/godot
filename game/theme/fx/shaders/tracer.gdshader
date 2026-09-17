// Projectile tracers: one MultiMesh, one draw for every shell in flight.
// Each instance is a quad stretched from the shell (head) back along its +Z (the tail), turned
// around that axis to face the camera. Per instance: COLOR = team tint,
// INSTANCE_CUSTOM = (tail length m, width m, intensity, unused).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

// Values above 1 feed the Environment glow. Render (round 5): 3.0 bloomed every shell into a comet that outshone the
// vehicles at 30 a side (the lead's "I see blue lights", moved from the accents to the effects); now the white-hot core
// still crosses the glow threshold and the body mostly doesn't.
uniform float hdr_boost = 1.5;
// How much of the team color a tracer carries over an incandescent warm white: a hint of who fired, not a neon stripe.
uniform float team_tint = 0.45;
uniform vec3 incandescent : source_color = vec3(1.0, 0.72, 0.42);

varying vec3 v_color;
varying float v_intensity;

void vertex() {
	vec3 head = MODEL_MATRIX[3].xyz;
	vec3 axis = normalize(MODEL_MATRIX[2].xyz);
	vec3 to_camera = normalize(INV_VIEW_MATRIX[3].xyz - head);
	vec3 side = cross(axis, to_camera);
	float side_len = length(side);
	side = side_len > 0.001 ? side / side_len : vec3(1.0, 0.0, 0.0);
	// QuadMesh UV: x across 0..1, y along 0..1 (0 = head).
	vec3 world = head + axis * (UV.y * INSTANCE_CUSTOM.x) + side * ((UV.x - 0.5) * INSTANCE_CUSTOM.y);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_color = COLOR.rgb;
	v_intensity = INSTANCE_CUSTOM.z;
}

void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	float head = 1.0 - UV.y;
	float body = across * across * (0.1 + 0.9 * head * head);
	float core = pow(across, 6.0) * head;
	vec3 tint = mix(incandescent, v_color, team_tint);
	vec3 color = mix(tint, vec3(1.0), core);
	ALBEDO = color * body * v_intensity * hdr_boost;
}

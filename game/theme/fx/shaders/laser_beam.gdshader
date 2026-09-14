// Laser pulses: every beam in one MultiMesh / one draw. A quad from the muzzle (instance origin) to
// the hit point along the instance's +Z (scaled to the beam length), turned around its axis to face
// the camera. White-hot core, colored halo, energy ripples running toward the target, and a fade
// from the start time (no script per frame beyond one `now` uniform).
// Per instance: COLOR = beam tint; INSTANCE_CUSTOM = (length m, start s, duration s, width m).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

uniform float now = 0.0;
uniform float hdr_boost = 4.0;

varying vec3 v_color;
varying float v_fade;
varying float v_length;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 axis = normalize(MODEL_MATRIX[2].xyz);
	float len = INSTANCE_CUSTOM.x;
	float age = (now - INSTANCE_CUSTOM.y) / max(INSTANCE_CUSTOM.z, 0.001);
	v_fade = clamp(1.0 - age, 0.0, 1.0) * step(0.0, age);
	vec3 to_camera = normalize(INV_VIEW_MATRIX[3].xyz - (origin + axis * len * 0.5));
	vec3 side = cross(axis, to_camera);
	side = length(side) > 0.001 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	// Thins as it fades, like a discharging beam.
	float width = INSTANCE_CUSTOM.w * (0.35 + 0.65 * v_fade);
	vec3 world = origin + axis * (UV.y * len) + side * ((UV.x - 0.5) * width);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_color = COLOR.rgb;
	v_length = len;
}

void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	float halo = across * across;
	float core = pow(across, 10.0);
	float ripple = 0.75 + 0.25 * sin(UV.y * v_length * 2.2 - now * 60.0);
	vec3 color = v_color * halo * ripple + vec3(1.0) * core * 1.5;
	ALBEDO = color * v_fade * v_fade * hdr_boost;
}

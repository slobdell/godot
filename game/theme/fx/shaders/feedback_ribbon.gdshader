// Round 37 (feedback, F1 repair a): a mending beam from a Resupply Tanker to the vehicle it repairs -- a ribbon that always
// faces the camera, arched a little, with pulses flowing from the Tanker to its patient. One MultiMesh, one draw.
// Per instance: origin = the Tanker's end, basis z = the vector to the patient's end (its length is the beam's);
// COLOR.rgb = tint, COLOR.a = strength; INSTANCE_CUSTOM = (unused, unused, width m, arch m).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

uniform float now = 0.0;

varying float v_along;
varying float v_length;
varying vec4 v_color;

void vertex() {
	vec3 from = MODEL_MATRIX[3].xyz;
	vec3 span = MODEL_MATRIX[2].xyz;
	float along = VERTEX.y + 0.5;
	float lift = 4.0 * along * (1.0 - along) * INSTANCE_CUSTOM.w;
	vec3 world = from + span * along + vec3(0.0, lift, 0.0);
	vec3 view_point = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	vec3 view_dir = (VIEW_MATRIX * vec4(span, 0.0)).xyz;
	vec3 side = normalize(cross(normalize(view_dir), normalize(view_point)));
	VERTEX = view_point + side * VERTEX.x * INSTANCE_CUSTOM.z;
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_along = along;
	v_length = length(span);
	v_color = COLOR;
}

void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float core = 1.0 - smoothstep(0.1, 0.9, across);
	float pulses = smoothstep(0.55, 0.95, fract(v_along * v_length / 3.0 - now * 2.2));
	float ends = smoothstep(0.0, 0.08, v_along) * (1.0 - smoothstep(0.92, 1.0, v_along));
	ALBEDO = v_color.rgb * core * (0.35 + 1.2 * pulses) * ends * v_color.a;
}

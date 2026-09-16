// Drift marks (feel X6): dark rubber streaks on the floor where a wheeled unit slid. One MultiMesh, one draw. Each
// instance is a 1×1 PlaneMesh stretched by its transform from one wheel position to the next.
// Per instance: INSTANCE_CUSTOM = (start s, duration s, strength 0..1, unused). They fade over their last half.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform float now = 0.0;

varying float v_alpha;

void vertex() {
	float age = (now - INSTANCE_CUSTOM.x) / max(INSTANCE_CUSTOM.y, 0.001);
	v_alpha = INSTANCE_CUSTOM.z * (1.0 - smoothstep(0.5, 1.0, age)) * step(0.0, age) * step(age, 1.0);
	VERTEX.y += 0.03;
}

void fragment() {
	// Soft across the tire's width, a little broken up along it like real rubber.
	float across = 1.0 - smoothstep(0.25, 0.5, abs(UV.x - 0.5));
	float grain = 0.75 + 0.25 * fract(sin(dot(floor(UV * vec2(3.0, 9.0)), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = vec3(0.02, 0.02, 0.025);
	ALPHA = across * grain * v_alpha * 0.5;
}

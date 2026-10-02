shader_type spatial;
// Fleet round 15, F2: a class lamp's amber dome (class_mark.gd). Unshaded and emissive so the night cannot hide it; a
// bright lobe sweeps round the dome as a rotating beacon's reflector does. Each lamp's phase comes from where it stands,
// so a squad's lamps do not flash in step.
render_mode unshaded, cull_back, shadows_disabled;

uniform vec3 amber = vec3(1.0, 0.55, 0.05);
uniform float turns_per_second = 1.3;

varying float lobe;

void vertex() {
	float phase = NODE_POSITION_WORLD.x * 1.7 + NODE_POSITION_WORLD.z * 0.9;
	float angle = atan(VERTEX.z, VERTEX.x);
	lobe = pow(0.5 + 0.5 * cos(angle - TIME * turns_per_second * 6.2831853 - phase), 4.0);
}

void fragment() {
	ALBEDO = amber * (0.55 + 1.6 * lobe);
}

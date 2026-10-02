shader_type spatial;
// Fleet round 15, F2: a class lamp's flare (class_mark.gd). A camera-facing additive glow that flashes each time the
// rotating lamp faces the viewer, with a low steady glow between flashes so the lamp is never simply off. Drawn a
// little toward the camera so the roof it sits on does not cut it in half.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 amber = vec3(1.0, 0.55, 0.05);
uniform float turns_per_second = 1.3;
uniform float steady = 0.28;

varying float flash;

void vertex() {
	// Billboard: keep the node's position, face the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX.z += 0.6;
	float phase = NODE_POSITION_WORLD.x * 1.7 + NODE_POSITION_WORLD.z * 0.9;
	flash = steady + (1.0 - steady) * pow(0.5 + 0.5 * cos(TIME * turns_per_second * 6.2831853 + phase), 8.0);
}

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float glow = clamp(1.0 - r, 0.0, 1.0);
	glow = glow * glow * glow;
	ALBEDO = amber * glow * flash * 1.8;
}

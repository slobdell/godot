// Blob shadows under vehicles (render X3, round 5): dynamic moon shadows cost +4.6 ms GPU on the lead's UHD 620 at
// 30 a side, so each vehicle sits on a soft dark ellipse instead. Multiplies the floor: one MultiMesh, one draw.
// Mesh: a 1x1 PlaneMesh (XZ). Per instance: transform scales it to the hull's footprint; INSTANCE_CUSTOM.x = darkness.
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, fog_disabled;

varying float v_darkness;

void vertex() {
	v_darkness = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// Solid in the middle, feathered at the rim, so it grounds the hull without reading as a decal.
	float shade = smoothstep(1.0, 0.35, length(p)) * v_darkness;
	ALBEDO = vec3(1.0 - shade);
}

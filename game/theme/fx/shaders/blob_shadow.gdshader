// Blob shadows under vehicles (render X3, round 5): dynamic moon shadows cost +4.6 ms GPU on the lead's UHD 620 at
// 30 a side, so each vehicle sits on a soft dark ellipse instead. Multiplies the floor: one MultiMesh, one draw.
// Mesh: a 1x1 PlaneMesh (XZ). Per instance: the transform scales it to the hull's footprint, COLOR.r is how dark it is.
//
// **Alpha-blended black, never blend_mul.** With `blend_mul` the Compatibility renderer drew these MultiMesh quads solid
// black whatever the fragment returned, so every vehicle sat on a hard dark rectangle (the lead, round 5: "every vehicle
// currently has an ugly dark rectangle below it"). Alpha blending with the falloff in ALPHA renders the oval correctly.
// The falloff is measured in the instance's own frame from its transform, which is robust for a MultiMesh.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, fog_disabled;

varying float v_darkness;
varying vec2 v_offset;

void vertex() {
	v_darkness = COLOR.r;
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 along = vec2(MODEL_MATRIX[0].x, MODEL_MATRIX[0].z);
	vec2 across = vec2(MODEL_MATRIX[2].x, MODEL_MATRIX[2].z);
	vec2 from_centre = world.xz - centre.xz;
	// Project onto the instance's own axes, in units of half its size (so a corner is (1, 1)).
	v_offset = vec2(dot(from_centre, normalize(along)) / (0.5 * length(along)),
			dot(from_centre, normalize(across)) / (0.5 * length(across)));
}

void fragment() {
	float falloff = clamp(1.0 - length(v_offset), 0.0, 1.0);
	float shade = falloff * falloff * (3.0 - 2.0 * falloff) * v_darkness;
	ALBEDO = vec3(0.0);
	ALPHA = shade;
}

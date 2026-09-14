// Ground light splats: an additive radial glow lying on the floor under each projectile, so the
// ground visibly lights up along the shot's path without a real light. One MultiMesh, one draw.
// Mesh: a 1×1 PlaneMesh (XZ). Per instance: transform scales it into an ellipse along the travel
// direction; COLOR = tint; INSTANCE_CUSTOM.x = intensity (fades with height).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

varying vec3 v_color;
varying float v_intensity;

void vertex() {
	v_color = COLOR.rgb;
	v_intensity = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float falloff = clamp(1.0 - dot(p, p), 0.0, 1.0);
	ALBEDO = v_color * falloff * falloff * v_intensity;
}

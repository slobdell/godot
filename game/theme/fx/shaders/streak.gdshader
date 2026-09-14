// Wet-asphalt reflections without SSR: under each bright source, a streak of light lies on the
// ground stretching toward the viewer, rippled like a wet floor. Oriented in the vertex shader from
// the camera, so static instances look right from any view, and faded out when looking straight
// down (a real reflection needs a grazing angle). One MultiMesh, one draw for the whole arena.
// Per instance: origin = source foot on the ground; COLOR = tint; INSTANCE_CUSTOM = (length m, width m, intensity, seed).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

varying vec3 v_color;
varying float v_intensity;
varying float v_seed;
varying float v_along_m;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 back = INV_VIEW_MATRIX[2].xyz;   // camera +Z: from the scene toward the viewer
	vec2 toward = back.xz;
	float grazing = length(toward);        // 0 looking straight down, ~1 looking level
	toward = grazing > 0.001 ? toward / grazing : vec2(0.0, 1.0);
	vec2 side = vec2(-toward.y, toward.x);
	float len = INSTANCE_CUSTOM.x;
	float width = INSTANCE_CUSTOM.y;
	// QuadMesh UV.y 0..1 along the streak (0 at the source), UV.x across.
	vec2 p = origin.xz + toward * (UV.y * len) + side * ((UV.x - 0.5) * width);
	VERTEX = (VIEW_MATRIX * vec4(p.x, 0.07, p.y, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_color = COLOR.rgb;
	v_intensity = INSTANCE_CUSTOM.z * smoothstep(0.25, 0.7, grazing);
	v_seed = INSTANCE_CUSTOM.w;
	v_along_m = UV.y * len;
}

void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	float along = 1.0 - UV.y;
	// Ripples: broken bands that drift slowly.
	float ripple = 0.55 + 0.45 * sin(v_along_m * 2.3 + v_seed * 17.0 + TIME * 0.7) * sin(v_along_m * 0.9 - TIME * 0.3);
	float body = pow(across, 2.5) * along * along;
	ALBEDO = v_color * body * ripple * v_intensity;
}

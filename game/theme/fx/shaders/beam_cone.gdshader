// Fake volumetric light beam (floodlights, searchlights): an open cone mesh drawn additively,
// brightest where the surface faces the camera (the thick middle of the beam) and fading toward
// the far end, with a slow noise drift so the air seems to move. No fog volumes needed.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(0.6, 0.85, 1.0);
uniform float energy = 0.25;
// CylinderMesh UV.y runs 0 (top: the lamp) to 1 (the far end).
uniform float end_fade = 1.2;

varying vec3 world_pos;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float along = pow(clamp(1.0 - UV.y, 0.0, 1.0), end_fade);
	float drift = 0.85 + 0.15 * sin(world_pos.y * 0.7 + TIME * 0.8 + world_pos.x * 0.3);
	ALBEDO = color * energy * facing * facing * along * drift;
}

// Fake volumetric light beam (floodlights, searchlights): an open cone mesh drawn additively,
// brightest where the surface faces the camera (the thick middle of the beam) and fading toward
// the far end, with a slow noise drift so the air seems to move. No fog volumes needed.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(0.6, 0.85, 1.0);
uniform float energy = 0.25;
// CylinderMesh UV.y runs 0 (top: the lamp) to 1 (the far end).
uniform float end_fade = 1.2;

// S6, the arena light show (_agents/lighting.md; show carve-out, feel reviews at merge). Defaults are the identity:
// show_level's floor is 1 and its span 0, so show_value() returns exactly 1.0 and nothing changes.
#include "res://game/theme/fx/shaders/show.gdshaderinc"
uniform vec4 show_level = vec4(1.0, 0.0, 0.0, 1.0);
uniform float show_spread = 0.0;
uniform vec3 show_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float show_color_mix = 0.0;

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
	// Per-tower phase: where the lamp stands round the venue, so four corner towers rise in sequence rather than
	// together. The same ordered angle the perimeter rim uses.
	float show_phase = atan(NODE_POSITION_WORLD.x, NODE_POSITION_WORLD.z) * show_spread;
	ALBEDO = mix(color, show_color, show_color_mix) * energy * facing * facing * along * drift
			* show_value(show_level, show_phase);
}

// Emissive neon: strips, light bars, signage. Unshaded (no light cost), HDR so glow catches it.
// Flicker/buzz runs here from TIME with a phase taken from the object's world position, so many
// props share ONE material and still flicker independently, with no script.
shader_type spatial;
render_mode unshaded, fog_disabled;

uniform vec3 color : source_color = vec3(0.0, 0.95, 1.0);
uniform float energy = 3.0;
// 0 = steady, 1 = a failing sign that drops out now and then.
uniform float flicker = 0.15;
// Slow breathing amplitude (0..1).
uniform float breathe = 0.15;
uniform float breathe_speed = 0.6;

// S6, the arena light show (_agents/lighting.md; show carve-out, feel reviews at merge). The lead: "the arena edges
// right now are just a dull neon purple. Those could easily have a breathing effect as well." The rim's six edges
// share ONE cached material (CyberMaterials.neon(..., fixture: &"rim")), so these two writes drive the whole ring,
// and the per-edge phase below is the edge's ANGLE around the venue -- so a chase or a sweep travels round the
// hexagon in order, instead of scattering the way the flicker's spatial hash does.
// Defaults are today's look exactly: show_level's floor is 1 and its span 0, so show_value() returns 1.0.
#include "res://game/theme/fx/shaders/show.gdshaderinc"
uniform vec4 show_level = vec4(1.0, 0.0, 0.0, 1.0);
uniform float show_spread = 0.0;
uniform vec3 show_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float show_color_mix = 0.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	float phase = dot(NODE_POSITION_WORLD, vec3(0.731, 0.0, 1.379));
	float t = TIME + phase * 7.0;
	float wave = 1.0 - breathe * (0.5 + 0.5 * sin(t * breathe_speed));
	// Dropouts: pick a random ~10% of 0.08 s slots to dim.
	float slot = floor(t * 12.5);
	float drop = step(0.9, hash(slot + phase)) * flicker;
	// Where this piece of neon sits around the venue, in radians. An ordered phase, not a hash.
	float show_phase = atan(NODE_POSITION_WORLD.x, NODE_POSITION_WORLD.z) * show_spread;
	ALBEDO = mix(color, show_color, show_color_mix) * energy * wave * (1.0 - drop * 0.85)
			* show_value(show_level, show_phase);
}

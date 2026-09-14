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
	ALBEDO = color * energy * wave * (1.0 - drop * 0.85);
}

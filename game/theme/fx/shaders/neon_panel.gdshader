// A flat emissive panel for prop tops and signage, readable from the tactical camera (~3 px/m):
// a glowing border, diagonal hazard stripes in the corners, and a dim inner fill with a slow scan.
// Unshaded (no light cost); flicker phase from world position so props sharing it stay independent.
shader_type spatial;
render_mode unshaded, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.0, 0.6);
uniform vec3 fill_color : source_color = vec3(0.05, 0.03, 0.08);
uniform float energy = 2.5;
// Border width as a fraction of the panel's shorter side.
uniform float border = 0.09;
uniform float stripes = 1.0;
// Panel aspect (x/y) so borders and stripes stay square on long panels.
uniform float aspect = 1.0;

void fragment() {
	float phase = dot(NODE_POSITION_WORLD, vec3(0.53, 0.0, 0.71));
	vec2 p = vec2(UV.x * aspect, UV.y);
	vec2 edge = min(p, vec2(aspect, 1.0) - p);
	float d = min(edge.x, edge.y);
	float rim = 1.0 - smoothstep(border * 0.7, border, d);
	// Hazard stripes near the two short ends.
	float end_zone = step(min(p.x, aspect - p.x), 0.28);
	float stripe = step(0.5, fract((p.x + p.y) * 4.0)) * end_zone * stripes * (1.0 - rim);
	float scan = 0.85 + 0.15 * sin(p.y * 30.0 - TIME * 2.0 + phase);
	float breathe = 0.9 + 0.1 * sin(TIME * 0.8 + phase * 5.0);
	vec3 lit = color * energy * (rim + stripe * 0.45) * breathe;
	ALBEDO = fill_color * scan + lit;
}

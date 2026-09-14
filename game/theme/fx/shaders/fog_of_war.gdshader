// Cyberpunk fog of war: a sheet on the floor over the whole arena, driven by gameplay's visibility
// texture (R: 0 never seen, ~0.35 seen before, 1 visible now). Never-seen ground sinks into a dark
// digital haze with faint grid static; remembered ground is dimmed; the edge of current vision glows
// a soft cyan like a sensor boundary, with a slow radar sweep. One alpha-blended draw.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D visibility : filter_linear, repeat_disable;
uniform float never_alpha = 0.78;
uniform float seen_alpha = 0.45;
uniform vec3 haze : source_color = vec3(0.01, 0.012, 0.03);
uniform vec3 edge_color : source_color = vec3(0.0, 0.85, 1.0);
uniform float edge_strength = 0.55;
// Arena size in meters (the sheet's UV spans it), for world-scale patterns.
uniform float size_m = 320.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

void fragment() {
	float v = texture(visibility, UV).r;
	float seen = smoothstep(0.05, 0.3, v);
	float lit = smoothstep(0.5, 0.95, v);
	vec2 world = UV * size_m;
	// Grid static: faint lines every 4 m that shimmer, only in the unknown.
	vec2 cell = abs(fract(world / 4.0) - 0.5);
	float grid = (1.0 - smoothstep(0.46, 0.5, max(cell.x, cell.y))) * (1.0 - seen);
	float static_noise = hash(floor(world * 0.5) + floor(TIME * 6.0)) * 0.08 * (1.0 - seen);
	float sweep = pow(fract(UV.y * 0.6 - TIME * 0.05), 30.0) * 0.25 * (1.0 - lit);
	// Vision boundary: a soft band where visibility crosses into "visible now".
	float edge = smoothstep(0.3, 0.6, v) * (1.0 - smoothstep(0.6, 0.92, v));
	float alpha = mix(mix(never_alpha, seen_alpha, seen), 0.0, lit);
	vec3 color = haze + edge_color * (grid * 0.05 + static_noise + sweep * 0.3);
	ALBEDO = mix(color, edge_color, edge * edge_strength);
	ALPHA = max(alpha, edge * edge_strength * 0.8);
}

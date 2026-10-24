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
// Round 39 (feedback F1, his "never hide an enemy inside a range the player was shown"): the field's picture can be two
// refreshes old, so lit ground is clipped to each crew's sight circle as it is NOW (FogViewers: x, z, radius per crew;
// -1 = no clip). `origin_m` is the world xz of UV (0, 0). Keep `clip_to_sight` in step with FogViewers.shown.
uniform vec4 viewers[64];
uniform int viewer_count = -1;
uniform vec2 origin_m = vec2(-160.0, -160.0);
uniform float seen_v = 0.3529;
uniform float clip_soft_m = 1.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

float clip_to_sight(float v, vec2 at) {
	if (viewer_count < 0 || v <= seen_v) {
		return v;
	}
	float best = 1e9;
	for (int i = 0; i < viewer_count; i++) {
		best = min(best, distance(at, viewers[i].xy) - viewers[i].z);
		if (best <= -clip_soft_m) {
			break;
		}
	}
	float inside = 1.0 - smoothstep(-clip_soft_m, 0.0, best);
	return mix(min(v, seen_v), v, inside);
}

void fragment() {
	float v = clip_to_sight(texture(visibility, UV).r, origin_m + UV * size_m);
	// Round 16 (R3): ground in sight now is exactly transparent -- at v >= 0.95 `lit` is 1, so `alpha` is 0, and `edge`
	// is 0 (its falloff ends at 0.92) -- and a mix-blend at alpha 0 writes back the pixel already there. Leave before
	// the grid, the static and the sweep are worked out: the same picture, a fraction of the work where it matters most
	// (around his own units, the middle of his screen).
	if (v >= 0.95) {
		discard;
	}
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
	// Round 16 (R3): ground in sight now (v >= 0.95) is exactly alpha 0, and a mix-blend at alpha 0 writes back the
	// pixel already there -- so skip the blend. Same picture, less framebuffer traffic on the biggest sheet on screen.
	if (ALPHA <= 0.0) {
		discard;
	}
}

// The arena floor (art X2/X3, 2026-09-14), shared by arena_ground.gdshader (tier high) and arena_ground_lite.gdshader
// (low/medium): cracked asphalt (CC0 ambientCG, tools/assets/build_ground.py) under a baked macro map (weathering,
// concrete slabs, oil), worn procedural hazard paint, and painted floodlight pools. Built for the Compatibility
// renderer's cost model, measured in make fx-bench (configs ground_*): texture fetches are what costs, so static
// variation is baked into `arena_macro` (one fetch for the whole floor) and the floodlights into `flood_map` (a light
// map the arena dressing bakes from its lamps). GROUND_HIGH adds a second asphalt sample against tiling, skid marks,
// and drains (5 fetches, drains only where drawn; lite: 3). A normal map cost 2 ms at tier high for relief the RTS
// camera barely shows, so there is none.

uniform sampler2D asphalt_albedo : source_color, filter_linear_mipmap, repeat_enable;  // A = roughness
uniform sampler2D arena_macro : source_color, filter_linear, repeat_disable;           // RGB ×1.5 multiplier, A gloss
uniform sampler2D flood_map : hint_default_black, filter_linear, repeat_disable;       // R × flood_scale
#ifdef GROUND_HIGH
uniform sampler2D detail_masks : hint_default_black, filter_linear_mipmap, repeat_enable;  // R tire, A fine noise
uniform sampler2D drain_texture : source_color, filter_linear_mipmap, repeat_disable;     // A = coverage
#endif

uniform float arena_half = 160.0;
uniform float flood_scale = 2.0;
uniform vec3 flood_color : source_color = vec3(0.92, 0.94, 1.0);
// A floor of light everywhere, so the unlit corners are dim rather than black.
uniform float flood_base = 0.05;
uniform float tile_meters = 6.0;
uniform float brightness = 0.85;
uniform vec3 tint : source_color = vec3(0.96, 0.96, 1.0);
uniform float tire_amount = 0.3;

uniform vec3 hazard_yellow : source_color = vec3(0.78, 0.56, 0.06);
// The painted perimeter band starts here (just inside the walls at ±121) and is `band_width` wide.
uniform float band_inner = 108.0;
uniform float band_width = 3.0;
uniform float ring_radius = 16.0;
uniform float ring_width = 1.4;

uniform float drain_spacing = 26.0;
uniform float drain_size = 1.6;

#ifdef GROUND_UNLIT
// The light the renderer would have added (arena_environment.tscn): ambient color × energy, and the moon's color ×
// energy × N·L / π (Lambert) for a flat floor, raised to stand in for the lit floor's soft specular sheen; matched by eye
// against the lit floor (make perf-scene layer ground_lit).
uniform vec3 ambient_light = vec3(0.275, 0.29, 0.35);
uniform vec3 key_light = vec3(0.62, 0.63, 0.67);
#endif

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 arena_uv = p / (2.0 * arena_half) + 0.5;
	vec4 macro = texture(arena_macro, arena_uv);
	vec2 uv_a = p / tile_meters;
	vec4 asphalt = texture(asphalt_albedo, uv_a);
#ifdef GROUND_HIGH
	// A second, rotated and larger sample fades in by the macro weathering so the 6 m tile never forms a grid.
	vec4 asphalt_b = texture(asphalt_albedo, mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p / (tile_meters * 2.3) + vec2(0.37, 0.71));
	asphalt = mix(asphalt, asphalt_b, smoothstep(0.5, 0.62, macro.g));
#endif
	vec3 albedo = asphalt.rgb * macro.rgb * 1.5;
	float rough = mix(asphalt.a, 0.3, macro.a);

#ifdef GROUND_HIGH
	vec4 detail = texture(detail_masks, p / 37.0);
	albedo *= 1.0 - detail.r * tire_amount * 0.6;
	float wear_noise = detail.a;
#else
	float wear_noise = asphalt.g;
#endif

	// Worn hazard paint: a striped band inside the walls and a striped ring around the center.
	float edge = max(abs(p.x), abs(p.y));
	float band = step(band_inner, edge) * step(edge, band_inner + band_width);
	float band_stripes = step(0.5, fract((p.x + p.y) / 2.8));
	float ring = 1.0 - smoothstep(ring_width * 0.5 - 0.05, ring_width * 0.5 + 0.05, abs(length(p) - ring_radius));
	float ring_stripes = step(0.5, fract(atan(p.y, p.x) / 6.28318 * 40.0));
	float painted = max(band, ring) * smoothstep(0.3, 0.6, wear_noise * 0.6 + asphalt.r * 0.8);
	vec3 paint = mix(vec3(0.02), hazard_yellow, band > 0.5 ? band_stripes : ring_stripes);
	albedo = mix(albedo, paint * mix(0.75, 1.0, asphalt.g), painted * 0.9);
	rough = mix(rough, 0.6, painted);

#ifdef GROUND_HIGH
	// Drains on a sparse grid; which cells get one comes from the macro map at the cell center.
	vec2 cell_center = (floor(p / drain_spacing) + 0.5) * drain_spacing;
	vec2 drain_uv = (p - cell_center) / drain_size + 0.5;
	float inside = step(0.0, drain_uv.x) * step(drain_uv.x, 1.0) * step(0.0, drain_uv.y) * step(drain_uv.y, 1.0);
	if (inside * (1.0 - band) > 0.5) {  // only the few pixels over a drain cell pay for these fetches
		float picked = step(0.62, fract(textureLod(arena_macro, cell_center / (2.0 * arena_half) + 0.5, 0.0).g * 37.0));
		vec4 grate = textureLod(drain_texture, drain_uv, 0.0);
		albedo = mix(albedo, grate.rgb * 0.6, picked * grate.a);
	}
#endif

	ALBEDO = albedo * brightness * tint;
	ROUGHNESS = max(rough, 0.45);
	METALLIC = 0.0;
	SPECULAR = 0.3;
#ifdef GROUND_UNLIT
	vec3 flood = albedo * brightness * tint * flood_color * (flood_base + texture(flood_map, arena_uv).r * flood_scale);
	ALBEDO = albedo * brightness * tint * (ambient_light + key_light) + flood;
#else
	EMISSION = ALBEDO * flood_color * (flood_base + texture(flood_map, arena_uv).r * flood_scale);
#endif
}

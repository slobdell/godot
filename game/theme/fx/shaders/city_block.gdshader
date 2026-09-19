// A playable city block's facade (feel, round 7: the lead wants "a cityscape type map ... to match the theme and
// consistency of our gladiator environment"). The same lit windows as the skyline ring on the horizon
// (city_windows.gdshaderinc), so the buildings you drive between are the city the arena sits in. Lit by the scene (the
// moon, the floodlights' ambient) with the windows as emission. Everything is in world space, so windows line up
// across faces and blocks and nothing needs UVs.
//   COLOR.r  what the vertex belongs to: 0 = storey facade, 0.5 = shopfront (ground floor), 1 = roof or bevel
//   COLOR.g  this block's seed (0..1): window pattern and tint vary per block
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec3 concrete : source_color = vec3(0.24, 0.23, 0.26);
uniform vec3 glass : source_color = vec3(0.04, 0.05, 0.08);
uniform vec3 edge : source_color = vec3(0.45, 0.44, 0.48);
uniform vec3 shopfront : source_color = vec3(0.05, 0.05, 0.07);
uniform vec3 roof : source_color = vec3(0.13, 0.13, 0.15);
uniform float window_level = 1.4;

#include "res://game/theme/fx/shaders/city_windows.gdshaderinc"

varying vec3 world;
varying vec3 world_normal;
varying float part;
varying float block_seed;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	part = COLOR.r;
	block_seed = COLOR.g;
}

void fragment() {
	// Along the facade: x on faces that look along z, z on faces that look along x (chamfers take whichever is nearer).
	float along = abs(world_normal.x) > abs(world_normal.z) ? world.z : world.x;
	float seed = floor(block_seed * 97.0);
	vec3 base = concrete;
	vec3 glow = vec3(0.0);
	ROUGHNESS = 0.8;
	if (part < 0.25) {
		// Storeys: concrete with a pilaster between bays and a seam every floor, every window a pane of dark glass, and
		// the city's lit ones glowing in it (the same pattern as the skyline on the horizon).
		vec2 cell = vec2(along / 4.0, world.y / 3.6);
		vec2 inside = fract(cell);
		float pane = step(0.2, inside.x) * step(inside.x, 0.85) * step(0.25, inside.y) * step(inside.y, 0.8);
		float pilaster = 1.0 - step(0.06, inside.x) * step(inside.x, 0.94);
		float seam = step(0.94, inside.y);
		float px = max(fwidth(cell.x), fwidth(cell.y));
		float detail = 1.0 - smoothstep(0.3, 0.7, px);  // far away the grid melts into an even tone, no shimmer
		vec3 wall = concrete * (0.9 + 0.2 * city_hash(vec2(seed, 3.0))) * (1.0 - 0.2 * seam) * (1.0 + 0.15 * pilaster);
		base = mix(mix(wall, glass, 0.35), mix(wall, glass, pane), detail);
		ROUGHNESS = mix(0.85, 0.2, pane * detail);
		glow = city_windows(vec2(along, world.y), seed, seed * 1.3, window_level);
	} else if (part < 0.75) {
		// Shopfronts: dark glass and shutters, a warm light behind some of them.
		base = shopfront;
		float bay = floor(along / 6.0);
		float lit = step(0.55, city_hash(vec2(bay, seed)));
		float glass = step(0.8, world.y) * step(world.y, 3.2) * step(0.12, fract(along / 6.0)) * step(fract(along / 6.0), 0.88);
		glow = vec3(1.0, 0.7, 0.42) * lit * glass * 0.35;
		ROUGHNESS = 0.35;
	} else {
		// Roofs, and the bevel where each tier's edge rolls in: the bevel catches a pale edge (the chamfer detail).
		base = world_normal.y < 0.9 ? edge : roof;
	}
	// The chamfered corners (faces at 45 degrees in plan) catch the same pale edge as the bevels.
	float diagonal = 1.0 - abs(abs(world_normal.x) - abs(world_normal.z));
	if (part < 0.75 && diagonal > 0.9 && abs(world_normal.y) < 0.5) {
		base = mix(base, edge, 0.6);
	}
	ALBEDO = base;
	EMISSION = glow;
}

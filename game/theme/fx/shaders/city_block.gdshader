// A playable city block's facade (feel, round 7: the lead wants "a cityscape type map ... to match the theme and
// consistency of our gladiator environment"). The same lit windows as the skyline ring on the horizon
// (city_windows.gdshaderinc), so the buildings you drive between are the city the arena sits in. Lit by the scene (the
// moon, the floodlights' ambient) with the windows as emission. Everything is in world space, so windows line up
// across faces and blocks and nothing needs UVs.
//   COLOR.r  what the vertex belongs to: 0 = storey facade, 0.5 = shopfront (ground floor), 1 = roof or bevel
//   COLOR.g  this block's seed (0..1): window pattern and tint vary per block
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec3 concrete : source_color = vec3(0.17, 0.165, 0.18);
uniform vec3 glass : source_color = vec3(0.04, 0.05, 0.08);
uniform vec3 edge : source_color = vec3(0.45, 0.44, 0.48);
uniform vec3 shopfront : source_color = vec3(0.05, 0.05, 0.07);
uniform vec3 roof : source_color = vec3(0.13, 0.13, 0.15);
uniform float window_level = 1.4;

// S6, the arena light show (_agents/lighting.md; show carve-out, feel reviews at merge). Every uniform below starts
// with `show_` and every default reproduces EXACTLY the look feel shipped: show_edge's floor is 0 (no emissive edge
// at all, today's pale albedo alone) and show_window / show_shop are a constant multiplier of 1.0. One write to the
// single shared facade_material() drives all eight Terminus blocks, and they still breathe on eight clocks because
// the per-block phase is block_seed, which the mesh already carries in COLOR.g.
#include "res://game/theme/fx/shaders/show.gdshaderinc"
#include "res://game/theme/fx/shaders/city_windows.gdshaderinc"

// The lead: "We could easily bring these figures to life by making the lit edges breathe and glow." The lit edges he
// is looking at are the chamfers and roof bevels, which are an ALBEDO today and have no emission to breathe -- so
// this is the term that did not exist, not a modulation of one that did.
uniform vec4 show_edge = vec4(0.0, 0.0, 0.0, 1.0);
// "we can also fade in and out different lights on those buildings": this one is scattered PER WINDOW, so individual
// windows swell and fade against each other instead of the block pulsing as one slab.
uniform vec4 show_window = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 show_shop = vec4(1.0, 0.0, 0.0, 1.0);
// How far out of phase instances are pushed: 0 = every block and every window together, 1 = fully scattered.
// Written once when the fixture registers, never per frame.
uniform float show_spread = 0.0;
// A cue's colour override (the victory sweep is the one team-coloured cue in the venue; art_direction.md).
uniform vec3 show_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float show_color_mix = 0.0;
// What a lit edge is made of. Cool white with a violet lean: the venue's neon, never a team colour.
uniform vec3 show_edge_color : source_color = vec3(0.62, 0.70, 1.0);
uniform float show_edge_energy = 2.2;
// A K5 event rippling outward along the lit edges from where it happened -- a kill, read off FxWorld.spectacle,
// the same bus the crowd already reacts to. (world x, world z, the wavefront's radius in metres, gain). Gain 0 is
// "nothing happened", which is what every block holds until the first kill, so this term costs nothing until then.
uniform vec4 show_event = vec4(0.0, 0.0, 0.0, 0.0);
uniform float show_event_width = 9.0;

const float SHOW_TAU = 6.28318530718;

varying vec3 world;

// Smooth value noise (for grime).
float grime_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(city_hash(i), city_hash(i + vec2(1.0, 0.0)), f.x), mix(city_hash(i + vec2(0.0, 1.0)), city_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
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
	// This block's own place in the show's clock. Eight blocks, one material, eight phases.
	float show_phase = block_seed * SHOW_TAU * show_spread;
	// How much of this fragment is a lit edge: the roof bevel, or a chamfered corner. Zero everywhere else.
	float edge_mask = 0.0;
	ROUGHNESS = 0.8;
	if (part < 0.25) {
		// Storeys: concrete with a pilaster between bays and a seam every floor, every window a pane of dark glass, and
		// the city's lit ones glowing in it (the same pattern as the skyline on the horizon).
		// Each block has its own bay width (3-4.5 m), so neighbours don't share one grid.
		float bay_m = 3.0 + 1.5 * city_hash(vec2(seed, 7.0));
		vec2 cell = vec2(along / bay_m, world.y / 3.6);
		vec2 inside = fract(cell);
		float pane = step(0.22, inside.x) * step(inside.x, 0.8) * step(0.3, inside.y) * step(inside.y, 0.78);
		float pilaster = 1.0 - step(0.06, inside.x) * step(inside.x, 0.94);
		float seam = step(0.94, inside.y);
		float px = max(fwidth(cell.x), fwidth(cell.y));
		float detail = 1.0 - smoothstep(0.3, 0.7, px);  // far away the grid melts into an even tone, no shimmer
		// Grime: vertical streaks running down from every floor line, darker low down.
		float streak = grime_noise(vec2(along * 1.3, world.y * 0.12 + seed)) * (0.6 + 0.4 * (1.0 - inside.y));
		float low = 1.0 - smoothstep(0.0, 12.0, world.y) * 0.25;
		vec3 wall = concrete * (0.9 + 0.2 * city_hash(vec2(seed, 3.0))) * (1.0 - 0.2 * seam) * (1.0 + 0.15 * pilaster)
				* (1.0 - 0.45 * streak) * low;
		base = mix(mix(wall, glass, 0.35), mix(wall, glass, pane), detail);
		ROUGHNESS = mix(0.85, 0.2, pane * detail);
		// The window grid city_windows() uses internally (4.0 x 3.6 m on the rescaled metres), recomputed here so
		// each window gets its OWN phase. Deliberately duplicated rather than changing the include's signature: the
		// distant skyline ring shares that include and must not move (feel owns it).
		vec2 window_id = floor(vec2(along * 4.0 / bay_m, world.y) / vec2(4.0, 3.6));
		float window_phase = city_hash(window_id + 5.1) * SHOW_TAU * show_spread;
		glow = city_windows(vec2(along * 4.0 / bay_m, world.y), seed, seed * 1.3, window_level) * pane
				* show_value(show_window, show_phase + window_phase);
	} else if (part < 0.75) {
		// Shopfronts: dark glass and shutters, a warm light behind some of them.
		base = shopfront;
		float bay = floor(along / 6.0);
		float lit = step(0.55, city_hash(vec2(bay, seed)));
		float window_glass = step(0.8, world.y) * step(world.y, 3.2) * step(0.12, fract(along / 6.0)) * step(fract(along / 6.0), 0.88);
		glow = vec3(1.0, 0.7, 0.42) * lit * window_glass * 0.35 * show_value(show_shop, show_phase);
		ROUGHNESS = 0.35;
	} else {
		// Roofs, and the bevel where each tier's edge rolls in: the bevel catches a pale edge (the chamfer detail).
		bool bevel_face = world_normal.y < 0.9;
		base = bevel_face ? edge : roof;
		// The parapet. On screen far more often since control's camera lifts over the rooftops (2026-09-20).
		edge_mask = bevel_face ? 1.0 : 0.0;
	}
	// The chamfered corners (faces at 45 degrees in plan) catch the same pale edge as the bevels.
	float diagonal = 1.0 - abs(abs(world_normal.x) - abs(world_normal.z));
	if (part < 0.75 && diagonal > 0.9 && abs(world_normal.y) < 0.5) {
		base = mix(base, edge, 0.6);
		edge_mask = max(edge_mask, 0.6);
	}
	// The kill ripple: a travelling front, widest where it is passing right now.
	float ripple = 0.0;
	if (show_event.w > 0.0) {
		ripple = show_event.w * exp(-abs(distance(world.xz, show_event.xy) - show_event.z) / show_event_width);
	}
	ALBEDO = base;
	// show_edge's floor is 0 and show_event's gain is 0 by default, so both terms are exactly 0 and EMISSION is
	// what it always was.
	EMISSION = glow + mix(show_edge_color, show_color, show_color_mix) * show_edge_energy * edge_mask
			* (show_value(show_edge, show_phase) + ripple);
}

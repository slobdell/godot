// A playable city block's facade (feel, round 7: the lead wants "a cityscape type map ... to match the theme and
// consistency of our gladiator environment"). The same lit windows as the skyline ring on the horizon
// (city_windows.gdshaderinc), so the buildings you drive between are the city the arena sits in. Lit by the scene (the
// moon, the floodlights' ambient) with the windows as emission. Everything is in world space, so windows line up
// across faces and blocks and nothing needs UVs.
//   COLOR.r  what the vertex belongs to: 0 = storey facade, 0.5 = shopfront (ground floor),
//            0.75 = roof clutter (plant in the reserved top band), 1 = roof or bevel
//   COLOR.g  this block's seed (0..1): window pattern and tint vary per block
//   COLOR.b  this block's index in the show's window grid, k/255 (S6 round 10; 0 without a show)
//   COLOR.a  this block's bay code, k/255: bay = 3.0 + 1.5 * code (m). It used to be a sin() hash of the seed,
//            which the CPU could not reproduce exactly, so the CPU could not know where a window was.
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
// Round 10: the shopfronts' spatial wave (lighting.md section 4c); zero is "the whole block on one phase", as before.
uniform vec4 show_shop_wave = vec4(0.0, 0.0, 0.0, 0.0);
// How far out of phase instances are pushed: 0 = every block and every window together, 1 = fully scattered.
// Written once when the fixture registers, never per frame.
uniform float show_spread = 0.0;
// A cue's colour override (the victory sweep is the one team-coloured cue in the venue; art_direction.md).
uniform vec3 show_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float show_color_mix = 0.0;
// What a lit edge is made of, PER BLOCK, from the venue's own palette (art_direction.md :31 "harsh magenta and
// cyan neon ... red warning lights, amber beacons", :56 "magenta + cyan, plus red warning and amber beacon").
// Two colours are deliberately absent (feel, 2026-09-20):
//   * COOL WHITE is not in the palette at all. It reads as architectural LED, which makes the city look new
//     rather than salvaged -- and it was the brightest thing on screen in the first strip.
//   * RED is a SIGNAL in this game, not trim: warning lights and beacons are red. Spending it on building edges
//     spends a colour that means "something is wrong".
uniform vec3 show_edge_a : source_color = vec3(1.0, 0.0, 0.6);
uniform vec3 show_edge_b : source_color = vec3(0.0, 0.95, 1.0);
uniform vec3 show_edge_c : source_color = vec3(1.0, 0.69, 0.23);
// Deliberately low: the parapet must sit UNDER the window grid, which sits under the fight. The first strip
// inverted that hierarchy -- the brightest pixels in the frame were the building edges and the darkest were the
// arena floor and the vehicles -- and "lit well enough to read the fight" (:72) is play, not taste.
uniform float show_edge_energy = 0.8;
// 0 = the roof parapet ONLY: a horizontal line along a roofline, which reads as a building.
// 1 = every vertical chamfer too, which reads as a wireframe. `show_edge` is added on the bevel/chamfer branch and
// that branch IS the silhouette, so at 1 the term can only ever draw an outline -- the named anti-pattern at
// art_direction.md :56, "Neon as outlines on everything". Kept as the `outline` patch style so the lead can
// compare against his own words ("make the lit edges breathe and glow"); never the default.
uniform float show_chamfer_gain = 0.0;
// A K5 event rippling outward along the lit edges from where it happened -- a kill, read off FxWorld.spectacle,
// the same bus the crowd already reacts to. (world x, world z, the wavefront's radius in metres, gain). Gain 0 is
// "nothing happened", which is what every block holds until the first kill, so this term costs nothing until then.
uniform vec4 show_event = vec4(0.0, 0.0, 0.0, 0.0);
uniform float show_event_width = 9.0;

// ---- S6 round 10: EVERY WINDOW ADDRESSABLE (_agents/lighting.md section 4c) --------------------------------------
// The lead: "basic primitives to adjust individual lights on the building". The unit of the show is the window.
//
// THE PIXEL LAYER. Every pane -- lit by the art or dark -- can carry a show light in the venue palette, on top of the
// art's own lit windows (which keep breathing on show_window). Its level is the larger of two sources:
//   * a PROGRAMME the shader evaluates per window from one channel (show_pixel) and a spatial wave
//     (show_pixel_wave = radians per storey, radians per metre along the facade, scatter 0..1 as a fraction of TAU
//     from the window's hash, clock-rate jitter 0..1). A vertical chase up a tower is a negative per-storey term; a
//     sweep across a facade a per-metre term; the Vegas twinkle is scatter + jitter. Zero CPU per window per frame.
//   * the window's own TEXEL in show_window_map, written by the CPU only for events (ShowWindowGrid: a floor-by-floor
//     fill, set_window). r = level, g = palette override (0 = the block's colour, 1..3 magenta/cyan/amber).
// Plus the kill ripple, which now crosses the WINDOWS of the facades nearest the kill, not only the parapet.
// show_pixel_focus = (block, facade, map_live, 0): x/y limit the programme to one block and/or facade (-1 = all) --
// the last-stand strobe on the facade facing the losing base rather than the whole city; z is 1 while the CPU has
// anything in the map, so the layer is skipped entirely (one branch) when neither source can light a window.
// Every default is the identity: show_pixel's floor and span are 0 and the map is black, so nothing changes until a
// patch binds `pixel`.
uniform vec4 show_pixel = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 show_pixel_wave = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 show_pixel_focus = vec4(-1.0, -1.0, 0.0, 0.0);
// 1.3, not 1.8: at 1.8 the first frames (9f68b95e, builder0) washed magenta and amber toward white; a saturated venue
// colour reads as neon, a pastel one as a lit office.
uniform float show_pixel_energy = 1.3;
uniform sampler2D show_window_map : hint_default_black, filter_nearest, repeat_disable;
// ShowWindowGrid's layout: COLS columns, ROWS storeys per facade, FACADES facades per block.
const int SHOW_COLS = 32;
const int SHOW_ROWS = 16;

const float SHOW_TAU = 6.28318530718;

// This block's edge colour: one of the venue's three, picked by the seed the mesh already carries in COLOR.g, so
// neighbouring blocks differ without a uniform per block.
vec3 show_edge_palette(float seed) {
	float p = fract(seed * 7.13);
	return p < 0.34 ? show_edge_a : (p < 0.67 ? show_edge_b : show_edge_c);
}

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
varying float block_index;
varying float bay_code;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	part = COLOR.r;
	block_seed = COLOR.g;
	block_index = COLOR.b;
	bay_code = COLOR.a;
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
		float bay_m = 3.0 + 1.5 * bay_code;
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
		// The pixel layer (see the uniforms). Skipped entirely -- one branch -- while nothing drives it.
		if (show_pixel.x + show_pixel.y > 0.0 || show_event.w > 0.0 || show_pixel_focus.z > 0.0) {
			int block_i = int(round(block_index * 255.0));
			int facade = abs(world_normal.x) > abs(world_normal.z) ? (world_normal.x > 0.0 ? 0 : 1)
					: (world_normal.z > 0.0 ? 2 : 3);
			ivec2 wid = ivec2(floor(cell));
			ivec2 texel = ivec2(((wid.x % SHOW_COLS) + SHOW_COLS) % SHOW_COLS,
					(block_i * 4 + facade) * SHOW_ROWS + ((wid.y % SHOW_ROWS) + SHOW_ROWS) % SHOW_ROWS);
			vec4 cpu = texelFetch(show_window_map, texel, 0);
			float scatter = city_hash(vec2(wid) + vec2(float(block_i) * 13.1, float(facade) * 7.3));
			float rate = city_hash(vec2(wid) * 1.37 + vec2(float(block_i) * 5.7 + 2.0, float(facade) * 3.1));
			vec4 chan = show_pixel;
			chan.z *= 1.0 + show_pixel_wave.w * (rate - 0.5);
			float pixel_phase = float(block_i) * 2.39996 * show_spread + show_pixel_wave.x * float(wid.y)
					+ show_pixel_wave.y * along + show_pixel_wave.z * SHOW_TAU * scatter;
			float focus = (show_pixel_focus.x < 0.0 || abs(float(block_i) - show_pixel_focus.x) < 0.5)
					&& (show_pixel_focus.y < 0.0 || abs(float(facade) - show_pixel_focus.y) < 0.5) ? 1.0 : 0.0;
			float level = max(show_value(chan, pixel_phase) * focus, cpu.r);
			if (show_event.w > 0.0) {
				level += show_event.w * exp(-abs(distance(world.xz, show_event.xy) - show_event.z) / show_event_width);
			}
			int pick = int(round(cpu.g * 255.0));
			vec3 hue = pick == 1 ? show_edge_a : (pick == 2 ? show_edge_b : (pick == 3 ? show_edge_c
					: show_edge_palette(fract(block_seed + float(block_i) * 0.37))));
			hue = mix(hue, show_color, show_color_mix);
			// Far away a pane is a fraction of a pixel: fade to its share of the bay, like the art's windows do.
			glow += hue * level * show_pixel_energy * mix(0.3, pane, detail);
		}
	} else if (part < 0.75) {
		// Shopfronts: dark glass and shutters, a warm light behind some of them.
		base = shopfront;
		float bay = floor(along / 6.0);
		float lit = step(0.55, city_hash(vec2(bay, seed)));
		float window_glass = step(0.8, world.y) * step(world.y, 3.2) * step(0.12, fract(along / 6.0)) * step(fract(along / 6.0), 0.88);
		// Round 10: per shop bay, through the generic wave (x unused at street level, y radians per metre along
		// the street, z scatter by the bay's hash): the shopfront band chases or shimmers bay by bay.
		float shop_phase = show_phase + show_shop_wave.y * along + show_shop_wave.z * SHOW_TAU * city_hash(vec2(bay, seed + 3.0));
		glow = vec3(1.0, 0.7, 0.42) * lit * window_glass * 0.35 * show_value(show_shop, shop_phase);
		ROUGHNESS = 0.35;
	} else if (part < 0.85) {
		// Roof clutter: housings, ducts and tanks in the band CityBlock reserves at the top of a block. It needs its
		// OWN band rather than the roof's, because the roof branch treats every non-upward face as a lit parapet
		// edge -- tagged as roof, a duct would have four glowing sides. Dark painted metal, a little lighter on top
		// where it catches the sky, and no emission: the plant is what the parapet and the neon are read AGAINST.
		// The tonal spread has to be WIDE or the plant does not read: the first version sat within +25%/-28% of the
		// roof's own value and rendered as shapes you had to look for. Tops catch the sky at roughly twice the
		// roof, sides fall well under it, and a per-unit hash off the world position keeps neighbouring boxes from
		// reading as one mass -- no extra vertex data, the position is already here.
		float up = smoothstep(0.55, 0.95, world_normal.y);
		float unit = city_hash(floor(world.xz * 0.35));
		base = roof * mix(0.45, 2.1, up) * (0.78 + 0.45 * unit);
		ROUGHNESS = 0.9;
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
		// The vertical chamfers are DARK by default; only the `outline` style lights them.
		edge_mask = max(edge_mask, 0.6 * show_chamfer_gain);
	}
	// The kill ripple: a travelling front, widest where it is passing right now.
	float ripple = 0.0;
	if (show_event.w > 0.0) {
		ripple = show_event.w * exp(-abs(distance(world.xz, show_event.xy) - show_event.z) / show_event_width);
	}
	ALBEDO = base;
	// show_edge's floor is 0 and show_event's gain is 0 by default, so both terms are exactly 0 and EMISSION is
	// what it always was.
	EMISSION = glow + mix(show_edge_palette(block_seed), show_color, show_color_mix) * show_edge_energy * edge_mask
			* (show_value(show_edge, show_phase) + ripple);
}

// Water for the `arena.terrain` slot (terrain stream, round 10; the wet look, arena, round 12). ONE material, ONE draw
// for every water footprint on the map, no lights, no textures but the floor's own light map. The channel itself is
// interior-mapped (terrain_trace.gdshaderinc, shared with pit.gdshader and nothing else).
//
// ROUND 12, "water reads black and should read wet" (the lead, 2026-09-24; arenas.md *Water reads black*). At his
// 21-degree camera the reflected ray points ~21 degrees UP, where round 10's modelled sky was near black, and Schlick
// gives a fresnel of ~0.16, so the surface was ~84 % `water_deep` = black. What makes a canal read wet at night is
// what is really around it, so this reflects the VENUE AS BUILT, each piece read from the scene, never copied
// (TerrainVisual feeds the uniforms from ArenaDressing.reflection_venue() and the layout's obstacles):
//   (a) the body: a dark teal, lit by the floor's own light map where the floodlight pools fall on it;
//   (b) an environment traced analytically from the reflection point: the city blocks and containers beside the
//       water (dark faces, a neon band, windows), the wall's inner face and its light bars, the stands' profile and
//       their crowd, then the smoggy sky;
//   (c) glints of the real lamp heads (venue towers, layout floodlights) on a slow swell -- low-frequency normals
//       only, never a per-pixel sparkle: feel's round-10 review read that as a "starfield/nebula";
//   (d) a lap line where the water meets its walls, which pits do not have.
// Every step has a dial whose zero is round 10's look (WaterLook.STEPS holds the pairs; `make water-pairs`).
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

#include "res://game/theme/arena_kit/terrain/terrain_trace.gdshaderinc"

// (a) The body. Round 10: (0.004, 0.012, 0.018), "oily black".
uniform vec3 water_deep : source_color = vec3(0.025, 0.09, 0.1);
uniform float body_flood = 0.3;
uniform sampler2D flood_map : filter_linear, repeat_disable;
uniform bool has_flood_map = false;
uniform float flood_half = 160.0;
uniform float flood_scale = 2.0;
uniform float reflection = 0.9;

// (b) The venue. 0 = round 10's horizon band; 1 = the traced venue.
uniform float venue_reflect = 1.0;
// The wall's inner face as polygon edges (from.xy, to.xy), and up to two stands spans along each edge
// (from_m, to_m, from_m, to_m; a span with to <= from is none).
uniform int edge_count = 0;
uniform vec4 edges[8];
uniform vec4 edge_stands[8];
uniform float wall_height = 3.0;
// The inner face's light bars: (y, height, energy) and a linear colour each.
uniform int bar_count = 0;
uniform vec3 bars[4];
uniform vec3 bar_colors[4];
// The stands' profile (metres out from the inner face, height), nearest first, and the crowd's band of heights.
uniform int stands_count = 0;
uniform vec2 stands[24];
uniform vec2 crowd = vec2(3.0, 8.0);
// Obstacles near the water: centre.xz, half extents (local x, z); yaw (rad), height, neon band (bottom, top); the
// band's linear colour and 1 for a block's windows.
uniform int box_count = 0;
uniform vec4 boxes[16];
uniform vec4 box_info[16];
uniform vec4 box_look[16];
// Each box's yaw as (cos, sin), computed once on the CPU rather than per pixel.
uniform vec2 box_rot[16];

// (c) Glints: lamp heads (xyz, energy) with linear colours, on a swell of this amplitude (radians of normal tilt,
// long and short waves). Round 10 had ONE fake lamp direction (`legacy_streak`).
uniform int lamp_count = 0;
uniform vec4 lamps[12];
uniform vec3 lamp_colors[12];
uniform float glint = 1.0;
// A lamp on rippled water is not a point but a COLUMN toward the viewer: the ripples tilt normals mostly toward and
// away from the eye, so its reflection is narrow in azimuth and long in elevation (the classic lights-on-a-harbour
// streak). Widths are the lobe's standard deviations in radians; the chop breaks the column into moving pieces.
uniform float glint_az = 0.05;
uniform float glint_el = 0.3;
uniform float glint_gain = 0.9;
// The floodlight POOLS glinting: where the floor's light map says a pool falls, the long swell's crests catch it as
// soft moving bands (smooth noise at ~16 m, never a per-pixel sparkle). Scaled by `glint` with the lamps.
uniform float pool_sheen = 0.35;
// The reflection's vertical smear (radians of elevation jitter from the short waves): rippled water stretches what it
// reflects into vertical streaks, which is what separates a reflection from a picture pasted on the surface.
uniform float smear = 0.09;
uniform float swell_amp = 0.08;
uniform float swell_fine = 0.025;
uniform float legacy_streak = 0.0;

// (d) The lap line at the walls.
uniform float lap = 1.0;
uniform float lap_width = 0.5;
uniform vec3 lap_color : source_color = vec3(0.42, 0.62, 0.66);

// Measurement: 1 paints every water pixel flat magenta, so a frame can be masked (`water-pairs` WATER_STATS).
uniform float mask_out = 0.0;

// Round 10's sky: smoggy near black, the venue's neon only as a faint band at the horizon.
vec3 horizon_sky(vec3 r) {
	float horizon = exp(-max(r.y, 0.0) * 6.0);
	float azimuth = atan(r.x, r.z);
	return mix(vec3(0.012, 0.01, 0.02), mix(neon_b, neon_a, 0.5 + 0.5 * sin(azimuth * 2.0)) * 0.35, horizon);
}

bool in_stands(int e, float along) {
	vec4 s = edge_stands[e];
	return (along > s.x && along < s.y) || (along > s.z && along < s.w);
}

// A face of an obstacle at height `y`, `along` metres across it. A block: a dark facade, the shopfront's neon band,
// and above it a grid of windows (a pattern, not the facade's exact windows: the swell breaks them up anyway).
vec3 box_face(int i, float y, float along) {
	vec4 info = box_info[i];
	vec4 look = box_look[i];
	vec3 c = vec3(0.016, 0.016, 0.02);
	if (info.w > info.z) {
		float band = smoothstep(0.08, 0.0, max(info.z - y, y - info.w));
		c += look.rgb * band * 3.0;
		c += look.rgb * 0.25 * exp(-abs(y - (info.z + info.w) * 0.5) * 1.5);
	}
	if (look.a > 0.5 && y > info.w + 0.3) {
		vec2 cell = vec2(along / 3.6, (y - info.w) / 3.3);
		vec2 f = fract(cell);
		vec2 soft = vec2(0.08, 0.12);
		float pane = smoothstep(0.2, 0.2 + soft.x, f.x) * smoothstep(0.8, 0.8 - soft.x, f.x)
				* smoothstep(0.28, 0.28 + soft.y, f.y) * smoothstep(0.8, 0.8 - soft.y, f.y);
		float lit = step(0.52, hash(floor(cell) + vec2(float(i) * 7.0, 0.0)));
		c += vec3(1.0, 0.78, 0.5) * pane * lit * 0.3;
	}
	return c;
}

// What a ray from the water at `p` leaving along `r` (r.y > 0) meets first: an obstacle, the wall's inner face, the
// stands above it, or the sky.
vec3 venue(vec3 p, vec3 r) {
	float hl = length(r.xz);
	if (hl < 1e-4 || edge_count == 0) {
		return horizon_sky(r);
	}
	vec2 h = r.xz / hl;
	float k = r.y / hl;
	// The wall: the nearest inner face ahead.
	float tw = 1e6;
	int ew = -1;
	float wall_along = 0.0;
	for (int e = 0; e < 8; e++) {
		if (e >= edge_count) {
			break;
		}
		vec2 a = edges[e].xy;
		vec2 b = edges[e].zw;
		vec2 tangent = normalize(b - a);
		vec2 n = vec2(tangent.y, -tangent.x);
		if (dot(n, a + b) < 0.0) {
			n = -n;
		}
		float denom = dot(h, n);
		if (denom > 1e-4) {
			float t = (dot(a, n) - dot(p.xz, n)) / denom;
			if (t > 0.0 && t < tw) {
				tw = t;
				ew = e;
				wall_along = dot(p.xz + h * t - a, tangent);
			}
		}
	}
	// Obstacles: a 2D slab test in each box's own frame; the ray only climbs, so a box is hit if the ray enters it
	// below the box's top.
	float tb = tw;
	int bi = -1;
	float box_along = 0.0;
	for (int i = 0; i < 16; i++) {
		if (i >= box_count) {
			break;
		}
		float cy = box_rot[i].x;
		float sy = box_rot[i].y;
		vec2 rel = p.xz - boxes[i].xy;
		vec2 lp = vec2(cy * rel.x - sy * rel.y, sy * rel.x + cy * rel.y);
		vec2 ld = vec2(cy * h.x - sy * h.y, sy * h.x + cy * h.y);
		vec2 inv = 1.0 / (ld + vec2(ld.x == 0.0 ? 1e-6 : 0.0, ld.y == 0.0 ? 1e-6 : 0.0));
		vec2 t1 = (-boxes[i].zw - lp) * inv;
		vec2 t2 = (boxes[i].zw - lp) * inv;
		vec2 tmin2 = min(t1, t2);
		vec2 tmax2 = max(t1, t2);
		float t_in = max(tmin2.x, tmin2.y);
		float t_out = min(tmax2.x, tmax2.y);
		if (t_in > 0.0 && t_in < t_out && t_in < tb && p.y + k * t_in < box_info[i].y) {
			tb = t_in;
			bi = i;
			vec2 at = lp + ld * t_in;
			box_along = tmin2.x > tmin2.y ? at.y : at.x;
		}
	}
	if (bi >= 0) {
		return box_face(bi, p.y + k * tb, box_along);
	}
	if (ew < 0) {
		return horizon_sky(r);
	}
	float y = p.y + k * tw;
	if (y < wall_height) {
		// The inner face: dark concrete and its light bars, softened with distance (the swell smears them).
		vec3 c = vec3(0.018, 0.018, 0.022);
		float blur = 0.04 + tw * 0.004;
		for (int j = 0; j < 4; j++) {
			if (j >= bar_count) {
				break;
			}
			float d = abs(y - bars[j].x);
			float core = bars[j].y * 0.5;
			c += bar_colors[j] * bars[j].z * (1.0 - smoothstep(core, core + blur, d));
			c += bar_colors[j] * bars[j].z * 0.06 * exp(-d * 2.5);
		}
		return c;
	}
	if (in_stands(ew, wall_along)) {
		for (int i = 1; i < 24; i++) {
			if (i >= stands_count) {
				break;
			}
			float ys = p.y + k * (tw + stands[i].x);
			if (ys < stands[i].y) {
				// The grandstand: dark steel, and the seated crowd as a scatter of dim colour.
				vec3 c = vec3(0.014, 0.013, 0.018);
				if (ys > crowd.x && ys < crowd.y) {
					vec2 cell = floor(vec2(wall_along * 1.6, ys * 2.4));
					float seat = hash(cell);
					vec3 shirt = 0.5 + 0.5 * cos(6.2831 * (hash(cell + 3.1) + vec3(0.0, 0.33, 0.67)));
					c += shirt * step(0.45, seat) * 0.16;
				}
				return c;
			}
		}
	}
	return horizon_sky(r);
}

// Lateral distance from a point on the surface to the nearest bank (a side of its footprint with dry ground past it).
float bank_dist(vec2 p) {
	float best = 1e6;
	for (int i = 0; i < 16; i++) {
		if (i >= wet_count) {
			break;
		}
		vec4 w = wet[i];
		if (!inside(p, w)) {
			continue;
		}
		float dx0 = p.x - w.x;
		float dx1 = w.z - p.x;
		float dz0 = p.y - w.y;
		float dz1 = w.w - p.y;
		if (!in_any_wet(vec2(w.x - 0.05, p.y))) best = min(best, dx0);
		if (!in_any_wet(vec2(w.z + 0.05, p.y))) best = min(best, dx1);
		if (!in_any_wet(vec2(p.x, w.y - 0.05))) best = min(best, dz0);
		if (!in_any_wet(vec2(p.x, w.w + 0.05))) best = min(best, dz1);
	}
	return best;
}

void fragment() {
	float t = clock(TIME);
	vec3 dir = normalize(world_pos - CAMERA_POSITION_WORLD);
	vec3 origin = vec3(world_pos.x, 0.0, world_pos.z);
	vec3 color;
	if (dir.y > -0.001) {
		color = wall_color;
	} else {
		float t_wall = wall_t(origin, dir);
		float t_surface = water_line / -dir.y;
		float t_deck = deck_under / -dir.y;
		vec3 at_deck = origin + dir * t_deck;
		if (t_deck < min(t_wall, t_surface) && under_deck(at_deck.xz)) {
			color = deck_shade(at_deck);
		} else if (t_wall < t_surface) {
			vec3 hit = origin + dir * t_wall;
			float below = -hit.y;
			color = wall_shade(below, hit.xz);
			// (d) Wet concrete: a darker, glossier strip above the water line, and the bright lap where they meet.
			float above = water_line - below;
			float wobble = 0.03 * sin(dot(hit.xz, vec2(1.3, 0.9)) + t * 1.7);
			color *= 1.0 - lap * 0.45 * smoothstep(0.35, 0.0, above);
			color += lap_color * lap * smoothstep(0.06, 0.0, abs(above - 0.02 - wobble)) * 0.9;
		} else {
			vec3 hit = origin + dir * t_surface;
			// A long, low-frequency swell drifting at `flow` tilts the surface; a shorter wave on top breaks a glint
			// into a few moving pieces. Both are smooth value noise at metres of wavelength: no sparkle.
			vec2 q = hit.xz * 0.06 + vec2(t * flow * 0.25, t * flow * 0.15);
			vec2 swell = vec2(noise(q) - 0.5, noise(q + 17.0) - 0.5);
			vec2 q2 = hit.xz * vec2(0.35, 0.22) + vec2(-t * flow * 0.9, t * flow * 0.6);
			vec2 chop = vec2(noise(q2) - 0.5, noise(q2 + 31.0) - 0.5);
			vec2 tilt = swell * 2.0 * swell_amp + chop * 2.0 * swell_fine;
			vec3 r = normalize(vec3(dir.x + tilt.x, -dir.y, dir.z + tilt.y));
			// The environment is looked up along a ray smeared in ELEVATION by the short waves (see `smear`). The
			// waves are laid out in the VIEW's frame, long across it and short along it, so a neon line breaks into
			// horizontal dashes stacked toward the eye; round noise drew closed contours (scribbles, 2026-09-27).
			vec2 ahead = normalize(dir.xz + vec2(1e-5, 0.0));
			vec2 across = vec2(-ahead.y, ahead.x);
			vec2 wave = vec2(dot(hit.xz, across) * 0.35, dot(hit.xz, ahead) * 3.2 + t * flow * 2.0);
			float jitter = (noise(wave) - 0.5) * 2.0 * smear;
			vec3 r_env = normalize(vec3(r.x, max(r.y + jitter, 0.001), r.z));
			// Schlick with water's F0 = 0.02, plus a small art-directed floor so the surface reads at 21 degrees.
			float fresnel = 0.06 + 0.94 * pow(1.0 - clamp(r.y, 0.0, 1.0), 5.0);
			vec3 env = venue_reflect >= 1.0 ? venue(hit, r_env)
					: mix(horizon_sky(r), venue(hit, r_env), venue_reflect);
			vec3 body = water_deep;
			vec3 pool = vec3(0.0);
			if (has_flood_map) {
				pool = texture(flood_map, (hit.xz + flood_half) / (2.0 * flood_half)).rgb * flood_scale;
				// By the light's LUMINANCE, so a sodium pool brightens the teal instead of turning it olive.
				body *= 1.0 + body_flood * dot(pool, vec3(0.2126, 0.7152, 0.0722));
			}
			color = mix(body, env, clamp(fresnel * reflection, 0.0, 1.0));
			// (c) The lamps' columns: each real lamp head against the reflected ray, split into azimuth and elevation.
			// Small-angle vector math, no atan (the lobe is ~3 degrees wide, where sin(a) = a to 0.05 %): the azimuth
			// gap is the cross product of the two horizontal directions, the elevation gap the difference of the sines
			// over the ray's cosine. A lamp behind the ray is skipped.
			if (glint > 0.0) {
				vec3 spec = vec3(0.0);
				float r_flat = length(r.xz);
				vec2 r_dir = r.xz / r_flat;
				for (int i = 0; i < 12; i++) {
					if (i >= lamp_count) {
						break;
					}
					vec3 l = lamps[i].xyz - hit;
					float l_flat = length(l.xz);
					vec2 l_dir = l.xz / l_flat;
					if (dot(l_dir, r_dir) <= 0.0) {
						continue;
					}
					float daz = l_dir.x * r_dir.y - l_dir.y * r_dir.x;
					float del = (l.y * inversesqrt(l_flat * l_flat + l.y * l.y) - r.y) / r_flat;
					spec += lamp_colors[i] * lamps[i].w
							* exp(-0.5 * (daz * daz / (glint_az * glint_az) + del * del / (glint_el * glint_el)));
				}
				float breakup = 0.3 + 1.4 * noise(hit.xz * vec2(0.8, 2.2) + vec2(t * flow * 1.1, -t * flow * 0.7));
				color += min(spec * breakup * glint_gain, vec3(1.4)) * glint;
				float crest = smoothstep(0.55, 0.8, noise(q * 1.6 + vec2(3.7, 1.3)));
				color += pool * crest * pool_sheen * fresnel * 4.0 * glint;
			}
			// Round 10's streak: one lamp direction that no lamp stood in.
			if (legacy_streak > 0.0) {
				vec3 lamp = normalize(vec3(0.15, 0.32, -1.0));
				float along = max(dot(r, lamp), 0.0);
				float streak = pow(along, 90.0) * (0.6 + 0.8 * noise(hit.xz * vec2(0.9, 0.15) + t * flow));
				color += vec3(1.0, 0.85, 0.6) * streak * 1.2 * legacy_streak;
			}
			// (d) The lap line: a thin pale band where the surface meets a bank, wavering with the swell.
			float bank = bank_dist(hit.xz) + (swell.x + chop.y) * 0.12;
			color += lap_color * lap * smoothstep(lap_width, 0.0, bank) * 0.9;
			// Shade the water a little under a bridge: its shadow reads the deck as ABOVE the water.
			if (under_deck(hit.xz)) {
				color *= 0.35;
			}
		}
	}
	ALBEDO = mix(color, vec3(1.0, 0.0, 1.0), mask_out);
}

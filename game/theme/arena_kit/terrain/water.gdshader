// Water and pits for the `arena.terrain` slot (terrain stream, round 10). ONE material per surface kind, ONE draw
// for every footprint of that kind on the map, no lights, no textures.
//
// The ground is flat and the arena floor is a single plane drawn over everything at y = 0, so a real sunken channel
// cannot be modelled without cutting feel's floor. Instead this is INTERIOR MAPPING (van Dongen, 2008), the standard
// technique for fake rooms behind flat windows: the quad sits just above the floor, and each fragment traces the
// view ray into an imaginary box below it -- the footprint's own walls, its water line and its floor -- and shades
// whatever the ray hits first. From the lead's 21-degree camera the far bank's inner wall is in view, so the channel
// reads as cut INTO the arena, with depth that parallaxes correctly as the camera moves.
//
// Per-vertex data: UV = the footprint's (min_x, min_z), UV2 = its (max_x, max_z). A quad that is only PART of a
// footprint (the water beside a bridge deck) still traces the whole footprint's box, so the walls line up.
// `decks` lists the bridge decks so the ray can hit a deck's edge and underside instead of seeing water through it.
//
// `is_pit` switches the look: water is a dark, mirror-still surface with the venue's neon reflected in it and one
// animated scalar (`flow`) moving the ripples; a pit is a deep, black shaft with a dim red glow at the bottom.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

uniform bool is_pit = false;
// How far below the floor the walls go (water: to its bed; pit: the pan), and where the water line sits.
uniform float depth = 3.0;
uniform float water_line = 0.7;
// The ONE animated scalar: ripple phase per second. 0 freezes the water (frame pairs, tests).
uniform float flow = 0.35;
// The deck underside, relative to the floor, for the ray to hit when it passes under a bridge.
uniform float deck_under = 0.45;
uniform int deck_count = 0;
uniform vec4 decks[8];
// Every footprint of this kind (min_x, min_z, max_x, max_z). A river built from several rectangles is ONE body of
// water: the trace hops from box to box and meets a wall only where the next ground is dry.
uniform int wet_count = 0;
uniform vec4 wet[16];
// Palette: the venue's night. Concrete walls, a deep teal-black water, and the two neons it reflects.
uniform vec3 wall_color : source_color = vec3(0.13, 0.135, 0.15);
uniform vec3 water_deep : source_color = vec3(0.01, 0.045, 0.065);
uniform vec3 neon_a : source_color = vec3(0.0, 0.95, 1.0);
uniform vec3 neon_b : source_color = vec3(0.85, 0.0, 1.0);
uniform vec3 pit_glow : source_color = vec3(1.0, 0.12, 0.02);
uniform float reflection = 0.9;

varying vec3 world_pos;
varying vec4 box;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	box = vec4(UV, UV2);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Distance along `d` (the ray's horizontal part, same parameter as the 3D ray) from `p` to the edge of `r`.
float rect_exit(vec2 p, vec2 d, vec4 r) {
	float tx = d.x > 0.0 ? (r.z - p.x) / d.x : (d.x < 0.0 ? (r.x - p.x) / d.x : 1e6);
	float tz = d.y > 0.0 ? (r.w - p.y) / d.y : (d.y < 0.0 ? (r.y - p.y) / d.y : 1e6);
	return max(0.0, min(tx, tz));
}

bool inside(vec2 p, vec4 r) {
	return p.x > r.x && p.x < r.z && p.y > r.y && p.y < r.w;
}

// Distance along `dir` to the first inner wall of the UNION of this kind's footprints: leave the current box, and if
// the ground just past its edge is another footprint, carry on through that one.
float wall_t(vec3 origin, vec3 dir) {
	vec2 d = dir.xz;
	vec4 current = box;
	float t = 0.0;
	for (int hop = 0; hop < 8; hop++) {
		t += rect_exit(origin.xz + d * t, d, current);
		vec2 next = origin.xz + d * (t + 0.05);
		bool found = false;
		for (int i = 0; i < 16; i++) {
			if (i >= wet_count) {
				break;
			}
			if (inside(next, wet[i])) {
				current = wet[i];
				found = true;
				break;
			}
		}
		if (!found) {
			return t;
		}
		t += 0.05;
	}
	return t;
}

bool under_deck(vec2 p) {
	for (int i = 0; i < 8; i++) {
		if (i >= deck_count) {
			break;
		}
		vec4 d = decks[i];
		if (p.x > d.x && p.x < d.z && p.y > d.y && p.y < d.w) {
			return true;
		}
	}
	return false;
}

// The concrete of an inner wall at depth `below` metres under the floor: darker with depth, a lit line near the top
// (the kerb's glow bleeding down), and horizontal pour lines so the depth has a scale.
vec3 wall_shade(float below, vec2 along) {
	float fade = exp(-below * (is_pit ? 0.32 : 0.9));
	float pour = 0.85 + 0.15 * step(0.5, fract(below * 1.25));
	float stain = 0.8 + 0.2 * noise(along * 0.7 + vec2(below * 3.0, 0.0));
	vec3 c = wall_color * pour * stain * fade;
	// A thin emissive band 0.15 m under the lip: the kerb's own light, read on the far wall.
	float band = smoothstep(0.04, 0.0, abs(below - 0.18));
	c += (is_pit ? vec3(1.0, 0.75, 0.05) : neon_a) * band * 0.9;
	if (is_pit) {
		// The glow from the bottom climbs the walls.
		c += pit_glow * 0.35 * exp(-(depth - below) * 0.6);
	}
	return c;
}

void fragment() {
	vec3 dir = normalize(world_pos - CAMERA_POSITION_WORLD);
	vec3 origin = vec3(world_pos.x, 0.0, world_pos.z);
	vec3 color;
	if (dir.y > -0.001) {
		color = wall_color;
	} else {
		float t_wall = wall_t(origin, dir);
		float surface = is_pit ? depth : water_line;
		float t_surface = surface / -dir.y;
		// A bridge deck over this footprint: the ray may meet its side or its underside before anything else.
		float t_deck = deck_under / -dir.y;
		vec3 at_deck = origin + dir * t_deck;
		bool deck_hit = t_deck < min(t_wall, t_surface) && under_deck(at_deck.xz);
		if (deck_hit) {
			// The deck's underside and girders: steel in shadow, one lit strip along the girder.
			float girder = step(0.8, fract(at_deck.x * 0.5 + at_deck.z * 0.5));
			color = vec3(0.03, 0.028, 0.03) + vec3(0.25, 0.1, 0.02) * girder * 0.15;
		} else if (t_wall < t_surface) {
			vec3 hit = origin + dir * t_wall;
			color = wall_shade(-hit.y, hit.xz);
		} else {
			vec3 hit = origin + dir * t_surface;
			if (is_pit) {
				// The pan: a dark grating with a dull red glow, the kill zone's floor.
				vec2 g = abs(fract(hit.xz * 0.5) - 0.5);
				float grid = step(0.46, max(g.x, g.y));
				float ember = noise(hit.xz * 0.35 + vec2(TIME * 0.05, 0.0));
				color = vec3(0.012) + pit_glow * (0.18 + 0.25 * ember) + vec3(0.05, 0.03, 0.0) * grid;
			} else {
				// Ripples: two octaves of noise drifting at `flow`, perturbing the reflection direction.
				vec2 q = hit.xz * 0.23 + vec2(TIME * flow, TIME * flow * 0.6);
				vec2 ripple = vec2(noise(q) - 0.5, noise(q * 2.3 + 17.0) - 0.5);
				vec3 r = normalize(vec3(dir.x + ripple.x * 0.12, -dir.y, dir.z + ripple.y * 0.12));
				// Fresnel: a grazing look reflects more (Schlick with water's F0 = 0.02).
				// Plus an art-directed floor: from the lead's 21-degree camera Schlick alone gives ~0.1 and the water
				// reads as a black hole (the first frames, round 10), not as a surface.
				float fresnel = 0.14 + 0.86 * pow(1.0 - clamp(r.y, 0.0, 1.0), 5.0);
				// What the water reflects: the venue's neon at the horizon, cyan on one axis and purple on the
				// other (the perimeter bars and the towers), a smoggy dark sky above. Streaked along the view.
				float azimuth = atan(r.x, r.z);
				float horizon = exp(-max(r.y, 0.0) * 3.5);
				float bars = 0.5 + 0.5 * sin(azimuth * 6.0 + ripple.x * 3.0);
				vec3 sky = mix(vec3(0.03, 0.02, 0.06), mix(neon_b, neon_a, bars) * 1.4, horizon);
				// Glints: sparse bright specks where a ripple faces the camera.
				float glint = smoothstep(0.93, 0.99, noise(q * 6.0)) * 0.6;
				// Slow bright ripple lines: the surface MOVES, which is what reads as water at a glance.
				float lines = smoothstep(0.47, 0.5, abs(fract(noise(q * 0.8) * 4.0) - 0.5)) * 0.08;
				color = mix(water_deep, sky, clamp(fresnel * reflection, 0.0, 1.0)) + neon_a * (glint + lines) * fresnel;
				// Shade the water a little under a bridge: its shadow reads the deck as ABOVE the water.
				if (under_deck(hit.xz)) {
					color *= 0.35;
				}
			}
		}
	}
	ALBEDO = color;
}

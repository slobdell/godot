// The trace that water.gdshader and pit.gdshader share (terrain stream, round 10; split by arena, round 12, so the
// water's wet look -- teal body, venue reflection, glints, lap line -- CANNOT reach the pits: they are two shaders).
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
// The including shader defines PIT (or not) before including this file.

// How far below the floor the walls go (water: to its bed; pit: the pan), and where the water line sits.
uniform float depth = 3.0;
uniform float water_line = 0.7;
// The ONE animated scalar: ripple phase per second. 0 freezes the water (frame pairs, tests).
uniform float flow = 0.35;
// Frame pairs (round 12): >= 0 replaces TIME, so two frames of one pair show the same instant of the swell.
uniform float freeze_time = -1.0;
// The deck underside, relative to the floor, for the ray to hit when it passes under a bridge.
uniform float deck_under = 0.45;
uniform int deck_count = 0;
uniform vec4 decks[8];
// Every footprint of this kind (min_x, min_z, max_x, max_z). A river built from several rectangles is ONE body of
// water: the trace hops from box to box and meets a wall only where the next ground is dry.
uniform int wet_count = 0;
uniform vec4 wet[16];
// Palette: the venue's night. Concrete walls and the kerb's light read on the far wall.
uniform vec3 wall_color : source_color = vec3(0.13, 0.135, 0.15);
uniform vec3 neon_a : source_color = vec3(0.0, 0.95, 1.0);
uniform vec3 neon_b : source_color = vec3(0.85, 0.0, 1.0);
uniform vec3 pit_glow : source_color = vec3(1.0, 0.12, 0.02);

varying vec3 world_pos;
varying vec4 box;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	box = vec4(UV, UV2);
}

float clock(float time) {
	return freeze_time >= 0.0 ? freeze_time : time;
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

bool in_any_wet(vec2 p) {
	for (int i = 0; i < 16; i++) {
		if (i >= wet_count) {
			break;
		}
		if (inside(p, wet[i])) {
			return true;
		}
	}
	return false;
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
#ifdef PIT
	float fade = exp(-below * 0.32);
#else
	float fade = exp(-below * 0.9);
#endif
	float pour = 0.85 + 0.15 * step(0.5, fract(below * 1.25));
	float stain = 0.8 + 0.2 * noise(along * 0.7 + vec2(below * 3.0, 0.0));
	vec3 c = wall_color * pour * stain * fade;
	// A thin emissive band 0.15 m under the lip: the kerb's own light, read on the far wall.
	float band = smoothstep(0.04, 0.0, abs(below - 0.18));
#ifdef PIT
	c += vec3(1.0, 0.75, 0.05) * band * 0.9;
	// The glow from the bottom climbs the walls, and the upper wall catches the kerb's amber: lit rim walls that
	// fall to black give the drop its height.
	c += pit_glow * 0.35 * exp(-(depth - below) * 0.6);
	c += vec3(1.0, 0.7, 0.1) * 0.12 * exp(-below * 0.8);
#else
	c += neon_a * band * 0.9;
#endif
	return c;
}

// The deck's underside and girders: steel in shadow, one lit strip along the girder.
vec3 deck_shade(vec3 at_deck) {
	float girder = step(0.8, fract(at_deck.x * 0.5 + at_deck.z * 0.5));
	return vec3(0.03, 0.028, 0.03) + vec3(0.25, 0.1, 0.02) * girder * 0.15;
}

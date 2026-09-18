// The city around the arena (feel X4, round 6): one open cylinder far outside the stands, drawn as two layers of
// building silhouettes with lit windows, a few neon signs and red aviation lamps on the tall towers. The lead's low camera
// (25 degrees, maybe lower) puts the horizon in every frame; this is what it lands on instead of black.
// UV.x runs once around the ring, UV.y from the ring's foot (0) to its top (1). Unshaded, and it makes its own haze
// (the scene's depth fog would bury anything this far out).
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled, depth_draw_opaque;

uniform float height_m = 220.0;
uniform float circumference_m = 4000.0;
uniform vec3 building : source_color = vec3(0.018, 0.018, 0.03);
uniform vec3 haze : source_color = vec3(0.13, 0.06, 0.11);
uniform float window_level = 0.55;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// One layer of towers: returns (roof height 0..1, column id, lamp) for this column of the ring.
vec3 towers(float around, float count, float seed, float low, float span) {
	float column = floor(around * count);
	float h = hash(vec2(column, seed));
	float roof = low + span * h * h;
	if (hash(vec2(column, seed + 7.0)) > 0.92) {
		roof = min(0.95, roof + span * 0.9);  // a skyscraper
	}
	return vec3(roof, column, step(0.97, hash(vec2(column, seed + 3.0))));
}

// Lit windows on a facade: floors 3.6 m, bays 4 m. Fades to its average lit value where a window is under ~2 px, so
// the far city doesn't shimmer as the camera moves.
vec3 windows(vec2 metres, float column, float seed) {
	vec2 cell = metres / vec2(4.0, 3.6);
	vec2 id = floor(cell);
	vec2 inside = fract(cell);
	float lit = step(1.0 - 0.28 * (0.6 + 0.8 * hash(vec2(column, seed + 11.0))), hash(id + column * 17.0 + seed));
	float pane = step(0.25, inside.x) * step(inside.x, 0.8) * step(0.3, inside.y) * step(inside.y, 0.75);
	float pick = hash(id * 1.7 + column);
	vec3 tint = pick > 0.85 ? vec3(0.45, 0.85, 1.0) : (pick > 0.8 ? vec3(1.0, 0.4, 0.8) : vec3(1.0, 0.72, 0.42));
	vec3 sharp = tint * lit * pane;
	vec3 average = tint * 0.28 * 0.25;
	float px = max(fwidth(cell.x), fwidth(cell.y));
	return mix(average, sharp, 1.0 - smoothstep(0.25, 0.6, px)) * window_level;
}

void fragment() {
	float y = UV.y;
	vec3 near = towers(UV.x, 150.0, 1.0, 0.2, 0.3);
	vec3 far = towers(UV.x + 0.37, 260.0, 5.0, 0.26, 0.42);
	vec3 color;
	float mist;
	if (y < near.x) {
		vec2 metres = vec2(UV.x * circumference_m, y * height_m);
		color = building + windows(metres, near.y, 1.0);
		// A neon sign on a few facades.
		if (near.z > 0.5 && abs(y - near.x * 0.8) < 0.012) {
			color += (hash(vec2(near.y, 9.0)) > 0.5 ? vec3(1.0, 0.1, 0.6) : vec3(0.1, 0.9, 1.0)) * 0.9;
		}
		mist = 0.3;
	} else if (y < far.x) {
		vec2 metres = vec2(UV.x * circumference_m * 1.3, y * height_m);
		color = building * 1.2 + windows(metres, far.y, 5.0) * 0.7;
		mist = 0.55;
		// Red aviation lamps on the tall ones.
		if (far.x > 0.6 && abs(y - far.x + 0.006) < 0.004 && fract(UV.x * 260.0) > 0.45 && fract(UV.x * 260.0) < 0.55) {
			color = vec3(2.0, 0.08, 0.05);
			mist = 0.0;
		}
	} else {
		discard;
	}
	// Smog is thickest at street level.
	mist = clamp(mist + (1.0 - smoothstep(0.0, 0.35, y)) * 0.3, 0.0, 0.9);
	ALBEDO = mix(color, haze, mist);
}

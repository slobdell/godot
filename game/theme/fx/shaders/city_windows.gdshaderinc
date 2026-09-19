// The city's lit windows (feel X4/round 7): shared by the distant skyline ring and the playable city blocks, so the
// horizon and the buildings you can drive past are one city. Floors 3.6 m, bays 4 m; a window under ~2 px fades to its
// average lit value so the far city doesn't shimmer as the camera moves.
float city_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 city_windows(vec2 metres, float column, float seed, float level) {
	vec2 cell = metres / vec2(4.0, 3.6);
	vec2 id = floor(cell);
	vec2 inside = fract(cell);
	float lit = step(1.0 - 0.28 * (0.6 + 0.8 * city_hash(vec2(column, seed + 11.0))), city_hash(id + column * 17.0 + seed));
	float pane = step(0.25, inside.x) * step(inside.x, 0.8) * step(0.3, inside.y) * step(inside.y, 0.75);
	float pick = city_hash(id * 1.7 + column);
	vec3 tint = pick > 0.85 ? vec3(0.45, 0.85, 1.0) : (pick > 0.8 ? vec3(1.0, 0.4, 0.8) : vec3(1.0, 0.72, 0.42));
	vec3 sharp = tint * lit * pane;
	vec3 average = tint * 0.28 * 0.25;
	float px = max(fwidth(cell.x), fwidth(cell.y));
	return mix(average, sharp, 1.0 - smoothstep(0.25, 0.6, px)) * level;
}


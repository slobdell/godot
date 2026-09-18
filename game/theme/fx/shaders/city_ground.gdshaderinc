// The city's streets at ground point `at` (world xz, metres): shared by city_ground.gdshader (the plane outside the
// arena) and night_sky.gdshader (which draws them below the horizon, where control's cutaway near plane clips every
// real surface between a camera past the wall and the wall itself).
const vec3 CITY_ASPHALT = vec3(0.012, 0.012, 0.018);
const vec3 CITY_ROAD = vec3(0.02, 0.019, 0.024);
const vec3 CITY_LAMP = vec3(0.9, 0.35, 0.06);
const float CITY_BLOCK_M = 70.0;
const float CITY_ROAD_M = 12.0;

float city_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// The concourse around the arena: concrete lit by the stands' spill, magenta-tinted like the walls' light bars, fading
// out over ~50 m past the wall (121 m). Linear values under ACES (white 6): anything much darker than the floor's
// crushes to pure black, which is how the first version of this was invisible.
const vec3 CITY_CONCOURSE = vec3(0.2, 0.13, 0.28);

vec3 city_ground(vec2 at) {
	vec2 cell = at / CITY_BLOCK_M;
	vec2 inside = fract(cell) * CITY_BLOCK_M;
	float street = 1.0 - step(CITY_ROAD_M, min(inside.x, inside.y));
	vec3 color = mix(CITY_ASPHALT, CITY_ROAD, street);
	vec2 corner = min(inside, vec2(CITY_BLOCK_M) - inside);
	float d_corner = length(corner - vec2(CITY_ROAD_M * 0.5));
	float along = min(abs(inside.x - CITY_BLOCK_M * 0.5), abs(inside.y - CITY_BLOCK_M * 0.5));
	float d_mid = length(vec2(along, min(corner.x, corner.y) - CITY_ROAD_M * 0.5));
	float lit = step(0.25, city_hash(floor(cell)));
	float pool = max(exp(-d_corner * d_corner / 40.0), exp(-d_mid * d_mid / 30.0) * 0.7) * lit;
	float outside = max(abs(at.x), abs(at.y)) - 121.0;
	float spill = exp(-max(outside, 0.0) / 50.0);
	float slabs = 0.92 + 0.08 * step(0.06, fract(at.x / 4.0)) * step(0.06, fract(at.y / 4.0));
	return color + CITY_LAMP * pool * 0.35 + CITY_CONCOURSE * spill * slabs;
}

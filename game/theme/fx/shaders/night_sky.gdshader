// The night sky over the arena (feel X4, round 6). Until round 6 the background was a flat near-black colour, which
// was fine from a camera looking down at the floor; at the lead's 25 degree camera (and lower) the sky is a fifth of the
// frame. A city at night lights its own smog from below: near-black at the zenith, a dull warm-magenta glow sitting on
// the horizon, and slow bands of low cloud catching it. Static on purpose (no TIME): a sky that changes every frame
// re-renders every frame. Nothing reads it for light (ambient comes from a colour, reflections are off).
// Drawn on a dome mesh (NightSky), not as the Environment's Sky: a Sky resource in the Compatibility renderer leaked its
// two 32x32 radiance textures across the title -> skirmish switch ("Texture with GL ID ... leaked 5460 bytes", control's
// shell-playtest; builder0 A/B with only the sky toggled).
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, shadows_disabled, depth_draw_never;

#include "res://game/theme/fx/shaders/city_ground.gdshaderinc"

uniform vec3 zenith : source_color = vec3(0.006, 0.006, 0.02);
uniform vec3 haze : source_color = vec3(0.16, 0.07, 0.13);
uniform vec3 haze_warm : source_color = vec3(0.2, 0.08, 0.1);
uniform vec3 ground : source_color = vec3(0.012, 0.01, 0.022);
uniform float haze_height = 0.22;
uniform float clouds = 0.35;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 eye = normalize(world - CAMERA_POSITION_WORLD);
	float up = eye.y;
	vec3 sky_color;
	if (up < 0.0) {
		// Below the horizon: the city's streets where this ray meets the ground. A camera past the wall has every real
		// surface between it and the wall clipped by control's cutaway, and without this the band under the near wall
		// was a void (control's played session at 12 degrees). Fades into the ground haze with distance.
		float reach = CAMERA_POSITION_WORLD.y / max(-up, 0.001);
		vec2 hit = CAMERA_POSITION_WORLD.xz + eye.xz * reach;
		sky_color = mix(city_ground(hit), ground, clamp(reach / 900.0, 0.0, 1.0));
	} else {
		float glow = exp(-up / haze_height);
		// The glow is warmer where the city is densest (one side of the horizon), magenta elsewhere.
		float warm = 0.5 + 0.5 * eye.x;
		vec3 color = mix(zenith, mix(haze, haze_warm, warm), glow);
		// Low cloud: stretched noise on a plane over the city, lit from below by the glow.
		// (Stretched by the plane projection toward the horizon already: more anisotropy than that reads as scanlines.)
		vec2 plane = eye.xz / (max(up, 0.04) + 0.15) * 1.2;
		float cloud = noise(plane * 1.3) * 0.65 + noise(plane * 3.1 + 5.0) * 0.35;
		cloud = smoothstep(0.45, 0.85, cloud) * smoothstep(0.02, 0.12, up) * (1.0 - smoothstep(0.35, 0.8, up));
		color += mix(haze, haze_warm, warm) * cloud * clouds * (0.4 + glow);
		sky_color = color;
	}
	ALBEDO = sky_color;
}

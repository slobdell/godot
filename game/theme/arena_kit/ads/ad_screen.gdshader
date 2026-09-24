// A giant arena screen (assets X2): shows its broadcast channel's feed (AdBroadcast's viewport) as an LED wall at night.
// Scanlines and an LED grid up close, a slow CRT flicker, and a glitch (tearing bands and RGB split) driven by the
// channel between ads and on big moments. One material per channel, shared by every screen on it. Visual only.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform sampler2D feed : source_color, filter_linear;
// Which part of the feed this ONE screen shows: xy = offset, zw = scale, in feed UV. The layout is authored portrait
// (AdBroadcast.LAYOUT, 320x640) and the ground screens are portrait too, so the default (0,0,1,1) is the whole feed
// on the whole panel. A panel of a different shape -- the airship's wide flank screens -- sets its own rect to fit
// the feed instead of stretching it; anything outside the feed is left as backlight, the way a stadium screen shows
// portrait content inside a wide wall. It is an INSTANCE uniform so every screen keeps the channel's ONE shared
// material (the "ten screens cost one layout" property) while cropping differently.
instance uniform vec4 feed_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float energy = 2.6;
// LED walls never reach true black: a faint backlight keeps the panel's shape readable at night.
uniform vec3 black_level = vec3(0.012, 0.014, 0.02);
uniform vec2 leds = vec2(120.0, 240.0);
uniform float scanline_depth = 0.16;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 uv = feed_rect.xy + UV * feed_rect.zw;
	// Off the feed (a letterboxed panel) there is no picture, only the wall's backlight -- sampling would smear the
	// edge pixel across the whole margin instead.
	float on_feed = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	float t = TIME;
	// Tearing: a few horizontal bands jump sideways while glitching, re-rolled 20 times a second.
	float band = floor(uv.y * 28.0);
	float roll = hash(band * 13.1 + floor(t * 20.0) * 7.7);
	uv.x += (roll - 0.5) * 0.16 * glitch * step(0.55, roll);
	float split = 0.0015 + 0.018 * glitch;
	vec3 color = vec3(texture(feed, uv + vec2(split, 0.0)).r, texture(feed, uv).g, texture(feed, uv - vec2(split, 0.0)).b);
	// Glitch blocks: dropped-signal rectangles.
	vec2 block = floor(uv * vec2(8.0, 16.0));
	float drop = step(0.93, hash(block.x * 3.7 + block.y * 17.3 + floor(t * 15.0))) * glitch;
	color = mix(color, vec3(color.g * 1.4, color.b * 0.2, color.r), drop);
	float scan = 1.0 - scanline_depth * (0.5 + 0.5 * sin(UV.y * leds.y * 6.2832));
	vec2 cell = abs(fract(UV * leds) - 0.5) * 2.0;
	float led = mix(0.72, 1.0, (1.0 - smoothstep(0.6, 1.0, cell.x)) * (1.0 - smoothstep(0.6, 1.0, cell.y)));
	float flicker = 0.95 + 0.05 * sin(t * 61.0) * sin(t * 3.1);
	vec2 edge = abs(UV - 0.5) * 2.0;
	float vignette = 1.0 - 0.25 * pow(max(edge.x, edge.y), 4.0);
	ALBEDO = (color * on_feed * scan * led * energy + black_level) * flicker * vignette;
}

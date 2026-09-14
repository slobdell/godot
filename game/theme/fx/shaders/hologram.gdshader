// Holographic billboard/ad: additive, scanlines, a scrolling glitch band, and procedural "text"
// blocks so it reads as signage without a texture. Flicker phase from world position.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.0, 0.6);
uniform vec3 accent : source_color = vec3(0.0, 0.95, 1.0);
uniform float energy = 1.6;
uniform float rows = 5.0;
uniform float seed = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453);
}

void fragment() {
	float phase = dot(NODE_POSITION_WORLD, vec3(0.37, 0.0, 0.91));
	float t = TIME + phase;
	vec2 uv = UV;
	// Glitch: a band that slides down and shifts pixels sideways.
	float band = step(abs(fract(t * 0.23) - uv.y), 0.03);
	uv.x += band * 0.04 * sin(t * 40.0);
	float scan = 0.65 + 0.35 * sin(uv.y * 220.0);
	// Border frame.
	vec2 edge = min(uv, 1.0 - uv);
	float frame = 1.0 - step(0.035, min(edge.x, edge.y * 2.5));
	// Text blocks: rows of random-width bars that change every second or two.
	float row = floor(uv.y * rows);
	float in_row = fract(uv.y * rows);
	float gap = step(0.25, in_row) * step(in_row, 0.75);
	float col = floor(uv.x * 18.0);
	float change = floor(t * 0.6 + row * 3.1);
	float lit = step(0.35, hash(vec2(col, row + change))) * gap;
	float inner = step(0.08, uv.x) * step(uv.x, 0.92) * step(0.1, uv.y) * step(uv.y, 0.9);
	float flick = 0.85 + 0.15 * step(0.5, hash(vec2(floor(t * 15.0), phase)));
	vec3 c = color * (frame + lit * inner * 0.8) + accent * band * 0.5;
	ALBEDO = c * scan * energy * flick;
}

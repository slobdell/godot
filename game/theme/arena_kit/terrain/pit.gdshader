// Pits for the `arena.terrain` slot (terrain stream, round 10; its own shader since round 12). A deep, black shaft
// with a dim red glow at the bottom: the kill zone's floor. It shares the interior-mapping trace with the water
// (terrain_trace.gdshaderinc) and nothing else, so the water's wet look cannot leak into it -- A3's rule, "pits stay
// pits", held by construction rather than by a flag. ONE material, ONE draw for every pit on the map, no lights.
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

#define PIT
#include "res://game/theme/arena_kit/terrain/terrain_trace.gdshaderinc"

// Measurement: 1 paints every pit pixel flat magenta, so a frame can be masked (`water-pairs` counts the pit pixels
// that change between the water's steps: it must be 0).
uniform float mask_out = 0.0;

void fragment() {
	vec3 dir = normalize(world_pos - CAMERA_POSITION_WORLD);
	vec3 origin = vec3(world_pos.x, 0.0, world_pos.z);
	vec3 color;
	if (dir.y > -0.001) {
		color = wall_color;
	} else {
		float t_wall = wall_t(origin, dir);
		float t_surface = depth / -dir.y;
		// A bridge deck over this footprint: the ray may meet its side or its underside before anything else.
		float t_deck = deck_under / -dir.y;
		vec3 at_deck = origin + dir * t_deck;
		if (t_deck < min(t_wall, t_surface) && under_deck(at_deck.xz)) {
			color = deck_shade(at_deck);
		} else if (t_wall < t_surface) {
			vec3 hit = origin + dir * t_wall;
			color = wall_shade(-hit.y, hit.xz);
		} else {
			vec3 hit = origin + dir * t_surface;
			// The pan: a dark grating with a dull red glow, the kill zone's floor.
			vec2 g = abs(fract(hit.xz * 0.5) - 0.5);
			float grid = step(0.46, max(g.x, g.y));
			float ember = noise(hit.xz * 0.35 + vec2(clock(TIME) * 0.05, 0.0));
			// Depth cue (feel's review): the glow pools at the WALLS' feet and the middle of the pan falls away to
			// black, so the floor reads as far down rather than as a flat red sheet.
			vec2 to_edge = min(hit.xz - box.xy, box.zw - hit.xz);
			float edge = smoothstep(9.0, 0.0, min(to_edge.x, to_edge.y));
			color = vec3(0.006) + pit_glow * (0.05 + 0.3 * edge) * (0.7 + 0.5 * ember) + vec3(0.05, 0.03, 0.0) * grid * edge;
		}
	}
	ALBEDO = mix(color, vec3(1.0, 0.0, 1.0), mask_out);
}

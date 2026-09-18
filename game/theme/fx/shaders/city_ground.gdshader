// The ground outside the arena (feel X4, round 6): the arena floor ends at 160 m and the city skyline stands at 640 m.
// Streets, car parks and sodium lamps, unlit and dark, under the scene's own fog so they fade into the city. One plane,
// one draw call, a few centimetres under the arena floor (which covers it inside 160 m).
// Colours are linear (the include's constants), so no source_color conversion.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://game/theme/fx/shaders/city_ground.gdshaderinc"

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = city_ground(world.xz);
}

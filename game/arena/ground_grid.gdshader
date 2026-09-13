// Flat ground with world-space grid lines, so motion is readable without textures.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.36, 0.42, 0.3);
uniform vec3 line_color : source_color = vec3(0.27, 0.32, 0.22);
uniform float cell_size = 4.0;
uniform float line_width = 0.08;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Distance (m) from this pixel to the nearest grid line on each axis.
	vec2 to_line = abs(fract(world_pos.xz / cell_size + 0.5) - 0.5) * cell_size;
	float on_line = 1.0 - step(line_width, min(to_line.x, to_line.y));
	ALBEDO = mix(base_color, line_color, on_line);
	ROUGHNESS = 1.0;
}

// Dark wet asphalt: low roughness so the pooled lights, muzzle flashes and explosions throw
// glossy highlights across it; faint neon lane markings on a grid so motion stays readable;
// cheap hash noise (no textures) breaks up the surface into patches and puddles.
shader_type spatial;
render_mode cull_back;

uniform vec3 base_color : source_color = vec3(0.035, 0.038, 0.05);
uniform vec3 patch_color : source_color = vec3(0.06, 0.055, 0.06);
uniform vec3 line_color : source_color = vec3(0.0, 0.55, 0.65);
uniform float line_energy = 0.35;
uniform float cell_size = 8.0;
uniform float line_width = 0.06;
uniform float puddle_roughness = 0.12;
uniform float dry_roughness = 0.55;

varying vec3 world_pos;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
			mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = value_noise(world_pos.xz * 0.08) * 0.65 + value_noise(world_pos.xz * 0.4) * 0.35;
	float puddle = smoothstep(0.55, 0.7, n);
	vec2 to_line = abs(fract(world_pos.xz / cell_size + 0.5) - 0.5) * cell_size;
	float on_line = 1.0 - smoothstep(line_width, line_width + 0.04, min(to_line.x, to_line.y));
	ALBEDO = mix(mix(base_color, patch_color, n), base_color * 0.6, puddle);
	ROUGHNESS = mix(dry_roughness, puddle_roughness, puddle);
	METALLIC = 0.0;
	SPECULAR = 0.6;
	EMISSION = line_color * line_energy * on_line * (1.0 - puddle * 0.5);
}

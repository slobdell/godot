// Generated vehicle bodies (Meshy PBR: albedo, normal, glTF ORM, emission) in the cyberpunk theme. One shared material
// per (texture set, team, paint, heat step): no instance uniforms, which cap the renderer at ~256 instances (render X2, round 5):
//   team_color  the model's own neon light bars (the cyan/magenta emission) glow in the TEAM color, so friend or
//               foe reads without extra geometry; red and amber warning lights keep their generated color
//   paint       rgb = the garage's body color, a = how strongly it shows through the grime (0 = none)
//   heat        weapons glow orange-white as they heat up (0 on hulls)
// A cool rim term lifts the silhouette of dark gunmetal against the night floor without a real light.
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_roughness_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// glTF ORM packing: G = roughness, B = metallic.
uniform sampler2D orm_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D emission_texture : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float emission_energy = 4.0;
// ACES tonemapping bleaches over-bright cyan to white: keep the team neon moderate (still over the glow threshold).
uniform float team_neon_energy = 0.6;
// Glossy dark metal under a black sky renders black blotches (orientation trip-up 43): keep a roughness floor.
uniform float roughness_floor = 0.5;
uniform float metallic_scale = 0.85;
uniform vec3 rim_color : source_color = vec3(0.5, 0.6, 1.0);
uniform float rim_strength = 0.22;
uniform float rim_power = 3.0;

uniform vec4 team_color : source_color = vec4(0.75, 0.75, 0.8, 1.0);
uniform vec4 paint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float heat = 0.0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1.0e-10)), d / (q.x + 1.0e-10), q.x);
}

void fragment() {
	vec3 base = texture(albedo_texture, UV).rgb;
	// Paint multiplies like a coat over the dirt: grime and hazard stripes stay visible.
	ALBEDO = base * mix(vec3(1.0), paint.rgb * 1.6, paint.a);
	vec4 orm = texture(orm_texture, UV);
	ROUGHNESS = max(orm.g, roughness_floor);
	METALLIC = orm.b * metallic_scale;
	NORMAL_MAP = texture(normal_texture, UV).rgb;

	vec3 glow = texture(emission_texture, UV).rgb;
	vec3 hsv = rgb_to_hsv(glow);
	float hue = hsv.x * 360.0;
	// Warm, saturated texels are warning lights and beacons: they stay red/amber on both teams.
	float warm = clamp(step(hue, 65.0) + step(335.0, hue), 0.0, 1.0) * step(0.3, hsv.y);
	vec3 neon = mix(team_color.rgb * hsv.z * team_neon_energy, glow, warm);

	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	// Heat: a dull red glow that turns orange-white only near the top (cubic, so warm barrels stay dark).
	vec3 hot = mix(vec3(0.9, 0.12, 0.01), vec3(1.0, 0.7, 0.35), heat * heat) * heat * heat * heat * 2.5;
	EMISSION = neon * emission_energy + rim_color * rim * rim_strength + hot;
}

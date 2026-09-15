// Shipping containers (assets X1): every container of a kind in one MultiMesh, all kinds on one texture set, and each
// instance's look chosen here from INSTANCE_CUSTOM (packed by ContainerYard.look):
//   r = paint index / 16 (palette), g = stencil cell / 8, b = rust 0..1, a = door opening 0..1 (1 = folded back 270°)
// Mesh attributes (ContainerMesh): UV in meters / 2.4 m, UV2 = side panel meters, or a face code in y with ± the hinge x
// in x on door leaves.
// Visual only; the trig here never touches the simulation.
shader_type spatial;
render_mode cull_back;

uniform sampler2D surface_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stencil_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 palette[16] : source_color;
uniform float height_m = 2.59;
uniform float hinge_z = 1.24;
// The stencil band on a side panel: 4.8 × 1.2 m, centered, bottom at 0.72 m.
uniform vec4 stencil_rect = vec4(-2.4, 0.72, 4.8, 1.2);
uniform vec3 rim_color : source_color = vec3(0.5, 0.6, 1.0);
uniform float rim_strength = 0.12;

varying flat vec4 v_look;
varying vec3 v_local;
varying float v_seed;

void vertex() {
	v_look = INSTANCE_CUSTOM;
	if (UV2.y < 0.0 && abs(UV2.x) > 0.5) {
		float side = sign(UV2.x);
		vec2 hinge = vec2(abs(UV2.x), side * hinge_z);
		float phi = -side * INSTANCE_CUSTOM.a * radians(270.0);
		float c = cos(phi);
		float s = sin(phi);
		vec2 d = VERTEX.xz - hinge;
		VERTEX.xz = hinge + vec2(d.x * c + d.y * s, -d.x * s + d.y * c);
		NORMAL.xz = vec2(NORMAL.x * c + NORMAL.z * s, -NORMAL.x * s + NORMAL.z * c);
		TANGENT.xz = vec2(TANGENT.x * c + TANGENT.z * s, -TANGENT.x * s + TANGENT.z * c);
	}
	v_local = VERTEX;
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_seed = fract(sin(dot(origin.xz, vec2(12.9898, 78.233)) + origin.y * 3.7) * 43758.5453);
}

void fragment() {
	float code = UV2.y;
	bool side_panel = code >= 0.0;
	bool frame = code < -2.0 && code > -4.0;
	bool interior = code < -4.0;
	vec4 det = texture(detail_tex, UV);
	vec4 surf = texture(surface_tex, UV * 1.6 + vec2(v_seed * 5.1, v_seed * 2.7));

	vec3 paint = palette[clamp(int(v_look.r * 16.0), 0, 15)] * (0.86 + det.a * 0.26);
	float height = clamp(v_local.y / height_m, 0.0, 1.0);
	// Rust gathers where water sits: along the bottom rail and under the roof rail, then runs down in streaks. The
	// middle of a panel only chips on badly kept containers.
	float band = max(1.0 - smoothstep(0.0, 0.3, height), smoothstep(0.86, 1.0, height));
	float rust = v_look.b * (0.42 + 0.85 * band + det.b * 0.35) + (frame ? 0.15 : 0.0);
	float bare = 1.0 - smoothstep(rust - 0.05, rust + 0.02, surf.a);
	vec3 rust_color = surf.rgb * vec3(0.66, 0.56, 0.5);
	paint = mix(vec3(dot(paint, vec3(0.3, 0.59, 0.11))), paint, 0.7);
	vec3 albedo = mix(paint * (frame ? 0.72 : 1.0), rust_color, bare);

	if (side_panel) {
		vec2 s = (UV2 - stencil_rect.xy) / stencil_rect.zw;
		if (s.x > 0.0 && s.x < 1.0 && s.y > 0.0 && s.y < 1.0) {
			float cell = floor(v_look.g * 8.0);
			vec2 atlas = (vec2(mod(cell, 2.0), floor(cell / 2.0)) + vec2(s.x, 1.0 - s.y)) / vec2(2.0, 4.0);
			vec4 stencil = textureLod(stencil_tex, atlas, 0.0);
			albedo = mix(albedo, stencil.rgb, stencil.a * (1.0 - bare));
		}
	}
	// Grime streaks run down from the roof rail.
	float grime = det.b * (0.2 + 0.5 * v_look.b) * (0.35 + 0.65 * height);
	albedo *= 1.0 - grime;

	if (interior) {
		albedo = vec3(0.025);
	} else if (!frame) {
		vec2 n = det.rg * 2.0 - 1.0;
		NORMAL_MAP = vec3(det.rg, sqrt(max(0.0, 1.0 - dot(n, n))) * 0.5 + 0.5);
	}
	ALBEDO = albedo;
	ROUGHNESS = interior ? 1.0 : mix(0.6, 0.92, bare);
	METALLIC = interior ? 0.0 : mix(0.08, 0.35, bare);
	SPECULAR = 0.35;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color * rim * rim_strength * (interior ? 0.0 : 1.0);
}

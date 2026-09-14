// Transient effects in one MultiMesh / one draw: flipbook fireballs, muzzle-flash stars, and
// ground glows. Animation runs entirely here from a start time; the script only writes an
// instance when an effect starts and sets `now` once per frame.
// Per instance: COLOR = tint; INSTANCE_CUSTOM = (start s, duration s, size m, kind).
//   kind 0: fireball flipbook billboard   kind 1: muzzle star billboard   kind 2: flat ground glow
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 frames = vec2(4.0, 4.0);
uniform float now = 0.0;
uniform float fire_boost = 2.5;

varying float v_age;
varying float v_kind;
varying vec3 v_color;
varying float v_seed;

void vertex() {
	float start = INSTANCE_CUSTOM.x;
	float duration = max(INSTANCE_CUSTOM.y, 0.001);
	float size = INSTANCE_CUSTOM.z;
	v_kind = INSTANCE_CUSTOM.w;
	v_age = (now - start) / duration;
	float alive = step(0.0, v_age) * step(v_age, 1.0);
	vec3 center = MODEL_MATRIX[3].xyz;
	v_seed = fract(sin(dot(center.xz, vec2(12.9898, 78.233))) * 43758.5453);
	// QuadMesh vertices span -0.5..0.5.
	vec2 corner = VERTEX.xy * size * alive;
	if (v_kind > 1.5) {
		// Ground glow: lies flat at the effect's position, slightly above the floor.
		vec3 world = vec3(center.x + corner.x, 0.06, center.z + corner.y);
		VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	} else {
		float angle = v_seed * 6.2831;
		mat2 spin = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
		vec4 view_center = VIEW_MATRIX * vec4(center, 1.0);
		VERTEX = view_center.xyz + vec3(spin * corner, 0.0);
	}
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_color = COLOR.rgb;
}

void fragment() {
	float age = clamp(v_age, 0.0, 0.999);
	if (v_kind < 0.5) {
		float count = frames.x * frames.y;
		float position = age * (count - 1.0);
		float f0 = floor(position);
		float f1 = min(f0 + 1.0, count - 1.0);
		vec2 cell0 = vec2(mod(f0, frames.x), floor(f0 / frames.x));
		vec2 cell1 = vec2(mod(f1, frames.x), floor(f1 / frames.x));
		vec4 a = texture(atlas, (cell0 + UV) / frames);
		vec4 b = texture(atlas, (cell1 + UV) / frames);
		vec4 tex = mix(a, b, fract(position));
		// The atlas is premultiplied: fire is bright rgb with low alpha, smoke dark with alpha.
		ALBEDO = tex.rgb * v_color * mix(fire_boost, 1.0, tex.a);
		ALPHA = tex.a;
	} else if (v_kind < 1.5) {
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		float theta = atan(p.y, p.x);
		float rays = pow(abs(cos(theta * 2.5 + v_seed * 3.0)), 18.0) * clamp(1.0 - r, 0.0, 1.0);
		float core = clamp(1.0 - r * 2.2, 0.0, 1.0);
		float fade = 1.0 - age;
		vec3 color = mix(v_color, vec3(1.0), core);
		ALBEDO = color * (rays * 2.0 + core * core * 3.0) * fade;
		ALPHA = 0.0;
	} else {
		vec2 p = UV * 2.0 - 1.0;
		float falloff = clamp(1.0 - dot(p, p), 0.0, 1.0);
		float fade = (1.0 - age) * (1.0 - age);
		ALBEDO = v_color * falloff * falloff * fade * 1.5;
		ALPHA = 0.0;
	}
}

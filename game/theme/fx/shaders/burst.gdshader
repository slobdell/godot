// Transient effects in one MultiMesh / one draw: flipbook fireballs, muzzle-flash stars, ground glows, shockwave rings,
// smoke and dust puffs, scorch marks, spark sprays, and debris. Animation runs entirely here from a start time; the
// script only writes an instance when an effect starts and sets `now` once per frame.
// Per instance: COLOR.rgb = tint, COLOR.a = variant (0..1, kind-specific);
//   INSTANCE_CUSTOM = (start s, duration s, size m, kind);
//   the instance basis is not a rotation: column 0 = velocity (m/s), column 1 = (drag 1/s, gravity m/s², rise m/s).
//   kind 0: fireball flipbook billboard   kind 1: muzzle star billboard   kind 2: flat ground glow
//   kind 3: flat shockwave ring            kind 4: smoke/dust puff (variant = darkness)
//   kind 5: flat scorch mark               kind 6: spark spray billboard (additive)
//   kind 7: debris/dirt spray billboard (variant = chunkiness)
//   kind 8: weak-spot flare billboard: a four-point glint that pops and spins, the "critical hit" read
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 frames = vec2(4.0, 4.0);
uniform float now = 0.0;
uniform float fire_boost = 2.5;
// Sparks and debris chunks per spray (the quality tier lowers it).
uniform int spray_count = 12;

varying float v_age;
varying float v_kind;
varying vec4 v_color;
varying float v_seed;
varying float v_size;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	float start = INSTANCE_CUSTOM.x;
	float duration = max(INSTANCE_CUSTOM.y, 0.001);
	float size = INSTANCE_CUSTOM.z;
	v_kind = INSTANCE_CUSTOM.w;
	float seconds = now - start;
	v_age = seconds / duration;
	float alive = step(0.0, v_age) * step(v_age, 1.0);
	vec3 velocity = MODEL_MATRIX[0].xyz;
	float drag = MODEL_MATRIX[1].x;
	float gravity = MODEL_MATRIX[1].y;
	float rise = MODEL_MATRIX[1].z;
	float t = max(seconds, 0.0);
	float travel = drag > 0.001 ? (1.0 - exp(-drag * t)) / drag : t;
	vec3 center = MODEL_MATRIX[3].xyz + velocity * travel + vec3(0.0, rise * t - 0.5 * gravity * t * t, 0.0);
	v_seed = hash(MODEL_MATRIX[3].xz + vec2(start * 3.1, start * 1.7));
	// Smoke puffs swell as they age; rings and sprays grow in the fragment shader instead.
	float grow = v_kind > 3.5 && v_kind < 4.5 ? 0.45 + 0.55 * sqrt(clamp(v_age, 0.0, 1.0)) : 1.0;
	v_size = size;
	// QuadMesh vertices span -0.5..0.5.
	vec2 corner = VERTEX.xy * size * grow * alive;
	if (v_kind > 1.5 && v_kind < 3.5 || v_kind > 4.5 && v_kind < 5.5) {
		// Ground glow, shockwave ring, scorch: flat on the floor at the effect's position.
		float lift = v_kind > 4.5 ? 0.035 : 0.06;
		vec3 world = vec3(center.x + corner.x, lift, center.z + corner.y);
		VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	} else {
		float angle = v_seed * 6.2831 + (v_kind > 3.5 && v_kind < 4.5 ? t * (v_seed - 0.5) * 0.8 : 0.0);
		mat2 spin = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
		// Sprays don't spin: their gravity must fall down the screen.
		if (v_kind > 5.5) {
			spin = mat2(vec2(1.0, 0.0), vec2(0.0, 1.0));
		}
		vec4 view_center = VIEW_MATRIX * vec4(center, 1.0);
		VERTEX = view_center.xyz + vec3(spin * corner, 0.0);
	}
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_color = COLOR;
}

// Distance from p to the segment a-b.
float segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.00001), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	float age = clamp(v_age, 0.0, 0.999);
	vec3 tint = v_color.rgb;
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
		ALBEDO = tex.rgb * tint * mix(fire_boost, 1.0, tex.a);
		ALPHA = tex.a;
	} else if (v_kind < 1.5) {
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		float theta = atan(p.y, p.x);
		float rays = pow(abs(cos(theta * 2.5 + v_seed * 3.0)), 18.0) * clamp(1.0 - r, 0.0, 1.0);
		float core = clamp(1.0 - r * 2.2, 0.0, 1.0);
		float fade = 1.0 - age;
		vec3 color = mix(tint, vec3(1.0), core);
		ALBEDO = color * (rays * 2.0 + core * core * 3.0) * fade;
		ALPHA = 0.0;
	} else if (v_kind < 2.5) {
		vec2 p = UV * 2.0 - 1.0;
		float falloff = clamp(1.0 - dot(p, p), 0.0, 1.0);
		float fade = (1.0 - age) * (1.0 - age);
		ALBEDO = tint * falloff * falloff * fade * 1.5;
		ALPHA = 0.0;
	} else if (v_kind < 3.5) {
		// Shockwave: a bright ring racing outward (fast at first), thinning and fading; a faint dust fill inside it.
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		// The front starts a little out from the center and ramps in, so frame one is a ring, not a blinding disc.
		float front = 0.12 + 0.88 * (1.0 - pow(1.0 - age, 3.0));
		float width = mix(0.08, 0.035, age);
		float ring = exp(-pow((r - front) / width, 2.0));
		float wobble = 0.8 + 0.2 * value_noise(vec2(atan(p.y, p.x) * 3.0 + v_seed * 10.0, age * 4.0));
		float fade = (1.0 - age) * (1.0 - age) * smoothstep(0.0, 0.06, age);
		float inside = step(r, front) * (1.0 - r / max(front, 0.001)) * 0.25;
		ALBEDO = tint * (ring * wobble * 2.2 + inside) * fade * step(r, 1.0);
		ALPHA = 0.0;
	} else if (v_kind < 4.5) {
		// Smoke or dust: a soft lumpy puff, premultiplied (darkens what's behind), thinning as it swells.
		vec2 p = UV * 2.0 - 1.0;
		float n = value_noise(p * 2.3 + v_seed * 17.0 + vec2(0.0, -age * 1.5)) * 0.6
				+ value_noise(p * 5.1 - v_seed * 9.0) * 0.4;
		float shape = clamp(1.0 - length(p) * (0.8 + 0.6 * n), 0.0, 1.0);
		// Soft all the way to the edge (no hard silhouette), thinning out as it ages.
		float density = shape * (2.0 - shape) * (1.0 - age) * smoothstep(0.0, 0.08, age);
		float darkness = v_color.a;
		ALPHA = density * mix(0.6, 0.9, darkness);
		// Unshaded smoke in a night arena must stay dim: moonlit grey for pale smoke and dust, near black for soot.
		ALBEDO = tint * mix(0.95, 0.08, darkness) * ALPHA;
	} else if (v_kind < 5.5) {
		// Scorch: a ragged dark blast mark with a still-hot core that cools, fading out over the last 30%.
		vec2 p = UV * 2.0 - 1.0;
		float angle = atan(p.y, p.x);
		float edge = 0.62 + 0.28 * value_noise(vec2(angle * 2.0 + v_seed * 31.0, v_seed * 7.0))
				+ 0.12 * value_noise(vec2(angle * 7.0, v_seed * 3.0));
		float r = length(p) / edge;
		float mark = smoothstep(1.0, 0.55, r) * (0.75 + 0.25 * value_noise(p * 6.0 + v_seed * 13.0));
		float fade = 1.0 - smoothstep(0.7, 1.0, age);
		ALPHA = mark * 0.82 * fade;
		float heat = smoothstep(0.45, 0.0, r) * (1.0 - smoothstep(0.0, 0.08, age));
		ALBEDO = vec3(1.0, 0.35, 0.08) * heat * 1.5 * ALPHA;
	} else if (v_kind < 6.5) {
		// Sparks: thin bright streaks flung out of the center, falling under gravity (screen-down), cooling to the tint.
		vec2 p = (UV * 2.0 - 1.0) * vec2(1.0, -1.0);
		float light = 0.0;
		float fly = 1.0 - pow(1.0 - age, 2.0);
		for (int i = 0; i < spray_count; i++) {
			float fi = float(i);
			float angle = hash(vec2(v_seed * 91.0, fi)) * 6.2831;
			float speed = 0.35 + 0.6 * hash(vec2(fi, v_seed * 47.0));
			vec2 dir = vec2(cos(angle), abs(sin(angle)) * 0.8 + 0.2 * sin(angle));
			vec2 head = dir * speed * fly - vec2(0.0, 0.9 * age * age);
			vec2 velocity = dir * speed * 2.0 * (1.0 - age) - vec2(0.0, 1.8 * age);
			vec2 tail = head - velocity * 0.12;
			float d = segment(p, head, tail);
			// At least ~7 cm wide whatever the spray's size, so small sprays don't vanish below a pixel.
			light += smoothstep(max(0.02, 0.07 / max(v_size, 0.1)), 0.0, d) * step(hash(vec2(fi, v_seed)) * 0.6, 1.0 - age);
		}
		vec3 hot = mix(vec3(1.0, 0.95, 0.8), tint, age);
		ALBEDO = hot * light * 3.0 * (1.0 - age * age);
		ALPHA = 0.0;
	} else if (v_kind > 7.5) {
		// Weak-spot flare: a hot four-point glint that punches out fast, turns a little, and shrinks away, with a ring.
		vec2 p = UV * 2.0 - 1.0;
		float spin = age * 1.2 + v_seed;
		mat2 rot = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin)));
		vec2 q = rot * p;
		float pop = 1.0 - pow(age, 0.5);
		float star = pow(max(0.0, 1.0 - abs(q.x) * 14.0), 2.0) * max(0.0, 1.0 - abs(q.y) / max(pop, 0.01))
				+ pow(max(0.0, 1.0 - abs(q.y) * 14.0), 2.0) * max(0.0, 1.0 - abs(q.x) / max(pop, 0.01));
		float r = length(p);
		float core = exp(-r * r * 60.0) * pop;
		float ring = exp(-pow((r - (0.2 + age * 0.7)) / 0.04, 2.0)) * (1.0 - age);
		// Gold, not white: only the very core goes white-hot, so the glint keeps its "critical hit" color under bloom.
		ALBEDO = (tint * (star * 1.6 + ring * 1.2) + mix(tint, vec3(1.0), 0.6) * core * 1.8) * (1.0 - age * age);
		ALPHA = 0.0;
	} else {
		// Debris or dirt: jagged shards thrown up and falling, tumbling (variant 1 = steel shards, 0 = dirt clods).
		vec2 p = (UV * 2.0 - 1.0) * vec2(1.0, -1.0);
		float cover = 0.0;
		float lit = 0.0;
		float shards = v_color.a;
		float chunk = mix(0.034, 0.034, shards);
		for (int i = 0; i < spray_count; i++) {
			float fi = float(i);
			float angle = mix(0.25, 2.9, hash(vec2(v_seed * 13.0, fi)));
			float speed = 0.45 + 0.5 * hash(vec2(fi * 3.0, v_seed * 29.0));
			vec2 dir = vec2(cos(angle), sin(angle));
			vec2 center = dir * speed * age * 1.6 - vec2(0.0, 1.5 * age * age);
			float spin = age * 9.0 * (hash(vec2(fi, 5.0)) - 0.5) + fi;
			mat2 rot = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin)));
			vec2 q = rot * (p - center);
			float size = chunk * (0.5 + hash(vec2(fi, v_seed * 3.0)));
			// Steel: a thin sliver; dirt: a rounded lump.
			vec2 extent = mix(vec2(size, size * 0.8), vec2(size * 1.6, size * 0.4), shards);
			float inside = shards > 0.5 ? step(abs(q.x) / extent.x + abs(q.y) / extent.y, 1.0) : step(length(q / extent), 1.0);
			cover = max(cover, inside);
			lit = max(lit, inside * step(0.2 * extent.y, q.y));
		}
		float fade = 1.0 - smoothstep(0.7, 1.0, age);
		ALPHA = cover * fade * 0.95;
		// A sliver of light along each piece's upper edge (the fire behind it), so debris reads as solid, not holes.
		ALBEDO = (tint * 0.25 + lit * mix(vec3(0.35, 0.22, 0.12), vec3(0.9, 0.5, 0.2), shards) * 0.6) * ALPHA;
	}
}

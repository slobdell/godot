// Round 39 (feedback F1, his "never hide an enemy inside a range the player was shown"): the radar's fog layer. The
// visibility field's picture (L8: 0 never, ~0.35 seen, 1 visible now) clipped to each crew's sight circle as it is NOW
// (FogViewers: x, z, radius per crew; -1 = no clip), as the 3D fog sheet does. Keep `clip_to_sight` in step with
// FogViewers.shown and game/theme/fx/shaders/fog_of_war.gdshader.
shader_type canvas_item;

uniform vec4 viewers[64];
uniform int viewer_count = -1;
// World xz of the texture's (0, 0) corner and its side in metres (UV spans the field whatever way it is drawn).
uniform vec2 origin_m = vec2(-160.0, -160.0);
uniform float size_m = 320.0;
uniform float seen_v = 0.3529;
uniform float clip_soft_m = 1.5;

varying vec4 tint;

float clip_to_sight(float v, vec2 at) {
	if (viewer_count < 0 || v <= seen_v) {
		return v;
	}
	float best = 1e9;
	for (int i = 0; i < viewer_count; i++) {
		best = min(best, distance(at, viewers[i].xy) - viewers[i].z);
		if (best <= -clip_soft_m) {
			break;
		}
	}
	return mix(min(v, seen_v), v, 1.0 - smoothstep(-clip_soft_m, 0.0, best));
}

void vertex() {
	tint = COLOR;
}

void fragment() {
	float v = clip_to_sight(texture(TEXTURE, UV).r, origin_m + UV * size_m);
	COLOR = vec4(vec3(v), 1.0) * tint;
}

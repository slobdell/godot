// The arena crowd (art X5): every spectator is one MultiMesh instance of a camera-facing quad (one draw call for the
// whole crowd). Instance transforms are a translation and uniform scale (no rotation). Per instance: COLOR = clothing
// tint, INSTANCE_CUSTOM = (phase 0..1, figure 0..1, seat x and z packed as (v + 500) / 1000 in b and a, so the shader
// knows who is near the action). Motion lives here, not in scripts:
//   idle   a slow sway and bob, each person on their own phase
//   cheer  `excitement` (0..1, crowd-wide) plus a local pulse around `event_position` (xz, radius, strength) makes
//          people jump and swap to their arms-up frame (+4 in the atlas); a few phone flashes pop when it's loud
// Alpha scissor (no blending): no sorting and no overdraw stacking.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert, specular_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;  // 8 frames: 0-3 rest, 4-7 cheering
uniform float excitement = 0.1;
uniform vec4 event_position = vec4(0.0, 0.0, 60.0, 0.0);  // x, z, radius, strength 0..1
uniform float rim = 0.35;
// Feel X2 (round 6): the stands are floodlit, so the crowd is lit as a bright mass: from the camera's usual 60-250 m a
// spectator is 7-25 px tall and reads only by value and colour against the dark metal of the stands (crowd-look).
uniform float lamp = 1.0;

varying float frame;
varying float flash;
varying float skin_seed;

float hash1(float n) {
	return fract(sin(n * 91.345) * 47453.5453);
}

void vertex() {
	float phase = INSTANCE_CUSTOM.r;
	skin_seed = phase;
	vec2 seat = vec2(INSTANCE_CUSTOM.b, INSTANCE_CUSTOM.a) * 1000.0 - 500.0;
	float near = 1.0 - clamp(length(seat - event_position.xy) / event_position.z, 0.0, 1.0);
	float want = clamp(excitement + near * event_position.w, 0.0, 1.0);
	// People react at different thresholds: a calm crowd has a few standing fans, a roaring one is all arms.
	float cheer = step(phase, want * 1.15 - 0.05);
	float bounce = cheer * abs(sin(TIME * (6.0 + phase * 3.0) + phase * 6.28)) * 0.3 * want;
	float sway = sin(TIME * (1.1 + phase) + phase * 12.0) * 0.05;
	frame = floor(INSTANCE_CUSTOM.g * 3.999) + cheer * 4.0;
	flash = step(0.99, hash1(floor(TIME * 4.0) + phase * 977.0)) * want;

	// Camera-facing around the vertical axis. The mesh quad spans x -1..1, y 0..1 (feet at the origin).
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 to_camera = CAMERA_POSITION_WORLD - origin;
	vec3 right = normalize(vec3(to_camera.z, 0.0, -to_camera.x) + vec3(1e-4, 0.0, 0.0));
	float scale = length(MODEL_MATRIX[1].xyz);
	VERTEX = right * VERTEX.x * 0.25 + vec3(0.0, VERTEX.y + bounce / scale, 0.0) + right * sway * VERTEX.y;
	NORMAL = normalize(vec3(to_camera.x, 0.0, to_camera.z) + vec3(0.0, 1e-4, 0.0));
}

void fragment() {
	vec4 figure = texture(atlas, vec2((UV.x + frame) / 8.0, UV.y));
	ALPHA = figure.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	// Heads and hands (atlas G) in a skin tone of this person's own (from the phase hash), the rest in their clothes.
	float tone = fract(skin_seed * 7.31);
	vec3 skin = mix(vec3(0.93, 0.74, 0.6), vec3(0.42, 0.28, 0.2), tone);
	vec3 base = mix(COLOR.rgb, skin, smoothstep(0.3, 0.7, figure.g));
	// Lit from the floodlights above: faces and shoulders catch light, the body falls into the stands' shadow.
	ALBEDO = base * figure.r * mix(1.1, 0.55, UV.y);
	// The floodlights never reach the stands as real light: the crowd is lit as emission (brighter up top, where the
	// lamps catch faces and raised arms), and the odd phone flash pops at head height.
	EMISSION = ALBEDO * rim * 2.2 * lamp + vec3(flash * 3.0) * step(0.08, UV.y) * step(UV.y, 0.22);
}

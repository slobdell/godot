// Round 37 (feedback, F1 cone c): the Sonic Emitter's wall of sound as a shimmer in the air -- an open cone drawn
// additively, pressure rings running from the horns to the cone's reach, brightest at its rim (view-facing fresnel).
// CylinderMesh UV.y: 0 at the narrow end (the horns) -> 1 at the far end (the weapon's range). No texture.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 tint = vec3(0.62, 0.48, 1.0);
uniform float intensity = 1.0;
uniform float now = 0.0;

void fragment() {
	float along = UV.y;
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - facing, 2.0);
	float rings = 1.0 - smoothstep(0.0, 0.16, abs(fract(along * 5.0 - now * 1.8) - 0.5));
	float reach = smoothstep(0.0, 0.08, along) * (1.0 - smoothstep(0.8, 1.0, along));
	float light = (rings * (0.35 + 0.65 * rim) + rim * 0.18) * reach;
	ALBEDO = tint * light * intensity;
}

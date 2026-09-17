// Emissive parts of procedural vehicles (ColorMeshBuilder's glow surface): vertex color × energy,
// shared by every tank. Vertex alpha is a heat mask: `heat` pushes masked parts from their color toward orange-white;
// `flash` brightens everything briefly. Both are plain uniforms on a few shared materials, one per quantized
// (heat, flash) step (ColorMeshBuilder.glow_material): no instance uniforms (render X2, round 5).
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;

uniform float energy = 1.7;
uniform float heat = 0.0;
uniform float flash = 0.0;

void fragment() {
	float mask = COLOR.a;
	vec3 hot = mix(vec3(1.0, 0.25, 0.02), vec3(1.0, 0.85, 0.5), heat) * (1.0 + 4.0 * heat * heat);
	vec3 base = COLOR.rgb * energy;
	ALBEDO = mix(base, max(base * 0.35, hot), mask * smoothstep(0.02, 0.35, heat)) * (1.0 + flash * 2.0);
}

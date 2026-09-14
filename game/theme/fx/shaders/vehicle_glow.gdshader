// Emissive parts of procedural vehicles (ColorMeshBuilder's glow surface): vertex color × energy,
// shared by every tank. Vertex alpha is a heat mask: `heat` (per instance, set_heat) pushes masked
// parts from their color toward orange-white. `flash` (per instance) brightens everything briefly.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;

uniform float energy = 1.7;
instance uniform float heat = 0.0;
instance uniform float flash = 0.0;

void fragment() {
	float mask = COLOR.a;
	vec3 hot = mix(vec3(1.0, 0.25, 0.02), vec3(1.0, 0.85, 0.5), heat) * (1.0 + 4.0 * heat * heat);
	vec3 base = COLOR.rgb * energy;
	ALBEDO = mix(base, max(base * 0.35, hot), mask * smoothstep(0.02, 0.35, heat)) * (1.0 + flash * 2.0);
}

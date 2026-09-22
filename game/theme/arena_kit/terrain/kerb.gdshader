// The kerb around every water channel and pit (terrain, round 10): the visible half of the 0.9 m rim collider,
// built from the SAME boxes (`ArenaTerrain.rim_slabs`), so what a hull stops against is exactly what is drawn.
// ONE material for every kerb on the map: COLOR.r = 1 marks a pit's kerb (hazard stripes, amber lip), 0 a water
// kerb (bare concrete, a cyan lip). Lit by the scene like every other concrete prop; the lip line is emissive so the
// edge of the drop reads at night from the lead's camera without adding a light.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 concrete : source_color = vec3(0.16, 0.16, 0.17);
uniform vec3 hazard : source_color = vec3(1.0, 0.72, 0.0);
uniform vec3 water_lip : source_color = vec3(0.0, 0.95, 1.0);
uniform float lip_energy = 2.2;

varying vec3 world_pos;
varying vec3 world_normal;
varying float pit;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	pit = COLOR.r;
}

void fragment() {
	bool top = world_normal.y > 0.5;
	vec3 base = concrete;
	vec3 glow = vec3(0.0);
	if (pit > 0.5) {
		// Diagonal hazard stripes, 0.6 m pitch, on the top and the sides alike.
		float stripe = step(0.5, fract((world_pos.x + world_pos.z + world_pos.y) / 1.2));
		base = mix(vec3(0.02), hazard * 0.55, stripe);
		glow = hazard * stripe * (top ? 0.35 : 0.12);
	}
	// The lip: an emissive line along the top edge of every face, which is where a kerb meets the drop.
	float lip = top ? 0.0 : smoothstep(0.78, 0.86, world_pos.y);
	glow += (pit > 0.5 ? hazard : water_lip) * lip * lip_energy;
	ALBEDO = base;
	ROUGHNESS = 0.8;
	METALLIC = 0.0;
	EMISSION = glow;
}

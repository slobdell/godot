// Round 19 (board, S2): a scoring zone drawn on the floor -- the lead: "there's very little indication that ... standing
// in the ring scores points". A flat decal per zone: a dashed white rim while nobody has it; a capture arc that runs
// round the rim in the colour of whoever stands in it; when held, the rim solid in the holder's colour, the floor
// tinted, and rings flowing INWARD once a second (the points going in). Visual only.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float radius_m = 15.0;
uniform float size_m = 34.0;
// 0..1 of the capture, and the colour of the side taking it.
uniform float fill = 0.0;
uniform vec3 fill_color : source_color = vec3(1.0);
// 1 while a side holds it (and so scores), with that side's colour.
uniform float held = 0.0;
uniform vec3 held_color : source_color = vec3(1.0);
// 1 while both sides stand in it (the capture is frozen): the rim flickers.
uniform float contested = 0.0;
uniform float energy = 2.2;

const float TAU = 6.28318530718;

void fragment() {
	vec2 p = (UV - 0.5) * size_m;
	float d = length(p);
	// 0 at the far side (-z), clockwise seen from above.
	float ang = fract(atan(p.x, -p.y) / TAU + 1.0);
	float aa = fwidth(d) * 1.5;
	float rim = 1.0 - smoothstep(0.22, 0.22 + aa, abs(d - radius_m));
	float dash = step(0.5, fract(ang * 48.0));
	vec3 col = vec3(0.0);
	float alpha = 0.0;
	// Neutral: a dashed white rim, always there, so the zone is readable before anyone takes it.
	float neutral_rim = rim * mix(dash, 1.0, held) * 0.7;
	col += vec3(0.85) * neutral_rim * (1.0 - held);
	alpha = max(alpha, neutral_rim * (1.0 - held));
	// The capture arc: a thick band just inside the rim, as far round as the capture has come.
	float band = 1.0 - smoothstep(0.6, 0.6 + aa, abs(d - (radius_m - 0.9)));
	float arc = band * step(ang, fill) * (1.0 - held);
	col = mix(col, fill_color, arc);
	alpha = max(alpha, arc * 0.95);
	// Held: the rim and the band solid in the holder's colour, the floor tinted, rings flowing in.
	if (held > 0.5) {
		float solid = max(rim, band);
		float inside = 1.0 - smoothstep(radius_m - aa, radius_m, d);
		float flow = fract(d / 4.0 + TIME * 0.9);
		float ripple = (1.0 - smoothstep(0.0, 0.12, abs(flow - 0.5))) * inside * 0.45;
		float breath = 0.10 + 0.05 * sin(TIME * 3.0);
		col = mix(held_color * breath, held_color, max(solid, ripple));
		alpha = max(solid, max(ripple, inside * breath));
	}
	if (contested > 0.5) {
		alpha *= 0.55 + 0.45 * step(0.5, fract(TIME * 4.0));
	}
	ALBEDO = col * energy;
	ALPHA = clamp(alpha, 0.0, 1.0);
}

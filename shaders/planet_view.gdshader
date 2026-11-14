shader_type canvas_item;

// Planet portrait lighting for the raster disc sprites. The disc, bands and
// craters stay the art; this adds a slow terminator, a limb/atmosphere glow and
// a faint specular so the portrait reads as a lit sphere instead of a sticker.
// Used by SpaceBackdrop (title, design, draft, debrief, report, crew, buff).

uniform float atmosphere = 0.55;
uniform vec4 rim_color : source_color = vec4(0.60, 0.82, 1.0, 1.0);
uniform float light_speed = 0.035;
uniform float base_light = 0.38;
uniform float specular = 0.12;
uniform float disc_radius = 0.90; // disc size inside the padded texture box
uniform vec2 planet_res = vec2(256.0, 256.0);

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	vec3 col = src.rgb;
	if (src.a > 0.004) {
		// Edge mask from the alpha channel rather than the UV radius: the
		// planet PNGs are padded by a few percent, so a pure UV normal would
		// spill outside the disc.
		vec2 e = vec2(1.5 / max(planet_res.x, 1.0), 1.5 / max(planet_res.y, 1.0));
		float a0 = texture(TEXTURE, UV + vec2(e.x, 0.0)).a;
		float a1 = texture(TEXTURE, UV - vec2(e.x, 0.0)).a;
		float a2 = texture(TEXTURE, UV + vec2(0.0, e.y)).a;
		float a3 = texture(TEXTURE, UV - vec2(0.0, e.y)).a;
		float limb = clamp(1.0 - min(min(a0, a1), min(a2, a3)), 0.0, 1.0);

		// Sphere normal over the disc.
		vec2 p = (UV - 0.5) * 2.0 / disc_radius;
		vec3 n = vec3(p, sqrt(max(1.0 - dot(p, p), 0.0)));

		// Slow-moving key light, upper-left, drifting through the mission.
		float ang = TIME * light_speed - 0.75;
		vec3 ld = normalize(vec3(cos(ang) * 0.75, -0.62, 0.55));
		float ndl = clamp(dot(n, ld), 0.0, 1.0);
		// Wrap the terminator so unlit terrain keeps a readable cool value.
		float lit = base_light + (1.0 - base_light) * pow(ndl, 0.85);
		col = src.rgb * mix(vec3(0.80, 0.86, 1.0), vec3(1.06, 1.02, 0.97), lit);

		// Specular sheen on the lit shoulder.
		vec3 h = normalize(ld + vec3(0.0, 0.0, 1.0));
		float spec = pow(clamp(dot(n, h), 0.0, 1.0), 26.0);
		col += vec3(1.0, 0.96, 0.86) * spec * specular;

		// Atmospheric limb: a thin glowing edge, strongest where the light hits.
		float rim = pow(limb, 0.75) * (0.25 + 0.75 * clamp(dot(n, ld) + 0.25, 0.0, 1.0));
		col += rim_color.rgb * rim * atmosphere;
	}
	COLOR = vec4(col, src.a);
}

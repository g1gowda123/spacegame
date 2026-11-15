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
// The node rotates the disc to spin the planet; this carries that same angle
// so the key light can be counter-rotated. Without it the terminator would
// sweep around with the surface, which reads as a turning lamp, not a planet.
uniform float spin = 0.0;
// Resting angle of the key light. -0.75 lights the disc from the right, which
// is what every console wants; the title menu turns it round so its planet is
// lit from off-frame left.
uniform float light_angle = -0.75;
// Title-screen life: slow drifting cloud bands over the baked surface. Zero on
// every other screen so the design/draft portraits stay still.
uniform float cloud_amount = 0.0;
uniform float cloud_speed = 0.10;
uniform float turn_amount = 0.0;

float pv_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float pv_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(pv_hash(i), pv_hash(i + vec2(1.0, 0.0)), u.x),
		mix(pv_hash(i + vec2(0.0, 1.0)), pv_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float pv_fbm(vec2 p) {
	float v = 0.0;
	v += pv_noise(p) * 0.55;
	v += pv_noise(p * 2.03 + vec2(11.0, 3.0)) * 0.30;
	v += pv_noise(p * 4.01 + vec2(2.0, 17.0)) * 0.15;
	return v;
}

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
		float ang = TIME * light_speed + light_angle - spin;
		vec3 ld = normalize(vec3(cos(ang) * 0.75, -0.62, 0.55));
		float ndl = clamp(dot(n, ld), 0.0, 1.0);
		// Wrap the terminator so unlit terrain keeps a readable cool value.
		float lit = base_light + (1.0 - base_light) * pow(ndl, 0.85);
		col = src.rgb * mix(vec3(0.80, 0.86, 1.0), vec3(1.06, 1.02, 0.97), lit);

		// Cloud bands: a slow horizontal weather layer, compressed toward the
		// limb by the same sphere normal. Kept very low contrast so the baked
		// craters and the terminator still lead.
		if (cloud_amount > 0.001) {
			vec2 cp = p * vec2(2.1, 2.7);
			cp.x += TIME * cloud_speed;
			float n = pv_fbm(vec2(cp.x, cp.y + sin(cp.x * 0.45) * 0.35));
			n = smoothstep(0.48, 0.80, n);
			float band = 0.55 + 0.45 * sin(p.y * 8.0 + TIME * 0.025);
			float inside = smoothstep(1.0, 0.80, length(p));
			float cl = n * band * inside;
			col = mix(col, vec3(0.84, 0.89, 0.96), cl * 0.30 * cloud_amount);
		}

		// Axial turn: rotate the planet normal around Y and reproject, so the
		// baked surface markings slide across the disc while the terminator
		// stays put. Oscillates instead of wrapping, because the source PNG
		// only has the near hemisphere.
		if (turn_amount > 0.001) {
			float turn = sin(TIME * 0.11) * 0.24 * turn_amount;
			vec3 n2 = vec3(
				n.x * cos(turn) + n.z * sin(turn),
				n.y,
				-n.x * sin(turn) + n.z * cos(turn)
			);
			float front = smoothstep(0.04, 0.32, n2.z);
			float core = smoothstep(1.0, 0.86, length(p));
			float m = front * core;
			if (m > 0.01) {
				vec2 uv2 = vec2(0.5) + n2.xy * disc_radius * 0.5;
				vec3 alt = texture(TEXTURE, uv2).rgb;
				alt *= mix(vec3(0.80, 0.86, 1.0), vec3(1.06, 1.02, 0.97), lit);
				col = mix(col, alt, m * 0.88);
			}
		}

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

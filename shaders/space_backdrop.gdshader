shader_type canvas_item;
render_mode unshaded;

// Full-screen deep-space plate. No textures: the same shader serves the survey
// board and the full-game title/draft/debrief screens, and `variation` rerolls
// the nebula, star tint and small worlds every sector.

uniform float variation = 0.37;
uniform float show_planet = 1.0;
uniform vec2 resolution = vec2(640.0, 360.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p = p * 2.03 + 17.1;
		a *= 0.5;
	}
	return v;
}

vec3 hue_rotate(vec3 c, float a) {
	vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

void fragment() {
	vec2 uv = UV;
	vec2 px = floor(uv * resolution);
	float aspect = resolution.x / max(resolution.y, 1.0);
	vec2 p = vec2(uv.x * aspect, uv.y);
	float v = fract(variation);

	// Deep base, with a faint diagonal galactic band. Keep it dark: the board
	// and the HUD must stay the brightest things on screen.
	float band = exp(-pow(abs(p.y - 0.52 + (p.x - aspect * 0.5) * 0.12), 1.7) * 5.0);
	vec3 base_a = vec3(0.018, 0.026, 0.052);
	vec3 base_b = vec3(0.035, 0.030, 0.070);
	vec3 col = mix(base_a, base_b, band * 0.9);

	// Nebula: two decorrelated low-frequency fields, deliberately subtle and
	// hue-shifted by the round variation. The 0.55 multiplier prevents the
	// big pastel clouds that made the old raster plate read as a gas giant.
	float n1 = fbm(p * 2.2 + vec2(v * 13.0, -v * 7.0));
	float n2 = fbm(p * 4.4 - vec2(v * 9.0, v * 5.0));
	vec3 neb = hue_rotate(vec3(0.10, 0.22, 0.30), v * 6.28318);
	float neb_a = smoothstep(0.52, 0.78, n1) * (0.36 + 0.22 * band);
	col += neb * neb_a * 0.55;
	col += hue_rotate(vec3(0.20, 0.10, 0.28), v * 4.0) * smoothstep(0.60, 0.86, n2) * 0.18;

	// Stars: three fixed grids, one 1-pixel cell per star at 640x360. The
	// smooth dot is only 0.7 px, so the nearest-filtered upscale keeps a
	// hard pixel rather than a cross-shaped bloom.
	for (int layer = 0; layer < 3; layer++) {
		float scale = 95.0 + float(layer) * 83.0;
		float field = hash21(px / scale + float(layer) * 31.7 + v * 19.0);
		if (field > 0.986) {
			float sx = hash21(floor(px / scale) + 3.1);
			float sy = hash21(floor(px / scale) + 9.7);
			vec2 cell = fract(px / scale) - vec2(sx, sy) * 0.6 - 0.2;
			float d = length(cell);
			float star = smoothstep(0.16, 0.0, d);
			float warm = hash21(floor(px / scale) + 17.0);
			vec3 sc = mix(vec3(0.72, 0.84, 1.0), vec3(1.0, 0.86, 0.72), warm * v);
			col += sc * star * (0.45 + 0.40 * hash21(floor(px / scale) + 21.0));
		}
	}

	// Optional small worlds, never a single giant focal planet. At most two
	// per round; some rounds get none. This is the Balatro-style reroll.
	float worlds = show_planet * step(0.40, fract(v * 7.0 + 0.17));
	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		float present = step(0.5, fract(v * (11.0 + fi * 5.0) + 0.3 + fi * 0.7));
		if (worlds * present < 0.5) {
			continue;
		}
		vec2 c = vec2(
			0.18 + 0.64 * fract(v * (5.0 + fi * 2.0) + 0.21),
			0.20 + 0.52 * fract(v * (7.0 + fi * 3.0) + 0.59)
		);
		float r = 0.030 + 0.040 * fract(v * 13.0 + fi * 0.31);
		vec2 d = (uv - c) * vec2(aspect, 1.0);
		float disc = smoothstep(r, r - 0.003, length(d));
		if (disc > 0.0) {
			vec3 wc = hue_rotate(vec3(0.34, 0.42, 0.52), v * 3.0 + fi);
			float shade = 0.55 + 0.45 * clamp(0.5 + dot(normalize(d + vec2(0.0001)), normalize(vec2(-0.6, 0.7))), 0.0, 1.0);
			col = mix(col, wc * shade, disc * 0.82);
			float rim = smoothstep(r, r * 0.72, length(d)) - smoothstep(r * 0.72, r * 0.55, length(d));
			col += vec3(0.38, 0.58, 0.72) * rim * 0.22 * disc;
		}
	}

	// Sparse 1-px dust, then a restrained vignette to frame the board.
	float dust = step(0.9993, hash21(px + v * 41.0));
	col += vec3(0.20, 0.24, 0.30) * dust;
	vec2 vd = uv - 0.5;
	col *= 1.0 - dot(vd, vd) * 0.55;

	COLOR = vec4(col, 1.0);
}

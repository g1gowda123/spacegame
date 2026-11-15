shader_type canvas_item;
render_mode unshaded;

// Animated star plate. Sits on the raster space background used by every
// non-sector screen, so the whole game breathes without touching layout.
// The raster stays the art: this shader only drifts it a few pixels, twinkles
// the existing bright pixels and adds a very slow nebula tint pulse.

uniform float drift = 1.0;
// Slow parallax pan. The plate is inset by `drift_amount` so the edges never
// clamp, and the whole field moves on a sine/cosine pair so it never loops with
// a visible seam. Sampling uses linear filtering on the node: a 1 px star must
// be allowed to sit between texels or the drift visibly steps one pixel at a
// time instead of gliding.
uniform float drift_amount = 0.030;
uniform float drift_speed = 0.070;
uniform float twinkle = 1.0;
uniform vec2 resolution = vec2(640.0, 360.0);
uniform vec4 tint_a : source_color = vec4(0.62, 0.86, 1.0, 1.0);
uniform vec4 tint_b : source_color = vec4(1.0, 0.84, 0.66, 1.0);
// The title menu asks for a brighter, warmer plate than the working consoles,
// so both the overall lift and the nebula wash are per-screen uniforms. The
// defaults keep every other screen exactly as it was.
uniform float bright = 1.0;
uniform float nebula = 0.012;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	// Inset the plate by the full drift amplitude, then pan inside that inset.
	// This crops ~4 px at 640 instead of stretching the edge texel when the
	// field moves past the plate boundary.
	float m = drift_amount * drift;
	vec2 off = vec2(sin(TIME * drift_speed * 0.83),
		cos(TIME * drift_speed)) * m;
	vec2 uv = UV * (1.0 - 2.0 * m) + m + off;
	vec4 src = texture(TEXTURE, uv);
	vec3 col = src.rgb * bright;

	// Bright pixels are stars: give each a stable phase and a slow breath.
	// The cell is taken from the *drifted* uv, so a star keeps its twinkle as
	// the field moves instead of flashing at a fixed screen pixel.
	vec2 cell = floor(uv * resolution);
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float is_star = smoothstep(0.22, 0.70, luma);
	float phase = hash21(cell) * 6.28318;
	float breath = 0.72 + 0.28 * sin(TIME * (0.9 + hash21(cell + 3.7) * 1.6) + phase);
	col += src.rgb * is_star * breath * 0.55 * twinkle * bright;

	// A few 1px sparkles that fade in and out on their own phase. A stepped
	// `floor(TIME)` gate popped whole pixels on and off; the sine envelope keeps
	// the field alive without a visible tick.
	float spark_seed = hash21(cell + 71.3);
	float spark = pow(max(sin(TIME * (0.35 + spark_seed * 0.75)
		+ spark_seed * 6.28318), 0.0), 22.0);
	vec3 spark_col = mix(tint_a.rgb, tint_b.rgb, hash21(cell + 9.1));
	col += spark_col * spark * 0.75 * twinkle;

	// Horizontal nebula wash that shifts hue over a minute. `nebula` is the
	// per-screen strength: near-invisible on the consoles, a soft coloured
	// sky behind the title menu.
	float band = exp(-pow(abs(UV.y - 0.46 - sin(UV.x * 3.1 + TIME * 0.02) * 0.05), 2.0) * 8.0);
	col += mix(tint_a.rgb, tint_b.rgb, 0.5 + 0.5 * sin(TIME * 0.03)) * band * nebula;

	COLOR = vec4(col, src.a);
}

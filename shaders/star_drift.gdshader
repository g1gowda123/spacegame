shader_type canvas_item;
render_mode unshaded;

// Animated star plate. Sits on the raster space background used by every
// non-sector screen, so the whole game breathes without touching layout.
// The raster stays the art: this shader only drifts it a few pixels, twinkles
// the existing bright pixels and adds a very slow nebula tint pulse.

uniform float drift = 1.0;
uniform float twinkle = 1.0;
uniform vec2 resolution = vec2(640.0, 360.0);
uniform vec4 tint_a : source_color = vec4(0.62, 0.86, 1.0, 1.0);
uniform vec4 tint_b : source_color = vec4(1.0, 0.84, 0.66, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	// Slow parallax drift, sub-pixel at 640x360.
	vec2 uv = UV + vec2(sin(TIME * 0.011), cos(TIME * 0.014)) * 0.0016 * drift;
	vec4 src = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	vec3 col = src.rgb;

	// Bright pixels are stars: give each a stable phase and a slow breath.
	vec2 cell = floor(UV * resolution);
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float is_star = smoothstep(0.22, 0.70, luma);
	float phase = hash21(cell) * 6.28318;
	float breath = 0.72 + 0.28 * sin(TIME * (0.9 + hash21(cell + 3.7) * 1.6) + phase);
	col += src.rgb * is_star * breath * 0.55 * twinkle;

	// A few 1px sparkles that only appear for a moment, so the field is never
	// perfectly static even on a sparse plate.
	float spark = step(0.9985, hash21(cell + floor(TIME * 0.7) * 17.0));
	vec3 spark_col = mix(tint_a.rgb, tint_b.rgb, hash21(cell + 9.1));
	col += spark_col * spark * 0.75 * twinkle;

	// Very faint horizontal nebula wash that shifts hue over a minute.
	float band = exp(-pow(abs(UV.y - 0.46 - sin(UV.x * 3.1 + TIME * 0.02) * 0.05), 2.0) * 8.0);
	col += mix(tint_a.rgb, tint_b.rgb, 0.5 + 0.5 * sin(TIME * 0.03)) * band * 0.012;

	COLOR = vec4(col, src.a);
}

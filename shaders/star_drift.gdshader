shader_type canvas_item;
render_mode unshaded;

// Animated star plate. Sits on the raster space background used by every
// non-sector screen, so the whole game breathes without touching layout.
// The raster stays the art: this shader only drifts it a few pixels, twinkles
// the existing bright pixels and adds a very slow nebula tint pulse.

uniform float drift = 1.0;
uniform float twinkle = 1.0;
uniform vec2 resolution = vec2(640.0, 360.0); // source plate size, not screen size
uniform vec4 tint_a : source_color = vec4(0.62, 0.86, 1.0, 1.0);
uniform vec4 tint_b : source_color = vec4(1.0, 0.84, 0.66, 1.0);
// The title menu asks for a brighter, warmer plate than the working consoles,
// so both the overall lift and the nebula wash are per-screen uniforms. The
// defaults keep every other screen exactly as it was.
uniform float bright = 1.0;
uniform float nebula = 0.012;

float hash21(vec2 p) {
	// The old sin/fract pair repeated visibly every ~50 cells at screen
	// resolution, which turned twinkle/spark cells into vertical star columns.
	// This is the Dave Hoskins 2D hash: weak correlation, no short period.
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	// Slow parallax drift, sub-pixel at 640x360.
	vec2 uv = UV + vec2(sin(TIME * 0.011), cos(TIME * 0.014)) * 0.0016 * drift;
	vec4 src = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	vec3 col = src.rgb * bright;

	// Bright pixels are stars: a smooth two-axis shimmer, not a per-cell hash.
	// A per-cell hash at screen resolution exposed a 20 px periodic artifact
	// that read as vertical columns of stars; a continuous sine field cannot
	// alias into columns at any window size.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float is_star = smoothstep(0.22, 0.70, luma);
	float breath = 0.78 + 0.22 * sin(TIME * 0.80 + UV.x * 9.0 + UV.y * 13.0);
	breath *= 0.90 + 0.10 * sin(TIME * 0.37 - UV.x * 5.0 + UV.y * 3.0);
	col += src.rgb * is_star * breath * 0.46 * twinkle * bright;

	// Horizontal nebula wash that shifts hue over a minute. `nebula` is the
	// per-screen strength: near-invisible on the consoles, a soft coloured
	// sky behind the title menu.
	float band = exp(-pow(abs(UV.y - 0.46 - sin(UV.x * 3.1 + TIME * 0.02) * 0.05), 2.0) * 8.0);
	col += mix(tint_a.rgb, tint_b.rgb, 0.5 + 0.5 * sin(TIME * 0.03)) * band * nebula;

	COLOR = vec4(col, src.a);
}

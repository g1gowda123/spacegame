shader_type canvas_item;
render_mode unshaded;

// Restrained print/film pass for the flight-binder look. Not a neon CRT:
// a little warm grain, a soft edge vignette and a hint of halation on the
// brightest paper. Reads the screen once; WebGL2/GL Compatibility safe.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float strength = 1.0;
uniform float grain_amount = 0.020;
uniform float vignette_amount = 0.05;
uniform float halation_amount = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_texture, uv).rgb;

	// A tiny warm halation on highlights only. Keeps type crisp while paper
	// edges and live values feel printed rather than flat-shaded.
	vec3 glow = texture(screen_texture, uv + vec2(px.x * 1.5, 0.0)).rgb;
	glow += texture(screen_texture, uv - vec2(px.x * 1.5, 0.0)).rgb;
	glow += texture(screen_texture, uv + vec2(0.0, px.y * 1.5)).rgb;
	glow += texture(screen_texture, uv - vec2(0.0, px.y * 1.5)).rgb;
	glow = max(glow * 0.25 - vec3(0.72), vec3(0.0));
	c += glow * halation_amount * strength;

	// Warm the shadows a touch; the page should feel aged, not blue.
	c = mix(c, c * vec3(1.01, 1.0, 0.98), 0.18 * strength);

	// Static paper grain: stable, so small 6-7 px labels do not crawl.
	vec2 gp = floor(uv / max(px, vec2(0.0001)) * 0.5);
	float g = hash(gp) - 0.5;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float dark = 1.0 - smoothstep(0.18, 0.55, lum);
	c += g * grain_amount * dark * strength;

	// Soft lens edge; strength is deliberately low so the map stays readable.
	float v = smoothstep(0.34, 0.92, length(uv - vec2(0.5)) * 1.28);
	c *= 1.0 - v * vignette_amount * strength;

	COLOR = vec4(c, 1.0);
}

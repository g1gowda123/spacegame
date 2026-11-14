shader_type canvas_item;
render_mode unshaded;

// Full-screen state overlay for the surface sector. Transparent in the middle
// so the board stays readable; only the edge carries the alert.
//
//   low_hull  0..1  red heartbeat edge when integrity is nearly gone
//   heat      0..1  amber edge shimmer as thermal load approaches overload
//   alert     0..1  steady dim red when the sector has ended
//
// The existing `_impact_flash` ColorRect sits above this and owns the single
// hit flash; this shader is the persistent state, not the event.

uniform float low_hull = 0.0;
uniform float heat = 0.0;
uniform float alert = 0.0;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.32, 0.22, 1.0);
uniform vec2 screen_size = vec2(640.0, 360.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.x *= screen_size.x / max(screen_size.y, 1.0);
	float r = length(p);
	float edge = smoothstep(0.74, 1.26, r);

	float pulse = 0.55 + 0.45 * sin(TIME * 3.6);
	float low = low_hull * edge * pulse * 0.60;
	float shimmer = 0.5 + 0.5 * sin(TIME * 2.3 + UV.y * 9.0);
	float hot = heat * edge * shimmer * 0.34;
	float dim = alert * edge * 0.22;

	vec3 col = mix(vec3(0.72, 0.08, 0.10), vec3(1.0, 0.46, 0.10), heat);
	// Disaster edge flash: a hot rim that rolls around the screen on a strike.
	float f = flash * edge;
	col = col + flash_color.rgb * f * 0.55;
	COLOR = vec4(col, clamp(low + hot + dim + f * 0.62, 0.0, 0.86));
}

shader_type canvas_item;

// A fog cell reads as dimmed, desaturated terrain, not a black rectangle.
// Polygon alpha is the per-band fog strength set by _draw_fog().
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 fog_color : source_color = vec4(0.055, 0.075, 0.105, 1.0);
uniform float desat : hint_range(0.0, 1.0) = 0.35;

void fragment() {
    vec3 src = texture(screen_texture, SCREEN_UV).rgb;
    float l = dot(src, vec3(0.299, 0.587, 0.114));
    vec3 muted = mix(src, vec3(l), desat);
    COLOR = vec4(mix(muted, fog_color.rgb, COLOR.a), 1.0);
}

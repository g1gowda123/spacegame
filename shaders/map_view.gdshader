shader_type canvas_item;
render_mode unshaded;

// 0 = Into the Breach-style 3/4 tilt, 1 = classic isometric diamond, 2 = flat top-down.
uniform int view_mode = 0;
uniform float map_scale = 0.92;
uniform float tilt = 0.75;
uniform vec2 screen_size = vec2(640.0, 360.0);
uniform vec2 map_size = vec2(3072.0, 3072.0);
uniform vec2 map_tiles = vec2(48.0, 48.0);
uniform vec2 camera_center = vec2(1536.0, 1536.0);
uniform int show_grid = 0;
uniform float saturation = 0.84;
uniform float brightness = 0.93;
uniform vec3 tint = vec3(0.94, 1.0, 0.97);
uniform vec4 biome_tint : source_color = vec4(1.0);
uniform float biome_tint_strength = 0.0;
uniform vec2 camera_offset = vec2(0.0);
uniform int circle_view = 1;
uniform float circle_radius = 0.40;
uniform float circle_soft = 0.055;
uniform float circle_outer = 0.56;
uniform float circle_outer_soft = 0.06;

void fragment() {
    // Use UV rather than FRAGCOORD: UV is stable across windowed/fullscreen
    // scaling and HiDPI, while FRAGCOORD is in physical pixels and can disagree
    // with the canvas-sized TextureRect.
    vec2 disc = (UV - 0.5) * vec2(screen_size.x / screen_size.y, 1.0);
    float disc_dist = length(disc);
    if (circle_view == 1 && disc_dist > circle_outer + circle_outer_soft) {
        discard;
    }
    vec2 px = (UV - 0.5) * screen_size + camera_offset;
    vec2 src_px;

    if (view_mode == 0) {
        // Ground plane recedes: horizontal scale stays, vertical is foreshortened.
        src_px = vec2(px.x / map_scale, px.y / (map_scale * tilt));
    } else if (view_mode == 1) {
        // Rotate 45 degrees, then squash vertically for a diamond map.
        float u = px.x / map_scale;
        float v = px.y / (map_scale * tilt);
        src_px = vec2(u + v, v - u) * 0.70710678;
    } else {
        src_px = px / map_scale;
    }

    vec2 uv = (camera_center + src_px) / map_size;
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        // Thick slab edge just outside the board. This reads as a physical
        // base under the terrain instead of a texture cut off at the screen.
        // src_px is screen-space; compare in UV/world units or the slab fills
        // the whole screen outside the board. Distance beyond the map edge, in
        // texture pixels.
        vec2 over = max(vec2(0.0), max(-uv, uv - 1.0)) * map_size;
        float d = max(over.x, over.y);
        if (d < 26.0) {
            float k = 1.0 - d / 26.0;
            vec3 side = mix(vec3(0.035, 0.042, 0.055), vec3(0.19, 0.21, 0.25), k);
            COLOR = vec4(side, 1.0);
        } else {
            // Soft drop shadow just outside the slab.
            vec2 suv = uv + vec2(0.0045, 0.0075);
            if (suv.x >= 0.0 && suv.x <= 1.0 && suv.y >= 0.0 && suv.y <= 1.0) {
                float a = texture(TEXTURE, suv).a;
                COLOR = vec4(0.0, 0.0, 0.0, a * 0.30);
            } else {
                COLOR = vec4(0.0);
            }
        }
    } else {
        COLOR = texture(TEXTURE, uv);

        // Biome tint: sell exotic mineral/ice chemistry without replacing the
        // shared terrain atlas. Strength comes from the biome definition.
        COLOR.rgb = mix(COLOR.rgb, COLOR.rgb * biome_tint.rgb, biome_tint_strength);

        // Directional key light from the upper-left. A flat board reads as a
        // tile editor; a single strong light direction makes the terrain feel
        // like a physical surface under a sun.
        float sun = clamp(0.5 + (UV.x - UV.y) * 0.62, 0.0, 1.0);
        COLOR.rgb *= mix(0.76, 1.12, sun);

        // Slow cloud shadows drifting across whole regions. This is the main
        // scale cue on the ground: the eye reads weather, not a texture repeat.
        vec2 cloud_uv = uv * map_size * 0.0017 + vec2(TIME * 0.0030, TIME * 0.0012);
        float cloud = sin(cloud_uv.x * 2.7 + sin(cloud_uv.y * 1.9) * 1.4);
        cloud += sin(cloud_uv.y * 3.4 + sin(cloud_uv.x * 2.2) * 1.1) * 0.55;
        cloud = smoothstep(-0.55, 0.85, cloud);
        COLOR.rgb *= mix(0.74, 1.02, cloud);

        // Mute the raw diffusion palette toward Into the Breach's dusty,
        // slightly cool board colors.
        float luma = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
        COLOR.rgb = mix(vec3(luma), COLOR.rgb, saturation) * tint * brightness;

        // Grade shadows toward cold teal and highlights toward pale amber.
        // This is deliberately stronger than a neutral curve: the survey
        // board should look lit, not color-corrected.
        vec3 shadow_grade = vec3(0.70, 0.88, 0.95);
        vec3 high_grade = vec3(1.07, 1.02, 0.92);
        COLOR.rgb *= mix(shadow_grade, high_grade, smoothstep(0.18, 0.82, luma));
        COLOR.rgb = (COLOR.rgb - 0.5) * 1.10 + 0.5;

        // Cold water catches a moving specular glint; land stays matte.
        float water_mask = smoothstep(0.16, 0.52, COLOR.b - max(COLOR.r, COLOR.g));
        float ripple = sin(uv.x * map_size.x * 0.55 + TIME * 1.7 + sin(uv.y * map_size.y * 0.31)) * 0.5 + 0.5;
        COLOR.rgb += vec3(0.02, 0.10, 0.13) * water_mask * (0.35 + 0.65 * ripple);

        // Low-frequency world-space variation breaks the visible 64px tile
        // repeat without touching the tile art. Keep it subtle: ±5% luma.
        vec2 macro_uv = uv * map_size * 0.0042;
        float macro = sin(macro_uv.x + sin(macro_uv.y * 1.37) * 1.8) * 0.5 + 0.5;
        float macro2 = sin(macro_uv.y * 0.71 + macro_uv.x * 0.23) * 0.5 + 0.5;
        COLOR.rgb *= mix(0.95, 1.05, macro * 0.55 + macro2 * 0.45);

        // 4px variant grain: enough to stop large fields reading as one flat
        // swatch, coarse enough that it never becomes per-pixel noise.
        vec2 grain_cell = floor(uv * map_size / 4.0);
        float grain = fract(sin(dot(grain_cell, vec2(12.9898, 78.233))) * 43758.5453);
        COLOR.rgb *= mix(0.975, 1.025, grain);

        // A restrained top-left ambient keeps the board from looking evenly
        // lit like a tile editor; the vignette is separate and stays centered.
        float ambient = clamp(0.5 + (UV.x - UV.y) * 0.12, 0.0, 1.0);
        COLOR.rgb *= mix(0.97, 1.03, ambient);

        // Board rim: a thin dark bevel at the edge of the visible slab.
        vec2 edge_px = min(uv * map_size, (1.0 - uv) * map_size);
        float edge = min(edge_px.x, edge_px.y);
        if (edge < 1.5) {
            COLOR.rgb = vec3(0.012, 0.016, 0.022);
        } else if (edge < 5.0) {
            COLOR.rgb *= mix(0.55, 1.0, (edge - 1.5) / 3.5);
        }

        // Gentle vignette keeps the eye on the lander and objectives.
        float vig = smoothstep(0.78, 0.24, length(UV - 0.5));
        COLOR.rgb *= mix(0.86, 1.0, vig);

        if (show_grid == 1) {
            vec2 g = fract(uv * map_tiles);
            float line = (g.x < 0.022 || g.y < 0.022) ? 0.14 : 0.0;
            COLOR.rgb = mix(COLOR.rgb, vec3(0.02, 0.03, 0.04), line);
        }
    }

    if (circle_view == 1) {
        // Circular survey horizon with a fog skirt. The inner disc is fully
        // lit; terrain beyond it stays visible but dims toward space so the
        // player can see that survey space continues past the focus circle.
        float focus = 1.0 - smoothstep(
            circle_radius - circle_soft, circle_radius + circle_soft, disc_dist
        );
        float outside = 1.0 - smoothstep(
            circle_radius + circle_soft, circle_outer, disc_dist
        );
        float rim = smoothstep(circle_radius - 0.030, circle_radius - 0.004, disc_dist);
        vec3 fog = vec3(0.025, 0.034, 0.047);
        COLOR.rgb = mix(COLOR.rgb, fog, (1.0 - focus) * 0.52);
        
        COLOR.a *= mix(0.12, 1.0, focus) * outside;
    }
}

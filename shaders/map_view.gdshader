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
uniform float saturation = 0.88;
uniform float brightness = 1.08;
uniform vec3 tint = vec3(0.97, 1.0, 0.99);
uniform vec4 biome_tint : source_color = vec4(1.0);
uniform float biome_tint_strength = 0.0;
uniform float exposure = 1.0;
uniform float lift = 1.0;
uniform vec2 camera_offset = vec2(0.0);
uniform int circle_view = 1;
uniform float circle_radius = 0.40;
uniform float circle_soft = 0.055;
uniform float circle_outer = 0.56;
uniform float circle_outer_soft = 0.06;
uniform sampler2D terrain_mask : filter_linear, repeat_disable;
uniform vec2 terrain_mask_size = vec2(80.0, 64.0);
uniform vec2 terrain_mask_origin = vec2(0.0);
uniform float terrain_mask_span = 1280.0;
uniform int edge_mode = 1;
uniform sampler2D height_mask : filter_linear, repeat_disable;
uniform vec2 height_mask_size = vec2(80.0, 64.0);
uniform bool relief = false;

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
        vec4 source = texture(TEXTURE, uv);
        // Lava/water micro-refraction: nudge the lookup on hot or wet pixels
        // before grading. Reads as heat shimmer / surface motion, costs one
        // extra texture fetch, and needs no screen-copy pass.
        float warm_guess = smoothstep(0.10, 0.42, source.r - max(source.g, source.b));
        float wet_guess = smoothstep(0.14, 0.46, source.b - max(source.r, source.g));
        vec2 wobble = vec2(
            sin(uv.y * map_size.y * 0.55 + TIME * 3.1),
            cos(uv.x * map_size.x * 0.48 + TIME * 2.6)
        );
        uv += wobble * 0.00085 * (warm_guess * 1.0 + wet_guess * 0.55);
        COLOR = texture(TEXTURE, uv);

        // Sub-cell material edge: sample the 4x material field on both sides of
        // the fragment and dither a small amount of the neighbour's average
        // colour into the seam. The transition tiles still own the silhouette;
        // this only removes the one-pixel cut between two correct tiles.
        if (edge_mode > 0) {
            vec2 muv = (uv * map_size - terrain_mask_origin) / max(terrain_mask_span, 1.0);
            vec3 m0 = texture(terrain_mask, muv).rgb;
            vec3 mx = texture(terrain_mask, muv + vec2(1.5 / terrain_mask_size.x, 0.0)).rgb;
            vec3 my = texture(terrain_mask, muv + vec2(0.0, 1.5 / terrain_mask_size.y)).rgb;
            float mask_edge = max(distance(m0, mx), distance(m0, my));
            float edge_amt = smoothstep(0.008, 0.055, mask_edge);
            if (edge_mode == 2) {
                // Optional noise-free variant for A/B; the accepted gate path
                // keeps the dithered threshold below.
                COLOR.rgb = mix(COLOR.rgb, (mx + my) * 0.5, 0.42 * edge_amt);
            } else {
                // Accepted W1: noise-dithered threshold across the seam.
                float dither = fract(sin(dot(floor(UV * screen_size * 0.5), vec2(12.9898, 78.233))) * 43758.5453);
                if (edge_amt > dither) {
                    COLOR.rgb = mix(COLOR.rgb, (mx + my) * 0.5, 0.34 * edge_amt);
                }
            }
        }

        if (relief) {
            // Elevation field -> slope normal. The light is fixed top-left so
            // terrain relief agrees with the structure-shadow direction.
            vec2 huv = (uv * map_size - terrain_mask_origin) / max(terrain_mask_span, 1.0);
            float hL = texture(height_mask, huv - vec2(1.0 / height_mask_size.x, 0.0)).r;
            float hR = texture(height_mask, huv + vec2(1.0 / height_mask_size.x, 0.0)).r;
            float hU = texture(height_mask, huv - vec2(0.0, 1.0 / height_mask_size.y)).r;
            float hD = texture(height_mask, huv + vec2(0.0, 1.0 / height_mask_size.y)).r;
            vec2 grad = vec2(hR - hL, hD - hU);
            vec3 n = normalize(vec3(-grad.x * 9.0, -grad.y * 9.0, 1.0));
            vec3 sun_dir = normalize(vec3(-0.55, -0.35, 0.76));
            float sun = clamp(dot(n, sun_dir), 0.0, 1.0);
            float h = texture(height_mask, huv).r;
            // Basin floor sits a little darker; crests catch the light.
            float basin = mix(0.94, 1.0, smoothstep(0.10, 0.55, h));
            COLOR.rgb *= mix(0.86, 1.10, sun) * basin;
        }

        // Biome tint, hue-only. Multiplying by the raw tint colour darkened the
        // board (barren measured 40 % of its source luma); normalising the tint
        // to unit luma shifts hue without stealing brightness.
        vec3 tint_unit = biome_tint.rgb / max(dot(biome_tint.rgb, vec3(0.299, 0.587, 0.114)), 0.001);
        COLOR.rgb = mix(COLOR.rgb, COLOR.rgb * tint_unit, biome_tint_strength);

        // Per-biome exposure: dark ash/sulfur tiles and bright ice tiles share
        // one atlas and one grade chain, so each board is normalised to the
        // same readable mid-tone instead of inheriting its tile brightness.
        COLOR.rgb *= exposure;
        // `lift` is a gamma, not another multiply: it opens the dark ash of a
        // volcanic board without pushing already-bright lava to white.
        COLOR.rgb = pow(max(COLOR.rgb, vec3(0.0)), vec3(lift));

        // Directional key light from the upper-left. A flat board reads as a
        // tile editor; a single strong light direction makes the terrain feel
        // like a physical surface under a sun. Keep the range narrow so the
        // shadow side still carries readable ground colour (W5 luminance floor).
        float sun = clamp(0.5 + (UV.x - UV.y) * 0.62, 0.0, 1.0);
        COLOR.rgb *= mix(0.86, 1.10, sun);

        // Slow cloud shadows drifting across whole regions. This is the main
        // scale cue on the ground: the eye reads weather, not a texture repeat.
        vec2 cloud_uv = uv * map_size * 0.0017 + vec2(TIME * 0.0030, TIME * 0.0012);
        float cloud = sin(cloud_uv.x * 2.7 + sin(cloud_uv.y * 1.9) * 1.4);
        cloud += sin(cloud_uv.y * 3.4 + sin(cloud_uv.x * 2.2) * 1.1) * 0.55;
        cloud = smoothstep(-0.55, 0.85, cloud);
        COLOR.rgb *= mix(0.91, 1.03, cloud);

        // Mute the raw diffusion palette toward Into the Breach's dusty,
        // slightly cool board colors.
        float luma = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
        COLOR.rgb = mix(vec3(luma), COLOR.rgb, saturation) * tint * brightness;

        // Grade shadows toward cold teal and highlights toward pale amber.
        // The dark band stops at 0.84, not 0.70: at 0.70 a barren board lost a
        // third of its luma before it ever reached the screen.
        vec3 shadow_grade = vec3(0.84, 0.92, 0.97);
        vec3 high_grade = vec3(1.05, 1.02, 0.96);
        COLOR.rgb *= mix(shadow_grade, high_grade, smoothstep(0.18, 0.82, luma));
        COLOR.rgb = (COLOR.rgb - 0.5) * 1.06 + 0.5;
        // Soft highlight rolloff keeps the brightest snow/light tiles from
        // clipping to flat white once the midtones are lifted.
        COLOR.rgb = COLOR.rgb / (1.0 + max(COLOR.rgb - 0.86, 0.0) * 0.55);
        COLOR.rgb = clamp(COLOR.rgb, 0.0, 1.0);

        // Cold water catches a moving specular glint; land stays matte.
        float water_mask = smoothstep(0.16, 0.52, COLOR.b - max(COLOR.r, COLOR.g));
        float ripple = sin(uv.x * map_size.x * 0.55 + TIME * 1.7 + sin(uv.y * map_size.y * 0.31)) * 0.5 + 0.5;
        COLOR.rgb += vec3(0.02, 0.10, 0.13) * water_mask * (0.35 + 0.65 * ripple);
        // Second, slower swell so water reads as a body with depth instead of
        // a texture that is merely brighter than the ground.
        float swell = sin(uv.y * map_size.y * 0.10 - TIME * 0.75 + uv.x * map_size.x * 0.045) * 0.5 + 0.5;
        float caustic = pow(0.5 + 0.5 * sin(
            uv.x * map_size.x * 0.85 + TIME * 1.15
            + sin(uv.y * map_size.y * 0.55 - TIME * 0.6) * 2.2
        ), 5.0);
        COLOR.rgb += vec3(0.015, 0.085, 0.105) * water_mask * (swell * 0.45 + caustic * 0.55);

        // Lava / hot mineral seams: a slow breathing emissive on warm pixels.
        // This is what makes a volcanic board read as hot rather than painted.
        float warm_mask = smoothstep(0.10, 0.42, COLOR.r - max(COLOR.g, COLOR.b));
        float lava_pulse = 0.55 + 0.45 * sin(TIME * 1.9 + uv.x * map_size.x * 0.06 + sin(uv.y * map_size.y * 0.04) * 1.7);
        COLOR.rgb += vec3(0.50, 0.16, 0.02) * warm_mask * lava_pulse * 0.42;

        // Ice / crystal: sparse pixel twinkles on bright cool ground.
        float ice_mask = smoothstep(0.08, 0.40, COLOR.b - COLOR.r) * smoothstep(0.42, 0.80, luma);
        vec2 twinkle_cell = floor(uv * map_size / 3.0) + vec2(floor(TIME * 1.4), floor(TIME * 0.9));
        float twinkle = step(0.9965, fract(sin(dot(twinkle_cell, vec2(12.9898, 78.233))) * 43758.5453));
        COLOR.rgb += vec3(0.55, 0.78, 0.95) * ice_mask * twinkle * 0.55;

        // Low-frequency world-space variation breaks the visible 64px tile
        // repeat without touching the tile art. Keep it subtle: ±5% luma.
        vec2 macro_uv = uv * map_size * 0.0042;
        float macro = sin(macro_uv.x + sin(macro_uv.y * 1.37) * 1.8) * 0.5 + 0.5;
        float macro2 = sin(macro_uv.y * 0.71 + macro_uv.x * 0.23) * 0.5 + 0.5;
        COLOR.rgb *= mix(0.97, 1.03, macro * 0.55 + macro2 * 0.45);

        // 4px variant grain: enough to stop large fields reading as one flat
        // swatch, coarse enough that it never becomes per-pixel noise.
        vec2 grain_cell = floor(uv * map_size / 4.0);
        float grain = fract(sin(dot(grain_cell, vec2(12.9898, 78.233))) * 43758.5453);
        COLOR.rgb *= mix(0.985, 1.015, grain);

        // A restrained top-left ambient keeps the board from looking evenly
        // lit like a tile editor; the vignette is separate and stays centered.
        float ambient = clamp(0.5 + (UV.x - UV.y) * 0.12, 0.0, 1.0);
        COLOR.rgb *= mix(1.0, 1.03, ambient);

        // Board rim: a thin dark bevel at the edge of the visible slab.
        vec2 edge_px = min(uv * map_size, (1.0 - uv) * map_size);
        float edge = min(edge_px.x, edge_px.y);
        if (edge < 1.5) {
            COLOR.rgb = vec3(0.012, 0.016, 0.022);
        } else if (edge < 5.0) {
            COLOR.rgb *= mix(0.55, 1.0, (edge - 1.5) / 3.5);
        }

        // Gentle vignette keeps the eye on the lander and objectives. It stops
        // at 0.95: the darker band was eating board luma at the edges (W5).
        float vig = smoothstep(0.78, 0.24, length(UV - 0.5));
        COLOR.rgb *= mix(0.95, 1.0, vig);

        if (show_grid == 1) {
            vec2 g = fract(uv * map_tiles);
            float line = (g.x < 0.022 || g.y < 0.022) ? 0.14 : 0.0;
            COLOR.rgb = mix(COLOR.rgb, vec3(0.02, 0.03, 0.04), line);
        }
    }

    if (circle_view == 0) {
        // Sector/windowed view: keep the rectangular tactical focus, but fade
        // the slab edge into space instead of ending on a hard parallelogram.
        // uv is the view-window rectangle, so this fades all four board edges.
        vec2 edge_uv = min(uv, vec2(1.0) - uv);
        float edge_px = min(edge_uv.x, edge_uv.y) * min(map_size.x, map_size.y);
        float edge_alpha = smoothstep(0.0, 46.0, edge_px);
        COLOR.a *= edge_alpha;
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

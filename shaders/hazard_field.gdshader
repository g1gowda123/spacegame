shader_type canvas_item;
render_mode unshaded;

// Animated hazard footprint. One material instance per live hazard; the
// Polygon2D UVs are world tile coordinates, so a 5-cell line and a 5x5 block
// share a continuous pattern instead of repeating per cell.
//
// Modes:
//   0 = armed   (this front resolves at end of turn)
//   1 = forming (faint, arms next turn)
//   2 = scar    (ground left behind after a hit, fades with `intensity`)
//
// Kind (matches sector.gd's HAZARDS dictionary):
//   0 generic, 1 flare, 2 thermal, 3 dust, 4 quake,
//   5 radiation, 6 eclipse, 7 cryo, 8 wind, 9 meteor

uniform vec4 hazard_color : source_color = vec4(1.0, 0.42, 0.35, 1.0);
uniform int kind = 0;
uniform int mode = 0;
uniform float intensity = 1.0;
uniform float seed = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Distance to the border of the cell that owns this fragment.
float cell_border(vec2 f) {
	return min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
}

void fragment() {
	vec2 uv = UV;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float t = TIME;
	float border = cell_border(f);
	float corner = min(f.x, 1.0 - f.x) * min(f.y, 1.0 - f.y); // not used yet
	vec3 col = hazard_color.rgb;
	float a = 0.0;

	// A per-cell random phase keeps a multi-cell footprint from pulsing as one
	// flat rectangle; it is deterministic from the cell coordinate.
	float phase = hash21(cell + seed) * 6.28318;
	// Broad diagonal warning tape: breaks the fill into a readable hazard
	// surface instead of a flat wash. Kept low-contrast so terrain survives.
	float tape = step(0.56, fract((uv.x + uv.y) * 2.4 - t * 0.35));

	if (mode == 2) {
		// Scar: a dark burn with an ember rim. Drawn under the debris/decals.
		float blotch = hash21(floor(uv * 3.0) + seed);
		vec3 char_col = vec3(0.045, 0.035, 0.032);
		float glow = smoothstep(0.55, 0.0, border) * (0.45 + 0.55 * blotch);
		col = mix(char_col, hazard_color.rgb, glow * 0.55);
		a = (0.40 + 0.40 * glow) * intensity;
		// Hot cracks: a couple of thin lines across the cell.
		float cr = abs(fract(uv.x * 2.1 + uv.y * 0.7 + seed) - 0.5);
		float crack = 1.0 - smoothstep(0.0, 0.035, cr);
		col = mix(col, hazard_color.rgb * 1.35, crack * 0.45 * intensity);
	} else if (mode == 1) {
		// Forming: warning outline only, dashed, with a vertical scan.
		float dash = step(0.45, fract((uv.x + uv.y) * 2.0 - t * 0.7));
		float outline = 1.0 - smoothstep(0.03, 0.075, border);
		float scan_y = fract(t * 0.32 + hash21(cell + 4.1));
		float scan = 1.0 - smoothstep(0.0, 0.045, abs(f.y - scan_y));
		// Forming should read as a dashed boundary with a scan/tape hint, not
		// as a solid pale diamond sitting on the map. Keep the fill below the
		// perceptual floor; the outline carries the telegraph.
		float fill = (0.018 + 0.025 * scan) + tape * 0.018;
		a = (outline * 0.78 * dash + fill) * intensity;
		col = mix(col, vec3(1.0), 0.10);
		col = mix(col, col * 0.62, tape * 0.18);
	} else {
		// Armed: hazard-type signature + a pulsing warning border.
		float pulse = 0.5 + 0.5 * sin(t * 4.2 + phase);
		float border_glow = 1.0 - smoothstep(0.015, 0.085, border);
		float inner = 0.112 + 0.036 * pulse;

		if (kind == 1) {
			// Stellar flare: spokes radiating from the cell centre.
			vec2 d = f - 0.5;
			float ang = atan(d.y, d.x);
			float rad = length(d);
			float spokes = pow(0.5 + 0.5 * sin(ang * 9.0 + t * 1.7 + phase), 6.0);
			inner += spokes * 0.36 * (1.0 - rad);
			inner += smoothstep(0.30, 0.0, rad) * 0.25;
		} else if (kind == 2) {
			// Thermal surge: rising convection bands.
			float band = 0.5 + 0.5 * sin(f.y * 12.0 - t * 5.0 + sin(f.x * 4.0) * 1.3);
			inner += band * 0.26;
		} else if (kind == 3) {
			// Dust storm: drifting grit, no clean edge.
			float grit = hash21(floor(uv * 7.0) + floor(t * 3.0));
			inner += step(0.72, grit) * 0.24;
		} else if (kind == 4) {
			// Seismic shock: concentric ground rings.
			float ring = 0.5 + 0.5 * sin(length(f - 0.5) * 26.0 - t * 7.0 + phase);
			inner += pow(ring, 8.0) * 0.30;
		} else if (kind == 5) {
			// Radiation belt: stippled ion grid.
			float stipple = step(0.68, fract(sin(dot(floor(uv * 6.0), vec2(12.9, 78.2))) * 43758.5));
			inner += stipple * 0.22;
			inner += 0.05 * (0.5 + 0.5 * sin(t * 2.0 + phase));
		} else if (kind == 6) {
			// Eclipse: a cold darkening with a thin rim.
			col = vec3(0.06, 0.10, 0.18);
			inner = 0.18;
			border_glow *= 0.6;
		} else if (kind == 7) {
			// Cryo quake: faceted ice fractures.
			float facet = abs(fract(f.x * 3.0 + f.y * 2.0) - 0.5);
			inner += (1.0 - smoothstep(0.0, 0.06, facet)) * 0.16;
			inner += 0.06 * (0.5 + 0.5 * sin(t * 1.4 + phase));
		} else if (kind == 8) {
			// Solar wind: horizontal streaks running downwind.
			float streak = 0.5 + 0.5 * sin(f.x * 16.0 - t * 6.0 + f.y * 3.0);
			inner += pow(streak, 6.0) * 0.24;
		} else if (kind == 9) {
			// Meteor shower: falling diagonals.
			float fall = fract((uv.x + uv.y * 1.6) * 1.8 + t * 0.9);
			inner += (1.0 - smoothstep(0.0, 0.12, fall)) * 0.22;
		}

		// Diagonal warning tape, very low alpha under the signature so the
		// footprint still reads as a striped hazard rather than a flat wash.
		float stripe = step(0.5, fract((uv.x + uv.y) * 2.5 - t * 0.55));
		a = inner + border_glow * (0.23 + 0.14 * pulse) + stripe * 0.025;
		// Alternate dark/light diagonal bands, not a uniform alpha wash. The
		// tape is the thing that makes a hazard footprint read as a surface
		// rather than a UI rectangle at map scale.
		a += tape * 0.092;
		col = mix(col, col * 0.42, tape * 0.35);
		// A darker rim inside every cell gives the footprint a tiled surface
		// at video scale instead of one continuous flat wash.
		float cell_rim = 1.0 - smoothstep(0.0, 0.16, border);
		a += cell_rim * 0.032;
		col = mix(col, vec3(0.035, 0.025, 0.020), cell_rim * 0.12);
		// Brighten the leading edge so a 5-cell line has a readable contour.
		col = mix(col, vec3(1.0), border_glow * 0.22);
	}

	a = clamp(a * intensity, 0.0, 1.0);
	COLOR = vec4(col, a);
}

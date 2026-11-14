# Map overhaul — the "huge" pass (ORION, 18:15)

The tile library is now complete enough that the remaining "RPG-maker / jagged" read is a
**rendering and composition** problem, not an art-supply problem. This document is the
work order for the overhaul. Every item names an owner, a file, an acceptance test and a
capture that must exist before it counts as done.

## Why the board still reads tiled

1. **Patch silhouettes are one cell wide.** `--debug-transitions` on seed 48394 reports
   `outer:62 straight:99 diag:21 inner:30 stripe:4` — corner and diagonal variants *do*
   fire. The rectangles the eye catches are places where a material patch is 1–2 cells
   wide, so the renderer has no choice but a straight edge on both sides.
2. **Edges are hard.** Even a correct outer-corner tile meets its neighbour at a 1-pixel
   seam line; at 2× display scale that reads as a cut-out.
3. **No lighting model.** Ground is flat albedo. Nothing tells the eye which way is up,
   so hills, basins and ridges all read as wallpaper.
4. **No small-scale detail.** A 64 px cell of grass is one texture. Real maps have
   pebbles, cracks, tufts and litter at 4–16 px that break repetition.
5. **The eye finds repeats.** Same rock cluster, same scale, same rotation in one view.

## Workstreams

### W1 — Sub-cell terrain edges (owner: ATLAS, with b)
- Render a **terrain mask field at 4× cell resolution** (one R8 texture per chunk,
  `cell*4` texels, nearest filtered) and hand it to `shaders/map_view.gdshader`.
- In the shader, compute the distance (in texels) from the current fragment to the
  nearest foreign material, then **blend the two material textures with a noise-dithered
  threshold** across a 3–5 texel band. Tiles stop meeting on a seam line; edges become
  organic and faintly irregular at sub-tile scale.
- Keep the existing transition tiles for the *band interior* (beach, wet sand); the mask
  handles the outer silhouette.
- Acceptance: `--debug-transitions` board plus a normal board at seed 48394; no visible
  1-px seam along any material boundary at 2× scale; no measurable frame-time regression
  (`--screen=perf` budget stays under 8 ms).

### W2 — Macro composition (owner: b)
- Minimum feature width **3 cells** for any non-base material; patches narrower than
  that are dissolved into their majority neighbour (morphological open/close on the
  material field).
- Ridges follow contour lines of the height field, not random walks; water fills basins
  and connects downhill; one large readable landform per board (a bay, a plateau, a
  ridge line) instead of evenly scattered noise.
- Acceptance: 20-seed sheet across 6 biomes; no board with more than 3 isolated 1-cell
  patches; each board has one shape a player could name.

### W3 — Elevation lighting (owner: ATLAS + VEGA)
- Height field (noise + ridges) → **directional shading + contact AO** in the map shader:
  tile brightness modulated by slope against a fixed light direction (top-left), plus a
  soft darkening in basins and at the foot of any rise.
- Structures cast one consistent shadow direction (already renderer-owned); terrain must
  agree with it.
- Acceptance: an arid board and a temperate board where hills read as hills with the map
  zoomed out; no "wallpaper" flatness at 2×.

### W4 — Detail decal layer (owner: VEGA)
- 10–14 transparent decals: pebbles, cracked plates, dry tufts, small bushes, glass
  shards, ash flakes. 24–32 px, palette-locked per biome, no shadow.
- Scatter at **6–9 %** of cells on base material only, never on water, never on
  structures or the path preview; bias to cluster (2–4 decals in a neighbourhood).
- Acceptance: side-by-side "before/after" crop of the same seed at 2×; the crop should
  read as a designed map, not a tiled one.

### W5 — Grade and luminance floor (owner: VEGA + ATLAS)
- Every biome's on-screen ground samples to a mid-tone **≥ 120 luma**, hue true to its
  biome (barren = dust grey-tan, iron = rust, cryo = blue-white).
- Shared grade: lift `brightness`, soften the shadow band, keep the vignette but stop it
  eating the board centre.
- Acceptance: measured mean RGB per biome printed in the capture note.

### W6 — Feature dressing and scale harmony (owner: VEGA + ATLAS)
- Structures appear in **clusters with a hero**: one large landmark, 2–3 supporting
  outcrops at 0.55–0.75 scale, a handful of props. No board gets two of the same hero.
- One silhouette per structure key per board; jitter scale ±8 % and tint ±4 % (already
  in the generator, extend to all lifecycle keys).
- Acceptance: three boards, no repeated hero, no structure floating without a contact
  edge.

## Order of work
W1 and W5 first (they change every board), W2 in parallel (generator-side), W4 and W6
next (they add richness), W3 last (it depends on W1's mask and W2's height field).

## Evidence rule
Every item lands with a capture in `/tmp/opencode/` and a line in `docs/BOARD.md`
naming the file. "Looks better" is not a verdict; a named frame at 2× is.

# Structure Scale & Grandeur Pass

Designer: NOVA. Requested by the boss (13:28): *"the big mountains are almost the
same size as the craft… make the world feel grand and bigger."*

## The measurement that caused it

| Sprite | Canvas | Visible alpha bbox | Old render scale | Old on-screen width |
|---|---|---|---|---|
| `lander.png` | 128×128 | 128×112 | 1.15 | **147 px** |
| `mountain_range.png` | 128×128 | 117×120 | 1.55 | 181 px |
| `mountain_massif.png` | 192×192 | 190×185 | 1.05 | 200 px |
| `volcano.png` | 192×192 | 183×187 | 1.00 | 183 px |
| `mesa.png` | 128×128 | 114×119 | 1.00 | 114 px |
| `iceberg.png` | 128×128 | 66×113 | 1.00 | 66 px |

The lander was authored at the same 128 px canvas as a mountain and rendered at
1.15× — so the *craft* was wider than a mountain range and wider than a mesa.
That is the real bug: the scale hierarchy was inverted, not just "mountains are
small".

## Stopgap shipped now (provisional, ATLAS owns final integration)

In `scripts/map_generator.gd`:

- Lander render scale `1.15 → 0.66`; its ground shadow `0.62 → 0.30` radius.
- `sprite_scale`: `mountain_range 1.55→2.40`, `mountain_massif 1.05→1.95`,
  `volcano 1.00→1.75`, `mesa 1.00→1.40`, `iceberg 1.00→1.30`,
  `coral_spire 1.00→1.20`, `geyser 1.00→1.15`, `habitat_dome 1.00→1.10`.
- Reachable-cell/hazard overlay `z_index 12 → 22` so the planning grid stays
  readable over an overhanging mountain.

Evidence: `scale_temperate_grand.png`, `scale_arid_grand.png`,
`scale_cryo_grand.png`, `scale_crystal_grand.png` (Godot user dir).

**Known limitation:** the sprites now overhang their collision footprints, so a
walkable cell can sit under a mountain's visual skirt. That is acceptable for a
stopgap (the path preview still shows blocked cells) but it is exactly what the
proper multi-tile pass below must fix.

## Proper system (delegated)

### Scale hierarchy contract

| Layer | Target visible width | Example |
|---|---|---|
| Props | 0.2–0.5 tile | shell, crystal nub, relay beacon |
| Actor | **0.8–1.0 tile** | lander |
| Medium landform | 2–3 tiles | mesa, iceberg, outcrop |
| Major landform | **4–6 tiles**, 3–5 tall | massif, volcano, ridge |
| Grand landmark | 6–8 tiles, one per sector | caldera, mountain wall |

### A. Structure pieces (VEGA)

Produce 64 px RGBA modules, palette-locked (`tools/palettes.json`), no baked
shadow, no plinth, transparent outside the silhouette:

- `mountain_peak_a/b/c` — one tall summit each, different silhouette.
- `mountain_shoulder_l/r` — half-height ridges that interlock with a peak.
- `mountain_foot_l/m/r` — rubble/foothill bases that hide the tile seam.
- `volcano_cone`, `volcano_flank_l/r`, `volcano_lava_apron` — a 4×4 volcano.
- `ridge_crest_a/b`, `ridge_foot` — 1×2/2×1 range pieces for long walls.
- Preview contact sheets on dark ground, plus a 4×4 assembled massif preview.

Deliver as `assets/tilesets/structures/pieces/` with a manifest of offsets so
ATLAS can place them without guessing. Keep the existing single-sprite files as
the fallback.

### B. Multi-tile composition (ATLAS)

1. Add optional `pieces` to a `STRUCTURES` entry:
   `{"pieces":[{"path":"...","dx":0,"dy":0}, ...], "w":4,"h":4}`. Each piece is
   drawn as its own sprite with a z-index from its own base row, so a lander can
   pass in front of the south face and behind the north peak.
2. Alternatively (minimum viable): add `visual_w/visual_h` and fit the sprite's
   **alpha bbox** to that footprint; block every cell the visible base covers.
   Keep overhang to at most one tile.
3. Collision must match the visible base, not the transparent canvas.
4. Reduce counts as footprints grow: one 5×5 massif is worth four 2×2 rocks.
   Suggested budget: major landforms occupy ≤ 25% of walkable cells per chunk.
5. Wire the 60 existing cliff tiles (`cliff_<height>_<dir>`) to raised terrain
   edges. Cliffs are the cheapest way to make the world feel tall: a 2–3 tile
   wall under a plateau reads as elevation, not a decal.
6. Optional parallax: two dark ridge silhouettes behind the diamond
   (VEGA, 640×120, transparent) to imply terrain beyond the playable sector.

### C. Connectivity guarantee (b / ATLAS)

Bigger footprints can partition the map. After structure placement:

1. Flood-fill walkable cells from the lander.
2. Assert every objective and the extraction pad is in the same component.
3. If not, remove the blocking structure or carve one 1-tile pass through the
   range. Log the repair in dev builds.
4. Run the check over 100 seeds per biome; zero unreachable objectives.

### D. Acceptance criteria (NOVA)

- Lander visible width ≤ 1 tile in every biome.
- A major mountain is clearly ≥ 4× the lander's width in a full frame.
- No walkable cell under a solid peak/volcano core.
- The reachable-cell grid and hazard telegraph are readable over the lander's
  foreground mountain.
- Full frames: temperate, volcanic, cryo, arid, crystal, ocean-edge.
- Headless smoke: zero script/parse errors; Web build still threadless.

## Ownership

- **VEGA:** pieces, previews, optional parallax silhouettes.
- **ATLAS:** `STRUCTURES` schema, piece rendering, cliffs, density retune,
  connectivity, final screenshots.
- **b:** placement/density/connectivity math review; no visual work.
- **NOVA:** hierarchy contract, acceptance review, final report copy.

# Tile Requests — Surface Renderer

**Status:** the map already has broad generic coverage. The remaining problem is
not raw tile count — it is missing *categories* that the renderer cannot fake.

## Current coverage

| Asset class | Count | Notes |
|---|---:|---|
| Terrain tiles | 78 | 5 base palettes; temperate has 24, other bases 6–12 |
| Transition tiles | 1,764 | 98 ordered pairs × 18 files (straight, outer/inner corners, stripes) |
| Natural structures | 28 | mostly 2×2; `volcano` is 3×3 |

The eight exotic biomes (`methane`, `iron`, `sulfur`, `crystal`, `obsidian`,
`ammonia`, `carbon`, plus ocean reefs) are currently **tinted reuses** of the
five base sets. That is why they read as recolors, not alien worlds.

## Priority 0 — fixes the two visible defects

### 1. Diagonal shore split tiles

The 64 px grid still shows right-angle water spurs. Generic corner tiles cannot
fix a one-cell diagonal because the boundary runs through the middle of a cell.

- 4 split tiles per water/land pair: `nw`, `ne`, `se`, `sw`.
- Pairs: `temperate/water_lake`, `ocean/water_shallow`, `ocean/water_deep`,
  `volcanic/lava`, `carbon/water`.
- Count: **20 tiles**.
- Each tile is a 64×64 cell with the water half cut on the named diagonal,
  including a 1 px shoreline band and a 1 px darker water edge.

### 2. Water depth and shore foam

One water tile per biome is not enough for a movement game.

- `temperate`: `water_lake_shallow`, `water_lake_deep`, `water_foam`.
- `ocean`: `water_shallow`, `water_deep` (exists), `water_reef` (exists),
  `water_foam`, `water_shelf`.
- `volcanic`: `lava_crust`, `lava_glow`.
- `cryo`: `ice_cracked`, `ice_thin`.
- Count: **10–12 tiles**.

## Priority 1 — makes the world feel grand rather than flat

### 3. Cliff faces

Mountains currently sit on flat rock ground. A cliff reads as elevation.

- 3 heights × 4 directions (`n/e/s/w`) × 5 palettes = **60 tiles**.
- Palette families: temperate, arid, cryo, volcanic, barren.
- Variants may share geometry and be palette-swapped; the silhouette is the
  expensive part.
- Each tile is a 64×64 face with a 2–3 px top lip, a dark base line, and no
  baked cast shadow (the shader adds direction).

### 4. Rivers and canyon channels

- 16-piece auto-tile set: straight ×2, bend ×4, T ×4, cross, source, mouth,
  shallow edge ×2, ford.
- 3 palettes: temperate water, arid dry riverbed, volcanic lava channel.
- Count: **48 tiles**.
- Width: one cell (64 px), with a 1 px bank on each side.

### 5. Exotic ground identities

Each exotic biome needs 6–8 tiles that are not a tint of grass/sand/snow:

| Biome | Distinct forms |
|---|---|
| methane | methane pools, bubbling mud, ice shards |
| iron | rust plates, oxide dunes, metallic shards |
| crystal | crystal shards, glassy ground, prism cracks |
| ammonia | ammonia slush, white crust, blue pools |
| obsidian | glass plates, sharp shards, ash |
| carbon | tar, graphite dust, diamond crust |
| sulfur | yellow crust, vents, acid pools |

Count: **42–56 tiles**. Start with 6 per biome.

## Priority 2 — landmarks and scale

### 6. Natural structures

One per biome family, 128×128 or 192×192, transparent background, no plinth,
no ground shadow:

- sandstone arch (arid)
- hoodoo cluster (arid)
- glacier wall (cryo)
- geyser field (volcanic)
- crystal spire (crystal)
- canyon bridge (arid/barren)
- methane vent (methane)
- basalt columns (volcanic)

Count: **8 structures**.

### 7. Detail props

Small 32–64 px accents, 6 per base biome: bones, shells, vents, cracks, tufts,
ice teeth. Count: **30–36**. These are optional once the ground reads.

## Output contract

- Terrain: **64×64**, PNG RGBA, full tile, no transparent margin.
- Structures: **128×128** or **192×192**, RGBA, transparent, no shadow/plinth.
- Palette-locked per biome; maximum 12–16 colors for ground, 24 for structures.
- No anti-aliasing, no baked directional light, no text.
- Naming: `assets/tilesets/<biome>/<name>.png`.
- After adding a tile, register it in `scripts/map_generator.gd` under the
  biome’s `base`/`detail`/`rock`/`water`/`shore` keys, and add impassable
  materials to `BLOCKED`.
- Transition extras are generated from the new pairs:

```bash
/home/g1/ComfyUI/.venv/bin/python tools/gen_transition.py --all-extras --band 5 --scatter 10 --wave 12 --seed 301
```

## What not to make

- More random grass/sand/snow variants. The 1,764 transition files already
  cover generic adjacency; another 200 noise variants will not change the read.
- Manmade panels, solar farms, roads, or cities. The fiction is lifeless
  planets; the existing outpost props are the only allowed exception.
- Tiles with baked shadows or perspective. The map shader owns light direction
  and the sides are drawn as separate cliff faces.

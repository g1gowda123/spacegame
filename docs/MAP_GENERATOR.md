# Map Generator

## Current state

- Dev scene: `scenes/map_generator.tscn`
- Script: `scripts/map_generator.gd`
- Shader: `shaders/map_view.gdshader`
- The project main scene is `scenes/title.tscn`; this scene is the generator's development entry point and is launched directly (`godot --path . scenes/map_generator.tscn`). It is wired and verified through in-game capture (`-- --capture`); the script still needs broader visual passes.
- The generator is currently monolithic. Splitting terrain/chunk/UI into modules is an open task.
- **Scope:** the generator is the foundation of the surface sectors. Gameplay systems (turns/data/hull/hazards) live in `scripts/game_state.gd` and `scripts/sector.gd`; art/tiles are owned by another agent.

## Controls

| Input | Action |
|---|---|
| `WASD` / arrow keys | Move the lander one tile |
| `R` | New random seed and regenerate |
| `T` | Regenerate with the same seed |
| `B` | Next biome (13 total) |
| `1`–`6` | Jump to temperate / arid / cryo / volcanic / ocean / barren |
| `7`–`0` | Jump to methane / iron / sulfur / crystal |
| `[` / `]` | Jump to obsidian / ammonia |
| `\` | Jump to carbon |
| `V` | Cycle view: 3/4 tilt → isometric → top-down |
| `G` | Toggle tile grid |
| `C` | Copy the current seed to the clipboard |
| `F3` | Toggle the debug overlay (seed, FPS, cell, chunk, chunk count, props/structures) |
| `F4`–`F8` | Toggle mountains / outposts / occlusion / props / sky (feature bar) |
| `F9` | Toggle the transition-debug overlay (tints every boundary cell by the variant it received) |
| `F10` | Save a viewport capture to `user://map_capture.png` |
| `F11` | Toggle windowed / fullscreen (desktop) |
| `H` | Hide/show the UI |

The on-screen panel has the same actions, plus a D-pad in the bottom-right. The nav line reports the nearest uncollected data node in screen-relative compass terms.

> **Dev scene vs sector.** In this dev scene WASD moves the lander exactly one tile. The shipped sector (`scripts/sector.gd`) overrides input: WASD/arrows move a path cursor, ENTER/MOVE commits one move of up to `move_range` tiles, and `V`/`G` still cycle the view and grid. `H` and `F10` are not forwarded to this handler from the sector.

### CLI (headless/debug)

```bash
godot --path . -- --capture --seed=16936 --biome=temperate --view=iso
```

| Flag | Meaning |
|---|---|
| `--seed=N` | Deterministic world seed |
| `--biome=<id\\|index>` | Start biome, e.g. `arid` or `2` |
| `--view=tilt\\|iso\\|top` | Initial projection |
| `--grid` | Start with the tile grid on |
| `--debug` | Start with the debug overlay on |
| `--no-ui` | Hide the gameplay/UI layer for clean map captures |
| `--debug-transitions` | Start with the transition-debug overlay on (also accepted by `scripts/sector.gd`) |
| `--legacy-water` | Skip water-body shaping (pre-coalescing shoreline), for A/B evidence |
| `--water=<r>,<p>,<wet>,<dry>` | Override the shaper knobs (default `1,1,0.60,0.40`) for same-seed comparisons |
| `--capture` | Render one frame to `user://map_capture.png`, then quit |

## Biomes

Thirteen biome definitions drive terrain, structures, props, tint and life status. The seven `exotic` entries reuse existing tile keys as placeholders until dedicated art arrives; the art agent owns those tiles.

| id | Name | Profile | Life | Tint |
|---|---|---|---|---|
| `temperate` | Temperate | temperate | rare biosphere | neutral |
| `arid` | Arid | arid | lifeless | neutral |
| `cryo` | Cryo | cryo | lifeless | neutral |
| `volcanic` | Volcanic | volcanic | lifeless | neutral |
| `ocean` | Ocean | ocean | lifeless | neutral |
| `barren` | Barren | barren | lifeless | neutral |
| `methane` | Methane Lakes | temperate | lifeless | `#63d6c4` |
| `iron` | Iron Desert | arid | lifeless | `#d97a50` |
| `sulfur` | Sulfur Plains | volcanic | lifeless | `#f0dc5a` |
| `crystal` | Crystal Field | barren | lifeless | `#b08cff` |
| `obsidian` | Obsidian Glass | volcanic | lifeless | `#9b7bd6` |
| `ammonia` | Ammonia Ice | cryo | lifeless | `#72c8e8` |
| `carbon` | Carbon World | temperate | lifeless | `#9aa2b2` |

`profile` selects the terrain algorithm; `shore_ring` adds a beach/shore ring around water (**methane, carbon** — temperate dropped its ring at 17:50 in favour of grass-to-water transitions). `life` controls the status line, so only temperate reports a biosphere.

## Architecture

### World and chunks

- `TILE = 64`, `CHUNK = 16`, `VIEW_W = 24`, `VIEW_H = 18`.
- Terrain is an infinite deterministic field from two `FastNoiseLite` layers (elevation and detail), seeded by `seed_value`.
- Each chunk is generated independently from `_chunk_seed(coord)`, so unloading and revisiting a chunk reproduces it exactly.
- Active neighborhood: 3×3 chunks. Chunks more than 2 chunks from the player are erased.
- `_pick_terrain()` uses the biome `profile` and maps elevation/detail through that profile’s thresholds. `shore_ring` is handled at render time.
- Water bodies go through `scripts/water_shaper.gd` between sampling and smoothing (see “Water shaping” below). Shaped water is the `shore_ring` biomes plus temperate, which needs the tiny-pond/spur cleanup even without a beach ring (`water_keys()` returns nothing for the rest); volcanic lava stays authored.
- Structures are placed fully inside a chunk; chance is `0.60` per chunk. Selection is biome-specific (sulfur volcano/geyser, iron mesa/crater, methane iceberg/crystal/crater, etc.); ocean structures only appear on reef, barren structures only on regolith.
- `_in_view()` culls structures, props, hazard cells, and data nodes outside the 20×16 render window, so nothing is drawn on the black board surround.
- Props are wired at chunk generation time. Density is per biome (`PROP_DENSITY`: temperate 4.5 %, cryo 3.2 %, ocean 1.5 %, 3 % default), and each biome has its own prop list (`PROPS`), including the generated ground accents (`accent_<biome>_<shape>.png`). `_prop_is_usable()` rejects PNGs with less than 8 % transparent pixels as a safety net.

### Rendering and streaming

- Only a `20×16` tile window around the player is drawn. It lives in a `1280×1024` `SubViewport` (about 5 MB), then the shader projects it to the screen. This keeps GPU/texture memory small for mobile.
- `_render_window()` sets `view_origin = player_cell - (VIEW_W/2, VIEW_H/2)`, fills the local window, applies shoreline and transition passes, and requests `SubViewport.UPDATE_ONCE`.
- `_project(world)` reproduces the shader's transform for overlays, structures, and actors.
- Structure sprites are bottom-anchored to the footprint’s south edge by visible alpha, so transparent padding does not make them hover. A structure with `"ground": true` (currently `impact_crater`) is center-anchored and squashed by `tilt`, so it reads as a decal instead of a floating object.
- The shader applies a 12px dark slab-edge band outside the board plus a drop shadow, color grade, vignette, and per-biome tint (`biome_tint`, `biome_tint_strength`). The bevel is subtle; stronger sidewalls are still a visual-polish task.
- The ground texture is re-rendered when the player moves or the map regenerates, not when only the view mode changes.

### Transitions

- `TRANSITION_PAIRS` lists material pairs. `gen_transition.py` produces four oriented tiles per pair under `assets/tilesets/transitions/<a>_<b>/`.
- For each rendered tile, the generator finds a differing neighbor with the highest priority (`water > shore > rock > detail > base`) and looks up a transition in either pair order. If no pair exists, it keeps the base tile.
- Every water material inherits the water priority (`5`), including biomes whose open water is `base`/`detail` instead of `water` (ocean: `ocean/water_shallow` / `ocean/water_deep`). Without that, `ocean/water_shallow` sat at the base priority and lost single-corner cells to the beach ring — 47 of 181 ocean corner cells fell back to right angles even with the diagonal art present.
- Corner cells (a land tile with exactly one diagonal water neighbor and no orthogonal water neighbor) use the hand-authored 45-degree split in `assets/tilesets/transitions/diagonal/<land>_<water>/<corner>.png`, which cuts the tile on the diagonal instead of stamping a right-angle corner. `tools/make_diagonal.py` (Python) and `tools/make_diagonal_gd.gd` (the same maths in Godot, for machines without numpy) build them from the two existing palette-locked tiles.
- A pair listed water-first in `transitions.json` still registers its land-first diagonal key, so art authored as `<land>_<water>` is found for both orderings.
- **Coverage note:** the diagonal art must exist for the material the renderer actually draws at the coast. On a `shore_ring` biome (methane, carbon) the land cell is swapped to the *shore* tile at render time, so the pair that matters is the shore↔water pair, not the base↔water pair. Temperate no longer has a shore ring, so for it the pair that matters is now `temperate/grass` ↔ `temperate/water_lake` (added 17:50 with the sand-band removal). Before the shore pairs existed, 100 % of corner cells fell back to the right-angle corner tile even though the diagonal art was present.
- **Measured coverage** (probe `--diagcheck`, 5-chunk window): temperate 235/235, methane 80/80, carbon 106/106, ocean 181/181 corner cells select a diagonal tile, 0 missing. That run predates temperate dropping its shore ring, so re-run `--diagcheck` to confirm the grass↔water pair covers the same cells. The last ocean gap was not art but priority (see above); with the priority fix the reef↔beach straight/right-angle tiles no longer outrank the reef↔water corner.

### Water shaping

Shorelines are produced in three chunk-local stages, in this order:

1. **Sample.** `_pick_terrain()` thresholds the warped elevation field. `shore_noise` (frequency 0.14) jitters the threshold per cell; `rough_noise` (frequency 0.045) scales that jitter, so some coast stretches read clean and others fray.
2. **Shape.** `scripts/water_shaper.gd` votes on the binary water mask of the padded chunk: a 3×3 window, land becomes water at ≥ 0.60 wet, water becomes land at ≤ 0.40 wet, one pass. That deletes 1–2 cell lakes, pinholes and sand specks before they ever reach the tile grid, while a straight coastline is a fixed point (land cell 4/9 = 0.44 > 0.40, water cell 5/9 = 0.56 < 0.60) so the coast does not creep outward.
3. **Smooth.** `_smooth_cell()` runs the legacy 3×3 material vote on the shaped mask.

Why a cellular automaton and not a component-size filter: a “delete water bodies smaller than N cells” pass measures better on paper, but it is not seam-safe. A 2-cell pond that touches one chunk window’s border is kept there (its true size is outside the window) and removed in a window where it is interior — and because a chunk’s raw terrain also feeds its neighbours’ transition choices, that disagreement renders as a shore tile next to land, i.e. a visible line along the chunk edge. A CA is strictly local, so every chunk computes the same value for the cells it shares with its neighbour as long as the raw halo is wide enough.

Cost: the raw halo grows from 1 to 2 cells (`pad` 18 → 20 per chunk, +23 % noise samples) plus 9 compares per cell per pass. Knobs (`RADIUS`, `PASSES`, `WET`, `DRY`) sit at the top of `water_shaper.gd`. `--legacy-water` skips stage 2 for side-by-side captures of the same seed.

`tools/water_probe.gd` measures the result on the real generator (fragmentation, water fraction, perimeter, corner-cell count, diagonal selection, and the clean-vs-frayed split by `rough_noise`) so tuning is evidence-based.

### Gameplay

This dev scene carries a **simplified** loop that exists to exercise terrain, not the shipped rules:

- Player: lander sprite from `assets/tilesets/structures/lander.png`.
- Start: 36 turns, 3 hull, 4 data objectives within 6–14 tiles.
- Each move consumes a turn, checks walkability (water/lava and structure footprints block), collects objectives, resolves the telegraphed 3×3 hazard, then spawns the next hazard.
- Hazard kinds: Solar flare, Dust storm, Radiation surge, Seismic shock.
- Game over: hull 0, all data collected, or turns exhausted.

The shipped sector is `scripts/sector.gd` (extends this generator) and owns the real rules: one committed move per turn of up to `move_range` tiles, per-tile Δv/sol/heat cost, nine hazards that resolve at end of turn, relay-beacon sectors, quota + landing-zone EXTRACT. See `README.md` "Surface operations".

### Mobile budget

- GL Compatibility renderer.
- One small SubViewport instead of a full-world texture.
- 3×3 chunk cache and unload beyond 2 chunks.
- Nearest filtering, 64×64 tiles.

## Extending

### Add a ground tile to a biome

1. Generate the tile into `assets/tilesets/<biome>/<name>.png` with `tools/gen_asset.py --tile --biome <palette>`.
2. Add it to the relevant `BIOMES` entry. The current fields are `base`, `detail`, `rock`, `shore`, `water`.
3. Add transition pairs to `TRANSITION_PAIRS` and `tools/transitions.json`, then run `tools/gen_transition.py`.
4. The runtime `TileSet` rebuilds automatically from the paths in `BIOMES`; missing files log a warning instead of crashing.

### Add a structure

1. Generate a transparent 128×128 or 192×192 sprite with `--bg auto` and an outline.
2. Copy it to `assets/tilesets/structures/<name>.png`.
3. Add an entry to `STRUCTURES` with `path`, `w`, `h`.
4. Add placement rules in `_generate_chunk_structures()`.

### Add a biome

1. Add a palette to `tools/palettes.json`.
2. Add a `BIOMES` entry with base/detail/rock/shore/water keys.
3. Generate the tiles and transitions.
4. Add it to the `1`–`6`, `7`–`0`, `[`/`]`, or `\` hotkey list if desired.
5. Add a `PROPS` entry and any biome-specific structures. Reuse an existing `profile` if the terrain algorithm should match another biome.

## Known issues / next work

- Visual validation now uses the in-game capture path; recapture after each meaningful change. Black/gray frames are failed captures.
- **Props**: density is per biome (`PROP_DENSITY`), so tune a biome by its own entry; the temperate map is intentionally the busiest.
- **Exotic art is partly inert**: dedicated methane/iron/sulfur/crystal/obsidian/ammonia/carbon tiles exist under `assets/tilesets/<biome>/`, but `BIOMES` still reuses existing tile keys plus tint for most of them. `tools/qa/audit_project.py` lists every unwired file.
- **Transitions**: 125 pairs, straight + corner + 45-degree split tiles. Three-way junctions are still unsolved, and a pair without a diagonal set falls back to the right-angle corner tile. Press `F9` (or pass `--debug-transitions`, also accepted by the sector) to tint every boundary cell by the variant it received — `TRANSDEBUG` prints the per-kind counts so "selection vs art" is measurable.
- **Structure grounding**: `impact_crater` uses the `"ground": true` center anchor + tilt squash; upright structures bottom-anchor by visible alpha and the renderer owns an irregular contact rim.
- **World aliveness**: structure chance is `0.60` per chunk, props are per-biome density, and the structure z-order is clamped below the lander (950) and the occlusion haze (1000).
- **Dropped**: the 60 top-down `cliff_<height>_<dir>` tiles do not sit on an isometric rim (they read as planks). The face strips (`assets/tilesets/cliffs/face_<biome>.png`) are the live route.
- **Board read**: the board now renders inside a circular survey disc with a dim outer skirt (edge fog) and a 12 px bevel. Rectangular patch silhouettes on **barren/iron** are the remaining top visual defect; the `F9` overlay is the tool for diagnosing them.
- **Modularize**: split `TerrainGenerator`, `ChunkWorld`, `MapUI`, `TileCatalog`; remove gameplay-only systems from the generator path if they impede map work.
- **Web export**: `export_presets.cfg` and a threadless WebGL 2 build are in the tree; re-export with `tools/release.sh` / `tools/release.py` after source or art changes.
- **Debug**: seed copy, minimap, feature toggles (`F4`–`F8`) and the transition overlay (`F9`) are done; a seed input field and a chunk-border overlay are not.
- **Terrain art**: noisy grass and bright patchwork are art-agent issues; do not regenerate tiles in this scope.

## Tuning from the editor
See `docs/TUNING.md`: the map root now exposes Inspector groups for render window, seed/biome, camera/circle, fog, decals and shader edge/relief modes, with CLI equivalents.

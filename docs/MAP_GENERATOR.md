# Map Generator

## Current state

- Main scene: `scenes/map_generator.tscn`
- Script: `scripts/map_generator.gd`
- Shader: `shaders/map_view.gdshader`
- The scene is wired and the project main scene is set. The generator is now verified through in-game capture (`godot --path . -- --capture`); the script still needs broader visual passes.
- The generator is currently monolithic. Splitting terrain/chunk/UI into modules is an open task.
- **Scope:** the map generator is the product. Gameplay systems (turns/data/hull/hazards) are present only as a demo/telegraph; art/tiles are owned by another agent.

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
| `H` | Hide/show the UI |

The on-screen panel has the same actions, plus a D-pad in the bottom-right. The nav line reports the nearest uncollected data node in screen-relative compass terms.

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

`profile` selects the terrain algorithm; `shore_ring` adds a beach/shore ring around water (temperate, methane, carbon). `life` controls the status line, so only temperate reports a biosphere.

## Architecture

### World and chunks

- `TILE = 64`, `CHUNK = 16`, `VIEW_W = 20`, `VIEW_H = 16`.
- Terrain is an infinite deterministic field from two `FastNoiseLite` layers (elevation and detail), seeded by `seed_value`.
- Each chunk is generated independently from `_chunk_seed(coord)`, so unloading and revisiting a chunk reproduces it exactly.
- Active neighborhood: 3×3 chunks. Chunks more than 2 chunks from the player are erased.
- `_pick_terrain()` uses the biome `profile` and maps elevation/detail through that profile’s thresholds. `shore_ring` is handled at render time.
- Structures are placed fully inside a chunk; chance is `0.60` per chunk. Selection is biome-specific (sulfur volcano/geyser, iron mesa/crater, methane iceberg/crystal/crater, etc.); ocean structures only appear on reef, barren structures only on regolith.
- `_in_view()` culls structures, props, hazard cells, and data nodes outside the 20×16 render window, so nothing is drawn on the black board surround.
- Props are wired at chunk generation time (6% of walkable cells). `_prop_is_usable()` rejects PNGs with less than 8% transparent pixels as a safety net; the art agent rebuilt the six props with `tools/make_prop.py` and 48–80% transparency, so they should now render.

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
- This gives straight and wavy boundaries without full blob autotiling. Corners and three-way junctions are not solved yet.

### Gameplay

- Player: lander sprite from `assets/tilesets/structures/lander.png`.
- Start: 36 turns, 3 hull, 4 data objectives within 6–14 tiles.
- Each move consumes a turn, checks walkability (water/lava and structure footprints block), collects objectives, resolves the telegraphed 3×3 hazard, then spawns the next hazard.
- Hazard kinds: Solar flare, Dust storm, Radiation surge, Seismic shock.
- Game over: hull 0, all data collected, or turns exhausted.

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
- **Props**: the art agent rebuilt all six with transparent borders; verify they appear at the intended 6% density and tune per biome (the temperate map can look shrub-heavy).
- **Exotic art is placeholder**: methane/iron/sulfur/crystal/obsidian/ammonia/carbon reuse existing tile keys plus tint. Dedicated tiles are art-agent work.
- **Transitions**: only straight edge tiles exist. Diagonal/three-way boundaries still staircase. Implement the 14-tile corner/stripe set and 8-neighborhood placement from `docs/TASKS.md`. Methane/carbon shore edges also lack dedicated transition pairs.
- **Structure grounding**: `impact_crater` now uses the `"ground": true` center anchor + tilt squash; audit the upright structures and keep shadows touching the cell base.
- **World aliveness**: structure chance is `0.60` and props are 6%; assess whether that is too dense or too sparse, and add rare 2–3-tile sites. Art/tiles remain owned by another agent.
- **Board read**: the 12px bevel is subtle; the board still reads flat. Stronger sidewalls and a tighter ITB-style frame are next.
- **UI**: 232px panel is still large at 640×360; compact it. Fullscreen target is 1920×1200.
- **Modularize**: split `TerrainGenerator`, `ChunkWorld`, `MapUI`, `TileCatalog`; remove gameplay-only systems from the generator path if they impede map work.
- **Web export**: add `export_presets.cfg`; install Web export templates; browser test.
- **Debug**: seed copy is done; add a seed input field, minimap, and chunk-border overlay.
- **Terrain art**: noisy grass and bright patchwork are art-agent issues; do not regenerate tiles in this scope.

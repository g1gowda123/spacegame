# Art Handoff — ORBIT & OUTPLAY

**Status:** the code-side integration is done. `SpaceBackdrop` and `ShipDiagram`
now load PNGs from the exact paths below. They no longer draw shader/vector
illustrations. The files currently in the repo are temporary generated
placeholders; replace them in place, do not rename or move them.

**Canonical command:** `bash tools/gen_game_art.sh`
The full prompt list, seeds and dimensions are in that script. Run it from
`/home/g1/godot/nasa` with ComfyUI on `http://127.0.0.1:8188`.

## Non-negotiable output contract

| Kind | Path | Size | Format |
|---|---|---|---|
| Ship portraits | `assets/sprites/ships/<hull>.png` | **190×70** | PNG, RGBA, transparent |
| Planet portraits | `assets/sprites/planets/<biome>.png` | **256×256** | PNG, RGBA, transparent |
| Title/report hero | `assets/sprites/planets/ringed.png` | **320×320** | PNG, RGBA, transparent |
| Space background | `assets/backgrounds/space.png` | **640×360** | PNG, RGB, full bleed |
| Data marker | `assets/sprites/markers/data_node.png` | **64×64** | PNG, RGBA, transparent |
| Lander | `assets/tilesets/structures/lander.png` | **128×128** | PNG, RGBA, transparent |

- `hull` is exactly `pathfinder`, `cryo`, `relay`, `hopper`.
- `biome` is exactly one of `temperate`, `arid`, `cryo`, `volcanic`, `ocean`,
  `barren`, `methane`, `iron`, `sulfur`, `crystal`, `obsidian`, `ammonia`,
  `carbon`.
- Use nearest/pixel-art output. No anti-aliasing, no gradients, no text, no
  watermark, no frame, no drop shadow, no stars in planet portraits.
- Ships must read as **horizontal side profiles** with a clear silhouette at
  190×70. Do not accept a front/three-quarter view.
- Planets must be **isolated discs** with transparent corners; the code places
  them over a starfield and applies no tint.
- Keep a 2–4 px transparent margin around sprites so the nearest-filtered
  outline never clips at the edge.

## Existing working workflows

Do not reinvent the graph. The project already has:

- `tools/comfy_workflows/itb_sprite.json` — SDXL + Pixel Art XL sprite graph.
- `tools/comfy_workflows/grass_tile.json` — tile graph.
- `tools/gen_asset.py` — automated version of the sprite graph:
  `sd_xl_base_1.0.safetensors` + `pixel-art-xl.safetensors`, 25 steps,
  CFG 5, `dpmpp_2m` / `karras`, 1024 source, magenta/auto background key,
  palette quantize, 1 px outline.
- `tools/pixelize_sprite.py` — wide/tall crop-and-fit for non-square sprites.
- `tools/make_ship.py` — **use this for the 190×70 ships.** Key → despeckle →
optional `--largest` → `--inset` frame crop → prefilter → LANCZOS fit → quantise
→ outline. Unlike `pixelize_sprite.py` it keeps the keyed alpha (that script's
NEAREST 5.6× reduction also moirés solar panels).
- `tools/pixelize.py` — square sprite/tile post-process.

`gen_asset.py` now accepts `--gen-width` and `--gen-height` for non-square
source renders. The ship pipeline is:

```bash
/home/g1/ComfyUI/.venv/bin/python tools/gen_asset.py \
  "isolated game sprite of a long interplanetary survey spacecraft, side profile, ..." \
  --out assets/raw/ship_pathfinder.png \
  --gen-width 1024 --gen-height 512 --seed 701 --colors 20 \
  --bg magenta --outline 10,14,20 \
  --view "exact horizontal side elevation, orthographic, flat 2D game sprite" \
  --negative-extra "front view, three-quarter view, planet, background scene, ground shadow, text" \
  --no-pixelize

/home/g1/ComfyUI/.venv/bin/python tools/make_ship.py \
  assets/raw/ship_pathfinder.png --out assets/sprites/ships/pathfinder.png \
  --width 190 --height 70 --colors 20 --bg auto --outline 10,14,20 \
  --largest --inset 8
```

## Asset-by-asset brief

### 1. Ships (4) — DONE (tiles agent, 07:47)

All four are visible immediately on Mission Design. They should share the same
camera, outline weight and palette language, but have distinct silhouettes:

- **pathfinder** — long silver survey bus, two rectangular solar wings, small
  dish, gold foil, teal lights. General-purpose.
- **cryo** — white insulated bus, three pale-blue radiator fins, blue solar
  wings. Reads cold.
- **relay** — amber/grey bus, oversized high-gain dish, widest solar arrays.
  Reads communications.
- **hopper** — compact purple/grey wedge lander, folded legs, one small wing.
  Reads light and fragile.

Delivered: pathfinder (seed 1901, teal/silver bus), cryo (2401, pale blue
insulated hull + fins), relay (2601, orange wedge), hopper (2502, mauve
rounded shuttle). Raws in `assets/raw/ship_<hull>.png`; every file verified
190×70 RGBA with 43–74% transparent. Evidence `/tmp/opencode/ships_sheet.png`
and `/tmp/opencode/design_shot2.png`.

### 2. Planet portraits (13 biomes + ringed hero) — highest priority

Draft cards show these at 92×72; the background uses them at up to 320 px.
They must read at 64 px. Match `GameState.BIOME_INFO` colors:

- temperate `#7fe08a`, arid `#ffb06a`, cryo `#8fd4ff`, volcanic `#ff6d5e`,
  barren `#b8b0a0`, methane `#63d6c4`, iron `#d97a50`, sulfur `#f0dc5a`,
  crystal `#b08cff`, obsidian `#9b7bd6`, ammonia `#72c8e8`,
  carbon `#9aa2b2`, ocean `#3f8fd8`.
- `ringed.png` is the title and final-report hero: one tilted Saturn-like
  planet, teal/blue bands, a single thin ring, transparent background.

Prompts are in `tools/gen_game_art.sh` section 2/3. Seed range 711–724.
The current `rocky.png`/`ringed.png` are placeholders; overwrite them.

**Planet QA:** `tools/gen_game_art.sh` already applies the circular alpha mask
after pixelizing each biome portrait (elliptical mask at the alpha-bbox centre,
radius 116 px on the 256 px final). This removes cast-shadow crescents and
forces a readable disc. Ringed planets must not be circular-masked; key the
background instead. If a generated portrait is still a landscape or rock pile,
reject it and reroll with the same prompt/negative list — do not accept it.

### 3. Space background (1)

`assets/backgrounds/space.png`, 640×360. Very dark navy, tiny stars, faint
teal/violet nebula. **No planet, no bright sun, no large focal object** — the
UI and planet portraits sit on top. Keep brightness low; the current
placeholder has a bright orange sun and is only a stand-in.

Command: `tools/gen_game_art.sh` section 4. It renders 1280×720, downsizes to
640×360 with Lanczos, and darkens to 0.58 so the white HUD stays readable.
The current `space.png` is a darkened crop of the first starfield render; rerun
the command to replace it with a clean full-frame starfield.

### 4. Sector actors (2)

- `data_node.png` — 64×64 teal science beacon/crystal on a tripod. Used as the
  world marker at 46% scale; needs a strong silhouette and dark outline.
- `lander.png` — 128×128 isometric lander, already used by the sector. Keep the
  same “tactical game unit” camera as the existing map props.

### 5. Not art / intentionally code

- HUD bars, buttons, panels, chips, frame lines and text are Godot `Control`
  chrome, not illustrations. Do not generate UI frames or font atlases.
- Hazard area is a translucent 3×3 cell overlay telegraph, not a sprite; its
  color comes from the hazard table in `sector.gd`.
- Orbit/route preview lines are gameplay overlays, not art assets.
- The title wordmark is text, not an image.

## Integration map (code already wired)

| Asset | Consumer |
|---|---|
| `assets/sprites/ships/*.png` | `scripts/ship_diagram.gd` via `ShipDiagram` |
| `assets/sprites/planets/<biome>.png` | `scripts/space_backdrop.gd` `asset_for_planet()`; draft/debrief/report |
| `assets/sprites/planets/ringed.png` | title + report `planet_asset: "ringed"`; falls back to rocky |
| `assets/backgrounds/space.png` | `SpaceBackdrop` star layer on every screen |
| `assets/sprites/markers/data_node.png` | `scripts/map_generator.gd` `node_tex` |
| `assets/tilesets/structures/lander.png` | `scripts/map_generator.gd` `player_tex` |

If a biome portrait is missing, `SpaceBackdrop` falls back to `rocky.png`; it
will not crash. Still, the final build should contain all 13 so drafts are
visually distinct.

## QA checklist

- [ ] All filenames exactly match the table.
- [ ] Ships are 190×70 with transparent corners and read as side profiles.
- [ ] Planets are 256×256, isolated, no stars/shadow/background, transparent.
- [ ] `ringed.png` has a ring that reads at 320 px and no grey box.
- [ ] Background is 640×360 and dark enough for white UI text.
- [ ] `data_node.png` reads at 48 px; `lander.png` at 128 px.
- [ ] No file contains text or a watermark.
- [ ] Run `godot --headless --path . --quit-after 4` with no import/parse errors.
- [ ] Screenshot title, design, draft, sector, debrief, report at 1280×720.

## Replace workflow

1. Generate to `assets/raw/` first.
2. Review at native size and at game size.
3. Write the final path in the table above.
4. Re-import Godot (launch editor/headless).
5. Run the QA checklist.
6. Append the result to `docs/WORKLOG.md`.

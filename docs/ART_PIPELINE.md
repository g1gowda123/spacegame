# Art Pipeline

> **Attribution:** all image generation is run by the user in ComfyUI (SDXL Base
> 1.0 + Pixel Art XL) on the local machine. Prompts, seeds and accept/reject
> decisions are the user's. Agents wrote the scripts in `tools/` and wired the
> outputs into the game.

## Game illustrations

The tile pipeline below covers terrain. Every **non-tile illustration**
(spacecraft, planet portraits, starfield background, data marker, lander) is
ComfyUI-generated raster and is integrated through exact file paths. Read
[`docs/ART_HANDOFF.md`](ART_HANDOFF.md) and run the canonical command list:

```bash
cd /home/g1/godot/nasa
bash tools/gen_game_art.sh
```

The game no longer uses shader or vector illustrations for these assets.

## Toolchain

- ComfyUI 0.45.0 at `http://127.0.0.1:8188`
- Checkpoint: `sd_xl_base_1.0.safetensors`
- LoRA: `pixel-art-xl.safetensors` at weight 1.0
- Python: `/home/g1/ComfyUI/.venv/bin/python`
- No “pixel art” trigger in prompts; the LoRA supplies the pixelation.

## Tile generation

```bash
cd /home/g1/godot/nasa
/home/g1/ComfyUI/.venv/bin/python tools/gen_asset.py \
  "lush green grass field, chunky grass clumps" \
  --out assets/tilesets/temperate/grass.png \
  --size 64 --colors 16 --tile --biome temperate --seed 21
```

- `--tile` disables background keying/trimming, enables the 2×2 preview, and applies the seam pass.
- `--biome` selects a palette from `tools/palettes.json`.
- `--size 64` is the game tile size. Native generation is 1024×1024, so this is a 16× nearest downscale.
- `--colors` is a fallback for tiles without a palette. Palette-locked tiles use the palette size instead.
- Raw output is kept in `assets/raw/`; only the final 64×64 file is game-ready.

## Palette policy

- 16–21 colors per biome; sub-palettes for water, snow, beach, rock, salt, sulfur, coral, kelp, and boreal scrub.
- The palette is locked after quantization so every tile in a biome shares colors.
- `pixelize.py` fills all 256 Pillow palette slots by cycling the palette; padding with black previously pulled dark pixels.
- Hand-authored palettes must be sampled from the actual source; guessed olive palettes collapse the mossy grass.

## Seam policy

1. Downscale to the final 64×64 with nearest-neighbor.
2. Roll by half a tile so the original edges meet in the center.
3. Heal a 1-pixel band around the center cross.
4. Roll back.

The seam ratio should be below 1.0 (wrap edge differs less than the interior). Wide bands (6–10 px) leave a visible smeared cross; `--seam-band 1` is the approved setting.

`--model-seamless` uses ComfyUI-seamless-tiling circular padding. It produces truly tileable output but changes the style into repeating blobs; keep it off unless experimenting.

## Transitions

`tools/gen_transition.py` composites two existing tiles with a wavy, dithered mask. It uses exact source pixels, so palettes and texture match.

- Manifest: `tools/transitions.json`
- Output: `assets/tilesets/transitions/<a>_<b>/<a>_west|east|north|south.png`
- The filename names the side occupied by material `a`; the opposite side is `b`.
- Recommended: `--wave 9 --band 3 --scatter 8`, one seed per pair.
- Boundary-axis seam ratios are typically 0.4–0.85; no visible seams.

## Raw catalog

`tools/catalog_raw.py` reads ComfyUI PNG metadata, recovers seed and prompts, matches manifest seeds to final tiles, and rebuilds:

- `assets/raw/catalog.json`
- `assets/raw/contact_sheet.png`
- `assets/raw/README.md`

Current: 46 raw images, 35 promoted, 11 candidates. Candidates are valid source material for new variants.

## Quality checklist

- Tile reads as the intended material at 64×64, not just at 1024.
- Palette matches the rest of the biome.
- 2×2 preview has no visible seam or repeating blob.
- Water tiles contain no reef/sand colors that make them read as land.
- Snow shadows stay blue-gray, not near-black.
- Structures are isolated on transparency and have a dark 1-pixel outline.
- No manmade assets in uninhabited biomes.

## GPU note

RTX 4060 Laptop, 60 W cap. A 1024×1024 tile takes about 19–20 seconds at 99–100% utilization, 59.9 W, ~65 °C, and ~7.3 GB VRAM. It is compute-bound, not bandwidth-bound. 1536+ generation would spill to system RAM on this 8 GB card.

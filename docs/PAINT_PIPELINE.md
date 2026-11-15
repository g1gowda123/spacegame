# Painted cosmic plates — workflow and use

A second art language, deliberately **not** pixel art. Soft painted space for
story beats: the dispatch card when the spacecraft leaves, run-end cards,
title/menu backdrops. Gameplay keeps the 64 px tiles; these are full-bleed
plates with a caption, letterboxed, 2–3 s.

## Why a separate pipeline

The gameplay art is palette-locked and pixel-snapped. Painterly plates are the
opposite: continuous gradients, brush texture, no outline, no palette. Forcing
them through `pixelize.py` destroys the look; forcing the tiles into this look
destroys readability. So they live in their own directory and their own script.

## Where things live

- Output: `assets/backgrounds/painted/<scene>.png` — **640×360**, 16:9, RGB.
- Sources: `assets/raw/painted/<scene>.png` — 1344×768 SDXL render.
- Generator: `tools/gen_paint.py [scene ...]` (no arg = all scenes).

## Pipeline

1. SDXL 1344×768, `--lora 0` (no pixel-art LoRA — this is the whole point),
   34 steps, cfg 6.5, style suffix = "digital painting, soft cosmic atmosphere,
   deep indigo and violet nebulae with warm ember highlights, loose expressive
   brushwork … children's storybook illustration, no text, no letters".
2. Centre-crop to 16:9, upscale to 1280×720, `UnsharpMask(radius=3, percent=60)`,
   then LANCZOS to 640×360.
3. Add 1.1 σ grain. **Required** — a smooth 640 px gradient bands on the panel,
   the noise dithers it.

## Use

- Draw the plate full-bleed at 640×360 behind everything, then letterbox with two
  28 px black bars and centre the caption in the game's UI font, cream on the
  darker third of the frame.
- Fade in 0.4 s, hold 2.5 s, fade out 0.4 s; never animate the plate itself.
- Prefer plates whose lower third is dark — that is where text goes.

## Scenes

| id | beat |
|---|---|
| `dispatch` | spacecraft leaving a ringed planet — the dispatch moment |
| `nebula` | parting nebula wall lit from within |
| `blackhole` | accretion ring bending starlight |
| `sunrise` | sun cresting storm clouds, beams through the gap |
| `moon` | pale moon in a blue cloud sea, one meteor |
| `star` | single four-point star in violet field |
| `galaxy` | spiral galaxy at an angle |
| `ember` | rust-red banded gas giant |

## QA

- No people, no text, no frames — SDXL slips a tiny silhouette into wide shots;
  check each plate at 1:1 before shipping.
- Nothing in these plates contradicts the lore: worlds are lifeless except the
  general/grassy biome, so a figure standing on a ridge is a defect, not a mood.

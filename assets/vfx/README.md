# Animation FX art (`assets/vfx/`)

This folder is **animation art only** — sprites and sheets whose meaning is
time. Static terrain tiles, structures, ships and planet portraits belong to
VEGA in `assets/tilesets/`, `assets/props/` and `assets/sprites/`.

The game never requires these files: `scripts/vfx.gd` falls back to procedural
shapes and a 2D-dot texture. When a sheet exists, it is used automatically.

## Single-frame particles

| File | Size | Used by |
|---|---|---|
| `particle_dot.png` | 8×8 | generic dust/mist |
| `particle_spark.png` | 12×12 | impact sparks, crystal ambience |
| `particle_smoke.png` | 16×16 | dust puffs |
| `particle_ember.png` | 6×6 | volcanic ambience, overheat |
| `particle_snow.png` | 5×5 | cryo/ammonia ambience |
| `particle_spore.png` | 5×5 | temperate ambience |

## Frame sequences

Each sequence is `frame_00.png … frame_NN.png` (transparent RGBA, nearest,
played left to right at 20 fps by `VFX.frames_for()`), with entry size and
frame count in `manifest.json`.

| Folder | Frames | Size | Played as |
|---|---|---|---|
| `ring/` | 8 | 48×48 | expanding shockwave |
| `shield/` | 8 | 48×48 | hex shield block |
| `flare/` | 8 | 64×64 | impact burst (additive) |
| `smoke/` | 8 | 40×40 | dust-storm / debris puff |
| `smoke_puff/` | 8 | 40×40 | procedural fallback puff |
| `splash/` | 6 | 32×32 | water/regolith splash |
| `debris/` | 6 | 16×16 | kicked-up debris |

## Regenerating

```bash
# deterministic, no model
python3 tools/make_vfx_art.py

# diffusion source (ComfyUI on 127.0.0.1:8188)
python3 tools/gen_vfx_sheet.py --kind flare --seed 4201
python3 tools/gen_vfx_sheet.py --kind smoke --seed 4202
python3 tools/gen_vfx_sheet.py --kind ember --seed 4203
```

`tools/gen_vfx_sheet.py` keys the backdrop, downscales (64/40/12 px), palette-
posterises and derives the 8 motion frames in code. Graphs:
`tools/comfy_workflows/vfx_{flare,smoke,ember}.json`. Full contract:
`docs/VFX.md`.

## Rules

1. Hard pixel edges: no antialiased outlines at 1×.
2. Transparent outside the effect; effects are additive or normal-blended in
   code, so do not bake a background.
3. Warm/cool-neutral values only — `VFX` tints the same sheet per hazard or
   biome with `modulate`. Do not bake a specific hazard's colour into a sheet
   that other effects share.
4. Keep sheets small: 8 frames × 64² is the budget ceiling at 640×360.

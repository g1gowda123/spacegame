# VFX, animation and shader lane

Owner: **VFX agent** (animator / shader lane). Static tile, ship, planet and
structure art belongs to VEGA. This lane may author **animation art** (effect
sheets, particles, masks) and all shaders, and may wire effects into
`scripts/map_generator.gd` / `scripts/sector.gd`.

Claims are on `docs/BOARD.md`; this file is the technical contract.

## What is in the build

### Shaders

| File | Used by | What it does |
|---|---|---|
| `shaders/map_view.gdshader` | sector + map sandbox | Grade (W5 luminance floor), hue-only biome tint, per-biome exposure, water swell + caustics, lava emissive, ice twinkle, cloud drift, macro variation, grain. |
| `shaders/hazard_field.gdshader` | `sector.gd::_draw_hazards()` | Animated hazard footprint: armed pulse + diagonal warning tape + per-kind signature, dashed forming state, burn/ember scar state. |
| `shaders/star_drift.gdshader` | `space_backdrop.gd` (title, design, draft, debrief, report, crew, buff) | Slow plate drift, star twinkle, 1 px sparkles, faint nebula hue breath. |
| `shaders/space_backdrop.gdshader` | procedural deep-space plate (legacy / experiments) | Pure-procedural stars + nebula + small worlds; kept for reference. |

### Animation systems

| System | File | Notes |
|---|---|---|
| `VFX` helper library | `scripts/vfx.gd` | `ring`, `shockwave`, `sparks`, `dust`, `embers`, `shield`, `pickup`, `beam`, `flare_burst`, `sheet_burst`. All procedural; authored sheets preferred when present. |
| Hazard telegraph | `sector.gd` + `hazard_field.gdshader` | Per-kind motion: flare spokes, thermal convection, dust grit, seismic rings, radiation stipple, eclipse veil, cryo facets, wind streaks, meteor fall. Multi-cell fronts share one continuous field (UV = world tile coords). |
| Impact | `sector.gd::_impact` | Screen flash (0.20 peak), 2 px shake, additive flare sheet, shockwave ring, sparks, dust. Shield blocks use a hex bubble instead. |
| Pickup | `sector.gd::_collect_node_at` | Expanding ring, white shockwave, 9 sparks, three rising motes, float text. |
| Extraction | `sector.gd::_extract` | 0.45 s charge: vertical additive beam, ground ring, sparks, then the result overlay. |
| Overheat | `sector.gd::_check_overheat` | Rising embers, red shockwave, dust, damage float. |
| Landing pad | `sector.gd::_spawn_pad_beacon` | Looping radius/alpha pulse at the start cell so "return to the lander" is visible. |
| Movement | `sector.gd::_execute_path` | Per-cell `_animate_player()` tween + dust puff + banking rotation, then the camera pan. |
| Objective pickups | `map_generator.gd::_rebuild_actors` | Breathing marker, pulsing beam, orbiting scanner diamond. |
| Biome ambience | `map_generator.gd::_build_ambient` | Per-biome CPUParticles2D: snow (cryo/ammonia), embers (volcanic/sulfur/obsidian), mist (ocean/methane), sparkles (crystal), dust (arid/iron/barren/carbon), spores (temperate). Rebuilt per board. |
| Lander | `map_generator.gd::_process` | Idle hover bob + breathing contact shadow. |
| Sector planet | `sector.gd::_process` | Slow vertical drift on the backdrop planet. |

All effects are `CPUParticles2D` / `_draw()`-based. No new nodes in `.tscn`
files, no export dependency, GL Compatibility safe.

## QA hooks

```bash
# Play the whole effect reel once (impact → shield → pickup → extraction beam)
godot --path . -- --screen=sector --biome=temperate --fx=all

# One effect
godot --path . -- --screen=sector --biome=volcanic --fx=impact
#   impact | shield | pickup | extract | all

# Record it (Godot Movie Maker)
godot --path . --write-movie /tmp/opencode/vfx/fx.avi --fixed-fps 30 --quit-after 110 \
  -- --screen=sector --biome=cryo --fx=all
ffmpeg -i /tmp/opencode/vfx/fx.avi -vf fps=30 /tmp/opencode/vfx/f_%03d.png
```

Existing hooks still work: `--hurt`, `--collect`, `--moves=`, `--pathmove=x,y`,
`--result=success|fail`, `--capture`.

## Animation art pipeline

Procedural (no model, deterministic, always available):

```bash
python3 tools/make_vfx_art.py        # assets/vfx/*.png + sheets + preview.png
```

Diffusion (user runs ComfyUI; graphs are loadable from the UI):

| Graph | Element | Output |
|---|---|---|
| `tools/comfy_workflows/vfx_flare.json` | single impact burst on black | one 1024² source |
| `tools/comfy_workflows/vfx_smoke.json` | single smoke/dust puff on black | one 1024² source |
| `tools/comfy_workflows/vfx_ember.json` | single molten ember | one 1024² source |

```bash
# ComfyUI at 127.0.0.1:8188, sd_xl_base_1.0 + pixel-art-xl
python tools/gen_vfx_sheet.py --kind flare --seed 4201
python tools/gen_vfx_sheet.py --kind smoke --seed 4202
python tools/gen_vfx_sheet.py --kind ember --seed 4203
```

The script keys the backdrop, downscales to 64/40/12 px, palette-posterises and
derives the 8-frame motion in code (expand + collapsing core, billow + drift,
shrink + flicker). That is deliberate: SDXL draws one great effect shape far
more reliably than eight consistent sprite-sheet cells. `--source path.png`
lets the user pick any ComfyUI output without re-running the API.

VFX prefers `assets/vfx/flare/`, `assets/vfx/smoke/`, `assets/vfx/ember/`,
`particle_*` when present and falls back to the procedural art, so a missing
generation never breaks the game.

## Tuning knobs

| Knob | Where | Effect |
|---|---|---|
| `saturation`, `brightness`, `tint` | `map_view.gdshader` uniforms | shared grade |
| `exposure` | `BIOMES[*].exposure` in `map_generator.gd` | per-biome mid-tone normalisation |
| `biome_tint`, `biome_tint_strength` | `BIOMES` | hue-only tint (luma preserving) |
| hazard `intensity`, `kind`, `mode` | `sector.gd::_hazard_material` | per-front look |
| ambient colour/amount/speed | `_ambient_profile()` in `map_generator.gd` | biome atmosphere |
| flash peak / shake | `sector.gd::_impact` | hit feedback strength |

## Known gaps / next

- Screen-to-screen transition (paper slide / fade) is not wired; every screen
  still hard-cuts through `get_tree().change_scene_to_file`.
- Sector HUD gauges (heat bar, power pips) are still instant; the UI identity
  pass owns the widget refactor, so animation of those waits for U2/U4.
- No heat-haze refraction on volcanic boards yet (would need a screen-copy or a
  second texture; cost/benefit not justified at 640×360).
- `space_backdrop.gdshader` (procedural) is unused by screens; kept as the
  reference implementation for the raster plate's animated successor.

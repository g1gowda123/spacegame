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
| `shaders/star_drift.gdshader` | `space_backdrop.gd` (title, design, draft, debrief, report, crew, buff) + sector backdrop | Slow plate drift, star twinkle, 1 px sparkles, faint nebula hue breath. |
| `shaders/planet_view.gdshader` | planet portrait in `space_backdrop.gd` | Slow terminator, limb/atmosphere glow, specular; the static disc stays the art. |
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
| Screen arrival | `scripts/scene_fx.gd` (autoload `SceneFX`) | Watches `tree.current_scene` and fades every new screen in from black (0.24 s). No call-site changes; works for title/design/draft/sector/debrief/report/briefing/crew/buff. |
| Ship portrait | `scripts/ship_diagram.gd` | Engine glow flicker + red/green nav strobe on every hull, plus the existing live-module flicker/blink. The portrait redraws every frame. |

All effects are `CPUParticles2D` / `_draw()`-based. No new nodes in `.tscn`
files, no export dependency, GL Compatibility safe.

## QA hooks

```bash
# Play the whole effect reel once (impact → shield → pickup → extraction beam)
godot --path . -- --screen=sector --biome=temperate --fx=all

# One effect
godot --path . -- --screen=sector --biome=volcanic --fx=impact
#   impact | shield | pickup | extract | all
#   disaster | strike-miss | strike-turn | world | meteor | gust | devil

# Transfer-arc ship in the mission review
godot --path . -- --screen=draft --review

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
| `lift` | `_apply_biome_tint()` | gamma < 1 opens dark ash/basalt without clipping lava (volcanic/sulfur/obsidian 0.72, barren/iron/carbon 0.88) |
| `biome_tint`, `biome_tint_strength` | `BIOMES` | hue-only tint (luma preserving) |
| hazard `intensity`, `kind`, `mode` | `sector.gd::_hazard_material` | per-front look |
| ambient colour/amount/speed | `_ambient_profile()` in `map_generator.gd` | biome atmosphere |
| flash peak / shake | `sector.gd::_impact` | hit feedback strength |

## Known gaps / next

- Scene **fade-out** on the way out is still a hard cut: `SceneFX` only owns the
  arrival fade. A true cross-fade needs a `SceneFX.go(path)` wrapper at the ~30
  `change_scene_to_file()` call sites (coordinate with the UI owner).
- Sector HUD gauges (heat bar, power pips) are still instant; the UI identity
  pass owns the widget refactor, so animation of those waits for U2/U4.
- No heat-haze refraction on volcanic boards yet (would need a screen-copy or a
  second texture; cost/benefit not justified at 640×360).
- `space_backdrop.gdshader` (procedural) is unused by screens; kept as the
  reference implementation for the raster plate's animated successor.
- Ship portrait: module blocks could stagger in on install (one block per 40 ms)
  instead of the single flash; needs `ShipBuild` slot ordering.

## Disaster beat (end of turn)

`_end_turn()` calls `_resolve_hazard()` for **every** live front, not just a
front under the player. The return value plus `_last_strike_near` gates a
0.62 s hold, so the player registers the strike before the next telegraph
lands. Per strike:

- every footprint tile gets dust; the front centre gets flare/shockwave/sparks/
  debris/beam for a dodged or remote strike, and `_impact()` covers a hit;
- tiles within 6 of the player get a scar (`_add_scar(cell,color,3)`), capped at
  26 scars;
- a hit shows the dark `_disaster_banner()` with title `!! <HAZARD> STRIKE` and
  the damage line; a near miss shows `!! <HAZARD> SURGE` / `NO CONTACT ·
  GROUND SCARRED`;
- `_disaster_edge()` ramps the `screen_state` shader `flash` uniform (hazard
  colour) 1→0 over 0.55 s, and `_shake()` shakes 5 steps on a near miss.

QA: `--fx=disaster` (unblockable quake on the player), `--fx=strike-miss`
(adjacent quake), `--fx=impact`, `--fx=all`.

## World aliveness director

Runs from `sector.gd::_process` while the sector is live:

| Timer | Action |
|---|---|
| 2.2–4.4 s | `_world_event()`: authored structure signature (volcano smoke+embers, geyser steam, crystal/ice glints) or a biome micro-event (lava embers, water ring, ice sparks, dust devil, spores) |
| 7–12 s | `_meteor_event()`: `VFX.meteor_streak()` at a cell near the player (gradient streak, dust, sparks, ring; cosmetic) |
| 6–12 s | `_shooting_star()`: gradient streak across the sky |
| 11–18 s | `_gust_event()`: three staggered `VFX.wind_gust()` streak fronts cross the board |
| 0.9–1.6 s | `_smoke_scars()`: burned tiles puff smoke while their scar lives |

`VFX.dust_devil()` uses the `DevilNode` inner class: four rotating arcs plus
grit, drifting 18–36 px/s, 2.8 s life, sine fade. Ambient CPUParticles2D counts
were raised for weather presence: snow 62, embers 44, dust 48, spores 34,
crystal 24. The map shader sways green-dominant pixels ±1 px for grass/scrub.

## Transfer-arc ship (`scripts/transfer_ship.gd`)

Used by `draft.gd::_show_mission_review()` in the 270×112 transfer panel.
`TransferShip` builds a `Curve2D` through the arc points and samples it:
- 4.6 s smoothstep travel from Earth to target, 0.9 s hold, fade in/out at loop
  edges;
- comet trail (last 22 %), space-dust, cyan engine flare, launch ring, arrival
  ring;
- draws the selected hull sprite (`assets/sprites/ships/<id>.png`) at 32 px
  along the tangent; falls back to a golden delta if the hull art is missing;
- emits `progress_changed(u)`; the review shows `IN TRANSIT  N%`, then `ORBIT
  INSERTION`.

The same ship powers the **commit transition**: pressing COMMIT MISSION runs
`draft.gd::_play_commit_transit()` — a full-screen starfield with Earth, the
target, the transfer arc and the ship — then changes to the sector after 1.85 s.

Test: `godot --path . -- --screen=draft --review` (panel) and
`godot --path . -- --screen=draft --review --commit` (full transit).

## Installed-systems rack (`scripts/upgrade_strip.gd`)

The sector HUD keeps a persistent Risk-of-Rain-style icon rack on the left edge
(`Vector2(10, 52)`), so a paid refit or field commission cannot vanish into the
debrief once the next sector starts.

- One 22 px chip per unique id; duplicates stack into a single chip with an
  `xN` badge (`FIELD REPAIR KIT` is the repeatable one).
- Refits are square steel chips (amber border for FIRMWARE); field commissions
  get a warm corner notch and a rarity accent (common muted, rare sage, epic
  amber).
- Hover opens the shared Balatro dossier (`UIKit.hover_info` / `UITip`) with
  `desc`, plain-language `plain`, type and installed count.
- Chips **pop** in staggered at sector start, flash when a new id appears, and
  **pulse when their stat changes**: hull → integrity, fuel → `dv`, heat →
  `thermal_res`, data → `data_cap`, power → `power_regen` / `shield`. The
  mapping is driven by `_refresh_status()` diffing the last HUD values, not by
  call sites.
- A three-bar porthole under the rack (also `TAB` / `I` / any chip click) opens
  the **ARSENAL** sheet on `CanvasLayer` 55: every entry with icon, name, effect,
  count, grouped in columns; fade/scale in, `ESC`/`TAB`/`CLOSE`/backdrop exits.
- Hovering a **top-bar stat** (`INTEGRITY`, `DELTA-V`, `DATA`, `THERMAL LOAD`,
  `POWER`) lights every rack chip that feeds it, so "why is my hull 10?" points
  at the armor/commission hardware without opening six dossiers.
- QA: `--screen=sector --owned=rtg,armor,wheel --buffs=harden,reactor`,
  `--rack-tip=0` (pin one dossier), `--rack-highlight=integrity` (light the
  matching chips), `--arsenal` (open the sheet), `--rack-dump` (print entries).
  Capture evidence `/tmp/opencode/vfx/rack_tip.png`, `arsenal_final.png`,
  `rack_many.png`, `rack_hl.png`.

## Living title planet (`shaders/planet_view.gdshader` + `SpaceBackdrop`)

The home-screen disc is the only planet with motion; all other portraits stay
still so the UI reads as a document.

- `cloud_amount` / `cloud_speed`: a low-contrast fbm cloud layer with latitude
  banding, drifting horizontally; compressed at the limb by the disc mask.
- `turn_amount`: rotates the surface **sampling** around Y and reprojects
  (`n2 = rotateY(n)`), so baked markings slide across the disc while the
  terminator and sphere normal stay fixed. Oscillates ±0.18 rad instead of
  wrapping, because the source PNG only has the near hemisphere.
- `SpaceBackdrop` sway: ±0.02 rad over a 74 s period, pivot at the disc centre.
- Enable only from `title.gd`:
  `configure({"planet_clouds": 1.0, "planet_turn": 1.0, "planet_sway": 1.0})`.
  Defaults are 0, so split-screen/draft/debrief portraits are unaffected.
- QA: `--screen=title` and capture at 1 s / 8 s / 15 s; the crater pattern and
  cloud bands must differ between frames with no transparent holes.

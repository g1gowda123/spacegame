# Exoplanet Tileset Library

Art assets for **Orbit & Outplay: Mission Architecture Roguelite**. No game code.

## Scope

- **Base terrain tiles:** 64x64, seamless when repeated.
- **Transition tiles:** one 64x64 band per material pair, four orientations.
  Enough for straight boundaries; no 47-tile ocean/river blob sets.
- **Multi-tile structures:** 128x128 (2x2) or 192x192 (3x3), transparent
  background, overlaid on the terrain.
- **Water:** base water depths + a beach/shore ring around authored lakes and
  craters. Full ocean/river autotiling is **out of scope** for a bounded
  tactical map.
- **Rivers:** only if a mission mechanic needs them. If so, add a small kit
  (straight, corner, T, cross, source, mouth) instead of a coastline blob set.

## Palette locking

`tools/palettes.json` holds one 16-21 colour palette per biome, plus reusable
sub-palettes (`water_fresh`, `water_deep`, `beach`, `rock`, `snow`, `hardware`).
Every tile in a biome is mapped onto the same palette, so unrelated tiles still
look like they belong together. Sub-palettes are subsets of the biome palette.

```bash
python tools/gen_asset.py "subject" --out path.png --size 64 --biome arid --tile
```

`--biome` fills `--palette` and `--colors` from the JSON.

## Seams

Tiles are downscaled first, then healed with `pixelize.py --tile --seamless
--seam-band 1`: roll by half, heal a 3 px cross, roll back. The healed cross
becomes the new wrap edge, so repetition is continuous without smearing the
texture.

Measured wrap ratio (seam edge difference / average interior difference):

- all 19 ground tiles: **0.20 - 0.74** (below 1.0 = no visible seam)
- all 15 transition tiles: **0.41 - 0.85** along the repeating edge

Do **not** use a wide band (8+ px): it leaves a visible soft cross. The
optional `--model-seamless` flag uses circular-padding nodes for mathematically
tileable output, but it changes the style into repeating blobs; keep it as an
experiment, not the default.

## Transition tiles

`assets/tilesets/transitions/<a>_<b>/` contains four files named by the side
material **A** occupies:

| File | A occupies | B occupies |
|---|---|---|
| `<a>_west.png` | west half | east half |
| `<a>_east.png` | east half | west half |
| `<a>_north.png` | north half | south half |
| `<a>_south.png` | south half | north half |

Each tile is a one-cell-wide band: 64 px of A blending into 64 px of B. It is
seamless along the boundary axis, so it repeats cleanly along a shore or flow.
The blend is a wavy, dithered mask composited from the two diffusion tiles, so
colours and texture stay exact. Current softness defaults: `--band 5`,
`--scatter 10`, `--wave 12` (lead decision 01:47 — transitions must not read as
a hard cut).

Pairs live in `tools/transitions.json`. Regenerate all:

```bash
python tools/gen_transition.py --all
```

**Coverage.** Every material pair that can touch inside any of the 13 biomes has
a set: `tools/transitions.json` lists **98 pairs** and all 98 directories exist.
Check at any time with:

```bash
python tools/audit_transitions.py        # exit 1 + list when something is missing
python tools/audit_transitions.py --fix  # append missing pairs to transitions.json
```

`--fix` only registers the pair; run `gen_transition.py --a A --b B --seed N`
(seed = `crc32(a|b) % 100000`, as the bulk run used) to produce the art.
cracked_earth/rock, snow/ice, snow/rock, shallow/deep water,
shallow/reef, reef/beach.

Not yet generated: corner pieces and three-way junctions. Straight edges cover
the mission-map layouts; add corners only if a map needs them.

## Current tiles

| Biome | Tile | Size | Seed | Palette | Status |
|---|---|---|---|---|---|
| temperate | grass | 64 | 21 | temperate | final |
| temperate | dirt | 64 | 151 | temperate | final |
| temperate | rock (mossy) | 64 | 152 | temperate | final |
| temperate | beach | 64 | 132 | beach | final |
| temperate | water_lake | 64 | 141 | water_deep | final |
| arid | sand | 64 | 111 | arid | final |
| arid | cracked_earth | 64 | 153 | arid | final |
| arid | rock (red) | 64 | 191 | arid | final |
| cryo | snow | 64 | 154 | snow | final |
| cryo | ice | 64 | 155 | cryo | final |
| cryo | rock | 64 | 192 | cryo | final |
| volcanic | lava | 64 | 102 | volcanic | final |
| volcanic | basalt | 64 | 156 | volcanic | final |
| volcanic | ash | 64 | 157 | volcanic | final |
| ocean | water_shallow | 64 | 351 blend | ocean | final (2026-11-14, calm) |
| ocean | water_deep | 64 | 158 (re-authored by derivation) | water_deep | final 2026-11-14: calm large-scale mottling, no coral-dither |
| ocean | reef | 64 | 159 | ocean | final |
| ocean | beach | 64 | 193 | beach | final |
| barren | regolith | 64 | 160 | barren | final |
| temperate | moss | 64 | 201 | temperate | final |
| temperate | mud | 64 | 202 | temperate | final |
| arid | dunes | 64 | 203 | arid | final |
| arid | salt_flat | 64 | 204 | arid | final |
| arid | dry_river | 64 | 205 | arid | final |
| cryo | glacier | 64 | 206 | cryo | final |
| cryo | snow_forest | 64 | 207 | cryo | final |
| cryo | frozen_lake | 64 | 208 | cryo | final |
| volcanic | obsidian | 64 | 209 | volcanic | final |
| volcanic | sulfur | 64 | 210 | volcanic | final |
| volcanic | pumice | 64 | 211 | volcanic | final |
| ocean | coral | 64 | 302 | ocean_coral | final (2026-11-14) |
| ocean | kelp | 64 | 341 | ocean_kelp | final (2026-11-14) |
| barren | rock | 64 | 214 | barren | final |
| barren | dust | 64 | 322 | barren_dust | final (2026-11-14) |

Water-dominant palettes `ocean_coral` and `ocean_kelp` keep underwater tiles
reading as water first; the coral/kelp accents are the minority of the pixels.
`barren_dust` is a warm tan palette: the earlier barren palette turned the dust
tile into blue-gray cracked stone.

## Structures

| Structure | Footprint | Seed | Palette | Notes |
|---|---|---|---|---|
| habitat_dome | 128 (2x2) | 113 | hardware | transparent, outlined |
| mountain_range | 128 (2x2) | 802 | temperate | teal-gray ridge mass, shadow-free, no plinth (2026-11-14) |
| comms_dish | 128 (2x2) | 173 | hardware | transparent, outlined |
| lander | 128 (2x2) | 164 | hardware | transparent, outlined |
| solar_farm | 128 (2x2) | 172 | hardware | opaque panel field |
| solar_array | 128 (2x2) | 182 | hardware | transparent, single deployable panel |
| volcano | 192 (3x3) | 174 | volcanic | transparent caldera, overlay |
| impact_crater | 192 (3x3) | 672 | hardware | rebuilt 2026-11-14 via `make_prop.py`; needs centre anchor |
| mesa | 128 (2x2) | — | arid | transparent |
| iceberg | 128 (2x2) | 702 | cryo | alien ice spire, rebuilt 2026-11-14 |
| geyser | 128 (2x2) | 692 | hardware | alien geothermal vent, rebuilt 2026-11-14 |
| coral_spire | 128 (2x2) | 805 | ocean_coral | vertical coral spire, shadow-free, no plinth; not yet used by any biome mapping |
| crystal_outcrop | 128 (2x2) | 671 | hardware | rebuilt 2026-11-14 (was a full-frame texture) |
| ridge_wide | 192x128 (2x2) | — | temperate | three overlapping, jittered `mountain_range` peaks composed into one continuous ridge; shadow-free (2026-11-14) |
| crystal_spire | 128 (2x2) | 905 | crystal ramp | violet faceted spire, shadow-free (2026-11-14) |
| sandstone_arch | 192 (3x3) | 911 | arid | natural arch, interior punched with `make_prop.py --key-interior` (2026-11-14) |
| glacier_wall | 128 (2x2) | 913 | cryo | short blue ice wall block (2026-11-14) |
| canyon_bridge | 192 (3x3) | 906 | arid | rust-red natural rock bridge (2026-11-14) |

## Edge and feature tiles

- **Cliffs** — `assets/tilesets/<biome>/cliffs/cliff_<low|mid|high>_<n|e|s|w>.png`,
  60 tiles for temperate / arid / cryo / volcanic / barren. Built by
  `tools/make_cliff.py` from the biome's **ground** tile (plateau) plus its
  **rock** tile (wall, darkened with a vertical falloff, striated, lit rim on
  the cliff-top edge, dark 1 px foot line). Regenerate with
  `make_cliff.py --rock <rock.png> --ground <ground.png> --biome <b> --outdir assets/tilesets/<b>/cliffs`.
- **Rivers** — `assets/tilesets/<biome>/rivers/` (temperate, arid, volcanic),
  16 pieces each: `straight_ns|ew`, `bend_ne|es|sw|wn`, `tee_nes|esw|swn|wne`,
  `cross`, `source`, `mouth`, `shallow_ns|ew`, `ford`. `tools/make_river.py`
  builds them from a distance-field channel mask; the composite is not
  re-locked, because locking to the ground palette flattens the water.
- **Algorithm ground / exotic identities** — 60 derived tiles via
  `tools/make_variants.py` (`--list` for the recipe keys, `--only`, `--all`):
  `arid/{dunes_ripple,dune_crest,sand_plateau}`, `volcanic/{lava_core,ash_rim,basalt_shelf}`,
  `cryo/{ice_plate,crack}`, `barren/{crater_rim,ejecta}`, `ocean/{reef_chain,sand_cay}`,
  plus six each for methane, iron, crystal, ammonia, obsidian, carbon, sulfur.
  Derived tiles are transformations of the biome's own base tile, never a tint
  of another biome.

## Planets and the space plate

- `assets/sprites/planets/<biome>.png` (256) and
  `assets/sprites/planets/sector/<biome>.png` (512) are **procedural**, not
  diffusion: `tools/make_planet.py --biome <b> --size 256|512`. The tool builds
  a seamless surface from an explicit ramp (`RAMPS`), projects it on a sphere
  with one light, adds limb darkening and a thin lit atmosphere, and
  palette-locks. Continents/sea ratio is per biome (`SEA_FRAC`); barren/carbon/
  obsidian get crater bowls, cryo/temperate/ammonia get polar caps, methane is
  a banded gas giant.
- `assets/backgrounds/space.png` (640x360) is `tools/make_space.py`: navy
  gradient, one faint nebula wash, ~210 stars, no planet.

## Props

Small, non-blocking set dressing, 64x64, transparent, bottom-anchored so the
sprite sits on its cell. Built with `tools/make_prop.py`, which isolates one
object from a diffusion sheet, keys the backdrop **and** a model-painted drop
shadow, palette-locks it and adds a 1 px outline. Art is **shadow-free by
default** (`--shadow` defaults to 0, lead decision 01:47): the renderer draws the
one contact ellipse. Pass `--shadow 1` only if a deliberate baked shadow is
wanted.

```bash
/home/g1/ComfyUI/.venv/bin/python tools/make_prop.py \
  assets/raw/sprite_00091_.png \
  --out assets/props/boulder.png --size 64 --biome temperate \
  --outline 16,20,14 --fill 0.80
```

| Prop | Biome | Seed | Notes |
|---|---|---|---|
| boulder | temperate | 601 | teal-lichen alien rock |
| shrub | temperate | 611 | bulbous blue-green succulent |
| dead_bush | arid | 621 | ochre spiked alien growth |
| ice_chunk | cryo | 631 | pale crystal shards |
| lava_rock | volcanic | 642 | charred rock with ember seams |
| barren_rock | barren | 651 | rounded gray stone |
| coral_shard | ocean | 681 | bleached alien coral shard (wired in `PROPS["ocean"]`) |
| obsidian_shard | obsidian / iron | 741 | grey glass shard, alien fracture planes (needs wiring) |
| sulfur_nodule | sulfur / volcanic | 742 | mineral nodule cluster with orange crystal specks (needs wiring) |
| shell_spiral | crystal / ammonia | 952 | 48 px alien spiral shell |
| crystal_nub | crystal / obsidian | 954 | 48 px three cyan crystal nubs in dark rock |
| ice_teeth | cryo / ammonia | 955 | 48 px jagged pale ice teeth |
| ash_mound | volcanic / barren | 956 | 48 px porous ash rock with ember specks |

Props are **alien, not earthly**: crystalline, bulbous, spined or glowing forms.
Only the general/grassy planet has vegetation; every other biome is lifeless
apart from rare mineral/ice/debris dressing.

Raw generations live in `assets/raw/`; each output folder has a
`manifest.jsonl` with the exact prompt, seed and settings.

## Regenerate a tile

```bash
cd /home/g1/godot/nasa

# terrain tile (seamless, palette-locked)
/home/g1/ComfyUI/.venv/bin/python tools/gen_asset.py \
  "lush green grass field, chunky grass clumps, dark green gaps between blades" \
  --out assets/tilesets/temperate/grass.png \
  --size 64 --biome temperate --seed 21 --tile

# 2x2 structure (transparent, outlined)
/home/g1/ComfyUI/.venv/bin/python tools/gen_asset.py \
  "pressurized habitat dome with cyan glass windows and orange warning lights" \
  --out assets/tilesets/structures/habitat_dome.png \
  --size 128 --biome hardware --seed 113 --bg auto --outline 13,17,23
```

## Notes

- Terrain: no background key, no trim, no outline.
- Structures: background key + trim + black outline.
- Pixel Art XL is tuned for an 8x nearest downscale (1024 -> 128) or 16x
  (1024 -> 64); keep the ratio integral.
- ComfyUI runs at `http://127.0.0.1:8188` on the RTX 4060. The 60 W laptop power
  cap is the reason the fan stays quiet; generation is still GPU-bound (100%
  utilisation, ~20 s per 1024 tile).

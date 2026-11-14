# Engine tuning (map / survey)

The map generator is meant to be tuned from the Godot Inspector, not by editing
the generator body. Open `scenes/map_generator.tscn` (or any scene that
instances it), select the root, and use the exported groups.

## Inspector groups

| Group | Parameters | Effect |
|---|---|---|
| **Render Window** | `view_w`, `view_h` | Tiles rendered around the lander. Bigger = more survey visible, more SubViewport work. Defaults are WebGL-friendly. |
| **Map / Seed** | `randomize_seed`, `seed_value`, `biome_index` | Turn `randomize_seed` off to reproduce the inspector seed. `biome_index` selects the biome directly. |
| **Camera / View** | `view_mode`, `circle_view`, `zoom`, `tilt`, `circle_radius`, `circle_soft`, `circle_outer` | Dimetric/isometric/top view, zoom, and the circular survey horizon/fog skirt. |
| **Fog / Survey** | `fog_enabled`, `fog_reveal_radius`, `fog_alpha_inner/mid/outer`, `fog_desat` | Toggle the default fog of war, its reveal radius, the three readability bands, and how much colour survives under the veil. CLI `--no-fog` still wins. |
| **Decals** | `decal_density`, `decal_cluster_threshold`, `decal_scale_min/max`, `decal_alpha` | W4 scatter. Density is a candidate rate; the noise gate forms clusters. |
| **Terrain Shader** | `edge_mode`, `relief_enabled` | `0` off, `1` accepted W1 dither, `2` smooth-tint A/B; `relief` is the W3 prototype and is off by default. |

## Where the data lives

- **Biomes** are the `BIOMES` array near the top of `scripts/map_generator.gd`:
  generator family, base/detail/rock/shore/water keys, `exposure`, `tint`,
  `shore_ring`, `cliffs`, `occlusion`.
- **Structures** are the `STRUCTURES` dictionary: footprint, sprite, scale,
  piece set, occlusion, ground flag.
- **Transition coverage** is `tools/transitions.json`; missing pairs are ignored
  and reported by `tools/water_probe.gd --diagcheck`.
- **Decal allow-lists** are `assets/tilesets/decals/manifest.json`.
- **Noise frequencies/seeds** are grouped in `_init_noise()` so a biome can be
  re-seeded without touching the shader or composition code.

## CLI equivalents

Useful for reproducible screenshots without opening the editor:

```bash
godot --path . --scene res://scenes/map_generator.tscn -- \
  --capture --seed=48394 --biome=temperate --view=iso

# A/B flags
--no-fog  --smooth-edges  --no-soft-edges  --relief  --legacy-water
```

## Rule of thumb

If a value changes *how every board plays* (window size, fog, density, biome
selection), expose it in an Inspector group and keep a CLI override. If it is a
one-off art placement, keep it in the art manifest.

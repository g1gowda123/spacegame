# Internal Status — Orbit & Outplay

**Not for judges.** The public, presentable version is the [README](../README.md)
"Five-minute showcase". This file is the working picture: what is in the tree,
what is in the package, who owns what, and what is still missing.

Last updated: 2026-11-15 02:05 (ECHO).

## Build vs source

| | |
|---|---|
| Source | playable end to end, native Godot; headless boot exits 0 with no parser/runtime errors |
| Packaged build | `build/web/` 54 MB, ZIP `submission/orbit_outplay_web.zip` 24 MB — **one pass behind the tree** |
| Missing from the package | survey fog + signal tiers, animated hazard shaders, V5 effect library, W6 outcrop set |
| Fix | one `tools/release.sh` run, then the browser loop (title → report, zero console errors) |

Do not demo the ZIP until it is re-exported; demo native (`godot --path .`) or re-export first.

## Done vs in flight

| Workstream | State | Where it lives |
|---|---|---|
| Run loop, economy, scoring, report | **Done** | `scripts/game_state.gd`, `scenes/` |
| Exoplanet data + derived hazards | **Done** | `data/exoplanets.json`, `tools/build_exoplanets.py` |
| Crew, difficulty tiers, daily seed, share codes | **Done** | `scripts/crew_director.gd` |
| Mission Architecture Review + briefing | **Done** | `scenes/briefing.tscn`, `docs/BRIEFING.md` |
| 13-biome terrain, transitions, structures | **Done** | `scripts/map_generator.gd`, `assets/tilesets/` |
| Animated hazards + effect library | **In tree, not packaged** | `shaders/hazard_field.gdshader`, `scripts/vfx.gd`, `docs/VFX.md` |
| Fog of war + signal-tier nodes | **Prototype, default on** | `docs/MAP_GAMEPLAY.md` (M1/M4), `--no-fog` |
| W6 hero/support outcrops | **Art landed, wiring in progress** | `assets/tilesets/outcrops/` |
| UI identity pass (folders/cards/stamps) | **Kit delivered, integration open** | `docs/UI_REDESIGN.md`, `assets/ui/skin/` |
| Music bed (3 context loops + 9 biome beds) | **Done, in tree** | `assets/music/`, `scripts/music_director.gd`, `docs/AUDIO.md` §5.2 |

## Who is doing what

| Who | Job | Right now |
|---|---|---|
| **ATLAS** | engine and map | terrain reads as land, wire new rocks, volcano corners |
| **VEGA** | art | hero rocks, planets, UI skin, ship art |
| **NOVA** | game design | fog-of-war survey loop, crew/difficulty tuning, rubric fit |
| **b** | terrain algorithms | coastlines, water bodies, reachability audits |
| **VFX agent** | animation and shaders | animated hazards, lighting grade, effect library |
| **c / d** | build and QA | one-command export, browser test loop |
| **e** | data and words | NASA numbers, README, deck, project page |
| **f** | feel | sound effects, HUD polish, overlay readability |
| **ECHO** | music | 3 context loops + 9 per-biome beds shipped; phase-locked handover |

## What needs to happen next

**P0 — before the next review:**

1. **Re-export and re-QA the web build.** `tools/release.sh`, then the browser loop title → report with zero console errors. Without this the fog/VFX work is invisible in the ZIP.
2. **Music bed.** Shipped: three 68.6 s context loops (title / sector / debrief) plus nine per-biome sector beds, all −16 LUFS, 2.75 MiB total, handover phase-locked (drift ≤0.05 s). Remaining: re-master `title`/`debrief` to −16.0 LUFS to remove the last 0.9 dB step; re-encode `sector.ogg` (−0.60 dBTP, over the ceiling). Details in `docs/AUDIO.md` §5.1–5.3.
3. **Volcano silhouette.** Each 4×4 volcano still occupies a narrow tower inside its ash square, so the corners read empty. Art-shape rework, not a wiring bug.

**P1 — the visible quality gap:**

4. **UI identity integration (U2–U4).** The 9-slice folder/card/stamp kit exists; it needs `UIKit` helpers and screen passes.
5. **W2 macro composition.** The remaining reason the board reads tiled: terrain is composed per cell. Generator-level change (`docs/MAP_OVERHAUL.md`); biggest visual win left.
6. **Survey choice + terrain cost (M2/M3).** Sample vs. deep scan, rock costs 2, water/lava blocks.

**P2 — polish:**

7. Scene transitions and HUD gauge animation (V6), volcanic heat haze (V7).
8. Return-weight rule (M6), structure-scale acceptance review, extra outcrop silhouettes.
9. README/deck refresh once the packaged build matches the tree (`e` lane).

## Known gaps (say them before a judge finds them)

- The packaged build is one pass behind the tree (fog, VFX, outcrops).
- No soundtrack yet; SFX only. Biggest remaining feel gap; plan written.
- The map still has per-cell composition artifacts at 2×. W2 is the fix.
- VFX/UI work is additive polish; the playable loop, data pipeline and scoring are done and verified.
- Scores are local only (best score + daily best). No server, no account, by design.

## Verify

```bash
godot --headless --path . --quit-after 8        # parse/runtime smoke
godot --path .                                 # newest code
tools/play_web.sh                             # packaged build on :8061
```

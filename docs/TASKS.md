# Task Board — Orbit & Outplay

The map-generator-only scope in the previous board is **superseded**. The user's brief (m00001) asks for a complete Space Mission Design Game prototype, and that is what shipped.

## Done — playable prototype

| Area | State | Notes |
|---|---|---|
| Title screen | done | Starfield, ringed planet, best score, How to Play overlay |
| Mission design | done | 4 hulls, 3 launch vehicles, 4 objectives, 6 instruments, live 6-bar telemetry, budget + fairing validation |
| Real-exoplanet data | done | 72 curated `pscomppars` planets, derived hazards, biome classification, `mass_est` flag |
| 3-planet draft | done | Biome-first planet colors, Teq/gravity/distance detail line, target selection |
| Surface sector | done | Chunked alien terrain, one-move-per-turn path planning with range preview, Δv/sol/thermal/power/integrity/data resources, end-of-turn telegraphed hazards, HOLD, EXTRACT |
| Hazards | done | Flare, thermal surge, dust storm, quake, radiation, eclipse, cryo; blockable via power |
| Debrief + shop | done | Success/failure review, science/grant/approval, 3-offer refit with stacking modules |
| Campaign report | done | Grade C–S, category breakdown, sector ledger, narrative, educational notes |
| Web export | done | `build/web/`, threadless WebGL 2, ~52 MB, static-host friendly |
| End-to-end play | verified | Native and browser: title → design → draft → sector → debrief ×3 → report |
| Docs | done | README, PROJECT, SUBMISSION, WORKLOG, data/formula table |

## Gameplay depth sprint (ATLAS, 12:04)

| Task | Status | Notes |
|---|---|---|
| Relay Survey objective | done | Every 2nd sector plants 3 relay beacons; amber mast markers, `RELAYS` HUD, relay-specific debrief/result copy. Web-tested at sector 2. |
| Mission Architecture Review | done | Pre-commit overlay: transfer arc, four NASA segments, CML, ConOps timeline, orbit readout. Screenshot `qa_engine_review3.png`. |
| Between-sector event cards | done | 8-card seeded pool, two trade-offs each, applied to budget/approval/next-sector heat/dv/power/sols/integrity/science. Web-tested through choice. |
| Hazard growth pre-state | done | New fronts render faint and do not fire for one turn; HUD says `FORMING · ARMS NEXT TURN`. Verified live. |
| Risk bonus | done | Extract with a live front within 2 tiles for +1 risk point, cap 2/run; report includes `RISK n` when earned. |
| Report grade gap | done | Final ledger shows `NEXT +N TO GRADE X` or `S GRADE · MAXIMUM`. |

## Remaining — submission pass (as of 03:15)

| Task | Status | Notes |
|---|---|---|
| Final Web re-export | done | 11:31, `build/web/` ~52 MB; report overflow fixed, final CML/analog/orbit content included, demo/deck re-rendered from the new frame |
| 30-second demo video | done | `demo/orbit_outplay_demo.mp4`, 29.6 s, 1280×720, 1.9 MB |
| 7-slide deck (alternative) | done | `demo/orbit_outplay_deck.pdf`, exactly 7 slides; visual QA passed |
| Project-page copy | done | `docs/SUBMISSION.md`: name, summary, description, NASA data, SI, references, shot list |
| Success path | verified | Native success overlay: DATA 4/4, quota 3, +$202M, +16 approval; full success report grade A / 5015 |
| Failure path | verified | Native + browser: 3 failed sectors → grade C / 195; no page errors |
| Browser success run | optional | Native success path shares `GameState.finish_sector`; browser report plumbing verified on the failure run |
| Host / submit | action for user | Upload `submission/orbit_outplay_web.zip` to itch.io/GitHub Pages, or any static host; attach video or deck |
| Ship portraits | done | 07:47 (tiles): all four `assets/sprites/ships/*.png` rebuilt as true side profiles via new `tools/make_ship.py`; verified 190×70 with 43–74% transparency. Re-export still needed to ship them. |
| Visual debt | optional | Sector terrain still has rectangular lake edges on some seeds; playable and readable, but the one remaining art-polish item |
| Gameplay depth pass | done | 07:10: one-move-per-turn path planning, 3–4 tile range, Ion Thruster +1, end-of-turn hazards, node-biased telegraphs; native + Web verified. ZIP/video/deck refreshed. |

### Submission package

`submission/` contains the static game ZIP, the 29.6 s video, the 7-slide deck, and the project-page copy. The game ZIP is just `build/web/`; no server-side code.

## Standing constraints

- Godot 4.7.2, GDScript, GL Compatibility, WebGL 2.
- 640×360 logical viewport; `stretch/aspect="keep"`; nearest filtering.
- No new runtime dependencies in the Web build.
- Archive values are real; derived game values must stay documented in README.
- Keep the pixel-art look; do not replace procedural terrain with flat placeholders.

## Map visual debt (lead-maintained, 03:30 — the surface renderer is NOT "done" until these land)

The surface renderer is functionally complete: 13 biomes, palette-locked 64 px tiles, 98 transition pairs, corner matching, props, structures, minimap, telegraphed hazards. Remaining visual debt — more than one item; the submission must not overclaim:

| # | Item | Notes |
|---|---|---|
| 1 | Shoreline roughness is uniform | **DONE+VERIFIED 06:55/07:30 (primary, lead-verified).** `rough_noise` (seed+4703, freq 0.045) low-freq mask: `jag = lerpf(0.015, 0.155, smoothstep(-0.30,0.30,rough))`. Evidence `/tmp/opencode/jag2_29607.png` — clean stretches alternate with frayed patches. |
| 2 | Small right-angle water spurs | **Wiring DONE 10:29 (primary):** `diag|<land>|<water>|<corner>` in `_build_tileset()`, `_pattern_data()` prefers the diagonal when a land cell has exactly one water corner. **Remaining (lead 10:45): generator-side water fragmentation** — lake-heavy archetypes are full of 1-2-tile islands/holes where diagonals can't help; coalesce water bodies so the diagonal trigger fires naturally. Evidence target: one Lake District + one ocean frame. |
| 3 | Deep-water coral-dither fill | **DONE 06:58 (tiles).** `ocean/water_deep` re-authored as a calm dark ramp derived from the smoothed shallow tile (4 shades `0c2230 103446 15485d 1c6075`, large-scale mottling, no coral dither); 11 dependent transition sets regenerated. Evidence `/tmp/opencode/evidence_water_deep.png`. |
| 4 | Legacy structures `mountain_range` + `coral_spire` | **DONE 06:59 (tiles), VERIFIED GOOD 07:30 (lead, tile+map scale).** Regenerated shadow-free/plinth-free via `gen_asset.py --no-pixelize` + `make_prop.py --shadow 0`: `mountain_range` seed 802 (teal-gray ridges, 128, 37% clear), `coral_spire` seed 805 (vertical coral spire, 128, 70% clear). Evidence `/tmp/opencode/evidence_mountain_range.png`. **LEAD DECISION 07:30: wire `coral_spire` to OCEAN (do not drop it)** — primary owns the `scripts/map_generator.gd` biome mapping. |
| 5 | Anti-RPG-maker verification | Round-8 shader grain accepted in principle; verify on a full frame that macro forms still dominate and the map reads distinct, then compare against user's "generic RPG Maker" complaint. **Partial pass 08:10 (lead): temperate full frame (sky_43255.png) reads alive/distinct. Remaining: one exotic-biome confirmation (crystal/iron — 02:47 audit showed stair-step rubble + monotony).** |

Items 1-4 are concrete art/code passes; item 5 is the acceptance gate. No gameplay work is needed for them.

**Assignments (lead, 03:40):** primary → items 1-2 (code-side: roughness variance mask, then diagonal split / sub-cell water mask) + one final re-export after all art passes. tiles agent → item 3 (regen the ocean water ramp: calm the deep fill, larger-scale mottling, palette-locked per tools/palettes.json) and item 4 (shadow-free plinth-free regens of `mountain_range` + `coral_spire`, using the 02:56 mesa/volcano template; 128/192 footprints, isometric orientation). Both: post evidence frames in /tmp/opencode and log in WORKLOG; lead verifies.

**Export status (11:31):** `build/web/index.pck` (14 MB) and `submission/orbit_outplay_web.zip` (21 MB) are refreshed after the report-layout fix; the extracted ZIP was re-tested through title → design → draft → sector with 0 console/page errors. The 11:20 art families (cliffs, rivers, exotic ground, ridge, landmarks) are **not wired** into `map_generator.gd` and remain inert extras; do not claim they are visible in game.

## ATLAS current pass (11:55)

| Task | Status | Notes |
|---|---|---|
| Per-world terrain tuning | in progress | Ocean now solid beach islands + reef fringes (`archipelago` offset + `temperate/beach` cores), volcanic `lava_glow`, crystal profile, arid dune/cracked detail in `scripts/map_generator.gd`; evidence `/tmp/opencode/worlds_seed5_sheet.png`, `/tmp/opencode/world_ocean.png`. No export/push. Remaining: shoreline stair-steps, arid mesa repetition, crystal quietness. |

## Gameplay depth sprint — ATLAS claim (12:25)

| Task | Status | Notes |
|---|---|---|
| Relay-survey objective | done | Verified sector 2: `RELAYS 0/3`, amber markers, `/tmp/opencode/relay5.png`; `RELAYDBG` removed. |
| Between-sector event choice | done | `event_card` declared; modal shows two choices; `--event-choice=0` resolves and applies budget; `event_capture.png`. |
| Hazard growth pre-state | verified | Sector capture shows `FORMING: SEISMIC · ARMS NEXT TURN`; `age=0` path active. |
| Risk bonus | verify | `_risk_bonus_nearby()` + `risk_points` cap already implemented. |
| Grade-gap line | done | Pre-existing `NEXT +%d TO GRADE %s` in `report.gd`; duplicate removed; no new label needed. |

## Art requests — tiles agent (on standby)

The tiles/art agent stays online and polls this file every ~6 minutes. To request art, add a row to the table below (do not edit `assets/` yourself) and the agent will claim it.

| # | Asset path | Size / contract | Brief | Status |
|---|---|---|---|---|
| 1 | `assets/tilesets/transitions/diagonal/` | 64×64, 20 PNGs | Four diagonal split tiles (`nw/ne/se/sw`) per water/land pair: `temperate/water_lake`, `ocean/water_shallow`, `ocean/water_deep`, `volcanic/lava`, `carbon/water`. Water occupies the named half-cell, 1 px shore band + 1 px dark water edge, no baked shadow. | `DONE` 10:10 — 20 tiles in `assets/tilesets/transitions/diagonal/` + `tools/make_diagonal.py`; wiring pending (primary) |
| 2 | `assets/tilesets/{temperate,ocean,volcanic,cryo}/water_*` | 64×64, 9 PNGs | Shallow/deep/foam variants: `temperate/water_lake_shallow`, `water_lake_deep`, `water_foam`; `ocean/water_shelf`, `water_foam`; `volcanic/lava_crust`, `lava_glow`; `cryo/ice_cracked`, `ice_thin`. Palette-lock to each biome. | `DONE` 10:10 — 9 tiles deployed, `water_lake` also re-authored calm; wiring pending (primary) |
| 3 | `assets/tilesets/{temperate,arid,cryo,volcanic,barren}/cliffs/` | 64×64, 60 PNGs | 3 heights × 4 directions × 5 palettes. 2–3 px top lip, dark base line, no baked cast shadow; shader owns light. | `DONE` 10:55 — `assets/tilesets/<biome>/cliffs/cliff_<low|mid|high>_<n|e|s|w>.png` via `tools/make_cliff.py` (ground+rock composite); wiring pending (primary) |
| 4 | `assets/tilesets/{temperate,arid,volcanic}/rivers/` | 64×64, 48 PNGs | 16-piece auto-tile per palette: straight ×2, bend ×4, T ×4, cross, source, mouth, shallow edge ×2, ford. 1 px bank each side. | `DONE` 11:20 — 48 tiles in `assets/tilesets/{temperate,arid,volcanic}/rivers/` via `tools/make_river.py`; wiring pending (primary) |
| 5 | `assets/tilesets/{biome}/` (algorithm ground) | 64×64, 18 PNGs | Ground identities exposed by the new generators: `arid/dunes_ripple`, `arid/dune_crest`, `arid/sand_plateau`; `volcanic/lava_core`, `volcanic/ash_rim`, `volcanic/basalt_shelf`; `cryo/ice_plate`, `cryo/crack`; `crystal/prism_plate`, `crystal/shard_field`; `barren/crater_rim`, `barren/ejecta`; `ocean/reef_chain`, `ocean/sand_cay`; `sulfur/acid_pool`, `sulfur/vent`; `obsidian/glass_plate`, `ammonia/slush`. | `DONE` 10:55 — all 18 tiles in their biome folders via `tools/make_variants.py`; wiring pending (primary) |
| 6 | `assets/tilesets/exotic/<biome>/` | 64×64, 42–56 PNGs | Six non-tinted forms each for methane, iron, crystal, ammonia, obsidian, carbon, sulfur (see `docs/TILE_REQUESTS.md` §5). | `DONE` 11:20 — 42 tiles (6 per biome) in `assets/tilesets/{methane,iron,crystal,ammonia,obsidian,carbon,sulfur}/` via `tools/make_variants.py`; wiring pending (primary) |
| 7 | `assets/tilesets/structures/` | 128/192, 8 PNGs | Natural landmarks: sandstone arch, hoodoo cluster, glacier wall, geyser field, crystal spire, canyon bridge, methane vent, basalt columns. Transparent, no plinth/shadow. | `PARTIAL` 11:20 — `sandstone_arch`, `glacier_wall`, `crystal_spire`, `canyon_bridge` done; hoodoo cluster / geyser field / methane vent / basalt columns still open (diffusion keeps returning fields of the object, or a disc plinth) |
| 8 | `assets/tilesets/props/` | 32–64, 30–36 PNGs | Optional small accents: bones, shells, vents, cracks, tufts, ice teeth; 6 per base biome, alien not earthly. | `PARTIAL` 11:36 — `shell_spiral`, `crystal_nub`, `ice_teeth`, `ash_mound` (48 px, shadow-free) done; bones/vents still open (diffusion returns bone *fields* or manmade braziers) |
| 9 | `assets/backgrounds/space.png` | 640×360 opaque PNG | Very dark deep-space plate for the tactical board: near-black navy, sparse tiny stars, one faint violet/blue nebula wash. No planet, moon, sun, spacecraft, text, or large bright cloud banks; white HUD text must stay readable. Replace current crop only if it is visibly cleaner. | `DONE` 10:30 — `tools/make_space.py` seed 7 deployed (640×360, 210 stars, faint nebula) |
| 10 | `assets/tilesets/structures/ridge_wide.png` | 192×128 RGBA, 2×2 footprint | One continuous isometric mountain ridge/massif, cooler gray-blue rock, chunky pixel clusters, grounded organic foot. No plinth, no baked shadow, no detached contact oval. Intended to replace the repeated 1.55× `mountain_range` 2×2 chain for temperate/barren. | `DONE` 10:55 — `assets/tilesets/structures/ridge_wide.png` (192×128, 23 % clear, three overlapping jittered peaks); needs `STRUCTURES` entry (primary) |
| 11 | `assets/sprites/planets/sector/` | 512×512, 13 PNGs | Larger versions of the 13 biome planet portraits for the sector backdrop: same composition/colour language as `assets/sprites/planets/<biome>.png`, perfect circular disc, transparent outside the disc, no ring/shadow/text. | `DONE` 10:30 — all 13 at `assets/sprites/planets/sector/` from `tools/make_planet.py` (procedural sphere, same seed/ramps as the 256 set) |
| 12 | `assets/sprites/planets/{arid,barren,methane}.png` | 256×256 RGBA, circular disc | Clean round discs for the three weakest draft portraits: arid ochre with dark canyon bands; gray cratered barren with readable crater contrast at 96 px; methane teal gas giant with subtle horizontal bands. | `DONE` 10:30 — arid/barren/methane regenerated with the whole 13-planet procedural set (barren has real crater bowls, methane has warped bands) |
| 13 | `assets/props/relay_beacon.png` | 64×64 RGBA prop | Relay beacon for the RELAY SURVEY objective: tripod, mast, cyan lens, antenna; shadow-free. | `DONE` 12:38 — procedural, 85.7 % clear; needs ATLAS to place it on beacon tiles |

Standing rules for the tile/prop pipeline: shadow-free art (renderer owns the contact ellipse), palette locked via `tools/palettes.json`, 64 px tiles / 128 or 192 px structures, raws under `assets/raw/`, and a WORKLOG line when a file lands.

## MISSION CONTROL design pass (NOVA, 12:35)

Designer lane; additive UI + small rule hooks. No map/terrain work, no `debrief.gd` edit (ATLAS event UI in flight).

| Task | Status | Notes |
|---|---|---|
| Crew Mode 1–4 (roles, buffs, conflicting goals, handoff overlay) | claimed by NOVA | New `scripts/crew_director.gd` autoload + `scripts/crew.gd` + `scenes/crew.tscn`; goals scored in report |
| Difficulty tiers (Cadet / Standard / Director) | claimed by NOVA | Budget, approval, hazard count, heat, score multiplier |
| Daily Challenge + campaign share/import code | claimed by NOVA | Deterministic seed; title daily best; report code; paste in Mission Control |
| Draft risk tags (SAFE / BALANCED / HARSH) | claimed by NOVA | Derived from each planet's archive numbers; no new data |
| Design rationale + rubric traceability doc | claimed by NOVA | `docs/DESIGN.md` |

### MISSION CONTROL — complete (NOVA, 12:56)

| Task | Status | Evidence |
|---|---|---|
| Crew Mode 1–4 (roles, buffs, conflicting goals, handoff overlay) | **DONE** | `crew5.png` (2-player manifest), `qa_design.png` / `qa_draft.png` / `qa2_sector.png` / `qa4_debrief.png` (handoff banners), `qa_report3.png` (3/4 goals, +540) |
| Difficulty tiers (Cadet / Standard / Director) | **DONE** | Meta probe: Director + 3-crew → `delta_v 27` (30+3−planet), `integrity 5/5`, `science ×1.10`, `hazard_mod 1`, `heat_gain 6`, `budget 85` after design; report row `DIFFICULTY x1.25 +1471` |
| Daily Challenge + campaign share/import code | **DONE** | `qa_daily_a.png` and `qa_daily_b.png` byte-identical (MD5 `532b20f8…`); code `OO-043AF-D3` round-trips to seed 17327 / director / 3 players; `qa2_report.png` shows daily header + code |
| Draft risk tags (SAFE / BALANCED / HARSH) | **DONE** | `qa_draft.png`: threat 20 / 36 / 85 with green/amber/red tags |
| Design rationale + rubric traceability doc | **DONE** | `docs/DESIGN.md`; README + PROJECT + SUBMISSION cross-links updated |
| Nil-`run` crash guard (ORION 12:45 urgent) | **DONE** | `scripts/crew_director.gd` guards `crew_players()`, `goal_rows()`, `code_for_run()`, `note_report_score()`; headless smoke `--quit-after 8` = 0 error lines; title/design/draft/sector/debrief/report all parse clean |
## f — Feel pass (claimed 12:00)

| # | Task | Status | Notes |
|---|---|---|---|
| 1 | Reachable-cells overlay crispness | **DONE + VERIFIED 12:10** | `scripts/sector.gd` now strokes only the union perimeter of the visible reachable set (`REACH_SIDES`, `_cell_corner`); per-cell lattice removed, union fill 0.055, hazard cells keep a red wireframe, path + target markers unchanged. Evidence `/tmp/opencode/f_reach_before.png` → `f_reach_after.png`; hazard-in-reach `f_reach_after_t9_hazard.png`; 2× crops `f_reach_*_crop.png`. **Biome sweep (12:09):** 6 native sector captures — temperate/rock, barren regolith and ocean/shallow water all keep the contour readable, including cyan-on-teal water. Sheet `/tmp/opencode/f_try_sheet.png`, full-size `/tmp/opencode/f_reach_try6_ocean.png`. 0 errors. |
| 2 | Sector audio audit + headless leak regression check | **DONE 12:02** | Board premise corrected: three WAVs exist — `click.wav` 0.055 s, `confirm.wav` 0.180 s, `alarm.wav` 0.420 s (44.1 kHz mono 16-bit). Current cues: buttons click, screen/design/debrief-success confirm, hazard/overheat/failure alarm, shield/HOLD click; **move commit and cursor move are silent**. Headless exit on title/design/draft/sector/debrief/report is clean (no ObjectDB or resource warnings) — 02:56 fix has not regressed. Logs `/tmp/opencode/f_headless_*.log`. |
| 3 | Minimal SFX set | **PROPOSED 12:06 — awaiting ORION** | Core: `move`, `extract`, `hazard`, `tick`. Optional: `deny`, `shield`, `node`. Code-only prerequisite: 4-voice player pool so cues do not cut each other. **No audio files added** per the 11:40 directive; see BOARD 12:06 for the scope request. |

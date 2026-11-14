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
| Hazards | done | Nine: flare, thermal surge, dust storm, seismic shock, radiation belt, eclipse shadow, cryo quake, solar-wind front (sweeping line), meteor shower; blockable via power |
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
| Visual debt | optional | Sector terrain still has rectangular lake edges on some seeds; playable and readable, but the one remaining art-polish item. **Generator side addressed 13:46 (b):** rect lake edges were 1–2-cell water bodies plus missing shore-pair diagonals; see debt item 2. Needs a Web re-export to ship (ORION/ATLAS gate). |
| Gameplay depth pass | done | 07:10: one-move-per-turn path planning, 3–4 tile range, Ion Thruster +1, end-of-turn hazards, node-biased telegraphs; native + Web verified. ZIP/video/deck refreshed. |

### Submission package

`submission/` contains the static game ZIP, the 29.6 s video, the 7-slide deck, and the project-page copy. The game ZIP is just `build/web/`; no server-side code.

## Copy & data lane — e (claimed 12:20)

| Task | Status | Notes |
|---|---|---|
| Claim audit: README / PROJECT / SUBMISSION vs code | done | 12:30. Fixed stale data + feature claims: curated radius range (0.69–2.19 R⊕, not 0.35), playable vs terrain-only biomes, hazard list (9, not 7), approval math, quota/extract/auto-sweep rule, controls (V, H), mission bars wording. File:line evidence in WORKLOG 12:30. |
| Repeatable data/copy validator | done | `tools/audit_data.py`: rebuilds the dataset from the raw CSV, recomputes every `game.*` value, checks the event schema/effect contract, and asserts the doc counts/ranges. 28 checks, 0 failed; run `python tools/audit_data.py`. |
| Event cards (8, seeded between-sector choices) | shipped (ATLAS inline pool); docs reconciled | Shipped: `scripts/game_state.gd:391-456` (`const EVENTS`, 8 cards x 2 options), selection at `:786`, apply at `:809`; modal in `scripts/debrief.gd:301-370`. `data/events.json` is a prototype no game file loads. `docs/EVENTS.md` §2 now lists the shipped pool and §6 the mismatches. |
| Gameplay-depth copy pack (relay, events, growth, risk, grade gap) | shipped; pack reconciled | `docs/COPY_DEPTH.md` §0 records the live strings. Relay (`sector.gd:405-511`), FORMING (`sector.gd:466-479`), risk (`finish_sector:974-979`, report `:194-203`), and next-grade gap (`report.gd:114-122`) are all in the build. Not shipped: report `DECISIONS` line, onboarding widget. |
| Onboarding hint card copy (first sector) | content done — widget still pending ATLAS | Three-line copy in `docs/EVENTS.md` §5. No widget exists in `scripts/`. Do not promise H/F10 in-sector: `sector.gd:1453 _unhandled_input` does not call the parent. |
| Copy/code mismatch list for ATLAS | done (re-verified against merged tree) | `docs/EVENTS.md` §6, 12 items: eclipse drains instead of restoring power (`sector.gd:45,1221,1226`); debrief hard-codes `ORBIT LOW` (`:139`); title "3 of 4" (`title.gd:134`); H/F10 dead in-sector (`sector.gd:1453`); radiator -3 vs `thermal_res: 6`; `data_cap` display-only; repair kit no-op; inline-vs-JSON event pool; missing DECISIONS line; superluminal transfer-arc duration; `>` used as a separator; relay/3-of-4 README scope. |
| E1 — Submission copy | done | `docs/PROJECT_PAGE.md` (project page, crew/difficulty/daily story) + `docs/DECK_NOTES.md` (7-slide speaker notes). Local upload copy `submission/project_page.md` (gitignored). |
| E2 — In-game science wording review | done | One consolidated list for ATLAS: `docs/EVENTS.md` §6. Includes the two number/phrasing issues a judge could challenge (transfer-arc `distance_ly / 4.0` years = ~4c; `Teq ... > heat ...` reads as "greater than"). |
| E3 — Onboarding + event tone pass | copy done; widget blocked | Onboarding copy final `docs/EVENTS.md` §5. Tone pass on all 8 shipped cards in `docs/EVENTS.md` §7 (title length, sign consistency, label verbs). |

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
| 2 | Small right-angle water spurs | **Wiring DONE 10:29 (primary):** `diag|<land>|<water>|<corner>` in `_build_tileset()`, `_pattern_data()` prefers the diagonal when a land cell has exactly one water corner. **Generator side DONE 13:46 (b):** `scripts/water_shaper.gd` coalesces water bodies before the tile grid (3×3 vote, chunk-seam-safe; Lake District 26758 water bodies 3 → 0, tiny water 3 → 0, perimeter/area −6 %). Missing shore-pair diagonal art added (6 sets), reversed pair-order lookup fixed, and water materials given the water priority so ocean corners resolve: coverage temperate 235/235, methane 80/80, carbon 106/106, ocean 181/181, 0 missing. Evidence `/tmp/opencode/b_review/{coast_26758_ab,ocean_prio_ab}.png`, `survey_final.ndjson`, `diag_landed.ndjson`. Remaining: three-way junctions still fall back to 90° `outer` tiles. |
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
| Risk bonus | done | Extract with a live front within 2 tiles for +1 risk point, cap 2/run; report includes `RISK n` when earned. |
| Grade-gap line | done | Pre-existing `NEXT +%d TO GRADE %s` in `report.gd`; duplicate removed; no new label needed. |

## b — generator: water shaping + diagonal coverage (claimed 13:20, done 13:46)

Direct answer to debt item 2 and to ORION's 10:45 directive (“attack the generator side: water-body scale”). **ATLAS no longer needs to implement the water-coalescing pass** — the algorithm, the wiring and the missing diagonal art are in the tree; what remains is ATLAS's own art wiring (cliffs/variants/ridge/rivers) plus the one export.

| Item | State | Notes |
|---|---|---|
| Water coalescing | done | `scripts/water_shaper.gd`: local 3×3 vote (1 pass, land→water at ≥0.60 wet, water→land at ≤0.40), applied between `_sample_terrain()` and `_smooth_cell()`. Raw halo 1 → 2 cells. `shore_ring` biomes only; lava stays authored. Chunk-seam-safe by construction (component filters are not — see the review in BOARD). |
| A/B switch | done | `--legacy-water` restores the pre-coalescing shoreline for same-seed captures; `--water=<r>,<p>,<wet>,<dry>` overrides the knobs. |
| Diagonal coverage | done | Six shore pairs had no 45° art, so **100 % of corner cells fell back to right-angle tiles**. Composited with VEGA's own maths (`tools/make_diagonal_gd.gd`, a Godot port of `make_diagonal.py` — this machine has no numpy): `temperate_beach_temperate_water_lake`, `ocean_beach_ocean_water_deep`, `ocean_reef_ocean_water_shallow`, `ocean_reef_ocean_beach`, `cryo_glacier_ocean_water_deep`, `barren_rock_ocean_water_deep`. `_build_tileset()` registers the land-first diagonal key for water-first pairs too. |
| Water priority | done | Last 47 ocean corner cells were **not** missing art: `ocean/water_shallow` is `base`, so it carried priority 1 and lost single-corner cells to `ocean/beach` (shore, 3). `_priority_map()` now gives every `BLOCKED` water tile priority 5. Ocean 134→181 of 181 corners diagonal; temperate/methane/carbon unchanged at 100 %. A/B frame shows no coastal regression. |
| Final coverage | done | Probe `--diagcheck --chunks=5`: temperate 235/235, methane 80/80, carbon 106/106, ocean 181/181 — 0 missing on all four. |
| Measurement tool | done | `tools/water_probe.gd` (pre-existing, extended): fragmentation, water fraction, perimeter/area, corner cells, diagonal selection **per material and per pair**, fallback-key histogram, and the clean-vs-frayed split by `rough_noise`; `--legacy` and `--chunks=N` added. |
| Evidence | done | Numbers + captures in `docs/WORKLOG.md` 13:46; probe JSON and sheets in `/tmp/opencode/b_review/` (`diag_landed.ndjson`, `ocean_prio_ab.png`, `coast_26758_ab.png`). |
| Reviewer | ORION | b posted the review on the board; VEGA may hand-tune the six composite sets, they are deterministic recombinations and can be regenerated in one command. |

## c — build/release: one-command release (claimed 17:50)

Direct answer to **C2** on the board. The gate keeps going stale because the export, the ZIP, the hash list, the serve test and the "what shipped" stamp all live in different heads and different chat messages. `tools/release.sh` is the single command that does the whole chain and refuses to leave a fresh-looking artifact behind when it fails.

| Item | State | Notes |
|---|---|---|
| `tools/release.sh` (claim command) | done | `bash tools/release.sh` = preflight -> export -> artifact check -> headless boot smoke -> package -> sha256 -> HTTP smoke serve -> `build/RELEASE.txt`. Flags: `--skip-export`, `--no-serve`, `--no-smoke`, `--strict`, `--port N`, `--godot PATH`; env `GODOT`, `PORT`, `PYTHON`. |
| Stale-artifact rule | done | The ZIP **and** `build/RELEASE.txt` are deleted before the export runs and only re-created after it succeeds, so a failed run cannot leave an old "RELEASE OK" next to no ZIP. `build/web` is wiped before export for the same reason. |
| Exit codes | done | 0 ok, 1 usage/preflight (incl. no engine), 2 export or boot-smoke failure, 3 `build/web` incomplete, 4 packaging failure, 5 serve failure, 6 `--strict` and a submission asset predates the PCK. |
| Portable python | done | Picks `python3` then `python` and *runs* it (`import sys,zipfile`) instead of trusting `command -v`; the Windows `python3` App Execution Alias exists but is not an interpreter. `PYTHON=` overrides. Packaging uses `zipfile` (no `zip` binary needed). |
| Asset stamp audit | done | Every `submission/*` and `demo/*` file is compared against the PCK mtime and flagged `STALE` in `build/RELEASE.txt`; `--strict` turns that into exit 6. This is the mechanism that would have caught the 11:31 deck/video against the 14:45 build. |
| Verification | done (stub engine) | `bash -n` clean; 10-case stub matrix, all PASS: happy path (5-entry ZIP, 3x HTTP 200, stamp written), `--skip-export`, export failure -> 2 (ZIP + stamp absent), empty export -> 3, boot `SCRIPT ERROR` -> 2, `--strict` -> 6, bad option -> 1, `--help` -> 0, missing engine -> 1. ZIP re-checked: `testzip()` None, no dot-files, identical sha256 on rerun. |
| Not verified here | blocked | This Windows box has no Godot and no `build/`, so the real export path and the real `--quit-after 8` smoke are untested; run it once on the Linux box (`/home/g1/godot/nasa`) and paste the `RELEASE OK ...` line. |

## Art requests — tiles agent (on standby)

The tiles/art agent stays online and polls this file every ~6 minutes. To request art, add a row to the table below (do not edit `assets/` yourself) and the agent will claim it.

| # | Asset path | Size / contract | Brief | Status |
|---|---|---|---|---|
| 1 | `assets/tilesets/transitions/diagonal/` | 64×64, 20 PNGs | Four diagonal split tiles (`nw/ne/se/sw`) per water/land pair: `temperate/water_lake`, `ocean/water_shallow`, `ocean/water_deep`, `volcanic/lava`, `carbon/water`. Water occupies the named half-cell, 1 px shore band + 1 px dark water edge, no baked shadow. | `DONE` 10:10 — 20 tiles in `assets/tilesets/transitions/diagonal/` + `tools/make_diagonal.py`; wiring pending (primary) |
| 2 | `assets/tilesets/{temperate,ocean,volcanic,cryo}/water_*` | 64×64, 9 PNGs | Shallow/deep/foam variants: `temperate/water_lake_shallow`, `water_lake_deep`, `water_foam`; `ocean/water_shelf`, `water_foam`; `volcanic/lava_crust`, `lava_glow`; `cryo/ice_cracked`, `ice_thin`. Palette-lock to each biome. | `DONE` 13:45 — wired `WATER_BANDS` in `_render_terrain_world()`; evidence `water2_ocean.png` / `water2_temperate.png` |
| 3 | `assets/tilesets/{temperate,arid,cryo,volcanic,barren}/cliffs/` | 64×64, 60 PNGs | 3 heights × 4 directions × 5 palettes. 2–3 px top lip, dark base line, no baked cast shadow; shader owns light. | `DONE` 10:55 — `assets/tilesets/<biome>/cliffs/cliff_<low|mid|high>_<n|e|s|w>.png` via `tools/make_cliff.py` (ground+rock composite); wiring pending (primary) |
| 4 | `assets/tilesets/{temperate,arid,volcanic}/rivers/` | 64×64, 48 PNGs | 16-piece auto-tile per palette: straight ×2, bend ×4, T ×4, cross, source, mouth, shallow edge ×2, ford. 1 px bank each side. | `DONE` 11:20 — 48 tiles in `assets/tilesets/{temperate,arid,volcanic}/rivers/` via `tools/make_river.py`; wiring pending (primary) |
| 5 | `assets/tilesets/{biome}/` (algorithm ground) | 64×64, 18 PNGs | Ground identities exposed by the new generators: `arid/dunes_ripple`, `arid/dune_crest`, `arid/sand_plateau`; `volcanic/lava_core`, `volcanic/ash_rim`, `volcanic/basalt_shelf`; `cryo/ice_plate`, `cryo/crack`; `crystal/prism_plate`, `crystal/shard_field`; `barren/crater_rim`, `barren/ejecta`; `ocean/reef_chain`, `ocean/sand_cay`; `sulfur/acid_pool`, `sulfur/vent`; `obsidian/glass_plate`, `ammonia/slush`. | `DONE` 10:55 — all 18 tiles in their biome folders via `tools/make_variants.py`; wiring pending (primary) |
| 6 | `assets/tilesets/exotic/<biome>/` | 64×64, 42–56 PNGs | Six non-tinted forms each for methane, iron, crystal, ammonia, obsidian, carbon, sulfur (see `docs/TILE_REQUESTS.md` §5). | `DONE` 11:20 — 42 tiles (6 per biome) in `assets/tilesets/{methane,iron,crystal,ammonia,obsidian,carbon,sulfur}/` via `tools/make_variants.py`; wiring pending (primary) |
| 7 | `assets/tilesets/structures/` | 128/192, 8 PNGs | Natural landmarks: sandstone arch, hoodoo cluster, glacier wall, geyser field, crystal spire, canyon bridge, methane vent, basalt columns. Transparent, no plinth/shadow. | `DONE` 13:35 — all 8: `sandstone_arch`, `glacier_wall`, `crystal_spire`, `canyon_bridge`, plus `hoodoo_cluster`, `geyser_field`, `methane_vent`, `basalt_columns` (the last four composed from primitives / existing sprites, not diffusion); wiring pending (ATLAS) |
| 8 | `assets/tilesets/props/` | 32–64, 30–36 PNGs | Optional small accents: bones, shells, vents, cracks, tufts, ice teeth; 6 per base biome, alien not earthly. | `PARTIAL` 13:48 — 34 accents: `shell_spiral`, `crystal_nub`, `ice_teeth`, `ash_mound` + 30 `accent_<biome>_<crack|vent|tuft|shell|bones|ice_teeth>.png` via `tools/make_accent.py`; wiring pending (ATLAS) |
| 9 | `assets/backgrounds/space.png` | 640×360 opaque PNG | Very dark deep-space plate for the tactical board: near-black navy, sparse tiny stars, one faint violet/blue nebula wash. No planet, moon, sun, spacecraft, text, or large bright cloud banks; white HUD text must stay readable. Replace current crop only if it is visibly cleaner. | `DONE` 10:30 — `tools/make_space.py` seed 7 deployed (640×360, 210 stars, faint nebula) |
| 10 | `assets/tilesets/structures/ridge_wide.png` | 192×128 RGBA, 2×2 footprint | One continuous isometric mountain ridge/massif, cooler gray-blue rock, chunky pixel clusters, grounded organic foot. No plinth, no baked shadow, no detached contact oval. Intended to replace the repeated 1.55× `mountain_range` 2×2 chain for temperate/barren. | `DONE` 10:55 — `assets/tilesets/structures/ridge_wide.png` (192×128, 23 % clear, three overlapping jittered peaks); needs `STRUCTURES` entry (primary) |
| 11 | `assets/sprites/planets/sector/` | 512×512, 13 PNGs | Larger versions of the 13 biome planet portraits for the sector backdrop: same composition/colour language as `assets/sprites/planets/<biome>.png`, perfect circular disc, transparent outside the disc, no ring/shadow/text. | `DONE` 10:30 — all 13 at `assets/sprites/planets/sector/` from `tools/make_planet.py` (procedural sphere, same seed/ramps as the 256 set) |
| 12 | `assets/sprites/planets/{arid,barren,methane}.png` | 256×256 RGBA, circular disc | Clean round discs for the three weakest draft portraits: arid ochre with dark canyon bands; gray cratered barren with readable crater contrast at 96 px; methane teal gas giant with subtle horizontal bands. | `DONE` 10:30 — arid/barren/methane regenerated with the whole 13-planet procedural set (barren has real crater bowls, methane has warped bands) |
| 13 | `assets/props/relay_beacon.png` | 64×64 RGBA prop | Relay beacon for the RELAY SURVEY objective: tripod, mast, cyan lens, antenna; shadow-free. | `DONE` 13:36 — wired into `map_generator` relay markers; fallback mast/dish retained |
| 14 | `assets/tilesets/structures/pieces/` | 64×64 modules | Modular landform pieces: massif 4×4, volcano 4×4, ridge 2×1, ridge foot, 2 parallax ridges, manifest of offsets. | `DONE` 15:20 — 35 pieces + `manifest.json` + assembled previews via `tools/make_structure_pieces.py`; ATLAS unblocked |

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
| 3 | Minimal SFX set | **DONE 12:22** | Core cues implemented via new `tools/make_sfx.py`: `move.wav` (0.130 s, peak 0.379) + `hazard.wav` (0.260 s, peak 0.706), 44.1 kHz mono 16-bit, no external samples. `GameState.sfx()` gained `move` (−4 dB) and `hazard`; `alarm.wav` now reserved for failure. 4-voice round-robin player pool removes cue cut-offs. Remaining proposal (`extract`, `tick`, `deny`, `shield`, `node`) stays parked. |
| 4 | Juice: hazard-hit shake (2 px) | **DONE 12:22** | `_impact()` shake retuned from ±3 to ±2 (4 steps, 0.035 s each + 0.06 s settle) per sprint item 5. |
| 5 | Juice: 0.12 s white pickup flash | **DONE 12:22** | New `_pickup_flash()` reuses the full-screen `_impact_flash`: white, 0.18 peak, 0.02 s in / 0.12 s out; called from both pickup paths. Evidence `/tmp/opencode/f_pickup_flash_sheet.png` (mean luma 66.0 → 37.9 over 6 frames) and movie `f_juice60.avi`. |
| 6 | Juice: idle lander bob | **DONE 12:22** | `sector.gd::_process` drives `player_sprite.offset.y` with a 1.4 s sine, ±6 texture px, eased to zero while moving/ended — independent of the move tween on `position`. Evidence `/tmp/opencode/f_bob_sheet.png`; wing Y drifts 89.4 → 94.8 movie px across the cycle. |
| 7 | Juice: move tick + hazard thud SFX | **DONE 12:22** | Move tick fires once per committed path (`_execute_path`); thud fires on hazard hit and overheat (`_resolve_hazard`, `_check_overheat`, legacy `_try_move`). QA hook `--collect` added for the pickup flash/sound. Headless title/design/draft/sector/debrief/report clean (`/tmp/opencode/f_headless_juice.log`). |

## Open — audio (posted 12:48)

| Task | Status | Notes |
|---|---|---|
| Music bed — Balatro-style reactive loop | **CLAIMED — ECHO** (15:00) | 3 seamless OGG loops on a shared tempo (title / sector / debrief, report reuses debrief), 2 s crossfade on screen change, duck ~6 dB while a hazard telegraph is live. One `MusicDirector` autoload, headless early-return, ≤3 MB total. Spec, model choice, prompts and seam/LUFS acceptance in `docs/AUDIO.md`. Blocked on user approval for the 3.46 GB Stable Audio 3 Small-Music download; nothing generated yet. |

| Shareable **full design** code (loadout import) | **DONE** | `OO-01156-S2-PAVMOLOA-SPTH` round-trips to seed 4438 / Standard / 2 players / Pathfinder / Vector M / Low / Characterize Atmosphere / Spectrometer + Thermal; short `OO-xxxxx-S1` codes still work |
| Design-screen header overlap fix | **DONE** | `MISSION DESIGN // 01 · STEP 1 OF 3` is now one line; the old step label was being covered by the panels (`qa_director3.png`) |

## ECHO — music lane (claimed 15:00)

`docs/AUDIO.md` is the lane doc: research verdict, engine matrix, prompt recipes,
loop-mastering contract, runtime contract, hardware reality.

| Task | Status | Notes |
|---|---|---|
| ComfyUI soundtrack research | **DONE 15:00** | Verdict: yes for source material, no for finished loops. SA3 wins instrumental quality + tempo/key adherence (61% / 64% vs ACE at chance); ACE wins songs/vocals/MIT. Numbers and sources in `docs/AUDIO.md` §1–2. |
| Engine choice (SA3 Small-Music primary) | **DONE 15:00** | 3.46 GB total, 100 BPM / A minor / 32-bar loops (76.8 s), −16 LUFS, OGG q3 ≤ 2.8 MB. Decision rationale in §2. |
| SA3 Small-Music download | **BLOCKED — needs user OK** | 2.27 GB checkpoint + 1.19 GB t5gemma; disk fine (124 GB), RAM tight (~1.3 GB available). Do not start without approval. |
| `tools/make_music_loop.py` | **TODO** | Bar-aligned trim, wrap-around crossfade, two-pass loudnorm, numeric seam check, OGG q3 + JSON sidecar. Contract §5. |
| Generate + master 3 cues | **TODO** | Prompt recipes §4. Post seam delta / LUFS / true peak for each. |
| `MusicDirector` autoload | **TODO** | §6 contract; headless safe; owns the duck hook. |
| Web export + size check | **TODO** | ≤3 MB music growth in `build/web` and the submission ZIP. |

## Structure scale & grandeur pass (NOVA request, 13:38)

Boss: "big mountains are almost the same size as the craft… make the world feel grand." Full spec: `docs/STRUCTURE_SCALE.md`.

| Task | Status | Owner | Notes |
|---|---|---|---|
| Stopgap scale hierarchy: lander 1.15→0.66, mountain/mesa/volcano/iceberg scale up, overlay z 12→22 | **DONE 13:36** | NOVA | `scripts/map_generator.gd`; evidence `scale_*_grand.png`; provisional, ATLAS owns final tuning |
| 64 px structure piece set (peak/shoulder/foot, volcano cone/flank/apron, ridge crest/foot) + previews | **REQUESTED** | VEGA | `assets/tilesets/structures/pieces/`, palette-locked, no plinth/shadow, manifest offsets |
| Multi-tile `pieces` schema + alpha-bbox footprint fit + per-piece z-sort | **REQUESTED** | ATLAS | Collision must match visible base; overhang ≤1 tile |
| Wire the 60 existing cliff tiles to raised terrain edges | **REQUESTED** | ATLAS | Cheapest verticality win; `cliff_<height>_<dir>` already on disk |
| Density retune for bigger footprints (fewer, larger landforms) | **REQUESTED** | ATLAS / b | Suggested: major landforms ≤25% of walkable cells per chunk |
| Connectivity guarantee after structure placement (flood fill to objectives/extract, carve a pass) | **REQUESTED** | b / ATLAS | Must hold over 100 seeds per biome |
| Optional parallax ridge silhouettes behind the diamond | **REQUESTED** | VEGA | 640×120 transparent, dark, low contrast |
| Acceptance review: lander ≤1 tile, mountain ≥4× craft, no walkable cell under a solid peak | **PENDING** | NOVA | Full frames per biome + headless smoke |

## Dynamic ship build (NOVA, 15:03)

Boss: the ship should update automatically from the upgrades received after a planet.

| Task | Status | Owner | Notes |
|---|---|---|---|
| `ShipBuild` slot model from instruments + `GameState.owned` | **DONE 15:02** | NOVA | `scripts/ship_build.gd`; payload/refit slots, tiers, short names |
| Live `ShipDiagram` module drawing + buy flash | **DONE 15:03** | NOVA | `scripts/ship_diagram.gd`; integer-aligned pixel blocks, per-hull accent, clipped to the portrait |
| Design-screen portrait reflects payload changes | **DONE 15:03** | NOVA | `design.gd` passes the selected instruments; build line under portrait |
| Debrief portrait + label updates immediately after INSTALL | **DONE 15:03** | NOVA | `debrief.gd` `_refresh_ship`/`flash_build`; hardware two-line legend |
| Final report prints completed build and tier | **DONE 15:03** | NOVA | `report.gd` SHIP row |
| Full-flow proof: 3 sectors, buy, next planet, stats + report | **DONE 15:03** | NOVA | `--screen=flowtest`: range 3→4, total 4963, grade A, 3 successes |
| Deep Data Buffer actually applies its comms promise | **DONE 15:04** | NOVA | `comms_bonus: 4` + `ship()` buffer branch; previously only a design-screen stat |

## VEGA — grounded structure pass (ATLAS request, 15:12)

**Problem (from user, m07249/m07307/m07316):** large structures read as sprites pasted on the ground. The worst offenders are the volcano's brown circular plinth and the cyan geyser/methane vents, which sit on perfect round discs. The 4×4 footprint also leaves grassy empty corners because the art only fills a circle.

**Direction:** real terrain never has a perfect circular platform. Replace every built-in plinth with an asymmetric, partially buried apron that spills into the footprint corners. The volcano should be designed as a **square 4×4 tile composition**, not a round icon on a square tile.

### 1. Volcano 4×4 — priority
- Output: `assets/tilesets/structures/assembled_volcano_4x4.png` and `assets/tilesets/structures/pieces/volcano_r*c*.png`.
- Keep the existing 4×4 / 16-piece / 64 px contract (`assets/tilesets/structures/pieces/manifest.json`), so `map_generator._add_piece_sprites()` needs no change.
- Remove the brown circular disc completely. Build the base from 4–8 irregular cooled-basalt lobes, ash/talus fans, and one or two lava channels that reach toward the tile edges. The contact line must be broken and asymmetric, with rubble partially covering it.
- Use the empty 4×4 corners: low caldera rim, ash drifts, broken crust, or lava seams. Do not leave transparent/grassy holes inside the footprint, and do not add a hard square border either.
- Keep the vent/summit off-center; visible crater; no text/UI; nearest-filter pixel art; derive colors from `volcanic/ash_rim`, `volcanic/basalt_shelf`, `volcanic/lava_core`, `volcanic/lava_glow`.
- No baked ground shadow (the renderer owns the contact ellipse), but bake a little ambient occlusion where the rock meets the soil.

### 2. Rounded-base audit — same pass
Rebuild the base silhouette, not just the shadow, for:
- `geyser.png`, `geyser_field.png`, `methane_vent.png` — remove the brown/stone circular pad under the cyan cone; replace with a fractured sinter terrace / mineral crust that merges into the ground.
- `basalt_columns.png`, `mesa.png`, `mesa_b.png`, `iceberg.png`, `islet.png`, `coral_spire.png`, `crystal_outcrop.png`, `impact_crater.png`, `mountain_range.png` — check for disc plinths and replace with talus, eroded feet, or broken shelves. `impact_crater` should read as a depression, not a platform.
- Small props keep their contact ellipse; do not add flat oval pedestals.

### 3. Acceptance
- 3×3 contact sheet on volcanic, temperate and cryo ground at native map scale; no visible circle, no floating edge, no hard square frame.
- `assembled_volcano_4x4.png` is 256×256 (or the existing piece grid), pieces align at 64 px, and the bottom-row z-order is unchanged.
- Save previews/evidence under `/tmp/opencode/vega_grounded_*`; update the manifest only if the footprint changes.
- Do not re-export or touch `map_generator.gd`; ATLAS will wire/test after d's 14:58 gate QA.

### ATLAS acceptance — after VEGA's 8 beach diagonals
VEGA must deliver:
- `assets/tilesets/transitions/temperate_beach_temperate_water_lake_deep/{nw,ne,se,sw}.png`
- `assets/tilesets/transitions/temperate_beach_temperate_water_lake_shallow/{nw,ne,se,sw}.png`

Then ATLAS runs:
`godot --headless --path . -s tools/water_probe.gd -- --seeds=26758 --biome=temperate --diagcheck`
and posts `diag_missing_by_key = {}` in BOARD/WORKLOG. Keep the existing `temperate_grass_*` sets for inland lakes.

**Status 15:15:** pass 1 (ash recolour + 16 talus lobes) is WIP, not accepted. Disc still readable, side boulders detached, top corners empty. Next: new cone drawn without any base/terrace primitive; generate apron as continuous ridges/ash flats connecting into all four corners. Geyser lineage shares the same replacement generator.

## UI identity pass — OPEN (NOVA brief, 15:31)

Boss: the UI "looks too generic and vibecoded." Brief: `docs/UI_REDESIGN.md`. **No owner is preassigned; claim in BOARD.** VEGA is invited for the skin/button generation; code integration is open to any agent or friend.

| Task | Status | Owner | Notes |
|---|---|---|---|
| U1 — `assets/ui/skin/` 9-slice folder/card/tab/button kit, stamps, tape, punch, ruler/barcode, paper texture | **VEGA — DELIVERED 17:20** (`tools/make_ui_kit.py`, 22 files + manifest + preview) | done | Procedural Pillow pixel geometry for crisp 9-slices, not diffusion; manifest + contact sheet |
| U2 — `UIKit` tokens/helpers (`folder_panel`, `card`, `stamp_button`, `ruler_gauge`, `stamp`) | **OPEN** | self-assign | `scripts/ui_kit.gd` single owner; keep old helpers as aliases during migration |
| U3 — Screen integration: title, design, draft, debrief, report, crew, buff | **OPEN** | self-assign | One pass per screen; preserve layout, rules and keyboard paths |
| U4 — Sector HUD pass (corner console, segmented heat/power, warning tape, physical D-pad) | **OPEN** | self-assign | Map stays the hero; coordinate with U2 owner |
| U5 — Copy/voice pass (mission-control voice, consistent labels) | **OPEN** | self-assign | No generic OK/CANCEL; keep short at 640×360 |
| U6 — QA: before/after at 640×360 + 1280×720, headless clean, Web 0 console/page errors | **OPEN** | self-assign | Evidence paths; do not re-export the gate until accepted |

## Milestone field commissions (NOVA, 15:26)

Boss: a Soul Knight-style free upgrade draft, separate from the shop, after fixed rounds.

| Task | Status | Notes |
|---|---|---|
| 12 `BUFFS` + `BUFF_MILESTONES [1,2]` in `game_state.gd` | **DONE 15:24** | Free, permanent; effects applied in `ship()`/`begin_sector`; score buffs in `calculate_score` |
| `scripts/buff.gd` + `scenes/buff.tscn` three-card draft | **DONE 15:26** | Card art, rarity, hover/keyboard 1/2/3, `--buff-pick=` QA hook |
| 12 pixel icons + generator `tools/make_buff_icons.py` | **DONE 15:19** | 48px, nearest 2×; preview `/tmp/opencode/buff_icons.png` |
| Trigger after planet 1 and 2; `debrief` routes event → commission → draft | **DONE 15:26** | `pending_buff`/`buff_choices`; footer shows NEXT: FIELD COMMISSION |
| Flow proof: buff pending, pick harden, integrity 4→6, report still scores | **DONE 15:29** | `--screen=flowtest` → `buff_pending=true buff_ok=true buffs=["harden"] integrity=4->6` |
| Screen evidence | **DONE 15:35** | `qa_buff2.png`, `qa_debrief_buff2.png`; README gallery + `screenshots/buff.png`; UI skin pass will restyle it |

# Task Board — Orbit & Outplay

> **Check `docs/BOARD.md` first — RULE 0: every agent reads the board before touching anything and keeps `bash tools/board_watch.sh docs/BOARD.md 5` armed in the background. Re-arm after every wake.**

The map-generator-only scope in the previous board is **superseded**. The user's brief (m00001) asks for a complete Space Mission Design Game prototype, and that is what shipped.

## QA lane — claimed by d (11:54)

d owns QA per `docs/BOARD.md` (browser loops, claim-vs-evidence checks, bug list). Scope claimed for this pass:

| # | Task | Status | Evidence / note |
|---|---|---|---|
| Q1 | Static claim-vs-evidence audit (asset refs resolve, art-wiring claims, dataset integrity) | **done** (16:05) | `python tools/qa/audit_project.py` on `7e8c55b` -> `docs/QA_REPORT.md`: 26 pass, 0 fail, 5 warn |
| Q2 | Native run + screen check on the current HEAD | **done** (16:05) | 10 screens (crew + relay added): **10/10 pass**, exit 0, non-blank (1,000-23,297 colours). The 15:33 P0 (design/debrief blank) is fixed upstream |
| Q3 | Browser loop against the gate build (title → design → draft → sector ×3 → report; C path + A path) | **blocked** (15:35) | `build/` absent here; 14:58 gate build lives on ATLAS's machine; template archive download defeated by network resets. Harness ready + self-tested: `tools/qa/browser_loop.mjs` |
| Q4 | Re-run browser loop against the final build | waiting on ATLAS/ORION | needs a build artifact or a published URL; same command as Q3 |
| Q5 | Bug list (claim vs evidence, docs drift) | **done** (16:05) | `docs/QA_REPORT.md`: 2 open bugs (`PSCOMPPARS` casing in title/draft credit; radiator -3 vs -6) + 3 nits. P0 parse error cleared |
| Q6 | Repeatable QA tooling + usage docs | **done** (12:20) | `tools/qa/{audit_project.py,native_screens.py,browser_loop.mjs,README.md}`; captures gitignored |

**Gate status:** the 15:35 P0 (`ship_diagram.gd` line order) is **fixed** on `7e8c55b`; design and debrief now render and the native pass is 10/10. Remaining pre-ship items are the two copy bugs (PSCompPars casing, radiator -3 vs -6). QA reports, it does not fix: `scripts/`, `scenes/`, `assets/` belong to ATLAS/VEGA. **Request:** publish `build/web/` (or a hosted URL) and the loop runs as `node tools/qa/browser_loop.mjs --dir build/web --port 8061`.

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
| 30-second demo video | done | `demo/orbit_outplay_demo.mp4`, 28.47 s, 1280×720, 2.31 MB, one continuous deterministic run (Movie Maker capture, `tools/record_demo.py`) |
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

`submission/` contains the static game ZIP (21.7 MB), the 28.47 s video, the 7-slide deck, and the project-page copy. The game ZIP is just `build/web/`; no server-side code.

## Build & release — c (claimed 11:59)

| Task | Status | Notes |
|---|---|---|
| Continuous demo capture | **DONE 16:55 (re-recorded)** | `tools/record_demo.py` + `scripts/demo_director.gd` + `tools/make_demo_from_capture.py`. Movie Maker mode (`--fixed-fps 30 --write-movie`) records one deterministic run; `markers.json` drives the 7 caption beats. Output `demo/orbit_outplay_demo.mp4` 1280×720, 854 frames, **28.47 s**, **3.77 MB**, cut from a 38.50 s / 1155-frame capture. Recorded on the same tree as the 17:03 PCK, so it shows the post-gate art (volcanic surface, ship build, field commission). |
| C1 — Web export + ZIP repack | **DONE 17:03 (`186fb8a`)** | `tools/release.sh`, clean tree: import 0, export 0, 9 files, `index.pck` **16,462,628 B** (sha256 `8ad2496725…`), `index.wasm` 39,514,754 B, `index.html` 5,468 B. ZIP `submission/orbit_outplay_web.zip` **23,753,398 B** (sha256 `24aad1dd…`), 9 entries at root. Smoke :8060 = 200/200/200. **ZIP is over a 20 MB host cap now.** |
| C2 — One-command release script | **DONE (export bug fixed 16:19)** | `tools/release.sh` did not work: it deleted `build/web` and exported into a missing folder (`Target folder does not exist or is inaccessible`, exit 2 — Godot 4.7 will not create it). Fixed with `mkdir -p`, plus an `--import` pass before every export and `*.import` stripping before zipping. `tools/release.py` is the Windows twin, same order and same outputs. |
| C3 — Load-time budget | **DONE 15:15** | `tools/load_probe.mjs` (CDP, no npm). Cold cache, SwiftShader software rasteriser: WASM runtime ready **5.2 s**, first drawn frame **5.1 s**. Payload `index.wasm` 39.5 MB + `index.pck` 16.5 MB; ZIP 23.8 MB. |
| C4 — Loop + demo on the post-gate flow | **DONE 17:12** | Loop green on `186fb8a`: 22 stills, `reachedReport: true`, **0 page errors / 0 console errors**, exit 0. Handles the first-run callsign sheet (`FILE APPOINTMENT` 210,204) and induction skip (576,42), the debrief footer (511,327) with event `CHOOSE` (484,166) + commission card (150,177), and ends each sector by attrition because `EXTRACT` now needs quota + landing zone. Demo `demo/orbit_outplay_demo.mp4`: 1280×720, 30 fps, 854 frames, 28.47 s, 3.77 MB, recorded on the same tree. |
| Browser loop on :8061 | **DONE 17:12** | `tools/browser_loop.mjs` (CDP + `node:zlib` PNG decode, no npm): asserts every screen change by 16×9 fingerprint and fails unless `reachedReport`. Exit 1 on page errors, console errors or a short run. |

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

The surface renderer is functionally complete: 13 biomes, palette-locked 64 px tiles, 125 transition pairs, corner matching, props, structures, minimap, telegraphed hazards. Remaining visual debt — more than one item; the submission must not overclaim:

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
| 8 | Blocked-move `deny` cue | **DONE 14:02** | `tools/make_sfx.py` now also writes `assets/audio/deny.wav` (0.100 s, peak 0.307, two-step 208→162 Hz buzz, −5 dB). `GameState.sfx("deny")`; `sector.gd::_try_move` fires it when the target cell is not walkable — walking into rock/water/edge used to be silent. |

## Audio — music bed + cues (posted 12:48, done 14:02)

| Task | Status | Notes |
|---|---|---|
| Music bed — Balatro-style reactive loop | **DONE 14:02** (f, both halves) | **3 loops, 68.6 s each, 84 BPM shared** (`title` / `sector` / `debrief`; report reuses debrief, design+draft reuse title). Generated by new `tools/make_music.py` (stdlib, seeded, no samples) → `assets/music/{title,sector,debrief}.ogg`, **total 792 KiB** (budget 3 MB). **Seams:** decoder-measured wrap discontinuity 0.23–0.48× the mean sample delta, exact 68.5714 s decoded — no encoder padding gap. **Levels:** all three at −17.4 dBFS RMS, peaks 0.65–0.93. **Wiring:** `MusicDirector` autoload, 2-deck 2 s crossfade (`FADE_IN/OUT`), `play(context)` no-ops on the same bed, `set_duck(true)` pulls −7 → −13 dB over 0.35 s, headless early-return, full `_exit_tree` teardown. **Duck source:** `sector.gd::_refresh_status` ducks whenever a telegraph is live and clears it when the sector is done. Evidence `/tmp/opencode/f_music_sheet.png`, log `--music-log`. |

| Shareable **full design** code (loadout import) | **DONE** | `OO-01156-S2-PAVMOLOA-SPTH` round-trips to seed 4438 / Standard / 2 players / Pathfinder / Vector M / Low / Characterize Atmosphere / Spectrometer + Thermal; short `OO-xxxxx-S1` codes still work |
| Design-screen header overlap fix | **DONE** | `MISSION DESIGN // 01 · STEP 1 OF 3` is now one line; the old step label was being covered by the panels (`qa_director3.png`) |

## ECHO — music lane (claimed 15:00)

`docs/AUDIO.md` is the lane doc: research verdict, engine matrix, prompt recipes,
loop-mastering contract, runtime contract, hardware reality.

| Task | Status | Notes |
|---|---|---|
| ComfyUI soundtrack research | **DONE 15:00** | Verdict: yes for source material, no for finished loops. SA3 wins instrumental quality + tempo/key adherence (61% / 64% vs ACE at chance); ACE wins songs/vocals/MIT. Numbers and sources in `docs/AUDIO.md` §1–2. |
| Engine choice (SA3 Small-Music primary) | **DONE 15:00** | 3.46 GB total, 100 BPM / A minor / 32-bar loops (76.8 s), −16 LUFS, OGG q3 ≤ 2.8 MB. Decision rationale in §2. |
| SA3 Small-Music download | **PARKED / OPTIONAL** | 2.27 GB checkpoint + 1.19 GB t5gemma. Procedural synth music landed in tree (788 KiB total); external model download parked unless high-fidelity stem sourcing is requested. |
| `tools/make_music_loop.py` | **DONE 18:40 (e, handed back to ECHO)** | Bar-aligned trim, wrap-around crossfade (folds the tail into the head so the wrap is sample-continuous), numeric seam gate, loudness match, OGG q3 + JSON sidecar. ECHO had no file on disk and the lane was idle since 15:02, so `e` wrote it; if ECHO lands its own version, take ECHO's and delete this one. `--selftest` is the evidence (no GPU, no ComfyUI, no generated audio needed). |
| Generate + master 3 cues | **DONE 18:40 (f, `7f7cbc8`) — one defect open** | Three 68.571 s beds (24 bars at 84 BPM) in `assets/music/`, `MusicDirector` wired, 788 KiB total. Measured by `e` with `--check` (`docs/AUDIO.md` §5.1): seams clean (wrap 14–18 dB below baseline), mono fine, but **`sector` peaks at −0.60 dBTP against the −1.5 ceiling** and the cues sit 1.16 dB apart in LUFS (title is the hot one). Both are one-gain-change fixes on the owner's side. |
| `MusicDirector` autoload | **DONE 14:02 (f, `7f7cbc8`)** | `scripts/music_director.gd` registered in `project.godot`; 2-deck 2 s crossfade, hazard duck (-6 dB via `MusicDirector.set_duck` in `sector.gd`), headless-safe early return, full `_exit_tree` cleanup. Wired to title/design/draft, sector, and debrief/report. |
| Web export + size check | **DONE in tree (788 KiB)** | Total music size 788 KiB (budget ≤3 MB, using 26%). In the tree; pending next `tools/release.sh` export package. |

## Structure scale & grandeur pass (NOVA request, 13:38)

Boss: "big mountains are almost the same size as the craft… make the world feel grand." Full spec: `docs/STRUCTURE_SCALE.md`.

| Task | Status | Owner | Notes |
|---|---|---|---|
| Stopgap scale hierarchy: lander 1.15→0.66, mountain/mesa/volcano/iceberg scale up, overlay z 12→22 | **DONE 13:36** | NOVA | `scripts/map_generator.gd`; evidence `scale_*_grand.png`; provisional, ATLAS owns final tuning |
| 64 px structure piece set (peak/shoulder/foot, volcano cone/flank/apron, ridge crest/foot) + previews | **DONE 18:55 — VEGA** (`pieces/massif_*`, `pieces/volcano_*`, `ridge_crest_a/b`, `ridge_foot`, `assembled_*_4x4.png`, `manifest.json`) | VEGA | `assets/tilesets/structures/pieces/`, palette-locked, no plinth/shadow, manifest offsets |
| Multi-tile `pieces` schema + alpha-bbox footprint fit + per-piece z-sort | **REQUESTED** | ATLAS | Collision must match visible base; overhang ≤1 tile |
| Wire the 60 existing cliff tiles to raised terrain edges | **REQUESTED** | ATLAS | Cheapest verticality win; `cliff_<height>_<dir>` already on disk |
| Density retune for bigger footprints (fewer, larger landforms) | **REQUESTED** | ATLAS / b | Suggested: major landforms ≤25% of walkable cells per chunk |
| Connectivity guarantee after structure placement (flood fill to objectives/extract, carve a pass) | **REQUESTED** | b / ATLAS | Must hold over 100 seeds per biome |
| Optional parallax ridge silhouettes behind the diamond | **DONE 12:40 — VEGA** (`pieces/parallax_ridge_a/b.png`, 640×120, transparent) | VEGA | 640×120 transparent, dark, low contrast |
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

## UI identity pass — U2–U4 + U7 DELIVERED 18:55 / 22:05 (keep navy/cyan; paper kit unwired)

Boss: the UI "looks too generic and vibecoded." Brief: `docs/UI_REDESIGN.md`. **No owner is preassigned; claim in BOARD.** VEGA is invited for the skin/button generation; code integration is open to any agent or friend.

| Task | Status | Owner | Notes |
|---|---|---|---|
| U1 — `assets/ui/skin/` 9-slice folder/card/tab/button kit, stamps, tape, punch, ruler/barcode, paper texture | **VEGA — DELIVERED 17:20** (`tools/make_ui_kit.py`, 22 files + manifest + preview) | done | Procedural Pillow pixel geometry for crisp 9-slices, not diffusion; manifest + contact sheet |
| U2 — `UIKit` tokens/helpers (`folder_panel`, `card`, `stamp_button`, `ruler_gauge`, `stamp`) | **DONE 18:55 / 22:05** | UI pass | `sheet()`, `hairline()`, `head()`/`mono()`, flat `option_card` rows, `UIGauge` (`scripts/ui_gauge.gd`), `hover_info()` alias; old helpers kept as aliases |
| U3 — Screen integration: title, design, draft, debrief, report, crew, buff | **DONE 18:55 · hover 22:05** | UI pass | All seven migrated; review/event modals included; keyboard paths unchanged. Hover dossiers trim visible rows on design/draft/crew/debrief/buff. Evidence `/tmp/opencode/ui_final/ui_*.png` |
| U4 — Sector HUD pass (corner console, segmented heat/power, warning tape, physical D-pad) | **DONE 18:55 · hover 22:05** | UI pass | One 620×40 row + separators, 112 px actions clear of the D-pad, duplicate QUOTA removed; transparent hover zones explain the six HUD stats; verified `--moves=DDH` |
| U5 — Copy/voice pass (mission-control voice, consistent labels) | **PARTIAL 18:55** | UI pass | Tightened labels (`CONFIRM DESIGN`, `MARK TARGET`, section names); full voice pass still open |
| U6 — QA: before/after at 640×360 + 1280×720, headless clean, Web 0 console/page errors | **PARTIAL 22:05** | UI pass | Headless + flowtest (`total=5107 grade=A`) + 640 downscales clean; hover dossiers verified by emitted `mouse_entered`; native QA's 6 flagged screens are the existing `title.ogg` exit leak. Web build not re-exported (per brief) |
| U7 — Progressive-disclosure hover dossiers (Balatro-style) | **DONE 22:05** | UI pass | `scripts/ui_tip.gd` + `UIKit.hover_info`; one 196 px card, placement flips/clamps, top-HUD drops below the bar; bindings on design/draft/crew/debrief/sector; stale tooltips removed |
| U8 — Binder palette/style shift (paper/ink/orange; night HUD) | **DONE 23:35 · `a1b6739`** | NOVA | FLIGHT BINDER 1975 on every flow screen: paper/ink/orange menus, night sector HUD retained, live cyan only for telemetry; debrief + event modal included |
| U9 — Restrained post-process pass (film/print grain, vignette, halation) | **DONE 23:35 · off by default** | NOVA (VFX busy) | `post_fx.gd` + `ui_post.gdshader`; default 0 in judged build, F8 cycles 0/0.35/0.7/1.0, `--post=0.45` for A/B; grain dark-only, 0.05 vignette, no scanlines/aberration |

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
## b — full audit pass (claimed 10:10, done 10:10)

| Item | State | Notes |
|---|---|---|
| Walkability / water + lava | done | `BLOCKED` includes all depth bands; `_is_walkable_world()` tests the raw field |
| Sector turn + HUD correctness | done | Eclipse sign, sweep origin, Δv/sol path cap, clamps, 12 pips, forming tag, credited-data toast, route cost |
| Economy + report | done | Radiator −3, repair kit → next-sector integrity, shop refresh, RISK row, passes/day |
| Campaign code + difficulty cards | done | Paste field 32 chars; heat modifier on all short strings |
| Tool portability | done | `/home/g1/...` defaults replaced with env/HOME |
| Doc drift record | done | `docs/AUDIT_FIXES.md` (existing docs intentionally not edited) |
| Evidence | done | `--quit-after 8` exit 0; `--screen=flowtest` `total=5034 grade=A` |

## Chief Engineer briefing (story / tutorial) — 15:44

Boss approved the story frame. Full beat sheet, layout and acceptance: `docs/BRIEFING.md`.

| Task | Status | Owner | Notes |
|---|---|---|---|
| Beat sheet + first-run/replay/skip flow + `briefing.seen` persistence | **DONE 15:46** | NOVA | 7 beats, 6+send-off; `docs/BRIEFING.md` |
| `scenes/briefing.tscn` + `scripts/briefing.gd` paper dialogue scene | **DONE 15:50** | NOVA | Character left, paper dialogue bottom, typewriter, mouse/Space/Enter/Esc |
| Placeholder portrait set (neutral/smile/stern) for layout QA | **DONE 15:48** | NOVA | Replaced by VEGA; same paths |
| Character sprite sheet (160×240 ×3 + 64×64 icon + manifest) | **ASSIGNED — VEGA** | VEGA | Creative latitude in face/uniform/pose; new ComfyUI workflows allowed; regenerate all expressions together |
| QA: first boot → briefing → design; skip; replay; 640×360; Web | **PENDING** | NOVA / d | `qa_briefing*.png`; browser pass after re-export |
## b — A1 reachability audit + connectivity (claimed 10:20, done 10:24)

| Task | State | Notes |
|---|---|---|
| `tools/audit_reach.gd` (N seeds × 6 biomes, bounded flood fill, table, exit code) | **DONE** | `godot --headless --path . --script tools/audit_reach.gd` |
| Connectivity guarantee after structure placement | **DONE** | `_place_objectives()` accepts only cells in `_reachable_world_cells(28)`; deterministic fallback keeps the node count |
| Bug evidence | **DONE** | Before: 18 unreachable / 240 markers (9 runs, volcanic worst). After: 0 / 2,400 markers |
| Full target run (100 seeds per biome) | **DONE** | `REACH OK` exit 0; see `docs/AUDIT_FIXES.md` §5 |

## b — A2 density-vs-footprint formula (claimed 10:36, done 10:40)

| Task | State | Notes |
|---|---|---|
| `tools/audit_density.gd` (per-chunk walkable denominator, major-footprint coverage, table, `--gate`) | **DONE** | `godot --headless --path . --script tools/audit_density.gd` |
| Formula: `sum(A_major) <= 0.25*W_walk`, `N_max=floor(0.25*W_walk/A)` | **DONE** | Caps at `W_walk=196`: 4×4 → 3 (1 with overhang), 3×3 → 5 (1), 2×2 → 12 (3) |
| 3 example chunks | **DONE** | barren 35.2% (10 craters), temperate 34.0% (5 massifs), volcanic 33.6% (3 volcanoes) |
| Full measurement | **DONE** | 1,064 chunks, 28 over budget (2.6%) |
| New finding: no major landform in arid/cryo/ocean | **DONE** | Ridge types are 2×2 mesa/iceberg and 1–2-cell islet |
| Enforcement in `_generate_chunk_structures()` | **QUEUED (freeze)** | Accumulate footprint, stop at `0.25*W_walk`; `--gate` is acceptance |

## QA close-out (16:29, this pass)

Direct follow-up to d's 16:05 report. Supersedes Q5's "2 open bugs" line: both are closed and the two static-audit fails that appeared after that pass are fixed.

| Task | Status | Notes |
|---|---|---|
| Archive credit `PSCompPars` casing (title + draft) | **DONE** | Pixel font is uppercase-only; both credit labels now use the body face (`pixel=false`). Verified in `qa/artifacts/native/qa_title.png` and `qa_draft.png`: reads `PSCompPars` |
| Radiator -3 vs -6 | **VERIFIED FIXED (no-op)** | `game_state.gd:136` is `thermal_res: 3` (landed in `9d49310`); copy and effect agree. The 16:05 report was stale |
| Static audit fails: `res://demo/capture` + transition count | **DONE** | `tools/qa/audit_project.py` treats `res://demo/*` as runtime output; README/TASKS corrected 98 -> 100 pairs to match `tools/transitions.json` |
| `MAP_GENERATOR.md` main-scene claim | **DONE** | Doc now says `scenes/title.tscn` is the project main scene; map scene is the direct-launch dev entry |
| Verification | **DONE** | `audit_project.py --check` 28 pass / 0 fail / 3 warn, exit 0; headless `--quit-after 8` exit 0; native screens 10/10 |
## VEGA — ACTIVE ART TASK (NOVA, 16:33)

**DELIVERED 19:10 by VEGA** — portraits rebuilt to this brief (seed 4101, `raw2_neutral_4101.png` canonical, smile/stern derived; contact sheet `/tmp/opencode/crew3.png`). UI skin in the dark-blue/cyan language deliberately **not** taken: the boss preferred the old look, so `assets/ui/skin/` (paper kit) stays out of the build unless asked for.

- **Character:** Dr. Imani Vale, executive secretary (not deputy director). Age ~30, professional and warm, light or navy agency uniform, fully covered, non-sexualised — hackathon-safe. She calls the player “Chief”.
- **Files:** `assets/sprites/crew/director_neutral.png`, `director_smile.png`, `director_stern.png` at 160×240 RGBA, same face across all three; `director_icon.png` 64×64; update `manifest.json`. Keep the transparent/cream-card readability that currently makes the jacket read white, not black. Raws under `assets/raw/crew/`; workflow/seed/prompt notes in the manifest or `assets/raw/crew/README.md`.
- **Creative freedom:** face, hair, uniform, badge, headset, silhouette, expression nuance. New ComfyUI workflows may be created at any time; if you use one, regenerate all three expressions from one reference so the face does not drift.
- **Optional UI skin:** `assets/ui/skin/` buttons/tabs/strips in the old dark-blue/cyan palette; do not recolor the game to olive/amber.
- **Acceptance:** three expressions + icon load in `scenes/briefing.tscn`; no black jacket block on the cream card; nameplate reads `EXECUTIVE SECRETARY`; no sexualised framing.
## b — A3 small-island metric + pinhole coalescing (claimed 10:52, done 11:24)

| Task | State | Notes |
|---|---|---|
| `tools/audit_islands.gd` (50 seeds x 4 biomes x 8x8, stitched components, per-chunk histogram, islets, `--gate`, `--dump`) | **DONE** | `godot --headless --path . --script tools/audit_islands.gd` |
| Baseline numbers | **DONE** | 1,119 holes / 12,800 chunks = 0.087/chunk; ocean 1,002 (889 one-cell), lake biomes 117 |
| Root cause 1: ocean `base` is water, speck fallback created pinholes | **DONE** | `_smooth_cell()` uses `land_fill` (shore/rock) + dominant-neighbour merge |
| Root cause 2: per-cell smoothing disagrees with smoothed neighbours | **DONE** | `_coalesce_water_pinholes()` post-pass over a 1-cell smoothed halo |
| Post-fix numbers | **DONE** | 8 / 12,800 = 0.001/chunk, max 1 per chunk; islets 142 -> 139 |
| Reachability regression | **DONE** | 100 seeds x 6 biomes / 2,400 markers / 0 unreachable |
| Density regression | **DONE** | 28 / 1,064 chunks over 25% (unchanged) |
| Water diagnostics | **DONE** | `water_probe --diagcheck`: `diag_missing_by_key {}`, `tiny_water_cells 0` |
| Residual seam-straddling 2-cell holes | **NOTE** | 8 total; require a 2-cell smoothed halo (raw pad 3); not worth the cost at 0.001/chunk |

## Autonomous pass (NOVA, 16:56)

| Task | Status | Owner | Notes |
|---|---|---|---|
| U2 — wire VEGA's `skin_dark` buttons | **PARTIAL DONE 16:56** | NOVA | Secondary buttons use `button_idle/hover/pressed`; primary teal buttons and layout unchanged. No art edits. Evidence `qa_title_skin.png`, `qa_design_skin.png`, `qa_skin_crew.png`. |
| Density/scale retune + unique 4×4 landmark | **DONE 16:56** | NOVA | Temperate gets one 4×4 massif; other ridges use `mountain_range` at 1.75; volcanic/sulfur/obsidian start with a 4×4 volcano (Lake District no longer swaps it for a geyser); lander 0.82. |
| Biome-specific ambient life | **DONE 16:56** | NOVA | Dust motes tinted/directed per biome (snow in cryo, embers in volcanic, dust in arid, spores in temperate); lander hover, breathing shadow, pulsing beacons/hazard, movement puff. |
| Cliff face height | **DONE 16:56** | NOVA | Existing `face_*` plateau rims raised 6→12 px; no new art. |
| Reachability after landmark/density change | **DONE 16:56** | NOVA/b | `tools/audit_reach.gd`: 600 seeds, 2,400 objectives, **0 unreachable**. |
| Parallax ridge wiring | **DONE 16:58** | NOVA | `parallax_ridge_a.png` on `space_layer` at y230, alpha 0.28, slow drift; evidence `qa_parallax_cryo.png`. No art edits. |
| 4×4 grand landmarks for cryo/arid/barren | **REQUESTED — VEGA ONLY** | VEGA | `iceberg_4x4`, `mesa_4x4`, `crater_4x4` in the existing piece manifest format; only the artist gets this. |

| Portrait lighting/segmentation fix (seed 4201) | **APPROVED 17:46 — VEGA** | VEGA | `--largest` + fixed head box; neutral canonical, smile/stern derived; cream + dark card check; no other art changes |

## Surface loop overhaul — first slice (NOVA, 18:15)

| Task | Status | Owner | Notes |
|---|---|---|---|
| M1 signal tiers / deep caches | **DONE 18:15** | NOVA | Distance bands 4/6/8/10; tiers 1/1/2/2; deep +2 data and +4 heat; larger bright marker; evidence `qa_tier_nodes.png` |
| M4 survey fog + bigger view | **PROTOTYPE DEFAULT 18:15** | NOVA / ATLAS | `VIEW_W/H 24×18`; fog default on, `--no-fog`; reveal 5 start / 2 per step; evidence `qa_fog_default.png`, `qa_fog_move.png` |
| M2 survey choice (sample/deep scan) | next | NOVA | turn-pause modal; see `docs/MAP_GAMEPLAY.md` |
| M3 terrain movement cost | next | NOVA / ATLAS | rock/ridge cost 2, water/lava block; path budget |
| Fog edge/softness + minimap reveal | needs ATLAS/VEGA | ATLAS / VEGA | current fog is cell-hard; do not add art without VEGA |

## VFX / animation / shader lane (claimed 18:00 — VFX agent)

Scope: all shaders, in-game animation, effect art. Static tiles/sprites stay VEGA's. Contract and knobs: `docs/VFX.md`.

| # | Task | Status | Evidence / note |
|---|---|---|---|
| V1 | W5 grade: hue-only tint, luminance floor, per-biome exposure | **DONE 18:20** | `shaders/map_view.gdshader`, `BIOMES[*].exposure`; A/B `/tmp/opencode/vfx/side_*.png`; measured in WORKLOG 18:20 |
| V2 | Animated hazard telegraph shader (armed/forming/scar + per-kind motion) | **DONE 18:20** | `shaders/hazard_field.gdshader`, `sector.gd::_draw_hazards()` |
| V3 | Effect library: impact, shield, pickup, extract beam, overheat, landing pad | **DONE 18:20** | `scripts/vfx.gd`; reel `--fx=all`; `/tmp/opencode/vfx/fx2_strip.png` |
| V4 | Movement/objective/ambient motion: per-cell tween + puff + bank, scanner ring, per-biome particles, planet drift, star twinkle | **DONE 18:20** | `sector.gd::_execute_path`, `map_generator.gd::_build_ambient` / `_rebuild_actors`, `shaders/star_drift.gdshader` |
| V5 | Animation-art pipeline: procedural sheets + ComfyUI VFX workflows + motion deriver | **DONE 18:20** | `tools/make_vfx_art.py`, `tools/gen_vfx_sheet.py`, `tools/comfy_workflows/vfx_*.json`, `assets/vfx/` |
| V6 | Scene transitions (fade/paper slide) and HUD gauge animation | **OPEN** | needs `change_scene_to_file` call sites and the UI gauge refactor; coordinate with UI owner |
| V7 | Volcanic heat-haze refraction | **OPEN** | needs a screen-copy or extra texture; evaluate after W1 mask lands |
## Static truth pass (18:10, this pass)

No Godot binary on this machine, so everything below is source/Python-tool work
only. Nothing here was runtime- or visually verified.

| Task | Status | Notes |
|---|---|---|
| Transition-pair count drift (audit FAIL) | **DONE 18:10** | `docs/TASKS.md` + `README.md` said 100 pairs; `tools/transitions.json` has 125 (ORION added 25 for retuned tile keys). Both corrected. `audit_project.py --check` back to **28 pass / 0 fail / 3 warn, exit 0**; `audit_data.py` **49 checks, 0 failed**. |
| `MAP_GENERATOR.md` accuracy | **DONE 18:10** | Controls section now matches the real handlers: `F4`-`F8` feature bar, `F9` transition debug, `F10`/`H` (map scene only), `F11` fullscreen. Documented `--debug-transitions` (accepted by `sector.gd` too), per-biome `PROP_DENSITY`, the dev-scene vs sector input difference, and the actual gameplay keys in `sector.gd`. |
| `EVENTS.md` §6 mismatch table | **DONE 18:10** | Added §6.1 status re-check: mismatches 1, 2, 3, 5, 7, 10, 11, 12 **CLOSED** with file evidence; 4 **OPEN by design** (H/F10 are not forwarded in-sector); 6 and 9 **PARTIAL**; 8 **QUARANTINED** (the shipped pool is inline in GDScript, `data/events.json` is a prototype). |
| ORION's 17:45 transition-debug ask | **ALREADY SHIPPED** | `map_generator.gd` already has `debug_transitions`, `_draw_transition_debug()` (tints straight/outer/inner/stripe/diag/other, prints `TRANSDEBUG {counts}`), the `F9` handler and `--debug-transitions`. ORION only needs one capture on a **barren/iron** board. |
| `NEXT +N TO GRADE X` clipped (`report.gd:124`) | **FIXED 18:38 (not by me)** | `7a1acdf` set height `8 -> 12` at `Vector2(14, 232)` and also took `BEST` from 10 to 12 while this pass was in flight; my equivalent commit rebased to empty and was dropped. Font-6 line was taller than the rect. Still needs one visual confirmation on a Godot machine. |
| Sector button label overflow (`MOVE  (ENTER)` etc.) | **OPEN - documented, not changed** | Measured ~108 px of label in a 100 px button at x=444-544; the D-pad starts at x=554 and the bottom-left panel ends at x=440, so there is no free 8 px to steal without re-laying out the footer. Left for the UI owner with a working Godot. |
| `SET COURSE >` overflow in draft | **OPEN - documented, not changed** | ~130 px text at x=482 inside a 620 px panel; cosmetic, needs a live check. |
| Re-export / browser loop / demo | **BLOCKED here** | No Godot, no `build/web`, no `submission/` in this clone; `build/` and `submission/` are gitignored. Must run on a machine with export templates (`tools/release.sh`). |

## Exoplanet outpost theme fix (NOVA request, 19:30)

| Task | Status | Owner | Notes |
|---|---|---|---|
| Quarantine human outpost modules (`habitat_dome`, `solar_farm`, `comms_dish`) from normal exoplanet generation | **DONE 19:30** | NOVA | `feature_toggles["outposts"] = false` in `scripts/map_generator.gd`; F5 remains dev-only preview |
| Re-author or replace the outpost set as alien/precursor ruins, if outposts return | **REQUESTED** | VEGA | No solar panels, habitat domes, airlocks, or Earth-industrial forms; 128/192 px, palette-locked; ComfyUI allowed; fixed brief + creative freedom |
| Lore/copy check for “abandoned survey architecture” mentions | **REQUESTED** | e | Surface should read as uncolonised survey target; only human objects are lander, flag, deployable relay |

| Difficulty curve: normalized quadratic across sectors (1.00 / 1.18 / 1.72), heat scale + sector-3 extra front | **DONE 19:35** | NOVA | `scripts/game_state.gd` `threat`, `scripts/sector.gd` `_hazard_budget`; evidence `--screen=flowtest` 4945/A |

| Precursor/alien ruins | **CANCELLED 19:42** | — | Boss: remove alien sectors. Assets stay unused/quarantined; do not wire into normal runs. |

## VEGA — modular multi-tile ridge kit (ATLAS, 22:18)

Current stopgap: `ridge_wide.png` is wired as a native 3×2 structure and chains 2–4 copies along a ridge (evidence `/tmp/opencode/ridge_chain.png`). It reads as a continuous wall, but every link reuses the same strip.

Please deliver a small modular kit, same 64 px grid, transparent background, no baked ground shadow, no circular plinth:

- `ridge_mid` — 3×2 straight segment, ragged base, continuous left/right edges.
- `ridge_cap_l`, `ridge_cap_r` — 3×2 end caps that close the ridge without a hard cut.
- `ridge_corner` — 3×3 corner (or 4×4 if cleaner) with the same rock/talus language.
- Optional biome palettes: temperate granite-moss, arid sandstone, cryo blue ice-rock, volcanic basalt-ash.

All segments must align at tile boundaries and preserve the existing 2×2/4×4 massif footprint language. Acceptance: a 9×2 chain and an L-shaped chain captured at 2× on temperate and arid, no visible rectangle seam, no detached boulders.

## Upgrade feedback + extraction pad (NOVA, 22:18)

| Item | State | Notes |
|---|---|---|
| Paid-refit delta capture | DONE | `GameState.buy_offer` snapshots `ship()` before/after; `last_upgrade` / `consume_last_upgrade`; `_upgrade_deltas` + `rig_summary`. |
| Debrief install feedback | DONE | `INSTALLED <name> · <delta>` green toast; rising stat tag; existing module flash. |
| Field rig feedback | DONE | `_show_rig_feedback` / `_show_rig_banner` at sector start; HUD pulses + green VFX ring; readable 2.8 s lifetime. |
| Extraction pad | DONE | LZ flag/pads re-projected after camera recenter; cyan pad chosen once 2–6 tiles away; `_extract` requires pad; `--extract-test` passes. |
| QA | DONE | Headless clean; flowtest 5284/S; `qa_rig_sector8.png`, `qa_rig_pop2.png`, `qa_extract_test.png`, `qa_pad_start.png`, `qa_pad_moved.png`. |
| Gate export | REQUESTED | ORION/ATLAS; changes are post-`f86134c` and unexported. |

## Juice / dopamine pass — tasks (ECHO, 22:55)

Boss feedback: *"not enough dopamine hits; after 5 minutes it feels boring; updates feel like no change to the user"* and *"not enough visual feedback from upgrades and shop items."* Claim a row before editing. `scripts/sector.gd` stays NOVA's until the binder pass lands.

| # | Task | Owner | Acceptance |
|---|---|---|---|
| J1 | Floating action text: `+2 DATA`, `−1 HULL`, `−3 HEAT`, `+1 POWER` on the action | NOVA (`sector.gd`) | 0.9 s rise, colour-coded, never covers the HUD; capture |
| J2 | Quota pips in the HUD that fill one at a time + `QUOTA MET` banner | NOVA | captures at 1/3 and 3/3 |
| J3 | Milestones: `FIRST NODE`, `QUOTA MET`, `CLEAN RUN ×3`, `DEEP CACHE +2` | NOVA | one toast each, once per sector |
| J4 | Grade projection in the HUD (`ON TRACK: A`) that updates on every pickup | NOVA | matches the final report within one grade |
| J5 | Pickup burst (sparks + ring) and hazard-impact vignette | VFX | 0.4 s, pooled, WebGL-safe |
| J6 | Install ping: ship emit + shop card stamp animation | VFX + UI | visible on purchase; capture |
| J7 | Module icons for every `UPGRADES` id, at 24 px and 40 px | VEGA | 11 icons + manifest + contact sheet |
| J8 | SFX: pickup chime, quota sting, deny buzz, upgrade thunk | f | 5 WAVs, ≤0.4 s, no external samples |
| J9 | Music: 4-bar sting on `QUOTA MET`, bed ducks under it | ECHO | after the first cue set lands |

**Shipped in this pass (ECHO):** `scripts/ship_diagram.gd` now detects a newly installed refit and pulses its slot for 3 s — white slot outline, expanding accent ring, rising `+`, and a `+RAD`-style name chip. No caller change needed; design and debrief both get it.

## Difficulty fairness (ECHO, 22:55)

- **Shipped:** sector-1 fuel/time floor in `scripts/game_state.gd` — `Δv ≥ 26` (plus +6 on the shakedown), `sols ≥ 26`; later sectors floor at 22/20. It only raises stats, so it cannot make a run harder.
- **Still needed (ATLAS / NOVA):** route-aware budget. After node placement, compute the cheapest route that collects the quota and returns to the pad, then top up Δv to ~1.25× that and print `ROUTE NEEDS ≈N ΔV` on the HUD at sector start. The floor prevents the worst cases but cannot know the actual layout.
- **Follow-up:** if the quota is 3 and the sector only affords 2, fail *at sector start* with a clear `ROUTE BUDGET` message instead of at the last node.

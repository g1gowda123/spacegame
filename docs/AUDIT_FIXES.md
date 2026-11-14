# Audit — code fixes and doc drift (agent b)

_Audited against `main` at `19f0d85`. Existing docs were **not** edited; this file
records what the code actually does so the owners of `README.md`,
`docs/ART_PIPELINE.md`, `docs/ART_HANDOFF.md`, `docs/STRUCTURE_SCALE.md` and
`AGENTS.md` can correct them deliberately._

## 1. Code bugs fixed in this pass

| # | Bug | Fix | File |
|---|---|---|---|
| 1 | Shallow/deep lake water, ocean `water_shelf` and volcanic `lava_core` were walkable. `_is_walkable_world()` tested the **rendered** tile, but the renderer swaps the raw water key for a depth-band key that `BLOCKED` did not name. | `BLOCKED` now lists every band key; walkability tests `_raw_terrain_world()`, which is always the canonical blocked key. | `scripts/map_generator.gd` |
| 2 | Eclipse was **silent** and drained power: `power: 2` was subtracted by `_resolve_hazard()` and the toast gate summed to a negative number. | Eclipse power is the signed delta `-2`; the gate fires on any non-zero delta and the toast prints cooling / restored power. | `scripts/sector.gd` |
| 3 | SWEEP arrow started at one **end** of the five-tile front (`cells[0]`) and pointed off the line. | Footprints store the centred origin (`anchor` / sweep `start_cell`); the arrow is drawn from the middle along travel. | `scripts/sector.gd` |
| 4 | Path preview accepted a 3-tile move with 1 Δv left; committing it failed the sector mid-path. | Reachable radius is capped by `min(move_range, delta_v, sols)` because every path tile costs 1 Δv + 1 sol. | `scripts/sector.gd` |
| 5 | Data toast printed the raw roll (`+2`) even when the cap credited `+0/+1`. | Toast prints the credited delta. | `scripts/sector.gd` |
| 6 | Integrity could go negative, so the fail screen read `INTEGRITY LEFT -1 / 6`. | All damage paths clamp at 0. | `scripts/sector.gd` |
| 7 | Power HUD had only 8 pips while `power_max` reaches 11–12. | 12 pips. | `scripts/sector.gd` |
| 8 | A forming sweep lost its SWEEP tag on the only planning turn (tail overwritten with `ARMS NEXT TURN`). | Forming sweeps read `SWEEP · ARMS NEXT TURN`. | `scripts/sector.gd` |
| 9 | Hazard footprints could land entirely on mountains/water/lava, consuming a budget slot with an untouchable threat. | A footprint needs at least one walkable cell. | `scripts/sector.gd` |
| 10 | Once the quota was met the route label hid the selected path's cost, so a lethal move had no preview. | Path cost is shown whenever a tile is selected; quota status is the fallback. | `scripts/sector.gd` |
| 11 | HUD read `3/4` while the win condition was quota `3`. | Data label uses `quota` for both survey and relay. | `scripts/sector.gd` |
| 12 | `--moves=` used a private copy of the movement rules (hazard on entry, no range check, no turn advance), so QA captures disagreed with play. | `_try_move()` selects and executes through the shipped turn model. | `scripts/sector.gd` |
| 13 | Dead `GameState.planet_biome_index()` assignment overwritten immediately. | Removed; the by-name loop is authoritative. | `scripts/sector.gd` |
| 14 | Deployable Radiator removed **6** heat/move while README + card said **−3**. | `thermal_res: 3`. | `scripts/game_state.gd` |
| 15 | Field Repair Kit was dead code: `pending_repair` was checked after integrity had already been reset to max. | Buying sets `next_integrity += 2`; the dead heal block and `pending_repair` writes are gone. Card now says “next sector”. | `scripts/game_state.gd` |
| 16 | Refit offers persisted across sectors, so later debriefs could show 1–2 cards. | `finish_sector()` clears `shop_offers`; each debrief rolls a fresh three. | `scripts/game_state.gd` |
| 17 | Dead `if id == "atmosphere": pass`. | Removed. | `scripts/game_state.gd` |
| 18 | Report score table omitted the risk bonus; orbit line omitted passes/day. | `RISK BONUS` row added; orbit line prints `N PASSES/DAY`. | `scripts/report.gd` |
| 19 | Campaign-code paste field capped at 16 chars, silently truncating the 25-char full code. | `max_length = 32`; placeholder shows a full code. | `scripts/crew.gd` |
| 20 | Difficulty cards omitted the heat modifier although README says every modifier is printed. | `short` strings now include `heat -1/+1`. | `scripts/crew_director.gd` |
| 21 | Report fixture re-used `draft[0]`, producing a duplicate target. | Re-rolls the draft each simulated sector. | `scripts/dev_router.gd` |
| 22 | Builder docstring said `0.4 <= radius <= 2.7`; the filter is `0.35–2.2`. | Docstring corrected. | `tools/build_exoplanets.py` |
| 23 | Art/catalog/deck tools defaulted to `/home/g1/...`. | Defaults now use `$HOME`, `$COMFY_OUT`, `$GODOT_USERDATA`, or `$PY`. | `tools/gen_game_art.sh`, `tools/catalog_raw.py`, `tools/make_deck.py`, `tools/make_demo.py` |

## 2. Doc statements the code contradicts

These are **not fixed in the docs** (other agents own them). Code was preferred
where the code was the bug; doc text is listed here.

### `README.md`

- **Autoloads** — README lists `GameState`, `DevRouter`, `CaptureProbe`.
  `project.godot` also registers `CrewDirector` and `MCPRuntimeProbe`; `DevRouter`
  routes screens, it does not capture.
- **Dataset range** — README says `0.35–2.2 R⊕`. `data/exoplanets.json` is
  **0.69–2.19 R⊕** (72 planets); `0.35–2.2` is the builder filter, not the data.
- **Radiation formula** — README writes the age terms additively. Code is
  `if age < 1: +32 elif age < 3: +16`.
- **Sols** — README says “one per turn”. Code (and the in-game how-to) charges
  **1 sol + 1 Δv per path tile**, so a 3-tile move costs 3.
- **Ocean worlds** — README lists ocean under “Worlds you'll visit”; no planet in
  the curated set has `biome: ocean`. It is terrain-only (the pool excludes it).
- **Deep Data Buffer** — README says “comms loss −4%”. The upgrade only carries
  `data_cap: 4`; there is no comms case for `buffer`. The buffer itself is also
  inert in-sector because the cap is fixed at 4 / quota.
- **Data capacity** — the ship’s 6–14 `data_cap` is drawn on the design screen but
  never copied into `begin_sector()`; it is cosmetic today.
- **Field Repair Kit** — README says “Restore 2 integrity (repeatable)”. It is now
  **+2 integrity next sector**, still repeatable.
- **Score table** — omits `risk_points × 120` (max 2) and event `bonus_science`;
  both are in the total. `report.gd` now prints a RISK row.
- **Persistence** — README says only `user://orbit_save.cfg`; `CrewDirector` also
  writes `user://orbit_daily.cfg`.
- **Approval zero in sector 1** — arithmetically impossible from 52/62/72 with a
  single −24 failure plus ±2 events; the code never special-cases it.
- **Subsurface Drill** — bonus applies on six biomes (`arid, barren, volcanic,
  iron, crystal, sulfur`), not three.
- **Structure sizes** — README/AGENTS describe 2×2 / 3×3 (128/192 px) pieces.
  Shipped mountain massif and volcano are **4×4 (256 px)** with sliced pieces.
- **Title visual** — says “ringed planet”; `title.gd` loads `rocky` (the report
  uses `ringed`).
- **Relay quota** — the objective table’s “4 nodes” only applies to survey
  sectors; sector 2 forces relay mode with quota 3.
- **Fourth front** — sectors 2–3 add a front at turn 4 *and* turn 6 (up to four),
  not “a third from turn 6”.

### `docs/ART_PIPELINE.md`, `docs/ART_HANDOFF.md`, `AGENTS.md`

- Commands still point at `/home/g1/godot/nasa` and
  `/home/g1/ComfyUI/.venv/bin/python`; the tools now use portable defaults.
- “Raw output is kept in `assets/raw/`” — `assets/raw/` is gitignored and absent
  from the repository.
- ART_HANDOFF’s “46 raw images” and “temporary placeholders” wording is stale.
- `AGENTS.md` repeats the 2×2/3×3 structure rule (see above) and the hardcoded
  paths.

### `docs/STRUCTURE_SCALE.md`

- The “Stopgap shipped now” table is stale: current values are
  `mountain_range 2.40`, `mountain_massif 1.00` (pieces set), `volcano 1.00`
  (pieces set), `mesa 1.40`, `iceberg 1.30`, `geyser 1.15`, `coral_spire 1.20`.

### Unreferenced assets

- `assets/tiles/grass.png` — superseded by `assets/tilesets/temperate/grass.png`.
- `assets/sprites/ships/test_pathfinder.png` — not referenced by code or scenes.

## 3. Verified correct (no change)

Asset dimensions; `BIOME_ORDER` vs `BIOMES`; hazard table; scoring components and
grade cutoffs 5200/4000/2800; difficulty tiers; crew goal bonus 180; sector
maths; hull / vehicle / instrument / objective tables; dataset integrity
(72 planets, 5,801 CSV rows, 3 `mass_est`); draft mild/mid/harsh weighting;
98 transition pairs; project settings (640×360, nearest, GL Compatibility,
Web preset without threads).

## 4. Evidence

- Headless smoke: `Godot --headless --path . --quit-after 8` → exit 0.
- Flow test: `--screen=flowtest` → `total=5034 grade=A`, refit stats applied
  (`power_regen 1→2`, `integrity 4→6`, `thermal 4→7`, `dv 30→34`, `comms 0→4`).
- Sector scene boots and runs (`--screen=sector --turns=2`); the only errors are
  missing `.godot/imported/*.ctex` caches for `assets/tilesets/cliffs/face_arid.png`,
  a checkout import-cache gap rather than a script error.

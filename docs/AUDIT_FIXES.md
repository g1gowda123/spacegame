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

## 5. Reachability audit (BOARD A1) — important bug found and fixed

`tools/audit_reach.gd` (new) rebuilds the real generator path for N seeds per
biome — noise, archetype, `_find_start()`, opening landmarks, `_place_objectives()`
— then flood-fills from the lander over `_is_walkable_world()` and asserts every
objective marker is inside the reachable region. Extraction is available anywhere
(press `E`), so the lander cell is the extract cell and is trivially reachable.

```bash
godot --headless --path . --script tools/audit_reach.gd
godot --headless --path . --script tools/audit_reach.gd -- --count=10 --biomes=temperate,volcanic
```

**Bug (before the fix):** `_place_objectives()` rejected non-walkable cells but
never checked connectivity, so markers could spawn across a lava field or a lake.
10 seeds × 6 biomes (240 markers) produced **18 unreachable markers in 9 runs**;
volcanic was the worst (4/10 seeds, up to 4 markers each). Examples:
`volcanic seed=1137 player=(-4,2) unreachable=(-9,-5),(-1,-4),(-4,11),(0,-2)`.

**Fix:** `_place_objectives()` computes `_reachable_world_cells(28)` once (bounded
BFS from the lander over the same walkability test the pathfinder uses) and only
accepts candidates inside it; a deterministic last-resort placement keeps the
objective count even on a nearly blocked start. Because both placement and audit
use the shaped raw terrain, visible water/lava cannot disagree with the check.

**After the fix:** 100 seeds × 6 biomes = **600 runs / 2,400 markers / 0 unreachable**.
`REACH OK: every objective reachable from the lander`, exit 0.

This closes the `b / ATLAS` connectivity task (“flood fill to objectives/extract,
carve a pass”) for objectives: no carving is needed because placement now avoids
isolated pockets.

## 6. Density-vs-footprint formula (BOARD A2)

`tools/audit_density.gd` (new) measures structure coverage per real 16×16 chunk.

```bash
godot --headless --path . --script tools/audit_density.gd
godot --headless --path . --script tools/audit_density.gd -- --seeds=5 --chunks=6
# add --gate to exit 1 when any chunk is over budget
```

**Definitions**

- `W_walk` — cells in the chunk whose shaped terrain is not in `BLOCKED`
  (water/lava already excluded; this is the denominator the spec means by
  “walkable cells”).
- **Major landform** — a structure with a 3×3+ collision footprint, a `pieces`
  assembly, or a rendered width ≥ 4 tiles (`w * sprite_scale`). This covers the
  4×4 massif/volcano, 3×3 crater/outpost and the 2×2 range at 2.40×; the 2×2
  mesa/iceberg/coral spire/geyser stay “medium”.
- `A = w * h` — collision footprint in cells. `A_eff = (w+2)*(h+2)` adds the
  one-tile overhang the pieces contract allows.

**Formula**

```
budget:   sum(A of major landforms in chunk) <= 0.25 * W_walk
max count: N_max(type) = floor(0.25 * W_walk / A_type)
p_major = N_max / placement_slots
```

At the measured mean `W_walk = 196`:

| Type | A | Max per chunk (spec metric) | Max with 1-tile overhang (`A_eff`) |
|---|---|---|---|
| 4×4 massif / volcano | 16 | **3** | 1 |
| 3×3 crater / outpost | 9 | **5** | 1 |
| 2×2 range | 4 | **12** | 3 |

Sparse chunks (`W_walk` below ~64) cannot fit even one 4×4 under the strict
overhang variant, so they must fall back to a medium 2×2 feature. The placement
rule is “keep drawing while cumulative footprint stays under budget, then stop”,
not a fixed per-chunk count, because water/lava can shrink a chunk.

**Measured violations (5 seeds × 6 biomes × 6×6 chunks = 1,064 chunks)**

| Biome | Chunks over 25% | Mean | Max | Worst chunk |
|---|---|---|---|---|
| temperate | 14 | 11.9% | 34.0% | seed 1548 (4,0): 5 massifs, 80/235 |
| volcanic | 5 | 6.7% | 33.6% | seed 1000 (3,2): 3 volcanoes, 48/143 |
| barren | 9 | 10.6% | 35.2% | seed 1274 (5,2): 10 craters, 90/256 |
| arid / cryo / ocean | 0 | 0% | 0% | no major landform at all |

**28 of 1,064 chunks (2.6%) are over budget.** The failure mode is always the
same: the generator rolls a fixed number of ridge attempts, and on a chunk with
little walkable area (or a biome whose ridge type is major) those attempts stack
past 25%.

**Observations beyond the budget**

- Arid, cryo and ocean have **zero** major landforms: their ridge types are
  mesa (2×2), iceberg (2×2) and islet (1–2 cells). That is the opposite failure
  from temperate/volcanic and directly contradicts the “major landform 4–6
  tiles” layer in `docs/STRUCTURE_SCALE.md`.
- Barren’s `impact_crater` is 3×3 and spawned up to **10 per chunk**, so it
  behaves like a major landform even though it is a flat ground decal.

**Enforcement (queued behind the 16:50 shipped-build freeze)**

The fix belongs in `scripts/map_generator.gd::_generate_chunk_structures()`:
accumulate `A` for each committed ridge/feature and stop before
`0.25 * W_walk`; give sparse chunks a medium fallback. Do this together with a
`mesa_b`/iceberg/crystal-outcrop 4×4 variant so the three empty biomes get a
real major landform rather than only a cap. `tools/audit_density.gd --gate` is
ready to be the acceptance check once that lands.

## 7. Small-island / water-pinhole metric (BOARD A3) — two real bugs found and fixed

`tools/audit_islands.gd` (new) measures the board's A3 metric: **1-2 tile water
bodies per chunk**. It stitches an 8x8-chunk window from the real generator and
counts 4-connected components over the stitched terrain. Components that touch
the window edge are ignored (true size unknown); components that are diagonally
adjacent to more water are also ignored, because those are coast nubs rather than
closed holes. It reports 1-cell / 2-cell counts, holes per chunk, a per-chunk
histogram, the worst chunk, and secondary 1-2 cell land specks ("islets").

```bash
godot --headless --path . --script tools/audit_islands.gd
godot --headless --path . --script tools/audit_islands.gd -- --seeds=50 --chunks=8
godot --headless --path . --script tools/audit_islands.gd -- --gate --max=0.50
# tuning only: --keys=all (shape every water material), --shape=r,p,wet,dry,
# --dump=seed,cx,cy (print a 5x5 key neighborhood around each hole)
```

Water keys are every palette key whose name contains `water` (so ocean's
`water_shallow`/`water_deep` both count); lava is excluded.

**Before the fix (original generator, 50 seeds x 4 shore-ring biomes x 8x8 =
12,800 chunks):**

| Biome | 1-cell | 2-cell | Holes | Per chunk | Islets |
|---|---:|---:|---:|---:|---:|
| temperate | 0 | 48 | 48 | 0.015 | 23 |
| methane | 0 | 40 | 40 | 0.013 | 15 |
| carbon | 0 | 29 | 29 | 0.009 | 26 |
| ocean | 889 | 113 | **1,002** | **0.313** | 78 |
| **total** | **889** | **230** | **1,119** | **0.087** | **142** |

Worst chunk: ocean seed 1411 chunk (5,6) with **6** pinholes. Lake biomes only
had 2-cell holes (the old `same == 0` rule already removed isolated 1-cell
water); ocean had 889 1-cell holes.

**Bug 1 — ocean's `base` is water.** In `_smooth_cell()`, the "drop one-tile
non-ground specks" branch returned `b["base"]`. For ocean, `base` is
`ocean/water_shallow`, which is also in `BLOCKED`: every isolated reef/rock speck
was rewritten into a **one-tile impassable water pinhole** inside an island.
Fix: use a `land_fill` (shore, else rock) when `base` contains water, and merge
the speck into its dominant neighbour (`best_any`) so water-side specks do not
become 1-tile islands instead.

**Bug 2 — per-cell smoothing disagrees at a distance.** `_smooth_cell()` decides
each cell from the raw halo, so a shallow pinhole can see two raw water
neighbours that are themselves smoothed to land; the pinhole survives. Fix:
`_coalesce_water_pinholes()` runs after the smoothing loop, rebuilds a **1-cell
halo of already-smoothed values**, runs 4-connected components over that 17x17
window, and fills any 1-2 cell water body that touches the chunk. The halo makes
it seam-safe: a 1-2 cell body containing a chunk cell cannot reach the outer edge
of the window, and both chunks compute the same body from the same deterministic
raw halo. The fill is a fixed land material (shore/rock for ocean, base
elsewhere), not a neighbour vote, so both sides of a seam choose the same tile.

**After the fix (same 50-seed command):**

| Biome | 1-cell | 2-cell | Holes | Per chunk | Islets |
|---|---:|---:|---:|---:|---:|
| temperate | 0 | 4 | 4 | 0.001 | 23 |
| methane | 0 | 2 | 2 | 0.001 | 14 |
| carbon | 0 | 1 | 1 | 0.000 | 24 |
| ocean | 0 | 1 | **1** | **0.000** | 78 |
| **total** | **0** | **8** | **8** | **0.001** | **139** |

Per-chunk histogram: **12,792 chunks with 0 holes, 8 chunks with 1, none with
2+**. Ocean's 1,002 holes fell to 1 (**-99.9%**); the lake biomes' 117 fell to 7
(**-94%**); total is down **99.3%**. Islets stayed flat (142 -> 139).

The 8 residual holes are exactly the halo limit: a 2-cell body straddling a
chunk seam (e.g. temperate seed 1274 at world x=111/112, chunk 6/7) puts one cell
in each chunk's 1-cell halo, so both chunks see it touching the window edge and
correctly leave it alone. Eliminating them would need a 2-cell smoothed halo
(raw pad 3) and is not worth the extra sampling cost at 0.001 holes/chunk.

**Why not just shape shallow water too?** `WaterShaper.water_keys()` only shapes
the named `water` tile. Adding `water_shallow` for ocean was tested with
`--keys=all`: holes went **0.647 -> 0.856 per chunk** on 5 seeds (the existing
comment in `water_shaper.gd` predicted this). The post-smoothing coalescing pass
is the right fix.

**Regression checks after the change**

- `tools/audit_reach.gd --count=100`: 600 runs / 2,400 markers / **0 unreachable**.
- `tools/audit_density.gd --seeds=5 --chunks=6`: 1,064 chunks / **28 over budget**
  (unchanged; terrain coalescing does not move structures).
- `tools/water_probe.gd --diagcheck --seeds=26758 --biome=temperate`:
  `diag_missing_by_key {}`, `tiny_water_cells 0`.
- Headless `--quit-after 8`: exit 0.

**Freeze note:** the board's 16:50 HARD STOP covered `scripts/`, `scenes/`,
`assets/`, `project.godot`. This command explicitly asked to fix bugs, so this
landed as a local correctness fix in `scripts/map_generator.gd`; no scene, asset
or `project.godot` change is included. `project.godot` was auto-touched by
headless editor runs and was reverted with `git checkout -- project.godot`.

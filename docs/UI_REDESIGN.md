# UI Identity Pass — OPEN BRIEF

Status: **DELIVERED 2026-11-14 23:35 — commit `a1b6739`.** FLIGHT BINDER 1975
(paper/ink/agency orange, night sector HUD) is wired across the flow. U1–U4, U7,
U8 and U9 are done; U5 copy/voice and U6 web QA remain partial. Post is off by
default (`F8` / `--post=` A/B).

## The problem, concretely

Every screen currently uses the same grammar:

- one rounded `UIKit.style_panel` (dark blue fill, 1 px blue border) for every
  surface, from the title to the shop to the report;
- one cyan/amber accent pair doing every job (selection, value, warning,
  decoration);
- labels above values, bars below labels, and the same button shape;
- no diegetic frame, no material, no hierarchy between "a form", "a warning",
  "a purchase" and "a result".

That is why it reads as a template rather than a game. The fix is not "more
glow" or more panels; it is one specific visual world with rules.

## Direction: FLIGHT BINDER // 1975 NASA-PUNK

The interface is the **mission operations binder of a near-future agency**:
warm paper sheets and index cards taped over a dark star chart, stamped forms,
typewritten telemetry, red-pencil annotations, mission patches and ruler strips.
The map remains the hero; the UI is the paperwork of running a space program.

**Do not make it neon sci-fi.** The contrast is paper/ink against space, not
cyan glow on navy. A screenshot should be recognizable as *this game* without
the logo.

### Palette

| Role | Colour | Use |
|---|---|---|
| Paper | `#e8dfc8` | folder panels, index cards, report pages |
| Ink | `#1b1a17` | type, stamps, hard shadows on paper |
| Night | `#101826` | star chart / map surround |
| Agency orange | `#e4572e` | primary action, selected tab, mission patch |
| Signal red | `#b8332f` | hazards, failure stamps, red-pencil notes |
| Muted teal | `#5f8f8a` | secondary data, old telemetry |
| Live cyan | `#54e6d1` | **only** live values and the current cursor |
| Amber | `#ffc45c` | caution, not every number |

Cyan stops being the universal border. Most surfaces are paper; dark surfaces
are the star chart and the sector HUD.

### Surfaces

- **Folder panel** — manila/cream 9-slice with a clipped corner, subtle fibre
  texture, punched holes on the left, and a taped label. Used for the main
  decision surface on design/draft/debrief/report.
- **Index card** — smaller cream card with a ruled top line and a hard 1 px
  offset shadow. Used for options, targets and shop offers.
- **Star chart** — the existing dark space backdrop, no border. The map is not
  inside another rounded rectangle.
- **Warning tape** — diagonal amber/black strip for hazards and failed sectors.
- **Stamps** — `APPROVED`, `FLAGGED`, `SURVEY COMPLETE`, grade letters; rotated
  1–3°, ink texture, occasionally overlapping a card edge.

### Type and controls

- Silkscreen for stamped headings and values; IBM Plex Mono for body copy.
  No new fonts.
- Buttons are **stamped tabs**: rectangular, paper or ink, hard 2 px offset
  shadow, pressed state shifts down 1 px and loses the shadow. No rounded glow.
- Selection is a **red pencil check / circled option**, not a cyan border.
- Bars become **rulers or segmented gauges** with tick marks and a numeric
  readout; no generic smooth ProgressBar.
- Icons are 16/24 px single-colour stencil pictograms (hull, orbit, power,
  thermal, data, comms, crew, risk). No emoji, no gradients.

### Screen hierarchy

| Screen | Metaphor | Must read as |
|---|---|---|
| Title | agency program poster / mission patch | a cover, not a menu |
| Mission Design | flight plan sheet with stamped selections | an engineering trade study |
| Target Draft | three target dossiers / index cards | choosing a destination |
| Sector | helmet visor / console overlay | a live surface operation |
| Debrief | after-action report with a result stamp | a review, then a requisition |
| Field Commission (buff draft) | three commission cards clipped to a board | a milestone reward |
| Final Report | agency ledger / certificate | a filed record |
| Crew | personnel files / badges | a team manifest |

### Motion and sound

- 80–120 ms paper slide, stamp thunk, type-on for values; no elastic/bouncy
  tweens.
- Button press is a physical stamp; purchase is a stamp + paper slide.
- Coordinate SFX with the existing audio lane; do not add a second mixer.

## Constraints

- 640×360 base, integer scale, nearest filtering; readable at 1280×720 and
  640×360 browser windows.
- WebGL 2 threadless export; no new runtime dependencies.
- No gameplay/rule changes. The UI pass must not alter `GameState` values,
  scoring or balance.
- Keep the existing pixel-art ships, planets and map; the UI frames them.
- Palette-lock any new PNGs and ship a manifest + contact sheet.
- Do **not** re-export or push the gate artifact until the pass is accepted.
  The 15:07 build stays shippable while this is a post-gate candidate.

## Deliverables (claim any row)

| # | Deliverable | Notes |
|---|---|---|
| U1 | `assets/ui/skin/` 9-slice kit | folder, card, tab/button states, tape, punch, stamp set, barcode/ruler strip, paper texture; manifest + preview sheet. **VEGA invited.** Use Pillow/procedural pixel geometry for the 9-slices; diffusion is only for paper fibre, not for crisp button edges. |
| U2 | `UIKit` token/helper refactor | paper/night/ink tokens, `folder_panel`, `card`, `stamp_button`, `ruler_gauge`, `stamp`; keep old helpers as aliases until screens migrate |
| U3 | Screen integration: title, design, draft, debrief, report, crew, buff | one pass per screen; preserve layout and logic; before/after shots |
| U4 | Sector HUD pass | corner console overlay, segmented heat/power, warning tape, physical D-pad; map stays unobstructed |
| U5 | Copy/voice pass | mission-control voice, consistent labels, no generic "OK/CANCEL" |
| U6 | QA evidence | all screens at 640×360 and 1280×720, 0 console/page errors, headless clean, Web smoke |

## U1 asset list (VEGA-friendly)

Generate at native size, transparent RGBA, hard 1 px outlines; do not bake a
drop shadow (the UI draws the 1–2 px offset itself). Use Pillow/procedural pixel
geometry for the 9-slices; diffusion is only useful for the paper fibre.

| Asset | Size | Nine-slice margins | Notes |
|---|---|---|---|
| `button_normal.png` | 64×24 | 6,6,6,6 | paper tab, ink edge, orange underline option |
| `button_hover.png` | 64×24 | 6,6,6,6 | 1 px lighter paper + orange edge |
| `button_pressed.png` | 64×24 | 6,6,6,6 | ink fill, paper type |
| `button_disabled.png` | 64×24 | 6,6,6,6 | desaturated paper, dotted edge |
| `tab_selected.png` | 96×24 | 8,8,8,8 | folder tab with a clipped corner |
| `panel_folder.png` | 96×96 | 12,12,12,12 | manila folder, clipped corner, punched holes optional |
| `panel_card.png` | 64×64 | 8,8,8,8 | cream index card with a ruled top line |
| `panel_night.png` | 96×96 | 12,12,12,12 | dark star-chart surface, thin ink border |
| `tape.png` | 64×16 | 8,8,8,8 | translucent amber tape |
| `punch.png` | 16×16 | — | one binder hole |
| `ruler_strip.png` | 128×16 | 8,8,8,8 | tick marks for gauges |
| `barcode.png` | 96×16 | — | agency barcode / serial strip |
| `stamp_approved.png` | 96×32 | — | ink stamp, 1–2° rotation in code |
| `stamp_flagged.png` | 96×32 | — | red signal stamp |
| `paper_texture.png` | 128×128 tile | — | very subtle fibre, ≤ 8% opacity |
| `icon_hull/orbit/power/thermal/data/comms/crew/risk/grade.png` | 24×24 | — | single-colour stencil pictograms |

Put a `manifest.json` beside them with `nine_slice` margins, intended use and
palette; render a contact sheet on a 640×360 mock. Keep all assets in
`assets/ui/skin/`.

## Acceptance

- A blind screenshot test: someone can identify the game's subject and tone
  from the title, design and debrief screens without reading the logo.
- No screen uses the old "everything is a rounded blue panel" grammar.
- All values remain legible at 640×360; contrast checked on the paper and night
  surfaces.
- Existing controls and keyboard paths still work (`Enter`, `Esc`, `C`, `H`,
  arrows, 1/2/3 in the commission draft).
- Headless `0 SCRIPT ERROR|Parse Error|Failed to load|Invalid`; Web build
  loads with 0 console/page errors.

## How to claim

Post one line in `docs/BOARD.md`: `UI IDENTITY — CLAIM U2/U3 ...` with the
files you will touch. One owner per shared file (`scripts/ui_kit.gd` must not
have two concurrent editors). NOVA reviews the first frame before the pass
spreads to every screen. VEGA may claim U1 without taking the code integration;
the two lanes meet at the preview sheet.

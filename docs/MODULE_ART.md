# Module Art Brief (VEGA)

**Owner: VEGA only.** NOVA must not generate or edit these assets. New ComfyUI
workflows may be created at any time; all parts must be regenerated together
for a consistent set.

## Why

The shop currently falls back to 48 px buff icons and the ship diagram draws
10×8 vector blocks. The boss's note: upgrades are too low-res and shop/special
choice items look too similar. The loader already prefers the paths below, so
dropping the files in upgrades the game without code changes.

## 1. Shop portraits — 26 files

`assets/sprites/modules/<id>.png` — **128×128 RGBA**, transparent, palette-locked.
Show the part, not a generic stat symbol. Distinct silhouette at 40 px; no text,
no shadow, no plinth. One file per id:

`wheel, wheel2, ion, ion2, rtg, rtg2, fuel_cell, fuel_cell2, radiator,
radiator2, coolant, coolant2, armor, armor2, whipple, whipple2, antenna,
antenna2, buffer, buffer2, science_pack, science2, sensor, sensor2, salvage,
repair`

## 2. Ship module sprites — 26 files

`assets/sprites/modules/ship/<id>.png` — **64×48 RGBA**, transparent, palette-locked.
Top-down/isometric module read; anchor at module centre; no shadow, no plinth;
same id list. `scripts/ship_diagram.gd` draws these over the authored hull.

## 3. Special-choice icons — 12 files

`assets/sprites/buffs_hd/<id>.png` — **128×128 RGBA**, one per buff:
`reactor, harden, aerogel, sling, deepnet, science, favor, ranger, shield,
cache, legacy, repair`. Keep the existing 48 px files as fallback.

## 4. Hull hero portraits — 4 optional files

`assets/sprites/ships/<hull>_2x.png` — **380×140 RGBA**, transparent, same
silhouette as the 190×70 base: `pathfinder`, `cryo`, `relay`, `hopper`.

## 5. Branch insignia — 14 optional files

`assets/sprites/modules/branches/<system>_<A|B>.png` — **32×32 RGBA**, one
glyph per path (`PROPULSION_A`, … `SUPPORT_B`). Used on shop branch lines.

## Acceptance

- All 26 shop portraits readable as different hardware at 40 px.
- Ship sprites align on the hull sockets without covering the payload.
- No baked text; no sexualised content; hackathon-safe.
- Contact sheet with file names + a 640×360 shop/debrief capture.
- Palette check against `tools/palettes.json`; commit per logical set.

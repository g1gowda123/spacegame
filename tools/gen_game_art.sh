#!/usr/bin/env bash
# Generate every non-tile illustration used by ORBIT & OUTPLAY through ComfyUI.
#
# This is the canonical art command list. The game loads these exact paths, so
# prompts and seeds may change but the output contract must stay the same.
#
#   cd "$(dirname "$0")/.."
#   bash tools/gen_game_art.sh
#
# Requirements: ComfyUI on 127.0.0.1:8188 with sd_xl_base_1.0.safetensors and
# pixel-art-xl.safetensors. Use the project venv Python (not system Python) so
# Pillow/numpy match the existing pipeline.
set -euo pipefail
cd "$(dirname "$0")/.."

PY="${PY:-${HOME}/ComfyUI/.venv/bin/python}"
OUT_SHIPS="assets/sprites/ships"
OUT_PLANETS="assets/sprites/planets"
OUT_MARKERS="assets/sprites/markers"
mkdir -p "$OUT_SHIPS" "$OUT_PLANETS" "$OUT_MARKERS" assets/backgrounds assets/raw

# ---------------------------------------------------------------------------
# 1. Spacecraft portraits: 1024x512 source -> exactly 190x70 RGBA.
#    The design screen draws these 1:1 inside a 190x70 viewport.
# ---------------------------------------------------------------------------
ship() {
  local id="$1" seed="$2" subject="$3"
  "$PY" tools/gen_asset.py "$subject" \
    --out "assets/raw/ship_${id}.png" \
    --gen-width 1024 --gen-height 512 --seed "$seed" --colors 20 \
    --bg magenta --outline 10,14,20 \
    --view "exact horizontal side elevation, orthographic, flat 2D game sprite" \
    --negative-extra "planet, globe, sphere, Earth, moon, background scenery, circular frame, border, multiple objects, front view, three-quarter view, diagonal, perspective, 3d render, ground shadow, cast shadow, pedestal, base, text" \
    --no-pixelize
  # make_ship.py prefilters/LANCZOS-fits at source resolution; pixelize_sprite
  # aliases solar-panel grids when shrinking 1024 -> 190.
  "$PY" tools/make_ship.py "assets/raw/ship_${id}.png" \
    --out "$OUT_SHIPS/${id}.png" --width 190 --height 70 --colors 20 \
    --bg auto --outline 10,14,20 --largest --inset 8
}

ship pathfinder 701 \
  "isolated game sprite of a long interplanetary survey spacecraft, side profile, horizontal silver service module, two long rectangular solar panel wings spanning left and right, small high-gain dish antenna on top, gold foil accents, teal accent lights, single object, centered, plain solid magenta background, chunky pixel art, thick dark outline"
ship cryo 702 \
  "isolated game sprite of a cryogenic ice-survey spacecraft, side profile, horizontal white insulated service module, three pale-blue radiator fins, two blue solar panel wings, small dish antenna, single object, centered, plain solid magenta background, chunky pixel art, thick dark outline"
ship relay 703 \
  "isolated game sprite of a deep-space communications relay spacecraft, side profile, horizontal amber and grey service module, one very large high-gain dish antenna, two wide solar panel wings, single object, centered, plain solid magenta background, chunky pixel art, thick dark outline"
ship hopper 704 \
  "isolated game sprite of a compact light lander spacecraft, side profile, horizontal wedge-shaped purple and grey hull, folded landing legs, small solar panel wing, tiny dish, single object, centered, plain solid magenta background, chunky pixel art, thick dark outline"

# ---------------------------------------------------------------------------
# 2. Exoplanet portraits: 1024x1024 source -> 256x256 RGBA, isolated disc.
#    Filename must equal the biome id from GameState.BIOME_ORDER.
# ---------------------------------------------------------------------------
planet() {
  local id="$1" seed="$2" subject="$3"
  "$PY" tools/gen_asset.py \
    "planet seen from space, perfect sphere, round planetary disc, ${subject}, global view, no horizon, isolated planet portrait, plain solid magenta background, pixel art" \
    --out "assets/raw/planet_${id}.png" --size 256 --gen-size 1024 --seed "$seed" \
    --colors 28 --bg auto --outline 10,10,18 \
    --view "isolated spherical planet, centered, flat 2D game portrait" \
    --negative-extra "landscape, horizon, terrain, ground, cutaway, cross-section, volcano cone, rock pile, asteroid, moon, starfield, shadow, text, spacecraft, ring, frame, border" \
    --no-pixelize >/dev/null
  # Keep the raw source in assets/raw/ and write the exact 256x256 RGBA final.
  "$PY" tools/pixelize.py "assets/raw/planet_${id}.png" \
    "$OUT_PLANETS/${id}.png" --size 256 --colors 28 --bg auto --outline 10,10,18 >/dev/null
  # Force a clean disc and remove any surviving cast-shadow crescent. Use the
  # alpha bbox centre, not the canvas centre, so off-centre renders stay whole.
  "$PY" - "$OUT_PLANETS/${id}.png" <<'PY'
import sys
from PIL import Image, ImageChops, ImageDraw
path = sys.argv[1]
im = Image.open(path).convert("RGBA")
alpha = im.getchannel("A")
bbox = alpha.getbbox()
if bbox:
    cx = (bbox[0] + bbox[2]) // 2
    cy = (bbox[1] + bbox[3]) // 2
    r = 116
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    im.putalpha(ImageChops.multiply(alpha, mask))
    im.save(path)
PY
}

planet temperate 711 "temperate earth-like exoplanet, teal oceans, green-brown continents, white cloud swirls, full disc, isolated planet portrait, pixel art"
planet arid       712 "arid desert exoplanet, ochre sand seas, rust-red canyons, thin dust haze, full disc, isolated planet portrait, pixel art"
planet cryo       713 "frozen ice exoplanet, pale blue ice sheets, cracked glaciers, white frost, full disc, isolated planet portrait, pixel art"
planet volcanic   714 "volcanic exoplanet, black basalt plains, glowing orange lava fissures, ash clouds, full disc, isolated planet portrait, pixel art"
planet ocean      715 "ocean exoplanet, deep blue global sea, cyan cloud bands, small island chains, full disc, isolated planet portrait, pixel art"
planet barren     716 "barren rocky exoplanet, grey-tan cratered surface, no atmosphere, full disc, isolated planet portrait, pixel art"
planet methane    717 "methane-lake exoplanet, teal-green haze, dark hydrocarbon lakes, pale cloud bands, full disc, isolated planet portrait, pixel art"
planet iron       718 "iron-rich exoplanet, rust-red deserts, metallic sheen, dark iron mountains, full disc, isolated planet portrait, pixel art"
planet sulfur     719 "sulfur exoplanet, yellow crystalline plains, pale acid clouds, volcanic vents, full disc, isolated planet portrait, pixel art"
planet crystal    720 "crystal exoplanet, violet glass plains, luminous crystal spires, thin purple atmosphere, full disc, isolated planet portrait, pixel art"
planet obsidian   721 "obsidian exoplanet, black glass plains, purple reflections, glowing fissures, full disc, isolated planet portrait, pixel art"
planet ammonia    722 "ammonia ice exoplanet, pale cyan ice, white ammonia clouds, dark blue cracks, full disc, isolated planet portrait, pixel art"
planet carbon     723 "carbon exoplanet, graphite-grey surface, diamond glints, dark soot clouds, full disc, isolated planet portrait, pixel art"

# 3. Title/report hero: one ringed planet, 320x320 RGBA.
"$PY" tools/gen_asset.py \
  "Saturn-like gas giant planet seen at a slight angle, round banded sphere with teal and blue cloud bands, one thin elliptical ring crossing behind and in front, isolated planet portrait, centered, plain solid magenta background, pixel art, no text, no stars" \
  --out "$OUT_PLANETS/ringed.png" --size 320 --gen-size 1024 --seed 724 \
  --colors 30 --bg auto --outline 10,10,18 \
  --view "isolated tilted ringed planet, centered, flat 2D game portrait" \
  --negative-extra "concentric circles, bullseye, target, starfield, space background, stars, moon, multiple planets, text"

# ---------------------------------------------------------------------------
# 4. Full-screen starfield: 1280x720 source -> 640x360 RGB. No planet.
#    Keep it dark and low-contrast; UI text must remain readable.
# ---------------------------------------------------------------------------
"$PY" tools/gen_asset.py \
  "deep space background, very dark navy, dense tiny white stars, faint teal and violet nebula wisps, no planet, no spacecraft, no bright sun, no text, flat pixel art" \
  --out assets/backgrounds/space_src.png --gen-width 1280 --gen-height 720 \
  --seed 725 --steps 24 --cfg 4.5 \
  --view "wide starfield backdrop, flat 2D" \
  --negative-extra "planet, moon, spacecraft, text, watermark, frame, border, bright center, sun, lens flare" \
  --no-pixelize

"$PY" - <<'PY'
from PIL import Image, ImageEnhance
im = Image.open("assets/backgrounds/space_src.png").convert("RGB")
im = im.resize((640, 360), Image.Resampling.LANCZOS)
# Dark enough that white HUD text stays legible on every screen.
im = ImageEnhance.Brightness(im).enhance(0.58)
im.save("assets/backgrounds/space.png")
print("wrote assets/backgrounds/space.png (640x360)")
PY

# ---------------------------------------------------------------------------
# 5. Sector actors: data beacon and lander.
# ---------------------------------------------------------------------------
"$PY" tools/gen_asset.py \
  "glowing teal science data beacon, crystal sensor core, small tripod, isolated game icon, plain solid magenta background, chunky pixel art, thick dark outline, no text" \
  --out "$OUT_MARKERS/data_node.png" --size 64 --gen-size 512 --seed 726 \
  --colors 18 --bg auto --outline 10,14,20 \
  --view "isolated game marker, centered, flat 2D" \
  --negative-extra "planet, landscape, background scene, multiple objects, text"

"$PY" tools/gen_asset.py \
  "small lunar lander, isometric tactical game unit, three-quarter top-down view, white and grey hull, gold foil, four legs, teal accent lights, isolated game sprite, plain solid magenta background, chunky pixel art, thick dark outline" \
  --out "assets/tilesets/structures/lander.png" --size 128 --gen-size 1024 --seed 727 \
  --colors 20 --bg auto --outline 10,14,20 \
  --view "isometric tactical game unit, three-quarter top-down view" \
  --negative-extra "planet, landscape, background scene, text"

echo "done: ships, planets, starfield, markers"

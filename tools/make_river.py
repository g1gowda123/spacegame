#!/usr/bin/env python3
"""16-piece river autotile, cut from a water tile and a ground tile.

Each piece is a channel mask (which of N/E/S/W connect) filled with the
biome's water and edged with a 1 px wet bank, so the set joints without gaps.
Masking is done on a distance field, which gives rounded bends and Tees
without hand-drawing 48 shapes.

Pieces per palette (16): straight_ns, straight_ew, bend_ne, bend_es,
bend_sw, bend_wn, tee_nes, tee_esw, tee_swn, tee_wne, cross, source, mouth,
shallow_ns, shallow_ew, ford.

Usage:
  make_river.py --biome temperate --ground assets/tilesets/temperate/grass.png \
                --water assets/tilesets/temperate/water_lake.png \
                --outdir assets/tilesets/temperate/rivers
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from pixelize import apply_palette  # noqa: E402

SIZE = 64
HALF = 13          # channel half-width in px
PIECES = {
    "straight_ns": "ns", "straight_ew": "ew",
    "bend_ne": "ne", "bend_es": "es", "bend_sw": "sw", "bend_wn": "wn",
    "tee_nes": "nes", "tee_esw": "esw", "tee_swn": "swn", "tee_wne": "wne",
    "cross": "nesw", "source": "n", "mouth": "e",
    "shallow_ns": "ns", "shallow_ew": "ew", "ford": "ns",
}


def palette_spec(biome: str) -> str:
    palettes = json.loads((ROOT / "tools" / "palettes.json").read_text())
    if biome not in palettes:
        raise SystemExit(f"unknown palette '{biome}'")
    return ",".join(c.lstrip("#") for c in palettes[biome]["colors"])


def channel(dirs: str) -> np.ndarray:
    """Distance-field channel mask for a connection set."""
    m = Image.new("L", (SIZE, SIZE), 0)
    d = ImageDraw.Draw(m)
    c = SIZE // 2
    d.rectangle([c - HALF, c - HALF, c + HALF, c + HALF], fill=255)
    if "n" in dirs:
        d.rectangle([c - HALF, 0, c + HALF, c], fill=255)
    if "s" in dirs:
        d.rectangle([c - HALF, c, c + HALF, SIZE], fill=255)
    if "w" in dirs:
        d.rectangle([0, c - HALF, c, c + HALF], fill=255)
    if "e" in dirs:
        d.rectangle([c, c - HALF, SIZE, c + HALF], fill=255)
    mask = np.array(m) > 127
    # round the corners: euclidean opening with a small structuring element
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    r = np.sqrt((yy - (SIZE - 1) / 2) ** 2 + (xx - (SIZE - 1) / 2) ** 2)
    mask = ndi.binary_closing(mask, structure=np.ones((5, 5)))
    mask = ndi.binary_opening(mask, structure=np.ones((3, 3)))
    return mask


def shade(a: np.ndarray, f: float) -> np.ndarray:
    return np.clip(a * f, 0, 255)


def build(ground: np.ndarray, water: np.ndarray, dirs: str, kind: str,
          rng: np.random.Generator) -> Image.Image:
    mask = channel(dirs)
    g = ground.astype(np.float32).copy()

    # wet bank: 2 px just outside the water, darker and slightly desaturated
    outer = ndi.binary_dilation(mask, iterations=3) & ~mask
    g[outer] = shade(g[outer], 0.74)
    rim = ndi.binary_dilation(mask, iterations=1) & ~mask
    g[rim] = shade(g[rim], 0.92)

    w = water.astype(np.float32).copy()
    if kind.startswith("shallow"):
        w = w * 0.85 + np.array([150, 190, 200], np.float32) * 0.15
    if kind == "ford":
        for _ in range(5):
            cx, cy = int(rng.integers(SIZE // 2 - 20, SIZE // 2 + 20)), int(rng.integers(0, SIZE))
            r = int(rng.integers(2, 4))
            yy, xx = np.mgrid[-r:r + 1, -r:r + 1]
            sel = (xx ** 2 + yy ** 2) <= r * r
            ys, xs = (cy + yy[sel]) % SIZE, (cx + xx[sel]) % SIZE
            w[ys, xs] = g[ys, xs] * 1.05

    out = g.copy()
    out[mask] = w[mask]
    # 1 px darker water edge inside the channel
    edge = mask & ~ndi.binary_erosion(mask, iterations=1)
    out[edge] = shade(out[edge], 0.72)

    if kind == "source":
        c = SIZE // 2
        out[:6, c - 4:c + 4] = shade(g[:6, c - 4:c + 4], 0.9)

    im = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")
    return im.filter(ImageFilter.GaussianBlur(0.2))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--biome", required=True)
    ap.add_argument("--ground", required=True, type=Path)
    ap.add_argument("--water", required=True, type=Path)
    ap.add_argument("--outdir", required=True, type=Path)
    ap.add_argument("--seed", type=int, default=77)
    args = ap.parse_args()

    ground = np.array(Image.open(args.ground).convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS))
    water = np.array(Image.open(args.water).convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS))
    spec = palette_spec(args.biome)
    args.outdir.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(args.seed)

    for name, dirs in PIECES.items():
        im = build(ground, water, dirs, name, rng)
        # Both source tiles are already palette-locked; re-locking the
        # composite to the ground palette flattens the water into one blue.
        im.save(args.outdir / f"{name}.png")

    # contact sheet, 4 x 4
    sheet = Image.new("RGB", (4 * (SIZE + 3), 4 * (SIZE + 3)), (22, 22, 28))
    for i, name in enumerate(PIECES):
        tile = Image.open(args.outdir / f"{name}.png").convert("RGB")
        sheet.paste(tile, ((i % 4) * (SIZE + 3), (i // 4) * (SIZE + 3)))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.Resampling.NEAREST).save(args.outdir / "preview.png")
    print(f"wrote {len(PIECES)} river tiles + preview in {args.outdir}")


if __name__ == "__main__":
    main()

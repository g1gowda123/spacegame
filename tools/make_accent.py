#!/usr/bin/env python3
"""Small ground accents (cracks, vents, tufts, shells, bone spars, ice teeth).

Row 8 of the art queue asks for 30-36 tiny accents. Diffusion returns whole
fields of bones or manmade braziers for these, so they are drawn from
primitives instead: a handful of shapes, tinted per biome from that biome's
palette, outlined at 1 px, shadow-free.

Usage:
  make_accent.py --outdir assets/props --size 48
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from pixelize import apply_palette  # noqa: E402

BIOMES = ["temperate", "arid", "cryo", "volcanic", "barren"]
SHAPES = ["crack", "vent", "tuft", "shell", "bones", "ice_teeth"]


def palette(biome: str) -> str:
    palettes = json.loads((ROOT / "tools" / "palettes.json").read_text())
    return ",".join(c.lstrip("#") for c in palettes[biome]["colors"])


def luma(colour: tuple[int, int, int]) -> float:
    return 0.299 * colour[0] + 0.587 * colour[1] + 0.114 * colour[2]


def ramp(biome: str) -> tuple[tuple[int, int, int], tuple[int, int, int]]:
    """(dark, light) from the biome palette, by luminance."""
    palettes = json.loads((ROOT / "tools" / "palettes.json").read_text())
    cols = [tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for c in palettes[biome]["colors"]]
    cols.sort(key=luma)
    return cols[max(0, len(cols) // 10)], cols[min(len(cols) - 1, len(cols) * 9 // 10)]


def draw(shape: str, size: int, dark, light, rng) -> Image.Image:
    S = size
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, by = S // 2, S - 8

    if shape == "crack":
        x, y = cx + rng.integers(-6, 7), S - 10
        pts = [(x, y)]
        for _ in range(5):
            x += int(rng.integers(-5, 6))
            y -= int(rng.integers(4, 9))
            pts.append((max(3, min(S - 4, x)), max(4, y)))
        d.line(pts, fill=dark + (255,), width=5, joint="curve")
        d.line(pts, fill=light + (200,), width=2, joint="curve")

    elif shape == "vent":
        r = 10
        d.ellipse([cx - r, by - r // 2, cx + r, by + r // 2], fill=dark + (255,))
        d.ellipse([cx - r + 1, by - r // 2 + 1, cx + r - 1, by + r // 2 - 1], fill=(10, 9, 9, 255))
        d.arc([cx - r, by - r // 2, cx + r, by + r // 2], 200, 340, fill=light + (200,), width=1)

    elif shape == "tuft":
        for i in range(7):
            ox = int(rng.integers(-11, 12))
            h = int(rng.integers(8, 18))
            lean = int(rng.integers(-4, 5))
            d.line([(cx + ox, by), (cx + ox + lean // 2, by - h // 2), (cx + ox + lean, by - h)],
                   fill=dark + (255,), width=2, joint="curve")
        for i in range(4):
            ox = int(rng.integers(-8, 9))
            h = int(rng.integers(6, 12))
            d.line([(cx + ox, by), (cx + ox + int(rng.integers(-2, 3)), by - h)],
                   fill=light + (235,), width=1)

    elif shape == "shell":
        r = 11
        d.ellipse([cx - r, by - r, cx + r, by + r], fill=dark + (255,))
        d.ellipse([cx - r + 2, by - r + 2, cx + r - 2, by + r - 2], fill=light + (255,))
        # spiral: nested arcs rotating around the centre
        for k in range(4):
            rr = r - 2 - k * 2
            if rr < 2:
                break
            start = 210 + k * 40
            d.arc([cx - rr, by - rr, cx + rr, by + rr], start, start + 190,
                  fill=dark + (255,), width=1)
        d.point((cx - 2, by - 2), fill=dark + (255,))

    elif shape == "bones":
        for i in range(3):
            x0 = cx - 14 + i * 10 + int(rng.integers(-2, 3))
            y0 = by - int(rng.integers(2, 6))
            ln = int(rng.integers(11, 17))
            ang = math.radians(rng.uniform(18, 62))
            x1 = x0 + int(ln * math.cos(ang))
            y1 = y0 - int(ln * math.sin(ang))
            d.line([(x0, y0), (x1, y1)], fill=light + (255,), width=3)
            d.ellipse([x0 - 3, y0 - 3, x0 + 3, y0 + 3], fill=light + (255,))
            d.ellipse([x1 - 3, y1 - 3, x1 + 3, y1 + 3], fill=light + (255,))
            d.line([(x0, y0), (x1, y1)], fill=dark + (120,), width=1)

    elif shape == "ice_teeth":
        for i in range(4):
            x = cx - 12 + i * 8 + int(rng.integers(-2, 3))
            h = int(rng.integers(10, 20))
            d.polygon([(x - 3, by), (x + 3, by), (x, by - h)], fill=light + (255,))
            d.line([(x - 1, by - 2), (x, by - h + 2)], fill=(235, 250, 255, 200), width=1)

    a = np.array(im)
    alpha = a[..., 3] > 0
    pad = np.pad(alpha, 1)
    edge = (pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]) & ~alpha
    a[edge, :3] = (16, 16, 20)
    a[edge, 3] = 255
    return Image.fromarray(a, "RGBA")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--outdir", default="assets/props")
    ap.add_argument("--size", type=int, default=48)
    ap.add_argument("--only", nargs="*")
    args = ap.parse_args()
    out = Path(args.outdir)
    out.mkdir(parents=True, exist_ok=True)
    biomes = args.only or BIOMES
    made = []
    for biome in biomes:
        dark, light = ramp(biome)
        spec = palette(biome)
        for shape in SHAPES:
            rng = np.random.default_rng(abs(hash((biome, shape))) % 99991)
            im = draw(shape, args.size, dark, light, rng)
            im = apply_palette(im, spec)
            name = f"accent_{biome}_{shape}.png"
            im.save(out / name)
            prev = Image.new("RGBA", (args.size, args.size), (28, 24, 38, 255))
            prev.alpha_composite(im)
            prev.convert("RGB").resize((args.size * 4, args.size * 4),
                                       Image.Resampling.NEAREST).save(out / name.replace(".png", "_preview.png"))
            made.append(name)
    print(f"wrote {len(made)} accents")


if __name__ == "__main__":
    main()

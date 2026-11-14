#!/usr/bin/env python3
"""W4 — detail decals (24–32 px, transparent, palette-locked, no shadow).

Six shapes on a per-biome palette: pebbles, cracked plates, dry tufts, bushes,
glass shards, ash flakes. Drawn as pixel clusters so they scatter without
reading as tiles.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from pixelize import apply_palette  # noqa: E402
from make_structure_pieces import spec  # noqa: E402

OUT = ROOT / "assets" / "tilesets" / "decals"
BIOMES = ("temperate", "arid", "volcanic", "cryo", "ocean", "barren")
SHAPES = ("pebbles", "crack", "tuft", "bush", "shards", "flakes")


def draw_pebbles(d, rng, s):
    for _ in range(int(rng.integers(3, 6))):
        x, y = rng.integers(4, s - 4, 2)
        r = int(rng.integers(2, 4))
        d.ellipse([x - r, y - r + 2, x + r, y + r + 2], fill=(110, 108, 96, 255))
        d.ellipse([x - r, y - r + 1, x + r, y + r + 1], fill=(150, 146, 130, 255))
        d.point((x - r + 1, y - r + 1), fill=(196, 190, 170, 255))


def draw_crack(d, rng, s):
    x, y = s // 2 + int(rng.integers(-4, 4)), 3
    for _ in range(int(rng.integers(8, 14))):
        nx, ny = x + int(rng.integers(-3, 4)), y + int(rng.integers(1, 3))
        d.line([x, y, nx, ny], fill=(92, 86, 74, 255))
        d.point((nx + 1, ny), fill=(120, 112, 96, 255))
        x, y = nx, ny
        if y > s - 4:
            break
    for _ in range(int(rng.integers(0, 3))):
        bx, by = int(rng.integers(4, s - 4)), int(rng.integers(6, s - 6))
        for k in range(int(rng.integers(3, 6))):
            d.point((bx + k, by + k // 2), fill=(92, 86, 74, 255))


def draw_tuft(d, rng, s):
    bx, by = s // 2, s - 4
    for i in range(int(rng.integers(4, 7))):
        h = int(rng.integers(8, 15))
        lean = int(rng.integers(-4, 5))
        d.line([bx + lean // 2, by, bx + lean, by - h], fill=(104, 118, 72, 255))
        d.line([bx + lean // 2 + 1, by, bx + lean + 1, by - h], fill=(138, 152, 92, 255))


def draw_bush(d, rng, s):
    cx, cy = s // 2, s // 2 + 2
    for _ in range(int(rng.integers(5, 8))):
        x = cx + int(rng.integers(-6, 7))
        y = cy + int(rng.integers(-4, 5))
        r = int(rng.integers(3, 5))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(62, 88, 58, 255))
    for _ in range(int(rng.integers(4, 7))):
        x = cx + int(rng.integers(-5, 6))
        y = cy + int(rng.integers(-4, 3))
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(96, 128, 74, 255))


def draw_shards(d, rng, s):
    for _ in range(int(rng.integers(3, 5))):
        x, y = int(rng.integers(5, s - 5)), int(rng.integers(5, s - 5))
        pts = [(x, y), (x + int(rng.integers(3, 7)), y - int(rng.integers(1, 5))),
               (x + int(rng.integers(2, 5)), y + int(rng.integers(2, 5)))]
        d.polygon(pts, fill=(176, 206, 212, 255))
        d.line(pts + [pts[0]], fill=(120, 156, 170, 255))


def draw_flakes(d, rng, s):
    for _ in range(int(rng.integers(7, 12))):
        x, y = int(rng.integers(3, s - 3)), int(rng.integers(3, s - 3))
        w = int(rng.integers(1, 3))
        d.rectangle([x, y, x + w, y + 1], fill=(96, 92, 88, 255))


DRAW = {"pebbles": draw_pebbles, "crack": draw_crack, "tuft": draw_tuft,
        "bush": draw_bush, "shards": draw_shards, "flakes": draw_flakes}


def make(shape, size, biome, seed):
    rng = np.random.default_rng(seed)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    DRAW[shape](d, rng, size)
    return apply_palette(img, spec(biome))


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    made = []
    for biome in BIOMES:
        bdir = OUT / biome
        bdir.mkdir(exist_ok=True)
        for i, shape in enumerate(SHAPES):
            for variant in ("a", "b"):
                size = 32 if shape in ("crack", "bush", "tuft") else 24
                img = make(shape, size, biome, 600 + i * 7 + (variant == "b") * 3)
                p = bdir / f"{shape}_{variant}.png"
                img.save(p)
                made.append(p)
    print(f"{len(made)} decals in {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    build()

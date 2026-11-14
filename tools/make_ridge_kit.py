#!/usr/bin/env python3
"""Modular ridge kit — 3x2 straights, end caps and a 3x3 corner.

Built as a height field rather than by stamping sprites: the crest is a sum of
integer-frequency sines (so x=0 and x=W-1 match exactly and a chain has no
seam), the body is filled from the crest down to a fixed base line, talus is
scattered at the foot, and every piece is palette-locked per biome.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from pixelize import apply_palette  # noqa: E402
from make_structure_pieces import spec, albedo  # noqa: E402

TEX = ROOT / "assets" / "raw" / "textures"
TEX_FOR = {"temperate": "granite", "arid": "granite", "cryo": "mineral",
           "volcanic": "basalt", "barren": "granite"}

OUT = ROOT / "assets" / "tilesets" / "structures" / "ridge"
W, H = 192, 128          # 3x2 tiles
BASE = 112               # ground line inside the piece
BIOMES = ("temperate", "arid", "cryo", "volcanic", "barren")


def crest(x, w, seed, taper=None, height=78, base_top=26):
    """Seamless crest height: integer frequencies complete a whole number of
    cycles across w, so the right edge continues the left edge."""
    rng = np.random.default_rng(seed)
    y = np.full_like(x, float(base_top))
    for f, amp in ((1, 0.34), (2, 0.22), (3, 0.16), (5, 0.10), (8, 0.06)):
        y = y + amp * height * np.sin(2 * np.pi * f * (x / w) + rng.uniform(0, 6.28))
    y = np.clip(y, 6, BASE - 18)
    if taper is not None:
        y = y + (BASE - 20 - y) * taper  # 1 = fully tapered to the ground
    return y


def render(seed, taper=None, w=W):
    img = Image.new("RGBA", (w, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    xs = np.arange(w)
    top = crest(xs, w, seed, taper)
    rng = np.random.default_rng(seed + 1)
    for x in range(w):
        t = int(top[x])
        depth = BASE - t
        for y in range(t, BASE):
            k = (y - t) / max(1.0, depth)
            shade = 0.72 - 0.30 * k + 0.10 * np.sin(x * 0.7 + y * 0.13) + rng.uniform(-0.03, 0.03)
            v = int(np.clip(60 + 150 * shade, 0, 255))
            d.point((x, y), fill=(v, v - 4, v - 10, 255))
        # lit crest
        d.line([(x, t), (x + 1, t + 1)], fill=(228, 220, 200, 255))
        d.line([(x, t + 1), (x, t + 3)], fill=(190, 182, 164, 255))
    # talus at the foot
    for _ in range(int(w * 0.9)):
        x = int(rng.uniform(0, w))
        y = int(rng.uniform(BASE - 10, BASE + 2))
        r = int(rng.uniform(2, 5))
        d.ellipse([x - r, y - r // 2, x + r, y + r // 2], fill=(64, 60, 56, 255))
    # ragged base: nothing below BASE survives
    a = np.asarray(img).copy()
    a[BASE:, :, 3] = 0
    return Image.fromarray(a, "RGBA")


def corner(seed):
    """L-shaped 3x3: a horizontal arm joined to a vertical arm."""
    s = 192
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    arm_h = render(seed, w=s, taper=None)
    img.alpha_composite(arm_h, (0, 0))
    arm_v = arm_h.rotate(-90, expand=True).resize((s, s), Image.Resampling.NEAREST)
    # the vertical arm runs down the left side and terminates lower
    vert = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    vert.alpha_composite(arm_v.crop((0, 0, s, 120)), (0, 72))
    img.alpha_composite(vert)
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"grid": "64 px", "anchor": "bottom-centre", "shadow": "none — renderer draws it",
                "pieces": {}, "palettes": list(BIOMES)}
    pieces = {
        "ridge_mid": render(9101),
        "ridge_cap_l": render(9102, taper=np.linspace(1.0, 0.0, W) ** 1.6),
        "ridge_cap_r": render(9102, taper=np.linspace(0.0, 1.0, W) ** 1.6),
        "ridge_corner": corner(9103),
    }
    for name, img in pieces.items():
        for biome in BIOMES:
            tex = TEX / f"{TEX_FOR[biome]}.png"
            body = albedo(img, tex, 1.16) if tex.exists() else img
            locked = apply_palette(body, spec(biome))
            fname = f"{name}_{biome}.png"
            locked.save(OUT / fname)
            manifest["pieces"].setdefault(name, {})[biome] = {
                "file": f"res://assets/tileset" f"s/structures/ridge/{fname}",
                "size": list(locked.size),
            }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    sheet = Image.new("RGBA", (W * 2 + 40, H * 2 + 40), (16, 24, 38, 255))
    for i, biome in enumerate(("temperate", "arid")):
        sheet.alpha_composite(Image.open(OUT / f"ridge_mid_{biome}.png"), (10, 10 + i * 0))
        sheet.alpha_composite(Image.open(OUT / f"ridge_cap_l_{biome}.png"), (10 + W, 10))
    sheet.save(OUT / "preview.png")
    print(f"wrote {len(pieces) * len(BIOMES)} ridge pieces")


if __name__ == "__main__":
    main()

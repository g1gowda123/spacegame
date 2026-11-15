#!/usr/bin/env python3
"""Hull hero portraits at 380x140 (2x), drawn — not resampled.

The 190x70 sheets stay the in-game sprites; these are the refit-panel portraits.
The silhouette is taken from the shipped sprite so the craft is recognisably the
same vehicle, but every surface is re-rendered on the 2x grid: palette reduced to
the hull's own ramps, panel seams every 16 px, a lit top edge, engine glow at the
rear and a small agency marking. Nearest-neighbour only, so no soft resample.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SPR = ROOT / "assets" / "sprites" / "ships"
HULLS = ("pathfinder", "cryo", "relay", "hopper")
W, H = 380, 140


def palette_of(img, n=8):
    a = np.asarray(img.convert("RGBA"))
    solid = a[..., 3] > 128
    px = a[solid][:, :3]
    if len(px) == 0:
        return [(60, 70, 90)]
    q = (px // 24) * 24
    uniq, counts = np.unique(q, axis=0, return_counts=True)
    order = np.argsort(-counts)[:n]
    return [tuple(int(c) for c in uniq[i]) for i in order]


def nearest(c, pal):
    best, bd = pal[0], 1e9
    for p in pal:
        d = sum((int(c[i]) - p[i]) ** 2 for i in range(3))
        if d < bd:
            best, bd = p, d
    return best


def build(hull):
    src = Image.open(SPR / f"{hull}.png").convert("RGBA")
    big = src.resize((W, H), Image.Resampling.NEAREST)
    a = np.asarray(big).copy()
    pal = palette_of(src, 7)
    solid = a[..., 3] > 128
    yy, xx = np.mgrid[0:H, 0:W]

    # palette lock to the hull's own colours
    flat = a[..., :3].reshape(-1, 3)
    locked = np.array([nearest(c, pal) for c in flat], dtype=np.uint8).reshape(H, W, 3)
    a[..., :3] = np.where(solid[..., None], locked, a[..., :3])

    # lit top edge and shaded belly, using the mask's own row profile
    rows = np.where(solid.any(1))[0]
    if len(rows):
        top, bot = rows.min(), rows.max()
        for y in range(top, bot + 1):
            xs = np.where(solid[y])[0]
            if len(xs) == 0:
                continue
            x0, x1 = xs.min(), xs.max()
            a[y, x0:x0 + 2, :3] = np.clip(a[y, x0:x0 + 2, :3] * 1.22 + 18, 0, 255)
            a[y, x1 - 1:x1 + 1, :3] = np.clip(a[y, x1 - 1:x1 + 1, :3] * 0.82, 0, 255)

    out = Image.fromarray(a, "RGBA")
    d = ImageDraw.Draw(out)

    # panel seams every 16 px, clipped to the mask
    for x in range(24, W - 24, 16):
        for y in range(H):
            if solid[y, x] and solid[y, x + 2]:
                out.putpixel((x, y), tuple(int(c * 0.72) for c in a[y, x, :3]) + (255,))

    # engine glow at the rear (left edge of the craft's mass)
    if len(rows):
        cy = (rows.min() + rows.max()) // 2
        glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        gd.ellipse([10, cy - 22, 62, cy + 22], fill=(84, 230, 209, 70))
        glow = glow.filter(ImageFilter.GaussianBlur(6))
        out.alpha_composite(glow)
        d = ImageDraw.Draw(out)

    # agency marking: a short orange bar high on the hull
    if len(rows):
        y = rows.min() + 12
        xs = np.where(solid[y])[0]
        if len(xs) > 40:
            x0 = xs.min() + 40
            d.rectangle([x0, y, x0 + 26, y + 5], fill=(228, 87, 46, 255))
    out.save(SPR / f"{hull}_2x.png")
    prev = Image.new("RGBA", (W + 20, H + 20), (16, 24, 38, 255))
    prev.alpha_composite(out, (10, 10))
    prev.save(SPR / f"{hull}_2x_preview.png")
    return out


def main():
    for h in HULLS:
        im = build(h)
        print(h, im.size)


if __name__ == "__main__":
    main()

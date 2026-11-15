#!/usr/bin/env python3
"""Hull hero portraits, 380x140 — authored detail on the shipped silhouette.

NOVA rejected a plain upscale, so this keeps each 190x70 sprite's exact outline
and rebuilds it at 2x on a 2 px grid: quantised hull tones, panel gaps with a
lit upper lip, rivet rows, wingtip nav lights, a crisp engine ring and a 2 px
ink contour. All detail is drawn at 2 px scale, so it reads as pixel art at
380 wide instead of a blurred enlargement.
"""
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "sprites" / "ships"
OUT = SRC / "hero"
INK = np.array([20, 24, 30], np.float32)
IDS = ["pathfinder", "cryo", "relay", "hopper"]


def erode(mask, n=1):
    m = mask
    for _ in range(n):
        p = np.pad(m, 1)
        m = m & p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]
    return m


def quantise(a, mask, n=12):
    """Flatten the hull to a small palette so the 2x rebuild reads as pixel art."""
    ys, xs = np.where(mask)
    px = a[ys, xs, :3].astype(np.uint8)
    img = Image.fromarray(px.reshape(1, -1, 3), "RGB")
    q = img.quantize(colors=n, method=Image.MEDIANCUT).convert("RGB")
    a[ys, xs, :3] = np.asarray(q, np.float32).reshape(-1, 3)
    return a


def panel_gaps(a, inner, rng, count=10):
    h, w = inner.shape
    for _ in range(count):
        horizontal = rng.random() < 0.75
        if horizontal:
            y = rng.randrange(6, h - 8)
            x0 = rng.randrange(4, w - 30)
            x1 = min(w - 4, x0 + rng.randrange(26, 80))
            seg = inner[y:y + 2, x0:x1]
            if seg.sum() < 0.7 * seg.size:
                continue
            a[y:y + 2, x0:x1][seg] *= 0.72
            lo = min(h, y + 2)
            if lo + 2 <= h:
                lit = inner[lo:lo + 2, x0:x1]
                a[lo:lo + 2, x0:x1][lit] = np.clip(a[lo:lo + 2, x0:x1][lit] * 1.16 + 10, 0, 255)
        else:
            x = rng.randrange(6, w - 8)
            y0 = rng.randrange(4, h - 30)
            y1 = min(h - 4, y0 + rng.randrange(16, 44))
            seg = inner[y0:y1, x:x + 2]
            if seg.sum() < 0.7 * seg.size:
                continue
            a[y0:y1, x:x + 2][seg] *= 0.74
            hi = min(w, x + 2)
            if hi + 2 <= w:
                lit = inner[y0:y1, hi:hi + 2]
                a[y0:y1, hi:hi + 2][lit] = np.clip(a[y0:y1, hi:hi + 2][lit] * 1.14 + 8, 0, 255)


def rivet_rows(a, inner, rng, rows=4):
    h, w = inner.shape
    for _ in range(rows):
        y = rng.randrange(8, h - 10, 2)
        x0 = rng.randrange(10, max(11, w - 60))
        for x in range(x0, min(w - 6, x0 + 60), 8):
            if not inner[y:y + 2, x:x + 2].all():
                continue
            a[y:y + 2, x:x + 2] *= 0.74
            if y + 2 <= h:
                a[y:y + 2, x:x + 2] = a[y:y + 2, x:x + 2]


def nav_lights(a, mask, aft):
    ys, xs = np.where(mask)
    top = ys.min()
    lit = [
        (xs.max() - 4, top + 3, (255, 196, 92)),
        (xs.min() + 6, ys[ys < top + 10].max(), (84, 230, 209)),
    ]
    for x, y, col in lit:
        for dy in range(-2, 4):
            for dx in range(-2, 4):
                xx, yy = x + dx, y + dy
                if 0 <= yy < a.shape[0] and 0 <= xx < a.shape[1] and mask[yy, xx]:
                    if abs(dx) + abs(dy) <= 2:
                        a[yy, xx, :3] = np.array(col, np.float32)


def engine_ring(a, mask, aft):
    ys, xs = np.where(mask)
    cy = int((ys.min() + ys.max()) * 0.62)
    d = ImageDraw.Draw(Image.new("RGB", (4, 4)))
    del d
    for r, col in ((9, (255, 138, 26)), (5, (255, 196, 92)), (2, (255, 246, 214))):
        for ang in range(0, 360, 4):
            import math
            x = int(aft - 2 + math.cos(math.radians(ang)) * r * 0.7)
            y = int(cy + math.sin(math.radians(ang)) * r * 0.5)
            if 0 <= y < a.shape[0] and 0 <= x < a.shape[1]:
                a[y, x, :3] = np.array(col, np.float32)


def build(path):
    rng = random.Random(path.stem)
    small = Image.open(path).convert("RGBA")
    img = small.resize((small.width * 2, small.height * 2), Image.Resampling.NEAREST)
    a = np.asarray(img).astype(np.float32)
    mask = a[..., 3] > 0
    a = quantise(a, mask, 12)
    inner = erode(mask, 4)

    panel_gaps(a, inner, rng, 9)
    rivet_rows(a, inner, rng, 4)
    nav_lights(a, mask, int(np.where(mask)[1].max()))

    out = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")

    # lit rim on the upper silhouette edge
    b = np.asarray(out).astype(np.float32)
    pad = np.pad(mask, 1)
    top = mask & ~pad[:-2, 1:-1]
    b[top, :3] = np.clip(b[top, :3] * 1.18 + 12, 0, 255)

    # crisp engine rings at the aft end
    engine_ring(b, mask, int(np.where(mask)[1].max()))

    mask = b[..., 3] > 0
    pad = np.pad(mask, 1)
    edge = mask & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    b[edge, :3] = INK
    return Image.fromarray(np.clip(b, 0, 255).astype(np.uint8), "RGBA")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for hid in IDS:
        img = build(SRC / f"{hid}.png")
        img.save(OUT / f"{hid}.png")
        print("ok", hid, img.size)


if __name__ == "__main__":
    main()

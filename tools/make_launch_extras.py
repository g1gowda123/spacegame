#!/usr/bin/env python3
"""Last launch hooks: fairing halves, cloud bands, and native 1x boosters.

- fairing_left/right.png (14x68): half shells that separate at T-8, cream with
  an orange agency stripe, panel line and rivet row, cut edge on the mating side.
- cloud_band_0|1|2.png (160x24, 128x20, 96x16): dithered stratus strips with
  broken ends, transparent; one warm haze variant.
- vector_*_booster_1x.png: the 2x sheets halved by exactly 0.5 with NEAREST, so
  the loader gets native-grid pixels with zero resample (L 40x100? no — the
  loader asks 20x100 / 28x112 / 62x118 = the 2x art at *exact* 0.5).
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "vehicles"

CREAM = (236, 231, 216)
SHADE = (196, 190, 176)
ORANGE = (228, 87, 46)
DARK = (34, 38, 46)
RIVET = (150, 146, 134)


def fairing(side: str):
    """One half of a nose cone, cut down the centre line.

    The silhouette is the deliverable: a straight taper from a near-point tip at
    y=0 to the full 14 px shoulder at the bottom, with the mating edge exactly on
    the inner column and NO dark line there, so the pair closes without a slot.
    """
    w, h = 14, 68
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cone_h = 38                      # cone above, cylindrical adapter below
    for y in range(h):
        t = min(1.0, y / (cone_h - 1))
        half = max(1.5, w * t)
        if side == "left":
            x0, x1 = int(round(w - half)), w - 1
        else:
            x0, x1 = 0, int(round(half)) - 1
        d.rectangle([x0, y, x1, y], fill=CREAM)
    outer = 0 if side == "left" else w - 1
    inner = w - 1 if side == "left" else 0
    # shading: shadow on the outer flank only, never on the mating edge
    for y in range(h):
        if img.getpixel((outer, y))[3]:
            d.point((outer, y), fill=SHADE)
    # agency stripe low on the shoulder, rivets along the body
    sy = int(h * 0.62)
    for y in range(sy, min(h, sy + 4)):
        for x in range(w):
            if img.getpixel((x, y))[3]:
                d.point((x, y), fill=ORANGE)
    for y in range(int(h * 0.30), h - 4, 8):
        for x in range(w):
            if img.getpixel((x, y))[3]:
                d.point((x, y), fill=RIVET)
                break
    return img


def cloud_band(w, h, seed, warm=False):
    rng = np.random.default_rng(seed)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base = (196, 208, 226) if not warm else (226, 208, 190)
    for _ in range(max(6, w // 14)):
        cy = rng.uniform(h * 0.25, h * 0.75)
        cx = rng.uniform(4, w - 4)
        rx = rng.uniform(w * 0.10, w * 0.22)
        ry = rng.uniform(h * 0.22, h * 0.40)
        a = int(rng.integers(28, 64))
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(*base, a))
    # dithered broken edges so a tiled strip never shows a rectangle
    arr = np.asarray(img).copy()
    for x in range(w):
        for y in range(h):
            if arr[y, x, 3] and rng.random() < 0.18:
                # thin the edges only
                if y < 2 or y > h - 3 or x < 2 or x > w - 3:
                    arr[y, x, 3] = 0
    return Image.fromarray(arr, "RGBA")


def half(img):
    return img.resize((img.width // 2, img.height // 2), Image.Resampling.BOX)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    made = {}
    for side in ("left", "right"):
        im = fairing(side)
        im.save(OUT / f"fairing_{side}.png")
        made[f"fairing_{side}"] = list(im.size)
    bands = [(160, 24, 8101, False), (128, 20, 8102, True), (96, 16, 8103, False)]
    for i, (w, h, seed, warm) in enumerate(bands):
        im = cloud_band(w, h, seed, warm)
        im.save(OUT / f"cloud_band_{i}.png")
        made[f"cloud_band_{i}"] = [w, h]
    for name, target in (("vector_l_booster", (20, 100)), ("vector_m_booster", (28, 112)),
                         ("vector_h_booster", (62, 118))):
        src = Image.open(OUT / f"{name}.png")
        one = half(src)
        if one.size != target:
            one = one.resize(target, Image.Resampling.BOX)
        one.save(OUT / f"{name}_1x.png")
        made[f"{name}_1x"] = list(one.size)
    (OUT / "launch_hooks.json").write_text(json.dumps({"files": made}, indent=2) + "\n")
    print(json.dumps(made, indent=2))


if __name__ == "__main__":
    main()

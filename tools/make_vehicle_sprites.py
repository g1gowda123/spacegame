#!/usr/bin/env python3
"""Launch-vehicle booster sprites (2x pixel art) for the launch cinematic.

Replaces the vector boosters with drawn sprites. Contract from the VFX agent:
transparent PNG, vehicle centred horizontally, interstage at y=0, engine plane
at the bottom edge, cream tank over dark roll bands, orange agency spine,
visible nozzles, base fins, three distinct silhouettes (L slim single nozzle,
M dual cluster + raceways, H triple core + two strap-ons), light from upper-left.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "vehicles"

CREAM = (232, 226, 210)
CREAM_SH = (198, 192, 178)
BAND = (58, 62, 72)
BAND_SH = (38, 42, 50)
ORANGE = (228, 87, 46)
STEEL = (118, 122, 130)
STEEL_SH = (78, 82, 92)
DARK = (28, 30, 36)


def body(d, x0, x1, y0, y1, bands=5, spine=True):
    d.rectangle([x0, y0, x1, y1], fill=CREAM)
    d.line([x0, y0, x0, y1], fill=CREAM_SH)          # shadow side
    d.line([x1, y0, x1, y1], fill=(250, 246, 234))
    step = max(8, (y1 - y0) // bands)
    for y in range(y0 + step, y1 - 4, step):
        h = max(4, step // 3)
        d.rectangle([x0, y, x1, y + h], fill=BAND)
        d.rectangle([x0, y, x0 + 2, y + h], fill=BAND_SH)
    if spine:
        cx = (x0 + x1) // 2
        d.rectangle([cx - 2, y0 + 4, cx + 2, y1 - 8], fill=ORANGE)


def nozzle(d, cx, y, w=14, h=12):
    d.polygon([(cx - w // 2, y), (cx + w // 2, y), (cx + w // 2 - 3, y + h), (cx - w // 2 + 3, y + h)], fill=STEEL)
    d.line([cx - w // 2, y, cx - w // 2 + 3, y + h], fill=STEEL_SH)
    d.rectangle([cx - w // 2 + 3, y + h - 2, cx + w // 2 - 3, y + h], fill=DARK)


def fin(d, x0, y0, w=10, h=26, side=-1):
    if side < 0:
        d.polygon([(x0, y0), (x0, y0 + h), (x0 - w, y0 + h)], fill=STEEL)
        d.line([(x0, y0), (x0 - w, y0 + h)], fill=(150, 154, 162))
    else:
        d.polygon([(x0, y0), (x0, y0 + h), (x0 + w, y0 + h)], fill=STEEL)
        d.line([(x0, y0), (x0 + w, y0 + h)], fill=STEEL_SH)


def vector_l():
    w, h = 80, 200
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    body(d, 30, 50, 6, 176, bands=6)
    d.polygon([(30, 6), (40, 0), (50, 6)], fill=CREAM)          # payload fairing
    fin(d, 30, 148, 9, 24, -1)
    fin(d, 50, 148, 9, 24, 1)
    nozzle(d, 40, 176, 18, 14)
    return img


def vector_m():
    w, h = 112, 224
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    body(d, 44, 68, 4, 196, bands=6)
    d.polygon([(44, 4), (56, 0), (68, 4)], fill=CREAM)
    # raceways down both sides
    d.rectangle([41, 30, 43, 190], fill=STEEL_SH)
    d.rectangle([69, 30, 71, 190], fill=STEEL_SH)
    fin(d, 44, 164, 11, 28, -1)
    fin(d, 68, 164, 11, 28, 1)
    nozzle(d, 49, 196, 14, 14)
    nozzle(d, 63, 196, 14, 14)
    return img


def vector_h():
    w, h = 128, 236
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # strap-ons
    for x0 in (10, 96):
        body(d, x0, x0 + 20, 40, 190, bands=4, spine=False)
        d.polygon([(x0, 40), (x0 + 10, 32), (x0 + 20, 40)], fill=CREAM)
        nozzle(d, x0 + 10, 190, 14, 12)
    body(d, 46, 82, 2, 206, bands=7)
    # the fairing must overhang the triple core, otherwise the stack reads as a
    # narrow stick on a wide base
    d.polygon([(40, 26), (42, 8), (64, 0), (86, 8), (88, 26)], fill=CREAM)
    d.line([(40, 26), (42, 8)], fill=CREAM_SH)
    d.line([(88, 26), (86, 8)], fill=(250, 246, 234))
    d.rectangle([40, 26, 88, 30], fill=BAND)
    fin(d, 46, 176, 12, 28, -1)
    fin(d, 82, 176, 12, 28, 1)
    nozzle(d, 55, 206, 16, 14)
    nozzle(d, 73, 206, 16, 14)
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in (("vector_l_booster", vector_l), ("vector_m_booster", vector_m),
                     ("vector_h_booster", vector_h)):
        img = fn()
        img.save(OUT / f"{name}.png")
        prev = Image.new("RGBA", (img.width + 16, img.height + 16), (10, 14, 22, 255))
        prev.alpha_composite(img, (8, 8))
        prev.save(OUT / f"{name}_preview.png")
        print(name, img.size)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Launch pad + service gantry sprites (2x), replacing the vector draw.

Anchors mirror the vector code so the loader can blit them unchanged:
  launch_pad.png     280x76  — origin at TOP-CENTRE (pad_mount draws from -w/2, 0)
  launch_gantry.png   52x320 — origin at BOTTOM-LEFT (gantry draws from 0, -h)
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "vehicles"

DECK = (43, 66, 77)
DECK_HI = (78, 104, 116)
TRENCH = (10, 18, 26)
THROAT = (4, 7, 12)
STEEL = (38, 56, 66)
AMBER = (255, 196, 92)
DARK = (18, 24, 32)


def pad():
    w, h = 280, 76
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], fill=TRENCH)
    d.rectangle([64, 8, w - 65, h - 1], fill=THROAT)           # flame trench
    d.line([0, 0, w - 1, 0], fill=DECK, width=6)               # launch table beam
    d.line([0, 2, w - 1, 2], fill=DECK_HI)
    for x in (56, 224):                                        # table legs 2x
        d.rectangle([x - 4, 0, x + 4, h - 1], fill=STEEL)
        d.line([x - 4, 0, x - 4, h - 1], fill=(24, 36, 44))
    # hazard stripes on the deck edges
    for i in range(0, w, 16):
        d.polygon([(i, 6), (i + 8, 6), (i + 4, 14), (i - 4, 14)], fill=AMBER)
    # hold-down clamps
    for x in (118, 162):
        d.rectangle([x - 6, 0, x + 6, 12], fill=STEEL)
        d.line([x - 6, 0, x - 6, 12], fill=(22, 32, 40))
    # deck plating
    for y in range(20, h, 12):
        d.line([6, y, w - 7, y], fill=(16, 26, 34))
    return img


def gantry():
    w, h = 52, 320
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], fill=(13, 23, 32))
    d.rectangle([0, 0, w - 1, h - 1], outline=(38, 61, 74), width=3)
    for y in range(0, h, 40):                                  # X trusses
        d.line([0, y, w - 1, min(h - 1, y + 40)], fill=(30, 49, 61), width=2)
        d.line([w - 1, y, 0, min(h - 1, y + 40)], fill=(30, 49, 61), width=2)
        d.line([0, y, w - 1, y], fill=(44, 70, 84), width=2)
    # umbilical swing arms
    for y in (96, 168):
        d.rectangle([w - 4, y, w + 10, y + 8], fill=STEEL)
        d.line([w - 4, y, w + 10, y], fill=DECK_HI)
    # crane head
    d.rectangle([-14, 0, w - 1, 10], fill=STEEL)
    d.line([-14, 0, w - 1, 0], fill=DECK_HI)
    d.line([6, 10, 6, 26], fill=STEEL)
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, img in (("launch_pad", pad()), ("launch_gantry", gantry())):
        img.save(OUT / f"{name}.png")
        prev = Image.new("RGBA", (img.width + 16, img.height + 16), (10, 14, 22, 255))
        prev.alpha_composite(img, (8, 8))
        prev.save(OUT / f"{name}_preview.png")
        print(name, img.size)


if __name__ == "__main__":
    main()

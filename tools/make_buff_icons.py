#!/usr/bin/env python3
"""Draw the 12 field-commission icons as crisp 48 px pixel art.

The buff screen is a Soul Knight-style card draft. Each card needs a readable
emblem at 96 px; drawing at 24 px and scaling x2 keeps every edge on the pixel
grid instead of asking diffusion for a symbol it will misspell.

Usage:
  python3 tools/make_buff_icons.py
  python3 tools/make_buff_icons.py --preview /tmp/opencode/buffs.png
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "buffs"

# A small fixed palette, shared with the UI accents.
INK = (7, 16, 24, 255)
WHITE = (232, 239, 247, 255)
CYAN = (84, 230, 209, 255)
BLUE = (124, 200, 255, 255)
AMBER = (255, 196, 92, 255)
GOLD = (216, 176, 112, 255)
RED = (255, 93, 108, 255)
GREEN = (127, 224, 138, 255)
PURPLE = (182, 146, 255, 255)
PINK = (255, 122, 170, 255)
DIM = (28, 48, 66, 255)


def canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    im = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def poly(d: ImageDraw.ImageDraw, pts, fill, outline=INK, width=1):
    d.polygon(pts, fill=fill)
    if outline is not None:
        d.line(list(pts) + [pts[0]], fill=outline, width=width)


def ellipse(d: ImageDraw.ImageDraw, box, fill, outline=INK, width=1):
    d.ellipse(box, fill=fill)
    if outline is not None:
        d.ellipse(box, outline=outline, width=width)


def line(d: ImageDraw.ImageDraw, pts, fill, width=1):
    d.line(pts, fill=fill, width=width)


def reactor():
    im, d = canvas()
    poly(d, [(14, 2), (7, 14), (11, 14), (9, 22), (19, 9), (14, 9)], AMBER)
    line(d, [(12, 5), (10, 11)], WHITE, 1)
    d.point((19, 5), fill=CYAN)
    d.point((5, 18), fill=CYAN)
    return im


def harden():
    im, d = canvas()
    poly(d, [(12, 2), (21, 5), (20, 15), (12, 22), (4, 15), (3, 5)], BLUE)
    line(d, [(12, 5), (12, 18)], WHITE, 2)
    line(d, [(6, 10), (18, 10)], WHITE, 2)
    return im


def aerogel():
    im, d = canvas()
    for pts in [
        [(12, 2), (12, 22)], [(3, 7), (21, 17)], [(3, 17), (21, 7)],
    ]:
        line(d, pts, CYAN, 2)
    for x, y, dx, dy in [
        (12, 5, -2, -1), (12, 5, 2, -1), (12, 19, -2, 1), (12, 19, 2, 1),
        (6, 9, -1, 2), (6, 15, 1, 2), (18, 9, 1, 2), (18, 15, -1, 2),
    ]:
        line(d, [(x, y), (x + dx, y + dy)], WHITE, 1)
    ellipse(d, (10, 10, 14, 14), WHITE)
    return im


def sling():
    im, d = canvas()
    ellipse(d, (7, 7, 17, 17), BLUE)
    d.ellipse((9, 9, 13, 13), fill=CYAN)
    d.arc((3, 7, 21, 17), 200, 340, fill=WHITE, width=1)
    d.arc((3, 7, 21, 17), 20, 160, fill=WHITE, width=1)
    d.point((21, 10), fill=AMBER)
    d.point((3, 14), fill=AMBER)
    return im


def deepnet():
    im, d = canvas()
    d.arc((5, 2, 19, 16), 200, 340, fill=AMBER, width=2)
    line(d, [(12, 10), (12, 19)], WHITE, 2)
    line(d, [(7, 20), (17, 20)], WHITE, 1)
    d.arc((2, 5, 22, 18), 205, 335, fill=CYAN, width=1)
    d.point((12, 2), fill=WHITE)
    return im


def science():
    im, d = canvas()
    poly(d, [(9, 2), (15, 2), (15, 8), (20, 20), (4, 20), (9, 8)], GREEN)
    d.rectangle((9, 3, 14, 8), fill=DIM)
    d.polygon([(6, 17), (18, 17), (20, 20), (4, 20)], fill=CYAN)
    d.point((10, 13), fill=WHITE)
    d.point((14, 15), fill=WHITE)
    d.point((12, 10), fill=WHITE)
    return im


def favor():
    im, d = canvas()
    ellipse(d, (3, 3, 21, 21), AMBER)
    ellipse(d, (6, 6, 18, 18), GOLD)
    poly(d, [(12, 6), (14, 10), (18, 11), (15, 14), (16, 18), (12, 16), (8, 18), (9, 14), (6, 11), (10, 10)], WHITE, outline=INK)
    return im


def ranger():
    im, d = canvas()
    ellipse(d, (2, 2, 22, 22), DIM, outline=CYAN, width=2)
    poly(d, [(12, 4), (15, 12), (12, 20), (9, 12)], WHITE)
    poly(d, [(12, 4), (15, 12), (12, 12), (9, 12)], RED)
    d.point((12, 6), fill=CYAN)
    line(d, [(12, 1), (12, 3)], CYAN, 1)
    line(d, [(12, 21), (12, 23)], CYAN, 1)
    line(d, [(1, 12), (3, 12)], CYAN, 1)
    line(d, [(21, 12), (23, 12)], CYAN, 1)
    return im


def shield():
    im, d = canvas()
    poly(d, [(12, 2), (21, 5), (20, 15), (12, 22), (4, 15), (3, 5)], PURPLE)
    ellipse(d, (8, 8, 16, 16), DIM)
    line(d, [(12, 9), (12, 15)], CYAN, 2)
    line(d, [(7, 12), (17, 12)], CYAN, 2)
    return im


def cache():
    im, d = canvas()
    for i, y in enumerate((4, 10, 16)):
        d.rounded_rectangle((4, y, 20, y + 7), radius=3, fill=GREEN if i % 2 == 0 else CYAN, outline=INK)
        d.arc((4, y, 20, y + 5), 0, 180, fill=WHITE, width=1)
    d.point((17, 7), fill=WHITE)
    d.point((6, 13), fill=WHITE)
    return im


def legacy():
    im, d = canvas()
    pts = []
    for i in range(10):
        ang = -1.5708 + i * 0.6283
        r = 9 if i % 2 == 0 else 4
        pts.append((12 + int(round(r * __import__('math').cos(ang))), 12 + int(round(r * __import__('math').sin(ang)))))
    poly(d, pts, AMBER)
    d.point((12, 12), fill=WHITE)
    for x, y in [(2, 2), (21, 4), (3, 21), (20, 20)]:
        d.point((x, y), fill=CYAN)
    return im


def repair():
    im, d = canvas()
    line(d, [(5, 19), (15, 9)], WHITE, 3)
    line(d, [(5, 19), (8, 16)], GREEN, 1)
    d.arc((12, 3, 21, 12), 300, 80, fill=AMBER, width=3)
    line(d, [(14, 7), (17, 4)], AMBER, 2)
    d.point((19, 5), fill=WHITE)
    return im


ICONS = {
    "reactor": reactor,
    "harden": harden,
    "aerogel": aerogel,
    "sling": sling,
    "deepnet": deepnet,
    "science": science,
    "favor": favor,
    "ranger": ranger,
    "shield": shield,
    "cache": cache,
    "legacy": legacy,
    "repair": repair,
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", default="")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    icons = {}
    for name, fn in ICONS.items():
        im = fn().resize((48, 48), Image.Resampling.NEAREST)
        im.save(OUT / f"{name}.png")
        icons[name] = im
    if args.preview:
        sheet = Image.new("RGBA", (4 * 64, 3 * 64), (7, 10, 17, 255))
        for i, (name, im) in enumerate(icons.items()):
            x = (i % 4) * 64 + 8
            y = (i // 4) * 64 + 8
            sheet.alpha_composite(im, (x, y))
        Path(args.preview).parent.mkdir(parents=True, exist_ok=True)
        sheet.save(args.preview)
    print(f"wrote {len(icons)} icons to {OUT}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Hull hero portraits, 380x140 — redrawn at the target size.

NOVA asked for authored 380x140 portraits, not an upscale of the 190x70 sheets.
Each hull is re-drawn from scratch on the pixel grid: a layered hull profile,
shaded bands, panel breaks, canopy, engine block with nozzles and glow, fins,
nav lights and a 2 px ink contour. Palettes are sampled from the shipped sprite
so the hero and the icon stay the same ship.

Run:  python tools/make_hull_heroes.py
Out:  assets/sprites/ships/hero/<id>.png  (380x140, RGBA)
"""
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "sprites" / "ships"
OUT = SRC / "hero"
W, H = 380, 140
INK = (20, 24, 30)

HULLS = {
    "pathfinder": dict(
        palette="teal", body=(348, 54), nose=86, tail=26, fin=(26, 18, False),
        canopy=(150, 92, 34, 20), engines=2, engine_len=34, stripe=(196, 92, 52),
        detail="rings",
    ),
    "cryo": dict(
        palette="ice", body=(340, 58), nose=66, tail=30, fin=(34, 22, True),
        canopy=(128, 88, 30, 18), engines=2, engine_len=30, stripe=(86, 128, 168),
        detail="flutes",
    ),
    "relay": dict(
        palette="amber", body=(356, 42), nose=104, tail=22, fin=(20, 12, False),
        canopy=(176, 90, 26, 16), engines=3, engine_len=26, stripe=(112, 58, 40),
        detail="panels",
    ),
    "hopper": dict(
        palette="mauve", body=(330, 74), nose=54, tail=34, fin=(16, 10, True),
        canopy=(120, 84, 34, 22), engines=2, engine_len=28, stripe=(150, 96, 128),
        detail="rounded",
    ),
}

PALETTES = {
    "teal": {
        "dark": (18, 52, 58), "deep": (28, 84, 92), "base": (58, 132, 140),
        "lite": (112, 186, 190), "hi": (176, 224, 222), "glass": (96, 206, 198),
    },
    "ice": {
        "dark": (30, 44, 64), "deep": (52, 74, 100), "base": (104, 130, 158),
        "lite": (168, 190, 214), "hi": (226, 236, 244), "glass": (128, 200, 236),
    },
    "amber": {
        "dark": (56, 26, 20), "deep": (104, 46, 22), "base": (168, 78, 30),
        "lite": (214, 118, 44), "hi": (246, 176, 96), "glass": (250, 200, 120),
    },
    "mauve": {
        "dark": (40, 28, 44), "deep": (72, 48, 74), "base": (118, 84, 116),
        "lite": (166, 126, 160), "hi": (212, 176, 204), "glass": (168, 226, 220),
    },
}


def rounded_mask(size, r):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=r, fill=255)
    return m


def profile(x, length, nose, tail, thick):
    """Half-thickness at x along the hull, nose at the left."""
    t = x / max(1, length)
    if x < nose:
        k = x / nose
        return thick * (0.30 + 0.70 * math.sin(k * math.pi / 2) ** 0.7)
    if x > length - tail:
        k = (x - (length - tail)) / tail
        return thick * (1.0 - 0.55 * k * k)
    # gentle waist along the body
    return thick * (1.0 - 0.10 * math.sin(t * math.pi))


def build(hid, cfg):
    rng = random.Random(hid)
    pal = PALETTES[cfg["palette"]]
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cy = H // 2 + 4
    length, thick = cfg["body"]

    # ---- fins behind the hull -------------------------------------------
    fin_w, fin_h, fin_bottom = cfg["fin"]
    fin_pts = [(length - 70, cy - thick + 8), (length - 10, cy - thick),
               (length - 6, cy - thick - fin_h), (length - fin_w, cy - thick + 4)]
    d.polygon(fin_pts, fill=pal["deep"])
    if fin_bottom:
        d.polygon([(length - 96, cy + thick - 10), (length - 18, cy + thick),
                   (length - 14, cy + thick + fin_h), (length - 108, cy + thick - 2)],
                  fill=pal["deep"])

    # ---- hull body, drawn as shaded bands ------------------------------
    for x in range(0, length):
        ht = profile(x, length, cfg["nose"], cfg["tail"], thick)
        top, bot = int(cy - ht), int(cy + ht)
        if bot <= top:
            continue
        d.line([(x, top), (x, bot)], fill=pal["base"])
        d.line([(x, top), (x, top + max(1, int(ht * 0.28)))], fill=pal["lite"])
        d.line([(x, betw := bot - max(1, int(ht * 0.34))), (x, bot)], fill=pal["deep"])
        if ht > 12:
            d.point((x, top + 1), fill=pal["hi"])
    # nose cap
    d.polygon([(8, cy - 2), (cfg["nose"] - 6, cy - 12), (cfg["nose"] + 2, cy), (cfg["nose"] - 6, cy + 10)],
              fill=pal["lite"])

    # ---- engine block ---------------------------------------------------
    ex = length - 2
    eh = thick * 0.92
    d.rounded_rectangle([ex - cfg["engine_len"], cy - eh, ex + 16, cy + eh], radius=8,
                        fill=pal["deep"])
    d.rounded_rectangle([ex - cfg["engine_len"], cy - eh, ex + 16, cy - eh + 10], radius=6,
                        fill=pal["base"])
    n = cfg["engines"]
    for i in range(n):
        yy = cy - eh + 12 + i * (2 * eh - 22) / max(1, n - 1) if n > 1 else cy
        d.ellipse([ex + 6, yy - 11, ex + 26, yy + 9], fill=(36, 38, 44))
        d.ellipse([ex + 10, yy - 8, ex + 22, yy + 6], fill=(214, 96, 36))
        d.ellipse([ex + 13, yy - 5, ex + 19, yy + 3], fill=(255, 204, 128))

    # ---- cockpit --------------------------------------------------------
    cw, ch = 46, 22
    cx, cyy = cfg["canopy"][0], cfg["canopy"][1]
    canopy = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    cd = ImageDraw.Draw(canopy)
    cd.rounded_rectangle([0, 0, cw - 1, ch - 1], radius=8, fill=pal["glass"])
    cd.rounded_rectangle([0, 0, cw - 1, 6], radius=6, fill=pal["hi"])
    img.paste(canopy, (cx, cyy), canopy)

    # ---- panel breaks ---------------------------------------------------
    x = cfg["nose"] + 12
    while x < length - 16:
        ht = profile(x, length, cfg["nose"], cfg["tail"], thick)
        if ht > 9:
            d.line([(x, cy - ht + 2), (x, cy + ht - 2)], fill=pal["dark"])
            d.line([(x + 1, cy - ht + 2), (x + 1, cy + ht - 2)], fill=pal["lite"])
        x += rng.randrange(22, 40)

    # ---- stripes and lights --------------------------------------------
    d.line([(cfg["nose"] - 8, cy + int(thick * 0.52)), (length - 26, cy + int(thick * 0.52))],
           fill=cfg["stripe"])
    d.line([(cfg["nose"] - 8, cy + int(thick * 0.52) + 1), (length - 26, cy + int(thick * 0.52) + 1)],
           fill=pal["dark"])
    d.rectangle([cfg["nose"] + 6, cy - thick - 3, cfg["nose"] + 10, cy - thick + 1], fill=(84, 230, 209))
    d.rectangle([length - 40, cy - thick - 3, length - 36, cy - thick + 1], fill=(255, 196, 92))

    # ---- greebles -------------------------------------------------------
    for i in range(9):
        gx = rng.randrange(cfg["nose"] + 6, length - 40)
        ht = profile(gx, length, cfg["nose"], cfg["tail"], thick)
        if ht < 12:
            continue
        gy = int(cy - ht * rng.uniform(0.2, 0.7))
        gw = rng.choice((6, 8, 10, 14))
        gh = rng.choice((3, 4))
        d.rectangle([gx, gy, gx + gw, gy + gh], fill=pal["deep"])
        d.line([(gx, gy), (gx + gw, gy)], fill=pal["hi"])

    # ---- outline --------------------------------------------------------
    a = np.asarray(img).copy()
    mask = a[..., 3] > 0
    pad = np.pad(mask, 1)
    edge = mask & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    a[edge] = (*INK, 255)
    # thickness: grow the contour one pixel so it holds at 1x
    edge2 = mask & (pad[:-2, 1:-1] ^ pad[2:, 1:-1])
    a[edge2, :3] = INK
    return Image.fromarray(a, "RGBA")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for hid, cfg in HULLS.items():
        img = build(hid, cfg)
        img.save(OUT / f"{hid}.png")
        print("ok", hid, img.size)


if __name__ == "__main__":
    main()

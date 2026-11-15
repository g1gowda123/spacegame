#!/usr/bin/env python3
"""Composed hardware portraits for the module parts diffusion kept mangling.

Three parts (whipple2, coolant2, science2) came back as debris clusters no
matter the prompt — disconnected shells, floating brackets, no readable border.
These are drawn instead: oblique 3/4 boxes and cylinders with a fixed light
from the upper left, the same 11-colour hardware ramp as the diffusion set, and
a 1 px ink contour, so they sit next to the generated parts without a style
break.

Out: assets/sprites/modules/<id>.png 128x128, assets/sprites/modules/ship/<id>.png 64x48
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "modules"
ICONS = ROOT / "assets" / "sprites" / "buffs_hd"
SHIP = OUT / "ship"

INK = (22, 24, 30)
DARK = (40, 44, 52)
MID = (86, 92, 102)
STEEL = (132, 140, 150)
LIGHT = (184, 192, 200)
CREAM = (232, 236, 240)
ORANGE = (228, 87, 46)
AMBER = (232, 184, 92)
CYAN = (84, 230, 209)

# oblique projection: x to the right, y down, depth to the upper right
DX, DY = 0.52, -0.34


def box(d, x, y, w, h, depth, col, ink=True):
    """Front face at (x,y,w,h), extruded by depth toward the upper right."""
    ox, oy = depth * DX, depth * DY
    front = [x, y, x + w, y + h]
    d.polygon([(x, y), (x + ox, y + oy), (x + w + ox, y + oy), (x + w, y)], fill=_shade(col, 1.18))
    d.polygon([(x + w, y), (x + w + ox, y + oy), (x + w + ox, y + h + oy), (x + w, y + h)],
              fill=_shade(col, 0.78))
    d.rectangle(front, fill=col)
    if ink:
        d.line([(x, y), (x + ox, y + oy), (x + w + ox, y + oy), (x + w, y), (x, y)], fill=INK)
        d.line([(x + w, y + h), (x + w + ox, y + h + oy), (x + w + ox, y + oy)], fill=INK)
        d.line([(x, y + h), (x + w, y + h)], fill=INK)
        d.line([(x + w, y), (x + w, y + h)], fill=INK)


def cyl(d, cx, cy, rx, ry, h, col):
    """Upright cylinder: ellipse cap at (cx,cy), body h tall."""
    d.rectangle([cx - rx, cy, cx + rx, cy + h], fill=col)
    d.ellipse([cx - rx, cy + h - ry, cx + rx, cy + h + ry], fill=_shade(col, 0.72))
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=_shade(col, 1.2))
    d.arc([cx - rx, cy - ry, cx + rx, cy + ry], 0, 360, fill=INK)
    d.line([(cx - rx, cy), (cx - rx, cy + h)], fill=INK)
    d.line([(cx + rx, cy), (cx + rx, cy + h)], fill=INK)


def bolts(d, x, y, w, h, step=26):
    for bx in range(x + 6, x + w - 4, step):
        for by in (y + 6, y + h - 6):
            d.ellipse([bx - 2, by - 2, bx + 2, by + 2], fill=DARK)


def _shade(c, k):
    return tuple(int(max(0, min(255, v * k))) for v in c)


def whipple2():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # three stacked laminate plates in a frame
    box(d, 18, 30, 70, 66, 16, MID)
    for i, y in enumerate((36, 52, 68)):
        box(d, 24, y, 58, 12, 10, STEEL if i % 2 == 0 else LIGHT, ink=False)
    d.rectangle([24, 84, 82, 90], fill=ORANGE)
    bolts(d, 18, 30, 70, 66, 24)
    box(d, 84, 22, 14, 76, 10, DARK)
    return img


def coolant2():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    box(d, 26, 34, 62, 60, 14, MID)  # housing
    for i in range(5):  # fin stack
        box(d, 32, 40 + i * 10, 50, 5, 8, LIGHT, ink=False)
    box(d, 20, 30, 10, 70, 10, DARK)  # end cap
    box(d, 86, 30, 10, 70, 10, DARK)
    d.rectangle([52, 18, 60, 40], fill=STEEL)  # inlet
    d.rectangle([52, 18, 60, 24], fill=CYAN)
    d.rectangle([30, 94, 38, 110], fill=STEEL)  # outlet
    bolts(d, 26, 34, 62, 60, 26)
    return img


def science2():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    box(d, 22, 78, 74, 24, 12, MID)  # cradle
    box(d, 30, 90, 58, 8, 6, DARK, ink=False)
    cyl(d, 46, 34, 18, 7, 44, STEEL)  # spectrometer body
    d.ellipse([38, 44, 54, 60], fill=(28, 34, 44))  # lens port
    d.ellipse([42, 48, 50, 56], fill=CYAN)
    box(d, 62, 40, 22, 16, 8, LIGHT)  # side housing
    d.rectangle([64, 44, 80, 48], fill=ORANGE)
    cyl(d, 76, 62, 6, 3, 16, DARK)  # connector
    d.rectangle([28, 34, 34, 60], fill=DARK)
    return img


def repair():
    """Sealant dispenser for the SELF-HEALING SEALANT card: one readable object."""
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    box(d, 38, 46, 44, 66, 14, STEEL)          # canister body
    box(d, 46, 58, 28, 34, 8, LIGHT, ink=False)  # label plate
    d.rectangle([52, 66, 74, 70], fill=ORANGE)   # hazard band
    d.rectangle([52, 74, 74, 78], fill=ORANGE)
    box(d, 44, 36, 32, 12, 10, DARK)            # collar
    cyl(d, 60, 24, 9, 4, 14, MID)               # nozzle
    d.rectangle([54, 14, 66, 20], fill=CYAN)
    d.polygon([(56, 14), (52, 8), (60, 11)], fill=CYAN)
    box(d, 34, 104, 52, 12, 10, DARK)           # base
    bolts(d, 38, 46, 44, 66, 24)
    # plus mark on the label
    d.rectangle([58, 60, 62, 72], fill=ORANGE)
    d.rectangle([54, 64, 66, 68], fill=ORANGE)
    return img


def main() -> None:
    SHIP.mkdir(parents=True, exist_ok=True)
    for pid, fn in (("whipple2", whipple2), ("coolant2", coolant2), ("science2", science2)):
        img = fn()
        img.save(OUT / f"{pid}.png")
        img.resize((64, 48), Image.Resampling.LANCZOS).save(SHIP / f"{pid}.png")
        print("ok", pid)
    ICONS.mkdir(parents=True, exist_ok=True)
    repair().save(ICONS / "repair.png")
    print("ok repair icon")


if __name__ == "__main__":
    main()

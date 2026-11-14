#!/usr/bin/env python3
"""Stencil pictograms for the flight-binder UI (16 and 24 px, single colour).

`docs/UI_REDESIGN.md` asks for "16/24 px single-colour stencil pictograms
(hull, orbit, power, thermal, data, comms, crew, risk)". These are drawn on an
integer grid in ink so the code can modulate their colour per surface.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "ui" / "icons"
INK = (27, 26, 23)


def dot(a, x, y, v=255):
    if 0 <= y < a.shape[0] and 0 <= x < a.shape[1]:
        a[y, x] = v


def rect(a, x0, y0, x1, y1, fill=False):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if fill or y in (y0, y1) or x in (x0, x1):
                dot(a, x, y)


def line(a, x0, y0, x1, y1):
    x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
    dx, dy = abs(x1 - x0), abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx - dy
    while True:
        dot(a, x0, y0)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 > -dy:
            err -= dy
            x0 += sx
        if e2 < dx:
            err += dx
            y0 += sy


def circ(a, cx, cy, r):
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if r - 0.9 < d < r + 0.6:
                dot(a, x, y)


def disc(a, cx, cy, r):
    for y in range(int(cy - r), int(cy + r + 1)):
        for x in range(int(cx - r), int(cx + r + 1)):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                dot(a, x, y)


def draw(name, s):
    a = np.zeros((s, s), np.uint8)
    if name == "hull":
        # capsule nose and a fin
        for y in range(3, s - 3):
            half = 1 if y < s * 0.45 else 2
            line(a, s // 2 - half, y, s // 2 + half, y)
        line(a, s // 2 - 3, s - 5, s // 2 - 3, s - 7)
        line(a, s // 2 + 3, s - 5, s // 2 + 3, s - 7)
        line(a, s // 2 - 3, s - 7, s // 2 - 1, s - 7)
        line(a, s // 2 + 3, s - 7, s // 2 + 1, s - 7)
    elif name == "orbit":
        circ(a, s / 2 - 0.5, s / 2 - 0.5, s * 0.36)
        disc(a, s * 0.5, s * 0.34, max(1, s * 0.06))
    elif name == "power":
        # lightning bolt
        line(a, s // 2 + 2, 3, s // 2 - 3, s // 2)
        line(a, s // 2 - 3, s // 2, s // 2 + 1, s // 2)
        line(a, s // 2 + 1, s // 2, s // 2 - 2, s - 4)
    elif name == "thermal":
        # thermometer: bulb + stem + ticks
        line(a, s // 2, 4, s // 2, s - 6)
        line(a, s // 2 - 2, 4, s // 2 - 2, s - 8)
        line(a, s // 2 + 2, 4, s // 2 + 2, s - 8)
        disc(a, s // 2, s - 5, 2)
        for y in range(6, s - 8, 3):
            line(a, s // 2 + 3, y, s // 2 + 5, y)
    elif name == "data":
        # three stacked plates
        for i, y in enumerate((4, s // 2, s - 5)):
            line(a, 3, y, s - 5, y)
            dot(a, s - 3, y)
    elif name == "comms":
        # dish + arc
        circ(a, s / 2, s * 0.62, s * 0.26)
        line(a, s / 2, s * 0.62, s / 2 + s * 0.22, s * 0.36)
        disc(a, s / 2 + s * 0.22, s * 0.36, 1)
    elif name == "crew":
        disc(a, s / 2, s * 0.34, max(2, s * 0.13))
        arc_pts = []
        for x in range(int(s * 0.22), int(s * 0.78)):
            t = (x - s * 0.5) / (s * 0.28)
            y = s * 0.80 - (1 - t * t) * s * 0.14
            arc_pts.append((x, int(y)))
        for (x, y) in arc_pts:
            dot(a, x, y)
    elif name == "risk":
        # triangle with a bang
        line(a, s // 2, 3, 2, s - 4)
        line(a, s // 2, 3, s - 3, s - 4)
        line(a, 2, s - 4, s - 3, s - 4)
        line(a, s // 2, s * 0.42, s // 2, s * 0.66)
        dot(a, s // 2, s - 7)
    elif name == "target":
        circ(a, s / 2 - 0.5, s / 2 - 0.5, s * 0.36)
        circ(a, s / 2 - 0.5, s / 2 - 0.5, s * 0.16)
        disc(a, s / 2, s / 2, 1)
    elif name == "cost":
        # coin/dollar-ish bracket
        circ(a, s / 2 - 0.5, s / 2 - 0.5, s * 0.34)
        line(a, s // 2, 4, s // 2, s - 4)
        line(a, s // 2 - 2, 6, s // 2 + 2, 6)
        line(a, s // 2 - 2, s - 6, s // 2 + 2, s - 6)
    return a


NAMES = ["hull", "orbit", "power", "thermal", "data", "comms", "crew", "risk", "target", "cost"]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    made = {}
    for name in NAMES:
        for s in (16, 24):
            a = draw(name, s)
            rgba = np.zeros((s, s, 4), np.uint8)
            solid = a > 0
            rgba[solid] = (*INK, 255)
            img = Image.fromarray(rgba, "RGBA")
            img.save(OUT / f"{name}_{s}.png")
            made[f"{name}_{s}"] = dict(size=[s, s])
    (OUT / "manifest.json").write_text(json.dumps({
        "set": "flight-binder stencil pictograms",
        "colour": "single ink channel (#1b1a17); modulate in code",
        "sizes": [16, 24],
        "names": NAMES,
        "files": made,
    }, indent=2) + "\n")

    sheet = Image.new("RGBA", (10 + 74 * 4, 20 + 46 * 3 + 20), (232, 223, 200, 255))
    from PIL import ImageDraw, ImageFont
    f = ImageFont.truetype(str(ROOT / "assets" / "ui" / "Silkscreen-Regular.ttf"), 8)
    d = ImageDraw.Draw(sheet)
    x = y = 10
    for i, name in enumerate(NAMES):
        img = Image.open(OUT / f"{name}_24.png")
        sheet.alpha_composite(img, (x, y))
        img16 = Image.open(OUT / f"{name}_16.png")
        sheet.alpha_composite(img16, (x + 30, y + 6))
        d.text((x, y + 28), name, font=f, fill=(*INK, 255))
        x += 74
        if i % 4 == 3:
            x, y = 10, y + 46
    sheet.save(OUT / "preview.png")
    print(f"wrote {len(made)} icons")


if __name__ == "__main__":
    main()

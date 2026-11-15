#!/usr/bin/env python3
"""Simplified module icons — flat, 3-tone, one system accent, 2 px ink edge.

The diffusion portraits carried too much micro-detail for a 52 px shop tile and
read as photographic next to the flat tile/ship art. These are drawn from a
small primitive set (slab, cylinder, ring, fin stack, bell, dish, claw) with a
fixed palette: three steel tones, cream, one system accent, ink. Silhouette
first — every icon should be identifiable as a black shape at 40 px.

Out: assets/sprites/modules/<id>.png 128, assets/sprites/modules/ship/<id>.png 64x48
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "modules"
SHIP = OUT / "ship"

INK = (24, 26, 32)
D = (52, 58, 68)
M = (104, 112, 124)
L = (166, 174, 186)
C = (232, 236, 240)

ACCENTS = {
    "PROPULSION": (232, 184, 92),
    "POWER": (84, 230, 209),
    "THERMAL": (228, 87, 46),
    "STRUCTURE": (150, 160, 172),
    "COMMS": (120, 200, 140),
    "SCIENCE": (168, 140, 220),
    "SUPPORT": (232, 226, 200),
}

SYSTEM = {
    "wheel": "PROPULSION", "wheel2": "PROPULSION", "ion": "PROPULSION", "ion2": "PROPULSION",
    "rtg": "POWER", "rtg2": "POWER", "fuel_cell": "POWER", "fuel_cell2": "POWER",
    "radiator": "THERMAL", "radiator2": "THERMAL", "coolant": "THERMAL", "coolant2": "THERMAL",
    "armor": "STRUCTURE", "armor2": "STRUCTURE", "whipple": "STRUCTURE", "whipple2": "STRUCTURE",
    "antenna": "COMMS", "antenna2": "COMMS", "buffer": "COMMS", "buffer2": "COMMS", "deepnet": "COMMS",
    "science_pack": "SCIENCE", "science2": "SCIENCE", "sensor": "SCIENCE", "sensor2": "SCIENCE",
    "salvage": "SUPPORT", "repair": "SUPPORT",
}


def panel(d, x, y, w, h, fill=M, hi=L, lo=D, edge=INK, t=2):
    d.rectangle([x, y, x + w, y + h], fill=fill)
    d.rectangle([x, y, x + w, y + t], fill=hi)
    d.rectangle([x, y + h - t, x + w, y + h], fill=lo)
    d.rectangle([x, y, x + w, y + h], outline=edge, width=1)


def cyl(d, x, y, w, h, fill=M, hi=L, lo=D):
    d.rounded_rectangle([x, y, x + w, y + h], radius=w // 2, fill=fill)
    d.rounded_rectangle([x + 2, y + 2, x + w - 2, y + h - 2], radius=max(1, w // 2 - 2), outline=LO_HEX(fill))
    d.rectangle([x, y + 2, x + w, y + 6], fill=hi)
    d.rectangle([x, y + h - 8, x + w, y + h - 4], fill=lo)
    d.rounded_rectangle([x, y, x + w, y + h], radius=w // 2, outline=INK, width=1)


def LO_HEX(c):
    return tuple(max(0, int(v * 0.86)) for v in c)


def ring(d, cx, cy, r, thick, fill=M, hi=L, lo=D):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=fill, width=thick)
    d.arc([cx - r, cy - r, cx + r, cy + r], 100, 260, fill=lo, width=thick)
    d.arc([cx - r, cy - r, cx + r, cy + r], 280, 60, fill=hi, width=thick)
    d.ellipse([cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1], outline=INK, width=1)


def fins(d, x, y, w, h, n, col=L):
    step = h / n
    for i in range(n):
        yy = int(y + i * step)
        d.rectangle([x, yy, x + w, yy + max(2, int(step) - 2)], fill=col)
        d.rectangle([x, yy + max(2, int(step) - 2) - 1, x + w, yy + max(2, int(step) - 2)], fill=D)


def mark(d, x, y, acc, s=6):
    d.rectangle([x, y, x + s, y + s], fill=acc)
    d.rectangle([x, y, x + s, y + s], outline=INK, width=1)


# ---------------------------------------------------------------- propulsion
def wheel(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ring(d, 64, 62, 34, 10, M, L, D)
    for a in (0, 90):
        d.arc([24, 22, 104, 102], a - 30 + 90, a + 30 + 90, fill=D, width=4)
    d.ellipse([56, 54, 72, 70], fill=D)
    d.ellipse([60, 58, 68, 66], fill=acc)
    panel(d, 44, 98, 40, 16, M, L, D)
    return img


def wheel2(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ring(d, 40, 58, 26, 8, M, L, D)
    ring(d, 88, 58, 26, 8, M, L, D)
    d.rectangle([36, 82, 92, 92], fill=M)
    d.rectangle([36, 82, 92, 86], fill=L)
    d.rectangle([36, 82, 92, 92], outline=INK, width=1)
    d.rectangle([56, 84, 72, 104], fill=D, outline=INK, width=1)
    mark(d, 60, 88, acc, 8)
    return img


def bell(d, cx, top, h, w):
    d.polygon([(cx - w // 2, top), (cx + w // 2, top), (cx + w, top + h), (cx - w, top + h)],
              fill=M)
    d.polygon([(cx - w // 2, top), (cx - w, top + h), (cx - w + 8, top + h), (cx - w // 2 + 8, top)],
              fill=L)
    d.polygon([(cx - w // 2, top), (cx + w // 2, top), (cx + w, top + h), (cx - w, top + h)],
              outline=INK)
    d.line([(cx - w, top + h), (cx + w, top + h)], fill=INK, width=2)


def ion(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    bell(d, 64, 34, 56, 26)
    panel(d, 34, 20, 60, 18, M, L, D)
    for i in range(3):
        y = 30 + i * 8
        d.line([(46, y), (82, y)], fill=acc if i == 1 else D, width=2)
    d.rectangle([44, 96, 84, 106], fill=D, outline=INK)
    return img


def ion2(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, cx in enumerate((36, 64, 92)):
        bell(d, cx, 46, 42, 14)
        d.rectangle([cx - 8, 34, cx + 8, 46], fill=M, outline=INK)
    panel(d, 20, 96, 88, 14, M, L, D)
    d.rectangle([28, 100, 100, 102], fill=acc)
    return img


# --------------------------------------------------------------------- power
def rtg(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cyl(d, 46, 22, 36, 78, M, L, D)
    for i in range(5):
        fins(d, 26, 32 + i * 12, 76, 8, 1, L)
    d.rectangle([38, 96, 90, 106], fill=D, outline=INK)
    d.ellipse([54, 24, 74, 34], fill=acc)
    d.ellipse([54, 24, 74, 34], outline=INK)
    return img


def rtg2(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, x in enumerate((30, 72)):
        cyl(d, x, 26, 26, 66, M, L, D)
        for j in range(3):
            d.rectangle([x - 6, 38 + j * 16, x + 32, 38 + j * 16 + 4], fill=L)
            d.rectangle([x - 6, 38 + j * 16 + 3, x + 32, 38 + j * 16 + 4], fill=D)
        d.rectangle([x, 92, x + 26, 100], fill=acc)
    d.rectangle([22, 100, 106, 110], fill=D, outline=INK)
    return img


def fuel_cell(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cyl(d, 30, 30, 28, 62, L, C, M)
    cyl(d, 62, 30, 28, 62, M, L, D)
    d.rectangle([26, 92, 94, 104], fill=D, outline=INK)
    d.rectangle([54, 20, 66, 30], fill=D)
    d.line([(66, 22), (94, 34)], fill=acc, width=3)
    mark(d, 40, 52, acc, 8)
    return img


def fuel_cell2(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, x in enumerate((26, 66)):
        cyl(d, x, 34, 36, 44, M, L, D)
        d.rectangle([x + 8, 40, x + 28, 44], fill=acc)
    for i, x in enumerate((34, 74)):
        cyl(d, x, 84, 20, 22, L, C, M)
    d.rectangle([20, 24, 108, 32], fill=D, outline=INK)
    return img


# ------------------------------------------------------------------- thermal
def radiator(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    panel(d, 30, 20, 68, 84, L, C, M)
    fins(d, 38, 28, 52, 68, 6, M)
    d.rectangle([26, 104, 102, 114], fill=D, outline=INK)
    d.rectangle([26, 104, 102, 108], fill=L)
    d.line([(60, 30), (60, 96)], fill=acc, width=3)
    return img


def radiator2(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for x, w in ((16, 46), (66, 46)):
        panel(d, x, 24, w, 72, L, C, M)
        fins(d, x + 6, 32, w - 12, 56, 5, M)
    d.rectangle([56, 96, 72, 106], fill=D, outline=INK)
    d.line([(40, 30), (88, 90)], fill=acc, width=3)
    return img


def coolant(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([30, 26, 90, 86], fill=M)
    d.ellipse([36, 32, 78, 70], fill=L)
    d.ellipse([30, 26, 90, 86], outline=INK)
    d.arc([30, 26, 90, 86], 100, 260, fill=D, width=4)
    panel(d, 40, 90, 48, 20, M, L, D)
    d.rectangle([56, 96, 72, 104], fill=acc)
    d.rectangle([50, 18, 70, 30], fill=D, outline=INK)
    return img


def coolant2(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cyl(d, 22, 34, 28, 58, M, L, D)
    cyl(d, 54, 34, 28, 58, L, C, M)
    panel(d, 84, 44, 22, 44, D, M, INK)
    fins(d, 86, 50, 18, 32, 4, M)
    d.rectangle([18, 94, 106, 104], fill=D, outline=INK)
    d.line([(36, 30), (92, 30)], fill=acc, width=3)
    return img


# ----------------------------------------------------------------- structure
def armor(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(24, 30), (96, 22), (108, 86), (70, 104), (26, 92)], fill=M)
    d.polygon([(24, 30), (96, 22), (100, 40), (30, 48)], fill=L)
    d.polygon([(70, 104), (108, 86), (104, 70), (66, 86)], fill=D)
    d.polygon([(24, 30), (96, 22), (108, 86), (70, 104), (26, 92)], outline=INK)
    for x, y in ((40, 56), (64, 50), (86, 46)):
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=D, outline=INK)
    d.line([(34, 76), (92, 66)], fill=acc, width=3)
    return img


def armor2(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    panel(d, 18, 56, 84, 20, M, L, D)
    panel(d, 30, 30, 84, 18, M, L, D)
    panel(d, 42, 16, 72, 14, L, C, M)
    for x in (44, 74, 100):
        d.line([(x, 38), (x, 56)], fill=D, width=4)
    d.rectangle([24, 84, 96, 92], fill=D, outline=INK)
    d.line([(34, 66), (88, 66)], fill=acc, width=3)
    return img


def whipple(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.arc([20, 24, 108, 104], 200, 340, fill=L, width=12)
    d.arc([20, 24, 108, 104], 200, 340, fill=M, width=6)
    d.arc([20, 24, 108, 104], 200, 340, fill=INK, width=1)
    d.arc([26, 36, 102, 108], 200, 340, fill=D, width=8)
    d.rectangle([26, 92, 38, 104], fill=M, outline=INK)
    d.rectangle([90, 92, 102, 104], fill=M, outline=INK)
    mark(d, 60, 66, acc, 8)
    return img


def whipple2(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, (yy, col) in enumerate(((28, L), (46, M), (64, L))):
        d.arc([18, yy, 110, yy + 52], 200, 340, fill=col, width=10)
        d.arc([18, yy, 110, yy + 52], 200, 340, fill=INK, width=1)
    d.rectangle([22, 92, 34, 110], fill=M, outline=INK)
    d.rectangle([94, 92, 106, 110], fill=M, outline=INK)
    d.rectangle([40, 100, 88, 108], fill=D, outline=INK)
    d.rectangle([40, 100, 88, 102], fill=acc)
    return img


# --------------------------------------------------------------------- comms
def dish(d, cx, cy, r, acc):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=L)
    d.ellipse([cx - r + 6, cy - r + 6, cx + r - 6, cy + r - 6], fill=M)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=INK)
    d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=acc, outline=INK)
    for a in (30, 90, 150):
        import math
        x = cx + int(math.cos(math.radians(a)) * r * 0.82)
        y = cy + int(math.sin(math.radians(a)) * r * 0.82)
        d.line([(cx, cy), (x, y)], fill=D, width=1)


def antenna(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    dish(d, 64, 48, 34, acc)
    d.line([(64, 76), (64, 100)], fill=M, width=8)
    d.rectangle([44, 100, 84, 112], fill=D, outline=INK)
    d.line([(64, 48), (64, 30)], fill=M, width=3)
    return img


def antenna2(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    dish(d, 38, 44, 24, acc)
    dish(d, 92, 52, 20, acc)
    d.line([(38, 68), (38, 96)], fill=M, width=6)
    d.line([(92, 72), (92, 96)], fill=M, width=6)
    d.rectangle([22, 96, 108, 108], fill=D, outline=INK)
    d.rectangle([22, 96, 108, 100], fill=M)
    return img


def buffer(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    panel(d, 22, 24, 84, 80, M, L, D)
    for i in range(4):
        y = 34 + i * 16
        panel(d, 30, y, 68, 10, D, M, INK)
        d.rectangle([88, y + 2, 96, y + 8], fill=acc if i % 2 == 0 else L)
    d.rectangle([22, 90, 106, 100], fill=D)
    return img


def buffer2(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    panel(d, 14, 28, 46, 76, M, L, D)
    panel(d, 68, 28, 46, 76, M, L, D)
    for i in range(3):
        d.rectangle([22, 40 + i * 20, 52, 46 + i * 20], fill=D)
        d.rectangle([76, 40 + i * 20, 106, 46 + i * 20], fill=D)
    d.rectangle([60, 34, 68, 98], fill=D)
    d.rectangle([60, 54, 68, 62], fill=acc)
    return img


def deepnet(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, r in enumerate((42, 28)):
        d.arc([64 - r, 62 - r, 64 + r, 62 + r], 200, 340, fill=L if i == 0 else M, width=8)
        d.arc([64 - r, 62 - r, 64 + r, 62 + r], 200, 340, fill=INK, width=1)
    d.line([(64, 62), (64, 96)], fill=M, width=6)
    d.rectangle([30, 96, 98, 108], fill=D, outline=INK)
    d.ellipse([58, 54, 70, 66], fill=acc, outline=INK)
    return img


# ------------------------------------------------------------------- science
def science_pack(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    panel(d, 18, 32, 74, 70, M, L, D)
    for i in range(3):
        d.rectangle([26 + i * 22, 42, 40 + i * 22, 56], fill=acc if i == 1 else D, outline=INK)
    d.rectangle([26, 64, 84, 92], fill=D)
    d.rectangle([30, 68, 80, 88], fill=M)
    d.line([(92, 46), (110, 30)], fill=M, width=5)
    d.ellipse([104, 22, 116, 34], fill=C, outline=INK)
    return img


def science2(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    panel(d, 14, 40, 52, 54, M, L, D)
    panel(d, 74, 32, 40, 62, M, L, D)
    d.ellipse([28, 52, 52, 76], fill=(28, 32, 40), outline=INK)
    d.ellipse([34, 58, 46, 70], fill=acc)
    d.rectangle([86, 42, 100, 58], fill=D, outline=INK)
    d.line([(93, 58), (93, 92)], fill=M, width=5)
    d.polygon([(88, 92), (98, 92), (93, 104)], fill=L)
    return img


def sensor(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([36, 26, 92, 74], radius=10, fill=M, outline=INK)
    d.ellipse([46, 36, 82, 66], fill=(26, 30, 38), outline=INK)
    d.ellipse([56, 44, 72, 58], fill=acc)
    d.ellipse([61, 48, 67, 54], fill=C)
    d.polygon([(44, 74), (84, 74), (94, 104), (34, 104)], fill=D)
    d.polygon([(44, 74), (84, 74), (94, 104), (34, 104)], outline=INK)
    d.rectangle([56, 96, 72, 104], fill=acc)
    return img


def sensor2(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([16, 30, 62, 70], radius=8, fill=M, outline=INK)
    d.ellipse([24, 38, 54, 62], fill=(26, 30, 38), outline=INK)
    d.ellipse([33, 44, 45, 56], fill=acc)
    d.rounded_rectangle([66, 22, 112, 56], radius=8, fill=M, outline=INK)
    d.ellipse([76, 28, 102, 50], fill=(26, 30, 38), outline=INK)
    d.ellipse([85, 35, 93, 43], fill=acc)
    d.rectangle([56, 70, 72, 104], fill=D, outline=INK)
    d.rectangle([40, 100, 88, 110], fill=D, outline=INK)
    return img


# ------------------------------------------------------------------- support
def salvage(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(40, 96), (88, 96), (100, 56), (62, 42), (26, 56)], fill=M, outline=INK)
    d.polygon([(52, 44), (74, 34), (92, 44), (86, 62), (56, 62)], fill=L, outline=INK)
    d.polygon([(56, 62), (86, 62), (92, 84), (50, 84)], fill=D, outline=INK)
    d.rectangle([60, 30, 72, 44], fill=acc, outline=INK)
    d.rectangle([34, 100, 96, 112], fill=D, outline=INK)
    return img


def repair(acc):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([48, 46, 80, 100], radius=8, fill=M, outline=INK)
    d.rectangle([48, 46, 80, 56], fill=D)
    d.rectangle([56, 64, 72, 68], fill=acc)
    d.rectangle([54, 74, 74, 78], fill=acc)
    d.rectangle([58, 24, 70, 46], fill=D, outline=INK)
    d.polygon([(58, 24), (60, 10), (80, 18), (70, 24)], fill=acc, outline=INK)
    d.rectangle([40, 100, 88, 112], fill=D, outline=INK)
    return img


FUNCS = {
    "wheel": wheel, "wheel2": wheel2, "ion": ion, "ion2": ion2,
    "rtg": rtg, "rtg2": rtg2, "fuel_cell": fuel_cell, "fuel_cell2": fuel_cell2,
    "radiator": radiator, "radiator2": radiator2, "coolant": coolant, "coolant2": coolant2,
    "armor": armor, "armor2": armor2, "whipple": whipple, "whipple2": whipple2,
    "antenna": antenna, "antenna2": antenna2, "buffer": buffer, "buffer2": buffer2,
    "deepnet": deepnet, "science_pack": science_pack, "science2": science2,
    "sensor": sensor, "sensor2": sensor2, "salvage": salvage, "repair": repair,
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    SHIP.mkdir(parents=True, exist_ok=True)
    for pid, fn in FUNCS.items():
        img = fn(ACCENTS[SYSTEM[pid]])
        img.save(OUT / f"{pid}.png")
        img.resize((64, 48), Image.Resampling.LANCZOS).save(SHIP / f"{pid}.png")
        print("ok", pid)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Module art: 26 shop portraits (128), 26 ship modules (64x48), 12 buff icons.

Everything is drawn on a small pixel grid and scaled with NEAREST, so the
silhouette stays crisp and every part reads as different hardware at 40 px.
Families: gyro, ion, rtg, cell, radiator, coolant, armour, whipple, antenna,
buffer, science, sensor, salvage, repair. Tier 2 adds a second stage and a warm
accent so an A/B pair is legible side by side.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "modules"
SHIP = OUT / "ship"
BUFF = ROOT / "assets" / "sprites" / "buffs_hd"

INK = (24, 26, 32)
STEEL = (96, 106, 118)
STEEL_HI = (150, 162, 176)
STEEL_SH = (62, 70, 80)
DARK = (44, 50, 60)
ORANGE = (228, 87, 46)
CYAN = (84, 230, 209)
GOLD = (232, 184, 92)
WHITE = (236, 240, 244)


def base(s=64):
    return Image.new("RGBA", (s, s), (0, 0, 0, 0))


def outline(img):
    a = img.split()[-1]
    lay = Image.new("RGBA", img.size, INK + (255,))
    mask = a.filter(ImageFilter.MaxFilter(3))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(lay, (0, 0), mask)
    out.alpha_composite(img)
    return out


from PIL import ImageFilter  # noqa: E402  (after helper for readability)


def gyro(d, t):
    d.arc([10, 10, 54, 54], 0, 360, fill=STEEL, width=3)
    d.arc([18, 18, 46, 46], 0, 360, fill=STEEL_HI, width=2)
    d.rectangle([28, 26, 36, 38], fill=DARK)
    if t:
        d.arc([4, 20, 60, 44], 200, 340, fill=ORANGE, width=3)
    else:
        d.line([32, 6, 32, 20], fill=STEEL_SH, width=2)


def ion(d, t):
    d.polygon([(22, 20), (42, 20), (46, 44), (18, 44)], fill=STEEL)
    d.rectangle([24, 44, 40, 50], fill=DARK)
    for x in range(24, 40, 4):
        d.line([x, 24, x, 40], fill=STEEL_SH)
    d.ellipse([28, 12, 36, 20], fill=CYAN)
    if t:
        d.polygon([(10, 26), (18, 32), (18, 40), (10, 34)], fill=STEEL_SH)
        d.polygon([(54, 26), (46, 32), (46, 40), (54, 34)], fill=STEEL_SH)


def rtg(d, t):
    d.rectangle([24, 16, 40, 46], fill=DARK)
    for y in (20, 28, 36):
        d.rectangle([20, y, 44, y + 5], fill=STEEL)
    d.rectangle([28, 8, 36, 16], fill=STEEL_HI)
    d.ellipse([27, 46, 37, 54], fill=GOLD)
    if t:
        d.ellipse([18, 4, 46, 14], fill=STEEL_SH)


def cell(d, t):
    for i, x in enumerate((16, 26, 36, 46)):
        h = 30 if not t else 22 + i % 2 * 8
        d.rectangle([x, 48 - h, x + 8, 48], fill=STEEL if i % 2 else DARK)
        d.rectangle([x, 14, x + 8, 20], fill=CYAN)
    if t:
        d.rectangle([12, 50, 52, 54], fill=ORANGE)


def radiator(d, t):
    for i, x in enumerate((14, 24, 34, 44)):
        d.rectangle([x, 16, x + 6, 46], fill=STEEL_HI if i % 2 else STEEL)
        d.line([x + 3, 18, x + 3, 44], fill=STEEL_SH)
    d.rectangle([10, 46, 54, 50], fill=DARK)
    if t:
        d.rectangle([10, 8, 54, 12], fill=ORANGE)


def coolant(d, t):
    d.ellipse([18, 18, 46, 46], fill=STEEL)
    d.ellipse([22, 22, 42, 42], fill=DARK)
    d.ellipse([26, 26, 38, 38], fill=CYAN)
    d.rectangle([30, 8, 34, 18], fill=STEEL_SH)
    if t:
        d.rectangle([8, 30, 18, 34], fill=STEEL_SH)
        d.rectangle([46, 30, 56, 34], fill=STEEL_SH)


def armour(d, t):
    d.polygon([(16, 20), (32, 10), (48, 20), (48, 40), (32, 52), (16, 40)], fill=STEEL)
    d.polygon([(22, 24), (32, 16), (42, 24), (42, 36), (32, 44), (22, 36)], fill=STEEL_HI)
    if t:
        d.line([(32, 16), (32, 44)], fill=ORANGE, width=2)


def whipple(d, t):
    for k, inset in enumerate((14, 20, 26)):
        d.arc([inset, 10 + k * 6, 64 - inset, 58 - k * 2], 200, 340,
              fill=STEEL_HI if k % 2 == 0 else STEEL, width=2)
    if t:
        d.line([(12, 44), (52, 44)], fill=ORANGE, width=2)


def antenna(d, t):
    if t:
        d.arc([10, 12, 54, 56], 190, 350, fill=STEEL_HI, width=3)
        d.arc([16, 18, 48, 50], 200, 340, fill=STEEL, width=2)
    else:
        d.arc([18, 14, 46, 42], 180, 360, fill=STEEL, width=3)
    d.line([32, 30, 32, 50], fill=STEEL_SH, width=2)
    d.point((32, 28), fill=CYAN)


def buffer(d, t):
    for i in range(4 if not t else 5):
        y = 16 + i * 7
        d.rectangle([18, y, 46, y + 5], fill=STEEL if i % 2 else DARK)
        d.rectangle([22, y + 1, 26, y + 4], fill=CYAN)
    if t:
        d.rectangle([14, 52, 50, 56], fill=ORANGE)


def science(d, t):
    d.polygon([(26, 10), (38, 10), (38, 22), (46, 48), (18, 48)], fill=STEEL)
    d.polygon([(28, 26), (36, 26), (41, 46), (23, 46)], fill=CYAN)
    d.ellipse([27, 6, 37, 14], fill=STEEL_HI)
    if t:
        d.ellipse([44, 18, 54, 28], fill=GOLD)


def sensor(d, t):
    d.ellipse([16, 16, 48, 48], fill=STEEL)
    d.ellipse([22, 22, 42, 42], fill=DARK)
    d.ellipse([28, 28, 36, 36], fill=CYAN)
    for a in (0, 90, 180, 270):
        d.point((32 + int(18 * (a == 0) - 18 * (a == 180)), 32 + int(18 * (a == 90) - 18 * (a == 270))), fill=WHITE)
    if t:
        d.arc([8, 8, 56, 56], 0, 360, fill=STEEL_HI, width=2)


def salvage(d, t):
    d.line([(32, 12), (32, 34)], fill=STEEL, width=4)
    d.arc([16, 30, 28, 46], 270, 90, fill=STEEL_HI, width=3)
    d.arc([36, 30, 48, 46], 90, 270, fill=STEEL_HI, width=3)
    d.rectangle([28, 8, 36, 14], fill=DARK)
    if t:
        d.ellipse([24, 40, 40, 52], fill=CYAN)


def repair(d, t):
    d.line([(20, 46), (42, 20)], fill=STEEL, width=5)
    d.arc([36, 10, 52, 26], 200, 340, fill=STEEL_HI, width=4)
    d.ellipse([16, 40, 26, 52], fill=DARK)
    if t:
        d.rectangle([16, 12, 26, 22], fill=ORANGE)


FAMILIES = {
    "wheel": (gyro, "gyro"), "wheel2": (gyro, "gyro"),
    "ion": (ion, "ion"), "ion2": (ion, "ion"),
    "rtg": (rtg, "rtg"), "rtg2": (rtg, "rtg"),
    "fuel_cell": (cell, "cell"), "fuel_cell2": (cell, "cell"),
    "radiator": (radiator, "rad"), "radiator2": (radiator, "rad"),
    "coolant": (coolant, "cool"), "coolant2": (coolant, "cool"),
    "armor": (armour, "arm"), "armor2": (armour, "arm"),
    "whipple": (whipple, "whp"), "whipple2": (whipple, "whp"),
    "antenna": (antenna, "ant"), "antenna2": (antenna, "ant"),
    "buffer": (buffer, "buf"), "buffer2": (buffer, "buf"),
    "science_pack": (science, "sci"), "science2": (science, "sci"),
    "sensor": (sensor, "sen"), "sensor2": (sensor, "sen"),
    "salvage": (salvage, "salv"), "repair": (repair, "rep"),
}


SYSTEM_ACCENT = {
    "wheel": (255, 170, 60), "ion": (255, 170, 60),
    "rtg": (84, 230, 209), "fuel_cell": (84, 230, 209),
    "radiator": (228, 120, 46), "coolant": (228, 120, 46),
    "armor": (150, 162, 176), "whipple": (150, 162, 176),
    "antenna": (108, 214, 132), "buffer": (108, 214, 132),
    "science_pack": (176, 132, 236), "sensor": (176, 132, 236),
    "salvage": (232, 223, 200), "repair": (232, 223, 200),
}


def base_id(part_id):
    return part_id[:-1] if part_id.endswith("2") and part_id not in ("wheel2",) else part_id


def detail(d, part_id, t):
    """Shared per-system material pass: rivets, seams, and a segmented housing
    on tier 2 so A and B differ in silhouette, not just in colour."""
    sys_id = part_id.rstrip("2") if part_id not in ("salvage", "repair") else part_id
    accent = SYSTEM_ACCENT.get(sys_id, SYSTEM_ACCENT.get(part_id, CYAN))
    for p in ((8, 8), (55, 8), (8, 55), (55, 55)):
        d.point(p, fill=STEEL_HI)
    d.line([(10, 46), (54, 46)], fill=(30, 34, 42))
    if t:
        # segmented housing: ribs on both flanks + a hatch, so the B build reads
        # as a different casing at 40 px
        for y in range(16, 52, 6):
            d.line([(6, y), (6, y + 3)], fill=accent)
            d.line([(57, y), (57, y + 3)], fill=accent)
        d.rectangle([40, 50, 52, 56], fill=(40, 46, 56))
        d.line([(40, 50), (52, 50)], fill=accent)
    else:
        d.rectangle([8, 50, 20, 56], fill=(40, 46, 56))


def portrait(part_id):
    fn, _ = FAMILIES[part_id]
    img = base(64)
    d = ImageDraw.Draw(img)
    t = part_id.endswith("2")
    fn(d, t)
    detail(d, part_id, t)
    img = outline(img)
    return img.resize((128, 128), Image.Resampling.NEAREST)


def ship_module(part_id):
    fn, _ = FAMILIES[part_id]
    img = base(64)
    d = ImageDraw.Draw(img)
    t = part_id.endswith("2")
    fn(d, t)
    detail(d, part_id, t)
    img = outline(img)
    return img.resize((64, 48), Image.Resampling.NEAREST)


def buff_icon(kind):
    img = base(64)
    d = ImageDraw.Draw(img)
    if kind == "reactor":
        d.ellipse([12, 12, 52, 52], fill=STEEL)
        d.ellipse([26, 26, 38, 38], fill=GOLD)
        for a in (0, 120, 240):
            import math
            r = math.radians(a)
            d.line([(32 + 12 * math.cos(r), 32 + 12 * math.sin(r)),
                    (32 + 24 * math.cos(r), 32 + 24 * math.sin(r))], fill=STEEL_HI, width=2)
    elif kind == "harden":
        d.polygon([(16, 18), (32, 10), (48, 18), (48, 40), (32, 52), (16, 40)], fill=STEEL)
        d.polygon([(22, 22), (32, 15), (42, 22), (42, 37), (32, 46), (22, 37)], fill=ORANGE)
    elif kind == "aerogel":
        for i, r in enumerate((20, 15, 10)):
            d.ellipse([32 - r, 32 - r, 32 + r, 32 + r], fill=(200, 214, 226, 120 + i * 40))
    elif kind == "sling":
        d.arc([10, 18, 54, 62], 200, 340, fill=STEEL_HI, width=3)
        d.ellipse([46, 16, 54, 24], fill=CYAN)
    elif kind == "deepnet":
        for p in ((16, 20), (48, 18), (20, 46), (46, 46), (32, 32)):
            d.ellipse([p[0] - 4, p[1] - 4, p[0] + 4, p[1] + 4], fill=CYAN)
        for a, b in (((16, 20), (32, 32)), ((48, 18), (32, 32)), ((20, 46), (32, 32)), ((46, 46), (32, 32))):
            d.line([a, b], fill=STEEL, width=1)
    elif kind == "science":
        d.polygon([(32, 10), (40, 40), (24, 40)], fill=STEEL_HI)
        d.ellipse([22, 34, 42, 52], fill=CYAN)
    elif kind == "favor":
        d.ellipse([14, 20, 50, 50], outline=GOLD, width=3)
        d.line([(32, 22), (32, 44)], fill=GOLD, width=3)
    elif kind == "ranger":
        d.polygon([(32, 8), (44, 32), (32, 40), (20, 32)], fill=ORANGE)
    elif kind == "shield":
        d.polygon([(16, 16), (32, 8), (48, 16), (48, 38), (32, 52), (16, 38)], fill=STEEL_HI)
        d.line([(32, 14), (32, 44)], fill=INK, width=2)
    elif kind == "cache":
        d.rectangle([16, 20, 48, 46], fill=DARK)
        d.rectangle([20, 24, 44, 30], fill=GOLD)
        d.rectangle([20, 34, 44, 40], fill=STEEL)
    elif kind == "legacy":
        for a in (0, 60, 120, 180, 240, 300):
            import math
            r = math.radians(a)
            d.line([(32, 32), (32 + 20 * math.cos(r), 32 + 20 * math.sin(r))], fill=GOLD, width=2)
        d.ellipse([28, 28, 36, 36], fill=CYAN)
    elif kind == "repair":
        d.line([(18, 46), (42, 20)], fill=STEEL, width=5)
        d.arc([36, 10, 52, 26], 200, 340, fill=ORANGE, width=4)
    return img.resize((128, 128), Image.Resampling.NEAREST)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    SHIP.mkdir(parents=True, exist_ok=True)
    BUFF.mkdir(parents=True, exist_ok=True)
    for pid in FAMILIES:
        portrait(pid).save(OUT / f"{pid}.png")
        ship_module(pid).save(SHIP / f"{pid}.png")
    buffs = ["reactor", "harden", "aerogel", "sling", "deepnet", "science",
             "favor", "ranger", "shield", "cache", "legacy", "repair"]
    for b in buffs:
        buff_icon(b).save(BUFF / f"{b}.png")
    (OUT / "manifest.json").write_text(json.dumps({
        "portraits": {"dir": "res://assets/sprites/modules", "size": [128, 128], "ids": list(FAMILIES)},
        "ship": {"dir": "res://assets/sprites/modules/ship", "size": [64, 48], "ids": list(FAMILIES)},
        "buffs": {"dir": "res://assets/sprites/buffs_hd", "size": [128, 128], "ids": buffs},
        "method": "drawn on a 64 px grid, scaled NEAREST; tier 2 adds a stage + warm accent",
    }, indent=2) + "\n")
    sheet = Image.new("RGBA", (7 * 136, 4 * 150), (16, 24, 38, 255))
    for i, pid in enumerate(FAMILIES):
        sheet.alpha_composite(Image.open(OUT / f"{pid}.png"), (4 + (i % 7) * 136, 4 + (i // 7) * 150))
    sheet.save(OUT / "preview.png")
    print(f"wrote {len(FAMILIES)} portraits, {len(FAMILIES)} ship modules, {len(buffs)} buffs")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""FLIGHT BINDER // 1975 — UI skin kit (9-slice + strips + stamps).

Everything here is drawn with integer pixel geometry so the 9-slices stay
crisp at 640x360 and 1280x720. Paper fibre is procedural noise, not
diffusion, so every corner of a panel is identical.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "ui" / "skin"
FONT_DIR = ROOT / "assets" / "ui"

PAPER = (232, 223, 200)
PAPER_DARK = (206, 195, 168)
PAPER_EDGE = (150, 138, 112)
INK = (27, 26, 23)
NIGHT = (16, 24, 38)
ORANGE = (228, 87, 46)
RED = (184, 51, 47)
TEAL = (95, 143, 138)
AMBER = (255, 196, 92)

rng = np.random.default_rng(7)


def fibre(img: Image.Image, amount=5) -> Image.Image:
    """Add ±amount paper grain, only inside opaque pixels."""
    a = np.asarray(img).astype(np.int16)
    noise = rng.integers(-amount, amount + 1, a.shape[:2])
    for k in range(3):
        a[..., k] = np.where(a[..., 3] > 0, np.clip(a[..., k] + noise, 0, 255), a[..., k])
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def panel(w, h, border, fill=PAPER, edge=PAPER_EDGE, shadow=True, ink_shadow=True):
    """Flat 9-slice panel: even border, flat centre, optional hard offset shadow."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], fill=(*fill, 255), outline=(*edge, 255))
    d.rectangle([1, 1, w - 2, h - 2], outline=(*PAPER_DARK, 255)) if border > 3 else None
    # inner rule line: the "form" look of a printed sheet
    if border >= 8:
        d.rectangle([border - 3, border - 3, w - border + 2, h - border + 2], outline=(*edge, 140))
    img = fibre(img, 4)
    if shadow and ink_shadow:
        out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
        sh = Image.new("RGBA", (w, h), (*INK, 90))
        out.alpha_composite(sh, (2, 2))
        out.alpha_composite(img, (0, 0))
        return out
    return img


def button(state):
    w, h = 44, 18
    fill, edge, text = PAPER, PAPER_EDGE, INK
    if state == "hover":
        fill, edge = (240, 232, 212), ORANGE
    elif state == "active":
        fill, edge, text = (246, 236, 210), ORANGE, INK
    elif state == "pressed":
        fill, edge = PAPER_DARK, INK
    img = panel(w, h, 5, fill=fill, edge=edge, shadow=(state != "pressed"))
    d = ImageDraw.Draw(img)
    if state == "active":
        d.line([3, h - 3, w - 4, h - 3], fill=(*ORANGE, 255), width=2)
    if state == "pressed":
        d.line([0, 0, w - 1, 0], fill=(*INK, 255))
    return img


def tape(w, h, hazard=False):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if hazard:
        d.rectangle([0, 0, w - 1, h - 1], fill=(*AMBER, 255))
        for x in range(-h, w, 8):
            d.polygon([(x, h), (x + 4, h), (x + 4 + h, 0), (x + h, 0)], fill=(*INK, 255))
    else:
        d.rectangle([0, 0, w - 1, h - 1], fill=(236, 226, 200, 190))
        for x in range(0, w, 3):
            d.line([x, 0, x, h - 1], fill=(214, 202, 174, 90))
    return img


def punch(size=10):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, size - 1, size - 1], fill=(*NIGHT, 255))
    d.arc([0, 0, size - 1, size - 1], 180, 360, fill=(*INK, 255))
    return img


def stamp(text, colour, w=None, h=22, rot=0):
    f = ImageFont.truetype(str(FONT_DIR / "Silkscreen-Bold.ttf"), 10)
    tw = f.getbbox(text)[2]
    w = w or (tw + 12)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], outline=(*colour, 255), width=2)
    d.text(((w - tw) // 2, (h - 10) // 2 - 1), text, font=f, fill=(*colour, 255))
    # ink texture: punch a few pixels out so it reads stamped, not printed
    a = np.asarray(img).astype(np.uint8)
    holes = rng.random(a.shape[:2]) < 0.06
    a[holes, 3] = 0
    img = Image.fromarray(a, "RGBA")
    if rot:
        img = img.rotate(rot, resample=Image.Resampling.NEAREST, expand=True)
    return img


def barcode(w=96, h=12):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], fill=(*PAPER, 255))
    x = 2
    while x < w - 2:
        bw = int(rng.choice([1, 1, 2, 3]))
        if rng.random() > 0.35:
            d.rectangle([x, 2, x + bw - 1, h - 3], fill=(*INK, 255))
        x += bw + int(rng.choice([1, 2]))
    return img


def ruler(w=160, h=14):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], fill=(*PAPER, 255), outline=(*INK, 255))
    for x in range(4, w - 4, 4):
        long = (x - 4) % 20 == 0
        d.line([x, 1, x, 5 if long else 3], fill=(*INK, 255))
    d.line([4, h - 3, w - 5, h - 3], fill=(*INK, 255))
    return img


def paper_texture(size=64):
    base = np.full((size, size, 4), (*PAPER, 255), np.uint8)
    base[..., :3] = np.clip(base[..., :3] + rng.integers(-7, 8, (size, size, 1)), 0, 255)
    img = Image.fromarray(base, "RGBA")
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    made = {}

    p = panel(48, 48, 12)
    p.save(OUT / "folder_panel.png"); made["folder_panel"] = dict(size=p.size, slice=12, shadow=2)

    tab = panel(64, 20, 6, fill=(240, 232, 212))
    tab.save(OUT / "folder_tab.png"); made["folder_tab"] = dict(size=tab.size, slice=6)

    # corner clip + punched margin are separate overlays so the panel itself
    # stays a true 9-slice
    corner = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    cd = ImageDraw.Draw(corner)
    cd.polygon([(0, 0), (10, 0), (16, 6), (16, 16), (0, 16)], fill=(*PAPER, 255))
    cd.line([(10, 0), (16, 6)], fill=(*PAPER_EDGE, 255))
    cd.line([(10, 1), (15, 6)], fill=(*PAPER_DARK, 255))
    corner.save(OUT / "folder_corner.png")
    made["folder_corner"] = dict(size=(16, 16), anchor="top-right")

    holes = Image.new("RGBA", (12, 44), (0, 0, 0, 0))
    hd = ImageDraw.Draw(holes)
    for i in range(3):
        y = 4 + i * 14
        hd.ellipse([1, y, 9, y + 8], fill=(*NIGHT, 255))
        hd.arc([1, y, 9, y + 8], 180, 360, fill=(*INK, 255))
    holes.save(OUT / "folder_holes.png")
    made["folder_holes"] = dict(size=(12, 44), anchor="left-middle")

    c = panel(32, 32, 8)
    c.save(OUT / "card.png"); made["card"] = dict(size=c.size, slice=8, shadow=2)

    for st in ("idle", "hover", "active", "pressed"):
        b = button(st)
        b.save(OUT / f"tab_{st}.png")
        made[f"tab_{st}"] = dict(size=b.size, slice=5, shadow=(0 if st == "pressed" else 2))

    tape(32, 14, hazard=True).save(OUT / "tape_hazard.png")
    tape(32, 12, hazard=False).save(OUT / "tape_masking.png")
    made["tape_hazard"] = dict(size=(32, 14), tile=True)
    made["tape_masking"] = dict(size=(32, 12), tile=True)

    punch(10).save(OUT / "punch_hole.png"); made["punch_hole"] = dict(size=(10, 10))

    stamps = {
        "stamp_approved": ("APPROVED", ORANGE, 0),
        "stamp_flagged": ("FLAGGED", RED, -2),
        "stamp_survey_complete": ("SURVEY COMPLETE", TEAL, 1),
        "stamp_grade_a": ("GRADE A", ORANGE, -1),
        "stamp_grade_b": ("GRADE B", TEAL, 1),
        "stamp_grade_c": ("GRADE C", RED, 2),
    }
    for name, (text, col, rot) in stamps.items():
        im = stamp(text, col, rot=rot)
        im.save(OUT / f"{name}.png")
        made[name] = dict(size=im.size, rotation=rot)

    barcode(96, 12).save(OUT / "barcode_strip.png"); made["barcode_strip"] = dict(size=(96, 12))
    ruler(160, 14).save(OUT / "ruler_strip.png"); made["ruler_strip"] = dict(size=(160, 14), tile_x=True)
    paper_texture(64).save(OUT / "paper_texture.png"); made["paper_texture"] = dict(size=(64, 64), tile=True)

    manifest = {
        "theme": "flight-binder-1975",
        "palette": {
            "paper": "#e8dfc8", "ink": "#1b1a17", "night": "#101826",
            "orange": "#e4572e", "red": "#b8332f", "teal": "#5f8f8a",
            "live_cyan": "#54e6d1", "amber": "#ffc45c",
        },
        "fonts": {"stamp": "res://assets/ui/Silkscreen-Bold.ttf", "body": "res://assets/ui/IBMPlexMono-Regular.ttf"},
        "nine_slices": {k: v for k, v in made.items() if "slice" in v},
        "tiles": [k for k, v in made.items() if v.get("tile")],
        "stamps": [k for k in made if k.startswith("stamp_")],
        "notes": "Hard 2 px ink offset shadows; pressed buttons drop the shadow and shift down 1 px in code.",
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    # contact sheet
    files = sorted(OUT.glob("*.png"))
    sheet = Image.new("RGBA", (520, 120 + 26 * ((len(files) + 3) // 4) + 150), (*NIGHT, 255))
    d = ImageDraw.Draw(sheet)
    f = ImageFont.truetype(str(FONT_DIR / "Silkscreen-Regular.ttf"), 10)
    d.text((10, 8), "FLIGHT BINDER // SKIN KIT", font=f, fill=(*PAPER, 255))
    d.text((10, 24), "paper, tabs, tape, stamps, strips", font=f, fill=(*TEAL, 255))
    x, y = 10, 48
    for i, fp in enumerate(files):
        if fp.name == "preview.png" or fp.name.endswith("_preview.png"):
            continue
        im = Image.open(fp).convert("RGBA")
        sheet.alpha_composite(im, (x, y))
        d.text((x, y + im.size[1] + 2), fp.stem[:14], font=f, fill=(*PAPER_DARK, 255))
        x += max(im.size[0], 110) + 8
        if x > 400:
            x, y = 10, y + 46
    sheet.save(OUT / "preview.png")
    print(f"wrote {len(files)} files to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Placeholder bust for the Chief Engineer briefing.

VEGA owns the final character sheet. This 80x120 (2x = 160x240) placeholder
exists so the briefing scene, layout and first-run flow can be tested now. It
uses the same file names VEGA will replace.

Usage: python3 tools/make_director_placeholder.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "crew"
RAW = ROOT / "assets" / "raw" / "crew"

SKIN = (214, 164, 126, 255)
SKIN_DARK = (174, 120, 88, 255)
HAIR = (58, 36, 44, 255)
HAIR_LIGHT = (86, 52, 62, 255)
NAVY = (24, 38, 54, 255)
NAVY_LIGHT = (38, 58, 78, 255)
ORANGE = (228, 87, 46, 255)
TEAL = (91, 155, 150, 255)
INK = (20, 20, 18, 255)
PAPER = (232, 223, 200, 255)
CYAN = (84, 230, 209, 255)
GOLD = (255, 196, 92, 255)


def base() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    im = Image.new("RGBA", (80, 120), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Shoulders / flight jacket.
    d.polygon([(6, 120), (18, 94), (31, 86), (49, 86), (62, 94), (74, 120)], fill=NAVY)
    d.polygon([(18, 94), (31, 86), (34, 96), (26, 102)], fill=NAVY_LIGHT)
    d.polygon([(62, 94), (49, 86), (46, 96), (54, 102)], fill=NAVY_LIGHT)
    # Neck.
    d.rectangle((34, 68, 46, 88), fill=SKIN)
    d.rectangle((34, 68, 46, 74), fill=SKIN_DARK)
    # Head.
    d.ellipse((25, 24, 55, 74), fill=SKIN)
    d.polygon([(28, 62), (34, 76), (46, 76), (52, 62)], fill=SKIN)
    d.polygon([(28, 62), (34, 76), (37, 76), (31, 60)], fill=SKIN_DARK)
    d.polygon([(52, 62), (46, 76), (43, 76), (49, 60)], fill=SKIN_DARK)
    # Hair: bob silhouette, face left clear.
    d.ellipse((23, 18, 57, 58), fill=HAIR)
    d.rectangle((23, 38, 30, 70), fill=HAIR)
    d.rectangle((50, 38, 57, 70), fill=HAIR)
    d.polygon([(23, 40), (18, 58), (24, 62), (27, 46)], fill=HAIR)
    d.polygon([(57, 40), (62, 58), (56, 62), (53, 46)], fill=HAIR)
    d.arc((26, 18, 54, 46), 200, 340, fill=HAIR_LIGHT, width=2)
    # Ears.
    d.rectangle((23, 48, 26, 57), fill=SKIN_DARK)
    d.rectangle((54, 48, 57, 57), fill=SKIN_DARK)
    # Collar + zip.
    d.polygon([(30, 86), (38, 92), (34, 104), (24, 100)], fill=ORANGE)
    d.polygon([(50, 86), (42, 92), (46, 104), (56, 100)], fill=ORANGE)
    d.line([(40, 92), (40, 120)], fill=NAVY_LIGHT, width=1)
    # Badge.
    d.rectangle((22, 102, 30, 110), fill=GOLD, outline=INK)
    d.point((26, 105), fill=INK)
    # Headset.
    d.arc((22, 20, 58, 58), 200, 340, fill=INK, width=2)
    d.rectangle((53, 48, 58, 58), fill=INK)
    d.line([(56, 56), (50, 64)], fill=INK, width=1)
    return im, d


def face(im: Image.Image, d: ImageDraw.ImageDraw, expr: str) -> None:
    # Eye sockets / whites / irises.
    for x in (32, 44):
        d.rectangle((x, 46, x + 6, 51), fill=(191, 128, 100, 255))
        d.rectangle((x + 1, 47, x + 5, 50), fill=PAPER)
        d.rectangle((x + 3, 48, x + 4, 50), fill=CYAN)
        d.rectangle((x + 3, 49, x + 4, 50), fill=INK)
        d.point((x + 2, 47), fill=PAPER)
    if expr == "neutral":
        d.line([(33, 43), (38, 43)], fill=HAIR, width=1)
        d.line([(45, 43), (50, 43)], fill=HAIR, width=1)
        d.line([(39, 62), (44, 62)], fill=(140, 82, 66, 255), width=1)
    elif expr == "smile":
        d.line([(33, 42), (38, 43)], fill=HAIR, width=1)
        d.line([(45, 43), (50, 42)], fill=HAIR, width=1)
        d.arc((37, 57, 47, 65), 20, 160, fill=(140, 82, 66, 255), width=1)
        d.point((31, 54), fill=(226, 146, 126, 255))
        d.point((52, 54), fill=(226, 146, 126, 255))
    else:  # stern
        d.line([(33, 42), (38, 46)], fill=HAIR, width=1)
        d.line([(45, 46), (50, 42)], fill=HAIR, width=1)
        d.line([(38, 62), (46, 61)], fill=(140, 82, 66, 255), width=1)
    # Nose.
    d.line([(40, 52), (39, 58), (42, 58)], fill=(140, 82, 66, 255), width=1)
    d.point((33, 55), fill=(226, 146, 126, 255))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    RAW.mkdir(parents=True, exist_ok=True)
    icons = []
    for expr in ("neutral", "smile", "stern"):
        im, d = base()
        face(im, d, expr)
        big = im.resize((160, 240), Image.Resampling.NEAREST)
        big.save(OUT / f"director_{expr}.png")
        icons.append(big)
    # Dialogue icon: head crop, 64x64.
    head = icons[0].crop((34, 30, 130, 126)).resize((64, 64), Image.Resampling.NEAREST)
    head.save(OUT / "director_icon.png")
    # Contact sheet.
    sheet = Image.new("RGBA", (3 * 176 + 8, 256), (16, 24, 38, 255))
    for i, im in enumerate(icons):
        sheet.alpha_composite(im, (8 + i * 176, 8))
    sheet.save("/tmp/opencode/director_placeholder.png")
    print("wrote placeholder portraits to", OUT)


if __name__ == "__main__":
    main()

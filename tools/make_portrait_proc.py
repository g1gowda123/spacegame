#!/usr/bin/env python3
"""Dr. Imani Vale — hand-built pixel portrait (160x240), three expressions.

Diffusion kept giving a dark, muddy face at this size, so this portrait is drawn
on the pixel grid instead: flat shapes, a 1 px ink contour, expression driven by
brow/mouth/eye parameters only. The face is identical by construction, which is
what the brief actually asks for.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "crew"
W, H = 160, 240

INK = (26, 24, 30)
SKIN = (232, 200, 172)
SKIN_SH = (206, 170, 142)
SKIN_DEEP = (170, 130, 106)
HAIR = (38, 32, 40)
HAIR_HI = (62, 54, 66)
NAVY = (22, 32, 48)
NAVY_HI = (36, 52, 74)
CREAM = (232, 223, 200)
ORANGE = (228, 87, 46)
CYAN = (84, 230, 209)
WHITE = (244, 240, 232)
LIP = (176, 108, 96)
LIP_DARK = (128, 74, 70)


def ellipse(d, box, fill):
    d.ellipse(box, fill=fill)


def body(d):
    # shoulders
    d.polygon([(16, 240), (30, 206), (58, 194), (102, 194), (130, 206), (144, 240)], fill=NAVY)
    # shirt collar
    d.polygon([(70, 194), (80, 214), (90, 194), (84, 190), (76, 190)], fill=CREAM)
    # collar wings
    d.polygon([(56, 194), (72, 196), (72, 216), (58, 212)], fill=NAVY_HI)
    d.polygon([(104, 194), (88, 196), (88, 216), (102, 212)], fill=NAVY_HI)
    # rank stripe + badge
    d.line([(36, 232), (52, 214)], fill=ORANGE, width=2)
    d.rectangle([58, 214, 68, 222], fill=ORANGE)
    d.rectangle([60, 216, 66, 220], fill=CREAM)
    d.rectangle([92, 216, 104, 219], fill=CREAM)


def head(d):
    # hair mass behind the face
    d.ellipse([38, 44, 122, 152], fill=HAIR)
    # neck
    d.rectangle([68, 140, 92, 196], fill=SKIN_SH)
    d.rectangle([70, 140, 90, 190], fill=SKIN)
    # face
    d.ellipse([46, 58, 114, 150], fill=SKIN)
    # jaw taper
    d.polygon([(52, 128), (108, 128), (96, 150), (64, 150)], fill=SKIN)
    # left-side shading (light from upper right)
    d.pieslice([46, 58, 114, 150], 120, 240, fill=SKIN_SH)
    d.ellipse([48, 60, 112, 148], fill=SKIN)
    # ears
    ellipse(d, [42, 96, 52, 116], SKIN_SH)
    ellipse(d, [108, 96, 118, 116], SKIN)
    # fringe
    d.pieslice([40, 46, 120, 110], 180, 360, fill=HAIR)
    d.polygon([(48, 78), (60, 66), (78, 74), (74, 82), (54, 86)], fill=HAIR)
    d.polygon([(98, 72), (112, 78), (110, 88), (96, 84)], fill=HAIR)
    # hair highlight
    d.arc([44, 50, 116, 104], 200, 320, fill=HAIR_HI, width=2)


def face(d, expr):
    """expr: neutral | smile | stern"""
    eye_y = 100
    for cx in (66, 94):
        d.rectangle([cx - 6, eye_y - 3, cx + 6, eye_y + 3], fill=WHITE)
        d.ellipse([cx - 4, eye_y - 4, cx + 4, eye_y + 4], fill=(56, 74, 92))
        d.ellipse([cx - 2, eye_y - 2, cx + 2, eye_y + 2], fill=INK)
        d.point((cx - 3, eye_y - 2), fill=WHITE)
        d.line([cx - 6, eye_y - 4, cx + 6, eye_y - 4], fill=INK)
        if expr == "stern":
            d.line([cx - 7, eye_y - 6, cx + 5, eye_y - 3], fill=INK)     # lowering lid
    # brows
    if expr == "stern":
        d.line([(58, 88), (72, 92)], fill=INK, width=2)
        d.line([(102, 88), (88, 92)], fill=INK, width=2)
    elif expr == "smile":
        d.line([(58, 90), (72, 87)], fill=INK, width=2)
        d.line([(102, 90), (88, 87)], fill=INK, width=2)
    else:
        d.line([(58, 89), (72, 88)], fill=INK, width=2)
        d.line([(102, 89), (88, 88)], fill=INK, width=2)
    # nose
    d.line([(80, 104), (80, 118)], fill=SKIN_SH)
    d.point((79, 118), fill=SKIN_DEEP)
    d.point((82, 118), fill=SKIN_DEEP)
    d.point((78, 110), fill=SKIN_DEEP)
    # mouth
    my = 132
    if expr == "smile":
        d.line([(72, my), (88, my)], fill=LIP_DARK)
        d.line([(70, my - 1), (72, my)], fill=LIP_DARK)
        d.line([(88, my), (90, my - 1)], fill=LIP_DARK)
        d.line([(74, my + 2), (86, my + 2)], fill=WHITE)
        d.line([(74, my + 3), (86, my + 3)], fill=LIP)
    elif expr == "stern":
        d.line([(72, my + 1), (88, my + 1)], fill=LIP_DARK)
        d.line([(70, my + 2), (72, my + 1)], fill=LIP_DARK)
        d.line([(88, my + 1), (90, my + 2)], fill=LIP_DARK)
        d.line([(76, my + 2), (84, my + 2)], fill=LIP)
    else:
        d.line([(73, my), (87, my)], fill=LIP_DARK)
        d.line([(75, my + 1), (85, my + 1)], fill=LIP)
    # cheeks
    if expr == "smile":
        d.arc([58, 112, 66, 120], 200, 340, fill=SKIN_SH)
        d.arc([94, 112, 102, 120], 200, 340, fill=SKIN_SH)


def headset(d):
    d.arc([34, 46, 126, 132], 190, 350, fill=INK, width=5)
    d.arc([36, 48, 124, 130], 190, 350, fill=(52, 60, 72), width=2)
    # ear cup on the viewer-left side
    d.rounded_rectangle([26, 88, 46, 124], radius=6, fill=(40, 46, 58), outline=INK)
    d.rounded_rectangle([30, 94, 42, 116], radius=4, fill=(58, 66, 80))
    d.rectangle([33, 102, 39, 108], fill=CYAN)
    # boom mic
    d.line([(44, 118), (62, 130)], fill=(40, 46, 58), width=2)
    d.ellipse([58, 126, 68, 134], fill=(40, 46, 58), outline=INK)


def outline(img):
    """1 px ink contour around the silhouette."""
    a = img.split()[-1]
    grown = a.filter(ImageFilter.MaxFilter(3))
    edge = Image.eval(grown, lambda v: 255 if v > 0 else 0)
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    lay.putalpha(edge)
    lay = Image.composite(Image.new("RGBA", img.size, INK + (255,)), lay, edge)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(lay)
    out.alpha_composite(img)
    # drop the outline on the very bottom rows so the fade is clean
    return out


def build(expr):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    body(d)
    head(d)
    face(d, expr)
    headset(d)
    img = outline(img)
    # soft bottom fade so the bust does not end on a hard cut
    import numpy as np
    a = np.asarray(img).astype(np.uint8).copy()
    fade = (np.clip((H - 1 - np.arange(H)) / 18.0, 0, 1) ** 1.2)[:, None]
    a[..., 3] = (a[..., 3] * fade).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    imgs = {}
    for expr in ("neutral", "smile", "stern"):
        im = build(expr)
        imgs[expr] = im
        im.save(OUT / f"director_{expr}.png")
    icon = imgs["neutral"].crop((52, 52, 108, 108)).resize((64, 64), Image.Resampling.NEAREST)
    icon.save(OUT / "director_icon.png")
    (OUT / "manifest.json").write_text(json.dumps({
        "character": "Dr. Imani Vale — executive secretary",
        "size": [160, 240],
        "expressions": ["neutral", "smile", "stern"],
        "method": "hand-built pixel portrait (tools/make_portrait_proc.py); expression is a parameter, so the face cannot drift",
        "palette": {"ink": "#1a181e", "skin": ["#e8c8ac", "#ceaa8e", "#aa826a"],
                    "hair": ["#262028", "#3e3642"], "navy": "#16202f",
                    "cream": "#e8dfc8", "orange": "#e4572e", "cyan": "#54e6d1"},
        "usage": "transparent, 18 px bottom fade, drawn under the dialogue card",
    }, indent=2) + "\n")
    sheet = Image.new("RGBA", (W * 3 + 20, H + 20), (232, 223, 200, 255))
    for i, e in enumerate(("neutral", "smile", "stern")):
        sheet.alpha_composite(imgs[e], (5 + i * (W + 5), 10))
    sheet.save("/tmp/opencode/vale_proc.png")
    print("wrote 3 expressions + icon")


if __name__ == "__main__":
    main()

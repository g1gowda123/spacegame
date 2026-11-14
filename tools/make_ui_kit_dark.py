#!/usr/bin/env python3
"""Dark-blue/cyan 9-slice kit — the look the boss kept ("the old version").

Same pixel geometry as the paper kit, but in the console palette the game
already uses: navy plates, steel borders, cyan for live values only, amber for
caution. Nothing here is wired in; it is a drop-in set for NOVA to trial.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "ui" / "skin_dark"

NAVY = (16, 24, 38)
PLATE = (23, 33, 50)
PLATE_HI = (31, 44, 66)
EDGE = (58, 82, 112)
EDGE_DIM = (38, 54, 76)
CYAN = (84, 230, 209)
AMBER = (255, 196, 92)
RED = (222, 78, 72)
TEXT = (206, 226, 235)

rng = np.random.default_rng(11)


def grain(img, amount=3):
    a = np.asarray(img).astype(np.int16)
    n = rng.integers(-amount, amount + 1, a.shape[:2])
    for k in range(3):
        a[..., k] = np.where(a[..., 3] > 0, np.clip(a[..., k] + n, 0, 255), a[..., k])
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def panel(w, h, border=12, fill=PLATE, edge=EDGE, glow=False):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], fill=(*fill, 255), outline=(*edge, 255))
    d.rectangle([2, 2, w - 3, h - 3], outline=(*EDGE_DIM, 255))
    if glow:
        d.rectangle([3, 3, w - 4, h - 4], outline=(*CYAN, 70))
    img = grain(img)
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    out.alpha_composite(Image.new("RGBA", (w, h), (0, 0, 0, 120)), (2, 2))
    out.alpha_composite(img, (0, 0))
    return out


def button(state):
    w, h = 44, 18
    fill, edge = PLATE, EDGE
    if state == "hover":
        fill, edge = PLATE_HI, CYAN
    elif state == "active":
        fill, edge = (26, 44, 58), CYAN
    elif state == "pressed":
        fill, edge = (14, 20, 32), EDGE_DIM
    img = panel(w, h, 5, fill=fill, edge=edge, glow=(state in ("hover", "active")))
    d = ImageDraw.Draw(img)
    if state == "active":
        d.line([3, 3, w - 4, 3], fill=(*CYAN, 255))
    if state == "pressed":
        d.line([0, 0, w - 1, 0], fill=(*EDGE_DIM, 255))
    return img


def gauge(w=96, h=10):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], fill=(*NAVY, 255), outline=(*EDGE_DIM, 255))
    for i in range(6):
        x = 3 + i * ((w - 6) // 6)
        d.line([x, 2, x, h - 3], fill=(*EDGE_DIM, 255))
    d.rectangle([2, 2, int(w * 0.45), h - 3], fill=(*CYAN, 255))
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    made = {}
    p = panel(48, 48, 12)
    p.save(OUT / "panel.png"); made["panel"] = dict(size=p.size, slice=12, shadow=2)

    c = panel(32, 32, 8)
    c.save(OUT / "card.png"); made["card"] = dict(size=c.size, slice=8, shadow=2)

    t = panel(64, 18, 6, fill=PLATE_HI, edge=EDGE)
    t.save(OUT / "tab.png"); made["tab"] = dict(size=t.size, slice=6)

    for st in ("idle", "hover", "active", "pressed"):
        b = button(st)
        b.save(OUT / f"button_{st}.png")
        made[f"button_{st}"] = dict(size=b.size, slice=5, shadow=(0 if st == "pressed" else 2))

    gauge().save(OUT / "gauge.png"); made["gauge"] = dict(size=(96, 10), tile_x=False)
    gauge().save(OUT / "gauge_bg.png")

    (OUT / "manifest.json").write_text(json.dumps({
        "theme": "console-dark (boss-preferred look)",
        "palette": {"navy": "#101826", "plate": "#172132", "edge": "#3a5270",
                    "cyan": "#54e6d1", "amber": "#ffc45c", "red": "#de4e48", "text": "#cee2eb"},
        "note": "cyan is reserved for live values, hover and the active tab; amber for caution",
        "files": made,
    }, indent=2) + "\n")

    bg = Image.new("RGBA", (340, 150), (*NAVY, 255))
    bg.alpha_composite(p, (10, 10))
    for i, st in enumerate(("idle", "hover", "active", "pressed")):
        bg.alpha_composite(Image.open(OUT / f"button_{st}.png"), (200, 12 + i * 24))
    bg.alpha_composite(gauge(), (10, 120))
    bg.resize((680, 300), Image.Resampling.NEAREST).save(OUT / "preview.png")
    print(f"wrote {len(list(OUT.glob('*.png')))} files")


if __name__ == "__main__":
    main()

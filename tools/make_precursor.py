#!/usr/bin/env python3
"""Precursor ruins — alien, not Earth infrastructure.

Four silhouette-first forms: a leaning monolith, a half-buried ring segment, a
faceted lattice shell with no opening, and a smooth cylinder with a spiral
seam. Palette-locked to the obsidian/crystal ramp, transparent, no shadow, no
baked ground.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from pixelize import apply_palette  # noqa: E402
from make_structure_pieces import spec  # noqa: E402

OUT = ROOT / "assets" / "tilesets" / "structures"
S = 192


def canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def monolith():
    img = canvas()
    d = ImageDraw.Draw(img)
    # leaning slab with a sharp, impossible overhang
    d.polygon([(70, 176), (96, 40), (120, 44), (128, 178)], fill=(96, 88, 116, 255))
    d.polygon([(96, 40), (120, 44), (112, 52), (90, 48)], fill=(150, 140, 176, 255))
    d.polygon([(70, 176), (82, 176), (100, 60), (96, 40)], fill=(70, 64, 88, 255))
    for y in range(70, 170, 22):
        d.line([(74 + (y - 70) * 0.3, y), (126 - (y - 70) * 0.1, y + 2)], fill=(56, 50, 72, 255))
    d.line([(112, 60), (116, 150)], fill=(196, 186, 214, 160))
    return img


def ring_segment():
    img = canvas()
    d = ImageDraw.Draw(img)
    box = [26, 96, 166, 236]
    d.arc(box, 190, 350, fill=(104, 96, 128, 255), width=16)
    d.arc(box, 190, 350, fill=(168, 158, 198, 255), width=4)
    for a in range(196, 344, 18):
        r = np.deg2rad(a)
        cx, cy = 96, 166
        d.line([(cx + 70 * np.cos(r), cy + 70 * np.sin(r)),
                (cx + 78 * np.cos(r), cy + 78 * np.sin(r))], fill=(60, 54, 76, 255))
    d.rectangle([30, 200, 162, 226], fill=(0, 0, 0, 0))
    return img


def lattice_shell():
    img = canvas()
    d = ImageDraw.Draw(img)
    cx, cy, r = 96, 140, 58
    d.ellipse([cx - r, cy - r * 0.62, cx + r, cy + r * 0.62], outline=(126, 118, 152, 255), width=3)
    for i in range(8):
        a = i * np.pi / 4
        d.line([(cx + r * np.cos(a), cy + r * 0.62 * np.sin(a)),
                (cx + r * 0.55 * np.cos(a), cy - r * 0.95)], fill=(108, 100, 134, 255))
        d.line([(cx + r * 0.55 * np.cos(a), cy - r * 0.95),
                (cx, cy - r * 1.15)], fill=(108, 100, 134, 255))
    d.line([(cx, cy - r * 1.15), (cx, cy - r * 0.2)], fill=(150, 140, 178, 255))
    d.rectangle([cx - r - 6, cy + r * 0.55, cx + r + 6, cy + r * 0.62], fill=(72, 66, 92, 255))
    return img


def spiral_cylinder():
    img = canvas()
    d = ImageDraw.Draw(img)
    d.rectangle([56, 58, 136, 178], fill=(88, 80, 108, 255))
    d.ellipse([56, 46, 136, 70], fill=(140, 130, 168, 255))
    d.ellipse([56, 166, 136, 190], fill=(68, 62, 88, 255))
    for k in range(7):
        y = 74 + k * 15
        d.arc([50, y - 10, 142, y + 10], 200, 340, fill=(190, 180, 216, 170), width=2)
    d.line([(96, 58), (96, 178)], fill=(70, 64, 90, 120))
    return img


BUILD = {"precursor_monolith": monolith, "precursor_ring": ring_segment,
         "precursor_lattice": lattice_shell, "precursor_cylinder": spiral_cylinder}


def main():
    manifest = {"theme": "precursor ruins (alien, non-industrial)", "anchor": "bottom-centre",
                "shadow": "none — renderer draws it", "keys": {}}
    for name, fn in BUILD.items():
        img = apply_palette(fn(), spec("obsidian"))
        img.save(OUT / f"{name}.png")
        bbox = img.split()[-1].getbbox()
        manifest["keys"][name] = {"file": f"res://assets/tilesets/structures/{name}.png",
                                  "bbox": list(bbox) if bbox else None, "footprint": "2x2"}
    (OUT / "precursor_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    sheet = Image.new("RGBA", (S * 4, S + 16), (16, 24, 38, 255))
    for i, name in enumerate(BUILD):
        sheet.alpha_composite(Image.open(OUT / f"{name}.png"), (i * S, 8))
    sheet.save(OUT / "precursor_preview.png")
    print("wrote 4 precursor ruins")


if __name__ == "__main__":
    main()

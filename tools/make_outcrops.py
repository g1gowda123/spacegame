#!/usr/bin/env python3
"""W6 — feature dressing: hero + supporting outcrops.

One silhouette per key, then supporting pieces at 0.55 / 0.35 scale with ±8 %
scale and ±4 % tint jitter so a board can repeat a rock without it reading as
a stamp. Everything stays transparent, palette-locked and shadow-free; the
renderer draws the contact ellipse.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from pixelize import apply_palette  # noqa: E402
from make_structure_pieces import spec  # noqa: E402

SRC = {
    "temperate": "mountain_range.png",
    "arid": "mesa.png",
    "cryo": "iceberg.png",
    "volcanic": "crystal_outcrop.png",
    "ocean": "coral_spire.png",
    "barren": "impact_crater.png",
}
OUT = ROOT / "assets" / "tilesets" / "outcrops"


def tint(img, rng, amount=0.04):
    a = np.asarray(img).astype(np.float32)
    m = 1.0 + rng.uniform(-amount, amount)
    a[..., :3] = np.clip(a[..., :3] * m, 0, 255)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"layer": "outcrops (W6)", "anchor": "bottom-centre", "shadow": "none — renderer draws it", "keys": {}}
    rng = np.random.default_rng(6613)
    for biome, src_name in SRC.items():
        src = Image.open(ROOT / "assets" / "tilesets" / "structures" / src_name).convert("RGBA")
        bbox = src.split()[-1].getbbox()
        if bbox:
            src = src.crop(bbox)
        entries = []
        for role, scale in (("hero", 1.0), ("sup_a", 0.55), ("sup_b", 0.35)):
            jitter = 1.0 + rng.uniform(-0.08, 0.08)
            w = max(8, int(src.size[0] * scale * jitter))
            h = max(8, int(src.size[1] * scale * jitter))
            im = src.resize((w, h), Image.Resampling.LANCZOS)
            im = apply_palette(tint(im, rng), spec(biome))
            name = f"{biome}_{role}.png"
            im.save(OUT / name)
            entries.append({"file": f"res://assets/tilesets/outcrops/{name}", "size": [w, h]})
        manifest["keys"][biome] = {"source": src_name, "pieces": entries}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    sheet = Image.new("RGBA", (560, 300), (16, 24, 38, 255))
    x = 10
    for biome in SRC:
        for role in ("hero", "sup_a", "sup_b"):
            im = Image.open(OUT / f"{biome}_{role}.png")
            sheet.alpha_composite(im, (x, 150 - im.size[1] // 2))
            x += im.size[0] + 6
        x += 10
        if x > 480:
            x = 10
    sheet.resize((1120, 600), Image.Resampling.NEAREST).save(OUT / "preview.png")
    print(f"wrote {len(SRC) * 3} outcrops")


if __name__ == "__main__":
    main()

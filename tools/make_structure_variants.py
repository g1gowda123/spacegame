#!/usr/bin/env python3
"""Silhouette variants for structures that repeat on the board.

Two identical crystal spires side by side is the tell that a map is generated.
Each key gets two extra variants: mirrored, ±6 % scale, ±5 % tint, plus a small
silhouette edit (a cropped toe or an extra notch) so the outline itself differs
and not just the colour.
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

S = ROOT / "assets" / "tilesets" / "structures"
OUT = S / "variants"
KEYS = {
    "crystal_outcrop": "crystal",
    "coral_spire": "ocean",
    "iceberg": "cryo",
    "mesa": "arid",
    "mountain_range": "temperate",
    "geyser": "volcanic",
}


def notch(img, rng):
    """Cut a wedge out of one side so the silhouette is not a pure mirror."""
    a = np.asarray(img).copy()
    w, h = a.shape[1], a.shape[0]
    side = bool(rng.integers(0, 2))
    depth = int(w * rng.uniform(0.10, 0.18))
    top = int(h * rng.uniform(0.30, 0.55))
    bottom = int(h * rng.uniform(0.70, 0.92))
    for y in range(top, min(bottom, h)):
        span = int(depth * (1.0 - abs((y - (top + bottom) / 2) / max(1, (bottom - top) / 2))))
        if side:
            a[y, max(0, w - 1 - span):w, 3] = 0
        else:
            a[y, 0:span, 3] = 0
    return Image.fromarray(a, "RGBA")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(8811)
    manifest = {"purpose": "silhouette variants so structures do not repeat", "keys": {}}
    for name, biome in KEYS.items():
        src = Image.open(S / f"{name}.png").convert("RGBA")
        entries = [{"file": f"res://assets/tilesets/structures/{name}.png", "role": "base"}]
        for v in ("v2", "v3"):
            im = src.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if v == "v3" else src.copy()
            im = notch(im, rng)
            scale = 1.0 + rng.uniform(-0.06, 0.06)
            w = max(8, int(im.size[0] * scale))
            h = max(8, int(im.size[1] * scale))
            im = im.resize((w, h), Image.Resampling.LANCZOS)
            a = np.asarray(im).astype(np.float32)
            a[..., :3] = np.clip(a[..., :3] * (1.0 + rng.uniform(-0.05, 0.05)), 0, 255)
            im = apply_palette(Image.fromarray(a.astype(np.uint8), "RGBA"), spec(biome))
            p = OUT / f"{name}_{v}.png"
            im.save(p)
            entries.append({"file": f"res://assets/tilesets/structures/variants/{name}_{v}.png",
                            "role": v, "size": [w, h]})
        manifest["keys"][name] = entries
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    sheet = Image.new("RGBA", (900, 220), (16, 24, 38, 255))
    x = 8
    for name in KEYS:
        for v in ("", "_v2", "_v3"):
            p = S / f"{name}{v}.png" if not v else OUT / f"{name}{v}.png"
            if not p.exists():
                continue
            im = Image.open(p)
            sheet.alpha_composite(im, (x, 200 - im.size[1]))
            x += im.size[0] + 8
        x += 12
    sheet.save(OUT / "preview.png")
    print(f"wrote {len(KEYS) * 2} variants")


if __name__ == "__main__":
    main()

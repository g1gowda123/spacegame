#!/usr/bin/env python3
"""Two small visual-debt assets.

1. Hazard-front edge strips: the zone currently paints as a flat lavender band.
   These sit on the leading edge and break it into wisps, so the boundary reads
   as a moving front instead of a fill colour.
2. A low-contrast landing ring that sits *under* the lander instead of competing
   with it: thin, dashed, no glow.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "tilesets" / "fx"
OUT.mkdir(parents=True, exist_ok=True)


def wisps(width=64, height=18, seed=1):
    rng = np.random.default_rng(seed)
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for x in range(0, width, 2):
        h = int(8 + 6 * rng.random())
        a = int(70 + 90 * rng.random())
        d.line([(x, height - h), (x + 1, height - 1)], fill=(176, 150, 206, a))
    for _ in range(5):
        x = int(rng.uniform(0, width))
        y = int(rng.uniform(2, 10))
        r = int(rng.uniform(2, 5))
        d.ellipse([x - r, y - r // 2, x + r, y + r // 2], fill=(196, 172, 220, 60))
    return img


def landing_ring(w=72, h=34):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(0, 360, 18):
        d.arc([2, 2, w - 3, h - 3], i, i + 10, fill=(255, 196, 92, 210), width=2)
    d.arc([8, 8, w - 9, h - 9], 0, 360, fill=(255, 196, 92, 90), width=1)
    return img


def main():
    made = {}
    for i, name in enumerate(("hazard_edge_n", "hazard_edge_s", "hazard_edge_e", "hazard_edge_w")):
        im = wisps(seed=11 + i)
        if name.endswith(("_s", "_e")):
            im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        if name.endswith(("_e", "_w")):
            im = im.rotate(90, expand=True)
        im.save(OUT / f"{name}.png")
        made[name] = dict(size=list(im.size), anchor="edge, tile along the front")
    ring = landing_ring()
    ring.save(OUT / "lz_ring.png")
    made["lz_ring"] = dict(size=list(ring.size), anchor="centre on start_cell",
                           note="dashed amber, no glow, drawn under the lander")
    (OUT / "manifest.json").write_text(json.dumps({
        "purpose": "hazard-front edge + subordinate landing ring",
        "palette": {"hazard": "#b096ce", "amber": "#ffc45c"},
        "files": made,
    }, indent=2) + "\n")
    print(f"wrote {len(made)} fx assets")


if __name__ == "__main__":
    main()

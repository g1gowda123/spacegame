#!/usr/bin/env python3
"""Faint agency-window inset for the briefing screen.

Fills the empty middle third with a station window / orbit track at ~12 %
opacity so it reads as a viewport behind the dialogue, never competing with
the paper card. Transparent PNG, 640x360, drawn in 1 px lines.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "backgrounds" / "briefing_station.png"
W, H = 640, 360
LINE = (206, 220, 214)


def main():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # hull window ring, off-centre so it sits in the empty third
    cx, cy, r = 372, 176, 150
    for rad, a in ((r, 34), (r - 6, 18), (r + 22, 12)):
        d.ellipse([cx - rad, cy - rad * 0.92, cx + rad, cy + rad * 0.92],
                  outline=(*LINE, a), width=1)

    # radial mullions
    for i in range(8):
        ang = i * np.pi / 4 + 0.18
        d.line([cx + np.cos(ang) * (r - 8), cy + np.sin(ang) * (r - 8) * 0.92,
                cx + np.cos(ang) * (r + 20), cy + np.sin(ang) * (r + 20) * 0.92],
               fill=(*LINE, 22), width=1)

    # orbit track sweeping through the frame
    pts = [(x, 232 - int(26 * np.sin((x - 40) / 96.0))) for x in range(40, 620, 2)]
    d.line(pts, fill=(*LINE, 26), width=1)
    for px in range(70, 620, 74):
        py = 232 - int(26 * np.sin((px - 40) / 96.0))
        d.ellipse([px - 2, py - 2, px + 2, py + 2], outline=(*LINE, 40))

    # station silhouette, far lower-left, very faint
    d.rectangle([28, 292, 128, 306], outline=(*LINE, 18))
    d.rectangle([44, 280, 92, 292], outline=(*LINE, 14))
    d.line([28, 306, 8, 330], fill=(*LINE, 12))
    d.line([128, 306, 150, 330], fill=(*LINE, 12))

    # registration ticks along the bottom edge (paper-plan feel)
    for x in range(0, W, 40):
        d.line([x, H - 6, x, H - 2], fill=(*LINE, 16))

    img.save(OUT)
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

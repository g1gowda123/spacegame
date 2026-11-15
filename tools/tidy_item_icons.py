#!/usr/bin/env python3
"""Tidy the 128 px item icons: kill key spill, ink the edge, flatten to the ramp.

The shop/card icons came from the older key that left a khaki halo along the
anti-aliased rim and no contour, so at card size they read as pasted cut-outs.
This snaps every pixel to the shared hardware ramp, hard-thresholds alpha and
re-draws a 2 px ink contour.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_module_art import PAL, lock_rgb  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
DIRS = [ROOT / "assets" / "sprites" / "buffs_hd", ROOT / "assets" / "sprites" / "buffs"]
INK = np.array([22, 24, 30], np.uint8)


def tidy(img: Image.Image, contour: int = 2) -> Image.Image:
    a = np.asarray(img.convert("RGBA")).astype(np.float32)
    alpha = a[..., 3] > 128
    alpha = ndimage.binary_fill_holes(alpha)
    lab, n = ndimage.label(alpha)
    if n > 1:
        sizes = ndimage.sum(alpha, lab, range(1, n + 1))
        alpha = lab == int(np.argmax(sizes)) + 1
    a[..., :3] = lock_rgb(a[..., :3])
    out = np.dstack([a[..., :3], np.where(alpha, 255, 0)]).astype(np.uint8)
    m = out[..., 3] > 0
    for _ in range(contour):
        pad = np.pad(m, 1)
        edge = m & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
        out[edge, :3] = INK
        m = ndimage.binary_erosion(m, iterations=1)
    return Image.fromarray(out, "RGBA")


def main() -> None:
    only = [x for x in sys.argv[1:] if not x.startswith("-")]
    for d in DIRS:
        for p in sorted(d.glob("*.png")):
            if p.stem.startswith("_") or (only and p.stem not in only):
                continue
            tidy(Image.open(p)).save(p)
            print("ok", p)


if __name__ == "__main__":
    main()

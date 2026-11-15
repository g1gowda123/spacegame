#!/usr/bin/env python3
"""Re-polish the module portraits from their raws — crisper edges, real margins.

The shop cards exposed two faults at 52 px: parts touched the tile edge (the
ARMT ring looked cropped) and stray screws survived the key, so the silhouette
read as debris. This re-runs the existing key + palette lock with a 6 px margin,
drops islands under 14 % of the largest, keeps alpha binary and re-inks the
contour after the downscale.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_module_art import BUFFS, BUFF, OUT, PARTS, RAW, SHIP, key, lock_rgb  # noqa: E402

INK = (22, 24, 30)


def polish(raw: Path, w: int, h: int, margin: int = 6, blur: float = 1.4) -> Image.Image:
    img = key(Image.open(raw))
    bb = img.split()[-1].getbbox()
    if bb:
        img = img.crop(bb)
    if blur:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    tw, th = w - 2 * margin, h - 2 * margin
    s = min(tw / img.width, th / img.height)
    img = img.resize((max(1, int(round(img.width * s))), max(1, int(round(img.height * s)))),
                     Image.Resampling.LANCZOS)
    a = np.asarray(img).astype(np.float32)
    solid = a[..., 3] >= 128
    solid = ndimage.binary_fill_holes(solid)
    solid = ndimage.binary_opening(solid, iterations=1)
    lab, n = ndimage.label(solid)
    if n > 1:
        sizes = ndimage.sum(solid, lab, range(1, n + 1))
        solid = lab == (int(np.argmax(sizes)) + 1)
        solid = ndimage.binary_fill_holes(solid)

    canvas = np.zeros((h, w, 4), np.uint8)
    rgb = lock_rgb(a[..., :3])
    ox, oy = (w - img.width) // 2, (h - img.height) // 2
    canvas[oy:oy + img.height, ox:ox + img.width, :3] = rgb
    canvas[oy:oy + img.height, ox:ox + img.width, 3] = np.where(solid, 255, 0)

    # 1 px ink contour, drawn after the downscale so it never gets blurred away
    m = canvas[..., 3] > 0
    pad = np.pad(m, 1)
    edge = m & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    canvas[edge, :3] = INK
    return Image.fromarray(canvas, "RGBA")


def main() -> None:
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    parts = [p for p in PARTS if not only or p in only]
    for pid in parts:
        raw = RAW / f"{pid}.png"
        if not raw.exists():
            print("skip (no raw)", pid)
            continue
        polish(raw, 128, 128).save(OUT / f"{pid}.png")
        polish(raw, 64, 48, margin=3, blur=1.2).save(SHIP / f"{pid}.png")
        print("ok", pid, flush=True)
    if not only:
        for bid in BUFFS:
            raw = RAW / f"buff_{bid}.png"
            if raw.exists():
                polish(raw, 128, 128).save(BUFF / f"{bid}.png")
        print("buffs done")


if __name__ == "__main__":
    main()

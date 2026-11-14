#!/usr/bin/env python3
"""Crop one isolated object out of a diffusion prop sheet and pixelize it.

The Pixel Art XL model often answers "single boulder" with a sheet of many
boulders.  gen_asset.py then keeps the whole sheet, which reads as a noisy
square when placed on the map.  This script keys the border colour, finds the
largest interior connected component, crops it with padding, and hands it to
pixelize.py so the result is one 64px prop with the biome palette and outline.

Usage:
  crop_prop.py raw.png out.png --palette "$P_TEMP" --outline 16,20,14
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


def border_colour(im: Image.Image, band: int = 8) -> np.ndarray:
    a = np.asarray(im.convert("RGB"), dtype=np.int32)
    edges = np.concatenate([
        a[:band, :, :].reshape(-1, 3),
        a[-band:, :, :].reshape(-1, 3),
        a[:, :band, :].reshape(-1, 3),
        a[:, -band:, :].reshape(-1, 3),
    ])
    return np.median(edges, axis=0)


def crop_one(src: Path, dst: Path) -> None:
    im = Image.open(src).convert("RGB")
    a = np.asarray(im, dtype=np.int32)
    bg = border_colour(im)
    mask = np.sqrt(((a - bg) ** 2).sum(axis=2)) > 32.0
    mask = ndimage.binary_opening(mask, iterations=1)
    labels, count = ndimage.label(mask, structure=np.ones((3, 3)))
    if count == 0:
        raise SystemExit(f"no foreground found in {src}")

    h, w = mask.shape
    best = None
    fallback = None
    for i in range(1, count + 1):
        ys, xs = np.where(labels == i)
        if len(xs) < 80:
            continue
        x0, x1 = int(xs.min()), int(xs.max())
        y0, y1 = int(ys.min()), int(ys.max())
        touches = x0 <= 1 or y0 <= 1 or x1 >= w - 2 or y1 >= h - 2
        area = len(xs)
        candidate = (area, x0, y0, x1, y1)
        if touches:
            if fallback is None or area > fallback[0]:
                fallback = candidate
        else:
            if best is None or area > best[0]:
                best = candidate
    pick = best or fallback
    if pick is None:
        raise SystemExit(f"no suitable component in {src}")
    _, x0, y0, x1, y1 = pick
    bw, bh = x1 - x0 + 1, y1 - y0 + 1
    pad = int(max(bw, bh) * 0.12)
    side = max(bw, bh) + pad * 2
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    left = max(0, cx - side // 2)
    top = max(0, cy - side // 2)
    right = min(w, left + side)
    bottom = min(h, top + side)
    left = max(0, right - side)
    top = max(0, bottom - side)
    crop = im.crop((left, top, right, bottom))
    crop.save(dst)
    print(f"crop {src.name}: bbox=({x0},{y0},{x1},{y1}) -> {crop.size}")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("input", type=Path)
    p.add_argument("output", type=Path)
    p.add_argument("--palette", required=True, help="comma-separated hex colours")
    p.add_argument("--outline", required=True, help="r,g,b")
    p.add_argument("--colors", type=int, default=16)
    args = p.parse_args()

    crop = args.output.with_name(args.output.stem + "_crop.png")
    crop_one(args.input, crop)
    cmd = [
        sys.executable,
        str(Path(__file__).with_name("pixelize.py")),
        str(crop),
        str(args.output),
        "--size", "64",
        "--colors", str(args.colors),
        "--palette", args.palette,
        "--bg", "auto",
        "--outline", args.outline,
    ]
    subprocess.run(cmd, check=True)


if __name__ == "__main__":
    main()

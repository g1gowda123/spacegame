#!/usr/bin/env python3
"""Composite diagonal water/land split tiles (64x64, four orientations).

A cell that is half water on a straight diagonal cannot be built from the
edge/corner transition set, which is why one-cell diagonal coasts still render
as right-angle spurs. Each tile here cuts the cell on the named diagonal, then
adds a 1 px wet shoreline on the land side and a 1 px darker water edge on the
water side, so the seam matches the straight transition tiles.

Usage:
  make_diagonal.py --land assets/tilesets/temperate/grass.png \
                   --water assets/tilesets/temperate/water_lake.png \
                   --outdir assets/tilesets/transitions/diagonal/temperate_grass_temperate_water_lake
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


def water_mask(corner: str, size: int) -> np.ndarray:
    yy, xx = np.mgrid[0:size, 0:size]
    if corner == "nw":
        return (xx + yy) < size - 1
    if corner == "se":
        return (xx + yy) > size - 1
    if corner == "ne":
        return yy < xx
    if corner == "sw":
        return yy > xx
    raise SystemExit(f"unknown corner {corner}")


def shift_or(mask: np.ndarray, dy: int, dx: int) -> np.ndarray:
    out = np.zeros_like(mask)
    h, w = mask.shape
    ys0, ys1 = max(0, dy), min(h, h + dy)
    xs0, xs1 = max(0, dx), min(w, w + dx)
    out[ys0:ys1, xs0:xs1] = mask[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return out


def build(land: Image.Image, water: Image.Image, corner: str) -> Image.Image:
    size = land.width
    a = np.asarray(land.convert("RGB"), dtype=np.float32)
    b = np.asarray(water.convert("RGB"), dtype=np.float32)

    wet = water_mask(corner, size)
    out = np.where(wet[..., None], b, a)

    # One pixel of land that touches the water reads as wet sand: pull it
    # toward the brightest water tone instead of leaving a hard colour step.
    land_band = (~wet) & (shift_or(wet, 1, 0) | shift_or(wet, -1, 0)
                          | shift_or(wet, 0, 1) | shift_or(wet, 0, -1))
    bright = b.reshape(-1, 3)[np.argsort(b.reshape(-1, 3).sum(axis=1))[-max(1, b.shape[0] * b.shape[1] // 50):]]
    wet_sand = bright.mean(axis=0)
    out[land_band] = out[land_band] * 0.55 + wet_sand * 0.45

    # One pixel of water that touches land is the darker shelf edge.
    water_band = wet & (shift_or(~wet, 1, 0) | shift_or(~wet, -1, 0)
                        | shift_or(~wet, 0, 1) | shift_or(~wet, 0, -1))
    out[water_band] *= 0.72

    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    img.putalpha(255)
    return img


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--land", required=True, type=Path)
    p.add_argument("--water", required=True, type=Path)
    p.add_argument("--outdir", required=True, type=Path)
    p.add_argument("--corners", default="nw,ne,se,sw")
    args = p.parse_args()

    land = Image.open(args.land)
    water = Image.open(args.water)
    if land.size != water.size:
        raise SystemExit(f"size mismatch: {land.size} vs {water.size}")
    args.outdir.mkdir(parents=True, exist_ok=True)

    tiles = []
    for corner in [c.strip() for c in args.corners.split(",") if c.strip()]:
        img = build(land, water, corner)
        img.save(args.outdir / f"{corner}.png")
        tiles.append(img)

    # 4-up preview: one row, corners in nw/ne/sw/se order for reading.
    size = land.width
    order = {"nw": 0, "ne": 1, "sw": 2, "se": 3}
    sheet = Image.new("RGB", (size * 4 + 12, size), (20, 20, 26))
    for img in tiles:
        name = img.info.get("_corner", "")
        _ = name
    for i, corner in enumerate([c.strip() for c in args.corners.split(",") if c.strip()]):
        sheet.paste(Image.open(args.outdir / f"{corner}.png").convert("RGB"),
                    (i * (size + 4), 0))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.Resampling.NEAREST).save(
        args.outdir / "preview.png"
    )
    print(f"wrote {len(tiles)} tiles + preview in {args.outdir}")


if __name__ == "__main__":
    main()

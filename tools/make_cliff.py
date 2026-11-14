#!/usr/bin/env python3
"""Cut cliff-edge tiles out of an existing rock tile.

A cliff tile is not new terrain art: it is the rock tile plus a bevel. The
renderer owns light direction, but the tile still has to read as an edge on
its own, so each tile gets a 2-3 px lit lip along the rim, a band of slightly
darker, vertically stretched rock for the face, and a 1 px dark base line.
The rest of the tile is the plateau surface.

Heights: low (face 18 px), mid (24 px), high (30 px).
Directions: n, e, s, w — the rim sits on that edge of the tile.

Usage:
  make_cliff.py --rock assets/tilesets/temperate/rock.png --biome temperate \
                --outdir assets/tilesets/temperate/cliffs
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from pixelize import apply_palette  # noqa: E402

SIZE = 64
HEIGHTS = {"low": 30, "mid": 40, "high": 50}
DIRS = ("n", "e", "s", "w")


def palette_spec(biome: str) -> str:
    palettes = json.loads((ROOT / "tools" / "palettes.json").read_text())
    if biome not in palettes:
        raise SystemExit(f"unknown palette '{biome}'")
    return ",".join(c.lstrip("#") for c in palettes[biome]["colors"])


def dominant_colours(rock: np.ndarray, k: int = 6) -> np.ndarray:
    """Most common colours of the rock tile — the cliff face reuses its hues."""
    im = Image.fromarray(rock.astype(np.uint8), "RGB").resize((32, 32), Image.Resampling.LANCZOS)
    q = im.quantize(colors=k, method=Image.Quantize.MEDIANCUT).convert("RGB")
    arr = np.array(q).reshape(-1, 3)
    uniq, counts = np.unique(arr, axis=0, return_counts=True)
    order = np.argsort(-counts)
    return uniq[order][:k].astype(np.float32)


def rock_face(size: int, height: int, colours: np.ndarray,
              rng: np.random.Generator) -> np.ndarray:
    """A stratified rock wall: beds, vertical shading, seams, cracks, grit."""
    lum = colours.sum(axis=1)
    order = np.argsort(lum)
    mid = colours[order[len(order) // 5: max(len(order) * 4 // 5, len(order) // 5 + 1)]]
    if not len(mid):
        mid = colours
    face = np.zeros((height, size, 3), np.float32)
    y = 0
    while y < height:
        bed = max(3, int(rng.integers(4, 10)))
        c = mid[int(rng.integers(0, len(mid)))] * rng.uniform(0.80, 1.10)
        face[y:y + bed] = c
        y += bed
    # per-column shading, smoothed so beds do not look like tiles
    col = ndi.gaussian_filter(rng.normal(1.0, 0.20, size).astype(np.float32), 1.2)
    face *= col[None, :, None]
    # vertical light falloff: the renderer does not shade terrain tiles, so the
    # wall itself has to go from lit (rim) to dark (foot).
    grad = np.linspace(1.12, 0.62, height, dtype=np.float32)[:, None, None]
    face *= grad
    # grit: fine per-pixel variance survives the palette lock as texture
    face *= (1.0 + rng.normal(0.0, 0.10, (height, size, 1))).astype(np.float32)
    # horizontal bedding seams with a lit ledge under each
    for yy in rng.choice(np.arange(1, height), size=max(1, height // 7), replace=False):
        face[yy] *= 0.66
        if yy + 1 < height:
            face[yy + 1] = np.clip(face[yy + 1] * 1.18 + 8.0, 0, 255)
    # vertical cracks
    for _ in range(max(1, size // 16)):
        x = int(rng.integers(1, size - 1))
        y0 = int(rng.integers(0, max(1, height - 4)))
        y1 = min(height, y0 + int(rng.integers(5, 14)))
        face[y0:y1, x] *= 0.55
    return np.clip(face, 0, 255)


def build(rock: np.ndarray, height: int, direction: str,
          rng: np.random.Generator, ground: np.ndarray | None = None) -> Image.Image:
    if ground is None:
        ground = rock
    base = rock.astype(np.float32)
    plateau = np.clip(ground.astype(np.float32) * 1.02 + 2.0, 0, 255)
    # The face is the same rock as the plateau, darkened and vertically
    # graded: a wall built of the local stone, not a new material.
    face = np.clip(base * 1.0, 0, 255)
    face = ndi.zoom(face, (1.0, 1.0, 1.0), order=1)
    face = np.roll(face, int(rng.integers(0, SIZE)), axis=1)
    face = np.roll(face, int(rng.integers(0, SIZE)), axis=0)
    grad = np.linspace(1.05, 0.30, face.shape[0], dtype=np.float32)[:, None, None]
    face = face * grad
    face *= (1.0 + rng.normal(0.0, 0.045, (face.shape[0], face.shape[1], 1))).astype(np.float32)
    # vertical striations: per-column shading, smoothed, so the wall is not
    # a flat copy of the ground texture
    stripe = ndi.gaussian_filter(rng.normal(1.0, 0.16, face.shape[1]).astype(np.float32), 1.0)
    face *= stripe[None, :, None]
    face = np.clip(face, 0, 255)

    out = plateau.copy()
    # f is always a band of `height` rows across the full 64 width, with the
    # rim at row 0, so one lip/foot routine serves all four directions.
    if direction in ("n", "s"):
        f = face[:height].copy()
    else:
        f = face[:, :height].transpose(1, 0, 2).copy()

    # lit rim along the cliff top (row 0), dark line where the wall meets the
    # ground at its foot (last row)
    lip = np.clip(f[1:4].mean(axis=0) * 1.28 + 10.0, 0, 255)
    f[0:3] = lip[None, :, :]
    f[height - 1] = np.clip(f[height - 1] * 0.40, 0, 255)

    if direction == "n":
        out[:height] = f
    elif direction == "s":
        out[-height:] = f[::-1]
    elif direction == "w":
        out[:, :height] = f.transpose(1, 0, 2)
    else:
        out[:, -height:] = f[::-1].transpose(1, 0, 2)

    # a couple of loose stones at the foot break the straight line
    foot_y = height if direction == "n" else (SIZE - 1 if direction == "s" else SIZE // 2)
    for _ in range(2):
        x = int(rng.integers(2, SIZE - 3))
        y = int(np.clip(foot_y + rng.integers(-1, 2), 1, SIZE - 2))
        if direction in ("n", "s"):
            out[y:y + 1, x:x + 2] = np.clip(base[y:y + 1, x:x + 2] * 0.8, 0, 255)
        else:
            out[y:y + 2, x:x + 1] = np.clip(base[y:y + 2, x:x + 1] * 0.8, 0, 255)

    im = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")
    im = im.filter(ImageFilter.GaussianBlur(0.25))
    return im.convert("RGBA")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--rock", required=True, type=Path)
    ap.add_argument("--ground", type=Path, default=None,
                    help="tile used for the plateau half (defaults to --rock)")
    ap.add_argument("--biome", required=True)
    ap.add_argument("--outdir", required=True, type=Path)
    ap.add_argument("--seed", type=int, default=4242)
    args = ap.parse_args()

    rock = np.array(Image.open(args.rock).convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS))
    ground = np.array(Image.open(args.ground).convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS)) if args.ground else rock.copy()
    spec = palette_spec(args.biome)
    args.outdir.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(args.seed)

    names = []
    for hname, hpx in HEIGHTS.items():
        for d in DIRS:
            im = build(rock, hpx, d, rng, ground)
            im = apply_palette(im, spec)
            name = f"cliff_{hname}_{d}"
            im.save(args.outdir / f"{name}.png")
            names.append(name)

    # contact sheet: rows = heights, cols = directions
    sheet = Image.new("RGB", (SIZE * 4 + 3 * 3, SIZE * 3 + 2 * 3), (24, 24, 30))
    for ri, hname in enumerate(HEIGHTS):
        for ci, d in enumerate(DIRS):
            tile = Image.open(args.outdir / f"cliff_{hname}_{d}.png").convert("RGB")
            sheet.paste(tile, (ci * (SIZE + 3), ri * (SIZE + 3)))
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.Resampling.NEAREST).save(
        args.outdir / "preview.png")
    print(f"wrote {len(names)} cliff tiles + preview in {args.outdir}")


if __name__ == "__main__":
    main()

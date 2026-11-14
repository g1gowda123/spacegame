#!/usr/bin/env python3
"""Build the tactical-board space plate (640x360) procedurally.

Why procedural instead of diffusion: the board needs a *quiet* backdrop —
near-black navy, a faint nebula wash, sparse tiny stars — so white HUD text
stays readable. Diffusion renders keep inventing planets, bright cloud banks
or horizons, and every bright pixel competes with the HUD.

Usage:
  make_space.py --out assets/backgrounds/space.png [--seed 7]
"""

from __future__ import annotations

import argparse

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

W, H = 640, 360


def fractal(shape: tuple[int, int], rng: np.random.Generator,
            octaves: int = 5, base: int = 6) -> np.ndarray:
    """Multi-octave value noise in [0, 1], smooth and band-free."""
    acc = np.zeros(shape, np.float32)
    amp = 1.0
    total = 0.0
    for o in range(octaves):
        cells = base * (2 ** o)
        g = rng.random((max(2, cells), max(2, cells))).astype(np.float32)
        up = np.array(Image.fromarray((g * 255).astype(np.uint8)).resize(
            (shape[1], shape[0]), Image.Resampling.BICUBIC), np.float32) / 255.0
        acc += up * amp
        total += amp
        amp *= 0.55
    acc /= total
    return (acc - acc.min()) / (acc.max() - acc.min() + 1e-6)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", required=True)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--stars", type=int, default=210)
    args = ap.parse_args()

    rng = np.random.default_rng(args.seed)

    # 1. base: deep navy, very slightly lighter at the bottom.
    y = np.linspace(0.0, 1.0, H, dtype=np.float32)[:, None]
    top = np.array([5, 6, 13], np.float32)
    bot = np.array([9, 10, 21], np.float32)
    img = top[None, None, :] + (bot - top)[None, None, :] * y[:, :, None]
    img = np.repeat(img, W, axis=1)

    # 2. one faint violet-blue nebula wash, off-centre, heavily feathered.
    n = fractal((H, W), rng, octaves=5, base=5)
    yy, xx = np.mgrid[0:H, 0:W]
    cx, cy = W * 0.68, H * 0.34
    rad = np.sqrt(((xx - cx) / (W * 0.42)) ** 2 + ((yy - cy) / (H * 0.55)) ** 2)
    falloff = np.clip(1.0 - rad, 0.0, 1.0) ** 2
    wash = np.clip((n - 0.42) / 0.58, 0.0, 1.0) ** 1.6 * falloff
    neb = np.array([64, 62, 132], np.float32) * (wash * 0.30)[..., None]
    img = img + neb

    # second, colder wisp low-left so the plate is not one-sided.
    rad2 = np.sqrt(((xx - W * 0.22) / (W * 0.36)) ** 2 + ((yy - H * 0.78) / (H * 0.42)) ** 2)
    wash2 = np.clip((fractal((H, W), rng, octaves=4, base=7) - 0.5) / 0.5, 0, 1) ** 1.8
    wash2 *= np.clip(1.0 - rad2, 0.0, 1.0) ** 2
    img = img + np.array([38, 66, 110], np.float32) * (wash2 * 0.22)[..., None]

    # 3. stars: weighted toward 1 px, a handful of 2 px, a few soft glows.
    for _ in range(args.stars):
        x, y0 = rng.integers(0, W), rng.integers(0, H)
        # keep stars out of the nebula core so the wash stays soft
        if abs(x - cx) < 40 and abs(y0 - cy) < 30 and rng.random() < 0.7:
            continue
        b = rng.uniform(0.45, 1.0)
        tint = np.array([rng.uniform(0.86, 1.0), rng.uniform(0.9, 1.0), 1.0], np.float32)
        col = np.array([225, 232, 245], np.float32) * b * tint
        img[y0, x] = np.maximum(img[y0, x], col * 0.9)
        if rng.random() < 0.12:
            for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1)):
                if 0 <= y0 + dy < H and 0 <= x + dx < W:
                    img[y0 + dy, x + dx] = np.maximum(img[y0 + dy, x + dx], col * 0.35)

    for _ in range(6):
        x, y0 = rng.integers(20, W - 20), rng.integers(20, H - 20)
        glow = np.zeros((H, W), np.float32)
        glow[y0, x] = 1.0
        glow = ndi.gaussian_filter(glow, 2.6) * rng.uniform(0.35, 0.6)
        img = img + glow[..., None] * np.array([190, 205, 240], np.float32)

    # 4. gentle dither so the gradient does not band on 8-bit displays.
    img = img + rng.normal(0.0, 0.8, img.shape).astype(np.float32)
    out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    out.save(args.out)
    print(f"wrote {args.out} {out.size[0]}x{out.size[1]}")


if __name__ == "__main__":
    main()

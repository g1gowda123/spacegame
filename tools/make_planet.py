#!/usr/bin/env python3
"""Planet portraits rendered on a sphere from a procedural surface.

Why not diffusion: every SDXL planet render came back with magenta key spill
(pink deserts, mauve cloud bands) and a fractured "cracked ball" silhouette,
because the model paints a whole scene rather than a surface. This tool builds
the surface procedurally from an explicit per-biome ramp, wraps it onto a
sphere with orthographic projection, shades it with one light, adds limb
darkening plus a thin lit atmosphere rim, and palette-locks the result. All
thirteen portraits then share one visual language and stay square-on.

Usage:
  make_planet.py --biome arid --out assets/sprites/planets/arid.png --size 256
  make_planet.py --biome methane --out x.png --size 512 --seed 3
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from pixelize import apply_palette  # noqa: E402

# biome -> surface style + colours. Ramps are deliberately short: the palette
# lock reads better with 8-10 steps than with a full 16-colour tile palette.
RAMPS = {
    "temperate": dict(style="continents", land=["3d5a4a", "5c7a5e", "86a374"],
                      sea=["1c6075", "277a8d"], accent="b8e6dc", cap="e8f7ef"),
    "arid": dict(style="continents", land=["91784c", "bfa86e", "d6c184"],
                 sea=["4f3f2b", "634f34"], accent="e8dcc0", cap=None),
    "cryo": dict(style="continents", land=["8fb8cc", "b8d8e4", "e6f2f6"],
                 sea=["2f5d70", "4a8496"], accent="d8f0f8", cap="ffffff"),
    "volcanic": dict(style="continents", land=["2a1c1c", "3d2724", "52332b"],
                     sea=["a33b12", "e86a10"], accent="ffb238", cap=None),
    "ocean": dict(style="continents", land=["3696a4", "52b3ba", "7fd0ce"],
                  sea=["103446", "15485d"], accent="b8e6dc", cap="e8f7ef"),
    "barren": dict(style="continents", land=["7a7370", "918a86", "a8a29c"],
                   sea=["3a3a3e", "55555b"], accent="c9c4be", cap=None),
    "methane": dict(style="gas", land=["1b5e5a", "2f8f83", "6fc0a8"],
                    sea=["0f3234", "1a4744"], accent="8fd8c4", cap=None),
    "iron": dict(style="continents", land=["8a4a34", "a95c3e", "c07a52"],
                 sea=["3a2118", "4e2c1e"], accent="d9a06a", cap=None),
    "sulfur": dict(style="continents", land=["b39c2e", "c9b23a", "ddc94f"],
                   sea=["5a5320", "73682a"], accent="e8dc84", cap=None),
    "crystal": dict(style="continents", land=["6f5fa8", "8a78c9", "b6a8e8"],
                    sea=["2a2144", "3a2f5e"], accent="e0d6ff", cap=None),
    "obsidian": dict(style="continents", land=["3a3348", "4b4260", "5d5375"],
                     sea=["16111f", "221a2c"], accent="9a7ee6", cap=None),
    "ammonia": dict(style="continents", land=["6fa9b5", "8fc4c9", "b8dcd8"],
                    sea=["1f3d4d", "2f5d70"], accent="cfece8", cap="e0f2ef"),
    "carbon": dict(style="continents", land=["4a4a4e", "63636a", "85858c"],
                   sea=["24242a", "33333a"], accent="a8a8b2", cap=None),
}


SEA_FRAC = {
    "temperate": 0.42, "arid": 0.10, "cryo": 0.34, "volcanic": 0.26,
    "ocean": 0.72, "barren": 0.16, "iron": 0.18, "sulfur": 0.14,
    "crystal": 0.20, "obsidian": 0.24, "ammonia": 0.30, "carbon": 0.18,
}


def hex2rgb(h: str) -> np.ndarray:
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


def wrap_noise(size: int, cells: int, rng: np.random.Generator,
               sigma: float = 2.0) -> np.ndarray:
    """Smooth periodic value noise: low-res grid, bicubic up, wrapped blur."""
    cells = max(2, int(cells))
    g = (rng.random((cells, cells)) * 255).astype(np.uint8)
    up = np.array(Image.fromarray(g).resize((size, size), Image.Resampling.BICUBIC),
                  np.float32) / 255.0
    up = ndi.gaussian_filter(up, sigma, mode="wrap")
    return (up - up.min()) / (np.ptp(up) + 1e-6)


def surface(biome: str, size: int, rng: np.random.Generator) -> np.ndarray:
    spec = RAMPS[biome]
    land = np.array([hex2rgb(h) for h in spec["land"]], np.float32)
    sea = np.array([hex2rgb(h) for h in spec["sea"]], np.float32)

    if spec["style"] == "gas":
        y = np.linspace(0, 1, size, dtype=np.float32)[:, None]
        warp = (wrap_noise(size, size // 48, rng, 3.5) - 0.5) * 0.06
        bands = 0.5 + 0.5 * np.sin((y + warp) * np.pi * rng.uniform(8, 13) + rng.uniform(0, 6.2))
        turb = 0.6 * wrap_noise(size, size // 64, rng, 2.6) + 0.4 * wrap_noise(size, size // 24, rng, 1.4)
        field = np.clip(0.62 * bands + 0.38 * turb, 0, 1)
    else:
        n = (0.55 * wrap_noise(size, size // 64, rng, 3.0)
             + 0.30 * wrap_noise(size, size // 32, rng, 1.6)
             + 0.15 * wrap_noise(size, size // 16, rng, 0.9))
        field = (n - n.min()) / (np.ptp(n) + 1e-6)

    idx = np.clip((field * len(land)).astype(int), 0, len(land) - 1)
    surf = land[idx].copy()

    if spec["style"] == "continents":
        frac = SEA_FRAC.get(biome, 0.4)
        thr = np.quantile(field, frac + rng.uniform(-0.04, 0.04))
        sea_mask = field < thr
        sidx = np.clip((field / max(thr, 1e-3) * len(sea)).astype(int), 0, len(sea) - 1)
        surf[sea_mask] = sea[sidx[sea_mask]]

        yy = np.linspace(-1, 1, size, dtype=np.float32)[:, None]
        if spec["cap"]:
            cap = np.repeat(np.abs(yy) > rng.uniform(0.78, 0.88), size, axis=1)
            surf[cap] = hex2rgb(spec["cap"])

        if biome in ("barren", "carbon", "obsidian"):
            for _ in range(int(rng.integers(12, 20))):
                cx, cy = (int(v) for v in rng.integers(0, size, 2))
                r = int(rng.integers(3, max(5, size // 22)))
                yy2, xx2 = np.ogrid[-r:r + 1, -r:r + 1]
                d = np.sqrt(xx2 ** 2 + yy2 ** 2)
                bowl = d < r * 0.72
                rim = (d >= r * 0.72) & (d < r)
                ys = (cy + yy2) % size
                xs = (cx + xx2) % size
                patch = surf[ys, xs]
                patch[bowl] = patch[bowl] * 0.55
                patch[rim] = np.clip(patch[rim] * 1.30 + 8.0, 0, 255)
                surf[ys, xs] = patch

    surf = surf * (1.0 + rng.normal(0.0, 0.05, (size, size, 1))).astype(np.float32)
    return np.clip(surf, 0, 255)


def sphere(surf: np.ndarray, out_size: int, light: tuple[float, float, float],
           rim: np.ndarray, rotation: float = 0.0,
           tilt: float = 0.0) -> tuple[np.ndarray, np.ndarray]:
    size = surf.shape[0]
    r = out_size * 0.47
    cx = out_size / 2 - 0.5
    yy, xx = np.mgrid[0:out_size, 0:out_size].astype(np.float32)
    nx = (xx - cx) / r
    ny = (yy - cx) / r
    d2 = nx ** 2 + ny ** 2
    nz = np.sqrt(np.clip(1.0 - d2, 0.0, 1.0))

    # orthographic lookup; rotation + tilt are per-planet so two worlds of the
    # same biome never show the same continents in the same place
    ca, sa = np.cos(rotation), np.sin(rotation)
    rx = nx * ca - ny * sa
    ry = nx * sa + ny * ca
    cb, sb = np.cos(tilt), np.sin(tilt)
    u = (rx * 0.94 + ry * 0.12) * 0.5 + 0.5
    v = (ry * 0.94 * cb - rx * 0.12 * cb + sb * 0.35) * 0.5 + 0.5
    sx = np.clip((u * size).astype(int), 0, size - 1)
    sy = np.clip((v * size).astype(int), 0, size - 1)
    col = surf[sy, sx].astype(np.float32)

    L = np.array(light, np.float32)
    L /= np.linalg.norm(L)
    diff = np.clip(nx * L[0] + ny * L[1] + nz * L[2], 0.0, 1.0)
    shade = 0.14 + 1.02 * diff
    limb = 0.46 + 0.54 * nz ** 0.5
    col = col * (shade * limb)[..., None]

    halo = (d2 > 1.0) & (d2 < 1.16)
    halo_amt = np.clip(1.0 - (d2 - 1.0) / 0.16, 0, 1) ** 1.6
    lit = np.clip((nx * L[0] + ny * L[1]) * 0.8 + 0.42, 0, 1)
    col = np.where(halo[..., None], col + rim * (halo_amt * lit * 0.5)[..., None], col)

    alpha = np.where(d2 <= 1.0, 255.0,
                     np.where(halo, 255.0 * np.clip(halo_amt * lit, 0, 1) * 0.5, 0.0))
    return np.clip(col, 0, 255), alpha


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--biome", required=True, choices=sorted(RAMPS))
    ap.add_argument("--out", required=True)
    ap.add_argument("--size", type=int, default=256)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--surface", type=int, default=512)
    ap.add_argument("--rotation", type=float, default=None,
                   help="uv rotation in radians (default: seeded per planet)")
    ap.add_argument("--tilt", type=float, default=None,
                   help="surface tilt in radians (default: seeded per planet)")
    args = ap.parse_args()

    rng = np.random.default_rng(args.seed)
    surf = surface(args.biome, args.surface, rng)
    spec = RAMPS[args.biome]
    cols = spec["land"] + spec["sea"] + [spec["accent"]] + ([spec["cap"]] if spec["cap"] else [])
    rot = args.rotation if args.rotation is not None else rng.uniform(0.0, 6.283)
    tilt = args.tilt if args.tilt is not None else rng.uniform(-0.35, 0.35)
    rgb, alpha = sphere(surf, args.size, (-0.42, -0.50, 0.76),
                        hex2rgb(spec["accent"]) * 0.75, rot, tilt)

    im = Image.fromarray(rgb.astype(np.uint8), "RGB").convert("RGBA")
    im.putalpha(Image.fromarray(alpha.astype(np.uint8), "L"))
    im = apply_palette(im, ",".join(cols))

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    im.save(args.out)
    a = np.array(im.getchannel("A"))
    print(f"wrote {args.out} {im.size[0]}x{im.size[1]} clear={(a == 0).mean() * 100:.1f}%")


if __name__ == "__main__":
    main()

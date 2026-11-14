#!/usr/bin/env python3
"""Derive the algorithm-ground tile set from existing biome tiles.

The row-5 request is for ground *identities* the generators can place, not new
materials: a ripple, a crest, a crater rim, a vent. Every one is a
transformation of the biome's own base tile plus a palette lock, so the new
tiles sit next to the existing ones without a hue clash, and a 64 px tile stays
legible (a downscaled scene render does not: it repeats as a picture).

Usage:
  make_variants.py --list
  make_variants.py --all
  make_variants.py --only arid/dunes_ripple
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

from pixelize import apply_palette, make_seamless  # noqa: E402

SIZE = 64

# palettes.json has no entry for the tint-only biomes; keep local ramps for them.
EXTRA_PALETTES = {
    "crystal": ["160f26", "241a3c", "322452", "43326b", "584288", "6f5fa8",
                "8a78c9", "a596e0", "b6a8e8", "cfc3f5", "0d0a12", "1c1730"],
    "ammonia": ["0d1a1e", "12272b", "1a3a3f", "245057", "2f6a70", "3f878b",
                "55a5a6", "6fa9b5", "8fc4c9", "b8dcd8", "d8eeea", "0a1416"],
    "methane": ["0a1418", "102026", "16303a", "1d4150", "255767", "2f7080",
                "3d8a96", "55a5a6", "7dc0bb", "0f2a22", "17402f", "2a5c42"],
    "iron": ["1a0f0c", "2e1a12", "452518", "5c3220", "7a4028", "944f31",
             "ab5f3a", "c07a52", "d9a06a", "3a3a3e", "55555b", "8a8a90"],
    "carbon": ["0d0d10", "16161a", "222228", "31313a", "43434e", "585864",
               "71717e", "8a8a96", "a8a8b2", "0a0a0c", "1c1c22", "c8c8d2"],
}


def palette_hexes(biome: str) -> str:
    palettes = json.loads((ROOT / "tools" / "palettes.json").read_text())
    if biome in palettes:
        return ",".join(c.lstrip("#") for c in palettes[biome]["colors"])
    if biome in EXTRA_PALETTES:
        return ",".join(EXTRA_PALETTES[biome])
    raise SystemExit(f"no palette for '{biome}'")


def load(path: Path) -> np.ndarray:
    im = Image.open(path).convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    return np.asarray(im, np.float32)


def wrapnoise(cells: int, rng: np.random.Generator, sigma: float = 1.2) -> np.ndarray:
    g = (rng.random((cells, cells)) * 255).astype(np.uint8)
    up = np.array(Image.fromarray(g).resize((SIZE, SIZE), Image.Resampling.BICUBIC), np.float32) / 255
    up = ndi.gaussian_filter(up, sigma, mode="wrap")
    return (up - up.min()) / (np.ptp(up) + 1e-6)


# ---------------------------------------------------------------- operations

def ripple(a: np.ndarray, rng, amp: float = 0.16, freq: float = 0.55,
           vertical: bool = False) -> np.ndarray:
    t = np.arange(SIZE, dtype=np.float32)
    wave = np.sin(t * freq * np.pi * 2 / SIZE)
    wave = ndi.gaussian_filter(wave, 0.8, mode="wrap")
    field = wave[None, :] if not vertical else wave[:, None]
    return a * (1.0 + amp * field[..., None])


def crest(a: np.ndarray, rng, amp: float = 0.30, freq: float = 0.8) -> np.ndarray:
    t = np.arange(SIZE, dtype=np.float32)
    wave = np.sin(t * freq * np.pi * 2 / SIZE + rng.uniform(0, 6.2))
    ridge = np.clip(np.diff(wave, prepend=wave[0]) * 8.0, -1, 1)
    band = ndi.gaussian_filter(ridge, 0.7, mode="wrap")[None, :]
    a = a * (1.0 + amp * band[..., None])
    peak = band > 0.55
    a[peak.repeat(SIZE, 0)] = a[peak.repeat(SIZE, 0)] * 1.18 + 8
    return a


def flatten(a: np.ndarray, rng, amount: float = 0.45) -> np.ndarray:
    mean = a.mean(axis=(0, 1), keepdims=True)
    return a * (1 - amount) + mean * amount


def plates(a: np.ndarray, rng, cells: int = 5, seam: float = 0.55) -> np.ndarray:
    n = wrapnoise(cells, rng, 1.6)
    mask = n > 0.5
    edges = mask ^ ndi.binary_erosion(mask, iterations=1)
    edges = ndi.binary_dilation(edges, iterations=1)
    a = a * (0.9 + 0.25 * n[..., None])
    a[edges] *= seam
    return a


def cracks(a: np.ndarray, rng, n: int = 8, dark: float = 0.5) -> np.ndarray:
    h = a.copy()
    for _ in range(n):
        x, y = int(rng.integers(0, SIZE)), int(rng.integers(0, SIZE))
        dx, dy = rng.normal(0, 1), rng.normal(0, 1)
        for _ in range(int(rng.integers(8, 22))):
            x, y = int(x) % SIZE, int(y) % SIZE
            h[y, x] *= dark
            if y + 1 < SIZE:
                h[y + 1, x] *= (dark + 1) / 2
            dx += rng.normal(0, 0.45)
            dy += rng.normal(0, 0.45)
            x += dx
            y += dy
    return h


def crater_ring(a: np.ndarray, rng, radius: float = 0.30, soft: bool = False) -> np.ndarray:
    """A partial crater arc, deliberately off-centre so a 3x3 tiling does not
    stamp a ring on every cell."""
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    if soft:
        cx = rng.choice([0.1, 0.9]) * SIZE
        cy = rng.uniform(0.15, 0.85) * SIZE
    else:
        cx, cy = rng.uniform(0.3, 0.7) * SIZE, rng.uniform(0.3, 0.7) * SIZE
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (radius * SIZE)
    bowl = d < 0.82
    rim = (d >= 0.82) & (d < 1.12)
    a = a.copy()
    a[bowl] *= 0.95
    a[rim] = a[rim] * 1.06 + 3
    return a


def ejecta(a: np.ndarray, rng, n: int = 26) -> np.ndarray:
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    cx, cy = SIZE / 2, SIZE / 2
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    ang = np.arctan2(yy - cy, xx - cx)
    a = a.copy()
    for _ in range(n):
        th = rng.uniform(-np.pi, np.pi)
        width = rng.uniform(0.05, 0.16)
        length = rng.uniform(14, 30)
        sel = (np.abs(np.angle(np.exp(1j * (ang - th)))) < width) & (d < length)
        a[sel] = a[sel] * 1.0 + np.array([10, 8, 4], np.float32)
    return a


def blobs(a: np.ndarray, rng, colour: tuple[float, float, float],
          n: int = 5, rad: tuple[int, int] = (4, 11), rim: float = 0.55,
          blend: float = 1.0) -> np.ndarray:
    a = a.copy()
    for _ in range(n):
        cx, cy = rng.integers(0, SIZE, 2)
        r = int(rng.integers(*rad))
        yy, xx = np.ogrid[-r:r + 1, -r:r + 1]
        d = np.sqrt(xx ** 2 + yy ** 2)
        sel = d < r * 0.85
        ring = (d >= r * 0.85) & (d < r)
        ys = (cy + yy) % SIZE
        xs = (cx + xx) % SIZE
        patch = a[ys, xs]
        new = np.array(colour, np.float32) * (0.9 + 0.2 * rng.random())
        patch[sel] = patch[sel] * (1 - blend) + new * blend
        patch[ring] = patch[ring] * rim
        a[ys, xs] = patch
    return a


def island(a: np.ndarray, rng, colour: tuple[float, float, float] = (216, 200, 160),
           radius: float = 0.28, blend: float = 0.8) -> np.ndarray:
    """An irregular sand cay: a noise-thresholded patch, off-centre, with a
    damp rim, so the tile does not stamp a circle on every cell."""
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    cx, cy = rng.uniform(0.25, 0.75) * SIZE, rng.uniform(0.25, 0.75) * SIZE
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (radius * SIZE)
    n = wrapnoise(4, rng, 1.1)
    body = (d + (n - 0.5) * 0.45) < 1.0
    rim = body & ((d + (n - 0.5) * 0.45) > 0.78)
    a = a.copy()
    a[body] = a[body] * (1 - blend) + np.array(colour, np.float32) * blend
    a[rim] = a[rim] * 0.86
    return a


def shards(a: np.ndarray, rng, n: int = 14, light: float = 1.25) -> np.ndarray:
    a = a.copy()
    for _ in range(n):
        cx, cy = int(rng.integers(2, SIZE - 2)), int(rng.integers(2, SIZE - 2))
        h = int(rng.integers(3, 8))
        w = int(rng.integers(1, 3))
        for i in range(h):
            for j in range(w):
                y, x = cy - i, cx + j
                if 0 <= y < SIZE and 0 <= x < SIZE:
                    a[y, x] = np.clip(a[y, x] * light + 6, 0, 255)
        a[cy, cx] = np.clip(a[cy, cx] * 0.6, 0, 255)
    return a


def glow(a: np.ndarray, rng, colour: tuple[float, float, float], amount: float = 0.35) -> np.ndarray:
    n = wrapnoise(6, rng, 1.5)[..., None]
    return a * (1 - amount) + np.array(colour, np.float32) * amount * (0.7 + 0.6 * n)


def gloss(a: np.ndarray, rng, amount: float = 0.5) -> np.ndarray:
    n = wrapnoise(4, rng, 2.0)
    hi = np.clip((n - 0.62) / 0.38, 0, 1)[..., None]
    return a + hi * amount * 60.0


# ------------------------------------------------------------------ recipes
# (source tile, operations) — path keys are relative to assets/tilesets/.
RECIPES: dict[str, tuple[str, list]] = {
    "arid/dunes_ripple": ("arid/sand", [("ripple", dict(amp=0.12, freq=1.3)), ("flatten", dict(amount=0.15))]),
    "arid/dune_crest": ("arid/sand", [("ripple", dict(amp=0.08, freq=0.7)),
                                      ("crest", dict(amp=0.14, freq=0.9)),
                                      ("flatten", dict(amount=0.2))]),
    "arid/sand_plateau": ("arid/sand", [("flatten", dict(amount=0.32)),
                                        ("plates", dict(cells=3, seam=0.72))]),
    "volcanic/lava_core": ("volcanic/lava", [("glow", dict(colour=(255, 140, 30), amount=0.45)),
                                             ("cracks", dict(n=6, dark=0.55))]),
    "volcanic/ash_rim": ("volcanic/ash", [("flatten", dict(amount=0.30)),
                                          ("cracks", dict(n=5, dark=0.8))]),
    "volcanic/basalt_shelf": ("volcanic/basalt", [("plates", dict(cells=4, seam=0.62))]),
    "cryo/ice_plate": ("cryo/ice", [("plates", dict(cells=5, seam=0.86)),
                                    ("flatten", dict(amount=0.26))]),
    "cryo/crack": ("cryo/ice", [("cracks", dict(n=3, dark=0.42))]),
    "crystal/prism_plate": ("cryo/ice", [("plates", dict(cells=3, seam=0.66)),
                                         ("gloss", dict(amount=0.55))]),
    "crystal/shard_field": ("cryo/ice", [("shards", dict(n=16, light=1.30))]),
    "barren/crater_rim": ("barren/regolith", [("crater_ring", dict(radius=0.52, soft=True)), ("flatten", dict(amount=0.12))]),
    "barren/ejecta": ("barren/regolith", [("ejecta", dict(n=24))]),
    "ocean/reef_chain": ("ocean/water_shallow", [("blobs", dict(colour=(150, 120, 90), n=5, rad=(2, 4), rim=0.88, blend=0.35)), ("flatten", dict(amount=0.12))]),
    "ocean/sand_cay": ("ocean/water_shallow", [("island", dict(colour=(216, 200, 160), radius=0.30, blend=0.80)), ("flatten", dict(amount=0.10))]),
    "sulfur/acid_pool": ("sulfur/sulfur", [("blobs", dict(colour=(190, 210, 60), n=4, rad=(6, 12), rim=0.5)),
                                           ("gloss", dict(amount=0.30))]),
    "sulfur/vent": ("sulfur/sulfur", [("blobs", dict(colour=(40, 40, 30), n=3, rad=(3, 6), rim=0.4)),
                                      ("glow", dict(colour=(220, 140, 40), amount=0.18))]),
    "obsidian/glass_plate": ("volcanic/obsidian", [("plates", dict(cells=3, seam=0.55)),
                                                   ("gloss", dict(amount=0.65))]),
    "ammonia/slush": ("cryo/ice_thin", [("blobs", dict(colour=(150, 200, 200), n=5, rad=(5, 10), rim=0.6)),
                                        ("flatten", dict(amount=0.2))]),

    # ---- exotic biome identities (row 6): derived, never a tint of grass ----
    "methane/pool": ("cryo/ice_thin", [("blobs", dict(colour=(24, 64, 66), n=3, rad=(6, 12), rim=0.82, blend=0.75)), ("flatten", dict(amount=0.1))]),
    "methane/mud": ("cryo/snow", [("ripple", dict(amp=0.08, freq=0.9)), ("blobs", dict(colour=(70, 62, 44), n=4, rad=(3, 7), rim=0.85, blend=0.5))]),
    "methane/ice_shards": ("cryo/ice", [("shards", dict(n=18, light=1.22)), ("flatten", dict(amount=0.12))]),
    "methane/frost_crust": ("cryo/snow", [("plates", dict(cells=6, seam=0.88)), ("flatten", dict(amount=0.28))]),
    "methane/seep": ("cryo/ice", [("blobs", dict(colour=(40, 110, 96), n=2, rad=(5, 9), rim=0.8, blend=0.55)), ("glow", dict(colour=(70, 170, 150), amount=0.12))]),
    "methane/flat": ("cryo/ice_thin", [("flatten", dict(amount=0.35))]),

    "iron/rust_plate": ("barren/regolith", [("plates", dict(cells=4, seam=0.70)), ("flatten", dict(amount=0.1))]),
    "iron/oxide_dune": ("arid/sand", [("ripple", dict(amp=0.10, freq=1.1)), ("flatten", dict(amount=0.22))]),
    "iron/metal_shard": ("barren/rock", [("shards", dict(n=14, light=1.35)), ("flatten", dict(amount=0.1))]),
    "iron/red_soil": ("arid/sand", [("flatten", dict(amount=0.38))]),
    "iron/iron_crust": ("barren/rock", [("cracks", dict(n=6, dark=0.78)), ("flatten", dict(amount=0.12))]),
    "iron/scrap": ("barren/rock", [("plates", dict(cells=6, seam=0.76)), ("shards", dict(n=6, light=1.25))]),

    "crystal/glass_ground": ("cryo/ice", [("flatten", dict(amount=0.3)), ("gloss", dict(amount=0.5))]),
    "crystal/prism_crack": ("cryo/ice", [("cracks", dict(n=5, dark=0.62)), ("gloss", dict(amount=0.6))]),
    "crystal/cluster": ("cryo/ice", [("shards", dict(n=12, light=1.3)), ("gloss", dict(amount=0.4))]),
    "crystal/geode": ("cryo/ice", [("blobs", dict(colour=(120, 96, 190), n=2, rad=(8, 12), rim=0.8, blend=0.6)), ("gloss", dict(amount=0.35))]),
    "crystal/plate": ("cryo/ice", [("plates", dict(cells=3, seam=0.80)), ("gloss", dict(amount=0.45))]),

    "ammonia/white_crust": ("cryo/snow", [("plates", dict(cells=6, seam=0.86)), ("flatten", dict(amount=0.2))]),
    "ammonia/blue_pool": ("cryo/ice", [("blobs", dict(colour=(40, 96, 120), n=3, rad=(7, 12), rim=0.84, blend=0.7)), ("flatten", dict(amount=0.1))]),
    "ammonia/frost": ("cryo/snow", [("ripple", dict(amp=0.06, freq=1.1)), ("flatten", dict(amount=0.3))]),
    "ammonia/vapor_crust": ("cryo/snow", [("blobs", dict(colour=(190, 220, 215), n=5, rad=(4, 9), rim=0.9, blend=0.3))]),

    "obsidian/sharp_shard": ("volcanic/obsidian", [("shards", dict(n=16, light=1.5)), ("flatten", dict(amount=0.08))]),
    "obsidian/black_glass": ("volcanic/obsidian", [("flatten", dict(amount=0.2)), ("gloss", dict(amount=0.5))]),
    "obsidian/cracked_glass": ("volcanic/obsidian", [("cracks", dict(n=6, dark=0.5)), ("gloss", dict(amount=0.3))]),
    "obsidian/ember_speck": ("volcanic/obsidian", [("blobs", dict(colour=(210, 90, 30), n=6, rad=(1, 2), rim=0.9, blend=0.8))]),
    "obsidian/flat": ("volcanic/obsidian", [("flatten", dict(amount=0.3))]),

    "carbon/tar": ("volcanic/basalt", [("flatten", dict(amount=0.42)), ("gloss", dict(amount=0.35))]),
    "carbon/graphite_dust": ("barren/regolith", [("ripple", dict(amp=0.06, freq=1.3)), ("flatten", dict(amount=0.3))]),
    "carbon/diamond_crust": ("cryo/ice", [("shards", dict(n=10, light=1.45)), ("gloss", dict(amount=0.5))]),
    "carbon/coal": ("volcanic/basalt", [("plates", dict(cells=5, seam=0.72)), ("flatten", dict(amount=0.2))]),
    "carbon/dark_soil": ("barren/dust", [("flatten", dict(amount=0.42))]),
    "carbon/grit": ("barren/regolith", [("cracks", dict(n=4, dark=0.85)), ("flatten", dict(amount=0.2))]),

    "sulfur/yellow_crust": ("barren/dust", [("plates", dict(cells=6, seam=0.86)), ("flatten", dict(amount=0.1))]),
    "sulfur/mineral_rim": ("barren/regolith", [("crater_ring", dict(radius=0.5, soft=True)), ("flatten", dict(amount=0.15))]),
    "sulfur/powder": ("barren/dust", [("flatten", dict(amount=0.32)), ("ripple", dict(amp=0.05, freq=1.2))]),
    "sulfur/flat": ("barren/dust", [("flatten", dict(amount=0.45))]),
}

BIOME_OF = {k: k.split("/")[0] for k in RECIPES}

# Reef/cay tiles live on the ocean palette but must not be re-locked to its
# water hues, which turns coral into sand-gold. Lock those to ocean_coral.
PALETTE_OVERRIDE = {"ocean/reef_chain": "ocean_coral", "ocean/sand_cay": "ocean_coral"}


def run(key: str, seed: int = 0) -> Path:
    src, ops = RECIPES[key]
    biome = BIOME_OF[key]
    blank = {"arid": "arid/sand", "volcanic": "volcanic/basalt", "cryo": "cryo/ice",
             "crystal": "cryo/glacier", "barren": "barren/regolith", "ocean": "ocean/water_shallow",
             "sulfur": "barren/dust", "obsidian": "volcanic/obsidian", "ammonia": "cryo/snow"}
    src_path = ROOT / "assets" / "tilesets" / f"{src}.png"
    if not src_path.exists():
        src_path = ROOT / "assets" / "tilesets" / f"{blank.get(biome, 'barren/regolith')}.png"
    a = load(src_path)
    rng = np.random.default_rng(abs(hash(key)) % 100000 + seed)
    for name, kw in ops:
        a = globals()[name](a, rng, **kw)
    a = np.clip(a, 0, 255)
    im = Image.fromarray(a.astype(np.uint8), "RGB")
    im = im.filter(ImageFilter.GaussianBlur(0.15))
    im = apply_palette(im.convert("RGBA"), palette_hexes(PALETTE_OVERRIDE.get(key, biome)))
    out = ROOT / "assets" / "tilesets" / f"{key}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    preview = Image.new("RGB", (SIZE * 3, SIZE * 3))
    for x in range(3):
        for y in range(3):
            preview.paste(im.convert("RGB"), (x * SIZE, y * SIZE))
    preview.resize((SIZE * 3 * 3, SIZE * 3 * 3), Image.Resampling.NEAREST).save(
        out.with_name(out.stem + "_preview.png"))
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--seed", type=int, default=0)
    args = ap.parse_args()
    if args.list:
        print("\n".join(sorted(RECIPES)))
        return
    keys = sorted(RECIPES) if args.all else (args.only or [])
    if not keys:
        raise SystemExit("pass --all, --only KEY..., or --list")
    for k in keys:
        if k not in RECIPES:
            raise SystemExit(f"unknown recipe '{k}'")
        print("wrote", run(k, args.seed))


if __name__ == "__main__":
    main()

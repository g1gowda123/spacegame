#!/usr/bin/env python3
"""Compose seamless edge-transition tiles from two terrain tiles.

One source tile per material pair: A on the west side, B on the east, joined
by a wavy, dithered boundary. The tile is periodic along the boundary axis, so
it repeats cleanly along a terraced edge. Rotate it 90/180/270 for the other
three sides (and the reverse A/B order).

This is compositing, not terrain generation: both source tiles are the
diffusion-made tiles, so the transition keeps their exact look and palette.

Usage:
  gen_transition.py --all
  gen_transition.py --a volcanic/lava --b volcanic/ash
  gen_transition.py --a volcanic/lava --b volcanic/ash --band 3 --scatter 6
"""

from __future__ import annotations

import argparse
import json
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TILESETS = ROOT / "assets" / "tilesets"
TRANSITIONS = TILESETS / "transitions"


def periodic_wave(seed: int, size: int, amplitude: float) -> np.ndarray:
    """A smooth boundary offset, periodic in y so the tile wraps."""
    rng = random.Random(seed)
    waves = []
    for k in (1, 2, 3):
        waves.append((rng.uniform(0.35, 1.0), k, rng.uniform(0, math.tau)))
    total = sum(w[0] for w in waves)
    y = np.arange(size, dtype=np.float32)
    off = np.zeros(size, dtype=np.float32)
    for weight, k, phase in waves:
        off += (weight / total) * amplitude * np.sin(math.tau * k * y / size + phase)
    # A little pixel jaggedness, also periodic in y.
    jitter = np.array([rng.choice((-1, 0, 1)) for _ in range(size)], dtype=np.float32)
    return off + jitter


def hash01(x: int, y: int, seed: int) -> float:
    h = (x * 374761393 + y * 668265263 + seed * 1442695040888963407) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    h ^= h >> 16
    return (h & 0xFFFFFFFF) / 0xFFFFFFFF


def compose(a: Image.Image, b: Image.Image, seed: int,
            band: int = 3, scatter: int = 6, wave: float = 5.0) -> Image.Image:
    size = a.width
    if b.size != a.size:
        raise SystemExit("source tiles must be the same size")
    pa = np.array(a.convert("RGBA"))
    pb = np.array(b.convert("RGBA"))
    out = np.empty_like(pa)
    off = periodic_wave(seed, size, wave)
    centre = size / 2.0

    for y in range(size):
        bx = centre + float(off[y])
        for x in range(size):
            d = x - bx
            pick_b: bool
            if d < -scatter:
                pick_b = False
            elif d > scatter:
                pick_b = True
            elif abs(d) <= band:
                # Dithered mix across the seam: A at -band, B at +band.
                p = (d + band) / (2.0 * band)
                pick_b = hash01(x, y, seed) < p
            else:
                # Sparse strays either side of the core band.
                p = 0.18 * (1.0 - min(1.0, (abs(d) - band) / max(1, scatter - band)))
                h = hash01(x, y, seed + 17)
                pick_b = h < p if d < 0 else h >= p
            out[y, x] = pb[y, x] if pick_b else pa[y, x]
    return Image.fromarray(out, "RGBA")


def corner_mask(size: int, corner: str, seed: int,
                radius: float = 36.0, wave: float = 4.0) -> np.ndarray:
    """Quarter-circle mask for an outer/inner corner, with a soft arc.

    ``corner`` is one of nw/ne/sw/se. The mask is True where B owns the
    quarter. The arc is perturbed and dithered so it does not read as a
    vector circle at 64 px.
    """
    corner_seed = {"nw": 11, "ne": 23, "sw": 37, "se": 53}.get(corner, 11)
    rng = random.Random(seed ^ corner_seed)
    phase_a = rng.uniform(0, math.tau)
    phase_b = rng.uniform(0, math.tau)
    yy, xx = np.mgrid[0:size, 0:size]
    cx = 0.0 if "w" in corner else float(size - 1)
    cy = 0.0 if "n" in corner else float(size - 1)
    dx = xx.astype(np.float32) - cx
    dy = yy.astype(np.float32) - cy
    dist = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dy, dx)
    r = radius + wave * np.sin(ang * 3.0 + phase_a) + wave * 0.45 * np.sin(ang * 5.0 + phase_b)
    mask = dist <= r
    edge = np.abs(dist - r) <= 1.15
    xs = np.arange(size, dtype=np.int32)[None, :].repeat(size, axis=0)
    ys = np.arange(size, dtype=np.int32)[:, None].repeat(size, axis=1)
    noise = np.vectorize(lambda x, y: hash01(int(x), int(y), seed + 31))(xs, ys)
    return np.where(edge, noise < 0.5, mask)


def stripe_mask(size: int, axis: str, seed: int,
                edge: float = 17.0, wave: float = 4.0) -> np.ndarray:
    """B on two opposite edges, A in the middle band.

    ``axis="ns"`` puts B on north/south and varies the boundary with x, so
    the stripe repeats along its length. ``axis="ew"`` is the transpose.
    """
    coord = np.arange(size, dtype=np.float32)
    off_a = periodic_wave(seed, size, wave)
    off_b = periodic_wave(seed + 97, size, wave)
    noise = np.vectorize(lambda x, y: hash01(int(x), int(y), seed + 53))(
        np.arange(size, dtype=np.int32)[None, :].repeat(size, axis=0),
        np.arange(size, dtype=np.int32)[:, None].repeat(size, axis=1),
    )
    if axis == "ns":
        y = np.arange(size, dtype=np.float32)[:, None]
        top = edge + off_a[None, :]
        bottom = (size - edge) + off_b[None, :]
        mask = (y < top) | (y >= bottom)
        near = (np.abs(y - top) <= 1.15) | (np.abs(y - bottom) <= 1.15)
    else:
        x = np.arange(size, dtype=np.float32)[None, :]
        left = edge + off_a[:, None]
        right = (size - edge) + off_b[:, None]
        mask = (x < left) | (x >= right)
        near = (np.abs(x - left) <= 1.15) | (np.abs(x - right) <= 1.15)
    return np.where(near, noise < 0.5, mask)


def compose_corner(a: Image.Image, b: Image.Image, seed: int,
                   corner: str, inner: bool) -> Image.Image:
    """Composite a quarter-corner transition.

    Outer: B owns the corner quarter, A the rest.
    Inner: A owns the corner quarter, B the rest.
    """
    pa = np.array(a.convert("RGBA"))
    pb = np.array(b.convert("RGBA"))
    mask = corner_mask(a.width, corner, seed)[..., None]
    out = np.where(mask, pa if inner else pb, pb if inner else pa)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def compose_stripe(a: Image.Image, b: Image.Image, seed: int, axis: str) -> Image.Image:
    """Composite a 1-wide-feature stripe (B on two opposite edges)."""
    pa = np.array(a.convert("RGBA"))
    pb = np.array(b.convert("RGBA"))
    mask = stripe_mask(a.width, axis, seed)[..., None]
    out = np.where(mask, pb, pa)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def preview(a: Image.Image, b: Image.Image, tile: Image.Image,
            out: Path, scale: int = 3) -> None:
    """A | transition | B, three rows tall, so the join is visible."""
    n = a.width
    cols, rows = 5, 4
    sheet = Image.new("RGBA", (cols * n, rows * n), (0, 0, 0, 0))
    for y in range(rows):
        for x in range(cols):
            if x < 2:
                sheet.alpha_composite(a, (x * n, y * n))
            elif x == 2:
                sheet.alpha_composite(tile, (x * n, y * n))
            else:
                sheet.alpha_composite(b, (x * n, y * n))
    big = sheet.resize((sheet.width * scale, sheet.height * scale), Image.Resampling.NEAREST)
    big.convert("RGB").save(out)


def run_pair(a_rel: str, b_rel: str, args, seed: int | None = None) -> dict:
    a_path = TILESETS / f"{a_rel}.png"
    b_path = TILESETS / f"{b_rel}.png"
    if not a_path.exists() or not b_path.exists():
        raise SystemExit(f"missing tile: {a_path} / {b_path}")
    a = Image.open(a_path).convert("RGBA")
    b = Image.open(b_path).convert("RGBA")
    a_name = Path(a_rel).name
    b_name = Path(b_rel).name
    pair = f"{a_name}_{b_name}"
    out_dir = TRANSITIONS / pair
    out_dir.mkdir(parents=True, exist_ok=True)

    use_seed = args.seed if seed is None else seed
    base = compose(a, b, use_seed, args.band, args.scatter, args.wave)
    variants = {
        "west": base,
        "east": base.transpose(Image.Transpose.ROTATE_180),
        "north": base.transpose(Image.Transpose.ROTATE_270),
        "south": base.transpose(Image.Transpose.ROTATE_90),
    }
    for side, img in variants.items():
        img.save(out_dir / f"{a_name}_{side}.png")
    preview(a, b, base, out_dir / f"{pair}_preview.png")

    entry = {
        "pair": pair,
        "a": str(a_path.relative_to(ROOT)),
        "b": str(b_path.relative_to(ROOT)),
        "a_side": "west",
        "tiles": {side: str((out_dir / f'{a_name}_{side}.png').relative_to(ROOT))
                  for side in variants},
        "preview": str((out_dir / f"{pair}_preview.png").relative_to(ROOT)),
        "seed": use_seed,
        "band": args.band,
        "scatter": args.scatter,
        "wave": args.wave,
    }
    with open(out_dir / "manifest.json", "w") as f:
        json.dump(entry, f, indent=2)
    print(f"wrote {pair}: {len(variants)} orientations + preview")
    return entry


def extras_preview(a: Image.Image, b: Image.Image, tiles: dict[str, Image.Image],
                   out: Path, scale: int = 3) -> None:
    """Outer row, inner row, and both stripe axes on one sheet."""
    names = ["outer_nw", "outer_ne", "outer_sw", "outer_se", "stripe_ns",
             "inner_nw", "inner_ne", "inner_sw", "inner_se", "stripe_ew"]
    n = a.width
    sheet = Image.new("RGBA", (5 * n, 2 * n), (0, 0, 0, 0))
    for i, name in enumerate(names):
        sheet.alpha_composite(tiles[name], ((i % 5) * n, (i // 5) * n))
    big = sheet.resize((sheet.width * scale, sheet.height * scale), Image.Resampling.NEAREST)
    big.convert("RGB").save(out)


def run_extras(a_rel: str, b_rel: str, args, seed: int | None = None) -> dict:
    """Generate the four outer, four inner, and two stripe tiles for one pair.

    Existing straight tiles are never touched; the pair manifest is updated in
    place so `run_pair` output and extras stay together.
    """
    a_path = TILESETS / f"{a_rel}.png"
    b_path = TILESETS / f"{b_rel}.png"
    if not a_path.exists() or not b_path.exists():
        raise SystemExit(f"missing tile: {a_path} / {b_path}")
    a = Image.open(a_path).convert("RGBA")
    b = Image.open(b_path).convert("RGBA")
    a_name = Path(a_rel).name
    b_name = Path(b_rel).name
    pair = f"{a_name}_{b_name}"
    out_dir = TRANSITIONS / pair
    out_dir.mkdir(parents=True, exist_ok=True)

    manifest_path = out_dir / "manifest.json"
    if manifest_path.exists():
        entry = json.loads(manifest_path.read_text())
    else:
        entry = {"pair": pair, "a": str(a_path.relative_to(ROOT)),
                 "b": str(b_path.relative_to(ROOT)), "a_side": "west", "tiles": {}}

    use_seed = (args.seed if seed is None else seed) + 100
    tiles: dict[str, Image.Image] = {}
    for corner in ("nw", "ne", "sw", "se"):
        tiles[f"outer_{corner}"] = compose_corner(a, b, use_seed, corner, inner=False)
        tiles[f"inner_{corner}"] = compose_corner(a, b, use_seed, corner, inner=True)
    tiles["stripe_ns"] = compose_stripe(a, b, use_seed, "ns")
    tiles["stripe_ew"] = compose_stripe(a, b, use_seed, "ew")

    # Reverse-facing stripes let a cell whose material is B handle two
    # opposite A neighbours without falling back to a straight edge.
    reverse = {
        "stripe_ns_b": compose_stripe(b, a, use_seed, "ns"),
        "stripe_ew_b": compose_stripe(b, a, use_seed, "ew"),
    }

    for name, img in tiles.items():
        img.save(out_dir / f"{a_name}_{name}.png")
        entry.setdefault("tiles", {})[name] = str(
            (out_dir / f"{a_name}_{name}.png").relative_to(ROOT)
        )
    for name, img in reverse.items():
        file_stem = name.replace("_b", "")
        img.save(out_dir / f"{b_name}_{file_stem}.png")
        entry.setdefault("tiles", {})[name] = str(
            (out_dir / f"{b_name}_{file_stem}.png").relative_to(ROOT)
        )
    extras_preview(a, b, tiles, out_dir / f"{pair}_extras_preview.png")
    entry["extras_seed"] = use_seed
    entry["extras_band"] = args.band
    entry["extras_scatter"] = args.scatter
    entry["extras_wave"] = args.wave
    entry["extras_preview"] = str(
        (out_dir / f"{pair}_extras_preview.png").relative_to(ROOT)
    )
    manifest_path.write_text(json.dumps(entry, indent=2))
    print(f"wrote {pair}: 12 extras + preview")
    return entry


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--a", help="first tile, relative to assets/tilesets (no .png)")
    p.add_argument("--b", help="second tile, relative to assets/tilesets (no .png)")
    p.add_argument("--all", action="store_true", help="run every pair in tools/transitions.json")
    p.add_argument("--extras", action="store_true", help="generate corner/stripe tiles for --a/--b")
    p.add_argument("--all-extras", action="store_true", help="corner/stripe tiles for every pair")
    p.add_argument("--seed", type=int, default=1)
    p.add_argument("--band", type=int, default=3, help="core dither half-width")
    p.add_argument("--scatter", type=int, default=8, help="stray-pixel half-width")
    p.add_argument("--wave", type=float, default=9.0, help="boundary wave amplitude in pixels")
    args = p.parse_args()

    if args.all_extras:
        plan = json.loads((ROOT / "tools" / "transitions.json").read_text())
        entries = []
        for i, pair in enumerate(plan["pairs"]):
            a_name = Path(pair[0]).name
            b_name = Path(pair[1]).name
            manifest = TRANSITIONS / f"{a_name}_{b_name}" / "manifest.json"
            seed = args.seed + i
            if manifest.exists():
                seed = json.loads(manifest.read_text()).get("seed", seed)
            entries.append(run_extras(pair[0], pair[1], args, seed=seed))
        with open(TRANSITIONS / "manifest_extras.json", "w") as f:
            json.dump({"pairs": entries}, f, indent=2)
        print(f"done: {len(entries)} pairs of extras")
    elif args.all:
        plan = json.loads((ROOT / "tools" / "transitions.json").read_text())
        entries = []
        for i, pair in enumerate(plan["pairs"]):
            entries.append(run_pair(pair[0], pair[1], args, seed=args.seed + i))
        with open(TRANSITIONS / "manifest.json", "w") as f:
            json.dump({"pairs": entries}, f, indent=2)
        print(f"done: {len(entries)} pairs")
    elif args.a and args.b:
        if args.extras:
            run_extras(args.a, args.b, args)
        else:
            run_pair(args.a, args.b, args)
    else:
        raise SystemExit("pass --a/--b or --all")


if __name__ == "__main__":
    main()

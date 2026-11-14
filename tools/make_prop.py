#!/usr/bin/env python3
"""Turn a diffusion object sheet into ONE game-ready prop sprite.

Props failed before because ``gen_asset.py`` keeps the whole 1024x1024 sheet:
the border key then leaves a beige square, and the scene's
``_prop_is_usable`` check correctly rejects it. This script isolates the
single largest object, keys everything else to transparency, palette-locks
the object and adds a 1 px outline. Shadows are the renderer's job (lead
rule 2026-11-14): pass --shadow 0 to keep art shadow-free (the default).
sits on its tile instead of floating.

The object is anchored to the BOTTOM of the square canvas, because the map
generator places prop sprites by their visible alpha bottom.

Usage:
  make_prop.py assets/raw/sprite_00012_.png --out assets/props/boulder.png \
      --biome temperate --outline 16,20,14
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

try:  # scipy is present in the ComfyUI venv; keep a numpy fallback otherwise.
    from scipy import ndimage
except ImportError:  # pragma: no cover - only used outside the ComfyUI venv
    ndimage = None

ROOT = Path(__file__).resolve().parent.parent


def border_colour(rgb: np.ndarray, band: int = 8) -> np.ndarray:
    edges = np.concatenate([
        rgb[:band, :, :].reshape(-1, 3),
        rgb[-band:, :, :].reshape(-1, 3),
        rgb[:, :band, :].reshape(-1, 3),
        rgb[:, -band:, :].reshape(-1, 3),
    ])
    return np.median(edges, axis=0)


def key_backdrop_and_shadow(mask: np.ndarray, rgb: np.ndarray,
                            bg: np.ndarray) -> np.ndarray:
    """Remove the backdrop AND any model-painted drop shadow.

    SDXL adds a soft neutral-grey ellipse under props even when told "no
    shadow". It survives a plain colour key because it differs from the
    backdrop. The shadow is desaturated mid-grey and is connected to the
    backdrop region, so we flood the border-connected "backdrop-or-shadow"
    area away. Pale pixels inside the object are not border-connected and
    survive (holes are filled later).
    """
    dist = np.sqrt(((rgb.astype(np.float32) - bg) ** 2).sum(axis=2))
    mx = rgb.max(axis=2).astype(np.float32)
    mn = rgb.min(axis=2).astype(np.float32)
    sat = (mx - mn) / np.maximum(mx, 1.0)
    val = mx / 255.0
    shadowish = (sat < 0.12) & (val > 0.30) & (val < 0.93) & (dist <= 150.0)
    removable = (dist <= 42.0) | shadowish
    if ndimage is None:
        return mask
    labels, count = ndimage.label(removable, structure=np.ones((3, 3)))
    h, w = removable.shape
    border_ids = set(labels[0, :].tolist()) | set(labels[-1, :].tolist())
    border_ids |= set(labels[:, 0].tolist()) | set(labels[:, -1].tolist())
    border_ids.discard(0)
    if border_ids:
        remove = np.isin(labels, list(border_ids))
        mask = mask & ~remove
    return mask


def largest_component(mask: np.ndarray) -> np.ndarray:
    """Keep the biggest foreground blob, holes filled."""
    if ndimage is None:
        return mask
    mask = ndimage.binary_opening(mask, structure=np.ones((3, 3)), iterations=1)
    mask = ndimage.binary_closing(mask, structure=np.ones((3, 3)), iterations=1)
    labels, count = ndimage.label(mask, structure=np.ones((3, 3)))
    if count == 0:
        raise SystemExit("no foreground object found (background key removed everything)")
    best, best_area = 0, 0
    h, w = mask.shape
    for i in range(1, count + 1):
        ys, xs = np.where(labels == i)
        area = len(xs)
        # Prefer an interior object; fall back to the largest if it touches an edge.
        touches = xs.min() <= 1 or ys.min() <= 1 or xs.max() >= w - 2 or ys.max() >= h - 2
        score = area * (0.5 if touches else 1.0)
        if score > best_area:
            best, best_area = i, score
    keep = labels == best
    keep = ndimage.binary_fill_holes(keep)
    return keep


def palette_hexes(biome: str | None, spec: str | None) -> list[str]:
    if biome:
        palettes = json.loads((ROOT / "tools" / "palettes.json").read_text())
        if biome not in palettes:
            raise SystemExit(f"unknown biome '{biome}' (have: {', '.join(palettes)})")
        return [c.lstrip("#") for c in palettes[biome]["colors"]]
    if spec:
        return [h.strip().lstrip("#") for h in spec.split(",") if h.strip()]
    raise SystemExit("pass --biome or --palette")


def lock_palette(rgb: np.ndarray, hexes: list[str]) -> np.ndarray:
    """Nearest palette colour for every pixel (no dithering). RGB in, RGB out."""
    pal = np.array([[int(h[i:i + 2], 16) for i in (0, 2, 4)] for h in hexes], dtype=np.int32)
    rgb = rgb.astype(np.int32)
    # Chunk the distance computation so 1024x1024 inputs stay cheap.
    flat = rgb.reshape(-1, 3)
    out = np.empty_like(flat)
    step = 65536
    for start in range(0, len(flat), step):
        chunk = flat[start:start + step]
        d = ((chunk[:, None, :] - pal[None, :, :]) ** 2).sum(axis=2)
        out[start:start + step] = pal[d.argmin(axis=1)]
    return out.reshape(rgb.shape).astype(np.uint8)


def outline_rgba(rgba: np.ndarray, colour: tuple[int, int, int]) -> np.ndarray:
    a = rgba[..., 3] > 0
    padded = np.pad(a, 1)
    edge = (
        padded[:-2, 1:-1] | padded[2:, 1:-1] | padded[1:-1, :-2] | padded[1:-1, 2:]
    )
    edge &= ~a
    out = rgba.copy()
    out[edge, :3] = colour
    out[edge, 3] = 255
    return out


def build(input_path: Path, out_path: Path, size: int, fill: float,
          biome: str | None, palette_spec: str | None, outline: str,
          shadow: float, seed_darken: int = 0, height: int | None = None,
          tolerance: float = 42.0, key_interior: bool = False) -> None:
    out_h = height if height else size
    src = Image.open(input_path).convert("RGB")
    rgb = np.asarray(src, dtype=np.int32)
    bg = border_colour(rgb)
    dist = np.sqrt(((rgb - bg) ** 2).sum(axis=2))
    mask = dist > tolerance
    mask = key_backdrop_and_shadow(mask, rgb, bg)
    keep = largest_component(mask)
    if key_interior:
        keep = keep & (dist > tolerance * 0.8)

    # Composite the isolated object on transparency at source resolution.
    rgba = np.dstack([np.asarray(src, dtype=np.uint8), (keep * 255).astype(np.uint8)])
    ys, xs = np.where(keep)
    if len(xs) == 0:
        raise SystemExit("empty object mask")
    obj = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]

    # Fit the object inside (size * fill) x (out_h * fill), keeping aspect.
    target_w = max(1, int(round(size * fill)))
    target_h = max(1, int(round(out_h * fill)))
    h, w = obj.shape[:2]
    scale = min(target_w / w, target_h / h)
    new_w, new_h = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
    obj_img = Image.fromarray(obj, "RGBA").resize((new_w, new_h), Image.Resampling.LANCZOS)
    obj = np.array(obj_img)
    obj[..., 3] = np.where(obj[..., 3] >= 128, 255, 0)

    alpha = obj[..., 3:4]
    obj = np.concatenate(
        [lock_palette(obj[..., :3], palette_hexes(biome, palette_spec)), alpha],
        axis=2,
    )
    obj = outline_rgba(obj, tuple(int(c) for c in outline.split(",")))
    obj_img = Image.fromarray(obj, "RGBA")

    # Soft contact shadow: two stacked ellipses, drawn under the object and
    # clipped to the canvas. Sits at the object's base so it reads grounded.
    canvas = Image.new("RGBA", (size, out_h), (0, 0, 0, 0))
    base_x = size // 2
    base_y = out_h - 2
    if shadow > 0:
        sh = Image.new("RGBA", (size, out_h), (0, 0, 0, 0))
        dr = ImageDraw.Draw(sh)
        sw = max(4, int(new_w * 0.62))
        shh = max(3, int(out_h * 0.13))
        dr.ellipse([base_x - sw // 2, base_y - shh // 2,
                    base_x + sw // 2, base_y + shh // 2],
                   fill=(0, 0, 0, int(255 * 0.30 * shadow)))
        sh = sh.filter(ImageFilter.GaussianBlur(0.8))
        canvas.alpha_composite(sh)

    canvas.alpha_composite(obj_img, (base_x - new_w // 2, base_y - new_h))
    canvas.save(out_path)

    preview = Image.new("RGBA", (size * 4, out_h * 4), (28, 24, 38, 255))
    preview.alpha_composite(canvas.resize((size * 4, out_h * 4), Image.Resampling.NEAREST))
    preview.save(out_path.with_name(out_path.stem + "_preview.png"))
    print(f"wrote {out_path} ({size}x{out_h}) and {out_path.stem}_preview.png")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("input", type=Path)
    p.add_argument("--out", required=True, type=Path)
    p.add_argument("--size", type=int, default=64)
    p.add_argument("--height", type=int, default=None,
                   help="canvas height when not square (defaults to --size)")
    p.add_argument("--fill", type=float, default=0.78,
                   help="fraction of the canvas the object occupies")
    p.add_argument("--biome", default=None, help="palette name from tools/palettes.json")
    p.add_argument("--palette", default=None, help="comma-separated hex colours")
    p.add_argument("--outline", default="16,20,14", help="r,g,b outline colour")
    p.add_argument("--key-interior", action="store_true",
                   help="also punch through background-coloured holes (arch openings)")
    p.add_argument("--tolerance", type=float, default=42.0,
                   help="background colour distance that counts as 'not object'")
    p.add_argument("--shadow", type=float, default=0.0,
                   help="contact-shadow strength multiplier (0 = shadow-free, default)")
    args = p.parse_args()

    args.out.parent.mkdir(parents=True, exist_ok=True)
    build(args.input, args.out, args.size, args.fill, args.biome,
          args.palette, args.outline, args.shadow, height=args.height,
          tolerance=args.tolerance, key_interior=args.key_interior)


if __name__ == "__main__":
    main()

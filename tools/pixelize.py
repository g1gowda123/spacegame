#!/usr/bin/env python3
"""Turn a generated image into a game-ready pixel-art sprite.

Pipeline: key out flat background -> trim -> square pad -> nearest downscale
-> palette quantize -> hard alpha -> optional 1px outline.

Usage:
  pixelize.py in.png out.png --size 128 --colors 24
  pixelize.py in.png out.png --bg magenta --outline 26,20,35
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


BG_COLORS = {
    "magenta": (255, 0, 255),
    "green": (0, 255, 0),
    "blue": (0, 0, 255),
    "white": (255, 255, 255),
    "black": (0, 0, 0),
}


def _color_diff(a: tuple, b: tuple) -> int:
    return int(np.abs(np.array(a, dtype=np.int32) - np.array(b, dtype=np.int32)).sum())


def _sample_border(im: Image.Image, band: int = 6) -> tuple[int, int, int]:
    """Median colour along the outer band — what the model actually used as bg."""
    arr = np.array(im.convert("RGB"))
    h, w = arr.shape[:2]
    edges = np.concatenate([
        arr[:band, :, :].reshape(-1, 3),
        arr[-band:, :, :].reshape(-1, 3),
        arr[:, :band, :].reshape(-1, 3),
        arr[:, -band:, :].reshape(-1, 3),
    ])
    return tuple(int(v) for v in np.median(edges, axis=0))


def key_background(im: Image.Image, bg: str, tolerance: int) -> Image.Image:
    """Flood-fill the flat backdrop from the corners, leaving interior colours intact.

    ``bg="auto"`` samples the actual backdrop colour (SDXL often renders white or
    grey even when asked for magenta). A flood fill keeps sprite pixels that
    happen to share the backdrop colour.
    """
    from PIL import ImageDraw

    rgb = im.convert("RGB")
    w, h = rgb.size
    if bg == "auto":
        target = _sample_border(rgb)
    else:
        target = BG_COLORS.get(bg)
        if target is None:
            target = tuple(int(c) for c in bg.split(","))

    sentinel = (255, 0, 254)
    for xy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        if _color_diff(rgb.getpixel(xy), target) <= max(tolerance, 30):
            ImageDraw.floodfill(rgb, xy, sentinel, thresh=tolerance)

    arr = np.array(rgb)
    mask = np.all(arr == np.array(sentinel, dtype=np.uint8), axis=-1)
    rgba = np.array(im.convert("RGBA"))
    rgba[mask, 3] = 0
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


def make_seamless(im: Image.Image, band: int = 10) -> Image.Image:
    """Offset by half, heal the seam cross, offset back.

    After the half-roll the original edges meet on the centre cross. Linearly
    healing that cross and rolling back makes the wrap continuous without
    changing the texture elsewhere.
    """
    arr = np.array(im.convert("RGBA"), dtype=np.float32)
    h, w = arr.shape[:2]
    rolled = np.roll(arr, (h // 2, w // 2), axis=(0, 1))
    cx, cy = w // 2, h // 2
    b = max(1, band)

    left = rolled[:, cx - b - 1, :3]
    right = rolled[:, cx + b + 1, :3]
    for i, x in enumerate(range(cx - b, cx + b + 1)):
        t = (i + 1) / (2 * b + 2)
        rolled[:, x, :3] = left * (1 - t) + right * t

    top = rolled[cy - b - 1, :, :3]
    bottom = rolled[cy + b + 1, :, :3]
    for i, y in enumerate(range(cy - b, cy + b + 1)):
        t = (i + 1) / (2 * b + 2)
        rolled[y, :, :3] = top * (1 - t) + bottom * t

    result = np.roll(rolled, (-(h // 2), -(w // 2)), axis=(0, 1))
    return Image.fromarray(np.clip(result, 0, 255).astype(np.uint8), "RGBA")


def trim_and_pad(im: Image.Image, margin: int) -> Image.Image:
    """Crop to opaque content, then pad to a square with a margin."""
    alpha = np.array(im)[..., 3]
    ys, xs = np.nonzero(alpha > 16)
    if len(xs) == 0:
        raise SystemExit("error: image is fully transparent after background key")
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))

    side = max(im.width, im.height) + margin * 2
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    return square


def downscale(im: Image.Image, size: int) -> Image.Image:
    """Nearest-neighbour downscale keeps the generated pixel grid crisp."""
    return im.resize((size, size), Image.Resampling.NEAREST)


def quantize(im: Image.Image, colors: int) -> Image.Image:
    """Quantize RGB only; preserve the hard alpha channel."""
    alpha = im.getchannel("A")
    rgb = im.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def apply_palette(im: Image.Image, spec: str) -> Image.Image:
    """Map the image onto a fixed palette (comma-separated hex colours)."""
    hexes = [h.strip().lstrip("#") for h in spec.split(",") if h.strip()]
    flat: list[int] = []
    for h in hexes:
        flat.extend(int(h[i:i + 2], 16) for i in (0, 2, 4))
    # Pillow reads all 256 palette slots. Repeat the palette instead of padding
    # with black, otherwise dark pixels get pulled toward an artificial black.
    full = flat * (256 // len(hexes) + 1)
    flat = full[:768]
    pal_img = Image.new("P", (1, 1))
    pal_img.putpalette(flat)
    alpha = im.getchannel("A")
    out = im.convert("RGB").quantize(palette=pal_img, dither=Image.Dither.NONE)
    out = out.convert("RGBA")
    out.putalpha(alpha)
    return out


def hard_alpha(im: Image.Image) -> Image.Image:
    a = np.array(im.getchannel("A"))
    a = np.where(a >= 128, 255, 0).astype(np.uint8)
    im.putalpha(Image.fromarray(a, "L"))
    return im


def add_outline(im: Image.Image, color: tuple[int, int, int]) -> Image.Image:
    """Add a 1px outline around opaque pixels (4-neighbour)."""
    a = np.array(im.getchannel("A")) > 0
    padded = np.pad(a, 1)
    edge = (
        padded[:-2, 1:-1] | padded[2:, 1:-1] | padded[1:-1, :-2] | padded[1:-1, 2:]
    )
    edge &= ~a
    rgba = np.array(im)
    rgba[edge, :3] = color
    rgba[edge, 3] = 255
    return Image.fromarray(rgba, "RGBA")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("input", type=Path)
    p.add_argument("output", type=Path)
    p.add_argument("--size", type=int, default=128)
    p.add_argument("--colors", type=int, default=24)
    p.add_argument("--palette", default=None, help="comma-separated hex colours to lock the palette")
    p.add_argument("--bg", default="auto", help="auto|magenta|green|blue|white|black|r,g,b")
    p.add_argument("--tolerance", type=int, default=70)
    p.add_argument("--margin", type=int, default=4)
    p.add_argument("--outline", default=None, help="r,g,b (default: none)")
    p.add_argument("--tile", action="store_true", help="tile mode: no background key, no trim, 2x2 preview")
    p.add_argument("--seamless", action="store_true", help="heal the wrap seam (tiles)")
    p.add_argument("--seam-band", type=int, default=0,
                   help="half-width of the healed cross in output pixels (0 = auto)")
    p.add_argument("--preview-scale", type=int, default=4)
    args = p.parse_args()

    im = Image.open(args.input).convert("RGBA")
    if args.tile:
        im = downscale(im, args.size)
        if args.seamless:
            band = args.seam_band or max(2, im.width // 16)
            im = make_seamless(im, band)
    else:
        im = key_background(im, args.bg, args.tolerance)
        im = trim_and_pad(im, args.margin)
        im = downscale(im, args.size)
        if args.seamless:
            band = args.seam_band or max(2, im.width // 16)
            im = make_seamless(im, band)
    im = quantize(im, args.colors)
    if args.palette:
        im = apply_palette(im, args.palette)
    im = hard_alpha(im)
    if args.outline:
        im = add_outline(im, tuple(int(c) for c in args.outline.split(",")))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    im.save(args.output)

    scale = max(1, args.preview_scale)
    if args.tile:
        tw, th = im.width * scale, im.height * scale
        prev = Image.new("RGBA", (tw * 2, th * 2), (28, 24, 38, 255))
        tile = im.resize((tw, th), Image.Resampling.NEAREST)
        for y in range(2):
            for x in range(2):
                prev.alpha_composite(tile, (x * tw, y * th))
    else:
        prev = Image.new("RGBA", (im.width * scale, im.height * scale), (28, 24, 38, 255))
        prev.alpha_composite(
            im.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST)
        )
    prev_path = args.output.with_name(args.output.stem + "_preview.png")
    prev.save(prev_path)
    print(f"wrote {args.output} ({im.width}x{im.height}) and {prev_path}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Fit a wide diffusion render into the 190x70 ship portrait without aliasing.

`pixelize_sprite.py` resizes the cropped render straight down with NEAREST,
which throws away ~5 of every 6 source columns: solar-panel grids turn into
moiré and the outline breaks. This tool prefilters at source resolution and
resamples with LANCZOS before quantising, so the silhouette stays clean at the
1:1 size the design screen draws.

Usage:
  make_ship.py raw.png --out assets/sprites/ships/pathfinder.png --width 190 --height 70
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelize as px  # noqa: E402


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("input", type=Path)
    p.add_argument("--out", required=True, type=Path)
    p.add_argument("--width", type=int, default=190)
    p.add_argument("--height", type=int, default=70)
    p.add_argument("--colors", type=int, default=20)
    p.add_argument("--bg", default="auto")
    p.add_argument("--tolerance", type=int, default=70)
    p.add_argument("--margin", type=int, default=3)
    p.add_argument("--prefilter", type=float, default=1.6)
    p.add_argument("--outline", default="10,14,20")
    p.add_argument("--contrast", type=float, default=1.0)
    p.add_argument("--largest", action="store_true",
                   help="keep only the largest connected opaque blob (drops stray dots and painted shadows)")
    p.add_argument("--inset", type=int, default=0,
                   help="crop this many pixels off every edge before keying (kills generated frames)")
    args = p.parse_args()

    im = Image.open(args.input).convert("RGBA")
    if args.inset > 0:
        im = im.crop((args.inset, args.inset, im.width - args.inset, im.height - args.inset))
    im = px.key_background(im, args.bg, args.tolerance)

    # Drop isolated specks and stray stars before cropping, so the bbox is the
    # ship and not a leftover dot in the corner.
    a = np.array(im)[..., 3]
    keep = np.zeros_like(a, dtype=bool)
    keep[a > 16] = True
    # 3x3 majority: keep pixels with at least 3 opaque neighbours.
    pad = np.pad(keep, 1, mode="constant")
    count = sum(pad[1 + dy:1 + dy + keep.shape[0], 1 + dx:1 + dx + keep.shape[1]]
                for dy in (-1, 0, 1) for dx in (-1, 0, 1))
    keep = keep & (count >= 3)
    a = np.where(keep, a, 0)
    im.putalpha(Image.fromarray(a))

    if args.largest:
        from scipy import ndimage
        a = np.array(im)[..., 3] > 16
        labels, count = ndimage.label(a)
        if count > 1:
            sizes = ndimage.sum(a, labels, range(1, count + 1))
            keep_id = int(np.argmax(sizes)) + 1
            a = labels == keep_id
            arr = np.array(im)
            arr[..., 3] = np.where(a, arr[..., 3], 0)
            im = Image.fromarray(arr, "RGBA")

    ys, xs = np.nonzero(np.array(im)[..., 3] > 16)
    if len(xs) == 0:
        raise SystemExit("error: sprite is fully transparent after keying")
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))

    # Blur colour and alpha separately: converting to RGB here would drop the
    # keyed background and paste an opaque rectangle into the portrait.
    rgb = im.convert("RGB").filter(ImageFilter.GaussianBlur(args.prefilter))
    mask = im.getchannel("A").filter(ImageFilter.GaussianBlur(args.prefilter * 0.5))
    im = Image.merge("RGBA", (*rgb.split(), mask))

    box_w = max(1, args.width - args.margin * 2)
    box_h = max(1, args.height - args.margin * 2)
    scale = min(box_w / im.width, box_h / im.height)
    nw = max(1, round(im.width * scale))
    nh = max(1, round(im.height * scale))
    im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    mask = mask.resize((nw, nh), Image.Resampling.LANCZOS)

    if args.contrast != 1.0:
        arr = np.asarray(im, dtype=np.float32)
        rgb_arr = arr[..., :3]
        mean = rgb_arr.reshape(-1, 3).mean(axis=0)
        arr[..., :3] = mean + (rgb_arr - mean) * args.contrast
        im = Image.fromarray(np.clip(arr, 0, 255).astype("uint8"))

    out = Image.new("RGBA", (args.width, args.height), (0, 0, 0, 0))
    out.paste(im, ((args.width - nw) // 2, (args.height - nh) // 2), im)
    out = px.quantize(out, args.colors)
    out = px.hard_alpha(out)
    if args.outline:
        out = px.add_outline(out, tuple(int(c) for c in args.outline.split(",")))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    out.save(args.out)

    prev = args.out.with_name(args.out.stem + "_preview.png")
    prev_img = out.resize((out.width * 3, out.height * 3), Image.Resampling.NEAREST)
    bg = Image.new("RGBA", prev_img.size, (22, 26, 34, 255))
    bg.alpha_composite(prev_img)
    bg.convert("RGB").save(prev)
    print(f"wrote {args.out} ({out.width}x{out.height}) + {prev}")


if __name__ == "__main__":
    main()

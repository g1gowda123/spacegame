#!/usr/bin/env python3
"""Turn a large diffusion render into a calm 64px seamless terrain tile.

The original tile path (`gen_asset.py --tile`) downscaled 1024 -> 64 with
NEAREST, which keeps one source pixel out of every 16x16 block: the pixel-art
LoRA's per-pixel detail becomes high-contrast flecks once palette-locked, and
the board reads as static instead of terrain. This tool prefilters before
resampling and resamples with LANCZOS, so colour arrives as large clusters.

Usage:
  make_tile.py raw.png --out assets/tilesets/cryo/snow.png --biome cryo
  make_tile.py raw.png --out t.png --palette 0e141c,1a2632 --size 64 --prefilter 2.2
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from pixelize import apply_palette, make_seamless  # noqa: E402


def load_palette(biome: str | None, spec: str | None) -> str | None:
    if spec:
        return spec
    if not biome:
        return None
    palettes = json.loads((ROOT / "tools" / "palettes.json").read_text())
    if biome not in palettes:
        raise SystemExit(f"unknown palette '{biome}' (have: {', '.join(palettes)})")
    return ",".join(c.lstrip("#") for c in palettes[biome]["colors"])


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("raw", type=Path)
    p.add_argument("--out", required=True, type=Path)
    p.add_argument("--size", type=int, default=64)
    p.add_argument("--prefilter", type=float, default=2.0,
                   help="gaussian radius applied at source resolution (px)")
    p.add_argument("--biome", default=None)
    p.add_argument("--palette", default=None, help="comma-separated hex colours")
    p.add_argument("--keep-colors", type=int, default=0,
                   help="when set, quantize to this many colours instead of palette locking")
    p.add_argument("--contrast", type=float, default=1.0,
                   help="<1 flattens the render toward its mean (0.85 = calmer)")
    p.add_argument("--seam-band", type=int, default=6)
    p.add_argument("--preview", action="store_true", default=True)
    args = p.parse_args()

    im = Image.open(args.raw).convert("RGB")
    if args.prefilter > 0:
        im = im.filter(ImageFilter.GaussianBlur(args.prefilter))
    im = im.resize((args.size, args.size), Image.Resampling.LANCZOS)

    if args.contrast != 1.0:
        import numpy as np
        a = np.asarray(im, dtype=np.float32)
        mean = a.reshape(-1, 3).mean(axis=0)
        a = mean + (a - mean) * args.contrast
        im = Image.fromarray(np.clip(a, 0, 255).astype("uint8"))

    rgba = im.convert("RGBA")
    if args.seam_band > 0:
        rgba = make_seamless(rgba, band=args.seam_band)
    rgba = rgba.convert("RGB").convert("RGBA")

    spec = load_palette(args.biome, args.palette)
    if args.keep_colors:
        rgba = rgba.convert("RGB").quantize(
            colors=args.keep_colors, method=Image.Quantize.MEDIANCUT
        ).convert("RGBA")
    elif spec:
        rgba = apply_palette(rgba, spec)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    rgba.save(args.out)

    if args.preview:
        w, h = rgba.size
        sheet = Image.new("RGB", (w * 3 + 8, h * 3 + 8), (20, 20, 26))
        for y in range(3):
            for x in range(3):
                sheet.paste(rgba.convert("RGB"), (x * (w + 4), y * (h + 4)))
        sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.Resampling.NEAREST)
        prev = args.out.with_name(args.out.stem + "_preview.png")
        sheet.save(prev)
        print(f"wrote {args.out} + {prev}")
    else:
        print(f"wrote {args.out}")


if __name__ == "__main__":
    main()

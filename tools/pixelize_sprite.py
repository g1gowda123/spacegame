#!/usr/bin/env python3
"""Crop a generated sprite to its content and fit it into a fixed canvas.

Unlike pixelize.py (square output), this preserves a wide/tall aspect so a
spacecraft can fill a 190x70 mission-design viewport without being shrunk to a
postage stamp.  Background keying, quantisation and outlining reuse the
project's proven pixelize helpers.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelize as px  # noqa: E402


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("input", type=Path)
    p.add_argument("output", type=Path)
    p.add_argument("--width", type=int, default=190)
    p.add_argument("--height", type=int, default=70)
    p.add_argument("--colors", type=int, default=20)
    p.add_argument("--bg", default="auto")
    p.add_argument("--tolerance", type=int, default=70)
    p.add_argument("--margin", type=int, default=2)
    p.add_argument("--outline", default=None)
    args = p.parse_args()

    im = Image.open(args.input).convert("RGBA")
    im = px.key_background(im, args.bg, args.tolerance)
    alpha = np.array(im)[..., 3]
    ys, xs = np.nonzero(alpha > 16)
    if len(xs) == 0:
        raise SystemExit("error: sprite is fully transparent after keying")
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))

    box_w = max(1, args.width - args.margin * 2)
    box_h = max(1, args.height - args.margin * 2)
    scale = min(box_w / im.width, box_h / im.height)
    nw = max(1, round(im.width * scale))
    nh = max(1, round(im.height * scale))
    im = im.resize((nw, nh), Image.Resampling.NEAREST)

    out = Image.new("RGBA", (args.width, args.height), (0, 0, 0, 0))
    out.paste(im, ((args.width - nw) // 2, (args.height - nh) // 2))
    out = px.quantize(out, args.colors)
    out = px.hard_alpha(out)
    if args.outline:
        out = px.add_outline(out, tuple(int(c) for c in args.outline.split(",")))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    out.save(args.output)
    print(f"wrote {args.output} ({out.width}x{out.height})")


if __name__ == "__main__":
    main()

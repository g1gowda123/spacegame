#!/usr/bin/env python3
"""W5 — luminance floor for base ground tiles.

`MAP_OVERHAUL.md` W5 wants every biome's on-screen ground at or above ~120
luma with its hue intact. Measure first (`--audit`), then lift with a gain
capped at 1.35 so nothing blows out, re-lock the biome palette and report the
before/after numbers.
"""
import argparse
import json
import re
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TARGET = 122.0
MAX_GAIN = 1.35


def luma(a):
    return float(0.2126 * a[..., 0].mean() + 0.7152 * a[..., 1].mean() + 0.0722 * a[..., 2].mean())


def bases():
    src = (ROOT / "scripts" / "map_generator.gd").read_text()
    out, seen = [], set()
    for bid, tile in re.findall(r'"id":\s*"([a-z]+)"[\s\S]{0,400}?"base":\s*"([a-z_]+/[a-z_0-9]+)"', src):
        if bid in seen:
            continue
        seen.add(bid)
        p = ROOT / "assets" / "tilesets" / (tile + ".png")
        if p.exists():
            out.append((bid, tile, p))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--audit", action="store_true")
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    rows = []
    for bid, tile, p in bases():
        a = np.asarray(Image.open(p).convert("RGB")).astype(np.float32)
        cur = luma(a)
        rows.append((bid, tile, p, cur))
    for bid, tile, p, cur in sorted(rows, key=lambda r: r[3]):
        if not args.apply or cur >= TARGET:
            print(f"{bid:10s} {tile:22s} {cur:6.1f}")
            continue
        gain = min(MAX_GAIN, TARGET / max(1.0, cur))
        img = Image.open(p).convert("RGBA")
        arr = np.asarray(img).astype(np.float32)
        arr[..., :3] = np.clip(arr[..., :3] * gain, 0, 255)
        img = Image.fromarray(arr.astype(np.uint8), "RGBA")
        sys_path = str(ROOT / "tools")
        import sys
        if sys_path not in sys.path:
            sys.path.insert(0, sys_path)
        from pixelize import apply_palette
        from make_structure_pieces import spec
        img = apply_palette(img, spec(bid))
        img.save(p)
        new = luma(np.asarray(img.convert("RGB")).astype(np.float32))
        print(f"{bid:10s} {tile:22s} {cur:6.1f} -> {new:6.1f}  gain {gain:.2f}")


if __name__ == "__main__":
    main()

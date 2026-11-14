#!/usr/bin/env python3
"""Deterministic pixel-art FX frames for Orbit & Outplay.

This is *animation* art: particle sprites and short effect sheets. The static
tile/sprite library belongs to VEGA; everything here is a time-varying effect
and is regenerated from code so it can be re-tuned without a diffusion pass.

Output (all nearest-neighbour, transparent RGBA):

    assets/vfx/particle_dot.png        8x8   soft dot (generic particle)
    assets/vfx/particle_spark.png     12x12  4-point spark
    assets/vfx/particle_smoke.png     16x16  soft smoke/dust puff
    assets/vfx/particle_ember.png      6x6   hot ember
    assets/vfx/particle_snow.png       5x5   snow flake
    assets/vfx/particle_spore.png      5x5   spore mote

    assets/vfx/ring/frame_00..07.png   48x48  shockwave ring, 8 frames
    assets/vfx/shield/frame_00..07.png 48x48  hex shield, 8 frames
    assets/vfx/flare/frame_00..07.png  64x64  impact flare, 8 frames
    assets/vfx/smoke_puff/frame_00..07.png 40x40 billowing puff
    assets/vfx/splash/frame_00..05.png 32x32  water/regolith splash
    assets/vfx/debris/frame_00..05.png 16x16  kicked-up debris

    assets/vfx/manifest.json           frame counts + fps + intended use
    assets/vfx/preview.png             contact sheet

Usage:
    python3 tools/make_vfx_art.py
"""
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "vfx"


def new(size: int | tuple[int, int]) -> Image.Image:
    if isinstance(size, int):
        size = (size, size)
    return Image.new("RGBA", size, (0, 0, 0, 0))


def put(im: Image.Image, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), color)


def disc(im: Image.Image, cx: float, cy: float, radius: float,
         color: tuple[int, int, int, int], hard: bool = False) -> None:
    """Pixel disc; hard edges (no antialiasing) unless `hard` is False."""
    r = int(math.ceil(radius))
    for y in range(int(cy) - r, int(cy) + r + 1):
        for x in range(int(cx) - r, int(cx) + r + 1):
            d = math.hypot(x - cx + 0.5, y - cy + 0.5)
            if d > radius:
                continue
            if hard:
                put(im, x, y, color)
            else:
                k = max(0.0, 1.0 - d / max(radius, 1e-6))
                a = int(color[3] * k * k * (3 - 2 * k))
                if a > 0:
                    put(im, x, y, (color[0], color[1], color[2], a))


def ring(im: Image.Image, cx: float, cy: float, radius: float, width: float,
         color: tuple[int, int, int, int]) -> None:
    r = int(math.ceil(radius + width))
    for y in range(int(cy) - r, int(cy) + r + 1):
        for x in range(int(cx) - r, int(cx) + r + 1):
            d = math.hypot(x - cx + 0.5, y - cy + 0.5)
            if abs(d - radius) <= width * 0.5:
                put(im, x, y, color)


def _save(im: Image.Image, rel: str) -> None:
    path = OUT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)


def particle_dot() -> Image.Image:
    im = new(8)
    disc(im, 4, 4, 3.6, (255, 255, 255, 230))
    return im


def particle_spark() -> Image.Image:
    im = new(12)
    c = 6
    for i in range(1, 6):
        a = int(255 * (1.0 - i / 6.0))
        col = (255, 240, 200, a)
        put(im, c - i, c, col)
        put(im, c + i, c, col)
        put(im, c, c - i, col)
        put(im, c, c + i, col)
    disc(im, c, c, 2.2, (255, 255, 230, 255))
    return im


def particle_smoke() -> Image.Image:
    im = new(16)
    disc(im, 8, 8, 7.0, (200, 198, 190, 120))
    disc(im, 6.5, 7.0, 4.2, (220, 218, 210, 90))
    disc(im, 9.5, 9.0, 3.4, (180, 178, 172, 70))
    return im


def particle_ember() -> Image.Image:
    im = new(6)
    disc(im, 3, 3, 2.6, (255, 150, 60, 160))
    disc(im, 3, 3, 1.3, (255, 236, 170, 255), hard=True)
    return im


def particle_snow() -> Image.Image:
    im = new(6)
    for p in ((2, 2), (3, 2), (2, 3), (3, 3)):
        put(im, p[0], p[1], (235, 248, 255, 235))
    put(im, 1, 1, (200, 230, 245, 120))
    put(im, 4, 4, (200, 230, 245, 120))
    return im


def particle_spore() -> Image.Image:
    im = new(6)
    disc(im, 3, 3, 2.2, (150, 230, 170, 150))
    put(im, 3, 3, (235, 255, 210, 235))
    return im


def ring_frames() -> list[Image.Image]:
    frames = []
    n = 8
    for i in range(n):
        t = i / (n - 1)
        im = new(48)
        radius = 3.0 + t * 20.0
        width = max(1.0, 3.0 * (1.0 - t) + 0.6)
        a = int(240 * (1.0 - t) ** 1.3)
        if a > 0:
            ring(im, 24, 24, radius, width, (255, 255, 255, a))
            ring(im, 24, 24, radius * 0.72, max(1.0, width * 0.55), (200, 245, 255, int(a * 0.45)))
        frames.append(im)
    return frames


def shield_frames() -> list[Image.Image]:
    frames = []
    n = 8
    for i in range(n):
        t = i / (n - 1)
        im = new(48)
        radius = 8.0 + t * 15.0
        a = int(235 * (1.0 - t) ** 1.1)
        cx = cy = 24.0
        pts = []
        for k in range(6):
            ang = math.tau * k / 6.0 + math.pi / 6.0
            pts.append((cx + math.cos(ang) * radius, cy + math.sin(ang) * radius))
        d = ImageDraw.Draw(im)
        # Filled panel at 20% plus a bright outline.
        d.polygon(pts, fill=(90, 230, 210, int(a * 0.16)))
        d.line(pts + [pts[0]], fill=(160, 255, 240, a), width=2)
        # Inner facet cross for the "energy" read.
        inner = [(cx + (x - cx) * 0.55, cy + (y - cy) * 0.55) for x, y in pts]
        d.line(inner + [inner[0]], fill=(90, 230, 210, int(a * 0.35)), width=1)
        frames.append(im)
    return frames


def flare_frames() -> list[Image.Image]:
    frames = []
    n = 8
    for i in range(n):
        t = i / (n - 1)
        im = new(64)
        c = 32.0
        # Hot core collapses, spokes and smoke expand.
        core = max(0.0, 9.0 * (1.0 - t * 1.3))
        if core > 0.5:
            disc(im, c, c, core, (255, 250, 220, int(255 * (1.0 - t))))
            disc(im, c, c, core * 0.55, (255, 255, 255, 255))
        spokes = 12
        for k in range(spokes):
            ang = math.tau * k / spokes + t * 0.5
            length = (6.0 + t * 24.0) * (0.55 + 0.45 * ((k * 37) % 11) / 10.0)
            a = int(180 * (1.0 - t))
            if a <= 0:
                continue
            x = c + math.cos(ang) * length
            y = c + math.sin(ang) * length
            ImageDraw.Draw(im).line((c, c, x, y), fill=(255, 214, 150, a), width=2 if t < 0.4 else 1)
        if t > 0.2:
            ring(im, c, c, 8.0 + t * 24.0, 1.5, (255, 255, 255, int(150 * (1.0 - t))))
        frames.append(im)
    return frames


def puff_frames() -> list[Image.Image]:
    frames = []
    n = 8
    for i in range(n):
        t = i / (n - 1)
        im = new(40)
        c = 20.0
        base_r = 4.0 + t * 13.0
        a = int(150 * (1.0 - t) ** 1.3)
        disc(im, c, c + t * 2.0, base_r, (190, 186, 176, a))
        disc(im, c - 4 - t * 3, c + 1 - t * 3, base_r * 0.7, (205, 200, 190, int(a * 0.8)))
        disc(im, c + 4 + t * 3, c + 1 - t * 2, base_r * 0.6, (170, 166, 158, int(a * 0.8)))
        frames.append(im)
    return frames


def splash_frames() -> list[Image.Image]:
    frames = []
    n = 6
    for i in range(n):
        t = i / (n - 1)
        im = new(32)
        c = 16.0
        drops = 9
        for k in range(drops):
            ang = math.tau * k / drops
            dist = 3.0 + t * 11.0
            x = c + math.cos(ang) * dist
            y = c + math.sin(ang) * dist * 0.65 - t * 6.0 + 6.0
            a = int(220 * (1.0 - t))
            if a > 0:
                put(im, int(x), int(y), (170, 220, 235, a))
                put(im, int(x), int(y) + 1, (120, 180, 205, a // 2))
        if t < 0.5:
            ring(im, c, c + 5, 2.0 + t * 12.0, 1.0, (200, 240, 250, int(180 * (1.0 - t * 2))))
        frames.append(im)
    return frames


def debris_frames() -> list[Image.Image]:
    frames = []
    n = 6
    for i in range(n):
        t = i / (n - 1)
        im = new(16)
        for k in range(7):
            ang = math.tau * k / 7 + 0.3
            dist = 1.0 + t * 7.0 * (0.6 + 0.4 * ((k * 5) % 3) / 2.0)
            x = 8 + math.cos(ang) * dist
            y = 8 + math.sin(ang) * dist + t * t * 5.0
            a = int(230 * (1.0 - t))
            if a > 0:
                put(im, int(x), int(y), (120, 104, 90, a))
        frames.append(im)
    return frames


def seq(name: str, frames: list[Image.Image]) -> dict:
    for i, im in enumerate(frames):
        _save(im, f"{name}/frame_{i:02d}.png")
    return {"frames": len(frames), "frame_ms": 42, "size": [frames[0].width, frames[0].height]}


def preview(sheets: dict[str, list[Image.Image]]) -> None:
    order = ["ring", "shield", "flare", "smoke_puff", "splash", "debris"]
    cell = 80
    cols = 8
    canvas = Image.new("RGBA", (cols * cell, len(order) * cell), (12, 16, 26, 255))
    for row, name in enumerate(order):
        for col, im in enumerate(sheets[name]):
            ox = col * cell + (cell - im.width) // 2
            oy = row * cell + (cell - im.height) // 2
            canvas.alpha_composite(im, (ox, oy))
    canvas.save(OUT / "preview.png")

    tiny = Image.new("RGBA", (6 * 40, 24), (12, 16, 26, 255))
    for i, im in enumerate([
        particle_dot(), particle_spark(), particle_smoke(),
        particle_ember(), particle_snow(), particle_spore(),
    ]):
        big = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
        tiny.alpha_composite(big, (i * 40 + 4, 4))
    tiny.save(OUT / "preview_particles.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    single = {
        "particle_dot": particle_dot(),
        "particle_spark": particle_spark(),
        "particle_smoke": particle_smoke(),
        "particle_ember": particle_ember(),
        "particle_snow": particle_snow(),
        "particle_spore": particle_spore(),
    }
    for name, im in single.items():
        _save(im, f"{name}.png")

    sheets = {
        "ring": ring_frames(),
        "shield": shield_frames(),
        "flare": flare_frames(),
        "smoke_puff": puff_frames(),
        "splash": splash_frames(),
        "debris": debris_frames(),
    }
    manifest = {
        "generator": "tools/make_vfx_art.py",
        "note": "Animation art only. Static tiles/sprites are VEGA's lane.",
        "particles": {k: {"size": [v.width, v.height]} for k, v in single.items()},
        "sheets": {k: seq(k, v) for k, v in sheets.items()},
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    preview(sheets)
    print(f"wrote FX art to {OUT} ({len(list(OUT.rglob('*.png')))} PNGs)")


if __name__ == "__main__":
    main()

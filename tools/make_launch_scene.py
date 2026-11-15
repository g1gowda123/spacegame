#!/usr/bin/env python3
"""Launch site: backdrop plate + pad and gantry redrawn at 2x.

The screen currently floats a thin rocket on flat navy with a disconnected
gantry, so this provides a scene to sit behind it: a night launch complex with a
horizon ridge, floodlight masts, ground haze and a lit pad deck. All pixel
geometry at 2x of the 640x360 view, so it scales down by exactly 0.5.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
BG = ROOT / "assets" / "backgrounds"
VEH = ROOT / "assets" / "sprites" / "vehicles"

W, H = 1280, 720
HORIZON = 560          # ground line in plate pixels (= y 280 at 1x)


def dither_row(rng, y, x0, x1, c0, c1, t):
    for x in range(x0, x1):
        c = c0 if rng.random() > t else c1
        _px[y, x] = c


def plate():
    global _px
    rng = np.random.default_rng(4242)
    img = Image.new("RGB", (W, H), (6, 9, 16))
    _px = img.load()
    # sky: vertical ramp from deep navy to a warmer haze at the horizon
    for y in range(HORIZON):
        t = y / HORIZON
        r = int(6 + 26 * t ** 2)
        g = int(9 + 30 * t ** 2)
        b = int(16 + 34 * t ** 1.6)
        for x in range(W):
            _px[x, y] = (r, g, b) if rng.random() > 0.02 else (r + 4, g + 4, b + 4)
    # stars above the haze
    for _ in range(240):
        x, y = int(rng.uniform(0, W)), int(rng.uniform(0, HORIZON * 0.55))
        v = int(rng.integers(90, 210))
        _px[x, y] = (v, v, min(255, v + 20))
    # distant ridge
    for x in range(W):
        h = int(34 * np.sin(x / 210.0) + 18 * np.sin(x / 63.0 + 1.2) + 26)
        for y in range(HORIZON - h, HORIZON):
            _px[x, y] = (14, 20, 30)
    # ground apron
    for y in range(HORIZON, H):
        t = (y - HORIZON) / (H - HORIZON)
        c = (int(18 + 10 * t), int(24 + 12 * t), int(32 + 14 * t))
        for x in range(W):
            _px[x, y] = c
    img = img.filter(ImageFilter.GaussianBlur(0.4))
    _px = img.load()

    # floodlight masts with soft cones
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for mx in (150, 1130):
        gd.rectangle([mx, 300, mx + 6, HORIZON], fill=(26, 32, 42))
        gd.rectangle([mx - 14, 292, mx + 20, 302], fill=(38, 46, 58))
        gd.ellipse([mx - 10, 286, mx + 16, 298], fill=(255, 232, 186))
        gd.polygon([(mx + 3, 296), (mx + 150, HORIZON), (mx - 140, HORIZON)], fill=(28, 26, 22))
    glow = glow.filter(ImageFilter.GaussianBlur(18))
    base = Image.fromarray(np.asarray(img).copy())
    base = Image.blend(base, Image.fromarray(np.clip(np.asarray(base).astype(int) + np.asarray(glow), 0, 255).astype(np.uint8)), 0.55)
    img = base

    # pad apron poles and cable runs, faint
    d = ImageDraw.Draw(img)
    for x in range(80, W, 190):
        d.rectangle([x, HORIZON + 18, x + 3, HORIZON + 54], fill=(26, 32, 40))
    d.line([(0, HORIZON + 8), (W, HORIZON + 8)], fill=(22, 30, 40))
    # haze band over the ground line
    haze = Image.new("RGB", (W, H), (0, 0, 0))
    hd = ImageDraw.Draw(haze)
    hd.rectangle([0, HORIZON - 20, W, HORIZON + 70], fill=(10, 14, 22))
    haze = haze.filter(ImageFilter.GaussianBlur(26))
    img = Image.fromarray(np.clip(np.asarray(img).astype(int) + np.asarray(haze) * 0.35, 0, 255).astype(np.uint8))
    img.save(BG / "launch_site.png")

    prev = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    prev.alpha_composite(img.convert("RGBA"))
    prev.resize((640, 360), Image.Resampling.LANCZOS).save(BG / "launch_site_preview.png")
    return img


def pad():
    w, h = 320, 96
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # trench
    d.rectangle([0, 26, w - 1, h - 1], fill=(12, 18, 26))
    d.rectangle([96, 30, w - 97, h - 1], fill=(5, 8, 12))
    # table deck
    d.rectangle([0, 18, w - 1, 30], fill=(58, 72, 84))
    d.line([0, 18, w - 1, 18], fill=(104, 122, 136))
    d.line([0, 29, w - 1, 29], fill=(30, 38, 48))
    # hazard chevrons
    for x in range(0, w - 8, 24):
        d.polygon([(x, 22), (x + 12, 22), (x + 6, 28), (x - 6, 28)], fill=(232, 184, 72))
    # legs and rails
    for x in (70, 246):
        d.rectangle([x - 6, 30, x + 6, h - 1], fill=(44, 56, 68))
        d.line([x - 6, 30, x - 6, h - 1], fill=(24, 32, 42))
    for x in range(28, w - 28, 40):
        d.line([x, 34, x, 44], fill=(70, 84, 98))
    # pipe runs along the trench edge
    d.line([12, 50, w - 13, 50], fill=(52, 64, 76), width=3)
    d.line([12, 58, w - 13, 58], fill=(38, 48, 58), width=2)
    # hold-down clamps at the centre
    for x in (142, 178):
        d.rectangle([x - 8, 12, x + 8, 20], fill=(86, 98, 110))
        d.line([x - 8, 12, x + 8, 12], fill=(132, 146, 158))
    img.save(VEH / "launch_pad.png")
    return img


def gantry():
    w, h = 96, 360
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([8, 0, w - 9, h - 1], fill=(20, 28, 38))
    d.rectangle([8, 0, w - 9, h - 1], outline=(64, 82, 98), width=3)
    for y in range(0, h - 1, 44):
        d.line([8, y, w - 9, min(h - 1, y + 44)], fill=(46, 62, 78), width=2)
        d.line([w - 9, y, 8, min(h - 1, y + 44)], fill=(46, 62, 78), width=2)
        d.line([8, y, w - 9, y], fill=(78, 98, 116), width=2)
    # swing arms toward the stack (left side) and pipes up the spine
    for y in (110, 196):
        d.rectangle([0, y, 10, y + 12], fill=(62, 78, 94))
        d.line([0, y, 10, y], fill=(110, 128, 142))
    d.line([w - 16, 8, w - 16, h - 10], fill=(88, 106, 122), width=3)
    d.line([w - 12, 8, w - 12, h - 10], fill=(56, 70, 84), width=2)
    # crane head
    d.rectangle([-22, 0, w - 9, 16], fill=(58, 74, 90))
    d.line([-22, 0, w - 9, 0], fill=(118, 136, 150))
    d.line([6, 16, 6, 40], fill=(70, 86, 102))
    img.save(VEH / "launch_gantry.png")
    return img


def main():
    plate()
    pad()
    gantry()
    print("launch_site 1280x720, pad 320x96, gantry 96x360")


if __name__ == "__main__":
    main()

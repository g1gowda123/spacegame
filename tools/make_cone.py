#!/usr/bin/env python3
"""Row-built cone/mound structures — no painted base disc.

A volcano is drawn as stacked flank rows: for each scanline the silhouette
half-width grows from the crater rim to the foot, with per-row jitter and a
per-column ridge pattern, so the outline is jagged and the ground contact is
the rock itself. The renderer supplies the only shadow.
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "tilesets" / "structures"

PALS = {
    "volcanic": dict(dark=(30, 28, 30), mid=(66, 60, 56), light=(108, 98, 86),
                     top=(150, 136, 118), lava=((255, 176, 62), (238, 104, 26), (146, 44, 14)),
                     crater=(200, 62, 20), rim=(160, 146, 126)),
    "geyser": dict(dark=(28, 32, 38), mid=(56, 62, 68), light=(88, 94, 96),
                   top=(120, 126, 124), lava=((196, 228, 236), (132, 182, 198), (74, 118, 138)),
                   crater=(58, 92, 104), rim=(126, 134, 132), cw=1.9),
    "methane": dict(dark=(22, 34, 36), mid=(52, 70, 70), light=(96, 124, 114),
                    top=(150, 176, 158), lava=((160, 232, 212), (94, 178, 160), (44, 106, 100)),
                    crater=(52, 118, 110), rim=(128, 156, 142), cw=1.9),
}


def lerp(c0, c1, t):
    return tuple(int(round(c0[i] + (c1[i] - c0[i]) * t)) for i in range(3))


def ramp(t, stops):
    t = min(max(t, 0.0), 1.0)
    n = len(stops) - 1
    i = min(int(t * n), n - 1)
    return lerp(stops[i], stops[i + 1], t * n - i)


def mixedish(c0, c1, t):
    return tuple(int(round(c0[i] * (1 - t) + c1[i] * t)) for i in range(3))


def build(name, size, seed, pal_name, summit=0.16, foot=0.90, base_half=0.44, top_half=0.055):
    P = PALS[pal_name]
    rng = np.random.default_rng(seed)
    img = np.zeros((size, size, 4), np.uint8)
    cx = (size - 1) / 2.0
    y0, y1 = summit * size, foot * size
    # per-row jaggedness and per-column ridge bias
    row_jit = rng.normal(0, 0.032, size)
    col_ridge = rng.normal(0, 1.0, size)
    col_ridge = np.convolve(col_ridge, np.ones(5) / 5, mode="same")
    # ground line: ragged per column so the foot never ends on a straight row
    bn = rng.normal(0, 0.030, size)
    bn = np.convolve(bn, np.ones(13) / 13, mode="same")
    bottom = (y1 * (1.0 + bn)).astype(int)
    bottom = np.clip(bottom, int(y1 * 0.84), size - 1)
    # a handful of lava runs down the flanks
    runs = []
    for _ in range(max(2, size // 40)):
        runs.append(dict(
            x=int(rng.uniform(cx - size * base_half * 0.55, cx + size * base_half * 0.55)),
            phase=rng.uniform(0, 6.28),
            wobble=rng.uniform(0.6, 2.2),
            start=rng.uniform(0.02, 0.28),
            end=rng.uniform(0.45, 0.98),
            width=int(rng.choice([1, 1, 2, 3])),
        ))

    for y in range(int(y0), int(y1) + 1):
        t = max(0.0, (y - y0) / max(1.0, (y1 - y0)))
        half = (top_half + (base_half - top_half) * t ** 0.82) * size
        half *= 1.0 + row_jit[y] + 0.05 * math.sin(y * 0.19)
        x0, x1 = int(cx - half), int(cx + half)
        if x1 <= x0:
            continue
        for x in range(x0, x1 + 1):
            if y > bottom[x]:
                continue
            u = (x - cx) / max(1.0, half)          # -1 left .. +1 right
            # light from upper-left, plus a little vertical falloff
            lit = 0.62 - 0.34 * u - 0.10 * (1.0 - t)
            lit += 0.10 * col_ridge[x] * (0.4 + 0.6 * t)
            # ridged flanks: darker gullies alternating with lit spurs
            gully = 0.5 + 0.5 * math.sin(x * 0.33 + row_jit[y] * 30)
            lit *= 0.86 + 0.20 * gully
            # mineral strata: horizontal bands break up the smooth cone
            band = 0.5 + 0.5 * math.sin(y * 0.62 + row_jit[y] * 26 + 0.8 * math.sin(x * 0.09))
            lit *= 0.90 + 0.16 * band
            base = ramp(0.30 + 0.55 * lit, [P["dark"], P["mid"], P["light"], P["top"]])
            # dry talus at the very foot
            if t > 0.88:
                base = mixedish(base, P["dark"], 0.35)
            # granular rock speckle
            j = int(rng.integers(-8, 9))
            base = (max(0, min(255, base[0] + j)), max(0, min(255, base[1] + j)),
                    max(0, min(255, base[2] + j)))
            img[y, x] = (*base, 255)

        # lava runs: a wobbling rivulet that widens as it descends
        for rn in runs:
            if t < rn["start"] or t > rn["end"]:
                continue
            xr = rn["x"] + int(rn["wobble"] * math.sin(y * 0.11 + rn["phase"]))
            spread = rn["width"] + int(2.0 * t)
            for dx2 in range(-spread, spread + 1):
                x2 = xr + dx2
                if not (x0 <= x2 <= x1) or y > bottom[x2]:
                    continue
                fade = 1.0 - abs(dx2) / (spread + 1.0)
                col = ramp(0.10 + 0.90 * (1.0 - t), list(P["lava"]))
                img[y, x2] = (*mixedish(P["dark"], col, 0.35 + 0.65 * fade), 255)

    # crater: dark vent with a hot throat and a raised rim
    cy = int(y0 + size * 0.012)
    rx, ry = size * (top_half + 0.012 * P.get("cw", 1.0)), size * 0.030 * P.get("cw", 1.0)
    yy, xx = np.mgrid[0:size, 0:size]
    d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
    rim = (d > 0.85) & (d < 1.55)
    vent = d <= 0.85
    img[rim] = (*P["rim"], 255)
    inner = np.clip(d, 0, 1)
    for y, x in zip(*np.nonzero(vent)):
        c = ramp(0.25 + 0.75 * inner[y, x], list(P["lava"]))
        img[y, x] = (*c, 255)

    # outline: 1 px dark contour so the cone sits on the map, not in it
    a = (img[..., 3] > 0)
    pad = np.pad(a, 1)
    edge = a & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    img[edge] = (16, 16, 20, 255)

    out = Image.fromarray(img, "RGBA")
    # albedo pass: diffuse texture through the sprite's own shading
    tex_name = "basalt" if pal_name == "volcanic" else "mineral"
    tex_path = ROOT / "assets" / "raw" / "textures" / f"{tex_name}.png"
    if tex_path.exists():
        from PIL import Image as _I
        c = np.asarray(out).astype(np.float32)
        t = np.asarray(_I.open(tex_path).convert("RGB").resize(out.size, _I.Resampling.LANCZOS)).astype(np.float32)
        a2 = c[..., 3]
        lum = 0.3 * c[..., 0] + 0.59 * c[..., 1] + 0.11 * c[..., 2]
        mean = max(1.0, float(lum[a2 > 0].mean())) if (a2 > 0).any() else 1.0
        light = np.clip(lum / mean, 0.45, 1.7)[..., None]
        o = np.clip(t * light * 1.12, 0, 255)
        r, g, b = c[..., 0], c[..., 1], c[..., 2]
        lava = (r > 90) & (r > g + 30) & (r > b + 30)
        o[lava] = c[lava][:, :3]
        out = _I.fromarray(np.dstack([o, a2]).astype(np.uint8), "RGBA")
    out.save(OUT / f"{name}.png")
    prev = Image.new("RGBA", out.size, (22, 26, 34, 255))
    prev.alpha_composite(out)
    prev.save(OUT / f"{name}_preview.png")
    print(f"{name}.png {size} cov={np.mean(img[..., 3] > 0):.1%}")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    build("volcano_prim", 192, 71, "volcanic")
    build("geyser_prim", 128, 73, "geyser", summit=0.30, foot=0.94, base_half=0.40, top_half=0.030)
    build("methane_vent_prim", 128, 77, "methane", summit=0.30, foot=0.94, base_half=0.40, top_half=0.030)
    build("geyser_field_prim", 192, 79, "geyser", summit=0.24, foot=0.94, base_half=0.46, top_half=0.040)


def build_terrace(name, size, seed, pal_name, steps=4):
    """Hot-spring terrace: stacked irregular mineral plates, no cone, no pad."""
    P = PALS[pal_name]
    rng = np.random.default_rng(seed)
    img = np.zeros((size, size, 3), np.uint8)
    alpha = np.zeros((size, size), np.uint8)
    cx = (size - 1) / 2.0
    base_y = size * 0.88
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)

    for i in range(steps):
        f = i / max(1, steps - 1)                 # 0 base .. 1 top
        cy = base_y - f * size * 0.46
        rx = size * (0.44 - 0.22 * f) * rng.uniform(0.94, 1.05)
        ry = rx * rng.uniform(0.34, 0.42)
        ox = rng.uniform(-0.03, 0.03) * size
        # wobbly rim
        ang = np.arctan2((yy - cy) / ry, (xx - cx - ox) / rx)
        wob = 1.0 + 0.10 * np.sin(ang * 5 + seed * 0.7 + i * 2.1) + 0.06 * np.sin(ang * 9 - i)
        d = np.sqrt(((xx - cx - ox) / (rx * wob)) ** 2 + ((yy - cy) / (ry * wob)) ** 2)
        inside = d <= 1.0
        if not inside.any():
            continue
        # side wall: same plate pushed down, darker, gives each terrace a face
        wh = size * 0.055
        dw = np.sqrt(((xx - cx - ox) / (rx * wob)) ** 2 + ((yy - cy - wh) / (ry * wob)) ** 2)
        wall = (dw <= 1.0) & ~inside
        img[wall] = np.array(P["dark"]) * 0.92
        alpha[wall] = 255
        # plate face: lighter toward the top edge, darker into the pool
        tone = 0.30 + 0.34 * (1.0 - np.clip((cy + ry - yy) / (2 * ry), 0, 1)) + 0.16 * f
        tone = tone + (np.sin(xx * 0.22 + yy * 0.31) * 0.03)
        col = ramp(0.0, [P["dark"], P["mid"], P["light"], P["top"]])
        rgb = np.zeros((size, size, 3))
        tt = np.clip(tone, 0, 1)
        stops = [P["dark"], P["mid"], P["light"], P["top"]]
        for k in range(3):
            c0 = np.array(stops[k]); c1 = np.array(stops[k + 1])
            m0, m1 = k / 3.0, (k + 1) / 3.0
            seg = np.clip((tt - m0) / (m1 - m0), 0, 1)
            rgb = np.where((tt >= m0)[..., None], c0 + (c1 - c0) * seg[..., None], rgb)
        # rim: a bright lip on the outer 2 px of the plate
        lip = (d > 0.90) & (d <= 1.0) & (yy < cy + ry * 0.15)
        rgb[lip] = np.array(P["rim"]) * 0.92
        img[inside] = rgb[inside]
        alpha[inside] = 255
        # pool in the top plate
        if i == steps - 1:
            pool = (d <= 0.42)
            for y, x in zip(*np.nonzero(pool)):
                c = ramp(0.2 + 0.8 * min(1.0, d[y, x] / 0.42), list(P["lava"]))
                img[y, x] = c
                alpha[y, x] = 255

    # dark contour
    a = alpha > 0
    pad = np.pad(a, 1)
    edge = a & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    img[edge] = (16, 16, 20)
    out = Image.fromarray(np.dstack([img, alpha]).astype(np.uint8), "RGBA")
    out.save(OUT / f"{name}.png")
    prev = Image.new("RGBA", out.size, (22, 26, 34, 255))
    prev.alpha_composite(out)
    prev.save(OUT / f"{name}_preview.png")
    print(f"{name}.png {size} cov={np.mean(alpha > 0):.1%}")

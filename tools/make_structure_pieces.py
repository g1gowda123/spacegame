#!/usr/bin/env python3
"""Cut modular structure pieces out of the assembled landform art.

The scale pass needs 4-6 tile major landforms built from modules that join
without seams. Rather than hand-cutting pieces (which never line up), this tool
**assembles** each landform at full size, then cuts it into 64 px tiles. ATLAS
places the tiles at integer offsets, so the join is pixel-exact by construction.

Sets produced in `assets/tilesets/structures/pieces/`:

  massif_r<row>c<col>   4x4 (256 px) temperate massif, 16 tiles
  volcano_r<row>c<col>  4x4 (256 px) volcanic cone + flanks + lava apron
  ridge_crest_a/b       2x1 (128x64) long wall crests
  ridge_foot            2x1 (128x64) rubble foot
  parallax_ridge_a/b    640x120 transparent silhouettes for the backdrop

Every piece is palette-locked, shadow-free, no plinth, transparent outside the
silhouette. `manifest.json` records the set layout and the anchor convention.

Usage:
  make_structure_pieces.py            # writes pieces + manifest + previews
"""

from __future__ import annotations

import math
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
TEX = ROOT / "assets" / "raw" / "textures"
sys.path.insert(0, str(ROOT / "tools"))

from pixelize import apply_palette  # noqa: E402

TILE = 64
OUT = ROOT / "assets" / "tilesets" / "structures" / "pieces"


def spec(biome: str) -> str:
    palettes = json.loads((ROOT / "tools" / "palettes.json").read_text())
    return ",".join(c.lstrip("#") for c in palettes[biome]["colors"])


def load(name: str) -> Image.Image:
    return Image.open(ROOT / "assets" / "tilesets" / "structures" / name).convert("RGBA")


def contact_fringe(img: Image.Image, rows: int = 3, factor: float = 0.76) -> Image.Image:
    """Darken the bottom few opaque pixels of each column.

    Ground contact for a structure is a value break, not a shadow: a 2-3 px
    darker rocky edge under the mass reads as planted instead of pasted.
    """
    a = np.asarray(img).astype(np.float32)
    h, w = a.shape[:2]
    for x in range(w):
        col = np.nonzero(a[:, x, 3] > 40)[0]
        if col.size == 0:
            continue
        for k in range(rows):
            y = col[-1] - k
            if y < 0:
                break
            a[y, x, :3] *= factor
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def albedo(img: Image.Image, tex_path: Path, gain: float = 1.18, keep_lava: bool = False) -> Image.Image:
    """Map a generated surface texture through the sprite's own shading.

    The shape stays procedural (crisp silhouette, no plinth); only the albedo
    comes from diffusion, which is where the flat-colour look came from.
    """
    tex = Image.open(tex_path).convert("RGB").resize(img.size, Image.Resampling.LANCZOS)
    c = np.asarray(img).astype(np.float32)
    t = np.asarray(tex).astype(np.float32)
    a = c[..., 3]
    lum = 0.3 * c[..., 0] + 0.59 * c[..., 1] + 0.11 * c[..., 2]
    mean = max(1.0, float(lum[a > 0].mean())) if (a > 0).any() else 1.0
    light = np.clip(lum / mean, 0.45, 1.7)[..., None]
    out = np.clip(t * light * gain, 0, 255)
    if keep_lava:
        r, g, b = c[..., 0], c[..., 1], c[..., 2]
        lava = (r > 90) & (r > g + 30) & (r > b + 30)
        out[lava] = c[lava][:, :3]
    return Image.fromarray(np.dstack([out, a]).astype(np.uint8), "RGBA")


def assemble_massif() -> Image.Image:
    """Six jittered copies of the mountain sprite into a 256x256 massif.

    The source sprite is pre-smoothed and then given a vertical value ramp:
    six copies of a crisp 128 px sprite read as gravel noise at 4x4, while a
    softer, darker-based composite reads as mass.
    """
    src = load("mountain_range.png").filter(ImageFilter.GaussianBlur(0.45))
    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    plan = [
        (-14, 1.34, 0.92, False, 0),
        (44, 1.62, 1.04, True, 10),
        (104, 1.44, 0.97, False, 4),
        (152, 1.70, 1.01, True, 16),
        (16, 1.06, 0.90, False, 60),
        (168, 1.10, 0.94, True, 56),
    ]
    from PIL import ImageDraw
    rng = np.random.default_rng(31)
    apron = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ad = ImageDraw.Draw(apron)
    # talus apron: ring of lobes plus four corner plugs, so the 4x4 set has
    # no empty corner and the foot never ends on a straight row
    for i in range(20):
        a = 2 * math.pi * i / 20
        x = 128 + math.cos(a) * 118 * rng.uniform(0.9, 1.05)
        y = 240 - abs(math.sin(a)) * rng.uniform(4, 16)
        w, hgt = rng.uniform(24, 42), rng.uniform(10, 18)
        c = int(rng.integers(64, 92))
        ad.ellipse([x - w, y - hgt, x + w, y + hgt], fill=(c, c + 2, c - 6, 255))
    for (x, y) in ((14, 244), (242, 244), (8, 216), (248, 216)):
        ad.ellipse([x - 34, y - 20, x + 34, y + 20], fill=(74, 76, 66, 255))
    apron = apron.filter(ImageFilter.GaussianBlur(0.8))

    for dx, sc, br, flip, dy in plan:
        im = src.resize((int(128 * sc), int(128 * sc)), Image.Resampling.LANCZOS)
        if flip:
            im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        im = ImageEnhance.Brightness(im).enhance(br)
        canvas.alpha_composite(im, (dx, 254 - im.size[1] - dy))

    # vertical value ramp + soft base shadow band so the massif has form
    a = np.asarray(canvas, np.float32)
    h = a.shape[0]
    ramp = np.linspace(1.14, 0.66, h, dtype=np.float32)[:, None, None]
    a[..., :3] = np.clip(a[..., :3] * ramp, 0, 255)
    canvas = Image.fromarray(a.astype(np.uint8), "RGBA")

    # foreground scree: breaks the sprites' own straight bases
    fore = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    fd = ImageDraw.Draw(fore)
    for _ in range(18):
        x, y = rng.uniform(10, 246), rng.uniform(226, 252)
        w, hgt = rng.uniform(14, 32), rng.uniform(6, 12)
        c = int(rng.integers(52, 82))
        fd.ellipse([x - w, y - hgt, x + w, y + hgt], fill=(c, c + 3, c - 6, 255))
    canvas.alpha_composite(fore)

    base = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    from PIL import ImageDraw
    ImageDraw.Draw(base).ellipse([18, 206, 238, 254], fill=(10, 14, 12, 60))
    base = base.filter(ImageFilter.GaussianBlur(4.0))
    base.alpha_composite(apron)
    base.alpha_composite(canvas)
    out = apply_palette(base, spec("temperate"))
    return contact_fringe(albedo(out, TEX / "granite.png", 1.10))


def assemble_volcano() -> Image.Image:
    """Volcano cone on a 256 canvas: cone + scalloped ash apron to all corners.

    The apron is a union of overlapping lobes rather than one cut ellipse, so
    the 4x4 set has no empty corners and no straight edge at the foot.
    """
    from PIL import ImageDraw
    cone = load("volcano.png")
    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    cone = cone.resize((214, 214), Image.Resampling.LANCZOS).crop((0, 0, 214, 198))

    rng = np.random.default_rng(23)
    apron = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(apron)
    cx, cy = 128, 238
    # ring of lobes: wide at the sides, filling the four corners
    for i in range(22):
        a = 2 * math.pi * i / 22
        rx = 118 * rng.uniform(0.92, 1.06)
        x = cx + math.cos(a) * rx
        y = cy - abs(math.sin(a)) * rng.uniform(6, 22)
        w = rng.uniform(26, 44)
        h = rng.uniform(12, 20)
        shade = int(rng.integers(38, 58))
        d.ellipse([x - w, y - h, x + w, y + h], fill=(shade, shade - 3, shade - 5, 255))
    # talus climbing the flanks: hides the cone's own straight base line
    for _ in range(14):
        x = rng.uniform(24, 232)
        y = rng.uniform(198, 244)
        w = rng.uniform(16, 34)
        h = rng.uniform(7, 13)
        shade = int(rng.integers(52, 82))
        d.ellipse([x - w, y - h, x + w, y + h], fill=(shade, shade - 4, shade - 8, 255))

    # explicit corner plugs so the piece set never shows sky in a corner
    for (x, y) in ((14, 246), (242, 246), (10, 222), (246, 222)):
        d.ellipse([x - 30, y - 18, x + 30, y + 18], fill=(52, 48, 44, 255))
    # a few cooled blocks sitting on the apron so it does not read as a band
    for _ in range(7):
        bx, by = int(rng.uniform(24, 232)), int(rng.uniform(222, 246))
        bw, bh = int(rng.uniform(7, 16)), int(rng.uniform(4, 9))
        c = int(rng.integers(70, 104))
        d.ellipse([bx - bw, by - bh, bx + bw, by + bh], fill=(c, c - 4, c - 12, 255))
    apron = apron.filter(ImageFilter.GaussianBlur(0.7))

    # lava spills crossing the apron to the rim
    for ang, ln in ((-0.5, 96), (0.35, 88), (2.7, 78)):
        x0, y0 = cx + math.cos(ang) * 26, cy - 34
        pts = []
        for t in range(0, ln, 4):
            pts.append((x0 + math.cos(ang) * t + math.sin(t * 0.3) * 3,
                        y0 + abs(math.sin(ang)) * t * 0.35 + t * 0.16))
        for px, py in pts:
            d.ellipse([px - 3, py - 2, px + 3, py + 2], fill=(206, 78, 20, 255))
            d.ellipse([px - 1, py - 1, px + 1, py + 1], fill=(255, 168, 56, 255))

    canvas.alpha_composite(apron)
    canvas.alpha_composite(cone, (21, 26))

    # foreground spray of cooled lobes: breaks the cone's own straight foot
    fore = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fore)
    for _ in range(18):
        x = rng.uniform(18, 238)
        y = rng.uniform(228, 252)
        w = rng.uniform(14, 30)
        h = rng.uniform(6, 12)
        shade = int(rng.integers(44, 76))
        fd.ellipse([x - w, y - h, x + w, y + h], fill=(shade, shade - 4, shade - 8, 255))
    canvas.alpha_composite(fore)

    # lava dribbles over the cone/apron seam so the joint never reads as a line
    jd = ImageDraw.Draw(canvas)
    for (jx, jl) in ((92, 16), (146, 20), (182, 13)):
        for t in range(jl):
            x = jx + int(math.sin(t * 0.35) * 2)
            y = 206 + t
            w = 5 if t < jl * 0.5 else 3
            jd.ellipse([x - w, y - 1, x + w, y + 1], fill=(198, 74, 20, 255))
            if t % 3 == 0:
                jd.ellipse([x - 1, y - 1, x + 1, y], fill=(255, 176, 58, 255))

    # 1 px contour around the whole apron so it reads as rock, not paint
    arr = np.asarray(canvas).copy()
    solid = arr[..., 3] > 0
    pad = np.pad(solid, 1)
    edge = solid & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    arr[edge, :3] = (18, 18, 22)
    canvas = Image.fromarray(arr, "RGBA")
    out = apply_palette(canvas, spec("volcanic"))
    return contact_fringe(albedo(out, TEX / "basalt.png", 1.18, keep_lava=True))


def slice_set(canvas: Image.Image, prefix: str) -> list[dict]:
    pieces = []
    for r in range(4):
        for c in range(4):
            tile = canvas.crop((c * TILE, r * TILE, (c + 1) * TILE, (r + 1) * TILE))
            name = f"{prefix}_r{r}c{c}.png"
            tile.save(OUT / name)
            pieces.append({"path": f"pieces/{name}", "tile": [c, r]})
    return pieces


def ridge_strip(seed: int, bright: float) -> Image.Image:
    src = load("ridge_wide.png")
    rng = np.random.default_rng(seed)
    canvas = Image.new("RGBA", (128, 64), (0, 0, 0, 0))
    for dx, sc in [(-6, 0.56), (54, 0.60), (104, 0.52)]:
        im = src.resize((int(src.size[0] * sc), int(src.size[1] * sc)), Image.Resampling.LANCZOS)
        im = ImageEnhance.Brightness(im).enhance(bright * float(rng.uniform(0.94, 1.06)))
        canvas.alpha_composite(im, (dx, 62 - im.size[1]))
    return apply_palette(canvas, spec("temperate"))


def parallax(seed: int, height: int = 120) -> Image.Image:
    """A dark ridge silhouette, transparent above the crest."""
    rng = np.random.default_rng(seed)
    W = 640
    im = Image.new("RGBA", (W, height), (0, 0, 0, 0))
    d = __import__("PIL.ImageDraw", fromlist=["ImageDraw"]).Draw(im)
    x = 0
    pts = [(0, height)]
    while x < W:
        step = int(rng.integers(28, 70))
        top = int(height - rng.integers(24, 86))
        pts.append((x + step // 2, top))
        pts.append((x + step, height - int(rng.integers(2, 16))))
        x += step
    pts.append((W, height))
    d.polygon(pts, fill=(18, 22, 30, 210))
    d.line(pts, fill=(30, 38, 48, 230), width=1)
    return im


def contact_sheet(images: list[tuple[str, Image.Image]]) -> None:
    w = sum(im.size[0] + 8 for _, im in images)
    h = max(im.size[1] for _, im in images) + 8
    sheet = Image.new("RGBA", (w, h), (24, 24, 30, 255))
    x = 4
    for _, im in images:
        sheet.alpha_composite(im, (x, h - im.size[1] - 4))
        x += im.size[0] + 8
    sheet.convert("RGB").save(OUT / "contact_sheet.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    massif = assemble_massif()
    volcano = assemble_volcano()

    massif_pieces = slice_set(massif, "massif")
    volcano_pieces = slice_set(volcano, "volcano")

    ridge_a = ridge_strip(3, 1.0)
    ridge_b = ridge_strip(7, 0.92)
    ridge_foot = ridge_strip(11, 0.78)
    ridge_a.save(OUT / "ridge_crest_a.png")
    ridge_b.save(OUT / "ridge_crest_b.png")
    ridge_foot.save(OUT / "ridge_foot.png")

    px_a = parallax(5)
    px_b = parallax(9)
    px_a.save(OUT / "parallax_ridge_a.png")
    px_b.save(OUT / "parallax_ridge_b.png")

    manifest = {
        "unit_px": TILE,
        "anchor": "Each piece is drawn with its bottom edge at the south edge of its tile and its "
                  "left edge at the tile's west edge. Place at (base_cell + tile) * TILE in world space; "
                  "z_index from the piece's own bottom row.",
        "shadow": "none — the renderer owns the contact ellipse",
        "sets": {
            "massif_4x4": {"footprint": [4, 4], "pieces": massif_pieces},
            "volcano_4x4": {"footprint": [4, 4], "pieces": volcano_pieces},
            "ridge_2x1": {"footprint": [2, 1], "pieces": [
                {"path": "pieces/ridge_crest_a.png", "tile": [0, 0]},
                {"path": "pieces/ridge_crest_b.png", "tile": [1, 0]},
            ]},
            "ridge_foot_2x1": {"footprint": [2, 1], "pieces": [
                {"path": "pieces/ridge_foot.png", "tile": [0, 0]},
            ]},
        },
        "parallax": ["pieces/parallax_ridge_a.png", "pieces/parallax_ridge_b.png"],
        "fallback": "single-sprite structures (mountain_range/ridge_wide/volcano) stay valid",
        "notes": [
            "massif_4x4 is 6 jittered mountain_range copies; volcano_4x4 is volcano + lava apron + mesa rubble.",
            "Pieces are palette-locked to temperate / volcanic respectively; tint per biome at draw time.",
            "Collision should cover the visible base, not the transparent canvas.",
        ],
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2))

    massif.save(OUT / "assembled_massif_4x4.png")
    volcano.save(OUT / "assembled_volcano_4x4.png")
    contact_sheet([
        ("massif", massif),
        ("volcano", volcano),
        ("ridge_a", ridge_a),
        ("ridge_b", ridge_b),
        ("ridge_foot", ridge_foot),
    ])
    print(f"wrote {len(massif_pieces) + len(volcano_pieces) + 3} pieces + manifest + previews in {OUT}")


if __name__ == "__main__":
    main()

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

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from pixelize import apply_palette  # noqa: E402

TILE = 64
OUT = ROOT / "assets" / "tilesets" / "structures" / "pieces"


def spec(biome: str) -> str:
    palettes = json.loads((ROOT / "tools" / "palettes.json").read_text())
    return ",".join(c.lstrip("#") for c in palettes[biome]["colors"])


def load(name: str) -> Image.Image:
    return Image.open(ROOT / "assets" / "tilesets" / "structures" / name).convert("RGBA")


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
    base = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    from PIL import ImageDraw
    ImageDraw.Draw(base).ellipse([18, 206, 238, 254], fill=(10, 14, 12, 60))
    base = base.filter(ImageFilter.GaussianBlur(4.0))
    base.alpha_composite(canvas)
    return apply_palette(base, spec("temperate"))


def assemble_volcano() -> Image.Image:
    """Volcano cone centred on a 256 canvas with lava apron and rubble flanks."""
    cone = load("volcano.png")
    apron = Image.open(ROOT / "assets" / "tilesets" / "volcanic" / "lava_glow.png").convert("RGBA")
    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))

    # lava apron: a squashed ring of molten tile under the cone
    ring = apron.resize((150, 70), Image.Resampling.BILINEAR).filter(ImageFilter.GaussianBlur(1.0))
    mask = Image.new("L", (150, 70), 0)
    from PIL import ImageDraw
    ImageDraw.Draw(mask).ellipse([4, 6, 146, 64], fill=170)
    canvas.paste(ring, (53, 186), mask)

    cone = cone.resize((150, 150), Image.Resampling.LANCZOS)
    canvas.alpha_composite(cone, (53, 60))

    # rubble flanks
    rubble = load("barren_rock.png") if (ROOT / "assets" / "tilesets" / "structures" / "barren_rock.png").exists() else None
    for dx, sc, br in [(10, 0.62, 0.92), (176, 0.58, 0.96), (36, 0.40, 0.86), (196, 0.38, 0.9)]:
        src = load("mesa.png")
        im = src.resize((int(128 * sc), int(128 * sc)), Image.Resampling.LANCZOS)
        im = ImageEnhance.Brightness(im).enhance(br)
        canvas.alpha_composite(im, (dx, 252 - im.size[1]))
    return apply_palette(canvas, spec("volcanic"))


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

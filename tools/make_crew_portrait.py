#!/usr/bin/env python3
"""Chief Engineer briefing portraits: raw render -> 160x240 pixel bust.

Backgrounds on these raws are magenta and the flight jacket is *also* in the
magenta family, so a global colour key would eat the uniform. Instead the
background is removed by connected-component flood from the frame edge, then
the jacket is re-toned to navy with orange patches.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "assets" / "raw" / "crew"
OUT = ROOT / "assets" / "sprites" / "crew"
W, H = 160, 240

INK = (27, 26, 23)
NAVY = (16, 24, 38)
ORANGE = (228, 87, 46)
PAPER = (232, 223, 200)
TEAL = (95, 143, 138)

SKIN = [(246, 216, 190), (236, 199, 172), (223, 180, 152), (205, 158, 130),
        (184, 134, 108), (160, 110, 88), (134, 88, 70), (110, 72, 60)]
HAIR = [(38, 30, 34), (58, 46, 50), (82, 66, 66), (104, 86, 82)]
UNIFORM = [(44, 58, 82), (58, 76, 104), (78, 98, 126)]

PALETTE = np.array([INK, NAVY, ORANGE, PAPER, TEAL,
                    *UNIFORM, *SKIN, *HAIR], np.float32)


def key_background(img: Image.Image, tol: float = 42.0) -> Image.Image:
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    h, w = a.shape[:2]
    corners = np.concatenate([a[:8, :8].reshape(-1, 3), a[:8, -8:].reshape(-1, 3),
                              a[-8:, :8].reshape(-1, 3), a[-8:, -8:].reshape(-1, 3)])
    bg = np.median(corners, axis=0)
    near = np.linalg.norm(a - bg, axis=2) < tol
    lab, n = ndimage.label(near)
    keep = np.zeros_like(near)
    for idx in np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])):
        if idx:
            keep |= lab == idx
    solid = ndimage.binary_closing(~keep, structure=np.ones((5, 5)))
    solid = ndimage.binary_fill_holes(solid)
    keep = ~solid
    rgba = np.dstack([a, np.where(keep, 0, 255)]).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def retune_uniform(img: Image.Image) -> Image.Image:
    """Magenta jacket -> navy; keep the mission patch and accents orange/teal."""
    a = np.asarray(img).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    magenta = (a[..., 3] > 0) & (r > 90) & (r > g + 28) & (b > g + 6)
    lum = (0.3 * r + 0.59 * g + 0.11 * b)
    t = np.clip(lum / 190.0, 0, 1)
    for k, (lo, hi) in enumerate(zip((18, 24, 34), (44, 62, 92))):
        a[..., k] = np.where(magenta, lo + (hi - lo) * t, a[..., k])
    # the other raws render the jacket as pale grey: bring it into the same navy
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    pale = (a[..., 3] > 0) & (mx > 120) & ((mx - mn) < 30)
    pale[: int(a.shape[0] * 0.55), :] = False
    for k, (lo, hi) in enumerate(zip((18, 24, 34), (44, 62, 92))):
        a[..., k] = np.where(pale, lo + (hi - lo) * t, a[..., k])
    a[pale & (mx > 210), :3] = (56, 74, 104)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def to_sprite(img: Image.Image) -> Image.Image:
    bbox = img.split()[-1].getbbox()
    img = img.crop(bbox)
    # head + shoulders: the raw is a half-body render, so keep the upper 68 %
    # and let the 16 px fade take the chest out of frame
    img = img.crop((0, 0, img.size[0], int(img.size[1] * 0.68)))
    # fit the bust into 160x240 keeping the head at the top
    scale = min(W / img.size[0], H / img.size[1])
    nw, nh = max(1, int(img.size[0] * scale)), max(1, int(img.size[1] * scale))
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.alpha_composite(img, ((W - nw) // 2, 0))

    # gentle prefilter then hard palette lock
    canvas = canvas.filter(ImageFilter.GaussianBlur(0.6))
    # normalise exposure: aim the 95th percentile at 212 so highlights do not
    # blow out to paper-white after the palette lock
    arr = np.asarray(canvas).astype(np.float32)
    solid = arr[..., 3] > 0
    if solid.any():
        p95 = float(np.percentile(arr[..., :3][solid], 95))
        gain = min(1.9, max(0.9, 212.0 / max(1.0, p95)))
        arr[..., :3] = np.clip(arr[..., :3] * gain, 0, 255)
    canvas = Image.fromarray(arr.astype(np.uint8), "RGBA")
    a = np.asarray(canvas).astype(np.float32)
    rgb = a[..., :3]
    d = ((rgb[:, :, None, :] - PALETTE[None, None, :, :]) ** 2).sum(-1)
    idx = d.argmin(-1)
    locked = PALETTE[idx].astype(np.uint8)
    alpha = (a[..., 3] > 110).astype(np.uint8) * 255
    # soft bottom fade: the bust must not end on a hard rectangular cut
    fade = np.clip((H - 1 - np.arange(H)) / 16.0, 0, 1)[:, None]
    alpha = (alpha * fade).astype(np.uint8)
    out = np.dstack([locked, alpha])

    # 1 px ink contour
    solid = alpha > 0
    pad = np.pad(solid, 1)
    edge = solid & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    out[edge, :3] = INK
    return Image.fromarray(out, "RGBA")



def expression_variant(base: Image.Image, mode: str) -> Image.Image:
    """Derive neutral/stern from one canonical render so the face cannot drift.

    Features are located from the skin mask rather than hard-coded rows, so a
    regenerated base does not need new pixel coordinates.
    """
    img = base.copy()
    a = np.asarray(img).astype(np.int16)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    skin = (al > 0) & (r > 120) & (r > g + 8) & (g > b)
    if not skin.any():
        return img
    ys, xs = np.nonzero(skin)
    top, bot = ys.min(), ys.max()
    left, right = xs.min(), xs.max()
    h = max(1, bot - top)
    brow_y = int(top + 0.34 * h)
    mouth_y = int(top + 0.74 * h)
    cx = (left + right) // 2

    # neutral: closed lips over the base's own open smile
    white = (al > 0) & (r > 196) & (g > 186) & (b > 176)
    white[: top + int(0.45 * h)] = False
    if white.any():
        for y, x in zip(*np.nonzero(white)):
            a[y, x, :3] = (198, 152, 132)

    if mode == "stern":
        # brows: copy the darkest band one row down, then angle the inner ends
        band = a[brow_y - 2:brow_y + 3, left:right + 1, :3]
        dark = band.mean(-1) < 120
        for yy in range(dark.shape[0]):
            for xx in range(dark.shape[1]):
                if dark[yy, xx]:
                    ty = brow_y - 2 + yy + 1
                    if ty < a.shape[0]:
                        a[ty, left + xx, :3] = (a[ty, left + xx, :3] * 0.72).astype(np.int16)
        # inner brow tips lowered for the scowl read
        for side in (-1, 1):
            for k in range(4):
                yy = brow_y - 1 + k // 2
                xx = cx + side * (6 + k)
                if 0 <= yy < a.shape[0] and 0 <= xx < a.shape[1]:
                    a[yy, xx, :3] = (78, 62, 56)
        # mouth: flat line with both corners pulled down
        for k in range(-8, 9):
            a[mouth_y, cx + k, :3] = (128, 84, 74)
        for d in (1, 2):
            a[mouth_y + d, cx - 8 - d, :3] = (128, 84, 74)
            a[mouth_y + d, cx + 8 + d, :3] = (128, 84, 74)
    elif mode == "smile":
        for k in range(-7, 8):
            a[mouth_y, cx + k, :3] = (150, 96, 88)
        for d in (1, 2):
            a[mouth_y - d, cx - 7 - d, :3] = (150, 96, 88)
            a[mouth_y - d, cx + 7 + d, :3] = (150, 96, 88)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheets = []
    # one canonical render; the other two are derived so the face cannot drift
    base = to_sprite(retune_uniform(key_background(Image.open(RAW / "raw2_neutral_4101.png"))))
    for name in ("neutral", "smile", "stern"):
        img = base if name == "neutral" else expression_variant(base, name)
        img.save(OUT / f"director_{name}.png")
        sheets.append((name, img))
        print(f"director_{name}.png {img.size}")

    # 64x64 dialogue icon from the neutral face
    face = sheets[0][1].crop((24, 8, 136, 120)).resize((64, 64), Image.Resampling.LANCZOS)
    a = np.asarray(face).astype(np.float32)
    rgb = a[..., :3]
    d = ((rgb[:, :, None, :] - PALETTE[None, None, :, :]) ** 2).sum(-1)
    locked = PALETTE[d.argmin(-1)].astype(np.uint8)
    icon = np.dstack([locked, (a[..., 3] > 110).astype(np.uint8) * 255])
    solid = icon[..., 3] > 0
    pad = np.pad(solid, 1)
    edge = solid & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    icon[edge, :3] = INK
    Image.fromarray(icon, "RGBA").save(OUT / "director_icon.png")

    # contact sheet on dark and paper
    sw = 160 * 3 + 40
    sheet = Image.new("RGBA", (sw, 240 * 2 + 60), NAVY + (255,))
    for i, (name, img) in enumerate(sheets):
        sheet.alpha_composite(img, (10 + i * 170, 10))
        sheet.alpha_composite(img, (10 + i * 170, 290))
    paper = Image.new("RGBA", (sw, 240 + 20), PAPER + (255,))
    for i, (name, img) in enumerate(sheets):
        paper.alpha_composite(img, (10 + i * 170, 10))
    combo = Image.new("RGBA", (sw, 240 * 2 + 300), PAPER + (255,))
    combo.alpha_composite(sheet, (0, 0))
    combo.alpha_composite(paper, (0, 260))
    combo.save("/tmp/opencode/crew_sheet.png")

    manifest = {
        "character": "Dr. Imani Vale — executive secretary, Mission Control briefing",
        "files": {n: f"res://assets/sprites/crew/director_{n}.png" for n in ("neutral", "smile", "stern")},
        "icon": "res://assets/sprites/crew/director_icon.png",
        "size": [160, 240],
        "expressions": ["neutral", "smile", "stern"],
        "palette": {"ink": "#1b1a17", "navy": "#101826", "orange": "#e4572e",
                    "paper": "#e8dfc8", "teal": "#5f8f8a",
                    "skin": ["#eec8ac", "#d6a888", "#b07e64", "#845846"],
                    "hair": ["#2e2628", "#463a3a", "#625450"]},
        "generation": {
            "workflow": "tools/gen_asset.py (SDXL base 1.0 + pixel-art-xl 0.45), --no-pixelize",
            "seed": 4101, "gen_size": [768, 1152], "samples": 24, "cfg": 7.0,
            "prompt_face": "female space agency executive secretary, age 30, shoulder-length dark hair tied back, light grey uniform jacket with navy trim, ID badge and headset, three-quarter view",
            "expression_prompts": {"neutral": "serious competent expression", "smile": "gentle confident smile", "stern": "stern serious frown, concerned"},
            "raws": "assets/raw/crew/raw2_neutral_4101.png (canonical); raw2_{smile,stern}_4101.png are unused drift samples",
        },
        "postprocess": "edge flood-fill key (magenta bg also sits in the jacket), magenta->navy uniform retune, blur 0.6, palette lock, hard alpha at 110, 1 px ink contour",
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("wrote manifest + icon")


if __name__ == "__main__":
    main()

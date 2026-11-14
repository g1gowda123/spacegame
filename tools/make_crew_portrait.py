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

SKIN = [(238, 200, 172), (214, 168, 136), (176, 126, 100), (132, 88, 70)]
HAIR = [(46, 38, 40), (70, 58, 58), (98, 84, 80)]
WHITE = (246, 242, 232)

PALETTE = np.array([INK, NAVY, ORANGE, PAPER, TEAL, WHITE, *SKIN, *HAIR], np.float32)


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
    # fit the bust into 160x240 keeping the head at the top
    scale = min(W / img.size[0], H / img.size[1])
    nw, nh = max(1, int(img.size[0] * scale)), max(1, int(img.size[1] * scale))
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.alpha_composite(img, ((W - nw) // 2, 0))

    # gentle prefilter then hard palette lock
    canvas = canvas.filter(ImageFilter.GaussianBlur(0.6))
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
    """Derive neutral/stern from the smile frame so the face cannot drift."""
    img = base.copy()
    a = np.asarray(img).astype(np.int16)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    white = (al > 0) & (r > 196) & (g > 186) & (b > 176)
    white[:70] = False
    white[150:] = False
    ys, xs = np.nonzero(white)
    if xs.size:
        cx, cy = int(xs.mean()), int(ys.mean())
        # open smile -> closed mouth: teeth become lip, one thin line kept
        for y, x in zip(ys, xs):
            a[y, x, :3] = (198, 152, 132)
        line_y = int(ys.max()) - 1
        for x in range(int(xs.min()) - 1, int(xs.max()) + 2):
            a[line_y, x, :3] = (120, 74, 66)
        if mode == "stern":
            # flat, downturned mouth and a heavier brow shadow
            for x in range(int(xs.min()) - 3, int(xs.max()) + 4):
                a[line_y - 1, x, :3] = (110, 66, 60)
            for x in (int(xs.min()) - 3, int(xs.min()) - 2, int(xs.max()) + 2, int(xs.max()) + 3):
                a[line_y + 1, x, :3] = (110, 66, 60)
            brow = a[cy - 46:cy - 36, max(0, cx - 34):cx + 34, :3]
            a[cy - 46:cy - 36, max(0, cx - 34):cx + 34, :3] = (brow * 0.82).astype(np.int16)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheets = []
    # one canonical render; the other two are derived so the face cannot drift
    base = to_sprite(retune_uniform(key_background(Image.open(RAW / "raw_smile_4001.png"))))
    for name in ("neutral", "smile", "stern"):
        img = base if name == "smile" else expression_variant(base, name)
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
        "character": "Chief Engineer's deputy director (mission control briefing)",
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
            "seed": 4001, "gen_size": [768, 1152], "samples": 24, "cfg": 7.0,
            "prompt_face": "female space agency deputy director, age 40, short practical dark hair, professional flight jacket with mission patch and headset, three-quarter view",
            "expression_prompts": {"neutral": "serious competent expression", "smile": "gentle confident smile", "stern": "stern serious frown, concerned"},
            "raws": "assets/raw/crew/raw_<expression>_4001.png",
        },
        "postprocess": "edge flood-fill key (magenta bg also sits in the jacket), magenta->navy uniform retune, blur 0.6, palette lock, hard alpha at 110, 1 px ink contour",
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("wrote manifest + icon")


if __name__ == "__main__":
    main()

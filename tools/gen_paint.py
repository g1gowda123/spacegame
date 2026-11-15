#!/usr/bin/env python3
"""Whimsical painted cosmic plates — one palette per scene, never one hue.

The first pass pinned "indigo and violet with warm ember" into the shared style
suffix, so every plate came back the same purple. Here the palette belongs to
the *scene*: each entry names its own colours, and the shared style is only about
medium and mood (storybook gouache, visible brush, playful shapes).
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "backgrounds" / "painted"
RAW = ROOT / "assets" / "raw" / "painted"
PY = "/home/g1/ComfyUI/.venv/bin/python"

STYLE = ("whimsical children's storybook illustration, gouache on textured paper, visible brush strokes, "
         "playful rounded shapes, limited flat colour blocks with a single accent hue, soft chalky edges, "
         "charming hand-painted look, slightly naive, no text, no letters")

NEG = ("text, letters, words, watermark, signature, frame, border, ui, interface, hud, photo, "
       "photorealistic, anime character, person, face, logo, purple gradient, violet glow, magenta haze, "
       "neon, glossy 3d render, airbrush, smooth digital gradient, generic ai art, oversaturated, "
       "ground, terrain, landscape, trees, plants, mountains, silhouette, figure, horizon")

SCENES = {
    "dispatch": ("a small teal spacecraft leaving a rose-gold planet, a long mint comet trail",
                 "palette: mint green, rose gold, warm cream, slate teal"),
    "nebula": ("a towering wall of nebula clouds parting around a distant star",
               "palette: sea green, coral pink, butter yellow, deep petrol blue"),
    "blackhole": ("a black hole ringed by a thin swirling accretion ring, stars bending around it",
                  "palette: pale gold, sky blue, ivory white, ink navy"),
    "sunrise": ("a blazing star cresting a bank of dark cosmic dust clouds, beams through the gap",
                "palette: marigold, peach, dusty lilac, charcoal plum"),
    "moon": ("a pale moon in a deep cloud sea, one slow meteor crossing the sky",
             "palette: pale blue-white, slate blue, soft coral, near-black teal"),
    "star": ("a single four-pointed star burning in a wide nebula field",
             "palette: peach, sage green, cream, midnight plum"),
    "galaxy": ("a spiral galaxy seen at an angle, its arms lit in white and ember, dust lanes dark against it",
               "palette: dusty rose, clotted cream, warm grey, midnight blue"),
    "ember": ("a rust-red gas giant with soft banded clouds and a faint dust ring",
              "palette: burnt sienna, lime green, pale sand, charcoal"),
}


def render(prompt, palette, out, seed):
    subprocess.run([PY, str(ROOT / "tools" / "gen_asset.py"),
                    prompt + ", " + palette + ", " + STYLE,
                    "--out", str(out), "--gen-width", "1344", "--gen-height", "768",
                    "--seed", str(seed), "--steps", "34", "--cfg", "6.0",
                    "--lora", "0", "--no-pixelize", "--negative-extra", NEG],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def finish(raw, out, w=640, h=360):
    img = Image.open(raw).convert("RGB")
    tw, th = 16, 9
    if img.width * th > img.height * tw:
        nw = int(img.height * tw / th)
        img = img.crop(((img.width - nw) // 2, 0, (img.width + nw) // 2, img.height))
    else:
        nh = int(img.width * th / tw)
        img = img.crop((0, (img.height - nh) // 2, img.width, (img.height + nh) // 2))
    img = img.resize((w * 2, h * 2), Image.Resampling.LANCZOS)
    img = img.filter(ImageFilter.UnsharpMask(radius=3, percent=55, threshold=2))
    img = img.resize((w, h), Image.Resampling.LANCZOS)

    # paper texture: a light 8-bit ordered dither over the grain keeps gouache
    # from looking like a smooth render at this size
    arr = np.asarray(img).astype(np.float32)
    rng = np.random.default_rng(11)
    arr += rng.normal(0, 1.6, arr.shape[:2])[..., None]
    arr = np.round(arr / 4.0) * 4.0
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(out)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    RAW.mkdir(parents=True, exist_ok=True)
    names = sys.argv[1:] or list(SCENES)
    for i, name in enumerate(names):
        prompt, palette = SCENES[name]
        raw = RAW / f"{name}.png"
        if not raw.exists() or "--force" in sys.argv:
            render(prompt, palette, raw, 6600 + i)
        finish(raw, OUT / f"{name}.png")
        print("ok", name, flush=True)


if __name__ == "__main__":
    main()

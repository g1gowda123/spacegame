#!/usr/bin/env python3
"""Painterly cosmic plates — a separate visual language from the pixel art.

The dispatch card and a few story beats want soft painted space, not 64 px
tiles, so this path deliberately skips the pixel pipeline: SDXL at 1344x768
with no pixel-art LoRA, then a photo-style downsample to the 640x360 view with a
light unsharp pass and film grain. Grain matters: a smooth gradient at 640 px
bands visibly on a 640-wide canvas, the noise dithers it.
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

STYLE = ("digital painting, soft cosmic atmosphere, deep indigo and violet nebulae with warm ember highlights, "
         "loose expressive brushwork, painterly edges, gentle rim light, cinematic wide composition, "
         "children's storybook illustration, no text, no letters")

NEG = ("text, letters, words, watermark, signature, frame, border, ui, interface, hud, photo, "
       "photorealistic, anime character, person, face, logo")

SCENES = {
    "dispatch": "a small spacecraft leaving a ringed planet, long comet trail, vast nebula behind it",
    "nebula": "a towering wall of nebula clouds parting around a distant star, dust lit from within",
    "blackhole": "a black hole ringed by swirling blue and violet accretion light, stars bending around it",
    "sunrise": "a blazing sun cresting a bank of dark storm clouds, beams of light through the gap",
    "moon": "a pale moon in a deep blue cloud sea, one slow meteor crossing the sky",
    "star": "a single four-pointed star burning in a wide violet nebula field",
    "galaxy": "a spiral galaxy seen at an angle, its arms lit in white and ember, dust lanes dark against it",
    "ember": "a rust-red gas giant with soft banded clouds, ringed by faint dust",
}


def render(prompt, out, seed):
    subprocess.run([PY, str(ROOT / "tools" / "gen_asset.py"),
                    prompt + ", " + STYLE,
                    "--out", str(out), "--gen-width", "1344", "--gen-height", "768",
                    "--seed", str(seed), "--steps", "34", "--cfg", "6.5",
                    "--lora", "0", "--no-pixelize", "--negative-extra", NEG],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def finish(raw, out, w=640, h=360):
    img = Image.open(raw).convert("RGB")
    # crop to 16:9 around the centre, then a soft step down
    tw, th = 16, 9
    if img.width * th > img.height * tw:
        nw = int(img.height * tw / th)
        img = img.crop(((img.width - nw) // 2, 0, (img.width + nw) // 2, img.height))
    else:
        nh = int(img.width * th / tw)
        img = img.crop((0, (img.height - nh) // 2, img.width, (img.height + nh) // 2))
    img = img.resize((w * 2, h * 2), Image.Resampling.LANCZOS)
    img = img.filter(ImageFilter.UnsharpMask(radius=3, percent=60, threshold=2))
    img = img.resize((w, h), Image.Resampling.LANCZOS)
    arr = np.asarray(img).astype(np.float32)
    rng = np.random.default_rng(7)
    arr += rng.normal(0, 1.1, arr.shape[:2])[..., None]
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    img.save(out)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    RAW.mkdir(parents=True, exist_ok=True)
    names = sys.argv[1:] or list(SCENES)
    for i, name in enumerate(names):
        raw = RAW / f"{name}.png"
        if not raw.exists():
            render(SCENES[name], raw, 6100 + i)
        finish(raw, OUT / f"{name}.png")
        print("ok", name, flush=True)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Painterly cosmic plates for the big moments (title, debrief, transition).

Different art language from the tiles: these are soft painted vistas, not pixel
sprites. SDXL renders a 1024x576 scene, which is then brought down to the 640x360
view with a light prefilter and a low-strength ordered dither so the sky keeps
its gradients instead of banding when the GL canvas scales it.
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "assets" / "raw" / "cosmic"
OUT = ROOT / "assets" / "backgrounds" / "cosmic"
GEN = ROOT / "tools" / "gen_asset.py"
PY = "/home/g1/ComfyUI/.venv/bin/python"

STYLE = ("digital painting, soft oil brush strokes, deep space vista, luminous rim light, "
         "rich navy violet and ember palette, painterly clouds of gas, no text, no letters, "
         "no frame, no border, wide cinematic composition")
NEG = ("text, letters, watermark, logo, frame, border, collage, panels, comic, ui, hud, "
       "earth city, buildings, people, spacecraft, lens flare dots")

SCENES = {
    "nebula": "vast nebula in deep violet and ember red, drifting gas clouds lit from within",
    "limb": "planet limb seen from orbit, turquoise oceans and white cloud bands curving under a thin atmosphere glow, a bright comet streak above",
    "eclipse": "total eclipse, black disc ringed by a blazing corona inside a swirling blue nebula",
    "sun": "boiling orange star filling half the frame, red prominences and a crown of glowing plasma",
    "moon": "small pale moon in a dark blue nebula sea, one thin comet trail crossing above it",
    "starcross": "single brilliant star with four long rays in a dark indigo sky, faint gas drifting past",
    "galaxy": "spiral galaxy tilted in a violet sky, pale core and dark dust lanes",
    "gasgiant": "banded rust orange gas giant in a maroon nebula, soft terminator shadow",
}


def gen(prompt, out, seed):
    cmd = [PY, str(GEN), f"{prompt}, {STYLE}", "--out", str(out), "--size", "1024",
           "--gen-size", "1024", "--seed", str(seed), "--lora", "0.0", "--no-pixelize",
           "--negative-extra", NEG, "--view", "wide cinematic landscape, 16:9"]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def plate(raw_path, w=640, h=360):
    img = Image.open(raw_path).convert("RGB")
    # centre-crop to 16:9 before the big downscale
    tw, th = 16, 9
    s = max(tw / img.width, th / img.height)
    img = img.resize((round(img.width * s), round(img.height * s)), Image.Resampling.LANCZOS)
    left = (img.width - tw * 96) // 2 if img.width >= tw * 96 else 0
    img = img.crop((left, (img.height - th * 96) // 2, left + tw * 96, (img.height + th * 96) // 2))
    img = img.filter(ImageFilter.GaussianBlur(0.6)).resize((w, h), Image.Resampling.LANCZOS)
    a = np.asarray(img).astype(np.int16)
    # ordered 4x4 dither, +-3 levels: enough to break sky banding, invisible at 1x
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) - 7.5
    d = np.tile(bayer, (h // 4 + 1, w // 4 + 1))[:h, :w][..., None]
    a = np.clip(a + d * 0.9, 0, 255).astype(np.uint8)
    return Image.fromarray(a)


def main():
    RAW.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    only = sys.argv[1:] or list(SCENES)
    for i, key in enumerate(only):
        raw = RAW / f"{key}.png"
        if not raw.exists():
            gen(SCENES[key], raw, 7100 + i)
        plate(raw).save(OUT / f"{key}.png")
        print("ok", key, flush=True)
    print(f"{len(only)} cosmic plates")


if __name__ == "__main__":
    main()

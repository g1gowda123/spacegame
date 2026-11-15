#!/usr/bin/env python3
"""Dr. Imani Vale — retro pixel-art portrait, 160x160, three expressions.

Style goes through the same door as every other sprite in the game: SDXL Base 1.0
with the Pixel Art XL LoRA at 1.0, chunky flat shading, thick dark outline, limited
palette (see `docs/ART_PIPELINE.md`). The render is 960x960 so the 6x nearest
downscale to 160 lands on a clean pixel grid, then the whole crew set is locked to
one sampled 20-colour palette so the three moods share skin and uniform tones.

Run: python tools/gen_portrait.py [--only neutral,smile,stern] [--seed 4821]
Out: assets/sprites/crew/director_{neutral,smile,stern}.png, director_icon.png
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_asset import LORA, generate  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "crew"
RAW = ROOT / "assets" / "raw" / "crew"
PALETTES = ROOT / "tools" / "palettes.json"

SUBJECT = (
    "portrait bust of a woman in her early forties, chief engineer of a deep space survey agency, "
    "warm brown skin, dark brown hair pulled back, calm attentive expression, navy utility uniform "
    "with a stand collar, thin orange rank tab, simple embroidered agency patch with an orbital "
    "emblem, slim black headset with a boom microphone"
)
STYLE = (
    "chunky flat-shaded shapes, thick dark outline, limited desaturated palette, teal and orange "
    "accents, retro science fiction pixel art, flat solid dark navy background, centered, no text"
)
NEG = (
    "blurry, photo, photorealistic, 3d render, smooth gradients, anti-aliasing, text, watermark, "
    "signature, frame, border, logo, american flag, national flag, flag patch, multiple people, "
    "hands, scenery, open mouth, teeth, exaggerated expression"
)
MOODS = {
    "neutral": "neutral professional expression, level gaze",
    "smile": "warm closed mouth smile, relaxed brow",
    "stern": "stern serious expression, brow lowered, mouth firm",
}
SIZE = 160
GEN = 960  # 6x SIZE, so the nearest downscale is exact
PALETTE_SIZE = 20


def graph(prompt: str, seed: int) -> dict:
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}},
        "2": {"class_type": "LoraLoader", "inputs": {
            "model": ["1", 0], "clip": ["1", 1], "lora_name": LORA,
            "strength_model": 1.0, "strength_clip": 1.0}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["2", 1]}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"text": NEG, "clip": ["2", 1]}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": GEN, "height": GEN, "batch_size": 1}},
        "6": {"class_type": "KSampler", "inputs": {
            "model": ["2", 0], "positive": ["3", 0], "negative": ["4", 0], "latent_image": ["5", 0],
            "seed": seed, "steps": 32, "cfg": 6.5, "sampler_name": "dpmpp_2m",
            "scheduler": "karras", "denoise": 1.0}},
        "7": {"class_type": "VAEDecode", "inputs": {"samples": ["6", 0], "vae": ["1", 2]}},
        "8": {"class_type": "SaveImage", "inputs": {"images": ["7", 0], "filename_prefix": "portrait"}},
    }


def pixelate(img: Image.Image) -> Image.Image:
    """Square crop, then 6x nearest downscale so edges stay on the pixel grid."""
    w, h = img.size
    side = int(h * 0.72)
    left = max(0, w // 2 - side // 2)
    top = int(h * 0.03)
    img = img.crop((left, top, left + side, top + side)).resize((SIZE, SIZE), Image.Resampling.NEAREST)
    return img.convert("RGB")


def sample_palette(img: Image.Image, n: int = PALETTE_SIZE) -> list:
    q = img.quantize(n, method=Image.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    return [c for _, c in q.getcolors()]


def save_palette(colors: list) -> None:
    data = json.loads(PALETTES.read_text())
    data["crew"] = {"colors": ["#%02x%02x%02x" % c for c in colors], "note": "sampled from the director portrait"}
    PALETTES.write_text(json.dumps(data, indent=2) + "\n")


def lock(img: Image.Image, colors: list) -> Image.Image:
    pal = Image.new("P", (1, 1))
    flat = []
    for c in colors:
        flat += list(c)
    flat += [0, 0, 0] * (256 - len(colors))
    pal.putpalette(flat)
    return img.quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--seed", type=int, default=4821)
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    RAW.mkdir(parents=True, exist_ok=True)
    ids = [m for m in MOODS if not args.only or m in args.only.split(",")]
    palette_file = RAW / "palette.json"
    colors = json.loads(palette_file.read_text()) if palette_file.exists() else None
    for mood in ids:
        prompt = f"{SUBJECT}, {STYLE}, {MOODS[mood]}"
        raw = generate(graph(prompt, args.seed), timeout_s=1200)
        img = pixelate(Image.open(raw))
        if colors is None:
            colors = sample_palette(img)
            palette_file.write_text(json.dumps(colors))
            save_palette(colors)
        img = lock(img, colors)
        img.save(OUT / f"director_{mood}.png")
        if mood == "neutral":
            img.resize((64, 64), Image.Resampling.NEAREST).save(OUT / "director_icon.png")
        print("ok", mood, raw)


if __name__ == "__main__":
    main()

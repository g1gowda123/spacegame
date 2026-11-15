#!/usr/bin/env python3
"""Dr. Imani Vale — realistic-painterly portrait, 160x240, three expressions.

The flat pixel portrait read as a cartoon next to the painted backdrops, so this
renders the character instead: SDXL text2img for the neutral bust, then low
denoise img2img for the smile and stern variants so the face stays the same
person. Output is keyed off a flat background, cropped to a bust, and reduced to
a tight palette so it survives the 146x146 briefing card.

Run: python tools/gen_portrait.py [--only neutral]
Out: assets/sprites/crew/director_{neutral,smile,stern}.png, director_icon.png
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_asset import generate, post_json  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "crew"
RAW = ROOT / "assets" / "raw" / "crew"

PORTRAIT = (
    "painterly digital portrait of a woman in her early forties, chief engineer of a deep-space "
    "survey agency, dark brown hair pulled back with a few loose strands, warm brown skin, "
    "calm attentive expression, subtle smile lines, wearing a navy blue utility uniform with a "
    "stand collar, a thin orange rank tab, and a slim black headset with a boom microphone, "
    "bust framed from the chest up, centered, facing slightly left of camera, soft key light "
    "from the left, cool rim light on the right, muted palette, flat dark navy background, "
    "no text, no border, single figure"
)
NEG = (
    "cartoon, anime, vector, flat colours, cell shaded, chibi, doll-like, overly smooth skin, "
    "text, watermark, signature, frame, border, logo, multiple people, crowd, scenery, landscape, "
    "planet, spaceship, hands, open mouth, teeth, exaggerated expression, glossy plastic"
)


def expression_prompt(mood: str) -> str:
    return f"{PORTRAIT}, {mood}"


MOODS = {
    "neutral": "neutral professional expression, level gaze",
    "smile": "warm closed-mouth smile, eyes slightly narrowed, relaxed brow",
    "stern": "stern serious expression, brow lowered, mouth firm",
}


def wf_text(seed: int, prompt: str) -> dict:
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}},
        "2": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["1", 1]}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"text": NEG, "clip": ["1", 1]}},
        "4": {"class_type": "EmptyLatentImage", "inputs": {"width": 832, "height": 1216, "batch_size": 1}},
        "5": {"class_type": "KSampler", "inputs": {
            "model": ["1", 0], "positive": ["2", 0], "negative": ["3", 0], "latent_image": ["4", 0],
            "seed": seed, "steps": 32, "cfg": 6.5, "sampler_name": "dpmpp_2m",
            "scheduler": "karras", "denoise": 1.0}},
        "6": {"class_type": "VAEDecode", "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
        "7": {"class_type": "SaveImage", "inputs": {"images": ["6", 0], "filename_prefix": "portrait"}},
    }


def wf_img2img(image_name: str, seed: int, prompt: str, denoise: float) -> dict:
    wf = wf_text(seed, prompt)
    wf["4"] = {"class_type": "LoadImage", "inputs": {"image": image_name}}
    wf["4b"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["4", 0], "vae": ["1", 2]}}
    wf["5"]["inputs"]["latent_image"] = ["4b", 0]
    wf["5"]["inputs"]["denoise"] = denoise
    return wf


def key(img: Image.Image) -> Image.Image:
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    pad = 10
    ring = np.concatenate([a[:pad, :pad].reshape(-1, 3), a[:pad, -pad:].reshape(-1, 3),
                           a[-pad:, :pad].reshape(-1, 3), a[-pad:, -pad:].reshape(-1, 3)])
    bg = np.median(ring, axis=0)
    dist = np.linalg.norm(a - bg, axis=2)
    alpha = np.clip((dist - 16) / 26.0, 0, 1)
    alpha = (alpha * 255).astype(np.uint8)
    out = Image.fromarray(a.astype(np.uint8)).convert("RGBA")
    out.putalpha(Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(0.8)))
    return out


def finish(img: Image.Image) -> Image.Image:
    bb = img.split()[-1].getbbox()
    if bb:
        img = img.crop(bb)
    # bust framing: keep the chest, crop tight to the card's 146x146 window
    w, h = img.size
    side = int(min(w, h * 1.05))
    img = img.crop(((w - side) // 2, 0, (w + side) // 2, side))
    img = img.resize((160, 240), Image.Resampling.LANCZOS)
    img = img.filter(ImageFilter.UnsharpMask(radius=1.4, percent=90, threshold=3))
    img = ImageEnhance.Contrast(img).enhance(1.06)
    rgb = img.convert("RGB").quantize(40, method=Image.MEDIANCUT).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(img.getchannel("A"))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    RAW.mkdir(parents=True, exist_ok=True)
    ids = [m for m in MOODS if not args.only or m in args.only.split(",")]
    base_name = "portrait_base.png"
    for mood in ids:
        if mood == "neutral":
            raw = generate(wf_text(4821, expression_prompt(MOODS[mood])), timeout_s=900)
        else:
            # reuse the neutral render as the identity anchor
            src = RAW / base_name
            if not src.exists():
                raise SystemExit("run neutral first")
            import shutil
            shutil.copy(src, Path("/home/g1/ComfyUI/input") / "portrait_anchor.png")
            raw = generate(wf_img2img("portrait_anchor.png", 4821, expression_prompt(MOODS[mood]), 0.32),
                           timeout_s=900)
        if mood == "neutral":
            import shutil
            shutil.copy(raw, RAW / base_name)
        img = finish(key(Image.open(raw)))
        img.save(OUT / f"director_{mood}.png")
        if mood == "neutral":
            img.resize((64, 96), Image.Resampling.LANCZOS).save(OUT / "director_icon.png")
        print("ok", mood, raw)


if __name__ == "__main__":
    main()

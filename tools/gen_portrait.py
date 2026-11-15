#!/usr/bin/env python3
"""Dr. Imani Vale — realistic portrait workflow, three expressions, 160x240.

No procedural drawing: this is the SDXL graph in `tools/workflows/portrait_bust.json`
(832x1216 base, nearest-exact 1.35x upscale, 0.42 denoise detail pass) edited into
the briefing card. The neutral render is the identity anchor; smile and stern are
img2img passes on it at low denoise so it stays the same person.

Run: python tools/gen_portrait.py [--only neutral|smile|stern] [--denoise 0.30]
Out: assets/sprites/crew/director_{neutral,smile,stern}.png, director_icon.png
     raws in assets/raw/crew/
"""
import argparse
import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_asset import generate  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "crew"
RAW = ROOT / "assets" / "raw" / "crew"
WF = ROOT / "tools" / "workflows" / "portrait_bust.json"
COMFY_IN = Path("/home/g1/ComfyUI/input")

BUST = (
    "realistic painterly science fiction character portrait, bust framing from the chest up, "
    "a woman in her early forties, chief engineer of a deep space survey agency, warm brown skin, "
    "dark brown hair pulled back with a few loose strands at the temples, calm attentive expression, "
    "faint smile lines, level gaze, wearing a navy blue utility uniform with a stand collar and a "
    "thin burnt orange rank tab, a simple embroidered agency patch with an orbital emblem on the "
    "chest, slim black headset with a short boom microphone, soft key light from the left, cool teal "
    "rim light on the right shoulder, muted nineteen seventies palette of navy cream orange and teal, "
    "flat dark navy background, single figure, no text, no border, screen printed illustration "
    "texture with subtle halftone grain, not a glossy photograph"
)
NEG = (
    "cartoon, anime, vector, flat colours, cell shaded, chibi, doll, plastic skin, airbrushed, "
    "american flag, national flag, flag patch, logo, text, watermark, signature, frame, border, "
    "multiple people, crowd, hands, scenery, landscape, planet, spaceship, open mouth, teeth, "
    "exaggerated expression, glossy highlight"
)
MOODS = {
    "neutral": "neutral professional expression, level gaze",
    "smile": "warm closed mouth smile, eyes slightly narrowed, relaxed brow",
    "stern": "stern serious expression, brow lowered, mouth firm",
}


def graph() -> dict:
    return json.loads(WF.read_text())


def text2img(prompt: str, seed: int) -> dict:
    wf = graph()
    wf["2"]["inputs"]["text"] = prompt
    wf["3"]["inputs"]["text"] = NEG
    wf["5"]["inputs"]["seed"] = seed
    wf["8"]["inputs"]["seed"] = seed
    return wf


def img2img(image_name: str, prompt: str, seed: int, denoise: float) -> dict:
    wf = graph()
    wf["2"]["inputs"]["text"] = prompt
    wf["3"]["inputs"]["text"] = NEG
    wf["4"] = {"class_type": "LoadImage", "inputs": {"image": image_name}}
    wf["4b"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["4", 0], "vae": ["1", 2]}}
    wf["5"]["inputs"]["latent_image"] = ["4b", 0]
    wf["5"]["inputs"]["denoise"] = denoise
    wf["5"]["inputs"]["seed"] = seed
    wf["8"]["inputs"]["seed"] = seed
    return wf


def key(img: Image.Image) -> Image.Image:
    """Soft key on the flat background: distance from the border median."""
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    pad = 12
    ring = np.concatenate([a[:pad, :pad].reshape(-1, 3), a[:pad, -pad:].reshape(-1, 3),
                           a[-pad:, :pad].reshape(-1, 3), a[-pad:, -pad:].reshape(-1, 3)])
    bg = np.median(ring, axis=0)
    dist = np.linalg.norm(a - bg, axis=2)
    alpha = np.clip((dist - 18) / 30.0, 0, 1)
    out = Image.fromarray(a.astype(np.uint8)).convert("RGBA")
    out.putalpha(Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0)))
    return out


def card(img: Image.Image) -> Image.Image:
    """Crop to the 160x240 card: head and shoulders, eyes on the upper third."""
    bb = img.split()[-1].getbbox()
    if bb:
        img = img.crop(bb)
    w, h = img.size
    side = int(min(w, h * 0.667))
    left = (w - side) // 2
    top = max(0, int(h * 0.02))
    img = img.crop((left, top, left + side, top + int(side * 1.5)))
    img = img.resize((160, 240), Image.Resampling.LANCZOS)
    img = img.filter(ImageFilter.UnsharpMask(radius=1.2, percent=80, threshold=3))
    img = ImageEnhance.Contrast(img).enhance(1.04)
    rgb = img.convert("RGB").quantize(56, method=Image.MEDIANCUT).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(img.getchannel("A"))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--denoise", type=float, default=0.30)
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    RAW.mkdir(parents=True, exist_ok=True)
    anchor = RAW / "portrait_anchor.png"
    ids = [m for m in MOODS if not args.only or m in args.only.split(",")]
    for mood in ids:
        prompt = f"{BUST}, {MOODS[mood]}"
        if mood == "neutral":
            raw = generate(text2img(prompt, 4821), timeout_s=1200)
            shutil.copy(raw, anchor)
        else:
            if not anchor.exists():
                raise SystemExit("generate neutral first (identity anchor)")
            shutil.copy(anchor, COMFY_IN / "portrait_anchor.png")
            raw = generate(img2img("portrait_anchor.png", prompt, 4821, args.denoise), timeout_s=1200)
        img = card(key(Image.open(raw)))
        img.save(OUT / f"director_{mood}.png")
        if mood == "neutral":
            img.resize((64, 96), Image.Resampling.LANCZOS).save(OUT / "director_icon.png")
        print("ok", mood, raw)


if __name__ == "__main__":
    main()

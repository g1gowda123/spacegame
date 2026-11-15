#!/usr/bin/env python3
"""Hull heroes by img2img: keep the authored silhouette, add real detail.

The 190x70 sheets are the approved silhouettes, so this starts from a 4x
upscale of each one and runs a low-denoise img2img pass on a magenta card,
which adds panel detail and surface material without re-inventing the ship.
The result is keyed, cleaned and re-fit to 380x140.
"""
import argparse
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_asset import generate, post_json  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "sprites" / "ships"
OUT = SRC / "hero"
COMFY_IN = Path("/home/g1/ComfyUI/input")

IDS = ["pathfinder", "cryo", "relay", "hopper"]
LOOK = {
    "pathfinder": "pale turquoise survey vessel, teal and cyan hull",
    "cryo": "ice-white insulated hauler, pale blue and steel hull",
    "relay": "orange and amber relay ship, rust and copper hull",
    "hopper": "mauve and violet short-range shuttle, plum hull",
}
NEG = ("blurry, low resolution, text, watermark, multiple ships, cropped, frame, "
       "border, background scenery, planet, stars, ground, shadow, three-quarter view, "
       "perspective, tilted, top view, front view, cartoon face, eyes")


def workflow(image_name: str, prompt: str, seed: int, denoise: float) -> dict:
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}},
        "2": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["1", 1]}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"text": NEG, "clip": ["1", 1]}},
        "4": {"class_type": "LoadImage", "inputs": {"image": image_name}},
        "5": {"class_type": "VAEEncode", "inputs": {"pixels": ["4", 0], "vae": ["1", 2]}},
        "6": {"class_type": "KSampler", "inputs": {
            "model": ["1", 0], "positive": ["2", 0], "negative": ["3", 0],
            "latent_image": ["5", 0], "seed": seed, "steps": 30, "cfg": 6.0,
            "sampler_name": "dpmpp_2m", "scheduler": "karras", "denoise": denoise}},
        "7": {"class_type": "VAEDecode", "inputs": {"samples": ["6", 0], "vae": ["1", 2]}},
        "8": {"class_type": "SaveImage", "inputs": {"images": ["7", 0], "filename_prefix": "hero"}},
    }


def prep_input(ship: Path, dest_name: str) -> None:
    im = Image.open(ship).convert("RGBA")
    im = im.resize((768, 288), Image.Resampling.LANCZOS)
    card = Image.new("RGB", im.size, (255, 0, 255))
    card.paste(im, (0, 0), im)
    COMFY_IN.mkdir(parents=True, exist_ok=True)
    card.save(COMFY_IN / dest_name)


def key(img: Image.Image) -> Image.Image:
    a = np.asarray(img.convert("RGB")).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    magenta = (r > 70) & (b > 70) & (g < 0.74 * np.minimum(r, b))
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    med = np.median(border, axis=0)
    near = np.abs(a - med).sum(axis=2) < 90
    bg = magenta | near
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    soft = Image.fromarray(alpha).filter(ImageFilter.MedianFilter(3))
    rgb = Image.fromarray(a.astype(np.uint8))
    out = rgb.convert("RGBA")
    out.putalpha(soft)
    return out


def finish(img: Image.Image, ship: Image.Image) -> Image.Image:
    bb = img.getbbox()
    if bb:
        img = img.crop(bb)
    pad = Image.new("RGBA", (img.width + 8, img.height + 8), (0, 0, 0, 0))
    pad.paste(img, (4, 4), img)
    img = pad.resize((380, 140), Image.Resampling.LANCZOS)
    a = np.asarray(img).astype(np.float32)
    a[..., 3] = np.where(a[..., 3] > 150, 255, 0)
    # palette: reuse the sheet's own hue family by pulling the hero toward it
    base = np.asarray(ship.convert("RGB")).astype(np.float32)
    base_mean = base.reshape(-1, 3).mean(axis=0)
    m = a[..., 3] > 0
    hero_mean = a[m][:, :3].mean(axis=0) if m.any() else base_mean
    # detail transfer: keep the crisp 2x original as the colour base and add
    # only the high-frequency band from the img2img pass, so flat hulls do not
    # pick up the render's mottling.
    small = ship.resize((380, 140), Image.Resampling.NEAREST)
    base = np.asarray(small).astype(np.float32)
    smooth = np.asarray(Image.fromarray(a[..., :3].astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(2.2))).astype(np.float32)
    high = a[..., :3] - smooth
    base[..., :3] = np.clip(base[..., :3] + high * 0.85, 0, 255)
    base[..., 3] = a[..., 3]
    out = Image.fromarray(base.astype(np.uint8), "RGBA")
    q = out.convert("RGB").quantize(colors=14, method=Image.MEDIANCUT).convert("RGB")
    q = q.filter(ImageFilter.UnsharpMask(radius=1, percent=130, threshold=2))
    q = ImageEnhance.Sharpness(q).enhance(1.5)
    out = q.convert("RGBA")
    out.putalpha(Image.fromarray(a[..., 3].astype(np.uint8)))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--denoise", type=float, default=0.40)
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    ids = [i for i in IDS if not args.only or i in args.only.split(",")]
    for hid in ids:
        ship_path = SRC / f"{hid}.png"
        name = f"hero_in_{hid}.png"
        prep_input(ship_path, name)
        prompt = (f"2D side profile of a {LOOK[hid]}, long horizontal hull pointing left, "
                  "detailed panel lines, rivets, engine nozzles, technical sci-fi detail, "
                  "crisp pixel art sprite, dark outline, isolated object on flat magenta background")
        wf = workflow(name, prompt, seed=8801, denoise=args.denoise)
        out = generate(wf, timeout_s=900)
        img = key(Image.open(out))
        hero = finish(img, Image.open(ship_path).convert("RGBA"))
        hero.save(OUT / f"{hid}.png")
        print("ok", hid, out)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Painted planet plates — own ComfyUI workflow, own finishing pass.

Different job from `gen_asset.py`, so it gets its own graph instead of borrowed
flags: SDXL at 16:9, a latent hires pass so the planet limb stays clean at 640
wide, then a screen-print finish (posterise + halftone + grain) that pushes the
model's smooth gradients toward flat retro print. The graph is written to
`tools/workflows/painted_planet.json` so it can be opened and edited in the
ComfyUI GUI, and the script reads the same file back.

Usage:
  gen_paint.py                 # every scene
  gen_paint.py world_ice sun   # named scenes
  gen_paint.py --force sun     # re-render raws too
"""
import json
import sys
import time
import urllib.request
import uuid
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "backgrounds" / "painted"
RAW = ROOT / "assets" / "raw" / "painted"
WF = ROOT / "tools" / "workflows" / "painted_planet.json"
COMFY = "http://127.0.0.1:8188"
CKPT = "sd_xl_base_1.0.safetensors"

W, H = 1344, 768          # generation size, then 1.5x latent hires
STEPS, CFG, SAMPLER = 32, 6.0, "dpmpp_2m"
SIGMA = "karras"
HIRES, HIRES_DENOISE = 1.5, 0.42
POSTERISE = 18

STYLE = ("flat vector space illustration, bold geometric planet shapes, clean silhouette, smooth soft gradients, "
         "minimal shading, modern science explainer animation look printed as a 1970s sci-fi poster, "
         "faint halftone grain, slightly faded inks, limited retro palette, no text, no letters")

NEG = ("text, letters, words, watermark, signature, frame, border, ui, hud, photo, photorealistic, "
       "anime, person, figure, logo, cute, childish, storybook, pastel candy, painterly, brush strokes, "
       "oil paint, dense detail, gritty, purple haze, neon, glossy 3d render")

SCENES = {
    "world_ocean": ("a deep teal ocean world with pale cloud swirls and a thin bright airglow, seen from orbit",
                    "palette: deep teal, sea green, ivory, slate blue"),
    "world_desert": ("an ochre desert world with long dune bands and dark canyon scars, seen from orbit",
                     "palette: ochre, burnt sienna, dusty rose, dark umber"),
    "world_ice": ("a pale ice world with cracked white plates and frost-blue fissures, seen from orbit",
                  "palette: pale blue-white, glacier blue, steel grey, deep navy"),
    "world_volcanic": ("a dark volcanic world with glowing lava fissures and ash plains, seen from orbit",
                       "palette: charcoal, ember orange, dim red, smoke grey"),
    "world_gas": ("a banded gas giant with amber and olive cloud belts and one storm oval",
                  "palette: amber, olive, cream, warm brown"),
    "world_ringed": ("a ringed world, its rings catching light as they pass behind it",
                     "palette: pale sand, grey-violet, warm gold, ink blue"),
    "world_moon": ("a cratered grey moon in the foreground with a larger blue planet rising behind it",
                   "palette: gunmetal grey, pale blue, bone white, near-black"),
    "world_crystal": ("a crystalline world of faceted mint and lilac mineral plains, seen from orbit",
                      "palette: mint, lilac, glacier white, charcoal"),
    "dispatch": ("a small ship leaving orbit of a ringed world, long engine trail, the planet filling half the frame",
                 "palette: steel blue, copper, cream, deep teal"),
    "sun": ("a huge amber star with a seething surface and a thin corona, a dark planet crossing in front",
            "palette: marigold, peach, rust, near-black"),
}


def graph(prompt, negative, seed, w=W, h=H):
    """Two-pass graph: base sample, latent upscale, low-denoise refinement."""
    g = {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": CKPT}},
        "2": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["1", 1]}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"text": negative, "clip": ["1", 1]}},
        "4": {"class_type": "EmptyLatentImage", "inputs": {"width": w, "height": h, "batch_size": 1}},
        "5": {"class_type": "KSampler", "inputs": {
            "seed": seed, "steps": STEPS, "cfg": CFG, "sampler_name": SAMPLER,
            "scheduler": SIGMA, "denoise": 1.0, "model": ["1", 0],
            "positive": ["2", 0], "negative": ["3", 0], "latent_image": ["4", 0]}},
        "6": {"class_type": "LatentUpscale", "inputs": {
            "upscale_method": "nearest-exact", "width": int(w * HIRES), "height": int(h * HIRES),
            "crop": "disabled", "samples": ["5", 0]}},
        "7": {"class_type": "KSampler", "inputs": {
            "seed": seed + 1, "steps": 22, "cfg": CFG * 0.9, "sampler_name": SAMPLER,
            "scheduler": SIGMA, "denoise": HIRES_DENOISE, "model": ["1", 0],
            "positive": ["2", 0], "negative": ["3", 0], "latent_image": ["6", 0]}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["7", 0], "vae": ["1", 2]}},
        "9": {"class_type": "SaveImage", "inputs": {"filename_prefix": "painted", "images": ["8", 0]}},
    }
    return g


def post(path, payload):
    req = urllib.request.Request(COMFY + path, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=60).read())


def wait_for(pid, raw):
    for _ in range(600):
        hist = json.loads(urllib.request.urlopen(f"{COMFY}/history/{pid}", timeout=30).read())
        if pid in hist:
            imgs = hist[pid]["outputs"]["9"]["images"]
            name = imgs[0]["filename"]
            data = urllib.request.urlopen(f"{COMFY}/view?filename={name}&type=output", timeout=60).read()
            raw.parent.mkdir(parents=True, exist_ok=True)
            raw.write_bytes(data)
            return
        time.sleep(2)
    raise TimeoutError(pid)


def render(prompt, negative, seed, raw):
    wf = graph(prompt, negative, seed)
    WF.parent.mkdir(parents=True, exist_ok=True)
    WF.write_text(json.dumps(wf, indent=2))
    pid = str(uuid.uuid4())
    post("/prompt", {"prompt": wf, "client_id": pid})
    wait_for(pid, raw)


def halftone(arr, step=3, strength=0.10):
    """Screen-print dots in the midtones only; highlights and shadows stay flat."""
    h, w = arr.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    dots = ((xx % step) - step / 2) ** 2 + ((yy % step) - step / 2) ** 2
    mask = (dots < (step * 0.42) ** 2).astype(np.float32)
    mask = 1.0 - (1.0 - mask) * strength
    return arr * mask[..., None]


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

    # flatten: posterise toward screen-print rather than leaving model gradients
    q = img.quantize(colors=POSTERISE, method=Image.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    img = Image.blend(img, q, 0.72).resize((w, h), Image.Resampling.LANCZOS)

    arr = np.asarray(img).astype(np.float32)
    arr = halftone(arr)
    rng = np.random.default_rng(5)
    arr += rng.normal(0, 1.3, arr.shape[:2])[..., None]
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(out)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    force = "--force" in sys.argv
    OUT.mkdir(parents=True, exist_ok=True)
    names = args or list(SCENES)
    for i, name in enumerate(names):
        prompt, palette = SCENES[name]
        raw = RAW / f"{name}.png"
        if force or not raw.exists():
            render(prompt + ", " + palette + ", " + STYLE, NEG, 7100 + i, raw)
        finish(raw, OUT / f"{name}.png")
        print("ok", name, flush=True)


if __name__ == "__main__":
    main()

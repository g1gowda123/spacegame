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

STYLE = ("flat vector space illustration, bold simple geometric shapes, clean silhouettes, smooth soft gradients, "
         "minimal shading, the look of a modern science explainer animation, printed like a 1970s sci-fi poster: "
         "slight halftone grain, slightly faded inks, limited retro palette, no text, no letters")

NEG = ("text, letters, words, watermark, signature, frame, border, ui, interface, hud, photo, "
       "photorealistic, anime character, person, face, logo, purple gradient, violet glow, magenta haze, "
       "neon, glossy 3d render, airbrush, smooth digital gradient, generic ai art, oversaturated, "
       "cute, childish, storybook, pastel, candy colours, painterly, brush strokes, oil painting, "
       "photorealistic texture, dense detail, gritty, dark mud, purple haze, "
       "ground, terrain, landscape, trees, plants, mountains, silhouette, figure, horizon")

SCENES = {
    # one planet type per plate: the point is that they read as *different worlds*
    "world_ocean": ("a deep teal ocean world with pale cloud swirls and a thin bright airglow, seen from orbit",
                    "palette: deep teal, sea green, ivory cloud, slate blue"),
    "world_desert": ("an ochre desert world with long wind-carved dune bands and dark canyon scars, seen from orbit",
                     "palette: ochre, burnt sienna, dusty rose, dark umber"),
    "world_ice": ("a pale ice world with cracked white plates and frost-blue fissures, seen from orbit",
                  "palette: pale blue-white, glacier blue, steel grey, deep navy"),
    "world_volcanic": ("a dark volcanic world with glowing lava fissures and ash plains, seen from orbit",
                       "palette: charcoal, ember orange, dim red, smoke grey"),
    "world_gas": ("a banded gas giant with amber and olive cloud belts and one storm oval",
                  "palette: amber, olive, cream, warm brown"),
    "world_ringed": ("a ringed world, its rings catching light as they pass behind it",
                     "palette: pale sand, dusty violet-grey, warm gold, ink blue"),
    "world_moon": ("a cratered grey moon in the foreground with a larger blue planet rising behind it",
                   "palette: gunmetal grey, pale blue, bone white, near-black"),
    "world_crystal": ("a crystalline world of faceted mint and lilac mineral plains, seen from orbit",
                      "palette: mint, lilac, glacier white, charcoal"),
    "dispatch": ("a small ship leaving orbit of a ringed world, long engine trail, the planet filling half the frame",
                 "palette: steel blue, copper, cream, deep teal"),
    "sun": ("a huge amber star with a seething surface and a thin corona, a dark planet crossing in front",
            "palette: marigold, peach, rust, near-black"),
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

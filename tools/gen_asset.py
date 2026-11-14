#!/usr/bin/env python3
"""Generate a game sprite with ComfyUI and post-process it to pixel art.

End-to-end: prompt -> ComfyUI API -> raw PNG -> pixelize -> game-ready PNG.

Requires ComfyUI running at http://127.0.0.1:8188 with
sd_xl_base_1.0.safetensors and pixel-art-xl.safetensors installed.

Usage:
  gen_asset.py "lunar rover" --out assets/sprites/rover.png --size 128
  gen_asset.py "astronaut helmet" --out assets/sprites/helmet.png --seed 42
"""

from __future__ import annotations

import argparse
import json
import random
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

COMFY = "http://127.0.0.1:8188"
CHECKPOINT = "sd_xl_base_1.0.safetensors"
LORA = "pixel-art-xl.safetensors"
ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "assets" / "raw"


def post_json(path: str, payload: dict) -> dict:
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        COMFY + path, data=data, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def get_json(path: str) -> dict:
    with urllib.request.urlopen(COMFY + path, timeout=30) as r:
        return json.loads(r.read())


def build_workflow(prompt: str, negative: str, seed: int, steps: int, cfg: float,
                   width: int, height: int, lora_strength: float,
                   seamless: bool = False) -> dict:
    model_out = ["9", 0] if seamless else ["2", 0]
    vae_out = ["10", 0] if seamless else ["1", 2]
    wf = {
        "1": {
            "class_type": "CheckpointLoaderSimple",
            "inputs": {"ckpt_name": CHECKPOINT},
        },
        "2": {
            "class_type": "LoraLoader",
            "inputs": {
                "model": ["1", 0],
                "clip": ["1", 1],
                "lora_name": LORA,
                "strength_model": lora_strength,
                "strength_clip": lora_strength,
            },
        },
        "3": {
            "class_type": "CLIPTextEncode",
            "inputs": {"text": prompt, "clip": ["2", 1]},
        },
        "4": {
            "class_type": "CLIPTextEncode",
            "inputs": {"text": negative, "clip": ["2", 1]},
        },
        "5": {
            "class_type": "EmptyLatentImage",
            "inputs": {"width": width, "height": height, "batch_size": 1},
        },
        "6": {
            "class_type": "KSampler",
            "inputs": {
                "seed": seed,
                "steps": steps,
                "cfg": cfg,
                "sampler_name": "dpmpp_2m",
                "scheduler": "karras",
                "denoise": 1.0,
                "model": model_out,
                "positive": ["3", 0],
                "negative": ["4", 0],
                "latent_image": ["5", 0],
            },
        },
        "7": {
            "class_type": "VAEDecode",
            "inputs": {"samples": ["6", 0], "vae": vae_out},
        },
        "8": {
            "class_type": "SaveImage",
            "inputs": {"filename_prefix": "sprite", "images": ["7", 0]},
        },
    }
    if seamless:
        # Circular padding makes every conv wrap, so the sampler produces a
        # genuinely tileable texture instead of one that must be healed after.
        wf["9"] = {
            "class_type": "SeamlessTile",
            "inputs": {
                "model": ["2", 0],
                "tiling": "enable",
                "copy_model": "Make a copy",
            },
        }
        wf["10"] = {
            "class_type": "MakeCircularVAE",
            "inputs": {
                "vae": ["1", 2],
                "tiling": "enable",
                "copy_vae": "Make a copy",
            },
        }
    return wf


def generate(workflow: dict, timeout_s: int = 600) -> Path:
    prompt_id = post_json("/prompt", {"prompt": workflow, "client_id": str(uuid.uuid4())})["prompt_id"]
    print(f"queued {prompt_id}", flush=True)

    deadline = time.time() + timeout_s
    while time.time() < deadline:
        hist = get_json(f"/history/{prompt_id}")
        if prompt_id in hist:
            entry = hist[prompt_id]
            status = entry.get("status", {})
            if status.get("status_str") == "error":
                raise SystemExit(f"generation failed: {json.dumps(status)[:2000]}")
            images = entry["outputs"]["8"]["images"]
            img = images[0]
            query = urllib.parse.urlencode(
                {"filename": img["filename"], "subfolder": img.get("subfolder", ""), "type": "output"}
            )
            RAW_DIR.mkdir(parents=True, exist_ok=True)
            dest = RAW_DIR / f"{img['filename']}"
            urllib.request.urlretrieve(f"{COMFY}/view?{query}", dest)
            return dest
        time.sleep(1.0)
    raise SystemExit("timed out waiting for ComfyUI")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("subject")
    p.add_argument("--out", required=True, type=Path)
    p.add_argument("--size", type=int, default=128)
    p.add_argument("--gen-size", type=int, default=1024,
                   help="native generation resolution (use size*8 for crisp pixels)")
    p.add_argument("--gen-width", type=int, default=0,
                   help="override native width (square --gen-size when 0)")
    p.add_argument("--gen-height", type=int, default=0,
                   help="override native height (square --gen-size when 0)")
    p.add_argument("--colors", type=int, default=24)
    p.add_argument("--palette", default=None, help="comma-separated hex colours")
    p.add_argument("--biome", default=None,
                   help="palette name from tools/palettes.json (overrides --palette/--colors)")
    p.add_argument("--seed", type=int, default=None)
    p.add_argument("--steps", type=int, default=25)
    p.add_argument("--cfg", type=float, default=5.0)
    p.add_argument("--lora", type=float, default=1.0)
    p.add_argument("--view", default="isometric tactical game unit, three-quarter top-down view")
    p.add_argument("--style", default="chunky flat-shaded shapes, thick dark outline, limited desaturated palette, teal and orange accents")
    p.add_argument("--bg", default="magenta")
    p.add_argument("--negative-extra", default="", help="extra negative terms (comma-separated)")
    p.add_argument("--outline", default=None)
    p.add_argument("--tile", action="store_true", help="tile mode: no background key, no trim, 2x2 preview")
    p.add_argument("--texture", action="store_true",
                   help="material mode for tools/make_tile.py (soft fields, low LoRA strength)")
    p.add_argument("--seam-band", type=int, default=1,
                   help="post-process seam band in output pixels (0 = skip)")
    p.add_argument("--model-seamless", action="store_true",
                   help="use circular-padding nodes (truly tileable, but changes style)")
    p.add_argument("--no-pixelize", action="store_true")
    args = p.parse_args()

    if args.biome:
        palettes = json.loads((ROOT / "tools" / "palettes.json").read_text())
        if args.biome not in palettes:
            raise SystemExit(f"unknown biome '{args.biome}' (have: {', '.join(palettes)})")
        entry = palettes[args.biome]
        args.palette = ",".join(c.lstrip("#") for c in entry["colors"])
        args.colors = len(entry["colors"])
        print(f"palette: {args.biome} ({args.colors} colors)")

    seed = args.seed if args.seed is not None else random.randint(1, 2**31 - 1)
    # Pixel Art XL needs no style trigger: the author recommends leaving
    # "pixel art" OUT of the prompt and letting the LoRA do the pixelation.
    if args.texture:
        # Material render for tools/make_tile.py. No LoRA pixel grid: the tile
        # pipeline wants soft, large-scale colour fields it can prefilt down.
        prompt = (
            f"aerial top-down view of {args.subject}, "
            f"flat even lighting, soft diffuse shading, wide even colour fields, "
            f"subtle low-contrast detail, no strong focal point"
        )
        negative = (
            "objects, rocks, debris, footprints, tracks, text, watermark, border, "
            "frame, vignette, perspective, horizon, sky, drop shadow, harsh contrast, "
            "high frequency noise, speckle, dithering, photorealistic detail"
        )
        if args.negative_extra:
            negative = f"{negative}, {args.negative_extra}"
    elif args.tile:
        prompt = (
            f"top-down seamless terrain tile, {args.subject}, "
            f"flat shading, chunky angular color clusters, limited palette, "
            f"even lighting, no shadows, no border, game terrain tile"
        )
        negative = (
            "blurry, photo, photorealistic, 3d render, smooth gradients, "
            "anti-aliasing, text, watermark, border, frame, vignette, perspective, "
            "horizon, sky, drop shadow, lighting hotspots, noise, dense speckle, "
            "large objects"
        )
        if args.negative_extra:
            negative = f"{negative}, {args.negative_extra}"
    else:
        prompt = (
            f"{args.subject}, {args.view}, {args.style}, "
            f"clean silhouette, centered, plain solid {args.bg} background, no text"
        )
        negative = (
            "blurry, photo, photorealistic, 3d render, smooth gradients, "
            "anti-aliasing, text, watermark, signature, multiple objects, cropped, frame, "
            "drop shadow, ground shadow, floor, ground plane, surface, reflection"
        )
        if args.negative_extra:
            negative = f"{negative}, {args.negative_extra}"
    gen_w = args.gen_width or args.gen_size
    gen_h = args.gen_height or args.gen_size
    wf = build_workflow(prompt, negative, seed, args.steps, args.cfg,
                        gen_w, gen_h, args.lora,
                        seamless=args.model_seamless)
    raw = generate(wf)
    print(f"raw: {raw} (seed {seed})")

    if args.no_pixelize:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_bytes(raw.read_bytes())
        print(f"wrote {args.out}")
        return

    cmd = [
        sys.executable, str(ROOT / "tools" / "pixelize.py"), str(raw), str(args.out),
        "--size", str(args.size), "--colors", str(args.colors), "--bg", args.bg,
    ]
    if args.tile:
        cmd += ["--tile"]
        if args.seam_band > 0:
            cmd += ["--seamless", "--seam-band", str(args.seam_band)]
    if args.palette:
        cmd += ["--palette", args.palette]
    if args.outline:
        cmd += ["--outline", args.outline]
    subprocess.run(cmd, check=True)

    manifest = args.out.parent / "manifest.jsonl"
    manifest.parent.mkdir(parents=True, exist_ok=True)
    try:
        display_path = str(args.out.resolve().relative_to(ROOT))
    except ValueError:
        display_path = str(args.out)
    with open(manifest, "a") as f:
        f.write(json.dumps({
            "file": display_path,
            "subject": args.subject,
            "biome": args.biome,
            "palette": args.palette,
            "seed": seed,
            "steps": args.steps,
            "cfg": args.cfg,
            "lora": args.lora,
            "checkpoint": CHECKPOINT,
            "prompt": prompt,
            "tile": args.tile,
        }) + "\n")


if __name__ == "__main__":
    main()

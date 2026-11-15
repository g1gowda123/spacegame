#!/usr/bin/env python3
"""Generate a cover illustration for Orbit & Outplay through ComfyUI.

This is a cover-specific graph, not the sprite helper. It runs SDXL + Pixel Art
XL at 1280x1024, then optionally does a low-denoise 1.5x hires pass so the
illustration keeps its pixel clusters instead of turning into a screenshot.

Usage:
  python tools/gen_cover.py --variant a --seed 7101 --raw-only
  python tools/gen_cover.py --variant a --seed 7101 --out assets/raw/cover_a.png

The text-free raw is composited by tools/compose_cover.py; keeping type out of
the diffusion pass is deliberate: SDXL cannot spell the wordmark reliably.
"""
from __future__ import annotations

import argparse
import json
import random
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

COMFY = "http://127.0.0.1:8188"
CHECKPOINT = "sd_xl_base_1.0.safetensors"
LORA = "pixel-art-xl.safetensors"
ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "assets" / "raw"
WORKFLOW = ROOT / "tools" / "comfy_workflows" / "cover_survey_api.json"

BASE_W, BASE_H = 1280, 1024
HIRES_W, HIRES_H = 1920, 1536

PROMPTS = {
    "f": (
        "store cover illustration for a turn-based exoplanet survey game, "
        "isometric diorama of stepped alien plateaus: warm terracotta and rust stone slabs with dark "
        "near-black vertical cliff walls, deep teal water channels winding between the shelves, "
        "one small glowing cyan survey orb resting in the water, a compact four-legged survey lander "
        "with a high-gain dish parked on the highest shelf, a few tiny data nodes strung along a path, "
        "a huge pale ringed planet low in the dark sky, "
        "limited palette of terracotta orange, teal, charcoal and cream, chunky 16-bit pixel art with "
        "crisp tile edges and two-tone top surfaces, calm dark sky across the top third, "
        "no text, no letters, no UI, no frame"
    ),
    "g": (
        "top-down isometric map view of a terraced alien plateau archipelago, "
        "orange stone shelves stepping down into deep teal ocean, dark cliff faces between levels, "
        "thin foam lines where rock meets water, a single glowing cyan anomaly on one shelf, "
        "a tiny survey lander with a dish, sparse dark rock spires, "
        "limited palette of terracotta, teal, charcoal and cream, chunky 16-bit pixel art, "
        "even lighting, no text, no UI, no frame"
    ),
    "e": (
        "store cover art for a turn-based exoplanet survey game, "
        "isometric tactical map diorama floating in a dark sky, alien tidal marsh: "
        "pale violet and mauve mineral ground, shallow teal channels full of flat water, "
        "black basalt spires with thin cyan beacon lights, scattered reeds and shell crust, "
        "a boxy survey lander with a high-gain dish on a raised shelf and a trail of glowing data nodes, "
        "a large ringed planet and two small moons above the diorama, soft fog at the edges, "
        "bright rose, violet and emerald palette with burnt-orange accents, "
        "even lighting, crisp pixel-art edges, wide composition with calm dark sky at the top, "
        "16-bit pixel-art illustration, no text, no letters, no UI, no frame"
    ),
    "d": (
        "cover illustration for a turn-based exoplanet survey game, "
        "alien tidal marsh under a teal and heliotrope sky, shallow reflective water broken by "
        "dark basalt plateaus and tall narrow rock spires, thin cyan beacon lights on the spires, "
        "a small boxy survey lander on a raised rock shelf with a high-gain dish, "
        "a winding trail of glowing data nodes leading to it, drifting low fog banks, "
        "a huge ringed planet low on the horizon, sparse alien reeds and mineral crust, "
        "atmospheric depth, muted violet and deep teal palette with burnt-orange accents, "
        "wide establishing shot, subject in the lower third, large calm dark sky at the top, "
        "16-bit pixel-art illustration, chunky readable shapes, no text, no letters, no UI, no frame"
    ),
    "a": (
        "dramatic cover illustration for a turn-based space mission design game, "
        "lone boxy survey lander with a tall high-gain dish on a windswept alien ridge, "
        "giant ringed exoplanet rising over the horizon, two small moons, "
        "winding trail of glowing cyan data nodes leading toward the lander, "
        "amber solar-storm front sweeping across the right side, thin lightning, "
        "deep navy and teal sky, bone-white highlights, burnt-orange hazard accents, "
        "low horizon, subject in the lower third, large clean dark negative space at the top, "
        "cinematic low-angle composition, 16-bit pixel-art illustration, crisp silhouette, "
        "high contrast, atmospheric perspective, no text, no letters, no UI, no HUD, no frame"
    ),
    "b": (
        "dramatic cover illustration for a space survey game, "
        "small astronaut in a bone-white suit kneeling beside a glowing cyan data node, "
        "boxy lander behind on a black volcanic ridge, enormous banded exoplanet overhead, "
        "orange radiation belt cutting across the sky, wind-blown dust, "
        "deep teal shadows, warm amber rim light, bone and rust palette, "
        "large dark negative space at the top for a title, "
        "cinematic side lighting, 16-bit pixel-art illustration, detailed, high contrast, "
        "no text, no letters, no UI, no HUD, no frame"
    ),
    "c": (
        "graphic cover illustration for a mission-design roguelite, "
        "low-angle hero shot of a compact lander silhouetted against a huge ringed planet, "
        "a bright cyan beacon on the lander, three data pips floating like stars, "
        "orange hazard ribbons curling through the foreground, "
        "deep navy sky, cream highlights, teal glow, amber accents, "
        "bold simple shapes, poster composition, negative space at top, "
        "16-bit pixel-art illustration, strong silhouette, no text, no letters, no UI, no HUD, no frame"
    ),
    "d": (
        "isometric cover illustration for a turn-based exoplanet survey game, "
        "tiny lander on a raised alien ridge surrounded by dark water and crystal spires, "
        "glowing cyan path of tiles winding to a science node, "
        "orange hazard front forming on the right, huge ringed planet in the sky, "
        "deep teal and navy palette, warm agency orange, bone-white UI accents, "
        "wide cinematic view, subject in lower third, dark sky at top, "
        "16-bit pixel-art illustration, crisp readable shapes, no text, no letters, no UI, no HUD, no frame"
    ),
    "e": (
        "hero cover illustration for a space survey game, "
        "lone astronaut in a bone-white suit kneeling on a black basalt ridge, "
        "holding a glowing cyan data core in both hands, "
        "a compact four-legged lunar lander with a gold-foil body and tall dish behind them, "
        "enormous banded exoplanet rising in the deep teal sky, "
        "orange solar storm ribbons on the right, dust blowing off the ridge, "
        "large clean dark negative space across the top third, "
        "cinematic low-angle composition, 16-bit pixel-art illustration, "
        "high contrast, warm bone and amber accents, no text, no letters, no UI, no HUD, no frame"
    ),
    "f": (
        "isometric key art for a turn-based exoplanet mission game, "
        "a prominent four-legged lunar lander with gold foil, a tall high-gain dish and cyan beacon lights, "
        "standing on a raised cliff in the center of the frame, "
        "a winding cyan path of illuminated tiles leads to a glowing science node, "
        "orange hazard front creeping along the lower right, dark teal water and crystal spires, "
        "a huge ringed planet fills the upper right sky, "
        "deep navy and teal with bone-white and agency-orange accents, "
        "clean poster composition, dark negative space top left, "
        "16-bit pixel-art illustration, strong readable silhouette, no text, no letters, no UI, no HUD, no frame"
    ),
}

NEGATIVE = (
    "text, letters, words, logo, watermark, signature, UI, HUD, screenshot, menu, "
    "frame, border, vignette, blurry, photorealistic, 3d render, low contrast, muddy, "
    "noise, oversaturated, cropped subject, duplicate lander, multiple suns, "
    "astronaut helmet reflection, busy composition, giant typography"
)


def post(path: str, payload: dict) -> dict:
    req = urllib.request.Request(
        COMFY + path,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def get(path: str) -> dict:
    with urllib.request.urlopen(COMFY + path, timeout=30) as r:
        return json.loads(r.read())


def graph(prompt: str, seed: int, steps: int, cfg: float, hires: bool) -> dict:
    """API-format ComfyUI graph. Node ids are stable so it can be replayed."""
    wf: dict = {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": CHECKPOINT}},
        "2": {"class_type": "LoraLoader", "inputs": {
            "model": ["1", 0], "clip": ["1", 1], "lora_name": LORA,
            "strength_model": 0.85, "strength_clip": 0.85,
        }},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["2", 1]}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"text": NEGATIVE, "clip": ["2", 1]}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {
            "width": BASE_W, "height": BASE_H, "batch_size": 1,
        }},
        "6": {"class_type": "KSampler", "inputs": {
            "seed": seed, "steps": steps, "cfg": cfg, "sampler_name": "dpmpp_2m",
            "scheduler": "karras", "denoise": 1.0, "model": ["2", 0],
            "positive": ["3", 0], "negative": ["4", 0], "latent_image": ["5", 0],
        }},
        "7": {"class_type": "VAEDecode", "inputs": {"samples": ["6", 0], "vae": ["1", 2]}},
        "8": {"class_type": "SaveImage", "inputs": {"filename_prefix": "cover", "images": ["7", 0]}},
    }
    if hires:
        wf.update({
            "9": {"class_type": "ImageScale", "inputs": {
                "image": ["7", 0], "upscale_method": "lanczos",
                "width": HIRES_W, "height": HIRES_H, "crop": "disabled",
            }},
            "10": {"class_type": "VAEEncode", "inputs": {"pixels": ["9", 0], "vae": ["1", 2]}},
            "11": {"class_type": "KSampler", "inputs": {
                "seed": seed + 1, "steps": max(14, steps // 2), "cfg": cfg,
                "sampler_name": "dpmpp_2m", "scheduler": "karras", "denoise": 0.32,
                "model": ["2", 0], "positive": ["3", 0], "negative": ["4", 0],
                "latent_image": ["10", 0],
            }},
            "12": {"class_type": "VAEDecode", "inputs": {"samples": ["11", 0], "vae": ["1", 2]}},
            "8": {"class_type": "SaveImage", "inputs": {"filename_prefix": "cover_hires", "images": ["12", 0]}},
        })
    return wf


def run(wf: dict, timeout: int = 600) -> Path:
    prompt_id = post("/prompt", {"prompt": wf, "client_id": str(uuid.uuid4())})["prompt_id"]
    print("queued", prompt_id, flush=True)
    end = time.time() + timeout
    while time.time() < end:
        hist = get("/history/" + prompt_id)
        if prompt_id in hist:
            entry = hist[prompt_id]
            status = entry.get("status", {})
            if status.get("status_str") == "error":
                raise SystemExit("generation failed: " + json.dumps(status)[:2000])
            out = entry["outputs"]["8"]["images"][0]
            q = urllib.parse.urlencode({
                "filename": out["filename"], "subfolder": out.get("subfolder", ""), "type": "output",
            })
            RAW.mkdir(parents=True, exist_ok=True)
            dest = RAW / out["filename"]
            urllib.request.urlretrieve(COMFY + "/view?" + q, dest)
            return dest
        time.sleep(1.0)
    raise SystemExit("timed out waiting for ComfyUI")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", choices=sorted(PROMPTS), default="a")
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--steps", type=int, default=28)
    ap.add_argument("--cfg", type=float, default=5.5)
    ap.add_argument("--out", type=Path, default=None)
    ap.add_argument("--hires", action="store_true", help="1.5x low-denoise detail pass")
    ap.add_argument("--raw-only", action="store_true", help="save the ComfyUI raw under assets/raw")
    ap.add_argument("--save-workflow", action="store_true", help="write the API graph JSON for replay")
    args = ap.parse_args()

    seed = args.seed if args.seed is not None else random.randint(1, 2**31 - 1)
    wf = graph(PROMPTS[args.variant], seed, args.steps, args.cfg, args.hires)
    if args.save_workflow:
        WORKFLOW.parent.mkdir(parents=True, exist_ok=True)
        WORKFLOW.write_text(json.dumps(wf, indent=1) + "\n")
        print("workflow:", WORKFLOW)
    raw = run(wf)
    print(f"raw: {raw} (seed {seed}, variant {args.variant})")
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_bytes(raw.read_bytes())
        print("wrote", args.out)


if __name__ == "__main__":
    main()

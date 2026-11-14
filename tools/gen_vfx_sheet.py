#!/usr/bin/env python3
"""ComfyUI -> animated VFX frames.

Animator lane. The static tile/sprite art is VEGA's; this pipeline makes the
time-varying effect sheets the VFX module plays.

Why not ask the model for a sprite sheet?
  SDXL is good at drawing ONE strong effect shape and bad at keeping 8 cells
  consistent. So we generate one high-detail element per kind, key it, then
  derive the motion in code (expand/fade, billow/drift, shrink/flicker). The
  result is deterministic and every seed is a one-click re-roll of the whole
  sequence.

Usage:
  python tools/gen_vfx_sheet.py --kind flare --seed 4201
  python tools/gen_vfx_sheet.py --kind smoke --seed 4202
  python tools/gen_vfx_sheet.py --kind ember --seed 4203
  python tools/gen_vfx_sheet.py --kind flare --source assets/raw/vfx/flare.png

Requires ComfyUI at http://127.0.0.1:8188 with sd_xl_base_1.0.safetensors and
pixel-art-xl.safetensors (the same stack tools/gen_asset.py uses). The matching
graphs live in tools/comfy_workflows/vfx_<kind>.json and are also loadable by
hand in the ComfyUI UI.

Output: assets/vfx/<kind>/frame_00..07.png (RGBA, nearest, transparent) and an
updated entry in assets/vfx/manifest.json.
"""
from __future__ import annotations

import argparse
import json
import math
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

COMFY = "http://127.0.0.1:8188"
CHECKPOINT = "sd_xl_base_1.0.safetensors"
LORA = "pixel-art-xl.safetensors"
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "vfx"
RAW = ROOT / "assets" / "raw" / "vfx"

PROMPTS = {
    "flare": (
        "single stylized 2D game explosion impact burst, bright white-hot core, "
        "short radial orange and amber sparks, chunky flat shaded shapes, thick "
        "dark outline, limited warm palette, centered, isolated on a plain solid "
        "black background, front view, no ground, no text"
    ),
    "smoke": (
        "single stylized 2D game smoke puff, billowing dust cloud, chunky flat "
        "shaded lobes, hard pixel edges, 3 value grey-tan ramp, dark outline, "
        "centered, isolated on a plain solid black background, no ground, no text"
    ),
    "ember": (
        "single stylized 2D game ember chunk, glowing orange molten pebble, bright "
        "yellow core, dark cooled crust edge, chunky flat shaded pixel shapes, "
        "isolated on a plain solid black background, no text"
    ),
}
NEGATIVE = (
    "photo, photorealistic, 3d render, smooth gradients, soft bloom, lens flare, "
    "multiple objects, off center, cropped, frame, text, watermark, signature, "
    "grid, sprite sheet"
)
SIZES = {"flare": 64, "smoke": 40, "ember": 12}


# --- ComfyUI transport ----------------------------------------------------

def _post(path: str, payload: dict) -> dict:
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        COMFY + path, data=data, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def _get(path: str) -> dict:
    with urllib.request.urlopen(COMFY + path, timeout=30) as r:
        return json.loads(r.read())


def build_api_workflow(kind: str, seed: int, steps: int = 25, cfg: float = 5.0,
                       lora_strength: float = 1.0) -> dict:
    return {
        "1": {"class_type": "CheckpointLoaderSimple",
              "inputs": {"ckpt_name": CHECKPOINT}},
        "2": {"class_type": "LoraLoader",
              "inputs": {"model": ["1", 0], "clip": ["1", 1],
                         "lora_name": LORA, "strength_model": lora_strength,
                         "strength_clip": lora_strength}},
        "3": {"class_type": "CLIPTextEncode",
              "inputs": {"text": PROMPTS[kind], "clip": ["2", 1]}},
        "4": {"class_type": "CLIPTextEncode",
              "inputs": {"text": NEGATIVE, "clip": ["2", 1]}},
        "5": {"class_type": "EmptyLatentImage",
              "inputs": {"width": 1024, "height": 1024, "batch_size": 1}},
        "6": {"class_type": "KSampler",
              "inputs": {"seed": seed, "steps": steps, "cfg": cfg,
                         "sampler_name": "dpmpp_2m", "scheduler": "karras",
                         "denoise": 1.0, "model": ["2", 0],
                         "positive": ["3", 0], "negative": ["4", 0],
                         "latent_image": ["5", 0]}},
        "7": {"class_type": "VAEDecode",
              "inputs": {"samples": ["6", 0], "vae": ["1", 2]}},
        "8": {"class_type": "SaveImage",
              "inputs": {"filename_prefix": "vfx_" + kind, "images": ["7", 0]}},
    }


def generate(kind: str, seed: int, timeout_s: int = 600,
             lora_strength: float = 1.0) -> Path:
    wf = build_api_workflow(kind, seed, lora_strength=lora_strength)
    prompt_id = _post("/prompt", {"prompt": wf, "client_id": str(uuid.uuid4())})["prompt_id"]
    started = time.time()
    while time.time() - started < timeout_s:
        hist = _get(f"/history/{prompt_id}")
        if prompt_id in hist:
            outs = hist[prompt_id].get("outputs", {})
            for node in outs.values():
                for img in node.get("images", []):
                    q = urllib.parse.urlencode({
                        "filename": img["filename"],
                        "subfolder": img.get("subfolder", ""),
                        "type": img.get("type", "output"),
                    })
                    RAW.mkdir(parents=True, exist_ok=True)
                    dest = RAW / f"{kind}_{seed}.png"
                    with urllib.request.urlopen(f"{COMFY}/view?{q}", timeout=60) as r:
                        dest.write_bytes(r.read())
                    return dest
        time.sleep(1.5)
    raise TimeoutError(f"ComfyUI did not finish {kind} seed {seed} in {timeout_s}s")


# --- keying / pixelisation ------------------------------------------------

def _border_color(im: Image.Image, band: int = 8) -> tuple[int, int, int]:
    rgb = im.convert("RGB")
    w, h = rgb.size
    band = max(1, min(band, w // 4, h // 4))
    px = []
    for y in range(band):
        for x in range(0, w, 4):
            px.append(rgb.getpixel((x, y)))
            px.append(rgb.getpixel((x, h - 1 - y)))
    for x in range(band):
        for y in range(0, h, 4):
            px.append(rgb.getpixel((x, y)))
            px.append(rgb.getpixel((w - 1 - x, y)))
    px.sort()
    return px[len(px) // 2]


def key_background(im: Image.Image, tolerance: int = 46) -> Image.Image:
    """Flood-fill the flat backdrop from the border, leaving interior darks."""
    rgb = im.convert("RGB")
    w, h = rgb.size
    bg = _border_color(im)
    out = rgb.convert("RGBA")
    seed_px = rgb.load()
    seen = bytearray(w * h)
    stack = []
    for x in range(w):
        stack.append((x, 0))
        stack.append((x, h - 1))
    for y in range(h):
        stack.append((0, y))
        stack.append((w - 1, y))

    def close(c) -> bool:
        return (abs(c[0] - bg[0]) + abs(c[1] - bg[1]) + abs(c[2] - bg[2])) <= tolerance

    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        idx = y * w + x
        if seen[idx]:
            continue
        if not close(seed_px[x, y]):
            continue
        seen[idx] = 1
        out.putpixel((x, y), (0, 0, 0, 0))
        stack.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return out


def crop_square(im: Image.Image) -> Image.Image:
    bbox = im.getbbox()
    if bbox is None:
        return im
    im = im.crop(bbox)
    side = max(im.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
    return canvas


def pixelize(im: Image.Image, size: int, colors: int = 20) -> Image.Image:
    """Nearest downscale + posterise, keeping hard alpha edges."""
    small = im.resize((size, size), Image.NEAREST)
    alpha = small.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    rgb = small.convert("RGB").quantize(colors=colors, method=Image.MEDIANCUT).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def quantized(im: Image.Image) -> Image.Image:
    """Palette-lock without inventing new outline colours."""
    if im.getbbox() is None:
        return im
    alpha = im.getchannel("A")
    rgb = im.convert("RGB").quantize(colors=18, method=Image.MEDIANCUT).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


# --- frame derivation -----------------------------------------------------

def _paste_scaled(canvas: Image.Image, src: Image.Image, scale: float,
                  offset: tuple[float, float] = (0.0, 0.0),
                  angle: float = 0.0, alpha: float = 1.0) -> None:
    w = max(1, int(src.width * scale))
    h = max(1, int(src.height * scale))
    im = src.resize((w, h), Image.NEAREST)
    if angle:
        im = im.rotate(angle, resample=Image.NEAREST, expand=True)
    if alpha < 1.0:
        a = im.getchannel("A").point(lambda v: int(v * alpha))
        im.putalpha(a)
    cx = canvas.width * 0.5 + offset[0]
    cy = canvas.height * 0.5 + offset[1]
    canvas.alpha_composite(im, (int(cx - im.width * 0.5), int(cy - im.height * 0.5)))


def strip_flare_haze(im: Image.Image) -> Image.Image:
    """Drop the low-saturation grey wash SDXL puts behind an explosion.

    The sprite is played additively, so grey reads as a dull cloud; the impact
    needs the white core and the warm spark wedges only.
    """
    out = im.copy()
    px = out.load()
    cx = out.width * 0.5
    cy = out.height * 0.5
    core_r = max(6.0, out.width * 0.16)
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            mx = max(r, g, b)
            mn = min(r, g, b)
            sat = 0.0 if mx == 0 else (mx - mn) / float(mx)
            dist = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if dist > core_r and sat < 0.35:
                # White/grey specks away from the core are the model's cloud,
                # not sparks. Warm wedges (high saturation) survive.
                px[x, y] = (r, g, b, 0)
            elif mx < 240 and sat > 0.25:
                # Palette-lock the shards to the game's impact orange. SDXL
                # returns brown/olive debris; additive blending needs a warm,
                # bright spark so the burst does not read as dirt.
                px[x, y] = (255, 152, 58, a)
            elif sat < 0.55 and mx < 236:
                px[x, y] = (r, g, b, int(a * 0.55))
    return out


def make_flare(src: Image.Image) -> list[Image.Image]:
    size = SIZES["flare"]
    frames = []
    for i in range(8):
        t = i / 7.0
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        # Expanding spark shell.
        _paste_scaled(canvas, src, 0.42 + 0.95 * t, angle=t * 42.0,
                      alpha=(1.0 - t) ** 1.15)
        # Collapsing white-hot core, drawn over the shell.
        core_r = 11.0 * max(0.0, 1.0 - t * 1.45)
        if core_r > 0.4:
            d = ImageDraw.Draw(canvas)
            c = size * 0.5
            d.ellipse((c - core_r, c - core_r, c + core_r, c + core_r),
                      fill=(255, 250, 226, int(255 * (1.0 - t))))
            r2 = core_r * 0.55
            d.ellipse((c - r2, c - r2, c + r2, c + r2), fill=(255, 255, 255, 255))
        frames.append(strip_flare_haze(quantized(canvas)))
    return frames


def make_smoke(src: Image.Image) -> list[Image.Image]:
    size = SIZES["smoke"]
    frames = []
    for i in range(8):
        t = i / 7.0
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        wobble = math.sin(t * 6.2) * 1.5
        _paste_scaled(canvas, src, 0.62 + 1.05 * t,
                      offset=(wobble, -t * 9.0),
                      angle=math.sin(t * 3.1) * 12.0,
                      alpha=(1.0 - t) ** 1.25)
        frames.append(quantized(canvas))
    return frames


def make_ember(src: Image.Image) -> list[Image.Image]:
    size = SIZES["ember"]
    frames = []
    for i in range(8):
        t = i / 7.0
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        flicker = 0.72 + 0.28 * math.sin(t * 9.0 + 0.7)
        _paste_scaled(canvas, src, 1.0 - 0.28 * t,
                      offset=((i % 3) - 1.0, -t * 3.0),
                      alpha=flicker * (1.0 - t * 0.65))
        frames.append(quantized(canvas))
    return frames


MAKERS = {"flare": make_flare, "smoke": make_smoke, "ember": make_ember}


def write_frames(kind: str, frames: list[Image.Image]) -> None:
    d = OUT / kind
    d.mkdir(parents=True, exist_ok=True)
    for i, im in enumerate(frames):
        im.save(d / f"frame_{i:02d}.png")
    manifest_path = OUT / "manifest.json"
    manifest = {}
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text())
    manifest.setdefault("sheets", {})[kind] = {
        "frames": len(frames), "frame_ms": 42,
        "size": [frames[0].width, frames[0].height],
        "source": "comfy",
    }
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--kind", choices=sorted(MAKERS), default="flare")
    ap.add_argument("--seed", type=int, default=4201)
    ap.add_argument("--source", type=Path, help="use an existing raw PNG instead of ComfyUI")
    ap.add_argument("--steps", type=int, default=25)
    ap.add_argument("--cfg", type=float, default=5.0)
    ap.add_argument("--lora", type=float, default=1.0, help="pixel-art LoRA strength (0 disables)")
    args = ap.parse_args()

    if args.source:
        raw = args.source
    else:
        print(f"generating {args.kind} seed {args.seed} from {COMFY} ...")
        raw = generate(args.kind, args.seed, timeout_s=900, lora_strength=args.lora)
    print("raw:", raw)

    keyed = crop_square(key_background(Image.open(raw)))
    size = SIZES[args.kind]
    base = pixelize(keyed, max(size, 48), colors=18)
    base = base.resize((size, size), Image.NEAREST)
    # Re-key the small version so stray backdrop specks do not survive.
    base = key_background(base, tolerance=30)
    frames = MAKERS[args.kind](base)
    write_frames(args.kind, frames)
    print(f"wrote {len(frames)} frames to {OUT / args.kind}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Catalog every raw ComfyUI output and build a contact sheet.

ComfyUI embeds its API prompt in each PNG, so we can recover the seed and
positive prompt without keeping a separate log. Raw images are development
sources; only the files listed under assets/tilesets/ are game-ready.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "assets" / "raw"
COMFY_OUT = Path(os.environ.get("COMFY_OUT", Path.home() / "ComfyUI" / "output"))
CATALOG = RAW_DIR / "catalog.json"
SHEET = RAW_DIR / "contact_sheet.png"


def read_meta(path: Path) -> dict:
    im = Image.open(path)
    info = {"file": path.name, "width": im.width, "height": im.height,
            "seed": None, "prompt": "", "negative": ""}
    raw = im.info.get("prompt")
    if not raw:
        return info
    try:
        data = json.loads(raw)
    except Exception:
        return info
    nodes = data if isinstance(data, dict) else {}
    for node in nodes.values():
        if not isinstance(node, dict):
            continue
        ct = node.get("class_type")
        ins = node.get("inputs", {})
        if ct == "KSampler":
            info["seed"] = ins.get("seed")
            pos = ins.get("positive")
            neg = ins.get("negative")
            if isinstance(pos, list) and pos:
                pn = nodes.get(str(pos[0]))
                if isinstance(pn, dict):
                    info["prompt"] = pn.get("inputs", {}).get("text", "")
            if isinstance(neg, list) and neg:
                nn = nodes.get(str(neg[0]))
                if isinstance(nn, dict):
                    info["negative"] = nn.get("inputs", {}).get("text", "")
            break
    return info


def final_tiles_by_seed() -> dict:
    out: dict = {}
    for manifest in ROOT.glob("assets/**/manifest.jsonl"):
        for line in manifest.read_text().splitlines():
            if not line.strip():
                continue
            try:
                row = json.loads(line)
            except Exception:
                continue
            seed = row.get("seed")
            file = row.get("file")
            if seed is None or not file:
                continue
            out.setdefault(int(seed), set()).add(file)
    return {k: sorted(v) for k, v in out.items()}


def main() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    # Bring the one ComfyUI output that was never copied into the project.
    extra = COMFY_OUT / "itb_sprite_00001_.png"
    if extra.exists() and not (RAW_DIR / extra.name).exists():
        (RAW_DIR / extra.name).write_bytes(extra.read_bytes())

    paths = sorted(RAW_DIR.glob("*.png"))
    paths = [p for p in paths if not p.name.endswith("_preview.png")
             and p.name != "contact_sheet.png"]
    used = final_tiles_by_seed()

    catalog = []
    for p in paths:
        meta = read_meta(p)
        meta["used_in"] = used.get(int(meta["seed"]), []) if meta["seed"] is not None else []
        meta["status"] = "game-ready" if meta["used_in"] else "candidate"
        catalog.append(meta)

    CATALOG.write_text(json.dumps(catalog, indent=2) + "\n")

    # Contact sheet: 8 columns, 256 px cells, labels underneath.
    cols = 8
    cell = 256
    rows = (len(catalog) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell, rows * cell), (20, 18, 26))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for i, row in enumerate(catalog):
        x = (i % cols) * cell
        y = (i // cols) * cell
        try:
            img = Image.open(RAW_DIR / row["file"]).convert("RGB")
            img.thumbnail((cell - 16, cell - 38), Image.Resampling.LANCZOS)
            sheet.paste(img, (x + (cell - img.width) // 2, y + 8))
        except Exception:
            pass
        label = row["file"].replace("sprite_", "").replace(".png", "")
        draw.text((x + 8, y + cell - 28), label, fill=(210, 225, 220), font=font)
        draw.text((x + 8, y + cell - 16), row["status"], fill=(120, 200, 170), font=font)

    sheet.save(SHEET)

    ready = sum(1 for r in catalog if r["status"] == "game-ready")
    readme = [
        "# Raw ComfyUI sources",
        "",
        "These are the 1024×1024 diffusion outputs. They are **development sources**, not",
        "game tiles: the game-ready 64×64 pixelized versions live in `assets/tilesets/`.",
        "",
        f"- {len(catalog)} raw images",
        f"- {ready} promoted to a final tile",
        f"- {len(catalog) - ready} unused candidates (experiments, alternate seeds, rejects)",
        "",
        "`catalog.json` records each image's seed, positive/negative prompt, and which",
        "final tile(s) it produced. `contact_sheet.png` shows all candidates.",
        "",
        "Promote a candidate:",
        "",
        "```bash",
        "cd path/to/spacegame",
        "python tools/pixelize.py \\",
        "  assets/raw/NAME.png assets/tilesets/BIOME/NAME.png \\",
        "  --size 64 --colors 16 --tile --seamless --seam-band 1 \\",
        "  --palette \"$(python -c 'import json;print(\",\".join(json.load(open(\"tools/palettes.json\"))[\"BIOME\"]))')\"",
        "```",
        "",
        "Regenerate this catalog with `python tools/catalog_raw.py`.",
        "",
    ]
    (RAW_DIR / "README.md").write_text("\n".join(readme))

    print(f"catalogued {len(catalog)} raw images ({ready} game-ready, {len(catalog)-ready} candidates)")
    print(f"wrote {CATALOG.relative_to(ROOT)} and {SHEET.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

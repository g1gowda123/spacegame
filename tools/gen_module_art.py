#!/usr/bin/env python3
"""Module / buff art from diffusion raws, finished at 128 px.

The hand-drawn set was too sparse — flat icons with no personality. This path
renders each part in SDXL (pixel-art LoRA), keys the magenta sheet, despills the
edges, halves with a prefilter and locks to the game's hardware palette, so a
shop tile carries real mechanical detail at 128 px but still sits in the UI.
"""
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "assets" / "raw" / "modules"
OUT = ROOT / "assets" / "sprites" / "modules"
SHIP = OUT / "ship"
BUFF = ROOT / "assets" / "sprites" / "buffs_hd"
GEN = ROOT / "tools" / "gen_asset.py"
PY = "/home/g1/ComfyUI/.venv/bin/python"

PAL = np.array([[22, 24, 30], [40, 46, 56], [60, 68, 78], [92, 102, 114],
                [124, 136, 148], [152, 164, 176], [190, 200, 210],
                [228, 87, 46], [84, 230, 209], [232, 184, 92], [238, 242, 246]], np.float32)

PARTS = {
    # Prompts follow the actual hardware the shop name refers to, simplified to a
    # bold silhouette: two or three big shapes that still read at 40 px.
    "wheel": "reaction wheel: one large spinning flywheel disc inside a square metal housing, axle hub, four mounting bolts",
    "wheel2": "two reaction wheel discs side by side in a single reinforced housing, twin axle hubs",
    "ion": "Hall effect thruster: short ceramic cylinder with a ring shaped discharge channel glowing orange, magnetic coils, feed lines",
    "ion2": "three Hall thruster cylinders in a row on a shared manifold plate, glowing rings",
    "rtg": "radioisotope thermoelectric generator: ribbed cylinder with radial cooling fins and a domed cap",
    "rtg2": "two finned RTG canisters on one mounting plate, domed caps",
    "fuel_cell": "regenerative fuel cell: two spherical pressure tanks either side of a stack of round cell plates",
    "fuel_cell2": "four spherical tanks on a rack around a tall stack of cell plates",
    "radiator": "loop heat pipe: closed pipe loop with an evaporator block and a flat condenser plate with fins",
    "radiator2": "large radiator wing: one flat finned panel with coolant pipes down the edge and a hinge",
    "coolant": "cryocooler: compressor housing with a coiled tube and a single cold finger",
    "coolant2": "cryocooler with two cold fingers, coiled line and a compressor can",
    "armor": "Whipple shield: flat bumper plate held on four standoff struts above a second plate",
    "armor2": "a thick armour slab cut from the hull: a single rectangular panel with a honeycomb core exposed along one sawn edge, bolted corners",
    "whipple": "hull cross section slab: a rectangular cutaway showing an outer bumper plate, an empty gap, then the inner pressure wall",
    "whipple2": "hull cross section slab with three layers: two thin bumper plates with gaps and a thick inner wall, cutaway block",
    "antenna": "high gain antenna: parabolic dish on a two axis gimbal with a feed horn at the focus",
    "antenna2": "two parabolic dishes on one rotating yoke, waveguide feeds",
    "buffer": "solid state data recorder: rectangular rack unit with a front panel of eight memory card slots, a row of small green status lights and two cable connectors at the back",
    "buffer2": "two recorder boxes stacked with a cable loom between them",
    "science_pack": "mass spectrometer: cylindrical vacuum chamber with a magnet ring, sample inlet tube and a readout panel",
    "science2": "mass spectrometer with a sample carousel and two instrument boxes",
    "sensor": "sensor bay: box with three lens apertures on a rotating ring mount",
    "sensor2": "two sensor heads, wide and narrow apertures, on one gimbal",
    "salvage": "contract data chit: thick plastic card with an embossed agency seal, half inserted into a small slot reader",
    "repair": "field kit: tool case with a wrench and patch plates strapped to the lid",
}

BUFFS = {
    "reactor": "compact fission reactor core, hexagonal housing with control rods and a radiant core",
    "harden": "reinforced hull brace, armoured bracket with bolts and a diagonal strut",
    "aerogel": "aerogel insulation tile, translucent porous block in a metal frame",
    "sling": "gravity sling trajectory hardware, orbital arc ring with a tethered probe",
    "deepnet": "deep space network transceiver, phased array panel with glowing elements",
    "science": "science boost module, spectrometer with sample chamber and glowing readout",
    "favor": "agency favour token, brass medallion with a stamped rocket emblem",
    "ranger": "long range ranger module, folded antenna mast with a pennant and beacon",
    "shield": "magnetic deflector shield emitter, ring coil with a glowing field aperture",
    "cache": "supply cache crate, strapped container with a latch and stencil marks",
    "legacy": "legacy flight recorder, steel casing with a starburst emblem and rivets",
    "repair": "repair kit, tool roll with wrench, patch plates and a welding torch",
}


def gen(prompt, out, seed):
    style = ("chunky flat shading, thick dark outline, limited desaturated palette, "
             "teal and orange accents, retro science fiction game icon")
    cmd = [PY, str(GEN), prompt + ", single piece of spacecraft hardware, engineering part, " + style,
           "--out", str(out), "--size", "1024", "--gen-size", "1024",
           "--seed", str(seed), "--lora", "1.0", "--no-pixelize", "--bg", __import__("os").environ.get("MODULE_BG", "magenta"),
           "--view", "product shot, three-quarter view, centred, one isolated object on a flat magenta background that fills the frame, nothing behind it, no backing shape, flat even lighting",
           "--negative-extra", "text, watermark, logo, frame, border, hands, person, multiple objects, blurry, photo, landscape, terrain, background shape, circle behind, ring, halo, badge, emblem behind, glow, gradient background, vignette, orange background, coloured backdrop"]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def key(img, tol=0):
    """Remove the sheet, whichever colour SDXL actually put behind the part.

    Two modes, chosen from the border ring: a magenta sheet is matched by hue
    (red and blue well above green), anything else by distance to the border
    median. Either way only the sheet region connected to the border is dropped
    and the interior is hole-filled, so pale panels are not keyed away and
    specular pinholes are not punched through the part.
    """
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    h, w = a.shape[:2]
    pad = 12
    ring = np.concatenate([a[:pad, :pad].reshape(-1, 3), a[:pad, -pad:].reshape(-1, 3),
                           a[-pad:, :pad].reshape(-1, 3), a[-pad:, -pad:].reshape(-1, 3)])
    bg = np.median(ring, axis=0)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    magenta_sheet = (bg[0] > 90) and (bg[2] > 90) and (bg[1] < 0.74 * min(bg[0], bg[2]))
    bright_sheet = (bg.mean() > 140) and (bg.max() - bg.min() < 40)
    if magenta_sheet:
        sheetish = (r > 70) & (b > 70) & (g < 0.74 * np.minimum(r, b))
    elif bright_sheet:
        # SDXL often paints a white studio card instead of the magenta sheet;
        # key by whiteness, then by distance, so neither survives as a box.
        sheetish = (a.min(axis=2) > 140) & ((a.max(axis=2) - a.min(axis=2)) < 30)
        sheetish |= np.linalg.norm(a - bg, axis=2) < 26
    else:
        sheetish = np.linalg.norm(a - bg, axis=2) < 34
    lab, n = ndimage.label(sheetish)
    if n:
        border_ids = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
        bgmask = np.isin(lab, border_ids[border_ids > 0])
    else:
        bgmask = sheetish
    fg = ndimage.binary_fill_holes(~bgmask)
    # a studio card painted inside the frame survives the border key; drop any
    # large near-white/grey plate that still touches the frame edge
    pale = (a.min(axis=2) > 145) & ((a.max(axis=2) - a.min(axis=2)) < 34)
    lp, np_ = ndimage.label(pale)
    if np_:
        for lid in range(1, np_ + 1):
            comp = lp == lid
            if comp.sum() < 0.012 * comp.size:
                continue
            ys, xs = np.nonzero(comp)
            # a studio card spans a wide rectangle; object panels are small and inset
            if (ys.min() < 8 or xs.min() < 8 or ys.max() > h - 9 or xs.max() > w - 9):
                fg &= ~comp
    fg = ndimage.binary_opening(fg, iterations=1)
    lab2, n2 = ndimage.label(fg)
    if n2 > 1:
        sizes = ndimage.sum(fg, lab2, range(1, n2 + 1))
        fg = np.isin(lab2, [i + 1 for i, sz in enumerate(sizes) if sz > 0.10 * sizes.max()])
    al = np.where(fg, 255, 0).astype(np.uint8)
    rgb = a.copy()
    rim = fg & ~ndimage.binary_erosion(fg, iterations=3)
    spill = rim & (r > g + 10) & (b > g + 4)
    rgb[spill, 0] = 0.5 * rgb[spill, 0] + 0.5 * rgb[spill, 1]
    rgb[spill, 2] = 0.5 * rgb[spill, 2] + 0.5 * rgb[spill, 1]
    return Image.fromarray(np.dstack([rgb, al]).astype(np.uint8), "RGBA")


def lock_rgb(rgb):
    d = ((rgb[:, :, None, :] - PAL[None, None, :, :]) ** 2).sum(-1)
    return PAL[d.argmin(-1)].astype(np.uint8)


def finish(img, w, h, blur=1.6):
    """Crop, prefilter, halve, lock to the hardware ramp, ink the outside edge.

    Order matters: blur the *source* while it is still large (the render's fine
    rivets survive), then downscale, then lock, so the palette is applied to
    averaged colours instead of single bright pixels. Interior holes are filled
    after thresholding — the background specks inside a chassis are what made
    parts look eaten at 128 px.
    """
    bbox = img.split()[-1].getbbox()
    if bbox:
        img = img.crop(bbox)
    if blur:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    m = 2
    tw, th = w - 2 * m, h - 2 * m
    s = min(tw / img.width, th / img.height)
    img = img.resize((max(1, int(img.width * s)), max(1, int(img.height * s))), Image.Resampling.LANCZOS)
    img = img.resize((max(1, img.width // 2), max(1, img.height // 2)), Image.Resampling.LANCZOS)
    img = img.resize((img.width * 2, img.height * 2), Image.Resampling.NEAREST)
    a = np.asarray(img).astype(np.float32)
    solid = a[..., 3] >= 110
    solid = ndimage.binary_fill_holes(solid)
    solid = ndimage.binary_opening(solid, iterations=1)
    canvas = np.zeros((h, w, 4), np.uint8)
    rgb = lock_rgb(a[..., :3])
    ox, oy = (w - img.width) // 2, (h - img.height) // 2
    canvas[oy:oy + img.height, ox:ox + img.width, :3] = rgb
    canvas[oy:oy + img.height, ox:ox + img.width, 3] = solid * 255
    pad = np.pad(canvas[..., 3] > 0, 1)
    edge = (canvas[..., 3] > 0) & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    canvas[edge, :3] = (22, 24, 30)
    return Image.fromarray(canvas, "RGBA")


def main():
    RAW.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    SHIP.mkdir(parents=True, exist_ok=True)
    BUFF.mkdir(parents=True, exist_ok=True)
    args = sys.argv[1:]
    reprocess = "--reprocess" in args
    only = [a for a in args if not a.startswith("--")] or list(PARTS)
    done = []
    for i, pid in enumerate(only):
        raw = RAW / f"{pid}.png"
        if not raw.exists():
            if reprocess:
                print("skip", pid, "(no raw)")
                continue
            gen(PARTS[pid], raw, 9400 + i)
        part = finish(key(Image.open(raw)), 128, 128)
        part.save(OUT / f"{pid}.png")
        finish(key(Image.open(raw)), 64, 48, blur=1.4).save(SHIP / f"{pid}.png")
        done.append(pid)
        print("ok", pid, flush=True)
    if len(sys.argv) == 1:
        for i, (bid, prompt) in enumerate(BUFFS.items()):
            raw = RAW / f"buff_{bid}.png"
            if not raw.exists():
                gen(prompt, raw, 9700 + i)
            finish(key(Image.open(raw)), 128, 128).save(BUFF / f"{bid}.png")
        print("buffs done")
    print(f"{len(done)} modules")


if __name__ == "__main__":
    main()

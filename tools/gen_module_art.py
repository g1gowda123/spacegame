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
    "wheel": "spacecraft control moment gyroscope, gimballed spinning wheel in a titanium cage, bearing hub",
    "wheel2": "twin counter-rotating gyroscope assembly, two gimbal cages on a common trunnion, reinforced frame",
    "ion": "ion thruster engine bell, grid of accelerator rings, ceramic insulator, feed lines",
    "ion2": "clustered ion thruster array, three bell nozzles on a shared manifold, braided power feeds",
    "rtg": "radioisotope thermoelectric generator, finned cylinder with cooling vanes and a hot glowing core cap",
    "rtg2": "extended RTG stack, two finned generator cans, radiator fins and shielded housing",
    "fuel_cell": "hydrogen fuel cell module, stacked pressure vessels with brass fittings and hoses",
    "fuel_cell2": "dual fuel cell rack, two stacks of tanks and a manifold with valves and gauges",
    "radiator": "deployable radiator panel, folding honeycomb fins with coolant pipes and hinge",
    "radiator2": "double radiator wing, two hinged fin panels with coolant loops and a rotary joint",
    "coolant": "coolant reservoir sphere with pump housing, insulated pipes and pressure valve",
    "coolant2": "coolant loop assembly, twin insulated tanks, circulation pump and heat exchanger",
    "armor": "layered spacecraft hull armour plate, bolted composite panels with a jagged edge",
    "armor2": "double-spaced armour array, two bolted plate layers on standoff struts",
    "whipple": "whipple shield bumper, thin curved metal shell with standoff frame and rivets",
    "whipple2": "multi-layer whipple shield stack, three curved shells on a honeycomb frame",
    "antenna": "deep space antenna dish on a gimbal mount, ribbed parabolic reflector and feed horn",
    "antenna2": "high gain antenna array, two dishes on a rotating yoke with waveguide feeds",
    "buffer": "solid state data recorder, stacked memory modules in a ribbed chassis with status lights",
    "buffer2": "redundant data vault, twin memory bays in a shielded case with cable looms",
    "science_pack": "science instrument pallet, spectrometer, sample vial rack and sensor boom",
    "science2": "expanded science suite, two instrument boxes with lenses, a drill and sample trays",
    "sensor": "spacecraft sensor turret, multi-lens optical head on a rotating base with cable",
    "sensor2": "dual sensor turret, wide and narrow aperture heads on a shared gimbal",
    "salvage": "salvage claw mechanism, hydraulic pincer with pistons and a cutting head",
    "repair": "repair arm tool head, wrench socket and welding torch on an articulated wrist",
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
    cmd = [PY, str(GEN), prompt + ", single piece of spacecraft hardware, engineering part,",
           "--out", str(out), "--size", "1024", "--gen-size", "1024",
           "--seed", str(seed), "--lora", "0.55", "--no-pixelize", "--bg", "magenta",
           "--view", "product shot, three-quarter view, centred, isolated on flat magenta",
           "--negative-extra", "text, watermark, logo, frame, border, hands, person, multiple objects, blurry, photo, landscape, terrain"]
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
    pad = 12
    ring = np.concatenate([a[:pad, :pad].reshape(-1, 3), a[:pad, -pad:].reshape(-1, 3),
                           a[-pad:, :pad].reshape(-1, 3), a[-pad:, -pad:].reshape(-1, 3)])
    bg = np.median(ring, axis=0)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    magenta_sheet = (bg[0] > 90) and (bg[2] > 90) and (bg[1] < 0.74 * min(bg[0], bg[2]))
    if magenta_sheet:
        sheetish = (r > 70) & (b > 70) & (g < 0.74 * np.minimum(r, b))
    else:
        sheetish = np.linalg.norm(a - bg, axis=2) < 34
    lab, n = ndimage.label(sheetish)
    if n:
        border_ids = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
        bgmask = np.isin(lab, border_ids[border_ids > 0])
    else:
        bgmask = sheetish
    fg = ndimage.binary_fill_holes(~bgmask)
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
    only = sys.argv[1:] or list(PARTS)
    done = []
    for i, pid in enumerate(only):
        raw = RAW / f"{pid}.png"
        if not raw.exists():
            gen(PARTS[pid], raw, 9400 + i)
        part = finish(key(Image.open(raw)), 128, 128)
        part.save(OUT / f"{pid}.png")
        finish(key(Image.open(raw)), 64, 48, blur=1.4).save(SHIP / f"{pid}.png")
        done.append(pid)
        print("ok", pid, flush=True)
    if not sys.argv[1:]:
        for i, (bid, prompt) in enumerate(BUFFS.items()):
            raw = RAW / f"buff_{bid}.png"
            if not raw.exists():
                gen(prompt, raw, 9700 + i)
            finish(key(Image.open(raw)), 128, 128).save(BUFF / f"{bid}.png")
        print("buffs done")
    print(f"{len(done)} modules")


if __name__ == "__main__":
    main()

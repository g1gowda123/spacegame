#!/usr/bin/env python3
"""QA audit for Orbit & Outplay.

Person d (QA) owns claim-vs-evidence checks. This script verifies the parts of
the project that can be checked without a display or a Web build:

  1. project/scene wiring resolves (autoloads, ext_resources, literal res:// paths)
  2. every tile / prop / structure / transition referenced by the map generator
     actually exists, at the documented size
  3. landed-but-unwired art is listed explicitly (doc claim vs code)
  4. the exoplanet dataset still satisfies its documented invariants and the
     derived `game` values recompute from the documented formulas
  5. README tables (hulls, vehicles, instruments, objectives, modules, hazards)
     match the constants in scripts/game_state.gd and scripts/sector.gd
  6. doc drift: docs that point at files/scenes that do not exist

Usage:
    python tools/qa/audit_project.py            # write docs/QA_REPORT.md
    python tools/qa/audit_project.py --check    # exit 1 if any FAIL

The report is written to docs/QA_REPORT.md. Console prints a compact summary.
"""
from __future__ import annotations

import argparse
import json
import math
import re
import statistics
import sys
from collections import Counter, defaultdict
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover - Pillow is present in the QA env
    Image = None

ROOT = Path(__file__).resolve().parents[2]

RESULTS: list[tuple[str, str, str]] = []  # (status, check, detail)


def add(status: str, check: str, detail: str = "") -> None:
    RESULTS.append((status, check, detail))


def ok(check: str, detail: str = "") -> None:
    add("PASS", check, detail)


def fail(check: str, detail: str = "") -> None:
    add("FAIL", check, detail)


def warn(check: str, detail: str = "") -> None:
    add("WARN", check, detail)


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="replace")


def rel_exists(rel: str) -> bool:
    return (ROOT / rel).exists()


def balanced_block(text: str, start: int, open_ch: str, close_ch: str) -> str:
    """Return the balanced block starting at `start` (which must be open_ch)."""
    depth = 0
    i = start
    in_str = False
    quote = ""
    escaped = False
    while i < len(text):
        ch = text[i]
        if in_str:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == quote:
                in_str = False
            i += 1
            continue
        if ch in "\"'":
            in_str = True
            quote = ch
        elif ch == open_ch:
            depth += 1
        elif ch == close_ch:
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
        i += 1
    return text[start:]


def block_after(text: str, marker: str) -> str:
    idx = text.find(marker)
    if idx < 0:
        return ""
    open_idx = text.find("[", idx)
    brace_idx = text.find("{", idx)
    if open_idx < 0 or (0 <= brace_idx < open_idx):
        return balanced_block(text, brace_idx, "{", "}")
    return balanced_block(text, open_idx, "[", "]")


def png_size(path: Path):
    if Image is None:
        return None
    try:
        with Image.open(path) as im:
            return im.size
    except Exception:
        return None


def visible_bbox(path: Path):
    if Image is None:
        return None
    try:
        with Image.open(path) as im:
            return im.convert("RGBA").split()[-1].getbbox()
    except Exception:
        return None


# ---------------------------------------------------------------------------
# 1. project + scene wiring
# ---------------------------------------------------------------------------

def check_project() -> None:
    proj = read("project.godot")
    if 'main_scene="res://scenes/title.tscn"' in proj or 'run/main_scene="res://scenes/title.tscn"' in proj:
        ok("main scene points at scenes/title.tscn")
    else:
        m = re.search(r'run/main_scene="([^"]+)"', proj)
        (fail if not m or not rel_exists(m.group(1)[6:]) else warn)(
            "main scene", m.group(1) if m else "missing"
        )

    for path in re.findall(r'=\*?"(res://[^"]+)"', proj):
        if not rel_exists(path[6:]):
            fail("autoload/script path exists", path)
    if "gl_compatibility" in proj:
        ok("renderer = gl_compatibility")
    else:
        fail("renderer = gl_compatibility", "not found in project.godot")
    m = re.search(r"window/size/viewport_width=(\d+)", proj)
    n = re.search(r"window/size/viewport_height=(\d+)", proj)
    if m and n and (m.group(1), n.group(1)) == ("640", "360"):
        ok("logical viewport 640x360")
    else:
        fail("logical viewport 640x360", f"{m and m.group(1)}x{n and n.group(1)}")

    missing = []
    for tscn in sorted((ROOT / "scenes").glob("*.tscn")):
        text = tscn.read_text(encoding="utf-8", errors="replace")
        for path in re.findall(r'path="(res://[^"]+)"', text):
            if not rel_exists(path[6:]):
                missing.append(f"{tscn.name}: {path}")
    ok("all .tscn ext_resources resolve") if not missing else fail(
        "all .tscn ext_resources resolve", "; ".join(missing)
    )


# ---------------------------------------------------------------------------
# 2. literal res:// references in scripts
# ---------------------------------------------------------------------------

def check_literal_refs() -> None:
    missing = []
    for gd in sorted((ROOT / "scripts").rglob("*.gd")):
        text = gd.read_text(encoding="utf-8", errors="replace")
        for path in re.findall(r'"(res://[^"\\]+)"', text):
            if "%s" in path or "%d" in path or path.endswith("/"):
                continue
            if not rel_exists(path[6:]):
                missing.append(f"{gd.name}: {path}")
    if missing:
        fail("literal res:// refs resolve", f"{len(missing)} missing: " + "; ".join(missing[:8]))
    else:
        ok("literal res:// refs resolve", "scripts/*.gd")


# ---------------------------------------------------------------------------
# 3. map-generator art contract
# ---------------------------------------------------------------------------

def map_gen() -> dict:
    text = read("scripts/map_generator.gd")
    biome_block = block_after(text, "var BIOMES: Array = [")
    structures = {}
    st_block = block_after(text, "var STRUCTURES: Dictionary = {")
    for m in re.finditer(r'"([a-z_0-9]+)"\s*:\s*\{(.*?)\n\t\}', st_block, re.S):
        key, body = m.group(1), m.group(2)
        path = re.search(r'"path"\s*:\s*"(res://[^"]+)"', body)
        w = re.search(r'"w"\s*:\s*(\d+)', body)
        h = re.search(r'"h"\s*:\s*(\d+)', body)
        pieces = re.search(r'"pieces"\s*:\s*"([a-z_0-9]+)"', body)
        if path:
            structures[key] = {
                "path": path.group(1)[6:],
                "w": int(w.group(1)) if w else None,
                "h": int(h.group(1)) if h else None,
                "pieces": pieces.group(1) if pieces else "",
            }
    props = {}
    props_block = block_after(text, "const PROPS: Dictionary = {")
    for m in re.finditer(r'"([a-z_0-9]+)"\s*:\s*\[([^\]]*)\]', props_block):
        props[m.group(1)] = re.findall(r'"([a-z_0-9]+)"', m.group(2))
    tile_keys = set(re.findall(r'"([a-z0-9_]+/[a-z0-9_]+)"', biome_block))
    return {
        "text": text,
        "tile_keys": tile_keys,
        "structures": structures,
        "props": props,
    }


def check_map_art(mg: dict) -> None:
    bad = []
    for key in sorted(mg["tile_keys"]):
        path = ROOT / "assets" / "tilesets" / f"{key}.png"
        if not path.exists():
            bad.append(f"missing tile {key}.png")
            continue
        size = png_size(path)
        if size != (64, 64):
            bad.append(f"{key}.png is {size}, expected (64, 64)")
    if bad:
        fail("map tile keys resolve at 64x64", f"{len(bad)} problem(s): " + "; ".join(bad[:10]))
    else:
        ok("map tile keys resolve at 64x64", f"{len(mg['tile_keys'])} keys")

    bad, notes = [], []
    # Piece-backed structures (massif_4x4, volcano_4x4) are drawn from cut
    # pieces at unit_px per tile; the single `path` PNG is only a fallback when
    # the manifest is missing. Validate the piece set's footprint instead.
    piece_sets = {}
    piece_manifest = ROOT / "assets/tilesets/structures/pieces/manifest.json"
    if piece_manifest.exists():
        try:
            piece_sets = json.loads(piece_manifest.read_text(encoding="utf-8")).get("sets", {})
        except ValueError:
            piece_sets = {}
    for key, info in sorted(mg["structures"].items()):
        path = ROOT / info["path"]
        if not path.exists():
            bad.append(f"missing structure {key} -> {info['path']}")
            continue
        set_name = str(info.get("pieces", ""))
        if set_name and set_name in piece_sets:
            fp = piece_sets[set_name].get("footprint", [])
            if list(fp) != [info["w"], info["h"]]:
                bad.append(f"{key}: piece set {set_name} footprint {fp} vs code {info['w']}x{info['h']}")
            continue
        size = png_size(path)
        if not (info["w"] and info["h"] and size):
            continue
        if info["w"] * info["h"] > 1:
            want = (info["w"] * 64, info["h"] * 64)
            if size != want:
                bad.append(f"{key}: {size} vs footprint {want}")
        elif size != (64, 64):
            # 1x1 structures may use a 128 canvas for height, but the visible
            # width must still read as one cell or the footprint lies.
            vis = visible_bbox(path)
            if vis and (vis[2] - vis[0]) > 96:
                notes.append(f"{key}: 1x1 footprint, {size} canvas, visible width {vis[2] - vis[0]} px")
    if bad:
        fail("structure files + footprints", "; ".join(bad))
    else:
        ok("structure files + footprints", f"{len(mg['structures'])} structures")
    if notes:
        warn("1x1 structure art fits its footprint", "; ".join(notes))

    bad = []
    for biome, names in sorted(mg["props"].items()):
        for name in names:
            path = ROOT / "assets" / "props" / f"{name}.png"
            if not path.exists():
                bad.append(f"missing prop {name} ({biome})")
                continue
            size = png_size(path)
            if size and max(size) > 64:
                bad.append(f"prop {name} is {size}, contract is 32-64 px")
    if bad:
        fail("biome props resolve (32-64 px)", "; ".join(bad))
    else:
        ok("biome props resolve (32-64 px)", f"{len(mg['props'])} biomes")

    # transitions
    pairs = []
    tpath = ROOT / "tools" / "transitions.json"
    if tpath.exists():
        pairs = json.loads(tpath.read_text(encoding="utf-8")).get("pairs", [])
    bad = []
    for pair in pairs:
        a, b = pair
        a_name, b_name = a.split("/")[-1], b.split("/")[-1]
        d = ROOT / "assets" / "tilesets" / "transitions" / f"{a_name}_{b_name}"
        if not d.is_dir():
            bad.append(f"missing dir {d.name}")
            continue
        for side in ("west", "east", "north", "south"):
            p = d / f"{a_name}_{side}.png"
            if not p.exists():
                bad.append(f"missing {d.name}/{p.name}")
            elif png_size(p) != (64, 64):
                bad.append(f"{d.name}/{p.name} size {png_size(p)}")
    if bad:
        fail("transition sets complete", f"{len(bad)} problem(s): " + "; ".join(bad[:8]))
    else:
        ok("transition sets complete", f"{len(pairs)} pairs x 4 edge tiles")

    diag = sorted((ROOT / "assets" / "tilesets" / "transitions" / "diagonal").glob("*_*"))
    bad = []
    for d in diag:
        if not d.is_dir():
            continue
        for corner in ("nw", "ne", "se", "sw"):
            p = d / f"{corner}.png"
            if not p.exists():
                bad.append(f"{d.name}/{corner}.png")
            elif png_size(p) != (64, 64):
                bad.append(f"{d.name}/{corner}.png size {png_size(p)}")
    if bad:
        fail("diagonal split sets complete", "; ".join(bad))
    else:
        ok("diagonal split sets complete", f"{len(diag)} pairs")


def check_art_wiring(mg: dict) -> None:
    """The board repeatedly said families were 'landed but inert'. Verify."""
    text = mg["text"]
    families = {
        "diagonal shore splits": "diag|",
        "cliff tiles (art)": "cliffs/",
        "river autotile (art)": "rivers/",
        "ridge_wide": "ridge_wide",
        "mountain_massif": "mountain_massif",
        "sandstone_arch": "sandstone_arch",
        "glacier_wall": "glacier_wall",
        "crystal_spire": "crystal_spire",
        "canyon_bridge": "canyon_bridge",
        "ash_mound": "ash_mound",
        "crystal_nub": "crystal_nub",
        "ice_teeth": "ice_teeth",
        "shell_spiral": "shell_spiral",
        "coral_spire": "coral_spire",
        "arid/dunes_ripple": "dunes_ripple",
        "crystal/shard_field": "shard_field",
        "barren/ejecta": "ejecta",
        "volcanic/lava_core": "lava_core",
        "sulfur/acid_pool": "acid_pool",
        "ammonia/slush": "slush",
        "obsidian/glass_plate": "glass_plate",
        "ocean/reef_chain": "reef_chain",
        "cryo/ice_plate": "ice_plate",
        "water_lake_shallow": "water_lake_shallow",
        "water_foam": "water_foam",
        "water_shelf": "water_shelf",
        "lava_crust": "lava_crust",
        "lava_glow": "lava_glow",
        "ice_cracked": "ice_cracked",
        "ice_thin": "ice_thin",
    }
    wired, inert = [], []
    for label, token in families.items():
        (wired if token in text else inert).append(label)
    detail = f"wired: {', '.join(wired) or 'none'}"
    if inert:
        warn("art wiring (code references)", f"INERT: {', '.join(inert)} | {detail}")
    else:
        ok("art wiring (code references)", detail)

    # props that exist on disk but are not in any PROPS list
    prop_names = sorted({n for names in mg["props"].values() for n in names})
    on_disk = sorted(p.stem for p in (ROOT / "assets" / "props").glob("*.png")
                     if not p.stem.endswith("_preview") and not p.stem.endswith("_crop"))
    unused = [n for n in on_disk if n not in prop_names]
    if unused:
        warn("props on disk but not placed", ", ".join(unused))
    else:
        ok("props on disk but not placed", "none")


# ---------------------------------------------------------------------------
# 4. dataset
# ---------------------------------------------------------------------------

def recompute(p: dict) -> dict:
    teq = float(p["eq_temp_k"])
    radius = float(p["radius_earth"])
    gravity_g = float(p["gravity_g"])
    teff = p.get("star_temp_k")
    age = p.get("star_age_gyr")
    insol = p.get("insolation_earth")
    n_planets = int(p.get("system_planets") or 1)
    dist_ly = float(p["distance_ly"])

    def clamp(v, lo, hi):
        return max(lo, min(hi, v))

    heat = int(clamp((teq - 140.0) / 8.0, 4, 100))
    rad = 12.0
    if age is not None and age < 1.0:
        rad += 32
    elif age is not None and age < 3.0:
        rad += 16
    if teff and teff > 6200:
        rad += 14
    if teff and teff < 3900:
        rad += 8
    if insol and insol > 10:
        rad += 10
    rad = int(clamp(rad, 10, 95))
    comms = 0 if dist_ly < 20 else 5 if dist_ly < 50 else 10 if dist_ly < 120 else 18 if dist_ly < 350 else 25
    science = 55
    if 180 <= teq <= 330:
        science += 28
    if radius <= 1.65:
        science += 16
    if n_planets >= 3:
        science += 8
    if teff and 4200 <= teff <= 6800:
        science += 6
    science = int(clamp(science, 40, 120))
    dv = int(clamp(round(36 - gravity_g * 2.5 - heat * 0.05 - rad * 0.08), 18, 36))
    sols = int(clamp(round(34 - abs(teq - 280) / 55.0), 22, 36))
    quake = int(clamp((gravity_g - 0.8) * 45.0, 0, 55))
    return {"heat": heat, "radiation": rad, "comms_loss": comms,
            "science": science, "delta_v": dv, "sols": sols, "quakes": quake}


def check_dataset() -> None:
    path = ROOT / "data" / "exoplanets.json"
    if not path.exists():
        fail("dataset exists", "data/exoplanets.json missing")
        return
    data = json.loads(path.read_text(encoding="utf-8"))
    planets = data.get("planets", [])
    meta = data.get("meta", {})
    if len(planets) == 72 and meta.get("count") == 72:
        ok("dataset size = 72 curated planets")
    else:
        fail("dataset size = 72 curated planets", f"{len(planets)} rows, meta.count={meta.get('count')}")

    ids = [p.get("id") for p in planets]
    dupes = [k for k, v in Counter(ids).items() if v > 1]
    ok("planet ids unique") if not dupes else fail("planet ids unique", ", ".join(dupes))

    radii = [float(p["radius_earth"]) for p in planets]
    if min(radii) >= 0.35 and max(radii) <= 2.2:
        ok("radius range inside 0.35-2.2 R_earth", f"{min(radii):.2f}-{max(radii):.2f}")
    else:
        fail("radius range inside 0.35-2.2 R_earth", f"{min(radii):.2f}-{max(radii):.2f}")

    # mass estimate rule + physical sanity
    bad = []
    for p in planets:
        r, m = float(p["radius_earth"]), float(p["mass_earth"])
        if r <= 0 or m <= 0:
            bad.append(f"{p['id']}: non-positive mass/radius")
            continue
        if m / r ** 3 > 3.0 + 1e-6 and not p.get("mass_est"):
            bad.append(f"{p['id']}: density {m / r ** 3:.2f} not flagged mass_est")
        if p.get("mass_est") and abs(m - r ** 2.06) > 0.02:
            bad.append(f"{p['id']}: mass_est value {m} != Chen&Kipping {r ** 2.06:.2f}")
    if bad:
        fail("mass validity / Chen-Kipping rule", "; ".join(bad[:8]))
    else:
        ok("mass validity / Chen-Kipping rule",
           f"{sum(1 for p in planets if p.get('mass_est'))} estimated masses")

    required = ["id", "name", "biome", "eq_temp_k", "radius_earth", "gravity_g",
                "distance_ly", "game"]
    bad = [p.get("id", "?") for p in planets if any(k not in p for k in required)]
    ok("required fields present") if not bad else fail("required fields present", ", ".join(bad))

    biomes = {p["biome"] for p in planets}
    known = {"temperate", "arid", "cryo", "volcanic", "ocean", "barren",
             "methane", "iron", "sulfur", "crystal", "obsidian", "ammonia", "carbon"}
    if biomes <= known:
        ok("biomes valid", ", ".join(sorted(biomes)))
    else:
        fail("biomes valid", ", ".join(sorted(biomes - known)))

    # derived values recompute (tolerate rounding of stored inputs)
    tol = {"heat": 1, "quakes": 1, "delta_v": 1, "sols": 1}
    bad = defaultdict(list)
    for p in planets:
        want = recompute(p)
        for key, val in want.items():
            got = (p.get("game") or {}).get(key)
            if got is None:
                bad[key].append(f"{p['id']}: missing")
            elif abs(int(got) - int(val)) > tol.get(key, 0):
                bad[key].append(f"{p['id']}: {got} vs {val}")
    if bad:
        detail = "; ".join(f"{k}: {len(v)} mismatch(es) e.g. {v[0]}" for k, v in bad.items())
        fail("derived game values recompute", detail)
    else:
        ok("derived game values recompute", "heat/rad/science/dv/comms/sols/quakes within rounding tolerance")

    raw = ROOT / "data" / "pscomppars_raw.csv"
    if raw.exists():
        rows = max(0, sum(1 for _ in raw.open(encoding="utf-8", errors="replace")) - 1)
        if rows == 5801:
            ok("raw archive snapshot rows", "5,801")
        else:
            warn("raw archive snapshot rows", f"{rows:,} (README says 5,801)")
    else:
        fail("raw archive snapshot exists", "data/pscomppars_raw.csv missing")


# ---------------------------------------------------------------------------
# 5. README claim checks
# ---------------------------------------------------------------------------

def table_rows(text: str, heading: str) -> list[list[str]]:
    idx = text.find(heading)
    if idx < 0:
        return []
    chunk = text[idx:idx + 6000]
    rows = []
    for line in chunk.splitlines():
        s = line.strip()
        if s.startswith("|") and s.endswith("|"):
            cells = [c.strip() for c in s.strip("|").split("|")]
            if all(re.fullmatch(r":?-{2,}:?", c) for c in cells if c) or not cells:
                continue
            rows.append(cells)
        elif rows and not s.startswith("|"):
            break
    return rows[1:] if rows else []  # drop header


def num(s: str):
    s = s.replace("−", "-").replace("–", "-").replace("$", "").replace(",", "")
    s = s.replace("kg", "").replace("M", "").replace("%", "").strip()
    m = re.search(r"-?\d+(?:\.\d+)?", s)
    return float(m.group()) if m else None


def check_readme() -> None:
    readme = read("README.md")
    gs = read("scripts/game_state.gd")

    # hulls
    hull_block = block_after(gs, "const HULLS := [")
    hulls = {}
    for chunk in re.split(r"\n\t\},", hull_block):
        name = re.search(r'"name"\s*:\s*"([A-Z ]+)"', chunk)
        if not name:
            continue
        def g(k):
            m = re.search(rf'"{k}"\s*:\s*(-?[\d.]+)', chunk)
            return float(m.group(1)) if m else None
        hulls[name.group(1).title()] = {
            "mass": g("mass"), "cost": g("cost"), "power": g("power_gen"),
            "dv": g("delta_v"), "integrity": g("integrity"),
            "data": g("data_cap"), "thermal": g("thermal_res"),
            "move": g("move_range"),
        }
    rows = table_rows(readme, "### Hulls")
    bad, checked = [], 0
    for cells in rows:
        if len(cells) < 10 or not cells[0].startswith("**"):
            continue
        name = cells[0].strip("* ").title()
        if name not in hulls:
            bad.append(f"{name}: not in game_state.gd")
            continue
        h = hulls[name]
        checks = {
            "mass": (num(cells[2]), h["mass"]), "cost": (num(cells[3]), h["cost"]),
            "power": (num(cells[4]), h["power"]), "dv": (num(cells[5]), h["dv"]),
            "integrity": (num(cells[6]), h["integrity"]), "data": (num(cells[7]), h["data"]),
            "thermal": (num(cells[8]), h["thermal"]), "move": (num(cells[9]), h["move"]),
        }
        for field, (doc, code) in checks.items():
            checked += 1
            if doc is None or code is None or doc != code:
                bad.append(f"{name}.{field}: README {doc} vs code {code}")
    ok("README hull table matches code", f"{checked} values") if not bad else fail(
        "README hull table matches code", "; ".join(bad))

    # vehicles
    veh_block = block_after(gs, "const VEHICLES := [")
    vehicles = {}
    for m in re.finditer(r'"name"\s*:\s*"([A-Z ]+)".*?"cost"\s*:\s*([\d.]+).*?"capacity"\s*:\s*([\d.]+)', veh_block, re.S):
        vehicles[m.group(1).title()] = (float(m.group(2)), float(m.group(3)))
    rows = table_rows(readme, "### Launch vehicles and orbits")
    bad = []
    for cells in rows:
        if len(cells) < 4 or not cells[0].startswith("**"):
            continue
        name = cells[0].strip("* ").title()
        if name not in vehicles:
            bad.append(f"{name}: not in code")
            continue
        cost, cap = vehicles[name]
        if (num(cells[1]), num(cells[2])) != (cost, cap):
            bad.append(f"{name}: README {(num(cells[1]), num(cells[2]))} vs code {(cost, cap)}")
    ok("README launch vehicle table matches code") if not bad else fail(
        "README launch vehicle table matches code", "; ".join(bad))

    # instruments
    ins_block = block_after(gs, "const INSTRUMENTS := [")
    instruments = {}
    for chunk in re.split(r"\n\t\},", ins_block):
        name = re.search(r'"name"\s*:\s*"([A-Z ]+)"', chunk)
        if not name:
            continue
        def g(k):
            m = re.search(rf'"{k}"\s*:\s*([\d.]+)', chunk)
            return float(m.group(1)) if m else None
        instruments[name.group(1).title()] = (g("mass"), g("cost"), g("power"))
    rows = table_rows(readme, "### Instruments")
    bad, checked = [], 0
    for cells in rows:
        if len(cells) < 4 or not cells[0].startswith("**"):
            continue
        name = cells[0].strip("* ").title()
        if name not in instruments:
            bad.append(f"{name}: not in code")
            continue
        checked += 1
        if (num(cells[1]), num(cells[2]), num(cells[3])) != instruments[name]:
            bad.append(f"{name}: README {(num(cells[1]), num(cells[2]), num(cells[3]))} vs code {instruments[name]}")
    if bad:
        fail("README instrument table matches code", "; ".join(bad))
    else:
        ok("README instrument table matches code", f"{checked} instruments")

    # objectives
    obj_block = block_after(gs, "const OBJECTIVES := [")
    objectives = {}
    for chunk in re.split(r"\n\t\},", obj_block):
        name = re.search(r'"name"\s*:\s*"([A-Z ]+)"', chunk)
        if not name:
            continue
        q = re.search(r'"quota"\s*:\s*(\d+)', chunk)
        objectives[name.group(1).title()] = int(q.group(1)) if q else None
    rows = table_rows(readme, "### Objectives")
    bad = []
    for cells in rows:
        if len(cells) < 2 or not cells[0].startswith("**"):
            continue
        name = cells[0].strip("* ").title()
        if name not in objectives:
            bad.append(f"{name}: not in code")
        elif num(cells[1]) != objectives[name]:
            bad.append(f"{name}: quota README {num(cells[1])} vs code {objectives[name]}")
    ok("README objective quotas match code") if not bad else fail(
        "README objective quotas match code", "; ".join(bad))

    # modules / upgrades
    up_block = block_after(gs, "const UPGRADES := [")
    upgrades = {}
    for m in re.finditer(r'"name"\s*:\s*"([A-Z -]+)"\s*,\s*"cost"\s*:\s*([\d.]+)', up_block):
        upgrades[m.group(1).title()] = float(m.group(2))
    rows = table_rows(readme, "## Debrief and refit")
    bad = []
    for cells in rows:
        if len(cells) < 2 or not cells[0].startswith("**"):
            continue
        name = cells[0].strip("* ").title()
        if name not in upgrades:
            bad.append(f"{name}: not in code (renamed?)")
        elif num(cells[1]) != upgrades[name]:
            bad.append(f"{name}: cost README {num(cells[1])} vs code {upgrades[name]}")
    ok("README refit module table matches code") if not bad else fail(
        "README refit module table matches code", "; ".join(bad))

    # radiator description vs actual effect
    rad = re.search(r'"name"\s*:\s*"DEPLOYABLE RADIATOR".*?"desc"\s*:\s*"([^"]+)".*?"thermal_res"\s*:\s*(\d+)', up_block, re.S)
    if rad:
        said = rad.group(1)
        value = int(rad.group(2))
        heat_gain = re.search(r'var heat_gain := int\(round\(float\(heat\) \* 0\.11\)\) - int\(s\["thermal_res"\]\)', gs)
        if "3" in said and heat_gain and value == 6:
            warn("radiator label matches effect",
                 f'label says "{said}" but thermal_res={value} subtracts {value} heat per move')
        else:
            ok("radiator label matches effect", f'{said} (thermal_res={value})')

    # hazards
    sec = read("scripts/sector.gd")
    haz_block = block_after(sec, "const HAZARDS := {")
    hazards = {}
    for m in re.finditer(r'"([a-z_]+)"\s*:\s*\{(.*?)\n\t\}', haz_block, re.S):
        body = m.group(2)
        name = re.search(r'"name"\s*:\s*"([A-Z ]+)"', body)
        if not name:
            continue
        def g(k):
            mm = re.search(rf'"{k}"\s*:\s*(-?\d+)', body)
            return int(mm.group(1)) if mm else None
        blk = re.search(r'"block"\s*:\s*(true|false)', body)
        hazards[name.group(1).title()] = {
            "block": blk.group(1) == "true" if blk else None,
            "integrity": g("integrity"), "thermal": g("thermal"), "dv": g("dv"),
        }
    rows = table_rows(readme, "### Hazards")
    bad, checked = [], 0
    for cells in rows:
        if len(cells) < 5 or not cells[0].startswith("**"):
            continue
        name = cells[0].strip("* ").title()
        if name not in hazards:
            bad.append(f"{name}: not in sector.gd")
            continue
        h = hazards[name]
        checked += 1
        doc_block = cells[1].strip().lower() == "yes"
        if doc_block != h["block"]:
            bad.append(f"{name}: block README {doc_block} vs code {h['block']}")
        for field, col in (("integrity", 2), ("thermal", 3), ("dv", 4)):
            doc = num(cells[col])
            doc = 0 if doc is None else abs(doc)
            code = abs(h[field] or 0)
            if doc != code:
                bad.append(f"{name}.{field}: README {doc} vs code {code}")
    if bad:
        fail("README hazard table matches code", "; ".join(bad))
    else:
        ok("README hazard table matches code", f"{checked} hazards")

    # run constants
    constants = {
        "START_BUDGET := 500.0": "$500M budget",
        "START_APPROVAL := 62": "approval starts at 62",
        "SECTORS_PER_RUN := 3": "3 sectors per run",
    }
    bad = [label for needle, label in constants.items() if needle not in gs]
    ok("README run constants match code") if not bad else fail(
        "README run constants match code", ", ".join(bad))
    if "-24" in readme and "-24.0" not in gs and "- 24" not in gs and "24" in gs:
        pass  # approval loss is applied in finish_sector; checked separately below
    fail_pen = re.search(r"approval.*?-\s*24|-\s*24.*?approval", readme)
    code_pen = re.search(r"approval.*?-\s*(\d+)", gs)
    if fail_pen and code_pen and code_pen.group(1) == "24":
        ok("README approval penalty matches code", "-24 per failed sector")


# ---------------------------------------------------------------------------
# 6. doc drift
# ---------------------------------------------------------------------------

def check_docs(mg: dict) -> None:
    proj = read("project.godot")
    main = re.search(r'run/main_scene="res://([^"]+)"', proj)
    main_scene = main.group(1) if main else "?"
    map_doc = read("docs/MAP_GENERATOR.md")
    if "Main scene: `scenes/map_generator.tscn`" in map_doc and main_scene != "scenes/map_generator.tscn":
        warn("MAP_GENERATOR.md is current",
             f"doc calls scenes/map_generator.tscn the main scene; project.godot main_scene={main_scene}")
    else:
        ok("MAP_GENERATOR.md main-scene claim")

    # docs that mention build artifacts that are intentionally absent from git
    missing_artifacts = []
    for doc in ("README.md", "docs/PROJECT.md", "docs/TASKS.md", "docs/SUBMISSION.md"):
        text = read(doc)
        for p in re.findall(r"(build/web/[\w./-]+|submission/[\w./-]+)", text):
            if not rel_exists(p):
                missing_artifacts.append(f"{doc}: {p}")
    if missing_artifacts:
        warn("build artifacts referenced by docs exist in this clone",
             f"{len(set(missing_artifacts))} path(s) absent (build/ and submission/ are gitignored): "
             + "; ".join(sorted(set(missing_artifacts))[:6]))
    else:
        ok("build artifacts referenced by docs exist in this clone")

    # doc-stated tile counts
    tmap = read("docs/TASKS.md")
    m = re.search(r"(\d+) transition pairs", tmap)
    pairs = json.loads((ROOT / "tools" / "transitions.json").read_text(encoding="utf-8")).get("pairs", [])
    if m:
        if int(m.group(1)) == len(pairs):
            ok("TASKS transition-pair count matches transitions.json", f"{len(pairs)}")
        else:
            fail("TASKS transition-pair count matches transitions.json",
                 f"doc {m.group(1)} vs json {len(pairs)}")


# ---------------------------------------------------------------------------
# report
# ---------------------------------------------------------------------------

def write_report() -> int:
    passed = sum(1 for s, _, _ in RESULTS if s == "PASS")
    failed = sum(1 for s, _, _ in RESULTS if s == "FAIL")
    warned = sum(1 for s, _, _ in RESULTS if s == "WARN")
    lines = [
        "# QA Report — Orbit & Outplay",
        "",
        "Owner: **d** (QA). Generated by `tools/qa/audit_project.py`.",
        "This report covers claim-vs-evidence checks that do not need a display or a",
        "Web build. Browser-loop results live in `docs/BOARD.md` / the work log.",
        "",
        f"**Summary: {passed} pass, {failed} fail, {warned} warn.**",
        "",
        "| Status | Check | Detail |",
        "|---|---|---|",
    ]
    for status, check, detail in RESULTS:
        d = detail.replace("|", "\\|").replace("\n", " ")
        if len(d) > 320:
            d = d[:317] + "..."
        lines.append(f"| {status} | {check} | {d} |")
    lines += [
        "",
        "## How to re-run",
        "",
        "```bash",
        "python tools/qa/audit_project.py --check   # non-zero exit on FAIL",
        "```",
        "",
        "## What this audit does not cover",
        "",
        "- Live rendering, input handling, and browser/WebGL behaviour.",
        "- Visual quality (ORION's full-frame audit owns that).",
        "- The Web build itself: `build/` is gitignored and absent from a fresh clone.",
        "",
    ]

    # Keep the hand-written findings block across regenerations: everything from
    # the marker down is authored by QA, not by this script.
    report = ROOT / "docs" / "QA_REPORT.md"
    manual = ""
    if report.exists():
        old = report.read_text(encoding="utf-8")
        marker = "<!-- findings -->"
        if marker in old:
            manual = old[old.index(marker):].rstrip()
    if manual:
        lines += [manual, ""]
    report.write_text("\n".join(lines), encoding="utf-8")
    return failed


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="exit non-zero on FAIL")
    args = ap.parse_args()

    check_project()
    check_literal_refs()
    mg = map_gen()
    check_map_art(mg)
    check_art_wiring(mg)
    check_dataset()
    check_readme()
    check_docs(mg)

    failed = write_report()
    passed = sum(1 for s, _, _ in RESULTS if s == "PASS")
    warned = sum(1 for s, _, _ in RESULTS if s == "WARN")
    print(f"QA audit: {passed} pass, {failed} fail, {warned} warn -> docs/QA_REPORT.md")
    for status, check, detail in RESULTS:
        if status != "PASS":
            print(f"  {status:4} {check}: {detail}")
    return 1 if (args.check and failed) else 0


if __name__ == "__main__":
    sys.exit(main())

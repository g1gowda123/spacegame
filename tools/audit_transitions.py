#!/usr/bin/env python3
"""Audit terrain-transition coverage against the biome table in map_generator.gd.

Every pair of materials that can touch inside a biome needs a transition set in
assets/tilesets/transitions/<a>_<b>/ (named by the file stem) and an entry in
tools/transitions.json, otherwise the map generator falls back to a hard edge.

Usage:  python tools/audit_transitions.py [--fix] [--json out.json]
  --fix   add the missing pairs to tools/transitions.json (does NOT generate art;
          run gen_transition.py for each listed pair, or tools/gen_missing.sh)
Exit code 1 when coverage is incomplete, 0 when clean.
"""
from __future__ import annotations

import argparse
import itertools
import json
import re
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCENE = ROOT / "scripts" / "map_generator.gd"
PAIRS = ROOT / "tools" / "transitions.json"
TRANS = ROOT / "assets" / "tilesets" / "transitions"
FIELDS = (
    "base", "base_alt", "detail", "detail_alt", "detail_alt2", "detail_alt3",
    "rock", "rock_alt", "shore", "water",
)


def biome_blocks(src: str) -> list[tuple[str, list[str]]]:
    body = src.split("var BIOMES", 1)[1].split("var STRUCTURES", 1)[0]
    out = []
    for bid, chunk in re.findall(r'\{\s*"id": "([^"]+)"(.*?)\n\t\}', body, re.S):
        mats = sorted({v for k, v in re.findall(r'"(\w+)": "([a-z_]+/[a-z_0-9]+)"', chunk) if k in FIELDS})
        out.append((bid, mats))
    return out


def set_name(a: str, b: str) -> str:
    return f"{a.split('/')[1]}_{b.split('/')[1]}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--fix", action="store_true")
    ap.add_argument("--json")
    args = ap.parse_args()

    src = SCENE.read_text()
    pairs = json.loads(PAIRS.read_text())["pairs"]
    listed = {tuple(sorted(p)) for p in pairs}
    have = {p.name for p in TRANS.iterdir() if p.is_dir()} if TRANS.exists() else set()

    missing: dict[tuple[str, str], int] = {}
    uncovered_biomes: dict[str, list[tuple[str, str]]] = {}
    for bid, mats in biome_blocks(src):
        for a, b in itertools.combinations(mats, 2):
            if set_name(a, b) in have or set_name(b, a) in have:
                continue
            key = tuple(sorted((a, b)))
            missing[key] = zlib.crc32((a + "|" + b).encode()) % 100000
            uncovered_biomes.setdefault(bid, []).append(key)

    print(f"biomes: {len(biome_blocks(src))}  pairs listed: {len(listed)}  tile sets on disk: {len(have)}")
    if not missing:
        print("transition coverage: COMPLETE")
        return 0

    print(f"transition coverage: {len(missing)} missing pair(s)")
    for bid, keys in sorted(uncovered_biomes.items()):
        print(f"  {bid}: {len(keys)}")
    for a, b in sorted(missing):
        print(f"  {a} <-> {b}   (seed {missing[(a, b)]})")

    if args.fix:
        listed |= set(missing)
        PAIRS.write_text(json.dumps({"pairs": [list(p) for p in sorted(listed)]}, indent=2) + "\n")
        print(f"wrote {len(listed)} pairs to {PAIRS.relative_to(ROOT)}")
    if args.json:
        Path(args.json).write_text(json.dumps(
            {"missing": sorted([list(k) + [v] for k, v in missing.items()]),
             "biomes": {k: [list(x) for x in v] for k, v in uncovered_biomes.items()}}, indent=2) + "\n")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

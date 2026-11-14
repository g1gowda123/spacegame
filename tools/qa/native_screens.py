#!/usr/bin/env python3
"""Native screen-capture QA for Orbit & Outplay (person d).

Runs the real game with Godot, deep-links into every screen through DevRouter,
saves a frame per screen, and fails on engine/script errors or blank captures.

This is the native counterpart to browser_loop.mjs. It needs a Godot 4.7.2
binary and a display (it renders a window); a Web build is not required.

Usage:
    python tools/qa/native_screens.py --godot "C:/path/to/godot_console.exe"
    python tools/qa/native_screens.py --godot ... --out qa/artifacts/native

Exit code: 0 = every screen captured cleanly, 1 = a screen failed.
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    Image = None

ROOT = Path(__file__).resolve().parents[2]
PROJECT_NAME = "Orbit & Outplay \u2014 Exoplanet Survey"  # user:// folder uses an em dash
SCREENS = [
    ("title", "title", []),
    ("design", "design", []),
    ("draft", "draft", []),
    ("sector", "sector", []),
    ("sector_success", "sector", ["--result=success"]),
    ("sector_fail", "sector", ["--result=fail"]),
    ("debrief", "debrief", []),
    ("report", "report", []),
]
BLANK_ERRORS = ("ERROR", "SCRIPT ERROR", "leaked", "still in use")


def user_dir() -> Path:
    if os.name == "nt":
        base = Path(os.environ["APPDATA"]) / "Godot" / "app_userdata"
    elif sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support" / "Godot" / "app_userdata"
    else:
        base = Path.home() / ".local" / "share" / "godot" / "app_userdata"
    return base / PROJECT_NAME


def run(godot: str, screen: str, extra: list[str], name: str, timeout: int = 120) -> tuple[int, str]:
    args = [godot, "--path", str(ROOT), f"--screen={screen}", "--capture",
            f"--capture-name={name}"]
    if extra:
        args += ["--"] + extra
    proc = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


def image_ok(path: Path) -> tuple[bool, str]:
    if not path.exists():
        return False, "missing"
    if path.stat().st_size < 5000:
        return False, f"tiny file ({path.stat().st_size} bytes)"
    if Image is None:
        return True, "ok (Pillow unavailable: size only)"
    with Image.open(path) as im:
        rgb = im.convert("RGB")
        colors = len(set(rgb.getdata()))
        extrema = rgb.getextrema()
    if colors < 24:
        return False, f"near-blank ({colors} colours)"
    if all(lo == hi for lo, hi in extrema):
        return False, "single-colour frame"
    return True, f"{im.size[0]}x{im.size[1]}, {colors} colours"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default=os.environ.get("GODOT", "godot"),
                    help="Godot 4.7.2 executable (console build recommended on Windows)")
    ap.add_argument("--out", default=str(ROOT / "qa" / "artifacts" / "native"))
    ap.add_argument("--no-import", action="store_true",
                    help="skip the one-time --import pass")
    args = ap.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    if not (ROOT / ".godot").exists() and not args.no_import:
        print("first run: importing assets / building the global class cache ...")
        subprocess.run([args.godot, "--headless", "--path", str(ROOT), "--import"],
                       cwd=ROOT, capture_output=True, text=True, timeout=900)

    failures = []
    for name, screen, extra in SCREENS:
        code, log = run(args.godot, screen, extra, f"qa_{name}")
        cap_src = user_dir() / f"qa_{name}.png"
        dst = out / f"qa_{name}.png"
        if cap_src.exists():
            shutil.copyfile(cap_src, dst)
            cap_src.unlink(missing_ok=True)
        ok_img, note = image_ok(dst)
        bad_lines = [ln.strip() for ln in log.splitlines() if any(e in ln for e in ("ERROR", "SCRIPT ERROR", "leaked", "still in use"))]
        status = "PASS" if code == 0 and ok_img and not bad_lines else "FAIL"
        if status == "FAIL":
            failures.append(name)
        print(f"{status} {name:15} exit={code} image={note}")
        for ln in bad_lines[:4]:
            print(f"       {ln}")

    print(f"\n{len(SCREENS) - len(failures)}/{len(SCREENS)} screens pass -> {out}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())

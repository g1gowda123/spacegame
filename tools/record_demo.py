#!/usr/bin/env python3
"""Record the Orbit & Outplay demo from one continuous playthrough.

The old demo path (`tools/make_demo.py`) laid debug screenshots on a timeline.
This wrapper records real motion instead:

1. Godot Movie Maker mode renders a deterministic run at a fixed 30 fps and
   writes `demo/capture/raw.avi` (MJPEG, 1280x720). `scripts/demo_director.gd`
   drives the run and writes `markers.json` with the beat boundaries.
2. `tools/make_demo_from_capture.py` cuts each beat to a target length, burns
   the caption bar, muxes the ambient pad, and writes
   `demo/orbit_outplay_demo.mp4`.

Usage:
    python tools/record_demo.py                 # full capture + assemble
    python tools/record_demo.py --fast          # 1/4-length pacing, for testing
    python tools/record_demo.py --raw-only      # capture only, keep the AVI
    python tools/record_demo.py --godot <path>  # explicit Godot binary

Requires Godot 4.7.2 and ffmpeg on PATH.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CAPTURE = ROOT / "demo" / "capture"
RAW = CAPTURE / "raw.avi"
MARKERS = CAPTURE / "markers.json"
OUT = ROOT / "demo" / "orbit_outplay_demo.mp4"

GODOT_CANDIDATES = [
    "godot",
    "godot4",
    "godot.exe",
    "Godot_v4.7.2-stable_win64_console.exe",
    "Godot_v4.7.2-stable_win64.exe",
]


def find_godot(explicit: str | None) -> str:
    if explicit:
        p = Path(explicit)
        if p.exists():
            return str(p)
        print(f"error: --godot path not found: {explicit}", file=sys.stderr)
        sys.exit(2)

    env = os.environ.get("GODOT")
    if env and Path(env).exists():
        return env

    for name in GODOT_CANDIDATES:
        found = shutil.which(name)
        if found:
            return found

    # Common local download locations (CI / agent sandboxes).
    patterns = [
        Path.home() / "AppData" / "Local" / "Temp" / "opencode" / "godot" / "*.exe",
        Path.home() / "Downloads" / "Godot_v4.7.2-stable_win64.exe",
    ]
    for pattern in patterns:
        for candidate in sorted(Path(pattern.parent).glob(pattern.name)):
            if "console" in candidate.name.lower():
                return str(candidate)
        for candidate in sorted(Path(pattern.parent).glob(pattern.name)):
            return str(candidate)

    print(
        "error: no Godot binary found.\n"
        "  Download Godot 4.7.2 and put it on PATH, set GODOT, or pass --godot.\n"
        "  https://github.com/godotengine/godot/releases/download/4.7.2-stable/"
        "Godot_v4.7.2-stable_win64.exe.zip",
        file=sys.stderr,
    )
    sys.exit(2)


def ffprobe_summary(path: Path) -> dict:
    cmd = [
        "ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries", "stream=width,height,r_frame_rate,nb_frames",
        "-show_entries", "format=duration,size",
        "-of", "json", str(path),
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(res.stderr.strip(), file=sys.stderr)
        return {}
    return json.loads(res.stdout)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--godot", help="path to the Godot 4.7.2 executable")
    ap.add_argument("--fast", action="store_true", help="quarter-length pacing for a smoke test")
    ap.add_argument("--raw-only", action="store_true", help="record the AVI but do not assemble")
    ap.add_argument("--keep", action="store_true", help="keep raw.avi after assembly")
    ap.add_argument("--fps", type=int, default=30)
    args = ap.parse_args()

    if shutil.which("ffmpeg") is None:
        print("error: ffmpeg not found on PATH", file=sys.stderr)
        sys.exit(2)

    godot = find_godot(args.godot)
    CAPTURE.mkdir(parents=True, exist_ok=True)
    for stale in (RAW, MARKERS):
        if stale.exists():
            stale.unlink()

    cmd = [
        godot,
        "--path", str(ROOT),
        "--fixed-fps", str(args.fps),
        "--write-movie", str(RAW),
        "--",
        "--record-demo",
        f"--demo-out={CAPTURE}",
    ]
    if args.fast:
        cmd.append("--demo-fast")

    print("recording:", " ".join(f'"{c}"' if " " in c else c for c in cmd))
    res = subprocess.run(cmd, cwd=str(ROOT))
    if res.returncode != 0:
        print(f"error: Godot exited {res.returncode}", file=sys.stderr)
        sys.exit(res.returncode)

    if not RAW.exists():
        print(f"error: no capture at {RAW}", file=sys.stderr)
        sys.exit(1)
    if not MARKERS.exists():
        print(f"error: no beat markers at {MARKERS}", file=sys.stderr)
        sys.exit(1)

    info = ffprobe_summary(RAW)
    stream = (info.get("streams") or [{}])[0]
    fmt = info.get("format") or {}
    print(
        "captured: {}x{} @ {} fps, {} frames, {:.2f}s, {:.1f} MB".format(
            stream.get("width", "?"), stream.get("height", "?"),
            stream.get("r_frame_rate", "?"), stream.get("nb_frames", "?"),
            float(fmt.get("duration", 0.0)), int(fmt.get("size", 0)) / 1e6,
        )
    )

    beats = json.loads(MARKERS.read_text(encoding="utf-8")).get("beats", [])
    print(f"beats: {len(beats)}")
    for b in beats:
        print("  {:<8} {:6.2f} -> {:6.2f}  {}".format(
            b.get("id", "?"), float(b.get("start", 0)), float(b.get("end", 0)),
            b.get("title", "")))

    if args.raw_only:
        print(f"kept raw capture: {RAW}")
        return

    assemble = [
        sys.executable, str(ROOT / "tools" / "make_demo_from_capture.py"),
        "--capture", str(CAPTURE),
        "--markers", str(MARKERS),
        "--out", str(OUT),
        "--fps", str(args.fps),
    ]
    print("assembling:", " ".join(assemble))
    res = subprocess.run(assemble, cwd=str(ROOT))
    if res.returncode != 0:
        sys.exit(res.returncode)

    if not args.keep and RAW.exists():
        RAW.unlink()
        print(f"removed intermediate: {RAW}")
    print(f"demo ready: {OUT}")


if __name__ == "__main__":
    main()

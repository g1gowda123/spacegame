#!/usr/bin/env python3
"""Turn a continuous Movie Maker capture into the captioned demo MP4.

`tools/record_demo.py` produces:

    demo/capture/raw.avi       Godot --write-movie, 1280x720 @ 30 fps
    demo/capture/markers.json  { beats: [{id,start,end,title,sub}, ...] }

This tool keeps the motion: each beat contributes a real clip decoded from the
AVI, trimmed to a target length, and the caption bar is composed per frame. The
old stills path remains available as `tools/make_demo.py` for reference.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent

W, H = 1280, 720
SCREEN_W, SCREEN_H = 1120, 630
SCREEN_X, SCREEN_Y = (W - SCREEN_W) // 2, 0
FPS = 30

BG = (5, 7, 12)
BAR = (7, 10, 17)
LINE = (30, 46, 66)
TEXT = (226, 236, 246)
MUTED = (150, 168, 188)
CYAN = (84, 230, 209)

PIXEL = str(ROOT / "assets" / "ui" / "Silkscreen-Bold.ttf")
BODY = str(ROOT / "assets" / "ui" / "IBMPlexMono-Regular.ttf")

# Target on-screen length per beat, in seconds. The sum is the final runtime.
# Source clips may be longer (the director holds each beat for a beat) and are
# trimmed from a small preroll so the motion starts immediately.
TARGETS = {
    "title": 2.8,
    "design": 3.6,
    "draft": 3.6,
    "sector": 8.4,
    "extract": 2.8,
    "debrief": 4.0,
    "report": 4.2,
}
DEFAULT_TARGET = 3.0


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def compose(game: Image.Image, title: str, sub: str) -> Image.Image:
    frame = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(frame)
    draw.rectangle(
        [SCREEN_X - 4, SCREEN_Y - 4, SCREEN_X + SCREEN_W + 3, SCREEN_Y + SCREEN_H + 3],
        fill=(2, 4, 8),
    )
    frame.paste(game, (SCREEN_X, SCREEN_Y))
    draw.rectangle(
        [SCREEN_X - 1, SCREEN_Y - 1, SCREEN_X + SCREEN_W, SCREEN_Y + SCREEN_H],
        outline=(22, 34, 50), width=1,
    )

    draw.rectangle([0, SCREEN_H, W, H], fill=BAR)
    draw.rectangle([0, SCREEN_H, W, SCREEN_H + 1], fill=LINE)
    draw.rectangle([SCREEN_X, SCREEN_H + 20, SCREEN_X + 4, SCREEN_H + 64], fill=CYAN)

    draw.text((SCREEN_X + 20, SCREEN_H + 18), title, font=font(PIXEL, 20), fill=CYAN)
    draw.text((SCREEN_X + 20, SCREEN_H + 48), sub, font=font(BODY, 15), fill=TEXT)

    tag = font(BODY, 11)
    label = "NASA SPACE APPS 2026  ·  SPACE MISSION DESIGN GAME"
    tw = draw.textlength(label, font=tag)
    draw.text((W - SCREEN_X - tw, SCREEN_H + 20), label, font=tag, fill=MUTED)

    credit = font(PIXEL, 9)
    c = "ORBIT + OUTPLAY  //  EXOPLANET SURVEY"
    cw = draw.textlength(c, font=credit)
    draw.text((W - SCREEN_X - cw, SCREEN_H + 52), c, font=credit, fill=(92, 112, 134))
    return frame


def decode_clip(avi: Path, start: float, duration: float, fps: int):
    """Yield RGB frames for [start, start+duration) from the capture."""
    cmd = [
        "ffmpeg", "-v", "error",
        "-ss", f"{max(0.0, start):.3f}",
        "-t", f"{duration:.3f}",
        "-i", str(avi),
        "-an", "-f", "rawvideo", "-pix_fmt", "rgb24", "-r", str(fps), "-",
    ]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    assert proc.stdout is not None
    frame_bytes = W * H * 3
    expected = max(1, int(round(duration * fps)))
    last = None
    got = 0
    for _ in range(expected):
        buf = proc.stdout.read(frame_bytes)
        if len(buf) < frame_bytes:
            break
        last = Image.frombytes("RGB", (W, H), buf)
        got += 1
        yield last
    # Short source clip: hold the last frame so audio/video stay aligned.
    while last is not None and got < expected:
        got += 1
        yield last
    proc.stdout.close()
    proc.wait()


def load_segments(markers: Path, total: float) -> list[dict]:
    data = json.loads(markers.read_text(encoding="utf-8"))
    beats = data.get("beats", [])
    segments: list[dict] = []
    for b in beats:
        start = max(0.0, float(b.get("start", 0.0)))
        end = min(total, float(b.get("end", start)))
        length = end - start
        if length < 0.2:
            continue
        target = TARGETS.get(str(b.get("id", "")), DEFAULT_TARGET)
        # Start a fraction into the beat so the clip is already in motion.
        preroll = min(0.2, length * 0.15)
        take = min(length - preroll, target)
        if take < 0.2:
            continue
        segments.append({
            "id": str(b.get("id", "")),
            "src": start + preroll,
            "dur": take,
            "title": str(b.get("title", "")),
            "sub": str(b.get("sub", "")),
        })
    return segments


def make_pad(path: Path, seconds: float) -> None:
    """Reuse the original ambient pad generator so audio stays identical."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import make_demo  # noqa: E402  (local tool, safe import)
    make_demo.make_audio(path, seconds)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--capture", default=str(ROOT / "demo" / "capture"))
    ap.add_argument("--markers", default="")
    ap.add_argument("--out", default=str(ROOT / "demo" / "orbit_outplay_demo.mp4"))
    ap.add_argument("--fps", type=int, default=FPS)
    ap.add_argument("--no-audio", action="store_true")
    args = ap.parse_args()

    capture = Path(args.capture)
    markers = Path(args.markers) if args.markers else capture / "markers.json"
    raw = capture / "raw.avi"
    out = Path(args.out)

    for p in (markers, raw):
        if not p.exists():
            sys.exit(f"missing input: {p}")

    probe = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", str(raw)],
        capture_output=True, text=True,
    )
    total = float(probe.stdout.strip() or 0.0)
    segments = load_segments(markers, total)
    if not segments:
        sys.exit("no usable beats in markers.json")

    total_out = sum(s["dur"] for s in segments)
    print(f"source {total:.2f}s -> cut {total_out:.2f}s in {len(segments)} beats")
    for s in segments:
        print(f"  {s['id']:<8} {s['src']:6.2f}s +{s['dur']:4.2f}s  {s['title']}")

    out.parent.mkdir(parents=True, exist_ok=True)
    pad = capture / "pad.wav"
    if not args.no_audio:
        make_pad(pad, total_out)

    cmd = [
        "ffmpeg", "-y",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
        "-r", str(args.fps), "-i", "-",
    ]
    if not args.no_audio:
        cmd += ["-i", str(pad)]
    cmd += [
        "-c:v", "libx264", "-preset", "medium", "-crf", "18",
        "-pix_fmt", "yuv420p",
    ]
    if not args.no_audio:
        cmd += ["-c:a", "aac", "-b:a", "128k"]
    cmd += ["-shortest", "-movflags", "+faststart", str(out)]

    encoder = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    assert encoder.stdin is not None

    written = 0
    contact_every = max(1, int(total_out * args.fps) // 9)
    contact: list[Image.Image] = []
    for seg in segments:
        for game in decode_clip(raw, seg["src"], seg["dur"], args.fps):
            shot = game.resize((SCREEN_W, SCREEN_H), Image.LANCZOS)
            frame = compose(shot, seg["title"], seg["sub"])
            encoder.stdin.write(frame.tobytes())
            if written % contact_every == 0 and len(contact) < 9:
                contact.append(frame)
            written += 1

    encoder.stdin.close()
    encoder.wait()
    if encoder.returncode != 0:
        sys.exit("ffmpeg encode failed")

    if contact:
        sheet = Image.new("RGB", (W * 3 // 2, H * 3 // 2), BG)
        for i, im in enumerate(contact):
            small = im.resize((W // 2, H // 2), Image.LANCZOS)
            sheet.paste(small, ((i % 3) * (W // 2), (i // 3) * (H // 2)))
        sheet_path = capture / "contact.png"
        sheet.save(sheet_path)
        print(f"contact sheet: {sheet_path}")

    print(f"wrote {out}  ({written} frames, {written / args.fps:.2f}s)")


if __name__ == "__main__":
    main()

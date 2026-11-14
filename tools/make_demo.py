#!/usr/bin/env python3
"""Build the 30-second NASA Space Apps demo video.

Reads the final screenshots, lays each one into a 1120x630 frame with a
caption bar, crossfades the shots, and muxes a quiet original ambient pad.
Output: demo/orbit_outplay_demo.mp4 (H.264, 1280x720, 30 fps, <=30 s).
"""

from __future__ import annotations

import math
import os
import struct
import subprocess
import sys
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SHOTS = Path("/home/g1/.local/share/godot/app_userdata/Orbit & Outplay — Exoplanet Survey")
OUT = ROOT / "demo"
OUT.mkdir(exist_ok=True)

W, H = 1280, 720
SCREEN_W, SCREEN_H = 1120, 630
SCREEN_X, SCREEN_Y = (W - SCREEN_W) // 2, 0
FPS = 30
DURATION = 29.6

BG = (5, 7, 12)
BAR = (7, 10, 17)
LINE = (30, 46, 66)
TEXT = (226, 236, 246)
MUTED = (150, 168, 188)
CYAN = (84, 230, 209)
AMBER = (255, 196, 92)

PIXEL = str(ROOT / "assets/ui/Silkscreen-Bold.ttf")
BODY = str(ROOT / "assets/ui/IBMPlexMono-Regular.ttf")


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


SEGMENTS = [
    {
        "shot": Path("/tmp/title_web.png"),
        "start": 0.0, "end": 3.4,
        "title": "ORBIT + OUTPLAY",
        "sub": "A mission-design roguelite powered by real NASA exoplanet data.",
    },
    {
        "shot": Path("/tmp/shot_design.png"),
        "start": 3.4, "end": 7.6,
        "title": "01  DESIGN THE MISSION",
        "sub": "Balance mass, power, heat, delta-v and a $500M budget.",
    },
    {
        "shot": Path("/tmp/shot_draft.png"),
        "start": 7.6, "end": 11.9,
        "title": "02  DRAFT A REAL EXOPLANET",
        "sub": "Measured temperature, gravity and distance become the hazards.",
    },
    {
        "shot": Path("/tmp/shot_sector.png"),
        "start": 11.9, "end": 18.5,
        "title": "03  SURVIVE THE SECTOR",
        "sub": "One move per turn. See the path, cost and hazard before you commit.",
    },
    {
        "shot": SHOTS / "final_sector_success.png",
        "start": 18.5, "end": 21.7,
        "title": "04  EXTRACT WITH THE DATA",
        "sub": "Meet the quota. A full four-node sweep pays more.",
    },
    {
        "shot": SHOTS / "final_debrief.png",
        "start": 21.7, "end": 25.3,
        "title": "05  REFIT AND STACK SYNERGIES",
        "sub": "Spend grants on modules. No single build survives every planet.",
    },
    {
        "shot": SHOTS / "final_report.png",
        "start": 25.3, "end": 29.6,
        "title": "THREE SECTORS. ONE AGENCY.",
        "sub": "Can you keep the lights on?",
    },
]


def fit_image(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGB")
    # Every capture is 16:9. Resample with Lanczos; the source game art is
    # already pixel-crisp, and the small downscale keeps text legible.
    return im.resize((SCREEN_W, SCREEN_H), Image.LANCZOS)


def base_frame(shot: Image.Image, title: str, sub: str) -> Image.Image:
    frame = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(frame)
    # Soft outer shadow / border around the game frame.
    draw.rectangle([SCREEN_X - 4, SCREEN_Y - 4, SCREEN_X + SCREEN_W + 3, SCREEN_Y + SCREEN_H + 3],
                   fill=(2, 4, 8))
    frame.paste(shot, (SCREEN_X, SCREEN_Y))
    draw.rectangle([SCREEN_X - 1, SCREEN_Y - 1, SCREEN_X + SCREEN_W, SCREEN_Y + SCREEN_H],
                   outline=(22, 34, 50), width=1)

    # Caption bar.
    draw.rectangle([0, SCREEN_H, W, H], fill=BAR)
    draw.rectangle([0, SCREEN_H, W, SCREEN_H + 1], fill=LINE)
    draw.rectangle([SCREEN_X, SCREEN_H + 20, SCREEN_X + 4, SCREEN_H + 64], fill=CYAN)

    tf = font(PIXEL, 20)
    sf = font(BODY, 15)
    draw.text((SCREEN_X + 20, SCREEN_H + 18), title, font=tf, fill=CYAN)
    draw.text((SCREEN_X + 20, SCREEN_H + 48), sub, font=sf, fill=TEXT)

    tag = font(BODY, 11)
    label = "NASA SPACE APPS 2026  ·  SPACE MISSION DESIGN GAME"
    tw = draw.textlength(label, font=tag)
    draw.text((W - SCREEN_X - tw, SCREEN_H + 20), label, font=tag, fill=MUTED)

    credit = font(PIXEL, 9)
    c = "ORBIT + OUTPLAY  //  EXOPLANET SURVEY"
    cw = draw.textlength(c, font=credit)
    draw.text((W - SCREEN_X - cw, SCREEN_H + 52), c, font=credit, fill=(92, 112, 134))
    return frame


def make_audio(path: Path, seconds: float) -> None:
    """A quiet, original four-chord synth pad; no external samples."""
    rate = 44100
    n = int(rate * seconds)
    chords = [
        (220.00, 261.63, 329.63),  # Am
        (174.61, 220.00, 261.63),  # F
        (130.81, 164.81, 196.00),  # C
        (196.00, 246.94, 293.66),  # G
    ]
    # Slow 7.4 s chord changes, matching the shot rhythm.
    samples = [0.0] * n
    for i in range(n):
        t = i / rate
        idx = min(3, int(t / 7.4))
        local = t - idx * 7.4
        amp = 0.035
        # Gentle swell inside each chord.
        env = 0.65 + 0.35 * math.sin(math.pi * min(1.0, local / 7.4))
        val = 0.0
        for j, f in enumerate(chords[idx]):
            # Fundamental plus a soft fifth harmonic, detuned a little.
            val += math.sin(2 * math.pi * f * t) * (0.55 if j == 0 else 0.32)
            val += math.sin(2 * math.pi * (f * 1.5 + 0.15) * t) * 0.06
        samples[i] = val * amp * env
    # Global fade in/out.
    fade_in = int(rate * 1.2)
    fade_out = int(rate * 2.2)
    for i in range(fade_in):
        samples[i] *= i / fade_in
    for i in range(fade_out):
        samples[n - 1 - i] *= i / fade_out
    # Gentle stereo width: one channel delayed by 11 ms.
    delay = int(rate * 0.011)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(rate)
        for i in range(n):
            l = int(max(-1.0, min(1.0, samples[i])) * 32767)
            r = int(max(-1.0, min(1.0, samples[i - delay] if i >= delay else 0.0)) * 32767)
            wf.writeframesraw(struct.pack("<hh", l, r))


def main() -> None:
    for seg in SEGMENTS:
        if not Path(seg["shot"]).exists():
            sys.exit(f"missing screenshot: {seg['shot']}")

    prepared = []
    for seg in SEGMENTS:
        prepared.append((base_frame(fit_image(Path(seg["shot"])), seg["title"], seg["sub"]),
                         seg["start"], seg["end"]))

    raw_path = OUT / "frames.rgb"
    vf = (
        f"fps={FPS},format=yuv420p,scale={W}:{H},"
        "libx264rgb=0"
    )
    # Feed ffmpeg raw RGB frames through a pipe.
    cmd = [
        "ffmpeg", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
        "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-i", str(OUT / "pad.wav"),
        "-c:v", "libx264", "-preset", "medium", "-crf", "18",
        "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "128k",
        "-shortest", "-movflags", "+faststart",
        str(OUT / "orbit_outplay_demo.mp4"),
    ]
    encoder = subprocess.Popen(cmd, stdin=subprocess.PIPE)

    total_frames = int(DURATION * FPS)
    seg_idx = 0
    prev_frame = None
    fade = int(0.30 * FPS)
    for i in range(total_frames):
        t = i / FPS
        while seg_idx + 1 < len(prepared) and t >= prepared[seg_idx][2]:
            seg_idx += 1
        frame, start, end = prepared[seg_idx]
        # Crossfade from the previous shot.
        out = frame
        if prev_frame is not None and (t - start) * FPS < fade and seg_idx > 0:
            a = max(0.0, min(1.0, (t - start) / 0.30))
            out = Image.blend(prev_frame, frame, a)
        # Fade from black at the start and to black at the end.
        if t < 0.4:
            a = t / 0.4
            out = Image.blend(Image.new("RGB", (W, H), BG), out, a)
        if t > DURATION - 0.5:
            a = max(0.0, (DURATION - t) / 0.5)
            out = Image.blend(Image.new("RGB", (W, H), BG), out, a)
        encoder.stdin.write(out.tobytes())
        prev_frame = out
    encoder.stdin.close()
    encoder.wait()
    if encoder.returncode != 0:
        sys.exit("ffmpeg encode failed")
    print(f"wrote {OUT / 'orbit_outplay_demo.mp4'}  ({DURATION:.1f}s)")


if __name__ == "__main__":
    make_audio(OUT / "pad.wav", DURATION)
    # Do not leave a giant raw frame file behind.
    try:
        main()
    finally:
        p = OUT / "frames.rgb"
        if p.exists():
            p.unlink()

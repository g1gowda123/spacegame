#!/usr/bin/env python3
"""Synthesize the two sector "juice" cues with no external samples.

    python3 tools/make_sfx.py

Writes 44.1 kHz mono 16-bit WAVs to assets/audio/:

  move.wav     ~0.13 s  tiny servo + latch tick, played once per committed path
  hazard.wav   ~0.26 s  low impact thud + noise burst, hazard hit / overheat
  deny.wav     ~0.10 s  muted two-step buzz, blocked move (rock, water, edge)

The point is reproducibility: one command rebuilds the files, and the recipe is
here rather than buried in a DAW project. Keep both cues short and quiet; the
sector can fire one per turn.
"""

import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")

TWO_PI = math.pi * 2.0


def _edge_fade(samples, attack=0.002, release=0.010):
    """Raise the head and drop the tail to zero so there is no click."""
    n = len(samples)
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    for i in range(min(a, n)):
        samples[i] *= i / a
    for i in range(min(r, n)):
        samples[n - 1 - i] *= i / r
    return samples


def _normalize(samples, peak):
    high = max(abs(s) for s in samples) or 1.0
    scale = peak / high
    return [s * scale for s in samples]


def _write(name, samples):
    path = os.path.abspath(os.path.join(OUT, name))
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(f"{path}  {len(samples) / SR:.3f}s  {len(data) // 1024} KiB")


def make_move():
    """Latch tick + short servo chirp + a soft low knock."""
    dur = 0.13
    n = int(dur * SR)
    rng = random.Random(4103)
    out = []
    for i in range(n):
        t = i / SR
        tick = math.sin(TWO_PI * 1850.0 * t) * math.exp(-t / 0.0055)
        knock = math.sin(TWO_PI * 92.0 * t) * math.exp(-t / 0.026)
        # 175 -> 430 Hz chirp with a 28 Hz motor tremolo.
        chirp = TWO_PI * (175.0 * t + 0.5 * (430.0 - 175.0) / dur * t * t)
        servo = math.sin(chirp) * (0.62 + 0.38 * math.sin(TWO_PI * 28.0 * t))
        servo *= math.exp(-t / 0.045)
        grit = rng.uniform(-1.0, 1.0) * math.exp(-t / 0.0035)
        out.append(0.42 * tick + 0.35 * knock + 0.30 * servo + 0.16 * grit)
    return _write("move.wav", _edge_fade(_normalize(out, 0.42)))


def make_hazard():
    """Sub-bass drop with a low-passed rumble and a short crack."""
    dur = 0.26
    n = int(dur * SR)
    rng = random.Random(9207)
    out = []
    phase = 0.0
    prev = 0.0
    low = 0.0
    for i in range(n):
        t = i / SR
        # Pitch falls 150 -> 44 Hz; integrate for a clean sweep.
        f = 44.0 + 106.0 * math.exp(-t / 0.055)
        phase += TWO_PI * f / SR
        body = math.sin(phase) * math.exp(-t / 0.085)
        sub = math.sin(TWO_PI * 55.0 * t) * math.exp(-t / 0.13)
        white = rng.uniform(-1.0, 1.0)
        low += (white - low) * 0.10
        rumble = low * math.exp(-t / 0.050)
        crack = (white - prev) * math.exp(-t / 0.009)
        prev = white
        out.append(0.72 * body + 0.42 * sub + 0.55 * rumble + 0.30 * crack)
    return _write("hazard.wav", _edge_fade(_normalize(out, 0.74)))


def make_deny():
    """Two short descending blips: reads as "not that way", not as damage."""
    dur = 0.10
    n = int(dur * SR)
    rng = random.Random(6611)
    out = []
    for i in range(n):
        t = i / SR
        f = 208.0 - 46.0 * (t / dur)
        body = math.sin(TWO_PI * f * t)
        body += 0.28 * math.sin(TWO_PI * f * 2.0 * t)
        gate = 0.55 + 0.45 * math.cos(TWO_PI * 17.0 * t)
        grit = rng.uniform(-1.0, 1.0) * 0.10
        out.append((body * gate + grit) * math.exp(-t / 0.055))
    return _write("deny.wav", _edge_fade(_normalize(out, 0.34), release=0.02))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    make_move()
    make_hazard()
    make_deny()

#!/usr/bin/env python3
"""Synthesize audio cues for the cinematic spacecraft launch sequence.

Generates 44.1 kHz mono 16-bit WAVs in assets/audio/:
  launch_beep.wav     - Crisp telemetry timing pip for countdown (T-10, T-5, T-3, T-2, T-1)
  launch_ignition.wav - Pyrotechnic ignition pop + high-pressure turbopump spin-up
  launch_rumble.wav   - Deep resonant sustained rocket engine roar and crackle
  launch_staging.wav  - Pneumatic stage / fairing separation clunk and cold gas hiss

Zero external dependencies (uses standard python wave, struct, math, random).
"""

import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
TWO_PI = math.pi * 2.0


def _edge_fade(samples, attack=0.003, release=0.015):
    n = len(samples)
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    for i in range(min(a, n)):
        samples[i] *= i / a
    for i in range(min(r, n)):
        samples[n - 1 - i] *= i / r
    return samples


def _normalize(samples, peak=0.85):
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
    print(f"Generated {name}: {len(samples)/SR:.2f}s, {len(data)//1024} KiB -> {path}")


def make_countdown_beep():
    """NASA-style mission control countdown timing pip (1760 Hz + 880 Hz harmonic)."""
    dur = 0.08
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        # Clean double-tone blip
        tone1 = math.sin(TWO_PI * 1760.0 * t)
        tone2 = 0.35 * math.sin(TWO_PI * 880.0 * t)
        env = math.exp(-t / 0.025)
        out.append((tone1 + tone2) * env)
    _write("launch_beep.wav", _edge_fade(_normalize(out, 0.70), attack=0.001, release=0.008))


def make_ignition():
    """Pyrotechnic ignition spark + high pressure turbine spin up."""
    dur = 1.2
    n = int(dur * SR)
    rng = random.Random(1337)
    out = []
    phase = 0.0
    low = 0.0
    for i in range(n):
        t = i / SR
        # Turbine whine sweeping from 120 Hz up to 880 Hz
        freq = 120.0 + 760.0 * (1.0 - math.exp(-t / 0.4))
        phase += TWO_PI * freq / SR
        whine = 0.35 * math.sin(phase) * (1.0 - math.exp(-t / 0.15))
        
        # Ignition pop at t=0
        pop = math.sin(TWO_PI * 75.0 * t) * math.exp(-t / 0.06)
        
        # High pressure gas hiss
        white = rng.uniform(-1.0, 1.0)
        low += (white - low) * 0.15
        hiss = (white - low * 0.5) * (1.0 - math.exp(-t / 0.25)) * math.exp(-t / 1.0)
        
        out.append(0.6 * pop + 0.45 * whine + 0.4 * hiss)
    _write("launch_ignition.wav", _edge_fade(_normalize(out, 0.80), attack=0.005, release=0.08))


def make_launch_rumble():
    """Heavy rocket booster roar with sub-bass rumble and acoustic crackle."""
    dur = 4.5
    n = int(dur * SR)
    rng = random.Random(8492)
    out = []
    sub_phase1 = 0.0
    sub_phase2 = 0.0
    low1 = 0.0
    low2 = 0.0
    prev = 0.0
    
    for i in range(n):
        t = i / SR
        # Build up over first 0.8s
        ramp = min(1.0, t / 0.8)
        # Deep sub-bass cluster (38 Hz + 54 Hz + 78 Hz)
        sub_phase1 += TWO_PI * 38.0 / SR
        sub_phase2 += TWO_PI * 54.0 / SR
        sub = math.sin(sub_phase1) * 0.5 + math.sin(sub_phase2) * 0.35
        
        # Turbulent low rumble
        white = rng.uniform(-1.0, 1.0)
        low1 += (white - low1) * 0.04
        low2 += (low1 - low2) * 0.05
        rumble = low2 * 2.8
        
        # Acoustic rocket crackle (intermittent sharp pressure peaks)
        crackle = 0.0
        if rng.random() < 0.18:
            crackle = rng.uniform(-1.0, 1.0) * 1.5
        
        # Mid exhaust hiss
        hiss = (white - prev) * 0.35
        prev = white
        
        sample = (0.45 * sub + 0.55 * rumble + 0.30 * crackle + 0.20 * hiss) * ramp
        # Soft sustain with gentle decay at tail
        if t > 3.6:
            sample *= max(0.0, (dur - t) / 0.9)
        out.append(sample)
        
    _write("launch_rumble.wav", _edge_fade(_normalize(out, 0.88), attack=0.01, release=0.15))


def make_staging():
    """Separation pyrotechnic bolt clunk + pneumatic gas release."""
    dur = 0.75
    n = int(dur * SR)
    rng = random.Random(7721)
    out = []
    for i in range(n):
        t = i / SR
        # Metallic clunk
        clunk = math.sin(TWO_PI * 85.0 * t) * math.exp(-t / 0.04)
        ring = math.sin(TWO_PI * 620.0 * t) * math.exp(-t / 0.08) * 0.4
        # Gas release hiss
        hiss = rng.uniform(-1.0, 1.0) * math.exp(-t / 0.22) * 0.5
        out.append(0.7 * clunk + 0.35 * ring + 0.45 * hiss)
    _write("launch_staging.wav", _edge_fade(_normalize(out, 0.75), attack=0.002, release=0.05))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    make_countdown_beep()
    make_ignition()
    make_launch_rumble()
    make_staging()

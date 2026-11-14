#!/usr/bin/env python3
"""Synthesize one ambient sector bed per exoplanet *type* (biome).

The game has 72 planets but only nine biomes in `data/exoplanets.json`
(temperate, arid, cryo, volcanic, barren, iron, sulfur, crystal, ammonia), so
the soundtrack is keyed to the type, not the planet. That keeps the asset count
and the download at nine beds instead of seventy-two.

Why these beds are shaped the way they are:

  * **One tonal centre (A), one tempo (84 BPM), one length (24 bars = 68.571 s).**
    Every bed therefore starts at the same musical place as every other one, so
    `MusicDirector` can hand over between them *at the same playback position*.
    The transition is a timbre morph, not a new track starting.
  * **A shared spine.** The sub drone (A1 + E2), the soft two-beat pulse and the
    noise floor are identical in all nine beds. Two beds in a crossfade agree on
    bass, tempo and beat placement; only the pad colour, filter and texture move.
  * **No intro, no outro, no riser, no drop, no fade.** The generator renders two
    bars past the loop point and `tools/make_music_loop.py` folds that tail into
    the head, so bar 24 hands into bar 1 sample-continuously.

Everything is additive sine synthesis with numpy; no samples, no model download.
The mastering, seam gate, loudness match and OGG encode are delegated to
`tools/make_music_loop.py` so the beds obey the same contract as the three
context cues (`docs/AUDIO.md` section 5).

    ~/anaconda3/bin/python tools/make_biome_music.py            # all nine
    ~/anaconda3/bin/python tools/make_biome_music.py --only cryo
    ~/anaconda3/bin/python tools/make_biome_music.py --quality 1

Writes `assets/music/sector_<biome>.ogg` plus the tool's `.json` sidecars.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "music"
LOOP_TOOL = ROOT / "tools" / "make_music_loop.py"

SR = 22_050
BPM = 84.0
BEAT = 60.0 / BPM
BAR = BEAT * 4.0
BARS = 24
TAIL_BARS = 2          # rendered past the loop point, folded into the head
CHORD_BARS = 6         # four chords per 24-bar loop
TOTAL = int(round(BAR * (BARS + TAIL_BARS) * SR))
LOOP_SECONDS = BAR * BARS

# The shared spine. Identical numbers in every bed is the whole point: these are
# what a crossfade must not change.
DRONE_A = (33, 0.105)      # A1
DRONE_E = (40, 0.048)      # E2, a fifth up
PULSE_HZ = 55.0            # A1 heartbeat on beats 1 and 3
PULSE_AMP = 0.055

# Per-biome colour. `chords` are MIDI notes for the four 6-bar slots, voiced to
# sit in a common register so a crossfade never jumps octave. `partials` are the
# additive recipe, `cutoff` the one-pole rolloff, `noise` the texture level and
# `shimmer` the high air layer.
SPECS = {
    "temperate": {
        "seed": 101,
        "chords": [
            [57, 60, 64, 67, 71],   # Am9
            [53, 57, 60, 64, 69],   # Fmaj7
            [60, 64, 67, 71, 74],   # Cmaj9
            [55, 59, 62, 67, 71],   # G6/9
        ],
        "drone": [DRONE_A, DRONE_E],
        "voice_amp": 0.050,
        "detune": 0.0016,
        "cutoff": 3400,
        "partials": ((1, 1.0), (2, 0.30), (3, 0.11)),
        "shimmer": 0.012,
        "noise": (0.0035, 900),
        "pulse": PULSE_AMP,
        "bells": (0.030, 1.6, 6),   # amp, decay, count
        "note": "warm and inhabited, major colour over a patient sub",
    },
    "arid": {
        "seed": 211,
        "chords": [
            [57, 60, 64, 71],       # Am(add9)
            [50, 57, 60, 65],       # Dm7
            [55, 57, 60, 64],       # Am/G
            [52, 59, 62, 67],       # Em7
        ],
        "drone": [DRONE_A, DRONE_E],
        "voice_amp": 0.046,
        "detune": 0.0012,
        "cutoff": 1900,
        "partials": ((1, 1.0), (2, 0.26), (3, 0.07)),
        "shimmer": 0.004,
        "noise": (0.0130, 700),     # dry wind across dust
        "pulse": PULSE_AMP * 0.8,
        "bells": (0.018, 2.2, 3),
        "note": "dry and suspended, Dorian, wind instead of air",
    },
    "cryo": {
        "seed": 307,
        "chords": [
            [57, 61, 64, 68, 71],   # Amaj7#11 voicing
            [54, 57, 61, 64, 68],   # F#m9
            [50, 57, 61, 64, 66],   # Dmaj9
            [52, 56, 59, 64, 66],   # E6/9
        ],
        "drone": [DRONE_A, DRONE_E],
        "voice_amp": 0.038,
        "detune": 0.0022,
        "cutoff": 7200,
        "partials": ((1, 1.0), (2, 0.18), (3, 0.17), (5, 0.06)),
        "shimmer": 0.020,
        "noise": (0.0030, 4200),    # thin air
        "pulse": PULSE_AMP * 0.7,
        "bells": (0.034, 2.6, 7),
        "note": "glassy and high, Lydian, ice ticking in vacuum",
    },
    "volcanic": {
        "seed": 401,
        "chords": [
            [45, 57, 60, 64],       # Am, low
            [41, 53, 56, 60],       # Fm
            [38, 50, 53, 57],       # Dm
            [40, 52, 56, 59],       # E
        ],
        "drone": [DRONE_A, (45, 0.045)],   # A2 rather than a 41 Hz rumble: weight without eating the pads' headroom
        "voice_amp": 0.052,
        "detune": 0.0010,
        "cutoff": 1150,
        "partials": ((1, 1.0), (2, 0.38), (3, 0.09)),
        "shimmer": 0.002,
        "noise": (0.0150, 130),     # slow rumble
        "pulse": PULSE_AMP * 1.2,
        "bells": (0.0, 0.0, 0),
        "note": "dark and heavy, minor, a crust thin enough to glow",
    },
    "barren": {
        "seed": 503,
        "chords": [
            [57, 60, 64],           # Am
            [52, 55, 59],           # Em
            [57, 60, 64],           # Am
            [53, 57, 60, 64],       # Fmaj7
        ],
        "drone": [DRONE_A, DRONE_E],
        "voice_amp": 0.044,
        "detune": 0.0040,           # wide, hollow
        "cutoff": 2400,
        "partials": ((1, 1.0), (2, 0.22), (3, 0.06)),
        "shimmer": 0.005,
        "noise": (0.0090, 1500),    # dust
        "pulse": PULSE_AMP * 0.9,
        "bells": (0.012, 2.4, 2),
        "note": "bare and open, three-note pads with nothing in between",
    },
    "iron": {
        "seed": 601,
        "chords": [
            [57, 60, 64, 67],       # Am
            [58, 62, 65, 70],       # Bb, Phrygian b2
            [57, 60, 64, 67],       # Am
            [55, 58, 62, 67],       # Gm
        ],
        "drone": [DRONE_A, DRONE_E],
        "voice_amp": 0.047,
        "detune": 0.0018,
        "cutoff": 2700,
        "partials": ((1, 1.0), (2, 0.34), (3, 0.26), (5, 0.10), (7, 0.05)),
        "shimmer": 0.007,
        "noise": (0.0060, 1100),
        "pulse": PULSE_AMP,
        "bells": (0.026, 2.0, 4),
        "note": "metallic and rusted, Phrygian second, struck-iron partials",
    },
    "sulfur": {
        "seed": 701,
        "chords": [
            [57, 62, 64, 67],       # Asus4
            [50, 55, 57, 62],       # Dsus4
            [58, 63, 65, 70],       # Bbsus4
            [52, 57, 59, 64],       # Esus4
        ],
        "drone": [DRONE_A, DRONE_E],
        "voice_amp": 0.048,
        "detune": 0.0014,
        "cutoff": 2300,
        "partials": ((1, 1.0), (2, 0.42), (3, 0.20)),
        "shimmer": 0.006,
        "noise": (0.0070, 1800),
        "pulse": PULSE_AMP,
        "bells": (0.014, 2.0, 3),
        "note": "suspended fourths, soft brass, yellow haze",
    },
    "ammonia": {
        "seed": 809,
        "chords": [
            [57, 60, 64, 67, 71],   # Am9
            [55, 60, 64, 71],       # Cmaj7
            [53, 57, 60, 65],       # Fmaj7
            [52, 55, 59, 62, 66],   # Em9
        ],
        "drone": [DRONE_A, DRONE_E],
        "voice_amp": 0.042,
        "detune": 0.0062,           # slow beating, like liquid under ice
        "cutoff": 4300,
        "partials": ((1, 1.0), (2, 0.20), (3, 0.14), (4, 0.05)),
        "shimmer": 0.010,
        "noise": (0.0055, 2600),
        "pulse": PULSE_AMP * 0.8,
        "bells": (0.016, 2.8, 3),
        "note": "dark glass with a slow beat, methane shallows",
    },
    "crystal": {
        "seed": 907,
        "chords": [
            [57, 61, 64, 68, 71],   # Amaj9
            [50, 57, 61, 64, 66],   # Dmaj9
            [54, 57, 61, 64, 69],   # F#m11
            [52, 56, 59, 64, 66],   # Eadd9
        ],
        "drone": [DRONE_A, DRONE_E],
        "voice_amp": 0.036,
        "detune": 0.0028,
        "cutoff": 6600,
        "partials": ((1, 1.0), (3, 0.22), (5, 0.10), (7, 0.04)),
        "shimmer": 0.024,
        "noise": (0.0028, 5200),
        "pulse": PULSE_AMP * 0.6,
        "bells": (0.040, 3.2, 8),
        "note": "long glass bells over almost no pad, Lydian",
    },
}

ORDER = list(SPECS)


def midi_hz(note: float) -> float:
    return 440.0 * (2.0 ** ((note - 69.0) / 12.0))


def adsr(n: int, attack: float, release: float) -> np.ndarray:
    env = np.ones(n, dtype=np.float32)
    a = min(int(attack * SR), n)
    r = min(int(release * SR), n)
    if a > 1:
        env[:a] = np.sin(np.linspace(0.0, math.pi * 0.5, a, dtype=np.float32)) ** 2
    if r > 1:
        env[n - r:] *= np.cos(np.linspace(0.0, math.pi * 0.5, r, dtype=np.float32)) ** 2
    return env


def lowpass_fft(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
    response = 1.0 / np.sqrt(1.0 + (freqs / max(cutoff, 20.0)) ** (2 * order))
    return np.fft.irfft(spectrum * response, n=len(x)).astype(np.float32)


def render(spec: dict) -> tuple[np.ndarray, np.ndarray]:
    rng = np.random.default_rng(spec["seed"])
    left = np.zeros(TOTAL, dtype=np.float32)
    right = np.zeros(TOTAL, dtype=np.float32)

    # --- shared spine: drone -------------------------------------------------
    t = np.arange(TOTAL, dtype=np.float32) / SR
    swell = 0.78 + 0.22 * np.sin(2.0 * math.pi * 0.019 * t - math.pi * 0.5)
    for note, amp in spec["drone"]:
        f = midi_hz(note)
        d = (np.sin(2.0 * math.pi * f * t)
             + 0.26 * np.sin(2.0 * math.pi * f * 2.0 * t + 0.7))
        left += d * amp * swell
        right += d * amp * swell

    # --- shared spine: soft two-beat pulse -----------------------------------
    pulse_len = int(0.55 * SR)
    pt = np.arange(pulse_len, dtype=np.float32) / SR
    pulse = np.sin(2.0 * math.pi * PULSE_HZ * pt) * np.exp(-pt / 0.085) * spec["pulse"]
    for bar in range(BARS + TAIL_BARS):
        for beat in (0.0, 2.0):
            start = int((bar * BAR + beat * BEAT) * SR)
            end = min(start + pulse_len, TOTAL)
            if start < TOTAL:
                left[start:end] += pulse[:end - start]
                right[start:end] += pulse[:end - start]

    # --- pad chords ----------------------------------------------------------
    slot = CHORD_BARS * BAR
    for i, chord in enumerate(spec["chords"]):
        start = int(round(i * slot * SR))
        dur = slot + 2.0 * BAR          # two bars of overlap into the next slot
        n = min(int(round(dur * SR)), TOTAL - start)
        if n <= 0:
            continue
        env = adsr(n, attack=3.2, release=4.5)
        tt = np.arange(n, dtype=np.float32) / SR
        for j, note in enumerate(chord):
            f = midi_hz(note)
            amp = spec["voice_amp"] * (1.0 - 0.07 * j)
            # One mono voice per note, panned by gain. Detune is applied to both
            # channels identically: that gives chorus width without decorrelating
            # the stereo pair, which would both cost bitrate and fold down badly.
            sig = np.zeros(n, dtype=np.float32)
            for mult, pamp in spec["partials"]:
                phase = rng.random() * 2.0 * math.pi
                det = 1.0 + spec["detune"] * (1.0 + 0.35 * j)
                sig += pamp * np.sin(2.0 * math.pi * f * mult * det * tt + phase)
            pan = -0.35 + 0.18 * j
            ang = (pan + 1.0) * math.pi * 0.25
            left[start:start + n] += sig * amp * env * math.cos(ang)
            right[start:start + n] += sig * amp * env * math.sin(ang)

    # --- air layer -----------------------------------------------------------
    if spec["shimmer"] > 0.0:
        for i, chord in enumerate(spec["chords"]):
            start = int(round(i * slot * SR))
            n = min(int(round((slot + 2.0 * BAR) * SR)), TOTAL - start)
            if n <= 0:
                continue
            tt = np.arange(n, dtype=np.float32) / SR
            env = adsr(n, attack=4.5, release=6.0)
            trem = 0.55 + 0.45 * np.sin(2.0 * math.pi * 0.07 * tt + rng.random() * 6.28)
            air = (np.sin(2.0 * math.pi * midi_hz(max(chord) + 24) * tt)
                   * spec["shimmer"] * trem * env)
            left[start:start + n] += air
            right[start:start + n] += air

    # --- texture -------------------------------------------------------------
    noise_amp, noise_cut = spec["noise"]
    if noise_amp > 0.0:
        base = rng.standard_normal(TOTAL).astype(np.float32)
        base = lowpass_fft(base, noise_cut)
        base /= max(float(np.abs(base).max()), 1e-6)
        breath = 0.6 + 0.4 * np.sin(2.0 * math.pi * 0.043 * t)
        left += base * noise_amp * breath
        right += base * noise_amp * breath

    # --- sparse bells --------------------------------------------------------
    bell_amp, bell_decay, bell_count = spec["bells"]
    if bell_count > 0:
        pool = [n for chord in spec["chords"] for n in chord]
        for _ in range(bell_count):
            bar = int(rng.integers(0, BARS))
            note = pool[int(rng.integers(0, len(pool)))] + 12
            start = int((bar * BAR + float(rng.choice([0.0, 1.0, 2.0, 3.0])) * BEAT) * SR)
            n = min(int(2.5 * SR), TOTAL - start)
            if n <= 0:
                continue
            tt = np.arange(n, dtype=np.float32) / SR
            env = np.exp(-tt / bell_decay) * adsr(n, attack=0.008, release=0.4)
            sig = (np.sin(2.0 * math.pi * midi_hz(note) * tt)
                   + 0.32 * np.sin(2.0 * math.pi * midi_hz(note) * 3.0 * tt + 0.5)) * bell_amp * env
            pan = float(rng.uniform(-0.45, 0.45))
            left[start:start + n] += sig * (1.0 - max(pan, 0.0))
            right[start:start + n] += sig * (1.0 + min(pan, 0.0))

    # --- gentle breathing on the whole bed -----------------------------------
    breath_l = 0.92 + 0.08 * np.sin(2.0 * math.pi * 0.031 * t)
    breath_r = 0.92 + 0.08 * np.sin(2.0 * math.pi * 0.031 * t + 0.8)
    left *= breath_l
    right *= breath_r

    # Keep the top end soft: a bed that hisses is not soothing.
    left = lowpass_fft(left, spec["cutoff"], order=2)
    right = lowpass_fft(right, spec["cutoff"], order=2)

    peak = max(float(np.abs(left).max()), float(np.abs(right).max()), 1e-6)
    gain = 0.86 / peak
    return left * gain, right * gain


def write_wav(path: Path, left: np.ndarray, right: np.ndarray) -> None:
    data = np.empty(len(left) * 2, dtype=np.int16)
    data[0::2] = np.clip(left * 32767.0, -32768, 32767).astype(np.int16)
    data[1::2] = np.clip(right * 32767.0, -32768, 32767).astype(np.int16)
    with wave.open(str(path), "wb") as fh:
        fh.setnchannels(2)
        fh.setsampwidth(2)
        fh.setframerate(SR)
        fh.writeframes(data.tobytes())


def master(biome: str, wav: Path, quality: int) -> int:
    out = OUT / f"sector_{biome}.ogg"
    cmd = [
        sys.executable, str(LOOP_TOOL),
        "--in", str(wav),
        "--out", str(out),
        "--cue", f"sector_{biome}",
        "--bpm", f"{BPM:g}",
        "--bars", str(BARS),
        "--crossfade-bars", str(TAIL_BARS),
        "--fade-curve", "auto",
        "--quality", str(quality),
        "--rate", "22050",
        "--seed", str(SPECS[biome]["seed"]),
        "--prompt", f"ambient biome bed: {biome} - {SPECS[biome]['note']}",
        "--force",
    ]
    return subprocess.run(cmd, cwd=str(ROOT)).returncode


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Synthesize one ambient bed per exoplanet biome.")
    ap.add_argument("--only", default="", help="comma-separated biome ids (default: all)")
    ap.add_argument("--quality", type=int, default=1, help="vorbis -q:a (default 1)")
    ap.add_argument("--keep-wav", action="store_true", help="leave the intermediate wav files")
    args = ap.parse_args(argv)

    wanted = [b.strip() for b in args.only.split(",") if b.strip()] or ORDER
    unknown = [b for b in wanted if b not in SPECS]
    if unknown:
        ap.error(f"unknown biome(s): {', '.join(unknown)}; choose from {', '.join(ORDER)}")

    OUT.mkdir(parents=True, exist_ok=True)
    tmp = Path(tempfile.mkdtemp(prefix="biome_music_"))
    failures = []
    total = 0
    for biome in wanted:
        left, right = render(SPECS[biome])
        wav = tmp / f"sector_{biome}.wav"
        write_wav(wav, left, right)
        rc = master(biome, wav, args.quality)
        if rc != 0:
            failures.append(biome)
            print(f"  {biome}: mastering failed (exit {rc})", file=sys.stderr)
            continue
        size = (OUT / f"sector_{biome}.ogg").stat().st_size
        total += size
        print(f"  {biome}: {LOOP_SECONDS:.2f} s loop, {size / 1024:.0f} KiB")
        if not args.keep_wav:
            wav.unlink(missing_ok=True)

    if not args.keep_wav:
        import shutil
        shutil.rmtree(tmp, ignore_errors=True)

    sidecars = [OUT / f"sector_{b}.json" for b in wanted]
    print(f"\n{len(wanted) - len(failures)}/{len(wanted)} beds mastered, "
          f"{total / 1024 / 1024:.2f} MiB in this run")
    for sc in sidecars:
        if sc.exists():
            info = json.loads(sc.read_text(encoding="utf-8"))
            print(f"  {sc.name:26s} {info['lufs']:6.2f} LUFS  "
                  f"{info['true_peak']:5.2f} dBTP  "
                  f"wrap {info['seam']['wrap_vs_baseline_db']:+.1f} dB  "
                  f"mono {info['seam']['mono_delta_db']:+.2f} dB  "
                  f"{'PASS' if info['gate']['passed'] else 'FAIL'}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

#!/usr/bin/env python3
"""Synthesize the three screen music beds with no samples and no DAW.

    python3 tools/make_music.py            # all three, ~1.5 MB of OGG
    python3 tools/make_music.py --bars 4   # fast smoke render (not loopable)

Writes 44.1 kHz-ready stereo OGG Vorbis loops to `assets/music/`:

  title.ogg    24 bars  contemplative pad + bell, no drums
  sector.ogg   24 bars  steady pulse: bass ostinato, soft kit, 16th arp
  debrief.ogg  24 bars  resolving major key, pad + melody, light shaker

Everything shares one tempo (84 BPM), one key family (A minor / C major) and
one 24-bar length, so the 2 s crossfades in `scripts/music_director.gd` land on
the beat instead of clashing.

Seamlessness comes from wrapping every note tail modulo the loop length before
the final master pass, so a chord that starts in bar 24 rings into bar 1. No
fade is applied at either end (a fade would defeat the point) — the loop point
is a real musical downbeat.

Design rules, learned from the SFX pass:
  * one command must rebuild the files, so the recipe lives here;
  * deterministic (seeded) so regenerating does not change the bed mid-review;
  * additive sine/triangle wavetables only, so the files stay small and the
    character matches the 16-colour pixel art rather than sounding sampled.
"""

import math
import os
import random
import struct
import subprocess
import sys
import tempfile
import wave

SR = 22050
BPM = 84.0
BEAT = 60.0 / BPM
BAR = BEAT * 4.0
DEFAULT_BARS = 24
TAU = math.pi * 2.0

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "music")
TMP = os.path.join(tempfile.gettempdir(), "orbit_music_build")

# ---------------------------------------------------------------------------
# Wavetables (one cycle, linearly interpolated). Cheap and click-free.
# ---------------------------------------------------------------------------

def _table(*harmonics, size=2048):
    """harmonics: (multiple, amplitude) pairs -> one normalised cycle."""
    norm = sum(abs(a) for _, a in harmonics) or 1.0
    out = [0.0] * size
    for i in range(size):
        p = i / size
        v = 0.0
        for mult, amp in harmonics:
            v += amp * math.sin(TAU * mult * p)
        out[i] = v / norm
    return out

SINE = _table((1, 1.0))
SOFT = _table((1, 1.0), (2, 0.30), (3, 0.12))          # warm pad
REED = _table((1, 1.0), (2, 0.22), (3, 0.16), (4, 0.07))  # bass / arp body
BELL = _table((1, 1.0), (2, 0.45), (3, 0.22), (5, 0.08))  # metallic pluck
GLASS = _table((1, 1.0), (3, 0.18), (7, 0.06))


def _midi(n):
    return 440.0 * (2.0 ** ((n - 69) / 12.0))


# ---------------------------------------------------------------------------
# Mixing helpers. Buffers are stereo float lists of exactly LOOP samples.
# ---------------------------------------------------------------------------

class Mix:
    def __init__(self, length):
        self.length = length
        self.l = [0.0] * length
        self.r = [0.0] * length

    def add(self, start, wave_, amp, pan=0.0):
        """Add a mono note with equal-power pan, wrapping past the loop end."""
        n = len(wave_)
        if n == 0:
            return
        # Equal power: centre = 0.707 each side.
        ang = (pan + 1.0) * math.pi * 0.25
        gl = math.cos(ang) * amp
        gr = math.sin(ang) * amp
        length = self.length
        l, r = self.l, self.r
        s = start % length
        for i in range(n):
            j = s + i
            if j >= length:
                j -= length
            v = wave_[i]
            l[j] += v * gl
            r[j] += v * gr


def _env(n, attack, decay_tau, release, sustain=0.0):
    """Attack -> exponential decay -> release, as a float list of length n."""
    out = [0.0] * n
    atk = max(1, int(attack * SR))
    rel = max(1, int(release * SR))
    for i in range(n):
        t = i / SR
        if i < atk:
            a = i / atk
        else:
            a = 1.0
        d = math.exp(-t / decay_tau) if decay_tau > 0 else 1.0
        if sustain > 0.0:
            d = sustain + (1.0 - sustain) * d
        left = n - i
        if left < rel:
            a *= left / rel
        out[i] = a * d
    return out


def _note(table_, freq, dur, amp, attack=0.004, decay_tau=0.25,
          release=0.05, vibrato=0.0, detune=0.0):
    """Render one note into a float list, wavetable lookup + envelopes."""
    n = max(1, int(dur * SR))
    env = _env(n, attack, decay_tau, release)
    wave_ = [0.0] * n
    size = len(table_)
    step = freq / SR * size
    ph = 0.0
    ph2 = 0.0
    step2 = (freq * (1.0 + detune)) / SR * size
    for i in range(n):
        v = table_[int(ph) & (size - 1)]
        if detune:
            v = 0.62 * v + 0.38 * table_[int(ph2) & (size - 1)]
            ph2 += step2
            if ph2 >= size:
                ph2 -= size
        if vibrato:
            step_i = step * (1.0 + vibrato * math.sin(TAU * 5.2 * i / SR))
        else:
            step_i = step
        ph += step_i
        if ph >= size:
            ph -= size
        wave_[i] = v * env[i] * amp
    return wave_


def _pluck(table_, freq, dur, amp, decay_tau=0.12):
    return _note(table_, freq, dur, amp, attack=0.002, decay_tau=decay_tau,
                 release=0.02)


# ---------------------------------------------------------------------------
# Drum kit (synthesised, low-passed noise + swept sines)
# ---------------------------------------------------------------------------

def _kick(dur=0.20, amp=0.55, pan=0.0):
    n = int(dur * SR)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = 46.0 + 94.0 * math.exp(-t / 0.035)
        ph += TAU * f / SR
        out[i] = math.sin(ph) * math.exp(-t / 0.075) * amp
    return out


def _hat(dur=0.055, amp=0.16, pan=0.3, seed=1):
    rng = random.Random(seed)
    n = int(dur * SR)
    out = [0.0] * n
    prev = 0.0
    for i in range(n):
        t = i / SR
        w = rng.uniform(-1.0, 1.0)
        hp = w - prev          # crude high-pass: keeps the top end only
        prev = w
        # 1.5 ms attack: a noise burst that starts at full level clicks, and
        # the first hat lands exactly on sample 0 of the loop.
        a = min(1.0, t / 0.0015)
        out[i] = hp * math.exp(-t / 0.014) * amp * a
    return out


def _snare(dur=0.14, amp=0.30, pan=-0.1, seed=7):
    rng = random.Random(seed)
    n = int(dur * SR)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        body = math.sin(TAU * 186.0 * t) * math.exp(-t / 0.045) * 0.5
        noise = rng.uniform(-1.0, 1.0) * math.exp(-t / 0.055)
        a = min(1.0, t / 0.002)
        out[i] = (body + noise * 0.75) * amp * a
    return out


# ---------------------------------------------------------------------------
# Track assembly
# ---------------------------------------------------------------------------

# Chord voicings as MIDI numbers. Title/sector sit in A minor, debrief resolves
# to C major; both progressions wrap cleanly over 24 bars (4-bar cycle x 6).
TITLE_PROG = [
    (57, 60, 64, 67),   # Am7
    (53, 57, 60, 64),   # Fmaj7
    (48, 52, 55, 59),   # Cmaj7
    (55, 59, 62, 64),   # G6
]
SECTOR_PROG = [
    (45, 57, 60, 64),   # Am
    (45, 53, 57, 60),   # Am/F colour
    (41, 53, 57, 60),   # F
    (43, 55, 59, 62),   # G
]
DEBRIEF_PROG = [
    (48, 55, 59, 64),   # Cmaj7
    (43, 55, 59, 62),   # G
    (45, 57, 60, 64),   # Am7
    (41, 53, 57, 60),   # Fmaj7
]


def build_title(mix, bars, rng):
    bar_len = BAR
    for b in range(bars):
        chord = TITLE_PROG[b % len(TITLE_PROG)]
        t0 = b * bar_len
        # Pad: whole-bar chord, slow attack so bar joins are inaudible.
        for k, m in enumerate(chord):
            pan = -0.35 + 0.23 * k
            w = _note(SOFT, _midi(m), bar_len * 1.05, 0.085,
                      attack=0.30, decay_tau=2.6, release=0.35,
                      detune=0.004)
            mix.add(int(t0 * SR), w, 1.0, pan)
        # Bass root, one octave down, long and quiet.
        root = chord[0] - 12
        mix.add(int(t0 * SR),
                _note(SINE, _midi(root), bar_len * 0.95, 0.20,
                      attack=0.05, decay_tau=1.4, release=0.3), 1.0)
        # Sparse bell motif: scale degrees 5 / 3 / 7 over the chord.
        if b % 2 == 0:
            for off, idx in ((0.0, 2), (1.5, 3), (2.75, 1)):
                m = chord[idx] + 12
                w = _pluck(BELL, _midi(m), 1.5, 0.14, decay_tau=0.55)
                mix.add(int((t0 + off * BEAT) * SR), w, 1.0,
                        0.25 if idx % 2 else -0.25)


def build_sector(mix, bars, rng):
    bar_len = BAR
    for b in range(bars):
        chord = SECTOR_PROG[b % len(SECTOR_PROG)]
        t0 = b * bar_len
        root = chord[0]
        # Pad, quieter than the title so the pulse carries.
        for k, m in enumerate(chord[1:]):
            w = _note(SOFT, _midi(m), bar_len * 1.02, 0.055,
                      attack=0.16, decay_tau=1.8, release=0.25,
                      detune=0.003)
            mix.add(int(t0 * SR), w, 1.0, -0.3 + 0.3 * k)
        # Bass ostinato: root, root, fifth, root — straight 8ths, no swing.
        pat = (0, 0, 7, 0, 0, 12, 7, 0)
        for k, semi in enumerate(pat):
            m = root - 12 + semi
            w = _note(REED, _midi(m), BEAT * 0.46, 0.20,
                      attack=0.006, decay_tau=0.10, release=0.02)
            mix.add(int((t0 + k * BEAT * 0.5) * SR), w, 1.0)
        # 16th arpeggio, alternating pan, very short decay.
        tones = chord[1:] + (chord[2] + 12,)
        for step in range(16):
            m = tones[step % len(tones)] + 12
            pan = 0.35 if step % 2 else -0.35
            w = _pluck(GLASS, _midi(m), BEAT * 0.24, 0.075,
                       decay_tau=0.055)
            mix.add(int((t0 + step * BEAT * 0.25) * SR), w, 1.0, pan)
        # Kit: kick on 1/3, snare on 2/4, closed hats on every 8th.
        for beat in (0, 2):
            mix.add(int((t0 + beat * BEAT) * SR), _kick(pan=0.0), 1.0)
        for beat in (1, 3):
            mix.add(int((t0 + beat * BEAT) * SR), _snare(amp=0.26, pan=-0.08), 1.0)
        for k in range(8):
            mix.add(int((t0 + k * BEAT * 0.5) * SR),
                    _hat(amp=0.11, pan=0.35, seed=b * 8 + k), 1.0)


def build_debrief(mix, bars, rng):
    bar_len = BAR
    # Pentatonic melody, seeded so the line is stable across rebuilds.
    scale = (60, 62, 64, 67, 69, 72, 74, 76)
    for b in range(bars):
        chord = DEBRIEF_PROG[b % len(DEBRIEF_PROG)]
        t0 = b * bar_len
        for k, m in enumerate(chord):
            w = _note(SOFT, _midi(m), bar_len * 1.05, 0.075,
                      attack=0.28, decay_tau=2.4, release=0.3,
                      detune=0.003)
            mix.add(int(t0 * SR), w, 1.0, -0.3 + 0.2 * k)
        mix.add(int(t0 * SR),
                _note(SINE, _midi(chord[0] - 12), bar_len * 0.9, 0.18,
                      attack=0.04, decay_tau=1.2, release=0.25), 1.0)
        # Two melody notes per bar, on beats 1 and 3, with rests between.
        if b % 2 == 0:
            for k, off in enumerate((0.0, 2.0)):
                m = scale[rng.randrange(len(scale))]
                w = _pluck(BELL, _midi(m), 1.8, 0.12, decay_tau=0.7)
                mix.add(int((t0 + off * BEAT) * SR), w, 1.0,
                        0.2 if k else -0.2)
        # Light shaker on the off-beats; keeps motion without a kit.
        for k in (1, 3):
            mix.add(int((t0 + k * BEAT) * SR), _hat(amp=0.07, pan=0.4,
                                                    seed=b * 3 + k), 1.0)


# ---------------------------------------------------------------------------
# Master chain: reverb taps -> one-pole low-pass -> soft clip -> normalise
# ---------------------------------------------------------------------------

def _reverb(mix):
    """Wrapped delay taps: cheap space, and the tail stays inside the loop.

    Each tap runs two full passes so the delay line is already warm when the
    loop restarts; a single pass starts cold at sample 0 and leaves an audible
    step at the seam.
    """
    taps = ((0.037, 0.22), (0.061, 0.16), (0.097, 0.11))
    n = mix.length
    for secs, gain in taps:
        d = int(secs * SR)
        for buf in (mix.l, mix.r):
            for i in range(n * 2):
                idx = i if i < n else i - n
                j = idx - d
                if j < 0:
                    j += n
                buf[idx] += buf[j] * gain


def _lowpass(mix, cutoff=4600.0, poles=3):
    """Cascaded one-pole low-pass, run twice so the filter state is periodic.

    Three poles is ~18 dB/oct: a single pole left audible hiss on the noise
    hats (visible as broadband energy up to Nyquist on the re-verify spectrogram).
    """
    n = mix.length
    a = 1.0 - math.exp(-TAU * cutoff / SR)
    for _pole in range(poles):
        for buf in (mix.l, mix.r):
            y = 0.0
            for i in range(n * 2):
                idx = i if i < n else i - n
                y += a * (buf[idx] - y)
                buf[idx] = y


def _master(mix, target_rms=0.135, ceiling=0.90):
    """Reverb -> low-pass -> loudness match -> peak guard.

    Matching integrated RMS across the three beds matters more than matching
    peaks: the sector track is transient-heavy and would otherwise sit ~4 dB
    under the title/debrief and jump in level on every crossfade.
    """
    _reverb(mix)
    _lowpass(mix)
    n = mix.length
    energy = sum(v * v for v in mix.l) + sum(v * v for v in mix.r)
    rms = math.sqrt(energy / (n * 2)) or 1.0
    scale = target_rms / rms
    high = 0.0
    for buf in (mix.l, mix.r):
        for i in range(n):
            buf[i] *= scale
            a = abs(buf[i])
            if a > high:
                high = a
    if high > ceiling:
        trim = ceiling / high
        for buf in (mix.l, mix.r):
            for i in range(n):
                buf[i] *= trim
    return mix


def write_wav(path, mix):
    n = mix.length
    frames = bytearray(n * 4)
    for i in range(n):
        l = max(-1.0, min(1.0, mix.l[i]))
        r = max(-1.0, min(1.0, mix.r[i]))
        struct.pack_into("<hh", frames, i * 4,
                         int(l * 32767), int(r * 32767))
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))


TRACKS = (
    ("title", build_title, 1100),
    ("sector", build_sector, 2200),
    ("debrief", build_debrief, 3300),
)


def main(argv):
    bars = DEFAULT_BARS
    for i, a in enumerate(argv):
        if a == "--bars" and i + 1 < len(argv):
            bars = int(argv[i + 1])
    length = int(round(BAR * bars * SR))
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    total = 0
    for name, builder, seed in TRACKS:
        mix = Mix(length)
        builder(mix, bars, random.Random(seed))
        _master(mix)
        wav_path = os.path.join(TMP, name + ".wav")
        ogg_path = os.path.join(OUT, name + ".ogg")
        write_wav(wav_path, mix)
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
             "-c:a", "libvorbis", "-qscale:a", "2", ogg_path],
            check=True,
        )
        size = os.path.getsize(ogg_path)
        total += size
        print(f"{ogg_path}  {length / SR:.1f}s  {size // 1024} KiB")
    print(f"total {total / 1048576:.2f} MiB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

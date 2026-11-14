#!/usr/bin/env python3
"""Master a generated music bed into a seamless, loudness-matched loop.

The generator (Stable Audio 3 / ACE-Step via ComfyUI) gives you a track; this
tool makes it a loop. It implements the contract in `docs/AUDIO.md` section 5:

  1. trim to `bars x bar` aligned to a downbeat offset (`--start`),
  2. wrap-around crossfade - the tail past the loop point is folded into the
     head, so the wrap hands src[N-1] straight into src[N] and the seam is
     sample-continuous by construction (a 40 ms declick is the fallback),
  3. loudness-matched to -16 LUFS / -1.5 dBTP,
  4. seam verified numerically (wrap discontinuity vs the file's own largest
     sample step, RMS step across the loop point, mono fold-down loss),
  5. encoded to OGG q3 with a `.json` sidecar carrying every measured number.

Why the gain is applied by hand instead of by the `loudnorm` filter: loudnorm
carries a lookahead delay and resamples to 192 kHz internally, so its output is
shifted against the input and the loop samples would move. We use it exactly
as a meter (pass 1 and pass 2) and apply the measured gain ourselves, which
leaves the waveform - and therefore the seam - untouched.

Usage:
  make_music_loop.py --in raw/sector_84s.wav --cue sector --seed 4101 \
      --prompt "tense minimal electronic pulse, 100 bpm, A minor"
  make_music_loop.py --in raw/title.wav --cue title --start 1.37 --declick-ms 40
  make_music_loop.py --selftest          # synthetic fixture, no ComfyUI needed

Exit codes: 0 shipped, 1 seam gate failed, 2 usage/dependency error.
"""

from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
import sys
import tempfile
import time
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
MUSIC_DIR = ROOT / "assets" / "audio" / "music"

SR = 48_000
DEFAULT_BPM = 100.0
DEFAULT_BARS = 32
DEFAULT_BEATS = 4
DEFAULT_CROSSFADE_BARS = 2
DEFAULT_DECLICK_MS = 40
TARGET_LUFS = -16.0
TARGET_TP = -1.5
OGG_QUALITY = 3

# gate thresholds: a seam is "invisible" when wrapping the file is no bigger a
# jump than the largest step already inside it, the level does not step, and
# the mono fold-down does not lose the bed.
SEAM_VS_BASELINE_DB = 6.0
RMS_STEP_ADVISORY_DB = 6.0
FADE_GAIN_ADVISORY_DB = 1.5
MONO_LOSS_DB = 6.0


# ---------------------------------------------------------------------------
# ffmpeg plumbing
# ---------------------------------------------------------------------------

def ffmpeg() -> str:
    exe = shutil.which("ffmpeg")
    if not exe:
        die("ffmpeg not found on PATH (build-time dependency, see docs/AUDIO.md 5)")
    return exe


def die(msg: str, code: int = 2) -> "None":
    print(f"make_music_loop: {msg}", file=sys.stderr, flush=True)
    raise SystemExit(code)


def decode(path: Path, sr: int = SR) -> np.ndarray:
    """Decode any ffmpeg-readable file to (samples, 2) float32."""
    if not path.exists():
        die(f"input not found: {path}")
    proc = subprocess.run(
        [ffmpeg(), "-v", "error", "-nostdin", "-i", str(path),
         "-f", "f32le", "-ar", str(sr), "-ac", "2", "-"],
        capture_output=True,
    )
    if proc.returncode != 0:
        die(f"decode failed: {proc.stderr.decode('utf-8', 'replace').strip()[:400]}")
    audio = np.frombuffer(proc.stdout, dtype="<f4")
    if audio.size == 0:
        die(f"decoded zero samples from {path}")
    return audio.reshape(-1, 2).astype(np.float32)


def measure(samples: np.ndarray, sr: int = SR) -> dict:
    """EBU R128 integrated loudness + true peak, measured (not applied)."""
    raw = np.ascontiguousarray(samples, dtype="<f4").tobytes()
    cmd = [
        # loudnorm prints its JSON at info level, so this one call keeps stderr
        # (everything else here runs with -v error).
        ffmpeg(), "-hide_banner", "-nostdin", "-nostats",
        "-f", "f32le", "-ar", str(sr), "-ac", "2", "-i", "pipe:0",
        "-af", f"loudnorm=I={TARGET_LUFS}:TP={TARGET_TP}:print_format=json",
        "-f", "null", "-",
    ]
    proc = subprocess.run(cmd, input=raw, capture_output=True)
    text = proc.stderr.decode("utf-8", "replace")
    start = text.rfind("{")
    end = text.rfind("}")
    if proc.returncode != 0 or start < 0 or end < start:
        die(f"loudnorm measurement failed: {text.strip()[:400]}")
    data = json.loads(text[start:end + 1])
    return {
        "lufs": float(data["input_i"]),
        "true_peak": float(data["input_tp"]),
        "lra": float(data["input_lra"]),
        "threshold": float(data["input_thresh"]),
    }


def encode_ogg(samples: np.ndarray, out_path: Path, quality: int, sr: int = SR) -> None:
    """Encode at `sr`. The buffer is always at the internal 48 kHz rate, so the
    pipe declares SR and `-ar` *after* `-i` asks ffmpeg to resample on the way
    out. Putting `-ar` before `-i` would reinterpret the buffer instead, which
    plays the bed back at the wrong speed."""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    raw = np.ascontiguousarray(samples, dtype="<f4").tobytes()
    proc = subprocess.run(
        [ffmpeg(), "-y", "-v", "error", "-nostdin",
         "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "pipe:0",
         "-c:a", "libvorbis", "-q:a", str(quality), "-ar", str(sr), str(out_path)],
        input=raw, capture_output=True,
    )
    if proc.returncode != 0:
        die(f"vorbis encode failed: {proc.stderr.decode('utf-8', 'replace').strip()[:400]}")


# ---------------------------------------------------------------------------
# loop construction
# ---------------------------------------------------------------------------

def loop_layout(bpm: float, bars: int, beats: int) -> tuple[int, float, float]:
    bar_seconds = beats * 60.0 / bpm
    return int(round(bars * bar_seconds * SR)), bar_seconds, bars * bar_seconds


def wrap_crossfade(src: np.ndarray, loop_len: int, fade_len: int,
                   curve: str) -> np.ndarray:
    """Fold the tail past the loop point into the head.

    The loop ends on src[loop_len-1] and opens on the tail, which is the very
    next slice of the same performance - so the wrap is continuous, and the
    early material fades in underneath over `fade_len` samples. At x == 0 the
    output is pure tail, at x == fade_len it is pure head.
    """
    if fade_len <= 0:
        return src[:loop_len].copy()
    t = np.arange(fade_len, dtype=np.float32) / float(fade_len)
    if curve == "linear":
        rise = t
        fall = 1.0 - t
    else:  # equal-power (spec default)
        rise = np.sin(0.5 * math.pi * t)
        fall = np.cos(0.5 * math.pi * t)
    out = src[:loop_len].copy()
    head = src[:fade_len]
    tail = src[loop_len:loop_len + fade_len]
    out[:fade_len] = head * rise[:, None] + tail * fall[:, None]
    return out


def declick_loop(src: np.ndarray, loop_len: int, declick_ms: float) -> np.ndarray:
    """Hard cut plus a short raised-cosine dip either side of the seam."""
    out = src[:loop_len].copy()
    n = max(1, int(round(declick_ms * 1e-3 * SR)))
    n = min(n, loop_len // 4)
    ramp = 0.5 - 0.5 * np.cos(np.pi * np.arange(n, dtype=np.float32) / n)
    out[:n] *= ramp[:, None]
    out[-n:] *= ramp[::-1][:, None]
    return out


def db(x: float, floor: float = -120.0) -> float:
    return max(floor, 20.0 * math.log10(max(float(x), 1e-12)))


def rms(x: np.ndarray) -> float:
    return float(np.sqrt(np.mean(np.square(x.astype(np.float64))))) if x.size else 0.0


def display_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(ROOT)).replace("\\", "/")
    except ValueError:
        return str(path)


def seam_report(y: np.ndarray, fade_len: int) -> dict:
    """Measure the seam instead of trusting it.

    `wrap_delta` is the jump from the last sample to the first one - the only
    discontinuity the listener hears once the engine wraps. It is compared
    against `baseline`, the 99.99th percentile of the file's own adjacent
    sample steps: if wrapping is not a bigger jump than the material already
    contains, it cannot click. `join_delta` is the crossfade exit point, and
    `fade_gain` reports the equal-power level bump over the head region.
    """
    steps = np.abs(np.diff(y, axis=0))
    wrap = float(np.max(np.abs(y[0] - y[-1])))
    baseline = float(np.quantile(steps, 0.9999)) if steps.size else 0.0
    join = 0.0
    if 0 < fade_len < len(y) - 1:
        join = float(np.max(np.abs(y[fade_len] - y[fade_len - 1])))
    head_rms = rms(y[:fade_len]) if fade_len > 0 else rms(y)
    body_rms = rms(y[fade_len:]) if fade_len > 0 else rms(y)
    win = int(0.010 * SR)
    step_db = abs(db(rms(y[:win])) - db(rms(y[-win:])))
    mono = (y[:, 0].astype(np.float64) + y[:, 1].astype(np.float64)) * 0.5
    stereo = rms(y)
    mono_loss_db = db(stereo) - db(rms(mono))
    return {
        "wrap_delta": wrap,
        "wrap_delta_dbfs": round(db(wrap), 2),
        "baseline_step": baseline,
        "baseline_dbfs": round(db(baseline), 2),
        "wrap_vs_baseline_db": round(db(wrap) - db(baseline), 2),
        "join_delta_dbfs": round(db(join), 2),
        "rms_step_db": round(step_db, 2),
        "fade_gain_db": round(db(head_rms) - db(body_rms), 2) if fade_len else 0.0,
        "mono_delta_db": round(mono_loss_db, 2),
        "peak_dbfs": round(db(float(np.max(np.abs(y)))), 2),
    }


def gate(report: dict) -> tuple[list[str], list[str]]:
    """Hard failures (a click) and advisory warnings (a level quirk)."""
    problems: list[str] = []
    warnings: list[str] = []
    if report["wrap_vs_baseline_db"] > SEAM_VS_BASELINE_DB:
        problems.append(
            f"wrap is {report['wrap_vs_baseline_db']:.1f} dB above the largest "
            f"internal step (limit {SEAM_VS_BASELINE_DB:.0f}) - the seam would click")
    join_vs_baseline = report["join_delta_dbfs"] - report["baseline_dbfs"]
    if join_vs_baseline > SEAM_VS_BASELINE_DB:
        problems.append(
            f"crossfade exit is {join_vs_baseline:.1f} dB above the largest internal "
            f"step - the fade ends on a step, try --fade-curve linear")
    if report["mono_delta_db"] > MONO_LOSS_DB:
        problems.append(
            f"mono fold-down loses {report['mono_delta_db']:.1f} dB (limit "
            f"{MONO_LOSS_DB:.0f}) - the bed will vanish on a single speaker")
    # Advisory: a beat-aligned bed legitimately lands a kick on the loop point,
    # which lifts the first 10 ms without being a click. Only a hole (>6 dB)
    # or a crossfade level bump (>1.5 dB) is worth acting on.
    if report["rms_step_db"] > RMS_STEP_ADVISORY_DB:
        warnings.append(
            f"level steps {report['rms_step_db']:.1f} dB across the loop point - "
            f"check the downbeat is not landing on a gap")
    if abs(report["fade_gain_db"]) > FADE_GAIN_ADVISORY_DB:
        warnings.append(
            f"crossfade changes the head level by {report['fade_gain_db']:+.1f} dB - "
            f"linear keeps correlated material flat, equal-power is for uncorrelated")
    return problems, warnings


# ---------------------------------------------------------------------------
# the pipeline
# ---------------------------------------------------------------------------

def master(src: np.ndarray, args: argparse.Namespace) -> tuple[np.ndarray, dict]:
    loop_len, bar_seconds, loop_seconds = loop_layout(args.bpm, args.bars, args.beats)
    fade_len = 0
    if args.mode == "equal-power":
        fade_len = int(round(args.crossfade_bars * bar_seconds * SR))

    start = int(round(args.start * SR))
    if start < 0:
        die("--start must be >= 0")
    src = src[start:]
    need = loop_len + fade_len
    if len(src) < need:
        die(f"source too short: need {need / SR:.2f} s "
            f"({args.bars} bars + {args.crossfade_bars} bars tail) after "
            f"--start {args.start:.3f} s, have {len(src) / SR:.2f} s. "
            f"Generate duration = loop + tail (e.g. 84 s for 32 bars at 100 bpm).")

    if args.mode == "equal-power":
        curves = ["equal-power", "linear"] if args.fade_curve == "auto" else [args.fade_curve]
        best = None
        for curve in curves:
            candidate = wrap_crossfade(src, loop_len, fade_len, curve)
            bump = abs(seam_report(candidate, fade_len)["fade_gain_db"])
            if best is None or bump < best[0]:
                best = (bump, curve, candidate)
        chooser = best[1]
        y = best[2]
    else:
        chooser = None
        y = declick_loop(src, loop_len, args.declick_ms)

    before = measure(y)
    gain_db = TARGET_LUFS - before["lufs"]
    if before["true_peak"] + gain_db > TARGET_TP:
        gain_db = TARGET_TP - before["true_peak"]
        limiter = True
    else:
        limiter = False
    y = (y * (10.0 ** (gain_db / 20.0))).astype(np.float32)

    after = measure(y)
    report = seam_report(y, fade_len)
    info = {
        "bpm": args.bpm,
        "bars": args.bars,
        "beats_per_bar": args.beats,
        "bar_seconds": round(bar_seconds, 4),
        "loop_seconds": round(loop_seconds, 4),
        "loop_samples": loop_len,
        "sample_rate": SR,
        "mode": args.mode,
        "crossfade_bars": args.crossfade_bars if args.mode == "equal-power" else 0,
        "crossfade_seconds": round(fade_len / SR, 4),
        "declick_ms": args.declick_ms if args.mode == "declick" else 0,
        "fade_curve": chooser if args.mode == "equal-power" else None,
        "fade_curve_requested": args.fade_curve,
        "start_offset_seconds": args.start,
        "source_seconds": round(len(src) / SR, 3),
        "lufs_before": round(before["lufs"], 2),
        "gain_db": round(gain_db, 2),
        "peak_limited": limiter,
        "lufs": round(after["lufs"], 2),
        "true_peak": round(after["true_peak"], 2),
        "seam": report,
    }
    return y, info


def sidecar_path(out: Path) -> Path:
    return out.with_suffix(".json")


def check_overwrite(out: Path, force: bool) -> None:
    """Contract 6: an accepted cue does not change silently."""
    sc = sidecar_path(out)
    accepted = False
    if sc.exists():
        try:
            accepted = bool(json.loads(sc.read_text(encoding="utf-8")).get("accepted"))
        except (json.JSONDecodeError, OSError):
            accepted = False
    if out.exists() and accepted and not force:
        die(f"{out.name} is marked accepted in {sc.name}; pass --force to replace "
            f"it (and say why in docs/WORKLOG.md)", 2)
    if out.exists() and not force:
        die(f"{out.name} already exists; pass --force to replace it", 2)


def run(args: argparse.Namespace) -> int:
    out = Path(args.out) if args.out else MUSIC_DIR / f"{args.cue}.ogg"
    check_overwrite(out, args.force)
    src = decode(Path(args.input))

    y, info = master(src, args)
    problems, warnings = gate(info["seam"])

    encode_ogg(y, out, args.quality, args.rate)
    shipped = decode(out)
    shipped_report = seam_report(shipped, 0)
    info.update({
        "cue": args.cue,
        "source": str(Path(args.input).name),
        "output": display_path(out),
        "bytes": out.stat().st_size,
        "kbps": round(out.stat().st_size * 8 / info["loop_seconds"] / 1000, 1),
        "quality": args.quality,
        "encode_rate": args.rate,
        "seed": args.seed,
        "prompt": args.prompt,
        "encoded_seconds": round(len(shipped) / SR, 4),
        "encoded_seam": shipped_report,
        "gate": {"passed": not problems, "problems": problems,
                 "warnings": warnings,
                 "limits": {"seam_vs_baseline_db": SEAM_VS_BASELINE_DB,
                            "rms_step_advisory_db": RMS_STEP_ADVISORY_DB,
                            "fade_gain_advisory_db": FADE_GAIN_ADVISORY_DB,
                            "mono_loss_db": MONO_LOSS_DB}},
        "mastered_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
    })
    sc = sidecar_path(out)
    sc.write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8")

    s = info["seam"]
    shape = info["mode"] + (f"/{info['fade_curve']}" if info["fade_curve"] else "")
    print(f"{args.cue or out.stem}: {info['loop_seconds']:.2f} s, "
          f"{shape}, {info['lufs']:.2f} LUFS, {info['true_peak']:.2f} dBTP, "
          f"gain {info['gain_db']:+.2f} dB{' (peak-limited)' if info['peak_limited'] else ''}")
    print(f"  seam  wrap {s['wrap_delta_dbfs']:.1f} dBFS vs baseline "
          f"{s['baseline_dbfs']:.1f} ({s['wrap_vs_baseline_db']:+.1f} dB), "
          f"join {s['join_delta_dbfs']:.1f}, rms step {s['rms_step_db']:.2f} dB, "
          f"mono {s['mono_delta_db']:+.2f} dB, fade {s['fade_gain_db']:+.2f} dB")
    print(f"  enc   {info['bytes'] / 1024:.0f} KiB, {info['kbps']:.0f} kbps, "
          f"{info['encoded_seconds']:.4f} s decoded "
          f"(delta {1000 * (info['encoded_seconds'] - info['loop_seconds']):+.1f} ms)")
    print(f"  sidecar {display_path(sc)}")
    for w in warnings:
        print(f"  WARN {w}")
    if problems:
        for p in problems:
            print(f"  FAIL {p}", file=sys.stderr)
        print("  not shipped as a loop - fix the source or pass --mode declick", file=sys.stderr)
        return 1
    return 0


def check(args: argparse.Namespace) -> int:
    """Measure an existing loop: no trim, no encode, no writes."""
    path = Path(args.check_path)
    y = decode(path)
    seconds = len(y) / SR
    _loop_len, bar_seconds, loop_seconds = loop_layout(args.bpm, args.bars, args.beats)
    loud = measure(y)
    seam = seam_report(y, 0)
    problems, warnings = gate(seam)
    bars_actual = seconds / bar_seconds
    if abs(bars_actual - args.bars) > 0.02:
        problems.append(
            f"{bars_actual:.2f} bars at {args.bpm:g} bpm, expected {args.bars} "
            f"({seconds:.3f} s vs {loop_seconds:.3f} s)")
    if loud["true_peak"] > TARGET_TP:
        problems.append(
            f"true peak {loud['true_peak']:.2f} dBTP exceeds the {TARGET_TP:.1f} "
            f"ceiling by {loud['true_peak'] - TARGET_TP:.2f} dB")
    if abs(loud["lufs"] - TARGET_LUFS) > 0.5:
        warnings.append(
            f"{loud['lufs']:.2f} LUFS against a {TARGET_LUFS:.0f} target "
            f"({loud['lufs'] - TARGET_LUFS:+.2f} dB) - cue changes will step in level")
    print(f"{display_path(path)}: {seconds:.3f} s ({bars_actual:.2f} bars at "
          f"{args.bpm:g} bpm), {loud['lufs']:.2f} LUFS, {loud['true_peak']:.2f} dBTP, "
          f"{path.stat().st_size / 1024:.0f} KiB")
    print(f"  seam  wrap {seam['wrap_delta_dbfs']:.1f} dBFS vs baseline "
          f"{seam['baseline_dbfs']:.1f} ({seam['wrap_vs_baseline_db']:+.1f} dB), "
          f"rms step {seam['rms_step_db']:.2f} dB, mono {seam['mono_delta_db']:+.2f} dB")
    for w in warnings:
        print(f"  WARN {w}")
    for p in problems:
        print(f"  FAIL {p}", file=sys.stderr)
    return 1 if problems else 0


# ---------------------------------------------------------------------------
# self-test: no ComfyUI, no GPU, no generated audio needed
# ---------------------------------------------------------------------------

def synth_bed(seconds: float, bpm: float, sr: int = SR) -> np.ndarray:
    """A 100 bpm ambient bed with a sub pulse, so the test has real transients."""
    n = int(round(seconds * sr))
    t = np.arange(n, dtype=np.float64) / sr
    bar = 4 * 60.0 / bpm
    pad = (0.16 * np.sin(2 * math.pi * 220.0 * t)
           + 0.10 * np.sin(2 * math.pi * 261.63 * t + 0.4)
           + 0.08 * np.sin(2 * math.pi * 329.63 * t + 1.1))
    pad *= 0.75 + 0.25 * np.sin(2 * math.pi * t / (4 * bar))
    beat = (t % (60.0 / bpm)) / (60.0 / bpm)
    kick = 0.35 * np.exp(-beat * 24.0) * np.sin(2 * math.pi * 55.0 * t)
    noise = 0.012 * np.random.default_rng(7).standard_normal(n)
    mono = pad + kick + noise
    return np.stack([mono, mono * 0.92], axis=1).astype(np.float32)


def selftest() -> int:
    print("selftest: synthetic 84 s bed -> 76.8 s loop")
    tmp = Path(tempfile.mkdtemp(prefix="music_loop_selftest_"))
    src = synth_bed(84.0, DEFAULT_BPM)
    wav = tmp / "bed_84s.wav"
    with wave.open(str(wav), "wb") as fh:
        fh.setnchannels(2)
        fh.setsampwidth(2)
        fh.setframerate(SR)
        fh.writeframes((np.clip(src, -1, 1) * 32767).astype("<i2").tobytes())

    ns = argparse.Namespace(
        input=str(wav), out=str(tmp / "sector.ogg"), cue="sector", bpm=DEFAULT_BPM,
        bars=DEFAULT_BARS, beats=DEFAULT_BEATS, mode="equal-power",
        crossfade_bars=DEFAULT_CROSSFADE_BARS, fade_curve="auto",
        declick_ms=DEFAULT_DECLICK_MS, start=0.0, quality=OGG_QUALITY, rate=SR,
        seed=0, prompt="selftest", force=True,
    )
    rc = run(ns)
    ok = rc == 0
    side = json.loads((tmp / "sector.json").read_text(encoding="utf-8"))
    ok = ok and abs(side["loop_seconds"] - 76.8) < 0.001
    ok = ok and -17.0 <= side["lufs"] <= -15.5
    ok = ok and side["true_peak"] <= TARGET_TP + 0.05
    ok = ok and side["fade_curve"] == "linear"  # correlated bed -> flat head
    ok = ok and abs(side["seam"]["fade_gain_db"]) <= 1.5
    print(f"selftest: pipeline {'PASS' if ok else 'FAIL'} "
          f"(curve {side['fade_curve']}, fade {side['seam']['fade_gain_db']:+.2f} dB)")

    # a deliberately broken loop must be caught, not shipped
    bad = np.zeros((SR, 2), dtype=np.float32)
    bad[:, 0] = 0.05 * np.sin(2 * math.pi * 220 * np.arange(SR) / SR)
    bad[0, 0] = 0.9  # a click exactly at the wrap
    bad_report = seam_report(bad, 0)
    caught = gate(bad_report)[0] != []
    print(f"selftest: click detection {'PASS' if caught else 'FAIL'} "
          f"(wrap {bad_report['wrap_delta_dbfs']:.1f} dBFS, "
          f"{bad_report['wrap_vs_baseline_db']:+.1f} dB over baseline)")

    # a wide (out-of-phase) bed must fail the mono check
    wide = np.zeros((SR, 2), dtype=np.float32)
    tone = 0.2 * np.sin(2 * math.pi * 220 * np.arange(SR) / SR)
    wide[:, 0], wide[:, 1] = tone, -tone
    mono_caught = any("mono" in p for p in gate(seam_report(wide, 0))[0])
    print(f"selftest: mono check {'PASS' if mono_caught else 'FAIL'}")

    # contract 6: an existing cue is not replaced silently
    ns.force = False
    try:
        run(ns)
        guard_ok = False
        guard_detail = "run() did not refuse"
    except SystemExit as exc:
        guard_ok = exc.code == 2
        guard_detail = f"exit {exc.code}"
    print(f"selftest: overwrite guard {'PASS' if guard_ok else 'FAIL'} ({guard_detail})")

    # the declick fallback must still ship a loop and record its window
    ns.force = True
    ns.out = str(tmp / "debrief.ogg")
    ns.cue = "debrief"
    ns.mode = "declick"
    declick_rc = run(ns)
    declick_side = json.loads((tmp / "debrief.json").read_text(encoding="utf-8"))
    declick_ok = declick_rc == 0 and declick_side["declick_ms"] == DEFAULT_DECLICK_MS
    print(f"selftest: declick fallback {'PASS' if declick_ok else 'FAIL'} "
          f"({declick_side['seam']['wrap_delta_dbfs']:.1f} dBFS wrap)")

    ok = ok and caught and mono_caught and guard_ok and declick_ok
    shutil.rmtree(tmp, ignore_errors=True)
    print(f"selftest: {'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="Master a generated bed into a seamless OGG loop "
                    "(docs/AUDIO.md section 5).")
    ap.add_argument("--in", dest="input", help="source audio (any ffmpeg format)")
    ap.add_argument("--out", help="output .ogg (default assets/audio/music/<cue>.ogg)")
    ap.add_argument("--cue", default="", help="cue name: title / sector / debrief")
    ap.add_argument("--bpm", type=float, default=DEFAULT_BPM)
    ap.add_argument("--bars", type=int, default=DEFAULT_BARS)
    ap.add_argument("--beats", type=int, default=DEFAULT_BEATS, help="beats per bar")
    ap.add_argument("--start", type=float, default=0.0,
                    help="seconds to skip so bar 1 lands on a downbeat")
    ap.add_argument("--mode", choices=("equal-power", "declick"),
                    default="equal-power",
                    help="equal-power wrap crossfade, or a 40 ms declick cut")
    ap.add_argument("--crossfade-bars", type=float, default=DEFAULT_CROSSFADE_BARS)
    ap.add_argument("--fade-curve", choices=("auto", "equal-power", "linear"),
                    default="auto",
                    help="auto picks whichever curve keeps the head level flat")
    ap.add_argument("--declick-ms", type=float, default=DEFAULT_DECLICK_MS)
    ap.add_argument("--quality", type=int, default=OGG_QUALITY, help="vorbis -q:a")
    ap.add_argument("--rate", type=int, default=SR,
                    help="encoder sample rate (default 48000; 22050 is transparent "
                         "for band-limited pads and halves the bitrate)")
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--prompt", default="", help="generation prompt, for the sidecar")
    ap.add_argument("--force", action="store_true",
                    help="replace an existing/accepted cue")
    ap.add_argument("--check", dest="check_path", metavar="FILE",
                    help="measure an existing loop instead of writing one")
    ap.add_argument("--selftest", action="store_true",
                    help="run the synthetic end-to-end check and exit")
    args = ap.parse_args(argv)

    if args.selftest:
        return selftest()
    if args.check_path:
        return check(args)
    if not args.input:
        ap.error("--in is required (or --selftest)")
    if not args.cue and not args.out:
        ap.error("--cue or --out is required")
    if args.bars <= 0 or args.bpm <= 0 or args.beats <= 0:
        ap.error("--bars, --bpm and --beats must be positive")
    if args.mode == "equal-power" and args.crossfade_bars <= 0:
        ap.error("--crossfade-bars must be > 0 for equal-power mode")
    return run(args)


if __name__ == "__main__":
    raise SystemExit(main())

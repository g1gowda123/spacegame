# Audio & Music — the ECHO lane

Owner: **ECHO** (music dev, joined 15:00). Scope: soundtrack generation in ComfyUI,
loop mastering, mix, and the `MusicDirector` integration contract. `f` keeps SFX,
UI feel, and the `AudioStreamPlayer` pool; this lane does not touch those cues.

> **Attribution:** generated music is produced by the user in ComfyUI on their
> machine (same rule as the art pipeline). This lane owns prompts, presets,
> post-processing, loop verification, and wiring.

---

## 1. The question: can ComfyUI make a good soundtrack?

**Yes for source material. No for a finished, loop-ready score.**

ComfyUI is now a real music generator: ACE-Step 1.5 and Stable Audio 3 are native
(native audio nodes + official templates), and the MCP server exposes both through
`generate_image action:"audio"` with `duration`, `prompt`, and — for ACE —
`bpm`, `musical_key`, `lyrics`. What it does **not** do is hand you a
seamless, loudness-matched, BPM-locked loop at the size a 640×360 WebGL game can
ship. That last part is a mastering problem, and it is this lane's job.

Verified state of the art (June–Oct 2026 evaluations, not vendor claims):

| Claim | Evidence |
|---|---|
| Stable Audio 3 is the strongest open instrumental model | First on all 9 quality metrics in an independent re-scoring (Kernel Audio Distance, extrapolated FAD, CLAP, Audiobox Aesthetics, MuQ-MuLan), against ACE-Step 1.5 and DiffRhythm 2 — 395 instrumental prompts. Lead survives bootstrap resampling. |
| It is also the only one that obeys tempo/key | Named tempo hit within 4% on **61%** of clips, exact key on **64%** (key detector ceiling ≈72%). ACE-Step 1.5 is at **chance** on exact key (0.067 vs 0.042 random) — it makes coherent music, it just ignores the tempo/key you typed. |
| For loops, that is the whole game | A bed that drifts 3 BPM or lands in the wrong key will not crossfade into the next cue. This is why SA3 is the primary engine here, not the one with the bigger parameter count. |
| ACE-Step wins elsewhere | Structured songs, vocals, lyric alignment, covers, repaint, stem extraction, MIT licence, 50+ languages, 10 s–10 min. Its 4B XL decoder is the best-sounding local option, but it is slow (median ~168 s per track on a 3090) and needs 12–20 GB VRAM. |
| Honest ceiling | Community listening tests put ACE-Step around "Suno v3–v4.5", not v5: hiss, mechanical vocals, occasional out-of-tune drift. Instrumental ambient/electronic beds are its strong case; vocals are not our case at all. |

**Verdict for this game:** generate instrumental beds + stingers in ComfyUI,
then master them here. That is enough for a genuinely good 10–15 minute
roguelite score. It is not enough to skip the mix.

---

## 2. Engine matrix — measured facts, not vibes

| | **Stable Audio 3 Small-Music** | **Stable Audio 3 Medium** | **ACE-Step 1.5 Turbo AIO** |
|---|---|---|---|
| Checkpoint | 2.27 GB | 9.22 GB | 10.03 GB (all-in-one) |
| Extra model | `t5gemma_b_b_ul2` 1.19 GB | same 1.19 GB | none — planner LM + DiT + VAE inside the AIO |
| Total download | **3.46 GB** | 10.41 GB | 10.03 GB |
| VRAM | on-device, CPU-capable | GPU, Flash-Attention-2 build | <4 GB with offload, 8 GB comfortable |
| Max length | 2:00 | ~6:20 | 10:00 |
| Obey tempo/key | yes (61% / 64%) | yes | no (chance) |
| Song structure / vocals | no (instrumental-first) | no | **yes** |
| Licence | Stability Community (free <$1M revenue) | same | **MIT** |
| Best for here | **all three loops** | final-quality re-render | a melodic title theme if we want one |

Decision: **SA3 Small-Music is the primary engine.** It is a 3.5 GB install,
runs on the 4060, and its tempo/key adherence is what a loop needs. ACE-Step
stays as the fallback for a "real song" title cue (MIT is also the cleanest
licence for a public repo). This is a decision about *fit*, not about which
model is bigger.

---

## 3. What the game needs (spec)

Three cues, one shared tempo so crossfades are musical:

- **Tempo 100 BPM, 4/4, A minor.** 100 BPM = 0.600 s/beat = **2.400 s/bar**;
  32 bars = **76.8 s** loop. 32 bars is long enough to not feel repetitive in a
  10–15 min run and short enough to stay under the size budget.
- Cues: `title`, `sector`, `debrief`. `report` reuses `debrief`; `design`/`draft`
  reuse `title` at lower intensity.
- Instrumental only. No vocals, no lyrics, no spoken word.
- Steady-state arrangement: no intro, no outro, no riser, no fade, no drop.
  The loop point must be invisible.
- Mono-compatible (one evaluator lost 9.3 dB on a single speaker — check it).
- Loudness matched across cues: **−16 LUFS integrated, true peak ≤ −1.5 dBTP**.
- Delivery: OGG Vorbis q3 (~96 kbps stereo) ≈ 0.92 MB per 76.8 s cue;
  **3 files ≤ 2.8 MB**, inside the ≤3 MB budget from the 12:48 task.
- Runtime: 2 s equal-power crossfade on screen change; **−6 dB duck** while a
  hazard telegraph is live; hard duck to −12 dB on failure overlay.

Sound direction ("Cold Signal"): agency-electronica, not space-opera. Analog
pads, FM bells, sub pulse, brushed noise, sonar pings, telemetry blips. Quiet
enough that the UI clicks and the hazard thud sit on top of it.

**What actually shipped is 84 BPM / 24 bars**, not the 100 BPM / 32 bars above:
the three beds in `assets/music/` are 68.571 s each (24.00 bars at 84 BPM), and
`scripts/music_director.gd` documents the 2 s crossfade as "lands within a bar at
84 BPM". The tempo change is fine — it is the shipped, working choice — but the
numbers in this section are the original spec, not the delivery. Measurements of
the delivery are in §5.1.

---

## 4. Prompt recipes (copy-paste)

Shared tail for every cue:

```
instrumental, no vocals, steady-state loop, no intro, no outro, no fade,
no build-up, no riser, no drop, no silence, 100 bpm, 4/4, A minor,
clean mix, mono-compatible, seamless loop
```

| Cue | Prompt body | Why |
|---|---|---|
| `title` | `slow ambient analog synth pad bed, deep space, sparse sonar ping on the bar, warm detuned chords, distant sub pulse, no drums, patient and vast, mission-control hush` | Establishes the key and the "agency" tone; no rhythm means it never fights menu clicks. |
| `sector` | `tense minimal electronic pulse, muted kick on the beat, ticking closed hi-hat, low ostinato bass, glassy arpeggio, restrained mission-control tension, subtle noise floor, no melody lead` | One steady pulse carries 10–15 min without fatigue; ostinato hides the loop seam. |
| `debrief` | `warm analog resolution pad, soft electric piano chords, gentle shaker, hopeful but tired, sparse, low sub, no lead melody` | Emotional release after a sector; same key so the crossfade from `sector` resolves. |

Negative prompt (SA3 supports it): `vocals, singing, lyrics, speech, choir,
drum solo, loud cymbals, riser, build-up, fade out, fade in, silence, crowd,
clipping, distortion, lo-fi wobble`.

Settings: SA3 category **Music**, `use_reprompt = off` for loops (the Qwen
expander likes to invent intros and outros). Generate `duration = 84` s
(76.8 s loop + 7.2 s = 3 bars of tail for the wrap-around), batch 4, pick by ear.
ACE-Step fallback: 8 steps, cfg 1, euler/simple, `bpm=100`, `musical_key="A minor"`,
`lyrics="[inst]"`.

---

## 5. Loop mastering (`tools/make_music_loop.py` — shipped 18:40)

**Status: implemented, self-tested, never yet run on generated audio.** Evidence
is `python tools/make_music_loop.py --selftest` (exit 0 here on ffmpeg 9.0.1,
numpy 2.5.2): it builds an 84 s synthetic bed with a sub pulse on the beat,
masters it, encodes it, decodes it back and re-measures the shipped file. It
cannot prove a Stable Audio 3 track loops well until the download is approved.

```bash
# master a raw bed into assets/audio/music/<cue>.ogg (+ <cue>.json)
python tools/make_music_loop.py --in raw/sector_84s.wav --cue sector \
    --seed 4101 --prompt "tense minimal electronic pulse, 100 bpm, A minor"
# the 40 ms declick fallback, and the manual downbeat offset
python tools/make_music_loop.py --in raw/title.wav --cue title --start 1.37 \
    --mode declick
# no audio needed: synthetic end-to-end check
python tools/make_music_loop.py --selftest
```

The contract it implements:

1. Trim to `32 × bar` at 100 BPM = 76.8 s, offset by `--start` seconds. Downbeat
   alignment stays a human decision: the tool cannot hear where bar 1 is, so it
   takes the offset rather than guessing.
2. Wrap-around crossfade: the tail past the loop point is folded **into the
   head**, so the loop ends on `src[N-1]` and opens on `src[N]` — the same
   performance, so the wrap is sample-continuous by construction, while the
   first 2 bars fade in underneath. `--mode declick` is the 40 ms fallback for
   material the crossfade would smear.
3. Loudness to −16 LUFS with −1.5 dBTP as a ceiling, so cue changes do not jump.
4. Seam verified numerically, and the gate is a **comparison, not a constant**:
   the wrap discontinuity must not exceed the 99.99th percentile of the file's
   own adjacent-sample steps by more than 6 dB. That is the click test — a seam
   quieter than the material's own transients cannot click — and it catches a
   planted 0.9 full-scale click at +55.9 dB over baseline.
5. OGG q3 (`libvorbis -q:a 3`) + a `.json` sidecar with bpm, bars, loop_seconds,
   lufs, true_peak, seed, prompt, the full seam report, the encoded-file delta
   and the gate verdict. The shipped file is decoded again and re-measured, so
   the numbers describe what is actually in the OGG, not the pre-encode buffer.
6. An existing cue is never replaced silently: `--force` is required, and a
   sidecar with `"accepted": true` gives a louder refusal.

Measured on the self-test fixture (synthetic, so read it as "the tool works",
not "the score is good"): **76.80 s, −16.00 LUFS, −3.14 dBTP**, wrap
**−33.8 dBFS vs a −22.6 dBFS internal baseline (−11.2 dB, i.e. below it)**,
crossfade exit −38.8 dBFS, RMS step 3.75 dB, mono fold-down +0.01 dB, fade level
+0.77 dB, **788 KiB at 84 kbps**, decoded length delta **0.0 ms**.

Two decisions worth keeping:

- **`loudnorm` is used as a meter, not as the filter.** Its lookahead delay and
  192 kHz internal rate would shift the loop samples against each other and
  move the seam. The tool measures with it (pass 1), applies that gain in numpy,
  then measures again (pass 2) to report what actually shipped. Waveform and
  seam are therefore untouched by mastering.
- **The fade curve is chosen by measurement (`--fade-curve auto`).** Equal-power
  is the textbook choice for uncorrelated material, but a loop's head and tail
  are the *same* music, so equal-power sums +2.9 dB on the first bars (measured).
  `auto` renders both curves and keeps whichever leaves the head level flat
  (linear, +0.77 dB on the fixture); `--fade-curve equal-power` still forces the
  old behaviour.
- **RMS step is advisory, not fatal.** A beat-aligned bed legitimately drops a
  kick exactly on the loop point, which lifts the first 10 ms by ~3.8 dB without
  being a click. Only a >6 dB step (a hole) or a >1.5 dB crossfade level bump is
  printed as a warning; the wrap test above is what fails the build.

`ffmpeg` 8.x/9.x is already on the box; the tool is build-time only, so it adds
no runtime dependency. Everything is stdlib + numpy — no `soundfile`, no
`pydub`, no ffmpeg-python.

### 5.1 The shipped beds, measured (18:55)

`f` landed three loops in `7f7cbc8` (`assets/music/title.ogg`, `sector.ogg`,
`debrief.ogg` + `scripts/music_director.gd`). They were not mastered with this
tool, so here is the independent measurement — `python tools/make_music_loop.py
--check <file> --bpm 84 --bars 24`, which reads the shipped OGG and writes
nothing:

| bed | length | bars @84 | LUFS | true peak | seam wrap vs baseline | mono | size |
|---|---|---|---|---|---|---|---|
| `title` | 68.571 s | 24.00 | −15.74 | −3.71 dBTP | −15.7 dB | +0.09 dB | 208 KiB |
| `sector` | 68.571 s | 24.00 | −16.90 | **−0.60 dBTP** | −18.3 dB | +0.02 dB | 349 KiB |
| `debrief` | 68.571 s | 24.00 | −16.91 | −3.34 dBTP | −14.4 dB | +0.04 dB | 231 KiB |

- **Seams are clean.** In all three, wrapping the file is 14–18 dB *smaller* than
  the largest adjacent-sample step already inside it — the loop point cannot
  click, which is what ORION asked to be shown numerically rather than by ear.
- **`sector` breaks the true-peak ceiling: −0.60 dBTP against −1.5.** It will clip
  on a playback chain that adds any gain, and the peak is 0.9 dB over. Fix is
  −0.9 dB on that one file (a re-encode; the audio owner's call, not mine).
- **The cues are not level-matched:** −15.74 vs −16.90 vs −16.91 LUFS, a 1.16 dB
  spread, so title→sector steps down audibly. −1.2 dB on `title` would match all
  three at ≈ −16.9.
- The large "rms step" figures (7.8 / 32.6 / 14.1 dB) are the *downbeat landing on
  the loop point*, which is musical for a beat-driven bed, not a click — that is
  exactly why the tool treats RMS step as advisory and the wrap comparison as the
  gate.
- Total music weight is **788 KiB**: inside the ≤3 MB budget and the ≤1 MB-per-bed
  constraint.

Nothing above is fixed by me: the beds are the audio owner's files, and a
re-encode is a content change. The numbers are here so the decision is theirs.

### 5.2 One bed per exoplanet *type* (nine beds, 2026-11-15)

The brief was "different ambient music for different exoplanet types, but not
72 tracks, and the change must not sound like an mp3 starting". So the beds are
keyed to the **biome**, which is the only type axis the planet data has:

```
temperate 25 · barren 14 · arid 7 · volcanic 7 · crystal 7 · cryo 4 · iron 4 · sulfur 3 · ammonia 1
```

Nine beds for 72 planets. `data/exoplanets.json` is the source of truth;
`tools/audit_music.gd` fails if a biome used by a planet has no bed.

**Why the handover is a morph, not a cut.** Three constraints, all enforced by
the generator (`tools/make_biome_music.py`):

1. **Same clock.** Every bed is 24 bars at 84 BPM = 68.5714 s on A. The director
   starts the incoming bed at the outgoing bed's *playback position*, not 0.0, so
   bar, beat and root line up across the fade. A restart at 0.0 is exactly the
   "new mp3" artefact the brief ruled out.
2. **Same spine.** A1+E2 drone, a soft pulse on beats 1 and 3, and the noise
   floor are byte-identical in all nine beds. Only pad colour, partials, filter,
   shimmer and bells differ, so a fade moves timbre and nothing else.
3. **No intro, no drop, no fade-out.** Two bars are rendered past the loop point
   and folded into the head by `tools/make_music_loop.py` (§5), so the loop is
   sample-continuous and there is no "start" to hear.

Measured (`--check`-style read of the shipped OGGs, all nine PASS):

| bed | centroid | LUFS | true peak | seam wrap vs baseline | mono | size |
|---|---|---|---|---|---|---|
| `temperate` | 499 Hz | −16.00 | −4.02 dBTP | −9.9 dB | +0.07 dB | 198 KiB |
| `arid` | 399 Hz | −16.00 | −4.97 dBTP | −28.7 dB | +0.05 dB | 200 KiB |
| `cryo` | 794 Hz | −16.01 | −4.08 dBTP | −25.9 dB | +0.05 dB | 265 KiB |
| `volcanic` | 212 Hz | −16.00 | −4.85 dBTP | −18.5 dB | +0.05 dB | 161 KiB |
| `barren` | 504 Hz | −16.00 | −4.98 dBTP | −22.4 dB | +0.04 dB | 220 KiB |
| `iron` | 569 Hz | −16.00 | −4.47 dBTP | −3.0 dB | +0.05 dB | 224 KiB |
| `sulfur` | 508 Hz | −16.00 | −4.18 dBTP | −12.4 dB | +0.05 dB | 220 KiB |
| `ammonia` | 669 Hz | −16.00 | −4.12 dBTP | −10.8 dB | +0.05 dB | 241 KiB |
| `crystal` | 912 Hz | −16.00 | −4.81 dBTP | −13.4 dB | +0.04 dB | 281 KiB |

- **Distinct, not random.** Centroids span 212–912 Hz in a deliberate order:
  volcanic is a 212 Hz rumble, crystal is 912 Hz glass. Every bed keeps ≥26 % of
  its energy below 200 Hz, so the nine still share a low end and a crossfade
  never loses the floor.
- **All nine at −16.00 LUFS.** This is the one thing the older three cues miss
  (they sit at −15.74 / −16.90 / −16.91, §5.1): a title→sector handover currently
  steps ~1 dB. The new beds remove that step inside the sector.
- **Seams are 3–29 dB below the file's own transient baseline** — the `iron`
  bed is the tightest at −3.0 dB and still under the gate, because its struck
  metal partials are the loudest transients in the set. No bed clicks.
- **1.96 MiB for nine beds**, 19–34 kbps, all 22.05 kHz (§5.3).

### 5.3 Why 22.05 kHz (`make_music_loop.py --rate`)

The beds are band-limited pads: measured energy above 9 kHz is 0–0.5 %. Encoding
at 48 kHz was spending ~35 % of the bitrate on empty spectrum. At 22.05 kHz,
q1, the same bed is 265 KiB instead of 591 KiB and measures identical below
9 kHz. `--rate` is applied **after `-i`** in the ffmpeg call: putting `-ar`
before the input reinterprets the 48 kHz buffer instead of resampling it, which
silently plays every bed at half speed (this bug shipped for one build and was
caught by a spectral probe — the beds read 55 kbps and a 794 Hz centroid at
"48 kHz" that was really 24 kHz of content). `--rate` is recorded in the sidecar
as `encode_rate` so a re-encode cannot drift back.

---

## 6. Runtime contract (for whoever wires it)

- New autoload `MusicDirector` (`scripts/music_director.gd`), loaded after `GameState`.
  API: `play(context: String, biome: String = "")`, `set_duck(on: bool)`, `stop()`.
- One `AudioStreamPlayer` per active cue (two max during a crossfade), bus `Master`
  (there is no separate `Music` bus in `project.godot`; ducking is done in gain,
  not by a bus). `AudioStreamOggVorbis.loop = true`, `loop_offset = 0.0`.
- **Phase-locked handover**: `play()` reads the outgoing player's position
  (`get_playback_position()` + `AudioServer.get_time_since_last_mix()` −
  `AudioServer.get_output_latency()`, wrapped to the loop) and starts the
  incoming bed at that position. Measured drift −0.03…−0.05 s over four
  handovers (`tools/music_probe.gd`), i.e. the position is preserved; a restart
  would show the full elapsed time as drift.
- **Linear crossfade, 4.0 s** (1.4 bars at 84 BPM). Not equal-power: the beds are
  *correlated* (shared drone/pulse/root), so equal-power sums coherently and
  measures **+2.7…+3.5 dB** at the fade midpoint. Linear measures **+0.9…+1.6 dB
  worst case, mid-fade within 0.1 dB**. Same conclusion as the loop seam in §5.
- Duck is a gain multiplier on both decks (`set_duck`, −6 dB, 0.35 s), so a
  telegraph arriving mid-handover does not fight the fade.
- Sector bed is chosen by `sec["planet"]["biome"]`; unknown biomes fall back to
  the neutral `sector` bed, so new planet data cannot silence a mission.
- Headless guard: if `DisplayServer.get_name() == "headless"` do nothing
  (the export/smoke tests must stay clean and silent).
- `_exit_tree()` stops players and clears streams — the 02:56 leak fix must not regress.
- Context map lives with the director, not in each scene: `title`/`design`/`draft` →
  `title`, `sector` → per-biome bed, `debrief`/`report` → `debrief`.
- Web budget: music total is **2.75 MiB** (788 KiB context cues + 1.96 MiB biome
  beds); the ZIP grows by that much only. The old ≤3 MB line still holds.

---

## 7. Local reality on this machine (checked 15:00)

- GPU: RTX 4060 Laptop, **7.7 GB VRAM**, ComfyUI 0.45.0, PyTorch 2.14.1+cu130.
- System RAM: 15 GB total, **~1.3 GB available** at check time (SDXL resident).
  That is the blocker for the 10 GB ACE AIO — offload needs RAM headroom.
- Disk: 124 GB free. Downloads are fine.
- Plan: `clear_vram` → download SA3 Small-Music + t5gemma (3.46 GB) → one 84 s
  `sector` test at batch 2. If RAM stays tight, run Medium/ACE on the RunPod path
  (`runpod` MCP) instead of fighting the laptop.

Do **not** download or generate until the user approves the 3.46 GB transfer —
the art queue shares this GPU.

---

## 8. Status & open items

- [x] `tools/make_music_loop.py` (seam check + loudnorm + OGG) — shipped 18:40 by `e`, self-tested.
- [x] Generate and master 3 cues — landed in `assets/music/` (24 bars @ 84 BPM, 788 KiB total); measured in §5.1 (wrap seams clean 14–18 dB below baseline; 2 minor gain/peak adjustments noted).
- [x] `MusicDirector` autoload (`scripts/music_director.gd`) + duck hook on the hazard telegraph in `sector.gd`.
- [x] Size budget verified: 788 KiB total (well under the ≤3 MB budget).
- [x] Per-biome sector beds (2026-11-15): nine beds for the nine planet biomes, 1.96 MiB, all −16.00 LUFS, phase-locked handover (§5.2–5.3); audited by `tools/audit_music.gd` and `tools/music_probe.gd`.
- [ ] Web re-export: package latest tree into `build/web` via `tools/release.sh`.
- [ ] Optional: User approval for SA3 Small-Music download (3.46 GB) if external model stem replacements are desired later.
- [ ] Phase 2 (optional): intensity variants for reactive layers. Currently reactive layer uses volume ducking (−6 dB on hazard telegraph).

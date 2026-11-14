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

## 5. Loop mastering (`tools/make_music_loop.py` — next)

The generator gives a track; the tool makes it a loop. Contract:

1. Trim to `32 × bar` at 100 BPM = 76.8 s, aligned to the first downbeat.
2. Wrap-around crossfade: overlap the last 2 bars with the first 2 bars
   (equal-power, 4.8 s). Falls back to a 40 ms declick when the material has a
   melody the crossfade would smear.
3. Loudness-normalise to −16 LUFS / −1.5 dBTP (two-pass `loudnorm`), so cue
   changes do not jump in level.
4. Verify the seam numerically: report max sample discontinuity, RMS step across
   the loop point, and a mono fold-down delta. Fail loudly rather than ship a click.
5. Encode OGG q3 + write `assets/audio/music/<cue>.ogg` and a `.json` sidecar
   (`bpm`, `bars`, `loop_seconds`, `lufs`, `true_peak`, `seam_delta`, seed, prompt).
6. Never overwrite an accepted cue without the `.json` sidecar changing too —
   the work log cites these numbers.

`ffmpeg` 8.x is on the box; no new runtime dependency (the tool is build-time only).

---

## 6. Runtime contract (for whoever wires it)

- New autoload `MusicDirector` (`scripts/music_director.gd`), loaded after `GameState`.
  API: `play(context: String)`, `duck(on: bool)`, `stop()`.
- One `AudioStreamPlayer` per active cue (two max during a crossfade), bus `Music`.
  `AudioStreamOggVorbis.loop = true`, `loop_offset = 0.0`.
- 2 s equal-power crossfade on `play()`; 0.25 s ramp for duck/unduck.
- Headless guard: if `DisplayServer.get_name() == "headless"` do nothing
  (the export/smoke tests must stay clean and silent).
- `_exit_tree()` stops players and clears streams — the 02:56 leak fix must not regress.
- Context map lives with the director, not in each scene: `title`/`design`/`draft` →
  `title`, `sector` → `sector`, `debrief`/`report` → `debrief`.
- Web budget: total `assets/audio/music/` ≤ 3 MB; the ZIP grows by that much only.

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

## 8. Open items

- [ ] User approval for the SA3 Small-Music download (3.46 GB).
- [ ] `tools/make_music_loop.py` (seam check + loudnorm + OGG).
- [ ] Generate and master `title` / `sector` / `debrief`; post seam + LUFS numbers.
- [ ] `MusicDirector` autoload + duck hook on the hazard telegraph.
- [ ] Web re-export and size check (`build/web` + ≤3 MB music).
- [ ] Phase 2 (optional): intensity variants for reactive layers. SA3 has no
      stem output; ACE-Step's extract/lego nodes are WIP. Until then the reactive
      story is volume ducking, not stem mixing — say so honestly in the README.

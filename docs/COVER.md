# Cover art — ORBIT & OUTPLAY

## Final files

| File | Use |
|---|---|
| `screenshots/cover_630x500.png` | itch.io / store cover, 630×500 |
| `screenshots/cover_315x250.png` | thumbnail, 315×250 |
| `submission/cover_630x500.png` | submission package copy |
| `submission/cover_315x250.png` | submission thumbnail copy |

The cover is a **generated illustration, not a screenshot**. It shows an astronaut
on a black basalt ridge holding a cyan data core, with the survey lander behind
and an amber solar-storm ribbon on the right. The art pass is text-free; the
wordmark and data strip are composited separately so the type is crisp.

## ComfyUI workflow

The final graph is `tools/comfy_workflows/cover_survey_api.json` (API format,
12 nodes): SDXL Base 1.0 → Pixel Art XL LoRA → base KSampler at 1280×1024 →
1.5× lanczos ImageScale → VAEEncode → low-denoise KSampler at 1920×1536 →
VAEDecode → SaveImage.

```bash
# base + 1.5x detail pass, text-free raw
python tools/gen_cover.py --variant e --seed 7501 --hires --raw-only

# typography, safe area, data strip, AI-generated-art mark
python tools/compose_cover.py assets/raw/cover_hires_00001_.png \
  --out screenshots/cover_630x500.png \
  --thumb screenshots/cover_315x250.png
```

Generation settings: 28 steps, CFG 5.5, `dpmpp_2m` + `karras`, LoRA strength
0.85, hires denoise 0.32. Other seeds/variants are exploratory and live under
`assets/raw/cover_*`; variant E was selected for the strong human focal point and
the clean top-third title space.

## Art direction / prompt

> hero cover illustration for a space survey game, lone astronaut in a bone-white
> suit kneeling on a black basalt ridge, holding a glowing cyan data core in both
> hands, a compact four-legged lunar lander with a gold-foil body and tall dish
> behind them, enormous banded exoplanet rising in the deep teal sky, orange
> solar storm ribbons on the right, dust blowing off the ridge, large clean dark
> negative space across the top third, cinematic low-angle composition, 16-bit
> pixel-art illustration, high contrast, warm bone and amber accents, no text,
> no letters, no UI, no HUD, no frame

Negative: text, letters, words, logo, watermark, signature, UI, HUD, screenshot,
menu, frame, border, vignette, blurry, photorealistic, 3d render, low contrast,
muddy, noise, oversaturated, cropped subject, duplicate lander, busy composition.

## Typography / compositing

- `assets/ui/Silkscreen-Bold.ttf` for the wordmark and `EXOPLANET SURVEY` kicker.
- `assets/ui/IBMPlexMono-Regular.ttf` for the tagline, NASA/data strip, and
  `AI-GENERATED ART` disclosure.
- Top gradient protects the title from the bright canyon/orb; bottom gradient
  protects the data strip. The art is cropped 630×500 with a 1.035 contrast and
  1.04 saturation lift.
- The visible `AI-GENERATED ART` mark is required by the 2026 Space Apps AI
  disclosure rules; the written disclosure is in `README.md` Credits and
  `submission/PROJECT_PAGE_COPY.md`.

## Reproducibility checklist

- [ ] ComfyUI at `http://127.0.0.1:8188` with `sd_xl_base_1.0.safetensors` and
  `pixel-art-xl.safetensors`.
- [ ] `python tools/gen_cover.py --variant e --seed 7501 --hires --raw-only`
  produces the raw under `assets/raw/`.
- [ ] `python tools/compose_cover.py <raw>` writes the 630×500 and 315×250
  covers.
- [ ] Final files are checked at 630×500 and 315×250; title remains legible,
  bottom data strip not clipped, AI disclosure visible.

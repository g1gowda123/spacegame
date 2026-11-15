#!/usr/bin/env python3
"""Composite the generated cover art into the 630x500 store cover.

The art pass is text-free on purpose. This script owns the wordmark, tagline,
safe area, data strip and the required AI-generated-art mark, so the cover can
be re-set for a different crop without regenerating the illustration.
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parent.parent
CREAM = (242, 234, 214)
BONE = (205, 198, 179)
INK = (8, 15, 18)
AMBER = (224, 158, 73)
CYAN = (107, 204, 190)
MUTED = (164, 174, 165)

TITLE_FONT = ROOT / "assets/ui/Silkscreen-Bold.ttf"
MONO_FONT = ROOT / "assets/ui/IBMPlexMono-Regular.ttf"


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size)


def text_width(draw: ImageDraw.ImageDraw, text: str, f: ImageFont.FreeTypeFont) -> int:
    return int(round(draw.textlength(text, font=f)))


def draw_stroked(draw, xy, text, f, fill, stroke=INK, width=2):
    draw.text(xy, text, font=f, fill=fill, stroke_width=width, stroke_fill=stroke)


def top_gradient(im: Image.Image, height: int, alpha: int) -> None:
    g = Image.new("L", (1, height))
    for y in range(height):
        g.putpixel((0, y), int(alpha * (1.0 - y / max(1, height - 1)) ** 1.45))
    mask = g.resize(im.size, Image.Resampling.BILINEAR)
    shade = Image.new("RGBA", im.size, (*INK, 0))
    shade.putalpha(mask)
    im.alpha_composite(shade)


def bottom_gradient(im: Image.Image, start_y: int, alpha: int) -> None:
    h = im.height - start_y
    g = Image.new("L", (1, h))
    for y in range(h):
        g.putpixel((0, y), int(alpha * (y / max(1, h - 1)) ** 1.35))
    mask = Image.new("L", im.size, 0)
    mask.paste(g.resize((im.width, h), Image.Resampling.BILINEAR), (0, start_y))
    shade = Image.new("RGBA", im.size, (*INK, 0))
    shade.putalpha(mask)
    im.alpha_composite(shade)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("raw", type=Path)
    ap.add_argument("--out", type=Path, default=ROOT / "screenshots" / "cover_630x500.png")
    ap.add_argument("--thumb", type=Path, default=ROOT / "screenshots" / "cover_315x250.png")
    ap.add_argument("--tagline", default="DRAFT A REAL EXOPLANET. SURVIVE ITS SURFACE.")
    args = ap.parse_args()

    im = Image.open(args.raw).convert("RGB")
    # 1280x1024 -> 630x500 (1.26:1). A small crop, never a screenshot crop.
    im = ImageOps.fit(im, (630, 500), method=Image.Resampling.LANCZOS,
                      centering=(0.52, 0.50))
    im = ImageEnhance.Contrast(im).enhance(1.035)
    im = ImageEnhance.Color(im).enhance(1.04)
    im = im.convert("RGBA")

    top_gradient(im, 200, 246)
    bottom_gradient(im, 410, 218)

    draw = ImageDraw.Draw(im)
    title_f = font(TITLE_FONT, 44)
    kick_f = font(MONO_FONT, 8)
    tag_f = font(MONO_FONT, 7)
    fact_f = font(MONO_FONT, 7)
    micro_f = font(MONO_FONT, 6)

    # Small agency kicker, then the wordmark with the ampersand in hazard amber.
    kicker = "EXOPLANET SURVEY"
    kw = text_width(draw, kicker, kick_f)
    draw.text(((630 - kw) // 2, 14), kicker, font=kick_f, fill=AMBER)

    parts = [("ORBIT", CREAM), ("  &  ", AMBER), ("OUTPLAY", CREAM)]
    widths = [text_width(draw, p, title_f) for p, _ in parts]
    x = (630 - sum(widths)) // 2
    bbox = draw.textbbox((0, 0), "ORBIT", font=title_f)
    ty = 27 - bbox[1]
    for (part, color), w in zip(parts, widths):
        draw_stroked(draw, (x, ty), part, title_f, (*color, 255), width=3)
        x += w

    # Short promise line, kept above the illustration's focal area.
    tag_w = text_width(draw, args.tagline, tag_f)
    draw.text(((630 - tag_w) // 2, 88), args.tagline, font=tag_f, fill=BONE)

    # Thin datum rule and corner ticks: a field document, not a poster frame.
    draw.line((24, 102, 606, 102), fill=(224, 158, 73, 150), width=1)
    for x, y in ((10, 10), (620, 10), (10, 490), (620, 490)):
        draw.line((x - 4, y, x + 4, y), fill=(242, 234, 214, 95), width=1)
        draw.line((x, y - 4, x, y + 4), fill=(242, 234, 214, 95), width=1)
    draw.rectangle((6, 6, 623, 493), outline=(242, 234, 214, 42), width=1)

    # Bottom data band. Two lines max; the thumbnail still reads the title.
    line1 = "72 REAL EXOPLANETS  ·  13 BIOMES  ·  3-SECTOR CAMPAIGN"
    line2 = "NASA EXOPLANET ARCHIVE  //  PSCOMPPARS"
    l1w = text_width(draw, line1, fact_f)
    l2w = text_width(draw, line2, micro_f)
    draw.text(((630 - l1w) // 2, 447), line1, font=fact_f, fill=BONE)
    draw.text(((630 - l2w) // 2, 461), line2, font=micro_f, fill=AMBER)
    line3 = "1–4 PLAYERS   ·   WEB   ·   NO INSTALL"
    l3w = text_width(draw, line3, micro_f)
    draw.text(((630 - l3w) // 2, 475), line3, font=micro_f, fill=MUTED)

    # Required visible disclosure for AI-generated imagery. Deliberately small
    # but legible at 630px; the written disclosure also lives in the credits.
    mark = "AI-GENERATED ART"
    mw = text_width(draw, mark, micro_f)
    draw.rectangle((630 - mw - 14, 483, 624, 493), fill=(8, 15, 18, 190))
    draw.text((630 - mw - 9, 484), mark, font=micro_f, fill=(205, 198, 179))

    im = im.convert("RGB")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    im.save(args.out, optimize=True)
    args.thumb.parent.mkdir(parents=True, exist_ok=True)
    im.resize((315, 250), Image.Resampling.LANCZOS).save(args.thumb, optimize=True)
    print("wrote", args.out, im.size)
    print("wrote", args.thumb, (315, 250))


if __name__ == "__main__":
    main()

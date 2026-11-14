#!/usr/bin/env python3
"""Build the 7-slide submission deck (backup to the 30-second video)."""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SHOTS = Path(os.environ.get(
    "GODOT_USERDATA",
    Path.home() / ".local/share/godot/app_userdata" / "Orbit & Outplay — Exoplanet Survey",
))
OUT = ROOT / "demo"
OUT.mkdir(exist_ok=True)

W, H = 1280, 720
BG = (6, 9, 15)
PANEL = (13, 21, 34)
LINE = (38, 56, 78)
TEXT = (228, 238, 248)
MUTED = (146, 166, 186)
CYAN = (84, 230, 209)
AMBER = (255, 196, 92)
GREEN = (127, 224, 138)
RED = (255, 93, 108)

PIXEL = str(ROOT / "assets/ui/Silkscreen-Bold.ttf")
MONO = str(ROOT / "assets/ui/IBMPlexMono-Regular.ttf")


def F(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def wrap(draw: ImageDraw.ImageDraw, text: str, font, width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    cur = ""
    for word in words:
        trial = (cur + " " + word).strip()
        if draw.textlength(trial, font=font) <= width:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def shot(path: Path, box: tuple[int, int, int, int]) -> Image.Image:
    im = Image.open(path).convert("RGB")
    x, y, w, h = box
    im = im.resize((w, h), Image.LANCZOS)
    return im


def page() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W, 4], fill=CYAN)
    return im, d


def footer(d: ImageDraw.ImageDraw, n: int, label: str) -> None:
    d.line([60, 674, W - 60, 674], fill=LINE, width=1)
    d.text((60, 688), "ORBIT + OUTPLAY  ·  NASA SPACE APPS 2026", font=F(PIXEL, 9), fill=MUTED)
    d.text((W - 60 - d.textlength(f"{n} / 7", font=F(PIXEL, 9)), 688), f"{n} / 7", font=F(PIXEL, 9), fill=MUTED)
    if label:
        d.text((W - 60 - d.textlength(label, font=F(MONO, 10)), 700), label, font=F(MONO, 10), fill=(80, 100, 120))


def title_block(d, x, y, title, kicker="") -> None:
    if kicker:
        d.text((x, y), kicker, font=F(PIXEL, 10), fill=AMBER)
        y += 22
    d.text((x, y), title, font=F(PIXEL, 26), fill=CYAN)
    d.line([x, y + 40, x + 90, y + 40], fill=CYAN, width=2)


def bullets(d, x, y, items, width=520, size=15, gap=46) -> None:
    for item in items:
        d.rectangle([x, y + 8, x + 6, y + 8], fill=CYAN)
        lines = wrap(d, item, F(MONO, size), width)
        for i, line in enumerate(lines):
            d.text((x + 20, y + i * 21), line, font=F(MONO, size), fill=TEXT)
        y += gap + (len(lines) - 1) * 21


def screenshot_card(im, d, path, x, y, w, h, border=CYAN, caption="") -> None:
    d.rectangle([x - 3, y - 3, x + w + 3, y + h + 3], fill=(2, 4, 8))
    im.paste(shot(path, (x, y, w, h)), (x, y))
    d.rectangle([x - 1, y - 1, x + w, y + h], outline=border, width=1)
    if caption:
        d.text((x, y + h + 10), caption, font=F(MONO, 10), fill=MUTED)


def slide1() -> Image.Image:
    im, d = page()
    d.text((60, 54), "NASA SPACE APPS 2026  ·  SPACE MISSION DESIGN GAME", font=F(PIXEL, 11), fill=CYAN)
    d.text((60, 142), "ORBIT", font=F(PIXEL, 66), fill=TEXT)
    d.text((60, 212), "+ OUTPLAY", font=F(PIXEL, 66), fill=AMBER)
    d.text((62, 292), "EXOPLANET SURVEY", font=F(PIXEL, 20), fill=CYAN)
    for i, line in enumerate([
        "A turn-based mission-architecture roguelite.",
        "Design a spacecraft. Draft a real exoplanet.",
        "Survive its surface. Keep your agency alive.",
    ]):
        d.text((62, 342 + i * 25), line, font=F(MONO, 16), fill=TEXT)
    d.text((62, 468), "Playable in the browser  ·  Godot 4 / WebGL 2", font=F(MONO, 13), fill=MUTED)
    shot_path = Path("/tmp/title_web.png")
    if shot_path.exists():
        screenshot_card(im, d, shot_path, 688, 96, 532, 299, caption="Title / agency console")
    d.text((688, 438), "72 real exoplanets", font=F(PIXEL, 16), fill=CYAN)
    d.text((688, 464), "13 terrain biomes", font=F(PIXEL, 16), fill=AMBER)
    d.text((688, 490), "3-sector campaign", font=F(PIXEL, 16), fill=GREEN)
    d.text((688, 530), "NASA Exoplanet Archive · pscomppars", font=F(MONO, 12), fill=MUTED)
    footer(d, 1, "CONCEPT")
    return im


def slide2() -> Image.Image:
    im, d = page()
    title_block(d, 60, 54, "MISSION DESIGN IS A WEB OF TRADE-OFFS", "THE PROBLEM")
    bullets(d, 60, 150, [
        "Every choice moves at least three numbers: mass, power, heat, delta-v, data, cost, or risk.",
        "A static form teaches the vocabulary but not the tension between those numbers.",
        "The challenge asks for an interactive game: design, simulate, score, explain.",
        "We made the coupling playable, with real planetary physics as the source of pressure.",
    ], width=600, size=15, gap=55)
    p = SHOTS / "final_sector_success.png"
    if p.exists():
        screenshot_card(im, d, p, 700, 138, 520, 292, caption="A run ends with a ledger, not a quiz")
    d.text((700, 468), "DECISION SPACE", font=F(PIXEL, 10), fill=AMBER)
    for i, (k, v) in enumerate([
        ("MASS", "launch fairing capacity"),
        ("POWER", "hazard shielding & instruments"),
        ("THERMAL", "heat per move vs. radiator mass"),
        ("DELTA-V", "route length vs. quota"),
    ]):
        y = 494 + i * 34
        d.text((700, y), k, font=F(PIXEL, 10), fill=CYAN)
        d.text((810, y + 1), v, font=F(MONO, 13), fill=TEXT)
    footer(d, 2, "PROBLEM")
    return im


def slide3() -> Image.Image:
    im, d = page()
    title_block(d, 60, 48, "ONE RUN, FIVE DECISIONS", "THE LOOP")
    steps = [
        ("01", "DESIGN", "Hull, launcher, objective, two instruments."),
        ("02", "DRAFT", "Pick one of three real exoplanets."),
        ("03", "SURVIVE", "One move per turn. Path, cost, hazard."),
        ("04", "REFIT", "Grants buy stacking modules and firmware."),
        ("05", "REPORT", "Three sectors. One grade. One ledger."),
    ]
    for i, (n, head, body) in enumerate(steps):
        y = 150 + i * 96
        d.text((60, y), n, font=F(PIXEL, 20), fill=AMBER)
        d.text((112, y), head, font=F(PIXEL, 17), fill=CYAN)
        d.text((112, y + 28), body, font=F(MONO, 13), fill=TEXT)
        if i < 4:
            d.line([78, y + 52, 78, y + 88], fill=LINE, width=1)
    p = Path("/tmp/shot_sector.png")
    if p.exists():
        screenshot_card(im, d, p, 576, 150, 644, 362,
                        caption="Surface sector: path preview, range and end-of-turn hazards")
    footer(d, 3, "LOOP")
    return im


def slide4() -> Image.Image:
    im, d = page()
    title_block(d, 60, 48, "MEASUREMENTS BECOME MECHANICS", "NASA DATA")
    d.text((60, 140), "NASA Exoplanet Archive · Planetary Systems Composite Parameters", font=F(MONO, 13), fill=MUTED)
    rows = [
        ("pl_eqt / pl_insol", "equilibrium temperature", "heat load / thermal start"),
        ("pl_bmasse / pl_rade", "mass and radius", "gravity / delta-v cost"),
        ("st_age / st_teff / insol", "stellar activity", "radiation environment"),
        ("sy_dist", "distance from Earth", "comms loss on downlink"),
        ("pl_orbsmax / pl_orbper", "orbit", "dossier / variety"),
    ]
    for i, (a, b, c) in enumerate(rows):
        y = 178 + i * 48
        d.text((60, y), a, font=F(MONO, 13), fill=CYAN)
        d.text((330, y), b, font=F(MONO, 13), fill=MUTED)
        d.text((560, y), c, font=F(MONO, 13), fill=TEXT)
        d.line([60, y + 30, 700, y + 30], fill=LINE, width=1)
    d.text((60, 440), "DERIVED, DOCUMENTED, REPRODUCIBLE", font=F(PIXEL, 10), fill=AMBER)
    for i, line in enumerate([
        "heat = clamp((Teq - 140) / 8, 4, 100)",
        "delta_v = clamp(36 - 2.5*g - 0.05*heat - 0.08*rad, 18, 36)",
        "comms_loss = distance band (0 / 5 / 10 / 18 / 25 %)",
    ]):
        d.text((60, 468 + i * 24), line, font=F(MONO, 12), fill=TEXT)
    p = Path("/tmp/shot_draft.png")
    if p.exists():
        screenshot_card(im, d, p, 760, 160, 460, 259)
    d.text((760, 438), "72 CURATED PLANETS", font=F(PIXEL, 14), fill=CYAN)
    d.text((760, 464), "0.35–2.2 Earth radii", font=F(MONO, 12), fill=TEXT)
    d.text((760, 490), "missing mass: Chen & Kipping (2017), flagged EST", font=F(MONO, 11), fill=MUTED)
    footer(d, 4, "DATA")
    return im


def slide5() -> Image.Image:
    im, d = page()
    title_block(d, 60, 44, "TELEGRAPHED HAZARDS, NOT HIDDEN RNG", "SURVIVE")
    p = Path("/tmp/shot_sector.png")
    if p.exists():
        screenshot_card(im, d, p, 60, 132, 720, 405, caption="Live sector: full path preview with a telegraphed hazard")
    x = 818
    d.text((x, 144), "EVERY MOVE SPENDS", font=F(PIXEL, 10), fill=AMBER)
    for i, line in enumerate([
        "one move per turn · range 3–4",
        "1 delta-v + 1 sol per path tile",
        "+ planet heat (clamped 1–18)",
    ]):
        d.text((x, 174 + i * 26), line, font=F(MONO, 13), fill=TEXT)
    d.text((x, 278), "RESPONSES", font=F(PIXEL, 10), fill=AMBER)
    for i, line in enumerate([
        "Pick a destination; preview the path",
        "Route around the telegraph",
        "Shield with power (blockable)",
        "HOLD: vent heat, +power, -1 sol",
        "Extract before resources run out",
    ]):
        d.text((x, 308 + i * 27), "> " + line, font=F(MONO, 12), fill=TEXT)
    d.text((x, 452), "QUOTA 3 OF 4 NODES", font=F(PIXEL, 12), fill=CYAN)
    d.text((x, 476), "Full sweep: +35 grant, better science", font=F(MONO, 11), fill=MUTED)
    footer(d, 5, "GAMEPLAY")
    return im


def slide6() -> Image.Image:
    im, d = page()
    title_block(d, 60, 44, "HONEST, REPRODUCIBLE, PLAYABLE", "VALIDITY & IMPACT")
    bullets(d, 60, 146, [
        "The archive value stays visible; the game value is labelled as a derived abstraction.",
        "Raw 5,801-row pscomppars snapshot, the build script, and the formula table ship with the game.",
        "Browser-first: one static build, mouse or touch, no install, no account.",
        "Classroom fit: a 10-minute run makes thermal, power, mass and downlink trade-offs concrete.",
    ], width=590, size=14, gap=48)
    p = SHOTS / "final_report.png"
    if p.exists():
        screenshot_card(im, d, p, 690, 140, 530, 298, caption="Agency ledger: science, efficiency, approval, funds, completion")
    d.text((690, 462), "GRADE C–S", font=F(PIXEL, 14), fill=AMBER)
    d.text((690, 488), "Feedback after every sector", font=F(MONO, 12), fill=TEXT)
    d.text((690, 510), "Failure is explainable: the hazard was visible.", font=F(MONO, 11), fill=MUTED)
    footer(d, 6, "IMPACT")
    return im


def slide7() -> Image.Image:
    im, d = page()
    title_block(d, 60, 54, "THE NEXT MISSION", "WHAT'S NEXT")
    bullets(d, 60, 152, [
        "Team mode: up to four players split design, flight, science, and comms.",
        "A codex linking every in-game value to its archive row and formula.",
        "More campaigns, hulls, and hazard families; classroom worksheets.",
        "Accessibility pass: color-blind palettes, remapping, and reduced motion.",
    ], width=650, size=15, gap=48)
    d.rectangle([60, 398, 700, 566], fill=PANEL, outline=LINE, width=1)
    d.text((86, 418), "TRY THE PROTOTYPE", font=F(PIXEL, 12), fill=CYAN)
    d.text((86, 448), "Local build:", font=F(MONO, 12), fill=MUTED)
    d.text((86, 470), "cd build/web && python3 -m http.server 8060", font=F(MONO, 13), fill=TEXT)
    d.text((86, 500), "Then open http://localhost:8060", font=F(MONO, 12), fill=MUTED)
    d.text((86, 528), "Demo video: submission/orbit_outplay_demo.mp4  ·  25.6 s", font=F(MONO, 12), fill=AMBER)
    d.text((760, 160), "BUILT WITH", font=F(PIXEL, 10), fill=AMBER)
    for i, line in enumerate([
        "Godot 4.7.2 · GDScript",
        "NASA Exoplanet Archive pscomppars",
        "Chen & Kipping (2017) mass–radius",
        "Silkscreen + IBM Plex Mono (OFL)",
        "Original diffusion-generated pixel art",
    ]):
        d.text((760, 190 + i * 30), line, font=F(MONO, 12), fill=TEXT)
    d.text((760, 370), "REFERENCES", font=F(PIXEL, 10), fill=AMBER)
    for i, line in enumerate([
        "exoplanetarchive.ipac.caltech.edu",
        "doi.org/10.3847/1538-4357/834/1/17",
        "spaceappschallenge.org",
    ]):
        d.text((760, 400 + i * 26), line, font=F(MONO, 12), fill=MUTED)
    footer(d, 7, "NEXT")
    return im


def main() -> None:
    pages = [slide1(), slide2(), slide3(), slide4(), slide5(), slide6(), slide7()]
    pages[0].save(
        OUT / "orbit_outplay_deck.pdf",
        save_all=True,
        append_images=pages[1:],
        resolution=144.0,
    )
    # Also keep a contact sheet for quick review.
    sheet = Image.new("RGB", (W * 2, H * 4), (0, 0, 0))
    for i, p in enumerate(pages):
        sheet.paste(p, ((i % 2) * W, (i // 2) * H))
    sheet.save(OUT / "deck_contact_sheet.png")
    print(f"wrote {OUT / 'orbit_outplay_deck.pdf'} (7 slides)")


if __name__ == "__main__":
    main()

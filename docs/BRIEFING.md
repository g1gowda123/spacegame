# Chief Engineer Briefing — Story / Tutorial

Status: **NOVA owns the scene and beat sheet; VEGA owns the character sprite
sheet.** Approved by the boss 15:44. This is a post-gate feature: it needs a
re-export and a browser pass before it ships.

## Why this exists

The game starts on a mission-design form. A new player has no reason to care
about budget, approval, or the next planet. The briefing gives the run a
career frame:

> You are the newly appointed **Chief Engineer** of a small space agency.
> Successful missions earn grants and approval; grants buy the hardware that
> makes harder, more dangerous worlds survivable. The agency is betting on you.

That is the roguelike justification without adding a second progression system.
The story explains the existing random planets, difficulty tiers, refit shop
and field commissions; it does not promise mechanics the game does not have.

## The character

**Dr. Imani Vale**, Deputy Director / Flight Director. Female, 35–45, practical
flight jacket or agency uniform, badge, short or tied-back hair. Competent,
dry, warm; she has kept the agency alive and is betting on the new chief. She
calls the player **“Chief”** two or three times, not every line.

She is **not** an anime waifu and the reference image is **placement only**:
character left, dialogue box bottom. Do not copy the RPG Maker frame, fonts or
bust style.

## Beats (6 + send-off)

| # | Card | Speaker | Text intent |
|---|---|---|---|
| 01 | INDUCTION | Vale | “Chief. Good — you're early. I'm Dr. Imani Vale, deputy director. The board just signed your appointment, and the press office is already asking for a quote.” |
| 02 | THE AGENCY | Vale | Three launch windows, one shrinking budget, a public that stopped watching. Success brings grants and approval; failure brings a review — and reviewers are cheaper than rockets. |
| 03 | MISSION DESIGN | Vale | Hull, launch vehicle, orbit, two instruments. Mass, power and delta-v are not decoration; a fantasy flight plan fails on the pad, not on the planet. |
| 04 | TARGET DRAFT | Vale | Safe worlds are forgiving. Harsh worlds pay more science and more grants, but they find every weakness in the hardware you can afford. |
| 05 | SURFACE | Vale | Data is funding. Move carefully, watch heat and power, extract before the window closes. HOLD is not cowardice; it is thermal management. |
| 06 | REFIT | Vale | Spend grants on refits, then claim your field commission. Build for the next planet, not the last one. |
| 07 | SEND-OFF | Vale | “That's the job, Chief. Make the agency matter. I'll be on comms.” |

Keep each beat to **1–2 sentences** on screen. The table above is the intent;
the final copy can be tightened for 640×360.

## Layout (640×360)

- Full-screen star-chart / agency window background, dimmed.
- Character **left**, 160×240 transparent bust at ~x=8, y=26; the lower body is
  covered by the dialogue box.
- Dialogue box **bottom**, cream paper card: x≈166, y≈248, w≈466, h≈94.
  Nameplate `DR. IMANI VALE // DEPUTY DIRECTOR` in agency orange; body copy in
  ink, 8 px, max three lines.
- Top kicker: `AGENCY INDUCTION // CHIEF ENGINEER`; progress `01 / 07`.
- `SKIP BRIEFING [ESC]` as a small paper tab, always visible.
- `SPACE / CLICK` advance hint; typewriter reveal at ~45 chars/s; first click
  completes the line, second advances.
- Final button: **BEGIN FIRST MISSION** on the first run; **RETURN TO MISSION
  CONTROL** on replay.
- Use the flight-binder language from `docs/UI_REDESIGN.md` for the paper card,
  hard 1 px ink edge and orange tab. Do not build a one-off JRPG skin.

## Flow

- `User://orbit_save.cfg` key `briefing.seen` (default false).
- First boot: `title.gd` routes to `scenes/briefing.tscn` before the menu.
- First run final: mark seen, `CrewDirector.begin_run("campaign", 1, "standard")`,
  go to `scenes/design.tscn`.
- Replay: **STORY** button on the title; final returns to title.
- Skip: mark seen and return to title; never force the briefing on a returning
  player.
- Dev: `--screen=briefing`, `--briefing-beat=N` for screenshots. `--screen=`
  must suppress the first-run auto-route so QA screenshots are deterministic.
- The briefing must be silent-safe: no voice, only existing UI SFX.

## VEGA — character sprite brief (assigned by the boss)

**Fixed**

- Female deputy director, 35–45, professional agency officer; calls the player
  “Chief”; no sexualisation, no pin-up pose, no exaggerated proportions.
- 3/4 bust, **160×240**, transparent RGBA, pixel art at 1× (no anti-aliasing,
  no baked background, no baked shadow). A 1 px dark outline is welcome.
- Deliver three expressions: `neutral`, `smile`, `stern`. The face must stay
  identical between them; only brows, eyes and mouth change.
- Files:
  - `assets/sprites/crew/director_neutral.png`
  - `assets/sprites/crew/director_smile.png`
  - `assets/sprites/crew/director_stern.png`
  - `assets/sprites/crew/director_icon.png` (64×64 dialogue icon)
  - `assets/sprites/crew/manifest.json` (paths, expression names, palette,
    workflow/seed notes)
  - `assets/raw/crew/` for the raw generation sources
- Palette: ink `#1b1a17`, navy `#101826`, agency orange `#e4572e`, paper
  `#e8dfc8`, teal `#5f8f8a`, skin/shadow values of your choice; keep the set
  coherent and palette-locked.
- Keep the silhouette readable at 1× on both the dark star chart and the cream
  dialogue card.
- QA contact sheet on dark and paper backgrounds; no cropped hair/hand; check
  at 160×240 and at 2× nearest.

**Creative freedom**

- Choose her exact face, hair, age within 35–45, uniform details, badge,
  headset, silhouette and expression nuance. A flight jacket, rolled sleeves,
  a holographic crew tag or a mission patch are all fair.
- You may improve the character beyond the placeholder and choose a different
  accent within the palette if it reads better.
- You may add a second pose (e.g. pointing at a display) if it is useful, but
  the three dialogue expressions are the required set.
- **New ComfyUI workflows can be created at any time.** Do not treat the
  current pipeline as fixed. If you build a better character workflow, use it,
  then regenerate **all three expressions from the same reference/seed** so the
  face does not drift. Record the workflow, model, seed and prompt in
  `assets/raw/crew/README.md` and update the manifest.
- Do not use diffusion for the dialogue frame/buttons; those are crisp 9-slice
  UI assets from the UI identity task. Diffusion is for the character art (and
  optionally a very subtle paper fibre).

## Acceptance

- First boot reaches the briefing; skip and replay both work; `briefing.seen`
  persists without wiping the best score.
- Seven beats, readable at 640×360; no text clipped; typewriter and advance
  work with mouse, Space and Enter; Esc skips.
- Character left / dialogue bottom placement reads like the reference without
  copying its frame.
- Headless `0 SCRIPT ERROR|Parse Error|Failed to load|Invalid`; Web browser
  pass with 0 console/page errors.
- VEGA's three expressions are consistent and replace the placeholder without
  code changes (same file paths).

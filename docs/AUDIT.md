# AUDIT — full project check (ORION, 2026-11-15)

Scope: every screen, the data pack, the flow, the web build and the submission
artifacts, checked against the current `main`. Evidence lives in
`/tmp/opencode/sweep/` (native screen captures), `/tmp/opencode/qa_s/`
(web QA at 1280×720 and 640×360) and `/tmp/opencode/demo_ops9/` (demo raw).

## 1. Screen sweep (native, `--screen=<name> --capture`)

| screen | renders | script errors | notes |
|---|---|---|---|
| title (mission terminal) | PASS | 0 | nav column, sector queue, transfer plot, archive counters, comms block all populated |
| briefing | PASS | 0 | bust + personnel card, `01 / 07`, callsign field, skip tab |
| design | PASS | 0 | hull bus / spacecraft / objective / instruments all legible; budget reads `$500M` |
| draft | PASS | 0 | three cards, threat chips, stat bars, `SET COURSE >`, `< REFIT` |
| launch | PASS | 0 | countdown, ignition, liftoff; shroud/booster junction still has the 30 px gap (assigned VEGA) |
| sector | PASS | 0 | HUD rows correct (`DATA 0/3 · NEED 3`), hazard telegraph, action tabs clear of D-pad |
| relay (sector 2) | PASS | 0 | relay counters present |
| debrief | PASS | 0 | `MISSION SUCCESS`, data/science/grant rows, refit store, `HANDLE EVENT >` |
| report | PASS | 0 | grade, sector ledger, ship path, rubric traces, campaign code |
| crew | PASS | 0 | crew size 1–4, difficulty tiers, start budget |
| buff (field commission) | PASS | 0 | three commission cards with hull art and effects |

Only non-zero line in any log is the benign
`ERROR: 2 resources still in use at exit` emitted by the capture probe at shutdown;
it does not appear in normal play.

## 2. Data pack (`data/exoplanets.json`)

- 72 planets, **no duplicate names**, all required fields present.
- 9 archive biomes: ammonia, arid, barren, cryo, crystal, iron, sulfur, temperate, volcanic.
- Mass–radius outliers all carry `mass_est: true` (Chen & Kipping estimate) — 0 unflagged.
- Surface gravity: max **3.13 g**, median 1.19 g (playable range, no 17 g outliers left).

## 3. Gameplay flow (headless `--screen=flowtest`)

```
launched=true buff_pending=true buff_ok=true buffs=["harden"]
bought=true range=4->3 dv=37->25
owned=["coolant"] modules=3 tier=FIELD-READY
report total=5182 grade=A successes=3
stats power_regen=1->3 integrity=6->8 thermal=4->7 dv=30->35 comms=0->4
```
Refit, commission, stat application, scoring and report assembly all consistent.

## 4. Web build

- Gate build from `HEAD` → `index.pck` md5 `0fbf82c54f99`.
- `tools/qa/qa_flow.py`: **PASS** at 1280×720 and 640×360, **0 console / 0 page errors**.
- Full loop verified: briefing → callsign → title → design → draft → review →
  **launch (loading screen)** → sector → committed turn.
- Harness note: the title button moved with the terminal rebuild, so the QA/demo
  scripts now drive with keyboard (`Enter` starts, `Enter` commits the review,
  `ESC` skips the launch) instead of hard-coded pixel taps.

## 5. Submission artifacts (refreshed to this build)

| file | value |
|---|---|
| `submission/orbit_outplay_demo.mp4` | 23.5 s, 706 frames, 2.30 MB, H.264, no audio track |
| `submission/orbit_outplay_deck.pdf` | 7 slides, 545 KB |
| `submission/orbit_outplay_web.zip` | 9 entries, 37.6 MB (index.pck 30 MB from gate `0fbf82c54f99`) |
| `submission/README.txt`, `PROJECT_PAGE_COPY.md` | retimed to 23.5 s |

## 6. Open defects (ranked)

1. **P1 — launch vehicle stack (VEGA):** shroud at `y=-98..-30`, payload at `y=-56`,
   booster from `y=0` → 30 px unrendered gap plus the hull poking through the nose.
2. **P1 — fog veil too heavy (ATLAS):** on sector boards the lit area is roughly
   10×10 cells and the rim goes almost black; the map stops being the hero.
3. **P2 — structure repetition:** crater families are capped per board, but rock
   spires still arrive in regular rows on several biomes.
4. **P3 — onboarding line length:** `TURN 1 — RANGE 4 · SHAKEDOWN +2 HULL · CYAN = EXIT · CLICK A TILE`
   is one long run-on row; splitting the shakedown note onto its own line would read cleaner.

## 7. Docs hygiene

- `docs/SUBMISSION.md` referenced an old gate hash for the demo build; corrected to
  describe the current gate instead of a specific pck.

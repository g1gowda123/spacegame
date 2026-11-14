# Orbit & Outplay — Game Design Notes

Designer: NOVA. This document records the *intent* behind the mission-control
layer and maps every feature to the NASA Space Apps 2026 *Space Mission Design
Game* brief. It is written for judges, future contributors, and the other
agents on the project.

## Design review (12:35)

The core loop already does the hard part of the brief: a real spacecraft
design, a real exoplanet draft, a telegraphed surface operation, a refit
economy, and a final grade. The loop is short (3 sectors, 10–15 minutes) and
every loss is explainable.

The first playable build was, however, a *solo engineering puzzle*. The brief
repeatedly asks for something broader:

- team play for up to four participants with different responsibilities;
- difficulty levels and multiple scenario types;
- random events and post-mission analysis;
- save, share and compare designs;
- feedback that explains *why* a decision mattered.

This pass closes those gaps without changing the approved pixel-art look or
the deterministic hazard model.

## Three design pillars

1. **One mission, four definitions of success.** Co-op is not a second HUD; it
   is a set of goals that genuinely conflict. The science lead wants one more
   node. Flight dynamics wants fuel left. The field commander wants the hull
   home. The director wants approval. The team has to negotiate every route.
2. **Every rule is visible before it bites.** Difficulty cards list every
   modifier. Role cards list the buff and the goal. Draft cards tag the threat
   from their own archive numbers. The final report names every bonus source.
3. **The next run is one click away.** A campaign code reproduces the same
   worlds; a daily seed gives everyone the same three-planet puzzle; the best
   score and the daily best sit on the title screen.

## What this pass adds

### Mission Control (new screen)

Reached from the title. It sets the run shape before mission design:

- **Campaign or Daily.** Campaign draws a new seed. Daily uses a date-derived
  seed, so every player gets the same three worlds for that day.
- **Crew size 1–4 (local hot-seat).** One console, one mission. The game shows
  a handoff banner before each decision phase naming the player and role whose
  call it is.
- **Difficulty tier** (below). Solo is a first-class mode: no role buffs, no
  role goals.

### Crew roles and goals

| Role | Owns | Buff | Personal goal | Bonus |
|---|---|---|---|---|
| **Flight Director** | Hull, launch vehicle, orbit, budget | +$30M starting budget | Finish with approval 60+ | +180 |
| **Science Lead** | Objective, instruments, science trace | +10% science all run | Deliver 9 data nodes | +180 |
| **Flight Dynamics** | Destination draft, fuel plan | +3 delta-v every sector | Finish with 12+ delta-v left | +180 |
| **Field Commander** | Surface route, extraction, hull | +1 integrity every sector | All three sectors successful | +180 |

Role sets for smaller crews:

- **2 players:** P1 = Director + Dynamics, P2 = Science + Field Commander.
- **3 players:** P1 = Director, P2 = Science + Dynamics, P3 = Field Commander.
- **4 players:** one role each.

The goals are deliberately antagonistic. A greedy science route spends
delta-v, heats the hull, and risks the field commander's clean-sheet goal. A
conservative extraction protects the hull but starves the science lead. The
report shows which goals were met (`CREW GOALS 3/4`), so the team can argue
about the right call *after* the run.

### Difficulty tiers

| Tier | Budget | Approval | Hazard fronts | Heat per tile | Score |
|---|---|---|---|---|---|
| **Cadet** | +$100M | +10 | −1 | −1 | ×0.90 |
| **Standard** | — | — | — | — | ×1.00 |
| **Director** | −$75M | −10 | +1 | +1 | ×1.25 |

Difficulty changes the *engineering problem*, not just a damage multiplier:
Cadet buys margin for a first run; Director removes margin and adds a fourth
hazard front on later turns. The score multiplier is applied to the engineering
subtotal and shown as an explicit report row.

### Daily Challenge and campaign codes

- The title shows today's date and the player's daily best.
- The daily seed is `hash("orbit-daily-" + YYYY-MM-DD)`; the draft is drawn
  from that seed, so the same three worlds appear on every machine that day.
- The report prints a campaign code, e.g. `OO-0F7A5-S1`:
  `seed | difficulty (C/S/D) | crew size`.
- The code can be pasted into Mission Control. It reproduces the seed,
  difficulty and crew size — the same worlds, with each player's own design.
  Press `C` on the report to copy it.

### Draft threat tags

Each destination card now shows `SAFE ROUTE`, `BALANCED` or `HARSH WORLD` plus a
threat number derived only from fields already on the card:

```
threat = heat×0.50 + radiation×0.35 + comms_loss×1.50
```

This makes the first real decision readable in one second without hiding the
underlying archive values.

## Why this is more fun

- **Tension instead of arithmetic.** The role goals give four players four
  reasons to want a different route. The argument is the gameplay.
- **Push-your-luck extraction.** The existing risk bonus and the science
  lead's 9-node goal reward staying out one more turn; the field commander's
  goal rewards banking early. Same rule set, new pressure.
- **Replayable in three ways.** New seed each campaign, a shared daily puzzle,
  and three difficulty tiers with genuinely different budgets and hazard
  pressure.
- **Readable failure.** Every report row sums to the total; difficulty and
  crew bonuses are separate lines, so a player can point at the exact decision
  that cost the grade.

## Challenge-brief traceability

| Brief line | Where it is now |
|---|---|
| Design a spacecraft | Mission Design: 4 hulls, 3 vehicles, 4 objectives, 2 of 6 instruments |
| Budget, mass, power, data, comms, lifetime | Live telemetry bars; per-sector heat, power, sols, comms loss |
| Launch vehicle and orbit | Vector L/M/H; Low/Polar/High with period, eclipse, passes |
| Simulate / manage the mission | Three-sector campaign, telegraphed hazards, HOLD, EXTRACT |
| Single player **and team of up to four** | Mission Control: 1–4 local hot-seat, role ownership, handoff banners |
| Distinct team responsibilities | Four roles with different buffs and personal goals |
| Multiple scenarios / mission types | 72 real planets, 13 biomes, survey/relay alternation, 8 event cards |
| Random events | Between-sector event choice (two real trade-offs) |
| Difficulty levels | Cadet / Standard / Director with explicit modifiers |
| Leaderboards / comparison | Local best, daily best, shareable campaign code |
| Post-mission analysis | Grade, category rows, sector ledger, role-goal result, educational notes |
| Feedback explains why | Report rows sum to total; CML gate; science-fit; draft threat tags |

## UX rules

- One screen per decision; Mission Control is the only new stop.
- Mouse and keyboard both work; `Enter` commits, `Esc` backs out, `C` copies
  the campaign code, `H` toggles How to Play.
- Text is never the only signal: role colours, threat colours, bar fills and
  the grade letter all carry the same information.
- No new runtime dependencies and no server: the whole feature works in the
  threadless WebGL 2 export.

## QA evidence (12:44–12:48)

- `qa_daily_a.png` and `qa_daily_b.png` are byte-identical after two separate
  launches: the daily draft is deterministic.
- Meta probe output: Director + 3-player crew gives `delta_v +3`,
  `integrity +1`, `science ×1.10`, `hazard_mod 1`, `heat +1`; campaign code
  `OO-043AF-D3` parses back to the same seed, difficulty and crew size.
- Screens: `qa_title.png`, `crew5.png`, `qa_design.png`, `qa_draft.png`,
  `qa2_sector.png`, `qa2_debrief.png`, `qa_report3.png`, `qa2_report.png`.

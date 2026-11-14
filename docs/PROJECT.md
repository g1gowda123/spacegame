# Project Summary — Orbit & Outplay

## One line

**A turn-based mission-design roguelite where every destination is a real exoplanet from the NASA Exoplanet Archive, and every hazard is derived from that planet's measured physics.**

## Challenge fit

NASA Space Apps 2026 — *Space Mission Design Game*. The game asks the player to design and fly a complete mission: spacecraft, launch vehicle, instruments, science objective, target, surface operations, budget, mass, power, thermal control, communications, data return, and lifetime. It scores the campaign and explains the trade-offs.

| Challenge requirement | Where it lives |
|---|---|
| Design a spacecraft | Mission Design: hull, launch vehicle, two instruments, objective |
| Budget and mass constraints | $500M budget; launch fairing capacity vs. ship mass |
| Power, thermal, comms, data, lifetime | Live telemetry bars; per-tile heat, power shielding, downlink loss, sols |
| Launch vehicle and orbit | Vector L/M/H; LOW / POLAR / HIGH orbit profiles with period, eclipse and pass readouts |
| Mission objective and instruments | Four science objectives; six instruments with build effects and objective–instrument science fit |
| Simulate / manage the mission | Three-sector campaign with telegraphed hazards, resource spending, extraction |
| Mission concept, trajectory, timeline | Pre-commit Mission Architecture Review: transfer arc, orbit insertion, six-stage ConOps and the four NASA mission segments |
| Random events / changing rhythm | Seeded between-sector event with two trade-offs; survey sectors recover data, every second sector plants 3 relay beacons |
| Multiple scenarios | Three real exoplanets per run, drawn from a 72-planet pool; 13 biomes; survey and relay objectives |
| Scoring and feedback | Grants, approval, per-sector debrief, risk bonus, final grade C–S, next-grade gap and category breakdown |
| Educational explanations | Draft detail line, CML design gate, design telemetry labels, report notes, README formula table |
| NASA data integral | All planet targets and their constraints come from `pscomppars`; mission-design resources are mapped in README/SUBMISSION |
| Team play (optional) | Local hot-seat crew mode for 1–4 players: role ownership (architecture, science, navigation, surface ops), handoff banners, conflicting personal goals scored in the report |

## Run structure

1. **Title** → best score, how to play.
2. **Mission Design** → hull + launch vehicle + objective + instruments; validation against budget and fairing mass.
3. **Target Draft** → three real planets; each card exposes Teq, gravity, distance, biome, and five derived hazard bars.
4. **Mission Architecture Review** → transfer arc, four mission segments, CML, ConOps timeline; commit the architecture.
5. **Sector** → chunked alien surface; one move per turn within a 3–4 tile range; path preview shows distance, Δv/sol cost and heat; hazards telegraph and resolve at end of turn; HOLD to vent; EXTRACT to bank.
6. **Debrief** → success/failure, data delivered, science, grant, approval delta, integrity, Δv, comms loss; three-offer refit shop; one seeded event choice before the next draft.
7. Repeat for three sectors; approval at zero ends the run early.
8. **Final Report** → grade, total, category breakdown, sector ledger, narrative, educational notes, new campaign.

## Core design decisions

- **Deterministic, telegraphed hazards, not combat.** The challenge is resource routing, not enemy AI. This keeps the game about mission engineering and makes every loss explainable.
- **Real data, abstracted into legible rules.** The archive does not publish "heat per move"; the builder derives a stable, documented game value from Teq, gravity, insolation, stellar age/type, and distance. The raw measurement is shown on the card so the abstraction is honest.
- **Roguelite structure for replay.** Three-sector runs, a 3-of-72 target draft, and stacking refit modules create build variety without a long campaign.
- **One screen per decision.** Design, draft, sector, debrief, report; no hidden menus. This fits a 30-second demo and a browser play session.
- **Pixel-art identity.** 640×360 logical resolution, palette-locked diffusion-generated terrain, ComfyUI-generated planet and ship sprites, a consistent cyan/amber console UI.
- **Web-first.** Threadless WebGL 2 export, static hosting, mouse and touch controls, no install.

## Data and validity

- Source: NASA Exoplanet Archive, **Planetary Systems Composite Parameters (`pscomppars`)**.
- Raw query snapshot: `data/pscomppars_raw.csv` (5,801 rows).
- Curated game set: `data/exoplanets.json` (72 planets, 0.35–2.2 R⊕).
- Builder: `tools/build_exoplanets.py` (deterministic; can be re-run).
- Missing or physically implausible masses use Chen & Kipping (2017) and are flagged `mass_est`.
- Full field list, derived formulas, SI units, and citations: `README.md` and `docs/SUBMISSION.md`.

## Tech

- Godot 4.7.2, GDScript, GL Compatibility, WebGL 2.
- 640×360 logical viewport, `canvas_items` stretch, `keep` aspect.
- No external runtime dependencies; dataset and audio are bundled.
- Build: `build/web/index.html` (static, threadless).

## Out of scope for the prototype

- Networked multiplayer (local hot-seat crew mode for 1–4 players is implemented).
- Persistent meta-progression beyond the local best score.
- Full 3D flight dynamics or real orbital mechanics.
- Voice-over, localization, and accessibility pass.
- Additional campaigns beyond the three-sector Exoplanet Survey.

## Status

Playable end to end in native Godot and in the Web build. Submission package assembled (static ZIP, 29.6 s video, 7-slide deck, project-page copy); remaining action is hosting and filling the official project page links.

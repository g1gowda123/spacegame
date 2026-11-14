# Submission Copy — Orbit & Outplay: Exoplanet Survey

Use this file to fill the NASA Space Apps project page. Trim to the field limits on the day.

## Project name

**Orbit & Outplay: Exoplanet Survey**

## Short summary (≤ 200 characters)

Build a spacecraft, draft a real NASA exoplanet, and survive its surface. A turn-based mission-design roguelite where every hazard comes from actual planetary data.

## Elevator pitch

You run a tiny space agency with a $500M budget and a fragile approval rating. Design a survey craft, pick one of three real exoplanets, and fly a telegraphed hazard course across its surface. Bring back data, refit, and survive three missions before the agency is defunded.

## Detailed description

**The problem.** Mission design is a chain of coupled trade-offs — mass against capability, thermal control against schedule, power against shielding, data volume against downlink distance. A static form teaches the vocabulary but not the tension. We made the tension playable.

**The game.** *Orbit & Outplay* is a turn-based tactical systems-engineering roguelite. Each run has three phases:

1. **Mission design.** Choose a hull, a launch vehicle, a science objective, and two instruments under a hard $500M budget and the launcher's fairing mass. Six live bars — mass, power, delta-v, hull integrity, thermal margin, data capacity — show the consequences immediately. The validation line blocks an over-budget or over-mass stack.
2. **Target draft.** Three real exoplanets are drawn from the NASA Exoplanet Archive. Each dossier shows the measured equilibrium temperature, surface gravity, distance, host star, and biome, plus the derived mission bars (thermal load, radiation, gravity, comms loss, science) the mission will face. The player chooses which physics to accept.
3. **Surface sector.** A procedurally generated alien surface is rendered as a chunked pixel-art map. Each turn allows **one move** within a 3–4 tile range; selecting a destination previews the full path, the delta-v/sol cost, the heat load, and whether the route crosses a hazard. Hazards are telegraphed one turn ahead and resolve at the **end** of the turn, not on contact: stellar flares, thermal surges, dust storms, seismic shocks, radiation belts, eclipse shadows, cryo quakes, solar-wind fronts, and meteor showers. Blockable hazards can be absorbed with power; HOLD vents heat and recharges; EXTRACT banks the data. Collect the objective quota (three or four nodes) and get out — or push for the fourth node and the full-sweep grant.

After target selection, a **Mission Architecture Review** commits the mission: a transfer arc, the four NASA mission segments, CML, and a launch-to-end ConOps timeline. Survey sectors recover data; every second sector switches to **RELAY SURVEY**, planting three beacons on marked tiles. Between sectors, a **debrief** converts the result into science points, a grant, and an approval change, then offers three refit modules and one seeded agency event with two trade-offs. Modules stack additively and multiplicatively: radiators cut heat per move, reaction wheels add delta-v, RTGs regenerate power, ablative armor adds integrity, a high-gain antenna recovers downlink loss, science packs multiply the score, and an Ion Thruster extends the per-turn path range. Three successful sectors produce a final **agency ledger** with a grade from C to S.

**Why it is a game, not a spreadsheet.** Every number is a decision the player can feel within one turn. A hot planet makes every move expensive; a massive planet eats delta-v; a distant planet loses data on downlink; a dim star changes which hazards appear. The player can always explain a loss: the telemetry was visible, the hazard was telegraphed, and the route was a choice.

**NASA data as a mechanic.** The 72-planet pool is curated from the NASA Exoplanet Archive's Planetary Systems Composite Parameters (`pscomppars`) table. Equilibrium temperature drives the thermal load and starting heat; mass and radius drive surface gravity and delta-v cost; stellar age, spectral type, and insolation drive the radiation environment; distance drives communications loss. Missing or physically implausible archive masses use the Chen & Kipping (2017) mass–radius relation and are flagged as estimates. The raw archive snapshot, the build script, and the formula table are included in the repository so every derived value is reproducible.

**Presentation.** The game runs in the browser at a 640×360 pixel-art internal resolution with a consistent console UI, ComfyUI-generated planet portraits, ship sprites, and a starfield backdrop. It is a single static WebGL 2 build with mouse and touch controls; no install, no account, no server.

**What is next.** Networked four-player missions (local hot-seat crew mode for 1–4 players is in this build), more campaigns and hulls, a codex that links every in-game number to its archive row, and a classroom mode with printable design worksheets.

## Challenge requirements trace

| Requirement from the brief | Where it is met |
|---|---|
| Define a mission objective and requirements | Objective cards plus the science-fit rule; the objective sets the quota and instrument compatibility. |
| Design a spacecraft | Four hulls, two instruments, mass/power/thermal/data bars, live ship diagram. |
| Select launch vehicle and orbit | Three launchers with fairing capacity; LOW/POLAR/HIGH orbit profiles with period, eclipse and passes/day. |
| Manage budget, mass, power, communications, data, lifetime | Budget and mass validation; HUD power/thermal/delta-v; downlink loss; data quota/buffer; sols. |
| See trade-offs | Instruments add mass/power/cost; hot planets cost more heat per move; heavy planets cost delta-v; distant planets lose data. |
| Mission simulation and evaluation | Three-sector campaign, telegraphed hazards, end-of-turn damage, refit shop, final grade and post-mission report. |
| Feedback and educational explanation | Per-turn HUD, damage toasts, debrief ledger, CML, four mission segments, mission analog, report notes. |
| Multiple scenarios | 72 real exoplanets, 13 biomes, survey vs relay sectors, seeded events. |
| Mission concept / trajectory / timeline (VR resource) | Mission Architecture Review: transfer arc plus six-stage ConOps timeline. |
| Collaboration up to four players | Mission Control supports 1-4 players with crew goals and a shared campaign code; crew bonuses feed the final score. |
| Save/share/compare | Campaign code on the report, copy with `C`; no online leaderboard. |
| Difficulty levels | Mission Control difficulty tiers scale score and hazard pressure. |
| NASA data | NASA Exoplanet Archive PSCompPars; raw CSV, builder and formula table included. |

## NASA mission-design resources used

The challenge's resource tab is not decoration: each resource maps to a visible decision or readout.

| Resource | How the game uses it |
|---|---|
| **Design and Develop Science Missions** | The design screen and final ledger are organized around the four mission segments — launch, space, ground, user. Launch vehicle, bus/payload, downlink loss, and the science objective each map to one segment. |
| **General Mission Analysis Tool (GMAT)** | Orbit choice is not a flavour toggle: LOW/POLAR/HIGH change altitude, thermal load, science return, and a GMAT-style readout of period, eclipse fraction, and passes per day. |
| **Concept Maturity Levels (CMLs)** | The design validation line reports **CML 1 CONCEPT → 2 FEASIBILITY → 3 TRADE STUDY → 4 POINT DESIGN** from mass margin, power margin, and science traceability; the final report records the level reached. |
| **Mission Design Lab (MDL)** | The design screen is a compact MDL-style trade study: hull, launcher, orbit, objective, and two instruments are compared under budget and mass before the player commits. Refit between sectors is the point-design loop. |
| **NASA Mission Viz** | The final report shows the flown orbit profile (altitude, period, eclipse, passes/day) so the player can connect the surface run to the orbital geometry that enabled it. |
| **A Learning Game About Telescopes** | Instruments are constrained by the science question: a matching instrument family earns a **science fit +10%** bonus, while a mismatched payload is legal but gives up science return. |
| **CubeSat 101** | The run is a compressed ConOps: design, launch, cruise/insertion, surface operations, downlink, and end-of-mission. Mass, power, thermal, data, and budget are the same budget lines the guide describes. |
| **Visualize a Space Mission Using Virtual Reality (2023)** | The review screen uses the 2023 brief's mission concept, trajectory and timeline requirements in a 2D Mission-Viz panel: launch, cruise, orbit insertion, surface operations, downlink, end of mission. It is not a VR build, but it teaches the same spatial/temporal mission story. |
| **CSA digital games and activities** | The browser build, short run length, readable HUD, and explicit feedback are aimed at the same pick-up-and-play audience as the CSA collection. |

## How NASA data was used

- **Dataset:** NASA Exoplanet Archive — Planetary Systems Composite Parameters (`pscomppars`), a composite of confirmed-planet parameters.
- **Snapshot:** 5,801 rows queried via the archive TAP service; the raw CSV is bundled at `data/pscomppars_raw.csv`.
- **Curated pool:** 72 planets, 0.69–2.19 Earth radii (builder filter 0.35–2.2 R⊕), selected to keep derived gravity playable and the dossier readable; three archive masses were implausible for their radii and were replaced with the Chen & Kipping estimate, flagged `mass_est`.
- **Fields:** `pl_eqt`, `pl_insol`, `pl_bmasse`, `pl_rade`, `pl_orbsmax`, `pl_orbper`, `sy_dist`, `st_teff`, `st_spectype`, `st_age`, `st_met`, `sy_pnum`.
- **Derived values:** heat, radiation, quakes, comms loss, science value, delta-v, sols, and biome. The exact formulas are in `README.md` and `tools/build_exoplanets.py`.
- **Honesty:** the dossier shows the archive measurement next to the derived game value; the README states that the in-game resources are abstractions, not flight dynamics.

## SI units and conventions

| Quantity | Unit used |
|---|---|
| Equilibrium temperature | kelvin (K) |
| Planet mass | Earth masses (M⊕); gravity converted to m/s² and displayed in g (9.80665 m/s²) |
| Planet radius | Earth radii (R⊕) |
| Insolation | Earth flux (S⊕); archive values in W/m² |
| Distance | light-years (ly); archive `sy_dist` in parsecs (pc), converted at 3.26156 ly/pc |
| Time | days (orbital period); sols for surface operations |
| Energy / power | watts (W) for instrument and hull power |
| Delta-v | in-game budget units, scaled from a gravity/thermal model; not a real m/s maneuver budget |

## References

1. NASA Exoplanet Archive, *Planetary Systems Composite Parameters* (pscomppars), NASA Exoplanet Science Institute / Caltech. <https://exoplanetarchive.ipac.caltech.edu/>
2. Chen, J. G., & Kipping, D. M. (2017). Probabilistic Forecasting of the Masses and Radii of Other Worlds. *The Astrophysical Journal*, 834(1), 17. <https://doi.org/10.3847/1538-4357/834/1/17>
3. NASA Space Apps Challenge 2026, *Space Mission Design Game* challenge brief. <https://www.spaceappschallenge.org/>
4. Godot Engine 4.7.2 documentation. <https://docs.godotengine.org/>
5. NASA, *Design and Develop Science Missions* (PDF). <https://www.nasa.gov/wp-content/uploads/2025/04/250323-design-and-develop-science-mission.pdf>
6. NASA, *General Mission Analysis Tool (GMAT)*. <https://software.nasa.gov/software/GSC-19468-1>
7. NASA JPL, *Concept Maturity Levels (CMLs)*. <https://dataverse.jpl.nasa.gov/dataset.xhtml?persistentId=hdl:2014/44299>
8. NASA GSFC, *Mission Design Lab (MDL)*. <https://etd.gsfc.nasa.gov/capabilities/integrated-design-center/mission-design-lab/>
9. NASA, *Mission Viz*. <https://nasa.github.io/mission-viz/>
10. NASA Webb, *Build It Yourself: A Learning Game About Telescopes*. <https://science.nasa.gov/mission/webb/game-build-it-yourself/>
11. NASA, *CubeSat 101: Basic Concepts and Processes for First-Time CubeSat Developers* (PDF). <https://www3.nasa.gov/sites/default/files/atoms/files/nasa_csli_cubesat_101_508.pdf>
12. Canadian Space Agency, *Digital Games and Activities*. <https://www.asc-csa.gc.ca/eng/youth-educators/digital-games-and-activities.asp>
13. NASA Space Apps Challenge 2023, *Visualize a Space Mission Using Virtual Reality*. <https://www.spaceappschallenge.org/2023/challenges/visualize-a-space-mission-using-virtual-reality/>
14. Silkscreen and IBM Plex Mono fonts, SIL Open Font License.

## Demo video — 30-second shot list

Record at 1280×720 from the Web build. Keep it under 30.0 seconds; hard-cut, no long fades.

| Time | Shot | On-screen text |
|---|---|---|
| 0.0–3.0 | Title: **ORBIT & OUTPLAY**, ringed planet, BEGIN MISSION | "Every target is a real exoplanet." |
| 3.0–8.0 | Mission Design: hover PATHFINDER and VECTOR M, toggle instruments; bars move | "Design under budget and mass." |
| 8.0–13.0 | Target Draft: three planets; select a hot one; detail line highlights Teq → heat, gravity → Δv | "NASA data becomes the hazard." |
| 13.0–22.0 | Surface: move the cursor to preview a path, commit, show the end-of-turn hazard telegraph, HOLD vent, extract | "One move per turn. Path, cost, hazard." |
| 22.0–26.0 | Debrief: MISSION SUCCESS, grant, approval, buy a radiator | "Earn grants. Refit. Stack synergies." |
| 26.0–30.0 | Final Report: grade and ledger | "Three sectors. One agency. Can you keep the lights on?" |

Voice-over optional; burn in English subtitles if used. The video must be **≤30 seconds**; if the platform rejects the length, submit the 7-slide deck instead.

## 7-slide deck — outline

1. **Title** — Orbit & Outplay, one-line pitch, team.
2. **Problem** — mission design is coupled trade-offs; forms do not teach tension.
3. **Game loop** — design → draft → surface → debrief → three-sector report.
4. **NASA data** — `pscomppars` fields → heat / gravity / radiation / comms / science; formula strip.
5. **Gameplay** — sector screenshot with hazard telegraph and HUD callouts.
6. **Impact and validity** — classroom use, reproducibility, honest abstraction, accessibility of browser play.
7. **What is next / call to action** — play link, repo, credits.

Do not exceed seven slides.

## Links to fill on submission day

- **Demo link:** upload `submission/orbit_outplay_demo.mp4` to YouTube/Vimeo (unlisted is fine) or attach the 7-slide PDF.
- **Final project link:** upload `submission/orbit_outplay_web.zip` to itch.io or GitHub Pages; the ZIP is the static `build/web/` folder.
- **Local run:** `cd build/web && python3 -m http.server 8060`, then open `http://localhost:8060`.

## Final submission checklist

- [ ] Demo is ≤30.0 s (current: **29.6 s**) or deck is ≤7 slides (current: **7**).
- [ ] Project page has name, summary, demo link, final project link, detailed description, NASA data, SI use, references.
- [ ] NASA data is named explicitly: Exoplanet Archive **PSCompPars** (`pscomppars`), with the Chen & Kipping (2017) mass–radius reference.
- [ ] Build loads from a plain static host over HTTP(S); no server code, no install, no account.
- [ ] Test on a fresh browser window: BEGIN → quick loadout → confirm → draft → sector → extract → debrief → report.

# Project page copy - Orbit & Outplay: Exoplanet Survey

Owner: e (data & copy). This is the versioned copy for the NASA Space Apps
project page. It is written to be pasted into the submission form on the day;
trim fields to the form's limits. The source of facts is the shipped merged
tree (`README.md`, `docs/DESIGN.md`, `docs/SUBMISSION.md`, `docs/EVENTS.md`),
not the original pitch.

Local working copy for upload: `submission/project_page.md` (gitignored, like
the rest of `submission/`).

---

## Name

**Orbit & Outplay: Exoplanet Survey**

## Tagline

Design the mission. Draft a real world. Keep the agency alive.

## Short summary (<= 200 characters)

Build a spacecraft, draft a real NASA exoplanet, and survive its surface. A
turn-based mission-design roguelite where every hazard comes from measured
planetary data.

## Elevator pitch

You run a small space agency with a $500M budget and a fragile approval rating.
Choose a crew and a difficulty, design a survey craft, then draft one of three
real exoplanets and fly a telegraphed hazard course across its surface. Bring
the data home, refit, and keep the lights on for three missions - or watch the
review board shut you down.

## Detailed description

**The problem.** Mission design is a chain of coupled trade-offs: mass against
capability, thermal control against schedule, power against shielding, data
volume against downlink distance. A static form teaches the vocabulary but not
the tension. We made the tension playable.

**The game.** *Orbit & Outplay* is a turn-based tactical systems-engineering
roguelite. Each run has three planets and five decisions:

1. **Mission Control.** Choose a campaign or the daily challenge, a crew of
   1-4 players, and a difficulty tier. Mission Control is optional - *Begin
   Mission* starts a solo Standard run immediately.
2. **Mission design.** Pick a hull, launch vehicle, orbit, science objective,
   and exactly two instruments under a hard $500M budget and the launcher's
   fairing mass. Six live bars - mass, power, delta-v, hull integrity, thermal
   margin, data capacity - show the consequences immediately, and the launch
   button stays locked until the stack is valid.
3. **Target draft.** Three real exoplanets are drawn from the NASA Exoplanet
   Archive. Each dossier shows the measured equilibrium temperature, surface
   gravity, distance, host star, and biome, plus five derived mission bars
   (thermal, radiation, gravity, comms, science) and a SAFE / BALANCED / HARSH
   threat tag. A pre-commit **Mission Architecture Review** adds the transfer
   arc, the four NASA mission segments, the CML level, and a launch-to-end
   ConOps timeline.
4. **Surface sectors.** A procedurally generated alien surface renders as a
   chunked pixel-art map. Each turn allows one committed move within a 3-4 tile
   range; the path preview shows delta-v cost, heat load, node count, and
   whether the route crosses a hazard. Hazards telegraph one turn ahead -
   including a faint **FORMING** pre-state - and resolve at the end of the turn,
   not on contact. Blockable hazards can be absorbed with power; HOLD vents heat
   and recharges; EXTRACT banks the data. Collect the quota and leave, or stay
   out for the fourth node and the full-sweep grant. Extracting with a live
   front within two tiles earns a capped **risk bonus**.
5. **Debrief, refit, incident.** The debrief converts the result into science
   points, a grant, and an approval change, then offers three refit modules and
   one seeded agency incident with two real trade-offs. Survey sectors recover
   data; every second sector switches to **RELAY SURVEY**, planting three
   beacons on marked tiles. Three sectors produce a final agency ledger with a
   grade from C to S, a next-grade gap, the sector ledger, the crew-goal result,
   and the story of what the agency found.

**Progression and comparison.** A campaign code on the final report
(`OO-0F7A5-S1`, or the full stack code once a design is committed) reproduces
the same worlds or the exact same spacecraft; `C` copies it. The daily run uses
a date-derived seed, so everyone gets the same three planets that day, and the
title screen shows the player's daily best. There is no online leaderboard.

**Why it is a game, not a spreadsheet.** Every number is a decision the player
can feel within one turn. A hot planet makes every move expensive; a massive
planet eats delta-v; a distant planet loses data on downlink; a dim star changes
which hazards appear. The player can always explain a loss: the telemetry was
visible, the hazard was telegraphed, and the route was a choice.

**NASA data as a mechanic.** The 72-planet pool is curated from the NASA
Exoplanet Archive's Planetary Systems Composite Parameters (`pscomppars`)
table. Equilibrium temperature drives thermal load and starting heat; mass and
radius drive surface gravity and delta-v cost; stellar age, spectral type, and
insolation drive the radiation environment; distance drives communications
loss. Missing or physically implausible archive masses use the Chen & Kipping
(2017) mass-radius relation and are flagged as estimates. The raw archive
snapshot, the build script, and the formula table are in the repository so every
derived value is reproducible.

**Honest abstraction.** The archive does not publish "heat per move". The game
derives a stable, documented value and shows the raw measurement next to it. The
README states that in-game delta-v, sols, and thermal load are abstractions, not
flight dynamics. The transfer arc is explicitly labelled `c-fraction abstracted`
rather than presented as a real trajectory.

**Presentation.** The game runs in the browser at a 640x360 pixel-art internal
resolution with a consistent console UI, generated planet portraits, ship
sprites, and a starfield backdrop. It is a single static WebGL 2 build with
mouse and touch controls; no install, no account, no server.

**Team play.** Local hot-seat crew mode for 1-4 players gives each player one or
two roles with a buff and a personal goal worth +180 points. The goals conflict
on purpose: the science lead wants one more node, flight dynamics wants fuel
left, the field commander wants the hull home, and the director wants approval.
A handoff banner names whose call it is before each decision. Difficulty tiers
(Cadet / Standard / Director) change budget, approval, hazard fronts, heat per
tile, and the final score multiplier, so the tier is an engineering problem, not
a damage slider.

**What is next.** Networked four-player missions, more campaigns and hulls, a
codex that links every in-game number to its archive row, and a classroom mode
with printable design worksheets.

## Feature list (form-friendly)

- 72 real exoplanets, 13 terrain biomes, 9 landable in the current pool.
- Four hulls, three launch vehicles, three orbits, four science objectives,
  six instruments.
- Three-sector campaign, survey and relay sector tasks, nine hazard types.
- Eight seeded between-sector incidents with two trade-offs each.
- 1-4 player local hot-seat crew mode with four roles and conflicting goals.
- Three difficulty tiers, daily challenge, and a shareable campaign code.
- Final grade C-S with a full score breakdown and a next-grade gap.

## Challenge requirements trace

| Requirement from the brief | Where it is met |
|---|---|
| Define a mission objective and requirements | Objective cards plus the science-fit rule; the objective sets the quota and instrument compatibility. |
| Design a spacecraft | Four hulls, two instruments, mass/power/thermal/data bars, live ship diagram. |
| Select launch vehicle and orbit | Three launchers with fairing capacity; LOW/POLAR/HIGH profiles with period, eclipse, and passes/day. |
| Manage budget, mass, power, communications, data, lifetime | Budget and mass validation; HUD power/thermal/delta-v; downlink loss; data quota; sols. |
| See trade-offs | Instruments add mass/power/cost; hot planets cost more heat per move; heavy planets cost delta-v; distant planets lose data. |
| Mission simulation and evaluation | Three-sector campaign, telegraphed hazards, end-of-turn damage, refit shop, final grade and report. |
| Feedback and educational explanation | Per-turn HUD, damage toasts, debrief ledger, CML, four mission segments, mission analog, report notes. |
| Multiple scenarios | 72 real exoplanets, 13 biomes, survey vs relay sectors, seeded incidents, daily seed. |
| Mission concept / trajectory / timeline | Mission Architecture Review: transfer arc plus six-stage ConOps timeline. |
| Collaboration up to four players | Mission Control supports 1-4 players with crew goals and a shared campaign code. |
| Save/share/compare | Campaign code on the report, copy with `C`; daily best on the title. |
| Difficulty levels | Cadet / Standard / Director with explicit budget, approval, hazard, heat, and score modifiers. |
| NASA data | NASA Exoplanet Archive PSCompPars; raw CSV, builder, and formula table included. |

## How NASA data was used

- **Dataset:** NASA Exoplanet Archive - Planetary Systems Composite Parameters
  (`pscomppars`), a composite of confirmed-planet parameters.
- **Snapshot:** 5,801 rows queried via the archive TAP service; the raw CSV is
  bundled at `data/pscomppars_raw.csv`.
- **Curated pool:** 72 planets, 0.69-2.19 Earth radii (builder filter
  0.35-2.2 R⊕), selected to keep derived gravity playable and the dossier
  readable; three archive masses were implausible for their radii and were
  replaced with the Chen & Kipping estimate, flagged `mass_est`.
- **Fields:** `pl_eqt`, `pl_insol`, `pl_bmasse`, `pl_rade`, `pl_orbsmax`,
  `pl_orbper`, `sy_dist`, `st_teff`, `st_spectype`, `st_age`, `st_met`,
  `sy_pnum`.
- **Derived values:** heat, radiation, quakes, comms loss, science value,
  delta-v, sols, and biome. The exact formulas are in the README and
  `tools/build_exoplanets.py`.
- **Honesty:** the dossier shows the archive measurement next to the derived
  game value; the README states that the in-game resources are abstractions.

## Units and conventions

| Quantity | Unit used |
|---|---|
| Equilibrium temperature | kelvin (K) |
| Planet mass | Earth masses (M⊕); gravity converted to m/s² and displayed in g (9.80665 m/s²) |
| Planet radius | Earth radii (R⊕) |
| Insolation | Earth flux (S⊕); archive values in W/m² |
| Distance | light-years (ly); archive `sy_dist` in parsecs (pc), converted at 3.26156 ly/pc |
| Time | days (orbital period); sols for surface operations |
| Energy / power | watts (W) for instrument and hull power |
| Delta-v | in-game budget units, scaled from a gravity/thermal model; not real m/s |

## References

1. NASA Exoplanet Archive, *Planetary Systems Composite Parameters*
   (pscomppars), NASA Exoplanet Science Institute / Caltech.
   <https://exoplanetarchive.ipac.caltech.edu/>
2. Chen, J. G., & Kipping, D. M. (2017). Probabilistic Forecasting of the Masses
   and Radii of Other Worlds. *The Astrophysical Journal*, 834(1), 17.
   <https://doi.org/10.3847/1538-4357/834/1/17>
3. NASA Space Apps Challenge 2026, *Space Mission Design Game* challenge brief.
   <https://www.spaceappschallenge.org/>
4. Godot Engine 4.7.2 documentation. <https://docs.godotengine.org/>
5. NASA, *Design and Develop Science Missions* (PDF).
6. NASA, *General Mission Analysis Tool (GMAT)*.
7. NASA JPL, *Concept Maturity Levels (CMLs)*.
8. NASA GSFC, *Mission Design Lab (MDL)*.
9. NASA, *Mission Viz*. <https://nasa.github.io/mission-viz/>
10. NASA Webb, *Build It Yourself: A Learning Game About Telescopes*.
11. NASA, *CubeSat 101* (PDF).
12. Canadian Space Agency, *Digital Games and Activities*.
13. NASA Space Apps Challenge 2023, *Visualize a Space Mission Using Virtual
    Reality*.
14. Silkscreen and IBM Plex Mono fonts, SIL Open Font License.

## Submission-day links

- **Demo:** upload the <=30 s capture to YouTube/Vimeo (unlisted is fine) or
  attach the 7-slide deck PDF.
- **Playable build:** upload `submission/orbit_outplay_web.zip` to itch.io or
  GitHub Pages; the ZIP is the static `build/web/` folder.
- **Local run:** `cd build/web && python3 -m http.server 8060`, then open
  `http://localhost:8060`.

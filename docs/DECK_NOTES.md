# 7-slide deck - speaker notes (owner: e)

Companion to the project page (`docs/PROJECT_PAGE.md`). Seven slides, no more.
Target: 2 minutes of speaking plus a 30-second capture. Every claim below is
true of the merged build; do not add features from the pitch that have not
shipped (there is no online leaderboard, no VR build, no network play).

Deck file (gitignored artifact): `submission/orbit_outplay_deck.pdf`.
Demo capture: `submission/orbit_outplay_demo.mp4`, <= 30.0 s (current 29.6 s).

---

## Slide 1 - Title

**On screen**

> ORBIT & OUTPLAY: EXOPLANET SURVEY
> Design the mission. Draft a real world. Keep the agency alive.
> [team names] - NASA Space Apps Challenge 2026

**Speaker notes (~15 s)**

"Every target in this game is a real exoplanet from the NASA Exoplanet
Archive. You are not piloting a ship - you are running a small space agency,
making engineering trade-offs under a fixed budget, then living with them on
an alien surface."

**Cue:** title screen with the ringed planet and `BEGIN MISSION`.

---

## Slide 2 - Problem

**On screen**

> Mission design is a chain of coupled trade-offs.
> Mass vs capability. Thermal vs schedule. Power vs shielding. Data vs distance.
> A form teaches the vocabulary. It does not teach the tension.

**Speaker notes (~20 s)**

"The brief asks students to design a mission. The hard part is not listing
subsystems - it is that every choice costs something else. We made that tension
playable: the design screen has six live bars, and the launch button stays locked
until the stack actually closes."

**Cue:** design screen; hover `PATHFINDER` then `VECTOR M`; point at mass,
power, delta-v, and the warning line.

---

## Slide 3 - Game loop

**On screen**

> ONE RUN = 3 EXOPLANETS
> Mission Control -> Design -> Draft -> Surface -> Debrief -> Report
> 10-15 minutes. One more run is one click away.

**Speaker notes (~25 s)**

"A run is three planets. You pick a crew of one to four players and a difficulty
in Mission Control - or start solo Standard immediately. Then you design the
craft, draft one of three real worlds, fly its surface, refit, and do it twice
more. The loop is short on purpose: you can lose in ten minutes and immediately
understand why."

**Cue:** Mission Control -> design -> draft. Cut on the transition to the
surface.

---

## Slide 4 - NASA data as a mechanic

**On screen**

> pscomppars -> mission constraints
> Teq -> heat | mass/radius -> gravity -> delta-v | distance -> downlink loss
> 72 planets. 13 biomes. 9 landable. Raw CSV + builder included.

**Speaker notes (~25 s)**

"Equilibrium temperature becomes the thermal load and the starting heat. Mass
and radius become surface gravity and delta-v cost. Distance becomes downlink
loss. The dossier shows the archive measurement next to the derived game value,
so a student can see the abstraction instead of trusting a black box. The
72-planet pool is a curated cut of the archive, and the builder is
deterministic."

**Cue:** draft screen; hover a hot planet and a cold planet; point at the
`Teq ... -> heat ...` detail line and the threat tag.

**Do not say:** "real physics simulation" or "real trajectory". The transfer arc
is labelled `c-fraction abstracted`; delta-v and sols are game units.

---

## Slide 5 - Gameplay

**On screen**

> One move per turn. Path, cost, hazard.
> Hazards telegraph one turn ahead. FORMING fronts arm next turn.
> HOLD vents heat. EXTRACT banks the data. Risk pays.

**Speaker notes (~25 s)**

"Each turn you preview a path: delta-v, heat, node count, and whether the route
crosses a hazard. Commit the move, then the hazard resolves at the end of the
turn. Faint fronts are forming and arm next turn. You can leave with the quota,
or stay out for the fourth node and the risk bonus - and that is the decision
the game is about."

**Cue:** surface run - preview a path, commit, show the telegraph, HOLD, then
extract with a live front nearby.

---

## Slide 6 - Team play, difficulty, replay

**On screen**

> 1-4 players, local hot-seat. Four roles, conflicting goals, +180 each.
> Cadet / Standard / Director. Daily seed. Campaign code.
> The final report names every bonus source.

**Speaker notes (~25 s)**

"Crew mode is not a second HUD. Each role has a buff and a personal goal that
conflicts with the others: the science lead wants one more node, flight dynamics
wants fuel left, the field commander wants the hull home, the director wants
approval. Difficulty tiers change the engineering problem, not just damage.
And a campaign code reproduces the same worlds or the exact same stack, so two
teams can compare designs on identical planets."

**Cue:** Mission Control crew/difficulty cards; report `CREW GOALS` and
`DIFFICULTY` rows; copy the campaign code.

---

## Slide 7 - Impact, validity, next

**On screen**

> Browser play, no install. Reproducible data. Honest abstraction.
> Next: networked crews, codex, classroom worksheets.
> Play: [link] | Repo: [link]

**Speaker notes (~20 s)**

"The build is a static WebGL 2 page - no install, no account, no server - so a
classroom can play it from a link. Every derived number is reproducible from
the bundled CSV and builder, and the README states where the game abstracts.
Next we want networked crews, a codex that links each number to its archive row,
and printable design worksheets."

**Cue:** final report - grade, score rows, next-grade gap, sector ledger,
educational notes.

---

## Delivery notes

- Hard-cut between slides; no long fades.
- Burn in English subtitles if the demo has voice-over.
- Keep the whole deck <= 7 slides and the video <= 30.0 s.
- If a judge asks "is the trajectory real?", answer: no - the game labels the
  transfer arc as abstracted and keeps the physics-honest parts (temperature,
  gravity, distance, orbital period) tied to archive values.
- If a judge asks about the leaderboard, answer: local best and daily best only;
  there is no online leaderboard.

# Surface Loop Overhaul — "Expedition Survey"

Designer: NOVA. Problem from the boss: the surface is a flat board with a
handful of one-tile props; finding data is a straight walk, not an expedition.
This document is the **gameplay** work order. The rendering/composition half is
`docs/MAP_OVERHAUL.md` (W1–W6, owned by ATLAS / b / VEGA).

## Design pillars

1. **Every move is a route decision.** Information, distance, heat and the
   return leg must compete for the same three turns.
2. **Telegraph first, punish second.** The player should always see the next
   consequence before committing (Into the Breach's core lesson).
3. **Landmarks are navigation, not decoration.** A caldera, canyon or glacier
   should tell the player where they are and what is worth crossing the board
   for.
4. **Data is heavy.** A sample has to come home; the interesting decision is
   often whether to go one node deeper.

## References and what each one teaches

| Reference | Lesson for Orbit & Outplay |
|---|---|
| **Into the Breach** | A small board is enough if every threat is telegraphed and every move is a commitment. Clarity beats map size. |
| **FTL: Faster Than Light** | A sector is a sequence of risk/reward choices; the player chooses how deep to dive before the exit. |
| **Subnautica** | Scanner + depth bands + wrecks: exploration is gated by equipment and the player names places by their landmark. |
| **Death Stranding** | Terrain, cargo weight and the return trip make traversal itself the game. |
| **Slay the Spire** | A visible route with safe/elite/rest nodes turns a walk into a plan. |
| **Outer Wilds** | Knowledge is the reward; landmarks are how the player holds a map in their head. |
| **Dome Keeper** | Sortie → haul → return → spend; a short loop with a hard return beat. |
| **Highfleet** | Signals and detection can make empty space tense without adding enemies. |

## Target loop (one sector)

1. **Landing shelf.** The lander sets down beside one hero landmark. Two easy
   signals are visible; the deep field is dark.
2. **Choose a line.** Tier-1 nodes are close and pay 1 data. Tier-2 "deep cache"
   nodes sit farther out, pay 2 data and add heat on pickup. A single deep node
   can finish the quota, but the return leg is longer and the hazard front moves.
3. **Survey.** Landing on a site starts a survey; the player can take the safe
   sample or spend an extra turn on a deep scan for a better payout and a
   complication.
4. **Weather the front.** Hazards are telegraphed, then move/expand. Shelter is
   a real choice (hold behind a ridge vs. dash for the last node).
5. **Return.** Quota aboard is not extraction. A cyan extraction pad is chosen
   once, 2–6 tiles from the landing zone; the lander has to reach that pad, with
   samples reducing range or increasing heat.
6. **Extract and refit.** The run's route becomes the story in the debrief.

## Map grammar

- **Three rings:** Landing Shelf (0–4 tiles), Interior (4–8), Deep Field (8–12).
  The ring controls node tier, hazard density and backdrop detail.
- **One hero landmark** per board (4×4 massif/volcano; cryo/arid/barren need
  their own 4×4 art from VEGA).
- **2–3 supporting outcrops** at 0.55–0.75 scale, one silhouette per key, with
  ±8 % scale / ±4 % tint jitter.
- **One named feature** the player can describe after the run ("the caldera
  board", "the glacier board").
- **No feature narrower than 3 cells** (W2); soft sub-cell edges (W1).

## Mechanics

### M1 — Signal tiers (implemented in this pass)

- `_place_objectives()` now places nodes in **distance bands** (≈4, 6, 8, 10
  tiles) and assigns `objective_tiers` / `objective_values`.
- Tier 1 = 1 data, cyan small node.
- Tier 2 = 2 data, larger/brighter node, **+4 heat** on pickup, toast
  `DEEP CACHE +2 · HEAT +4`.
- The path preview still counts nodes; the HUD quota remains the same, so a
  deep route is a genuine shortcut with a thermal cost.
- This is deliberately small and shippable; it makes the existing 4-node board
  read as a route choice without new art or UI.

### M2 — Survey choice (next)

When the lander steps onto a tier-2 site, pause the turn and offer:

- **SAMPLE** — 1 turn, +2 data, no extra heat.
- **DEEP SCAN** — 1 turn, +3 data, +8 heat and a telegraphed hazard spike.
- **LEAVE** — no turn spent, keep the route.

This is the "greed" decision; it needs a small modal and a turn-pause. Implement
only after M1 is stable.

### M3 — Terrain cost (next)

- Rock/ridge cells cost 2 range, ice slides 1 extra cell, water/lava block.
- The path preview prints `COST n / RANGE 3`; the route is a real budget, not
  just a step count.
- Pair with the camera pan; no new art.

### M4 — Survey fog / scanner (next)

- The board starts dim outside a scanner radius (5 cells); moving reveals 2
  cells; relay beacons reveal 4.
- Terrain stays faintly visible; nodes and hazard fronts are hidden until
  scanned. This turns the map into an expedition without hiding the art.
- This is the highest-risk item for readability; trial behind a flag first.

### M5 — Hazard fronts (existing + tune)

- Hazards already telegraph one turn ahead and resolve at end of turn.
- Make one front **drift** one cell toward the last known player signal each
  turn; keep the preview exact. This is the Highfleet/Into the Breach tension.

### M6 — Return weight (later)

- Each sample adds 1 heat and reduces range by 1 on the return leg, so a greedy
  deep run has a real extraction risk. Needs a HUD "cargo" readout.

## Acceptance for the first slice

- Four nodes spawn in four distance bands; at least one tier-2 node is reachable
  within the first three turns on 50 seeds per biome.
- A tier-2 pickup credits 2 data and adds 4 heat; the toast and HUD agree.
- 600-seed reachability audit still reports **0 unreachable**.
- Full sector capture shows the larger/brighter deep node distinct at 1×.
- No new art; VEGA owns any decals/4×4 landmarks.

## Ownership

- **NOVA:** M1 code, the survey/turn model, acceptance captures.
- **ATLAS:** W1/W3/W6 map hooks, terrain cost/path integration if M3 lands.
- **b:** W2 macro composition and ring placement guarantees.
- **VEGA only:** decals, 4×4 cryo/arid/barren landmarks, any new animation art.
- **ORION:** gate decision; no export without a named capture.

## Difficulty curve (NOVA, 19:35)

Boss asked for a gentle quadratic ramp across rounds. Research summary:

- **Balatro:** blind targets are a hand-authored, steepening table (300 → 800 →
  2,000 → 5,000 → 11,000 → 20,000 → 35,000 → 50,000), with Small/Big/Boss at
  1×/1.5×/2×; the steepest jump is Ante 4→5. Higher stakes *swap the table*
  and add discrete rules, not a smooth multiplier.
- **Soul Knight (Matrix):** Pressure +1 per floor; enemies gain +15% base HP
  per Pressure and +1 damage every 3 Pressure. It is linear/cumulative per
  floor, with loops, not n².
- **Slay the Spire:** three acts with authored enemy tables, plus 20 Ascension
  modifiers that remove forgiveness one named rule at a time.
- **FTL:** enemy systems/hull scale per sector, and some enemy types are gated
  until later sectors.

A literal n² over three rounds (1 / 4 / 9) would erase the refit power curve.
The shipped curve is normalised to the campaign:

`threat = 1.0 + 0.18 × (sector − 1)²`

| Sector | Threat | Effect |
|---|---|---|
| 1 | 1.00× | Shakedown: +2 hull, +4 sols, +1 range, hazards capped at 2, max 1 hull damage per hit |
| 2 | 1.18× | Heat gain ×1.18; normal hazard ramp |
| 3 | 1.72× | Heat gain ×1.72; **+1 hazard front** (quadratic tier bonus) |

This is a **stat ramp plus one discrete rule** at sector 3, matching how the
reference games keep escalation legible. Player power still comes from
refits/buffs; the curve asks the build to keep up rather than invalidating it.
HUD shows `THREAT 1.2x` / `1.7x` in the bottom route line.

## Route tempo (2026-11-15)

- Starting sols: **30** on the shakedown sector, **24** on normal sectors (+4 from the old 26/20).
- Each sector also places **3 optional data caches** at roughly 6/9/12 tiles. A cache is `+1 DATA` and refunds `+1 SOL`; it is never part of the quota.
- This makes the map a route choice: quota nodes are the shortest finish, caches are the longer line that buys back mission time.

# Content Pack - Events, Onboarding, and Copy Audit (owner: e)

Status re-verified **after the ORION merge** (working tree on top of `32cff00`
+ `origin/main`). The event feature has **shipped**, but not from this pack:
ATLAS wired an inline 14-card pool in `scripts/game_state.gd` (`const EVENTS`,
line 391) and a modal in `scripts/debrief.gd` (`_show_event`, line 301).

Therefore:

- The **shipped** card content is the table in §2. That is what players see and
  what the README describes.
- `data/events.json` is a **prototype pack that no game file loads**. It is kept
  because it has the richer two-choice contract (SAFE/GREEDY kinds, exact
  `detail` promises, effect keys) and `tools/audit_data.py` still validates it.
  It is not the source of truth for the current build.
- The onboarding hint card is **still not wired** (no widget exists in
  `scripts/`). Copy is final in §5; it needs an ATLAS widget.
- The copy/code mismatch list is §6. Every row is verified against the merged
  working tree, not against an old commit.

Line numbers move; function names and string literals are the reliable anchors.

---

## 1. Shipped flow

```
sector 1 -> debrief (result + shop) -> incident card -> draft 2
sector 2 -> debrief (result + shop) -> incident card -> draft 3
sector 3 -> debrief -> final report            (no card)
```

`GameState.finish_sector()` increments `run.sector`, then calls `roll_event()`
only while `run.sector <= SECTORS_PER_RUN` and approval is above zero
(`game_state.gd:1002-1005`). The debrief reopens an unresolved card on entry
(`debrief.gd:286-288`), so closing the overlay cannot skip the choice.

Selection is seeded per run and skips repeats:

```gdscript
rng.seed = int(run["seed"]) + sector_no * 977
# walk the pool until an id not in run["events_seen"] is found
```

`choose_event(index)` (`game_state.gd:809`) applies `budget` and `approval`
immediately, banks `next_heat` / `next_dv` / `next_power` / `next_sol` /
`next_integrity` / `next_data` / `bonus_science` in the run, records the id in
`events_seen`, and clears `event_card`. `begin_sector()` consumes the `next_*`
values (`game_state.gd:846-866`, `:909`). There is no `run.pending` dictionary
in the shipped code - the prototype contract below is the only place that name
appears.

---

## 2. Shipped card pool (`game_state.gd` `const EVENTS`)

Fourteen cards, two trade-offs each, no obviously correct option. Effects in
brackets are the exact shipped keys; the visible `desc` is the promise.

| # | Title (`id`) | Body | Option A | Option B |
|---|---|---|---|---|
| 1 | **SOLAR STORM WARNING** (`solar_storm`) | A coronal front is tracking toward the next target. | `RIDE IT OUT` - Next sector starts with +8 heat. `[next_heat 8]` | `POWER DOWN` - -1 approval, +1 power next sector. `[approval -1, next_power 1]` |
| 2 | **PRIVATE DONOR** (`private_donor`) | A launch provider offers a no-strings grant. The board notices. | `TAKE THE GRANT` - +$50M, -2 approval. `[budget 50, approval -2]` | `DECLINE` - +1 approval. `[approval 1]` |
| 3 | **SALVAGE CACHE** (`salvage_cache`) | A spent upper stage is drifting near the transfer orbit. | `STRIP IT` - +$30M, +1 delta-v next sector. `[budget 30, next_dv 1]` | `LEAVE IT` - +1 integrity next sector. `[next_integrity 1]` |
| 4 | **CRYO LOOP LEAK** (`cryo_leak`) | The thermal loop is losing working fluid between missions. | `PATCH IT` - $25M, +1 integrity next sector. `[budget -25, next_integrity 1]` | `TOP IT OFF` - +1 heat, +1 power next sector. `[next_heat 1, next_power 1]` |
| 5 | **STELLAR ARCHIVE** (`stellar_data`) | A colleague offers a calibrated light-curve archive. | `BUY ACCESS` - $30M for +160 science. `[budget -30, bonus_science 160]` | `SHARE LATER` - +1 approval. `[approval 1]` |
| 6 | **CREW FATIGUE** (`crew_fatigue`) | Two flight controllers have been awake for 31 hours. | `REST ROTATION` - -1 sol next sector, +1 integrity. `[next_sol -1, next_integrity 1]` | `PUSH THROUGH` - +1 delta-v, -1 integrity next sector. `[next_dv 1, next_integrity -1]` |
| 7 | **RIVAL AGENCY** (`rival_agency`) | A competitor wants your raw survey data before publication. | `PUBLISH FIRST` - +2 approval, -$20M. `[approval 2, budget -20]` | `SELL THE COPY` - +$35M, -1 approval. `[budget 35, approval -1]` |
| 8 | **ANOMALOUS SIGNAL** (`anomalous_signal`) | The receiver hears a narrowband pulse during the cruise phase. | `INVESTIGATE` - -1 integrity, +180 science. `[next_integrity -1, bonus_science 180]` | `LOG AND MOVE` - +1 power next sector. `[next_power 1]` |
| 9 | **PULSAR FIX** (`pulsar_fix`) | A millisecond pulsar gives the nav team a free timing fix, if the receiver can spare the cycles. | `LOCK THE PULSAR` - +2 data buffer, -2 sols next sector. `[next_data 2, next_sol -2]` | `STAY OPTICAL` - +1 power, +3 heat next sector. `[next_power 1, next_heat 3]` |
| 10 | **SOLAR SAIL TRIAL** (`sail_trial`) | A piggyback solar sail can be deployed on the cruise. It is either a science headline or a thermal problem. | `DEPLOY SAIL` - +220 science, +6 heat next sector. `[bonus_science 220, next_heat 6]` | `KEEP IT STOWED` - +2 delta-v next sector. `[next_dv 2]` |
| 11 | **DEBRIS SWEEP** (`debris_sweep`) | A tracked debris cloud crosses the approach corridor. The shield can take the hits, or the pilot can thread it. | `RUN THE SHIELD` - +1 integrity, -2 sols next sector. `[next_integrity 1, next_sol -2]` | `THREAD IT` - +2 delta-v, -1 integrity next sector. `[next_dv 2, next_integrity -1]` |
| 12 | **HOST CITY** (`host_city`) | The launch range offers a public outreach day. The agency can open the pad or keep the schedule quiet. | `OPEN THE PAD` - +3 approval, -$20M. `[approval 3, budget -20]` | `KEEP IT QUIET` - +$30M, -1 approval. `[budget 30, approval -1]` |
| 13 | **RADIATOR SWAP** (`radiator_swap`) | A ground-test radiator is available before the next departure. It is better hardware, or a quick sale. | `SWAP IT IN` - -$35M, -6 heat next sector. `[budget -35, next_heat -6]` | `SELL THE CORE` - +$25M, +5 heat next sector. `[budget 25, next_heat 5]` |
| 14 | **OPEN-SOURCE FLIGHT SOFTWARE** (`open_source`) | The team can publish its scheduler as a public good, or license it to a partner agency. | `PUBLISH IT` - +2 approval, -$10M. `[approval 2, budget -10]` | `LICENSE IT` - +$35M, -1 approval. `[budget 35, approval -1]` |

Tone notes for the next edit pass (E3) are in §7.

### 2.1 Shipped card chrome (`debrief.gd:301-370`)

| Element | Shipped string |
|---|---|
| Kicker | `BETWEEN MISSIONS  //  AGENCY EVENT` (7 px, AMBER) |
| Title | `<card.title>` (13 px, CYAN) |
| Body | `<card.body>` (7 px, MUTED, wraps in 420 px) |
| Option row | panel 420x66; `<option.label>` 9 px TEXT, `<option.desc>` 7 px MUTED, button `CHOOSE` |
| Footer hint | `This choice carries into the next sector.` (6 px, DIM) |

The richer `COPY_DEPTH.md` chrome (SAFE/GREEDY chips, `EVENT 1 OF 2`, exact
`detail`) did **not** ship. Do not claim it in the README or the submission.

---

## 3. Prototype pack (`data/events.json`, not loaded)

This pack is intentionally kept as a design artifact. If the live pool is ever
replaced, this is the better contract:

- eight cards keyed by `choices[].kind` (`safe` / `greedy`);
- exact `detail` promises that the UI must render verbatim;
- additive effect keys with clamps, applied at `begin_sector()`.

The full schema, effect contract, and balance table live in git history (the
pre-merge version of this file) and in the JSON `meta` block. The validator
still enforces: 8 cards, two choices each, uppercase labels, `detail` present,
known effect keys, multipliers inside 0.5-2.0 (`tools/audit_data.py` §3).

**Do not re-wire this file without also editing the shipped strings.** The ids
only partly overlap (`solar_storm`, `private_donor`, `salvage_cache` vs
`salvage_wreck`, `cryo_leak` vs `window_slip`, `stellar_data` vs `peer_review`,
`crew_fatigue` vs `contractor_audit`, `rival_agency` vs `rival_leak`,
`anomalous_signal` vs `gravity_assist`), and the choices/numbers differ.

---

## 4. Report line - NOT shipped

`docs/COPY_DEPTH.md` §4.5 asks for a narrative `DECISIONS` line on the final
report. `scripts/report.gd` has no such line, and `GameState.run` does not store
the chosen label (only `events_seen` ids). Do not claim it.

Suggested minimal wiring if ATLAS wants it:

1. In `choose_event()`, append
   `{"id": card.id, "label": options[index].label}` to `run.events`.
2. In `report.gd:_build_ledger()`, print the labels joined by `  ·  ` under the
   stats block; truncate to campaign titles if the string exceeds 62 chars.

No score effect.

---

## 5. Onboarding hint card (first sector, still widget-pending)

Three lines, shown once per run on the first sector, dismissable, never again
in that run. ATLAS owns the widget; the copy is final:

```
MOVE   Click a tile to preview the path. ENTER commits one move.
DATA   Collect the quota (3 or 4 nodes), then EXTRACT with E.
DANGER Hazards land where the grid shows, at end of turn. HOLD vents heat.
```

Implementation notes:

- Show when `int(GameState.run.sector) == 1 and turn == 1`, inside the existing
  HUD frame, and set `run.onboarded = true` on dismiss.
- Do not cover the D-pad or the action buttons (`y=268..344` on the right).
- **Do not promise H in the sector.** `sector.gd:1453 _unhandled_input()` does
  not call the parent, so `H` (hide UI, `map_generator.gd`) and `F10`
  (screenshot) do nothing during a surface run. `H` opens How to Play on the
  title screen only.
- `V` (view cycle) and `G` (grid) do work in-sector, but the card is full;
  keep them on the pause/help overlay.

---

## 6. Copy and code mismatches found during the audit (for ATLAS)

Re-verified against the merged working tree. These are listed instead of
silently edited because they live in another owner's file. Ordered by
player-visible impact.

| # | File:line | Problem | Suggested fix |
|---|---|---|---|
| 1 | `scripts/sector.gd:45` + `1221`, `1226` | `ECLIPSE SHADOW` has `"power": 2`; the resolver does `total_p += 2` then `power = max(0, power - total_p)`, so the hazard **drains 2 power** and the toast reads `-2 PWR`. README:202 and the hazard theme say "Restores 2 power". | Make power a signed gain (`power_gain`) or set `"power": -2` and apply `power = clampi(power + total_p, 0, power_max)` so the copy ("restores") is true. |
| 2 | `scripts/debrief.gd:139` | `ORBIT  LOW INSERTION` is hard-coded, so POLAR/HIGH runs are reported as LOW. (`report.gd:214-219` already computes the flown orbit correctly.) | `ORBIT  %s INSERTION` with `str(GameState.orbit().get("name", "LOW"))`. |
| 3 | `scripts/title.gd:134` | "Collect 3 of 4 data nodes" is wrong for MAP THE SURFACE (quota 4) and for relay sectors (3 beacons). | "Collect the quota (3 or 4 nodes) before sols or delta-v run out." Also mention forming fronts if the line has room (`COPY_DEPTH.md` §5.1). |
| 4 | `scripts/sector.gd:1453` | `_unhandled_input()` never calls the parent, so `H` (hide UI) and `F10` (screenshot) are dead in-sector although README lists F10 as map-generation-only and H as title-only. | Call `super._unhandled_input(event)` for keys this handler ignores, or add `KEY_H` / `KEY_F10` branches. |
| 5 | `scripts/game_state.gd:136` | Deployable Radiator desc says "Heat gain -3 per move" but the module sets `thermal_res: 6`. `begin_sector()` computes `round(heat * 0.11) - thermal_res` before multipliers (`:857`), so it removes about 6. | Pick one number: set `thermal_res: 3`, or change the desc (and README:261) to the real value. Keep the three in sync. |
| 6 | `scripts/game_state.gd:142` + `design.gd:302` | Deep Data Buffer sets `data_cap: 4`, but `data_cap` is only drawn as the design-screen DATA bar. `finish_sector()` uses a fixed cap (`4 if survey else quota`, `:944`), and bonuses already clamp to it. | Either use the ship `data_cap` in the delivered/downlink math, or rewrite the desc ("+4 data capacity on the design screen") so it does not promise gameplay that is not there. |
| 7 | `scripts/game_state.gd:831`, `902-908` | Field Repair Kit banks `pending_repair`, but `begin_sector()` sets both `integrity` and `integrity_max` to the full hull value (`:871-879`), so `integrity < integrity_max` is never true. The purchase is a no-op, including `repeatable`. | Apply the repair to the run's persisted hull state before the next sector is built, or heal the previous sector's ending integrity instead of starting full. |
| 8 | `scripts/game_state.gd:391-456` | The shipped event pool is inline and differs from `data/events.json` (ids, titles, choices, numbers). This file used to say the JSON was the source of truth. | Decide one source. If the inline pool stays, delete or clearly quarantine `data/events.json`; if the JSON wins, port the shipped descs and drop `const EVENTS`. |
| 9 | `scripts/report.gd` | No `DECISIONS` line and no risk-bonus row. Risk is appended to the `CONCEPT CML ...` line (`:194-203`), and the grade gap is `NEXT  +%d TO GRADE %s` at `:114-122`. | Copy is fine as shipped; just make docs describe what exists. If the `COPY_DEPTH` chrome is wanted, wire `run.events` first. |
| 10 | `scripts/draft.gd:393-395` | The transfer arc prints `distance_ly / 4.0` years, so a 4.2 ly target reads `1.0 YR` (about 4c) and a 4,976 ly target reads 1,244 yr. The note says `c-fraction abstracted`, but the number still implies faster-than-light. | Use a plausible cruise speed and label it, e.g. `distance_ly / 0.06` for 6% c (4.2 ly = 70 yr), or replace the duration with a qualitative `TRANSFER ARC  ·  4.2 LY`. |
| 11 | `scripts/draft.gd:283` | The dossier detail line uses `>` as a separator: `Teq 167 K > heat 39   ·   1.02g > dv ...`. A judge can read it as "greater than". | Use `→` or `·` between the measurement and the derived value. |
| 12 | `scripts/sector.gd:1453` + `title.gd:134` | README:176 says "Reaching all four nodes auto-completes the survey"; relay sectors use 3 beacons and the title row says "3 of 4". The HUD itself is correct (`RELAYS n/3`). | Keep the README sentence scoped to survey sectors, and fix the title row (item 3). |

### 6.1 Status re-check (2026-11-14 — static, no Godot on this box)

Rows 1, 2, 3, 5, 7, 10, 11 and 12 are **closed** in the tree; only 4, 6, 8 and 9 still describe live behaviour. Checked by reading the source, not by re-running an old report:

| # | Status | Evidence |
|---|---|---|
| 1 | **CLOSED** | `sector.gd` eclipse info is `"power": -2`; the resolver does `clampi(power - total_p)` and the toast prints `+2 PWR` when `total_p < 0`. README's "restores 2 power" is now true. |
| 2 | **CLOSED** | `debrief.gd` no longer prints an orbit line at all; the header is `PLANET · BIOME · SURFACE OPERATIONS REPORT`. `report.gd` still prints the flown orbit. |
| 3 | **CLOSED** | `title.gd` How-to-Play now says "Collect the required data nodes, then return to the lander and press EXTRACT before sols or delta-v run out." |
| 4 | **OPEN (by design)** | `sector.gd:_unhandled_input()` still does not forward unhandled keys, so `H` (hide UI) and `F10` (capture) do nothing in-sector. README scopes F10 to map-generation screens; `docs/MAP_GENERATOR.md` now says the same. Wiring them is a two-branch change if a later pass wants it. |
| 5 | **CLOSED** | `game_state.gd` radiator is `"thermal_res": 3` with "Heat gain -3 per move."; `tools/qa/audit_project.py` asserts the pair. |
| 6 | **PARTIAL** | Deep Data Buffer's `comms_bonus: 4` now applies in `ship()`, but `finish_sector()` still caps delivered data at `4 if survey else quota`, so the `+4 data buffer` half is still design-screen-only. Copy says "4% less data lost on downlink" first, so the player-facing promise is met. |
| 7 | **CLOSED** | The kit banks `next_integrity`, consumed in `begin_sector()` (`integrity = hull + next_integrity + crew + buffs`). `pending_repair` is gone; a comment records why. |
| 8 | **QUARANTINED** | The inline pool in `game_state.gd` is the shipped source; `data/events.json` is kept as a validated prototype and both `this doc` and `audit_data.py` say so. |
| 9 | **PARTIAL** | Risk has its own report row; the narrative `DECISIONS` line is still not shipped, and `report.gd` does not claim it. |
| 10 | **CLOSED** | `draft.gd` prints `TRANSFER ARC · %.1f LY · %.1f YR @0.85c` and divides by 0.85 — no faster-than-light number. |
| 11 | **CLOSED** | The dossier detail line separates values with `·` (no `>` as a separator). |
| 12 | **CLOSED** | The title wording is generic ("the required data nodes"); README scopes the 4/4 sweep to survey sectors. |

Second pass notes (still true):

- README now says Δv **and** sols are spent per tile moved, and marks F10 as
  map-generation-only, matching `sector.gd:874-876`.
- The builder docstring in `tools/build_exoplanets.py` was corrected to the real
  filter, `0.35 <= radius <= 2.2` (it said `0.4-2.7`).
- Approval is `8 + 2 * delivered` (`game_state.gd:965`); grant is
  `(30 + 15 * delivered) * grant_mult` plus `+20` on a full sweep and `1.25x`
  for geology on rocky biomes (`:952-961`). README matches both.

---

## 7. Event tone pass (E3) - notes for ATLAS

The shipped pool is already tonally consistent: one-sentence body, uppercase
imperative labels, every cost visible. Micro-edits only:

1. **`SOLAR STORM WARNING` is 19 characters**, above the 18-char clip budget in
   `COPY_DEPTH.md` §4.3. Use `SOLAR STORM`; the body already says "tracking
   toward the next target".
2. **Sign consistency.** `PATCH IT` reads `$25M` while `BUY ACCESS` reads `$30M`
   and `PUBLISH FIRST` reads `-$20M`. House style is an explicit sign: use
   `-$25M` and `-$30M` (or `$25M` everywhere, never mixed).
3. **"no-strings grant"** followed by `-2 approval` is the joke; keep it. Do not
   add "but" or explain it in the body.
4. **`LOG AND MOVE`** is the only label without a resource verb. `LOG IT` or
   `FILE AND MOVE` reads faster at a glance; optional.
5. **Keep the 31-hour detail.** Specific numbers are what make the card feel
   like an agency, not a deck of abstractions.
6. **`stellar_data` id vs `STELLAR ARCHIVE` title** is invisible to players; no
   action, but do not use the id as a caption.

---

## 8. Acceptance checklist

Shipped and verified by reading the merged tree:

- [x] One card after sectors 1 and 2 only; none after sector 3
      (`finish_sector` / `roll_event` guard).
- [x] Both options render label + desc before the click; no hidden cost.
- [x] `budget` / `approval` apply once and clamp (`choose_event`).
- [x] `next_*` values are consumed at the next `begin_sector()`.
- [x] Same run seed reproduces card order; `events_seen` prevents repeats.
- [x] Card is a modal over the debrief, not a new scene.

Still open:

- [ ] `DECISIONS` line on the report (content ready, no storage).
- [ ] Onboarding hint card widget.
- [ ] Mismatch items 1-12 above, in ATLAS's files.
- [ ] `data/events.json` removed or re-wired so there is one source of truth.

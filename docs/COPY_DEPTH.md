# Copy pack — gameplay depth (owner: e)

Status: **content ready, wiring pending (ATLAS)**. This file is the single source
of the exact UI strings for the 12:04 gameplay-depth sprint (BOARD) and the two
copy bugs that ride along with it. It does **not** ship anything by itself: no
scene loads these strings yet, so README/SUBMISSION must not claim relay
surveys, event cards, hazard growth, risk bonus, or the grade-gap line as
visible until ATLAS wires them and d verifies a frame.

Anchors below are against **`HEAD f1eafc9`**. Line numbers move; function names
are the reliable anchor.

Read order for the implementer: `docs/EVENTS.md` (event content + schema), then
this file (UI copy + layout budget).

---

## 1. House style (so new copy matches the shipped screens)

- **ALL CAPS** for labels, titles, buttons and chips. Sentence case is never
  used in the HUD (`docs/EVENTS.md` card bodies are the one exception).
- Separator is `  ·  ` (two spaces, middle dot, two spaces). `—` is only used
  for "no value" or a hard break, never between two facts.
- Numbers: no thousands separators (`1043`, not `1,043`), matching
  `report.gd:68`. Money is `+$60M` / `-$40M`, never `$60,000,000`.
- Signs are always explicit on deltas: `+8`, `-6`, `%+d`.
- Colour semantics already in `scripts/ui_kit.gd`: CYAN = information/mission,
  GREEN = gain/success, AMBER = cost/warning, RED = danger/failure,
  MUTED/DIM = secondary.
- Do not invent new control keys in copy. The live set is ENTER, SPACE, E, G,
  V, WASD/arrows, F10; H is title-screen only (see §7).

---

## 2. Naming: "mission objective" vs "sector task"

The design screen already has four **mission objectives** (`atmosphere`,
`surface`, `astro`, `geology`). The relay feature is a *per-sector variant*, so
it must never be called an objective in UI text:

| Concept | Player-facing name | Never call it |
|---|---|---|
| Design-screen choice | `MISSION OBJECTIVE` (existing) | — |
| Recover/relay variant | `SECTOR TASK` | "relay objective" |
| One relay placement | `RELAY` / `BEACON` | "node", "data node" |

Every relay-sector string says **RELAY**, not DATA. Data nodes stay DATA in
recover sectors only.

---

## 3. Relay Survey (sector task variant)

Contract assumed from BOARD: every second sector (i.e. sector 2 of 3) plants
**3 relay beacons on marked tiles**, then extracts; same verbs and same extract
button. The implementation should keep using the existing `quota`, `data` and
`finish_sector()` math so grant/approval/score copy does not change.

### 3.1 Sector HUD (`scripts/sector.gd`)

| Slot / anchor | Current (recover) | Relay sector string | Notes |
|---|---|---|---|
| Stat label, `_build_hud()` L257 `_top_stat(..., "DATA", ...)` | `DATA` | `RELAY` | Keep the same x/width; 5 chars fits the 64 px column at 6 px. |
| Stat value, `_refresh_status()` L403 | `%d/4` | `%d/3` | Beacons planted / quota. Green while below quota, CYAN at 3/3 (same pattern as DATA). |
| Quota chip, L404 | `QUOTA 3` | `QUOTA 3` | Unchanged — the field is already the quota. |
| Idle route line, L466-470 | `TURN 4 · RANGE 3 · need 2 more nodes · CLICK A TILE` | `TURN 4 · RANGE 3 · 2 RELAYS LEFT · CLICK A MARKED TILE` | 57 chars, fits 414 px at 7 px. |
| Path preview append, L456-460 | ` · NODE` | ` · RELAY` | Only when the previewed path ends on an unplanted beacon tile. |
| Commit toast, `_execute_path()` / `_show_toast` | `DATA +1` (existing) | `RELAY 1/3 ONLINE` | 16 chars. On the third: `RELAY 3/3 ONLINE`. |
| Quota-met route line, L452 | `TURN 6 · RANGE 3 · QUOTA MET — E EXTRACT` | `TURN 6 · RANGE 3 · RELAY NET ONLINE — E EXTRACT` | 45 chars. |
| Sector-start toast, `_start_sector()` | none | `RELAY SURVEY  ·  PLANT 3 BEACONS` | One-shot, 2.0 s, CYAN. 33 chars. |
| Threat label, L423-441 | unchanged | unchanged | Hazard copy is orthogonal. |

Do **not** rename the extract button, the HOLD button, or the E key. The verb
"extract" is the same in both sector tasks by design (BOARD item 1).

### 3.2 Debrief (`scripts/debrief.gd`)

The summary panel rows are at `y=46..130` and already nearly touch the rule at
140, so relay copy replaces lines rather than adding them.

| Slot / anchor | Current | Relay sector string |
|---|---|---|
| Success reason, L87-92 | `ALL QUOTAS MET` | `RELAY NETWORK DEPLOYED` |
| Failure reason, L87-92 | `AGENCY REVIEW FLAGGED` | `RELAY NET NOT DEPLOYED` (not extracted or <3 planted) |
| Data row, L94-102 | `DATA DELIVERED` / `3 / 3 NODES` | `RELAYS ONLINE` / `3 / 3 BEACONS` |
| Footer sub after sector 1, L235-237 | `Three new targets. Choose where the grants go.` | `Three new targets. Next sector task: RELAY SURVEY.` (52 chars, fits 360 px at 7 px) |
| Everything else (science/grant/approval rows, shop) | unchanged | unchanged |

The relay count still goes through `finish_sector(extracted, planted, sec)` so
the existing grant formula and the `data` clamp keep working. If a relay sector
can plant fewer than 3 and extract, that is a failure with the reason above.

### 3.3 Report (`scripts/report.gd`)

No layout change: the ledger's `%d/%d` column already shows planted/quota and
the stats line stays `DATA DELIVERED  %d NODES`. Rationale: the report is a
campaign summary of delivered science; adding a second column would not fit the
344 px panel and the mission theme does not change.

### 3.4 Mission design / title

Unchanged. The four mission objectives are not relay. Do not add relay to the
design screen or the title how-to-play rows.

---

## 4. Event cards (between sectors)

Full card content is in `data/events.json`; this section fixes the **UI chrome
and the report line** so the card looks native.

### 4.1 Flow (copy-side contract)

```
debrief (result + shop)
  -> footer button "REVIEW INCIDENT >"        (instead of "SELECT NEXT TARGET >")
  -> card overlay: two choices
  -> choice clicked -> toast "FILED · <LABEL>" -> footer button becomes "SELECT NEXT TARGET >"
  -> draft
```

The card is a **modal overlay on the debrief**, not a new scene: one less scene
to export, and the shop stays visible behind the dim so the player can see what
they just bought. No card after the final sector.

### 4.2 Debrief footer (`debrief.gd:218-245`)

| Slot | Pending-event string | After choice / no event |
|---|---|---|
| `footer_title` L229 | `INCIDENT REPORT  ·  BEFORE DRAFT` | `NEXT: EXOPLANET TARGET DRAFT` (existing) |
| `footer_sub` L235 | `Two options. The choice applies to the next sector.` | existing |
| `next_btn` L242 | `REVIEW INCIDENT >` | `SELECT NEXT TARGET >` (existing) |

`next_btn` must not skip the card. If the player closes the card without
choosing (Esc), keep the footer button at `REVIEW INCIDENT >` and re-open the
same card — no default choice, no silently applied effects.

### 4.3 Card overlay (new, on top of `debrief.gd`)

720-wide design budget is 640; use a 460×220 panel at `(90, 70)` with a
`ColorRect(Color(0.01,0.02,0.04,0.72))` full-rect shade behind it.

| Element | String | Font / colour | Position / size |
|---|---|---|---|
| Header | `INCIDENT REPORT  //  <TAG>` (tag = `event.tag`) | 9, AMBER, bold | (12, 8), 280×12 |
| Card id | `EVENT 1 OF 2` / `EVENT 2 OF 2` | 6, DIM, right | (330, 10), 110×10 |
| Title | `<event.title>` (uppercase in JSON) | 14, CYAN, bold | (12, 24), 436×18 |
| Body | `<event.body>` | 8, TEXT, wrap | (12, 46), 436×40 |
| Choice A panel | see §4.4 | — | (12, 92), 436×54 |
| Choice B panel | see §4.4 | — | (12, 152), 436×54 |
| Footer hint | `CLICK A CHOICE  ·  APPLIES TO NEXT SECTOR` | 6, DIM | (12, 208), 436×10 |
| Filed state (after click) | `FILED  ·  <chosen label>` | 7, GREEN, bold | replaces footer hint, same box |

Card title must be a single line: every title in `events.json` is ≤ 18 chars.
Body is ≤ 150 chars by construction; 8 px text in 436 px wraps to 3 lines max.

### 4.4 Choice rows

Both options are always fully visible; the cost is never hidden behind hover.

| Element | String | Font / colour |
|---|---|---|
| Panel | `UIKit.panel(Color("#0c1726"), Color("#263d55"))` | — |
| Kind chip | `SAFE` (kind `safe`) / `GREEDY` (kind `greedy`) | 5, CYAN / AMBER, right-aligned |
| Label | `<choice.label>` | 9, TEXT, bold |
| Detail | `<choice.detail>` (exact JSON string) | 7, MUTED, wrap, two lines max |

Rules:
- `detail` is the promise. Render it verbatim; if it does not fit two lines at
  7 px in 420 px, shorten the JSON string — do not shrink the font.
- Clicking anywhere in the row commits that choice, including the label text.
- Disable both rows on the first click before applying effects (no double
  apply of `budget_delta` / `approval_delta`).
- Keyboard: Up/Down moves focus, Enter commits. Do not bind Enter to a default
  choice before focus is shown.

### 4.5 Report line (`scripts/report.gd`)

Add one line to the ledger panel at `y=190`, 6 px, MUTED, width 320, only when
`run.events` is non-empty:

```
DECISIONS  SOLAR STORM: RIDE IT OUT  ·  PRIVATE DONOR: DECLINE
```

Formatting:
- `DECISIONS  ` prefix, then `TITLE: LABEL` joined by `  ·  `.
- Labels are already uppercase in `data/events.json`.
- If the joined string exceeds 62 characters, print campaign titles only:
  `DECISIONS  SOLAR STORM  ·  PRIVATE DONOR`. Do not wrap (it would collide
  with `notes` at y=200).
- At most two entries per run (sectors 1–2), so the truncation rule is enough.
- No score effect. This is narrative only.

---

## 5. Hazard growth pre-state

Copy is additive: the existing telegraphed strings stay for active fronts.

| State | Threat line (`sector.gd` L423-441) | Render |
|---|---|---|
| Front just spawned, cannot fire this turn | `INCOMING: FLARE  ·  FORMING` | footprint at 45% alpha, no damage preview |
| Several forming | `INCOMING: FLARE +1  ·  FORMING` | each at 45% alpha |
| Active front (next turn onward) | existing: `INCOMING: FLARE  ·  SHIELD 2 PWR OR -1 INT` / `... · UNBLOCKABLE` / `... · SWEEP` | solid |
| No front | `—` | — |

Wording rules:
- Use `FORMING` only for the pre-state; do not use "growing", "charging",
  "inbound", or "warning".
- `FORMING` replaces the shield/sweep tail that turn — do not print both
  (`FORMING · SHIELD 2 PWR` is wrong and too long).
- The world render is the code side; copy only supplies the label. Faintness
  must never be the only difference: the label states it too (colour-blind and
  small-screen safety).

### 5.1 How-to-play row fix (`scripts/title.gd:116`)

This row currently carries the "3 of 4" bug (EVENTS.md §7 item 4) and is the
right place to explain forming fronts. Replace the body string with:

```
Click a tile to preview the path. One move per turn; ENTER commits. Collect the quota (3 or 4 nodes) before sols or delta-v run out. Faint fronts are forming and fire next turn.
```

The `03  SURVIVE` key stays. The extra sentence wraps inside the existing
382 px body column; no panel resize.

---

## 6. Risk bonus

Contract assumed from BOARD item 4: extracting with a live hazard front within
2 tiles of the lander awards a risk bonus, capped at 2 per run. b owns the exact
point value; **copy takes the number as a variable (`%d`) and never hard-codes
"1"** until b posts the formula.

### 6.1 In-sector

| Moment | String | Where |
|---|---|---|
| Quota met / net online, bonus available | append ` · RISK +1` to the existing quota-met route line | `_refresh_status()` L452 |
| Bonus already earned twice this run | append ` · RISK MAX` instead | same |
| Successful extract with the bonus | `RISK BONUS  +%d  ·  FRONT WITHIN 2 TILES` toast, GREEN | `_extract()` toast, `sector.gd:307` |

The ` · RISK +1` suffix is the whole tutorial for the mechanic: it appears at
the exact moment the player has to decide whether to leave. Do not show it
before the quota is met.

### 6.2 Debrief

On a successful sector with a bonus, append to the reason line (L87-92):

```
ALL QUOTAS MET  ·  RISK +%d
```

(Relay sector: `RELAY NETWORK DEPLOYED  ·  RISK +%d`.) 27–38 chars, fits the
286 px line at 7 px. No separate row: the summary panel is already full.

### 6.3 Report

The breakdown rows must still sum to `total`, so the risk points are a **seventh
row** after EFFICIENCY, never folded invisibly into another row. Layout
suggestion for `report.gd:_build_grade()`: move the rule to `y=145`, start rows
at `y=148`, step `13` (7 rows end at 238, inside the 248 px panel). Copy:

| Row label | Value |
|---|---|
| `RISK BONUS` | `+%d` |

Omit the row when the run earned 0. If ATLAS keeps the 14 px step instead, drop
the ALL-SUCCESS BONUS row into the notes block first (do not overflow the
panel); the risk row is the one that has to be visible.

---

## 7. Grade gap

Only on the final report, directly under the total score
(`report.gd:68-75`). The grade letter stays the dominant element.

| State | String | Placement |
|---|---|---|
| Next grade exists | `NEXT: %d TO %s` (e.g. `NEXT: 1043 TO A`) | 6, MUTED, centered, `(0, 144)`, 266×8 |
| Grade S | `NEXT: MAX GRADE` | same |
| Score below C threshold | `NEXT: %d TO C` — never negative | same |

Rules:
- `%d` is `threshold − total`, integer, no separators, no plus sign.
- Threshold table comes from `calculate_score()` (S 5200 / A 4000 / B 2800 / C
  is the floor, so C shows the gap to B).
- If `total` lands exactly on a threshold, the grade is that tier and the gap
  is the next tier up (never `NEXT: 0 TO ...`).
- The line must fit 266 px at 6 px; the largest realistic gap (`5200` from a
  near-zero run) is `NEXT: 5200 TO S` = 16 chars.

---

## 8. Do-not list (stale copy that must not survive the wiring)

- **Do not** keep `Collect 3 of 4 data nodes` anywhere
  (`title.gd:116`, and the onboarding card already avoids it).
- **Do not** promise `H` hides UI inside a sector. `sector.gd` overrides
  `_unhandled_input()` and does not call the parent; H is title-screen How to
  Play only (EVENTS.md §7 item 3).
- **Do not** call relay an "objective" or count beacons as "data nodes".
- **Do not** add a hard-coded `ORBIT LOW` line; the report already computes the
  orbit, and `debrief.gd:113` is the one remaining hard-coded copy (mismatch
  item 1 — replace with `ORBIT  %s INSERTION` and `GameState.orbit().name`).
- **Do not** claim events/relay/risk/growth in README, SUBMISSION, or the deck
  until ATLAS lands the wiring and d has a frame. When it lands, the claims to
  update are:
  - README §"A run, step by step" surface row: mention the relay sector task.
  - README §"Debrief and refit": mention the between-sector incident choice.
  - README §"Hazards": mention forming fronts.
  - README §"Scoring": mention risk bonus and the next-grade gap.
  - SUBMISSION feature list: same four lines, one sentence each.

---

## 9. Acceptance checklist (copy side)

- [ ] Relay sector: HUD reads RELAY / `n/3`; no DATA label on that sector.
- [ ] Relay flow: 3 beacons -> extract succeeds; 2 beacons -> failure reason is
      RELAY NET NOT DEPLOYED.
- [ ] Event card renders both `detail` strings in full before either is clicked.
- [ ] Event card cannot double-apply budget/approval.
- [ ] Report DECISIONS line appears only for events actually chosen.
- [ ] Forming fronts print `FORMING` and never the shield/sweep tail.
- [ ] Risk suffix appears only at quota-met / net-online; toast once per extract.
- [ ] Report breakdown rows sum to the printed total (risk row included).
- [ ] Grade gap is correct for C/B/A and says MAX GRADE at S.
- [ ] Every string above renders without clipping at 640×360 in the Web build.
- [ ] No "3 of 4", no in-sector H promise, no ORBIT LOW on non-LOW runs.

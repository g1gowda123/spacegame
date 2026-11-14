# Content Pack - Event Cards + Onboarding (owner: e)

Status: **content complete, wiring pending (ATLAS)**. Source of truth is
`data/events.json`; this file explains the schema, the balance intent, and the
exact hooks each effect needs. Nothing here is loaded by the game yet, so the
README does not claim events as shipped.

Read order for the implementer: this file, then `scripts/game_state.gd`
(`new_run`, `begin_sector`, `finish_sector`, `make_shop`) and
`scripts/debrief.gd`.

---

## 1. Why this pack exists

The boss directive (BOARD, 11:55) asks for "Event cards between sectors
(debrief choice)" - one card from a pool of ~8, seeded per run, two choices.
The goal is a **decision with no obviously correct answer** that changes the
next sector's opening position, not another shop. Cards are short, thematic,
and every option has a visible cost.

Hard rules used when writing them:

- **Deterministic.** Same run seed + sector => same card and same option text.
- **Telegraphed.** Both outcomes are printed on the card before the click.
- **No dead ends.** No option can zero approval, budget, hull, or sols at the
  moment it is chosen; clamps below guarantee a playable next sector.
- **No strictly better option.** Each pair trades a resource for a different
  resource (budget vs approval, hull vs sols, science vs heat, and so on).
- **No new systems.** Every effect reuses an existing sector field, so wiring
  is a `pending` dictionary and an apply block, not a new subsystem.

---

## 2. Flow and selection

```
sector 1 -> debrief (result + shop) -> EVENT CARD -> draft 2
sector 2 -> debrief (result + shop) -> EVENT CARD -> draft 3
sector 3 -> debrief -> final report            (no event)
```

Selection (deterministic, no save needed):

```
index = (int(run.seed) + int(run.sector) * 17) % events.size()
while events[index].id in run.event_ids_used:
    index = (index + 1) % events.size()
run.event_ids_used.append(events[index].id)
```

`run.sector` is already incremented by `finish_sector()`, so the event after
sector 1 reads `run.sector == 2`. Use the pre-increment value if the card is
shown before the increment; the constant only has to be stable.

Store the choice for the final report:

```
run.events.append({"id": id, "choice": choice_index, "label": label_text})
```

The report can then print one line: `DECISIONS  SOLAR STORM (ride it out) ·
PRIVATE DONOR (declined)`. No score effect.

---

## 3. Schema (`data/events.json`)

```json
{
  "id": "solar_storm",
  "tag": "SPACE WEATHER",
  "title": "SOLAR STORM",
  "body": "One or two sentences, <= 150 characters for the card width.",
  "choices": [
    { "label": "RIDE IT OUT", "kind": "greedy",
      "detail": "+10% science next sector, +8 starting heat.",
      "effects": { "science_mult_next": 1.10, "thermal_next": 8 } }
  ]
}
```

- `kind` is presentation only: `safe` = keeps the run stable, `greedy` = more
  upside with a resource cost. Use it for the choice colour/icon.
- `detail` is the exact promise the UI must render. Do not shorten it in a way
  that hides a downside.
- Effects are additive numbers unless the key ends in `_mult_next`, which is a
  multiplier.

---

## 4. Effect contract (wire these exact keys)

Apply `budget_delta` / `approval_delta` immediately when the choice is taken.
Bank every `*_next` key in `run.pending` (a Dictionary, default `{}`) and apply
it in `begin_sector()` **after** the base sector values are built and **before**
`changed.emit()`:

| Key | Apply at | Formula / clamp |
|---|---|---|
| `budget_delta` | immediately | `run.budget = max(0, run.budget + v)` |
| `approval_delta` | immediately | `run.approval = clamp(run.approval + v, 0, 100)` |
| `integrity_next` | `begin_sector` | `integrity = clamp(integrity + v, 1, integrity_max)` |
| `thermal_next` | `begin_sector` | `thermal = clamp(thermal + v, 0, 99)` |
| `heat_gain_next` | `begin_sector` | `heat_gain = clamp(heat_gain + v, 1, 18)` |
| `power_max_next` | `begin_sector` | `power_max = max(1, power_max + v)`, also raise `power` to match |
| `sols_next` | `begin_sector` | `sols = max(1, sols + v)`, update `sols_max` if you want the bar full |
| `delta_v_pct_next` | `begin_sector` | `dv = max(1, round(dv * (1 + v / 100)))` |
| `science_mult_next` | `begin_sector` | `science_mult = clamp(science_mult * v, 0.5, 2.0)` |
| `grant_mult_next` | `begin_sector` | `grant_mult = clamp(grant_mult * v, 0.5, 2.0)` |
| `move_range_next` | `begin_sector` | `move_range = clamp(move_range + v, 1, 6)` |

Consume the pending dictionary once (`run.pending = {}`) so it cannot stack by
mistake. If an event is skipped or the run ends, the pending effects are
simply dropped with the run.

Suggested `GameState` helpers (keeps `debrief.gd` dumb):

```gdscript
func draw_event() -> Dictionary   # returns one event, records its id
func resolve_event(choice_index: int) -> void  # applies immediate + banks pending
```

---

## 5. Balance intent (expected value, not exact scoring)

| # | Card | Safe option | Greedy option | Tension |
|---|---|---|---|---|
| 1 | Solar Storm | -3 sols | +10% science, +8 heat | tempo vs science + thermal risk |
| 2 | Private Donor | +2 approval | +$60M, -6 approval | ~90 score of funds vs ~72 score of approval and survival risk |
| 3 | Salvage Wreck | +$45M | +20% delta-v, -1 integrity | cash now vs route range next sector |
| 4 | Window Slip | -2 sols, +2 integrity | +4 sols, -2 integrity | time vs hull |
| 5 | Peer Review | +4 approval, -8% science | +20% science, -4 approval | science score vs defunding risk |
| 6 | Contractor Audit | -$40M, +2 integrity | +$15M, -1 integrity | funds vs a hull hit |
| 7 | Rival Leak | +1 power capacity | +20% grants, -3 approval | survivability vs money/approval |
| 8 | Gravity Assist | +10% delta-v, +6 heat | +1 move range, -12% delta-v | reach vs fuel + heat |

If playtesting shows one side always wins, change the numbers in
`data/events.json`, not the copy. Keep `detail` in sync with `effects` - the UI
shows `detail`.

---

## 6. Onboarding hint card (first sector only)

Three lines, shown once per run on the first sector, dismissable, and never
again in that run. Board item 6 (gameplay sprint) owns the copy; ATLAS owns
the widget.

Copy (fits a 300x54 panel at font size 7-8):

```
MOVE   Click a tile to preview the path. ENTER commits one move.
DATA   Collect the quota (3 or 4 nodes), then EXTRACT with E.
DANGER Hazards land where the grid shows, at end of turn. HOLD vents heat.
```

Notes for the implementer:

- Show when `int(GameState.run.sector) == 1 and turn == 1`, in `_start_sector()`
  or `_build_hud()`, and set `run.onboarded = true` when dismissed.
- Keep it inside the existing HUD frame; do not cover the D-pad or the three
  action buttons (they sit at `y=268..344` on the right).
- **Do not promise the H key in the sector.** The H "hide UI" toggle lives in
  `map_generator.gd` (`KEY_H`, `ui_layer.visible`), but `sector.gd` overrides
  `_unhandled_input()` and does not call the parent, so H does nothing during a
  surface run. `H` opens How to Play on the title screen only. Either wire the
  toggle in `sector.gd` first, or leave H off the card (this copy leaves it off).
- `V` cycles view mode and `G` toggles the grid in the sector, but the card is
  already full; put those on the pause/help overlay instead.

---

## 7. Copy and code mismatches found during the audit (for ATLAS)

These are real, verified against `HEAD 56e583c`; they are listed instead of
silently edited because they live in another owner's file.

| # | File:line | Problem | Suggested fix |
|---|---|---|---|
| 1 | `scripts/debrief.gd:113` | `ORBIT  LOW INSERTION` is hard-coded, so a POLAR or HIGH mission is reported as LOW. | `ORBIT  %s INSERTION` with `GameState.orbit().get("name", "LOW")`. |
| 2 | `scripts/sector.gd:33-36` + `1125-1133` | `ECLIPSE SHADOW` has `"power": 2` and the resolver subtracts `total_p`, so the hazard **drains** 2 power instead of restoring it (README and the sector theme say "restores"). | Use a negative cost or add a positive `power_gain` branch so the effect matches the copy. |
| 3 | `scripts/sector.gd:1335` vs `map_generator.gd:2833` | The sector overrides `_unhandled_input`, so `H` (hide UI) is dead during a surface run although the board says it works. | Call the parent handler for unhandled keys, or move the H toggle into the sector handler. |
| 4 | `scripts/title.gd:116` | "Collect 3 of 4 data nodes" is wrong for MAP THE SURFACE (quota 4). | "Collect the quota (3 or 4 nodes) before sols or delta-v run out." |

None of these block the event/copy pack; they are quick follow-ups.

---

## 8. Acceptance checklist for the wiring PR

- [ ] `data/events.json` parses (`JSON.parse_string`), 8 events, every choice has `label`, `detail`, `effects`.
- [ ] Card appears after sectors 1 and 2 only; never after the final sector.
- [ ] Two choices are clickable with mouse and keyboard; the chosen `detail` is visible before confirming.
- [ ] `budget_delta` / `approval_delta` apply once (no double click).
- [ ] `run.pending` is consumed exactly once in `begin_sector()`.
- [ ] Clamps hold: approval 0-100, budget >= 0, integrity >= 1, thermal <= 99, sols >= 1, delta-v >= 1, move range 1-6.
- [ ] Same run seed reproduces the same card order; replaying the same run does not repeat a card.
- [ ] Sector HUD number matches the promise (e.g. "+8 starting heat" shows exactly 8 more THERMAL).
- [ ] `docs/WORKLOG.md` and `docs/TASKS.md` updated; board message posted.

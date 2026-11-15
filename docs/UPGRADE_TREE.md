# Upgrade Tree

**Status:** implemented in `scripts/game_state.gd` (`UPGRADES`, `BRANCH_ROLE`,
`make_shop`, `sell_upgrade`) and `scripts/debrief.gd` (branch labels + RESALE
BAY). Art brief: `docs/MODULE_ART.md`.

## Rule

Every system has two paths. They are **not permanent**: the shop can offer
either path, and the player can mix, sell and rebuild. Tier 2 unlocks only after
tier 1 on the same path. The build identity comes from which branches you invest
in, not from a lock. Bloons-style reading, but with free resale.

| System | A path | A build | B path | B build |
|---|---|---|---|---|
| PROPULSION | RW-4 / RW-8 Gyrodyne | **BURN** — delta-v reserve | HALL H9 / H12 | **CRUISE** — move range |
| POWER | MMRTG-140 / 280 | **FISSION** — power over time | RFC-2 / RFC-4 | **CELL** — power + data/comms |
| THERMAL | LHP-2 / LHP-4 | **LOOP** — passive heat resistance | CRYO LOOP / II | **CRYO** — vent recovers power |
| STRUCTURE | WHIPPLE MK-I / II | **WHIPPLE** — pure hull | COMPOSITE / MK-II | **COMPOSITE** — hull + heat |
| COMMS | X-BAND HGA / KA-BAND DSN | **DSN** — downlink | SSR-4 / SSR-8 | **RECORDER** — data + comms |
| SCIENCE | MASS SPEC LAB / MK-II | **LAB** — science % | MULTI-SENSOR / II | **SENSOR** — data + science |
| SUPPORT | CONTRACT RIDER | **CONTRACT** — grant | FIELD KIT | **FIELD** — repair |

## Resale

`SELL PARTS` in the debrief opens **RESALE BAY**. Any installed part can be
pulled for **50%** of its purchase price. Tier 2 must be sold before its tier 1
prerequisite. Selling the last part on a path unlocks the other path at the next
shop refresh. Repair kits remove their unspent `next_integrity` when sold.

## Shop

Three cards, one guaranteed **branch continuation** if a tier 2 is unlocked and
one affordable anchor otherwise. Card line reads e.g. `PROPULSION A1 · BURN`.

## NASA references

Names follow NASA/industry hardware language (MMRTG, Whipple shield, Hall
thruster, X/Ka-band, SSR recorder). The challenge resource page's systems-
engineering and CML language is the intended flavour: parts are technology
insertions, not generic “power +1” cards.

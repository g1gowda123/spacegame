# QA tooling (person d)

QA for **Orbit & Outplay**. Three checks, in increasing cost:

| Tool | Needs | Checks | Output |
|---|---|---|---|
| `audit_project.py` | Python 3 | claims vs evidence: scene/asset refs resolve, art is actually wired, dataset recomputes, README tables match code, docs drift | `docs/QA_REPORT.md` |
| `native_screens.py` | Godot 4.7.2 + display | the real game on every screen; fails on script errors, blank frames, or a missing capture | `qa/artifacts/native/*.png` |
| `browser_loop.mjs` | Node 22+ and Chrome/Edge | the Web build in a browser: boot → title → design → draft → sector ×3 → report, page/console errors, per-stage screenshots | `qa/artifacts/web/*.png` + `report.json` |

No npm install and no Python packages are required. `native_screens.py` uses
Pillow for colour-count checks when it is available, and falls back to file-size
checks when it is not.

## Static audit

```bash
python tools/qa/audit_project.py            # write docs/QA_REPORT.md, always exit 0
python tools/qa/audit_project.py --check    # exit 1 if any check FAILs
```

`docs/QA_REPORT.md` is generated — edit the script, not the report.

## Native screen pass

```bash
python tools/qa/native_screens.py --godot "/path/to/Godot_v4.7.2-stable_win64_console.exe"
```

It runs `--screen=<name> --capture` through the game's `DevRouter`, copies each
frame out of `user://`, and rejects small, near-blank, or single-colour images.
A white, black, or gray frame is a FAILED capture, not a pass.

Screens: `title`, `crew`, `design`, `draft`, `sector`, `relay`,
`sector_success`, `sector_fail`, `debrief`, `report`. The first run also does a
one-time `--import` because a fresh clone has no `.godot` cache (without it the
scripts fail on `UIKit`).

## Browser loop

```bash
# Full loop against a local export
node tools/qa/browser_loop.mjs --dir build/web --port 8061

# Boot-only smoke after a new export
node tools/qa/browser_loop.mjs --dir build/web --mode boot

# Against an already-hosted build (no local server)
node tools/qa/browser_loop.mjs --url https://example.test/spacegame/ --mode boot

# Prove the harness itself works (no game build needed)
node tools/qa/browser_loop.mjs --self-test
```

Options: `--port` (static server, default 8061), `--debug-port` (Chrome
DevTools, default `port + 1`; they must differ), `--out` (capture dir),
`--chrome <path>` or `CHROME_PATH`, `--headful` to watch the run.

The loop drives the game the way a player does: `Enter` on title/design/draft,
then `Space` (HOLD) until the sector runs out of sols, then clicks the result
overlay's CONTINUE button and the debrief's next-target button. Those two click
points are logical 640×360 coordinates derived from `scripts/sector.gd:1278`
and `scripts/debrief.gd:242`; if those layouts move, update `clickLogical()`
calls in `browser_loop.mjs`. Every stage is screenshotted even when a later
stage fails, so a broken build still leaves evidence.

`report.json` records the URL, mode, stage captures, all console messages, and
the filtered page errors. SwiftShader `ReadPixels` / `GroupMarkerNotSet`
warnings are ignored; anything else fails the run.

## Evidence

Captures are local and gitignored (`qa/artifacts/`), matching the project rule
that build/submission artifacts stay out of git. Re-run the commands above to
reproduce them. Reference the file paths in `docs/WORKLOG.md` / `docs/BOARD.md`
when reporting a result.

## Scope

QA reports; it does not fix. `scripts/`, `scenes/`, and `assets/` belong to
ATLAS/VEGA — findings go to `docs/QA_REPORT.md`, `docs/TASKS.md`, and the board.

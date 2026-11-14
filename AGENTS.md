# Agent Coordination

This project may have multiple agents working in parallel. Read this before touching files.

**Attribution:** all image generation is run by the user in ComfyUI on their
machine; prompts, seeds and accept/reject calls are the user's. Agents write the
generation and pixelisation scripts, wire the outputs into the game, and do the
code. This file describes the coordination rules, not who generated the art.

## Read order

1. `README.md` — project overview and current status.
2. `docs/PROJECT.md` — brief game/project summary.
3. `docs/WORKLOG.md` — what has already happened and what was decided.
4. `docs/TASKS.md` — current task board and owners.
5. `docs/MAP_GENERATOR.md` — generator architecture and controls.
6. `docs/ART_PIPELINE.md` — tile generation rules.
7. `docs/ART_HANDOFF.md` — exact ComfyUI asset paths, sizes and prompts.

## Communication protocol

- **Append, do not rewrite.** Add a dated entry to `docs/WORKLOG.md` after any meaningful change: files touched, command run, result, decision, and blockers.
- **Claim work.** Put your name/handle and status in `docs/TASKS.md` before starting a multi-file task. Move it to Done when complete.
- **Respect file ownership.** Do not overwrite another agent's in-progress file without checking the work log.
- **Leave a handoff.** If you stop mid-task, add a “Handoff” bullet with the exact next command or file/line.
- **Record decisions, not just actions.** Future agents need the “why” (e.g. “band 1 because wider bands smear”).

## Hard constraints

- Godot 4.7.2, GDScript, **GL Compatibility** renderer for HTML5/WebGL 2.
- Viewport 640×360; nearest texture filtering; mobile memory budget matters.
- Keep the approved **diffusion pixel-art** look. Do not replace terrain with flat procedural graphics.
- Tiles: 64×64. Structures: 128×128 (2×2) or 192×192 (3×3).
- Palette-lock every tile to `tools/palettes.json`; heal seams with band 1.
- Raw 1024×1024 sources live in `assets/raw/`; game-ready tiles live in `assets/tilesets/`.
- The project is a Git repository on `main`. Commit per logical change and keep the work log in sync with what actually landed.

## Useful commands

```bash
# Run the game
godot --path /home/g1/godot/nasa

# Headless parse/smoke test
timeout 40s godot --headless --path /home/g1/godot/nasa --quit-after 8

# Generate a tile
/home/g1/ComfyUI/.venv/bin/python tools/gen_asset.py \
  "subject" --out assets/tilesets/<biome>/<name>.png \
  --size 64 --colors 16 --tile --biome <palette> --seed <n>

# Rebuild raw catalog + contact sheet
/home/g1/ComfyUI/.venv/bin/python tools/catalog_raw.py

# Restart ComfyUI if it segfaults
cd /home/g1/ComfyUI && setsid .venv/bin/python main.py \
  --listen 127.0.0.1 --port 8188 > /tmp/opencode/comfyui.log 2>&1 < /dev/null &
```

## Definition of done for map-generator work

- Scene opens and runs without parser/runtime errors.
- All three view modes render correctly and fit the screen.
- Walking, collecting, hazard damage, turn loss, and game-over all work.
- New tiles have palette-locked finals, no visible seams, and at least one transition path where materials meet.
- `docs/WORKLOG.md` and `docs/TASKS.md` are updated.

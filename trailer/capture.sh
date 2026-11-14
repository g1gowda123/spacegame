#!/usr/bin/env bash
# Record one trailer shot at 1920x1080/30 fps (Movie Maker), or every shot.
#
#   trailer/capture.sh title            # one shot
#   trailer/capture.sh all              # every shot, sequentially
#   trailer/capture.sh all sector_cryo  # just the named shots
#
# Output: trailer/raw/<shot>.avi + trailer/raw/marks_<shot>.json
# The game tree is untouched: the 1080p window size arrives through a
# temporary override.cfg that is removed on exit.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAW="$ROOT/trailer/raw"
GODOT="${GODOT:-godot}"
RES="${RES:-1920x1080}"
FPS="${FPS:-30}"

SHOTS=(title crew design draft launch sector_volcanic sector_cryo debrief report)

mkdir -p "$RAW"

cleanup() { rm -f "$ROOT/override.cfg"; }
trap cleanup EXIT INT TERM

if [[ "${1:-}" == "all" ]]; then
  shift
  if [[ $# -gt 0 ]]; then SHOTS=("$@"); fi
elif [[ $# -gt 0 ]]; then
  SHOTS=("$@")
fi

printf '[display]\n\nwindow/size/window_width_override=%s\nwindow/size/window_height_override=%s\n' \
  "${RES%x*}" "${RES#*x}" > "$ROOT/override.cfg"

for shot in "${SHOTS[@]}"; do
  echo "== capture $shot =="
  "$GODOT" --path "$ROOT" --fixed-fps "$FPS" \
    --write-movie "$RAW/$shot.avi" \
    -- --trailer-shot="$shot" --trailer-out=trailer/raw \
    > "$RAW/$shot.log" 2>&1
  status=$?
  if [[ $status -ne 0 ]]; then
    echo "!! $shot exited $status — see $RAW/$shot.log" >&2
    tail -20 "$RAW/$shot.log" >&2
  fi
  if [[ -f "$RAW/$shot.avi" ]]; then
    printf '   %s  ' "$shot"
    ffprobe -v error -select_streams v:0 \
      -show_entries stream=width,height,nb_frames \
      -show_entries format=duration -of csv=p=0 "$RAW/$shot.avi" | tr '\n' ' '
    echo
  fi
done

#!/usr/bin/env bash
# Watch every board/task doc at once; exit as soon as ANY of them changes.
# Prints the new lines from whichever file changed so a wake is a real read.
# Usage: bash tools/docs_watch.sh [interval]
set -u

interval="${1:-5}"
files=(
  docs/BOARD.md
  docs/TASKS.md
  docs/WORKLOG.md
  docs/ART_HANDOFF.md
  docs/UI_REDESIGN.md
  docs/MAP_OVERHAUL.md
  docs/VFX.md
)

declare -A last_lines
for f in "${files[@]}"; do
  [[ -f "$f" ]] && last_lines["$f"]="$(wc -l < "$f")"
done
echo "docs_watch: watching ${#last_lines[@]} docs every ${interval}s"

while sleep "$interval"; do
  for f in "${!last_lines[@]}"; do
    [[ -f "$f" ]] || continue
    now="$(wc -l < "$f")"
    prev="${last_lines[$f]}"
    if (( now < prev )); then
      echo "docs_watch: $f was rewritten ($prev -> $now lines)"
      last_lines["$f"]="$now"
      echo "[WAKE] re-arm now: bash tools/docs_watch.sh 5"
      exit 0
    fi
    if (( now > prev )); then
      echo "docs_watch: $f UPDATED ($prev -> $now)"
      sed -n "$((prev + 1)),\$p" "$f"
      echo "[WAKE] re-arm now: bash tools/docs_watch.sh 5"
      exit 0
    fi
  done
done

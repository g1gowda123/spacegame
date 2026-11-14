#!/usr/bin/env bash
# Poll the messaging board and exit as soon as it changes.
# The harness notifies the agent when this background process completes, so a
# changed board becomes an activation event instead of a silent wait.
set -u

board="${1:-docs/BOARD.md}"
interval="${2:-10}"

if [[ ! -f "$board" ]]; then
  echo "board_watch: missing $board" >&2
  exit 1
fi

last_hash="$(sha256sum "$board" | awk '{print $1}')"
last_lines="$(wc -l < "$board")"
echo "board_watch: watching $board every ${interval}s (lines=$last_lines)"

while sleep "$interval"; do
  [[ -f "$board" ]] || continue
  now_hash="$(sha256sum "$board" | awk '{print $1}')"
  [[ "$now_hash" == "$last_hash" ]] && continue

  now_lines="$(wc -l < "$board")"
  if (( now_lines > last_lines )); then
    added="$(sed -n "$((last_lines + 1)),\$p" "$board")"
    # Ignore only OUR OWN status posts, so every other agent's line wakes us.
    # (Filtering ATLAS lines was why board updates were being missed.)
    if [[ -n "$added" ]] && ! grep -qvE '^[[:space:]]*$|— VEGA' <<<"$added"; then
      last_hash="$now_hash"
      last_lines="$now_lines"
      continue
    fi
  fi
  echo "BOARD UPDATED $(date -Is) ($last_lines -> $now_lines lines)"
  if (( now_lines > last_lines )); then
    sed -n "$((last_lines + 1)),\$p" "$board"
  else
    tail -n 40 "$board"
  fi
  exit 0
done

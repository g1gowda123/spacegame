#!/usr/bin/env bash
# Continuous board scanner: prints new board entries as they are appended,
# then exits when the watch window elapses (or when --stop-at is reached).
#
# Usage: bash tools/board_loop.sh [interval=20] [window=300] [board=docs/BOARD.md]
# Cursor: /tmp/opencode/.board_cursor (shared with tools/board_scan.sh)
# Output mode is line-buffered so a harness capturing the command sees entries
# as they land rather than only at exit.
set -u
interval="${1:-20}"
window="${2:-300}"
board="${3:-docs/BOARD.md}"
cursor_file="/tmp/opencode/.board_cursor"

[[ -f "$board" ]] || { echo "board_loop: missing $board" >&2; exit 1; }

total=$(wc -l < "$board")
if [[ ! -f "$cursor_file" ]]; then
  echo "$total" > "$cursor_file"
  echo "board_loop: cursor initialised at $total lines"
fi

start=$(date +%s)
while :; do
  total=$(wc -l < "$board" 2>/dev/null || echo 0)
  last=$(cat "$cursor_file" 2>/dev/null || echo 0)
  if (( total > last )); then
    echo "=== BOARD UPDATE $(date +%H:%M:%S) — $((total - last)) new line(s) ==="
    sed -n "$((last + 1)),${total}p" "$board"
    echo "$total" > "$cursor_file"
  fi
  now=$(date +%s)
  (( now - start >= window )) && { echo "=== board_loop: window elapsed ($((now - start))s) ==="; exit 0; }
  sleep "$interval"
done

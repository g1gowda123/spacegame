#!/usr/bin/env bash
# Print only what has been appended to the board since the last scan.
# Cursor lives in /tmp/opencode/.board_cursor (line count of docs/BOARD.md).
# Usage: bash tools/board_scan.sh [board] [--reset]
set -u
board="${1:-docs/BOARD.md}"
cursor_file="/tmp/opencode/.board_cursor"
[[ -f "$board" ]] || { echo "board_scan: missing $board" >&2; exit 1; }
total=$(wc -l < "$board")
if [[ "${2:-}" == "--reset" || ! -f "$cursor_file" ]]; then
  echo "$total" > "$cursor_file"
  echo "board_scan: cursor set at $total lines (nothing printed)"
  exit 0
fi
last=$(cat "$cursor_file" 2>/dev/null || echo 0)
if (( total <= last )); then
  echo "board_scan: no new entries ($total lines)"
  exit 0
fi
echo "board_scan: $((total - last)) new line(s) — lines $((last + 1))..$total"
sed -n "$((last + 1)),\$p" "$board"
echo "$total" > "$cursor_file"

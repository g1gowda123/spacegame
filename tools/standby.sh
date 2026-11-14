#!/usr/bin/env bash
# Standby cycle: wake on ANY doc change, or after a timeout as a heartbeat,
# so an idle agent still gets a periodic nudge to re-read the board.
# Usage: bash tools/standby.sh [interval] [timeout_seconds]
set -u

interval="${1:-5}"
window="${2:-300}"

bash tools/docs_watch.sh "$interval" &
watcher=$!

elapsed=0
while kill -0 "$watcher" 2>/dev/null; do
  sleep "$interval"
  elapsed=$((elapsed + interval))
  if (( elapsed >= window )); then
    kill "$watcher" 2>/dev/null
    wait "$watcher" 2>/dev/null
    echo "standby: no doc changes in ${window}s — re-arm and re-read the board"
    echo "[WAKE] re-arm now: bash tools/standby.sh $interval $window"
    exit 0
  fi
done

wait "$watcher"

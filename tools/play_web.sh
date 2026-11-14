#!/usr/bin/env bash
# Serve the exported Web build locally and open it in the browser.
# Usage: tools/play_web.sh [port]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${1:-8061}"
URL="http://127.0.0.1:${PORT}/index.html"

if [[ ! -f "$ROOT/build/web/index.html" ]]; then
  echo "No Web export found at build/web/index.html." >&2
  echo "Export first from Godot: Project > Export > Web." >&2
  exit 1
fi

if ! curl -sf "$URL" >/dev/null 2>&1; then
  echo "Starting local server on ${PORT}..."
  (cd "$ROOT/build/web" && python3 -m http.server "$PORT" --bind 127.0.0.1 \
    >/tmp/orbit_web_server.log 2>&1 &)
  for _ in $(seq 1 30); do
    curl -sf "$URL" >/dev/null 2>&1 && break
    sleep 0.1
  done
fi

if ! curl -sf "$URL" >/dev/null 2>&1; then
  echo "Server failed to start; see /tmp/orbit_web_server.log" >&2
  exit 1
fi

echo "ORBIT & OUTPLAY: $URL"
if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$URL" >/dev/null 2>&1 || true
fi
